-- Procedurally builds the Storm Salvage town at server start.
-- Layout (north = -Z): raised Scrapyard hub in the north, town below it.
--   Gas Station (NW)   Supermarket (NE)
--   Houses (SW)   Town Square (centre)   Warehouse (SE)
--               Motel (far south)
--
-- Gameplay-relevant geometry (walls, floors, Roofs folder, trusses, loot points) is built by
-- building() and the zone code. Everything made with prop()/wedge() is decoration: anchored,
-- no shadows, ignored by raycasts, and kept clear of loot points.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Palette = require(game:GetService("ReplicatedStorage").Shared.Palette)

local MapBuilder = {}

local TOWN_HALF = 210 -- town ground is 420x420 centred on origin
local PLATEAU_HEIGHT = 30
local PLATEAU_CENTER = Vector3.new(0, 0, -275)
local PLATEAU_SIZE = Vector3.new(170, PLATEAU_HEIGHT, 110)

local TRIM = Color3.fromRGB(236, 230, 218)
local ASPHALT = Color3.fromRGB(52, 52, 58)
local CONCRETE = Color3.fromRGB(165, 162, 155)

local map: Model
local roofs: Folder

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local parent = props.Parent
	props.Parent = nil
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent or map
	return p
end

-- Decoration: no shadows (cheaper on mobile) and invisible to raycasts.
local function prop(props: { [string]: any }): Part
	if props.CastShadow == nil then
		props.CastShadow = false
	end
	props.CanQuery = false
	return part(props)
end

local function wedge(props: { [string]: any }): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.CanQuery = false
	local parent = props.Parent
	props.Parent = nil
	for k, v in props do
		(w :: any)[k] = v
	end
	w.Parent = parent or map
	return w
end

local function sign(parent: Instance, text: string, color: Color3, offsetY: number, maxDistance: number?)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 50)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = maxDistance or 250
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Parent = gui
	gui.Parent = parent
	return gui
end

-- Text painted onto one face of a part (storefront signs, the yard gate).
local function surfaceSign(
	target: BasePart,
	face: Enum.NormalId,
	text: string,
	color: Color3,
	font: Enum.Font?
)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.2
	gui.MaxDistance = 350
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = font or Enum.Font.FredokaOne
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.12, 0)
	pad.PaddingBottom = UDim.new(0.12, 0)
	pad.PaddingLeft = UDim.new(0.05, 0)
	pad.PaddingRight = UDim.new(0.05, 0)
	pad.Parent = label
	label.Parent = gui
	gui.Parent = target
	return gui
end

-- Wall along X or Z with an optional door gap in the middle.
local function wall(
	parent: Instance,
	center: Vector3,
	length: number,
	height: number,
	alongX: boolean,
	door: boolean,
	color: Color3,
	material: Enum.Material
)
	local thickness = 1
	local function seg(offset: number, len: number, y: number, h: number)
		local pos = alongX and center + Vector3.new(offset, y, 0) or center + Vector3.new(0, y, offset)
		local size = alongX and Vector3.new(len, h, thickness) or Vector3.new(thickness, h, len)
		part({ Parent = parent, Size = size, Position = pos, Color = color, Material = material })
	end
	if not door then
		seg(0, length, height / 2, height)
		return
	end
	local doorWidth, doorHeight = 8, 9
	local side = (length - doorWidth) / 2
	seg(-(doorWidth / 2 + side / 2), side, height / 2, height)
	seg(doorWidth / 2 + side / 2, side, height / 2, height)
	seg(0, doorWidth, doorHeight + (height - doorHeight) / 2, height - doorHeight)
end

-- Blender asset library (assets/roblox, synced by Rojo into ServerStorage.Assets). Each model's
-- pivot is its base center and its front faces -Z, so CFrame.lookAt(base, base + facing) places it.
local assetRoot = ServerStorage:FindFirstChild("Assets")

local function placeAsset(set: string, name: string, cf: CFrame, parent: Instance): Model?
	local folder = assetRoot and assetRoot:FindFirstChild(set)
	local source = folder and folder:FindFirstChild(name)
	if not source then
		warn("[MapBuilder] missing asset", set, name)
		return nil
	end
	local model = source:Clone() :: Model
	model:PivotTo(cf)
	model.Parent = parent
	return model
end

local function facing(base: Vector3, direction: Vector3): CFrame
	return CFrame.lookAt(base, base + direction)
end

-- Adds text to the one MeshPart of a model whose name contains `swatchKey`.
local function labelAsset(model: Model?, swatchKey: string, face: Enum.NormalId, text: string, color: Color3)
	if not model then
		return
	end
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and string.find(p.Name, swatchKey, 1, true) then
			surfaceSign(p, face, text, color, Enum.Font.LuckiestGuy)
			return
		end
	end
end

-- Recolors a placed asset: every MeshPart whose swatch (last "__" segment) is a key of `map`.
local function recolor(model: Model?, swatchColors: { [string]: Color3? })
	if not model then
		return
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			local swatch = string.match(p.Name, "__(%w+)$")
			local color = swatch and swatchColors[swatch]
			if color then
				p.Color = color
			end
		end
	end
end

local FACES = {
	N = { Normal = Vector3.new(0, 0, -1), Tangent = Vector3.new(1, 0, 0), Id = Enum.NormalId.Front },
	S = { Normal = Vector3.new(0, 0, 1), Tangent = Vector3.new(1, 0, 0), Id = Enum.NormalId.Back },
	E = { Normal = Vector3.new(1, 0, 0), Tangent = Vector3.new(0, 0, 1), Id = Enum.NormalId.Right },
	W = { Normal = Vector3.new(-1, 0, 0), Tangent = Vector3.new(0, 0, 1), Id = Enum.NormalId.Left },
}

export type BuildingOptions = {
	Sign: string?, -- storefront board above the door
	SignColor: Color3?,
	SignTextColor: Color3?,
	Label: string | false | nil, -- floating name; false hides it
	Gable: number?, -- pitched roof height (houses)
	Parapet: boolean?,
	Awning: boolean?, -- covered walkway along the front; counts as shelter
	Trim: Color3?,
	-- Blender shell drawn over invisible gameplay walls/roof (assets/roblox/town/<Name>).
	Shell: {
		Name: string,
		Set: string?, -- asset folder, default "town"
		Wall: Color3?,
		Roof: Color3?,
		Interior: boolean?,
		Porch: number?,
		SignText: string?, -- labels the shell's Signboard mesh
		SignColor: Color3?,
	}?,
	LootMargin: number?, -- distance from the walls to the loot grid (default 4)
}

-- Builds a hollow building. Returns interior loot points.
local function building(
	name: string,
	center: Vector3,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	doorFace: string,
	roofColor: Color3?,
	ladder: boolean?,
	opts: BuildingOptions?
): { Vector3 }
	local o: BuildingOptions = opts or {}
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = map

	local w, h, d = size.X, size.Y, size.Z
	local roofTint = roofColor or Color3.fromRGB(90, 60, 50)
	local trim = o.Trim or TRIM
	part({
		Parent = model,
		Name = "Floor",
		Size = Vector3.new(w, 1, d),
		Position = center + Vector3.new(0, 0.5, 0),
		Color = Color3.fromRGB(120, 105, 90),
		Material = Enum.Material.WoodPlanks,
	})
	local roof = part({
		Parent = roofs,
		Name = name .. "Roof",
		Size = Vector3.new(w + 2, 1, d + 2),
		Position = center + Vector3.new(0, h + 0.5, 0),
		Color = roofTint,
		Material = Enum.Material.Slate,
	})
	CollectionService:AddTag(roof, "Shelter")

	wall(model, center + Vector3.new(0, 0, -d / 2), w, h, true, doorFace == "N", color, material)
	wall(model, center + Vector3.new(0, 0, d / 2), w, h, true, doorFace == "S", color, material)
	wall(model, center + Vector3.new(w / 2, 0, 0), d, h, false, doorFace == "E", color, material)
	wall(model, center + Vector3.new(-w / 2, 0, 0), d, h, false, doorFace == "W", color, material)

	local face = FACES[doorFace]
	local shell = o.Shell
		and placeAsset(o.Shell.Set or "town", o.Shell.Name, facing(center, face.Normal), model)
	if shell and o.Shell then
		-- Walls and roof stay for collision, shelter raycasts, and flood/lightning rules; the
		-- shell draws the house. Its meshes never collide.
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") and p.Name ~= "Floor" then
				p.Transparency = 1
			end
		end
		roof.Transparency = 1
		recolor(shell, { Plaster = o.Shell.Wall, RoofRed = o.Shell.Roof })
		if o.Shell.SignText then
			labelAsset(
				shell,
				"Signboard",
				Enum.NormalId.Front,
				o.Shell.SignText,
				o.Shell.SignColor or Color3.new(1, 1, 1)
			)
		end
		if o.Shell.Porch then
			-- The porch roof looks like cover, so make it count as shelter.
			local porchRoof = part({
				Parent = roofs,
				Name = name .. "Porch",
				Size = Vector3.new(o.Shell.Porch, 0.6, 6),
				CFrame = facing(center, face.Normal) * CFrame.new(0, 10.4, -d / 2 - 2.6),
				Transparency = 1,
				CanCollide = false,
			})
			CollectionService:AddTag(porchRoof, "Shelter")
		end
		if o.Shell.Interior then
			local frame = facing(center, face.Normal)
			-- Furniture hugs the walls, outside the loot grid (LootMargin keeps loot >= 5 studs in).
			local layout = {
				{ "Sofa", CFrame.new(-13.2, 0, 2) * CFrame.Angles(0, -math.pi / 2, 0) },
				{ "Bed", CFrame.new(13.2, 0, 9.9) }, -- length along the east wall, headboard on the back wall
				{ "Kitchen", CFrame.new(-3, 0, 12.1) },
				{ "Shelf", CFrame.new(9, 0, -12.6) * CFrame.Angles(0, math.pi, 0) },
			}
			for _, item in layout do
				placeAsset("town", item[1], frame * CFrame.new(0, 1, 0) * item[2], model)
			end
		end
	end

	-- Windows on the side walls (cosmetic)
	for _, sx in (if shell then {} else { -1, 1 }) :: { number } do
		local glassPos = center + Vector3.new(sx * (w / 2 + 0.5), h * 0.55, 0)
		prop({
			Parent = model,
			Size = Vector3.new(0.3, 4, math.min(8, d / 3)),
			Position = glassPos,
			Color = Color3.fromRGB(150, 200, 230),
			Material = Enum.Material.Glass,
			Transparency = 0.3,
			CanCollide = false,
		})
		prop({
			Parent = model,
			Size = Vector3.new(0.2, 4.8, math.min(8, d / 3) + 0.8),
			Position = glassPos - Vector3.new(sx * 0.1, 0, 0),
			Color = trim,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
	end

	-- Front face: door frame, shop windows, storefront sign
	local faceWidth = face.Tangent.X ~= 0 and w or d
	local halfDepth = face.Tangent.X ~= 0 and d / 2 or w / 2
	local function onFace(along: number, y: number, out: number): Vector3
		return center + face.Tangent * along + face.Normal * (halfDepth + out) + Vector3.new(0, y, 0)
	end
	local function faceSize(width: number, height: number, thickness: number): Vector3
		return face.Tangent.X ~= 0 and Vector3.new(width, height, thickness)
			or Vector3.new(thickness, height, width)
	end
	for _, s in (if shell then {} else { -1, 1 }) :: { number } do
		prop({
			Parent = model,
			Size = faceSize(0.8, 9.6, 0.6),
			Position = onFace(s * 4.4, 4.8, 0.4),
			Color = trim,
			Material = Enum.Material.SmoothPlastic,
		})
	end
	if not shell then
		prop({
			Parent = model,
			Size = faceSize(9.6, 0.8, 0.6),
			Position = onFace(0, 9.4, 0.4),
			Color = trim,
			Material = Enum.Material.SmoothPlastic,
		})
	end
	if faceWidth >= 26 and not shell then
		local windowWidth = math.min(10, faceWidth * 0.2)
		for _, s in { -1, 1 } do
			prop({
				Parent = model,
				Size = faceSize(windowWidth, 4.5, 0.3),
				Position = onFace(s * faceWidth * 0.3, 5.5, 0.6),
				Color = Color3.fromRGB(150, 200, 230),
				Material = Enum.Material.Glass,
				Transparency = 0.35,
				CanCollide = false,
			})
			prop({
				Parent = model,
				Size = faceSize(windowWidth + 0.8, 5.3, 0.2),
				Position = onFace(s * faceWidth * 0.3, 5.5, 0.45),
				Color = trim,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
			})
		end
	end
	if o.Sign and not shell then
		local signY, signH = math.min(h - 2.2, 11.8), 3.6
		if o.Awning then
			signY, signH = 12.3, 3.2 -- sit between the awning and the roof
		end
		local board = prop({
			Parent = model,
			Name = "Sign",
			Size = faceSize(math.min(faceWidth * 0.6, 34), signH, 0.5),
			Position = onFace(0, signY, 0.5),
			Color = o.SignColor or Color3.fromRGB(40, 40, 48),
			Material = Enum.Material.SmoothPlastic,
		})
		surfaceSign(board, face.Id, o.Sign, o.SignTextColor or Color3.new(1, 1, 1))
	end
	if o.Awning then
		-- Covered walkway: real shelter from wind and lightning, so it's added to the Roofs folder.
		local awning = part({
			Parent = roofs,
			Name = name .. "Awning",
			Size = faceSize(faceWidth, 0.6, 6),
			Position = onFace(0, 10.3, 3),
			Color = roofTint,
			Material = Enum.Material.Metal,
		})
		CollectionService:AddTag(awning, "Shelter")
		if shell then
			awning.Transparency = 1 -- the shell draws the awning and its posts
		end
		for along = -faceWidth / 2 + 2, (if shell then -math.huge else faceWidth / 2 - 2), 15 do
			if math.abs(along) > 6 then
				prop({
					Parent = model,
					Size = Vector3.new(0.6, 10, 0.6),
					Position = onFace(along, 5, 5.6),
					Color = trim,
					Material = Enum.Material.Metal,
				})
			end
		end
	end

	if o.Gable and shell then
		-- Invisible pitched-roof collision under the shell's roof meshes, so anyone climbing
		-- the ladder in a flood stands on the roof they can see (not inside it).
		local rh = o.Gable
		local rd = d / 2 + 1.5
		for _, side in { -1, 1 } do
			local cf = CFrame.new(center + Vector3.new(0, h + 1 + rh / 2, side * rd / 2))
			if side == 1 then
				cf *= CFrame.Angles(0, math.pi, 0)
			end
			wedge({
				Parent = model,
				Name = "RoofSlope",
				Size = Vector3.new(w + 3, rh, rd),
				CFrame = cf,
				Transparency = 1,
				CastShadow = false,
			})
		end
	end
	if o.Gable and not shell then
		local rh = o.Gable
		local rd = (d + 3) / 2
		local baseY = h + 1
		for _, side in { -1, 1 } do
			-- A wedge's tall end is at +Z, so the south half is turned around to meet at the ridge.
			local cf = CFrame.new(center + Vector3.new(0, baseY + rh / 2, side * rd / 2))
			if side == 1 then
				cf *= CFrame.Angles(0, math.pi, 0)
			end
			wedge({
				Parent = model,
				Size = Vector3.new(w + 3, rh, rd),
				CFrame = cf,
				Color = roofTint,
				Material = Enum.Material.Slate,
			})
		end
		prop({
			Parent = model,
			Size = Vector3.new(2.5, rh + 2, 2.5),
			Position = center + Vector3.new(w * 0.25, baseY + (rh + 2) / 2, rd * 0.4),
			Color = Color3.fromRGB(140, 80, 65),
			Material = Enum.Material.Brick,
		})
	end
	if o.Parapet and not shell then
		local py = h + 1 + 0.8
		for _, s in { -1, 1 } do
			prop({
				Parent = model,
				Size = Vector3.new(w + 2, 1.6, 0.8),
				Position = center + Vector3.new(0, py, s * (d / 2 + 0.6)),
				Color = trim,
				Material = Enum.Material.Concrete,
			})
			prop({
				Parent = model,
				Size = Vector3.new(0.8, 1.6, d + 2),
				Position = center + Vector3.new(s * (w / 2 + 0.6), py, 0),
				Color = trim,
				Material = Enum.Material.Concrete,
			})
		end
	end

	if ladder then
		-- Truss on the back wall so players can climb to the roof during floods.
		local backZ = doorFace == "S" and -d / 2 - 2.5 or d / 2 + 2.5
		local truss = Instance.new("TrussPart")
		truss.Anchored = true
		truss.Size = Vector3.new(2, h + 4, 2) -- trusses snap to even sizes; all heights here are even
		truss.Position = center + Vector3.new(w / 2 - 4, (h + 4) / 2, backZ)
		truss.Color = Color3.fromRGB(230, 180, 40)
		truss.Parent = model
	end

	if o.Label ~= false then
		sign(roof, (o.Label or name) :: string, Color3.fromRGB(255, 255, 255), 8, 180)
	end

	local points = {}
	local margin = o.LootMargin or 4
	for x = -w / 2 + margin, w / 2 - margin, 7 do
		for z = -d / 2 + margin, d / 2 - margin, 7 do
			table.insert(points, center + Vector3.new(x, 2.5, z))
		end
	end
	return points
end

local treeRng = Random.new(11)

-- Town props come from the Blender kit when it's present; the primitive versions remain as a
-- fallback so the map still builds without assets.
local function townAsset(name: string, cf: CFrame, scale: number?): Model?
	if not (assetRoot and assetRoot:FindFirstChild("town")) then
		return nil
	end
	local model = placeAsset("town", name, cf, map)
	if model and scale and scale ~= 1 then
		model:ScaleTo(scale)
	end
	return model
end

local function tree(pos: Vector3)
	if
		townAsset(
			"TreeBlocky",
			CFrame.new(pos) * CFrame.Angles(0, treeRng:NextNumber(0, math.pi * 2), 0),
			treeRng:NextNumber(0.9, 1.35)
		)
	then
		return
	end
	local height = treeRng:NextNumber(9, 13)
	prop({
		Size = Vector3.new(height, 1.6, 1.6),
		Position = pos + Vector3.new(0, height / 2, 0),
		Shape = Enum.PartType.Cylinder,
		Orientation = Vector3.new(0, 0, 90),
		Color = Color3.fromRGB(95, 68, 45),
		Material = Enum.Material.Wood,
		CastShadow = true,
	})
	for i = 1, 3 do
		local s = treeRng:NextNumber(6, 9)
		local offset = Vector3.new(
			treeRng:NextNumber(-2.5, 2.5),
			height + treeRng:NextNumber(0, 3) + (i == 1 and 1 or 0),
			treeRng:NextNumber(-2.5, 2.5)
		)
		local green = Color3.fromHSV(
			treeRng:NextNumber(0.24, 0.32),
			treeRng:NextNumber(0.45, 0.6),
			treeRng:NextNumber(0.42, 0.58)
		)
		prop({
			Size = Vector3.one * s,
			Position = pos + offset,
			Shape = Enum.PartType.Ball,
			Color = green,
			Material = Enum.Material.Grass,
			CanCollide = false,
			CastShadow = true,
		})
	end
end

local function bush(pos: Vector3, s: number)
	if townAsset("BushRound", CFrame.new(pos) * CFrame.Angles(0, treeRng:NextNumber(0, 6.28), 0), s / 4) then
		return
	end
	prop({
		Size = Vector3.new(s, s * 0.7, s),
		Position = pos + Vector3.new(0, s * 0.3, 0),
		Shape = Enum.PartType.Ball,
		Color = Color3.fromRGB(70, 125, 60),
		Material = Enum.Material.Grass,
		CanCollide = false,
	})
end

-- facing: the direction the lamp arm reaches (over the road).
local function streetLight(pos: Vector3, facingDir: Vector3?)
	local lampModel = townAsset("StreetLamp", facing(pos, facingDir or Vector3.new(-1, 0, 0)))
	if lampModel then
		for _, p in lampModel:GetChildren() do
			if p:IsA("BasePart") and p.Material == Enum.Material.Neon then
				local light = Instance.new("PointLight")
				light.Range = 24
				light.Brightness = 1.5
				light.Color = Color3.fromRGB(255, 230, 180)
				light.Parent = p
			end
		end
		return
	end
	prop({
		Size = Vector3.new(0.6, 14, 0.6),
		Position = pos + Vector3.new(0, 7, 0),
		Color = Color3.fromRGB(60, 60, 65),
		Material = Enum.Material.Metal,
	})
	local lamp = prop({
		Size = Vector3.new(2, 0.8, 2),
		Position = pos + Vector3.new(0, 14.2, 0),
		Color = Color3.fromRGB(255, 240, 200),
		Material = Enum.Material.Neon,
	})
	local light = Instance.new("PointLight")
	light.Range = 24
	light.Brightness = 1.5
	light.Color = Color3.fromRGB(255, 230, 180)
	light.Parent = lamp
end

local function car(pos: Vector3, color: Color3, rotY: number)
	local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(rotY), 0)
	part({
		Size = Vector3.new(6, 2.2, 11),
		CFrame = cf * CFrame.new(0, 1.8, 0),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
	})
	prop({
		Size = Vector3.new(5.6, 2, 5.5),
		CFrame = cf * CFrame.new(0, 3.9, -0.5),
		Color = Color3.fromRGB(40, 50, 60),
		Material = Enum.Material.Glass,
		Transparency = 0.2,
	})
	for _, o in
		{
			Vector3.new(-3, 0.9, 3.5),
			Vector3.new(3, 0.9, 3.5),
			Vector3.new(-3, 0.9, -3.5),
			Vector3.new(3, 0.9, -3.5),
		}
	do
		prop({
			Size = Vector3.new(1, 1.8, 1.8),
			CFrame = cf * CFrame.new(o),
			Shape = Enum.PartType.Cylinder,
			Color = Color3.fromRGB(25, 25, 25),
		})
	end
end

-- Power pole; returns the wire attachment height for stringing lines between poles.
local function powerPole(pos: Vector3): Vector3
	-- Turned so the crossarm runs across the line of wires (wires run along X).
	if townAsset("PowerPole", CFrame.new(pos) * CFrame.Angles(0, math.pi / 2, 0)) then
		return pos + Vector3.new(0, 19.2, 0)
	end
	prop({
		Size = Vector3.new(1, 20, 1),
		Position = pos + Vector3.new(0, 10, 0),
		Color = Color3.fromRGB(100, 78, 58),
		Material = Enum.Material.Wood,
		CastShadow = true,
	})
	prop({
		Size = Vector3.new(6, 0.5, 0.5),
		Position = pos + Vector3.new(0, 18.5, 0),
		Color = Color3.fromRGB(100, 78, 58),
		Material = Enum.Material.Wood,
	})
	return pos + Vector3.new(0, 18.8, 0)
end

local function wire(a: Vector3, b: Vector3)
	prop({
		Size = Vector3.new(0.15, 0.15, (a - b).Magnitude),
		CFrame = CFrame.lookAt((a + b) / 2, b),
		Color = Color3.fromRGB(25, 25, 25),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
end

---------------------------------------------------------------------------- Environment

local function ensure(parent: Instance, className: string, name: string): any
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = parent
	return inst
end

-- Warm late-afternoon grade for calm weather; StormService tweens these during storms.
local function setupEnvironment()
	Lighting.ClockTime = 15.5
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(70, 70, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(135, 130, 125)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 240, 215)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.GeographicLatitude = 35

	local grade = ensure(Lighting, "ColorCorrectionEffect", "Grade")
	grade.Saturation = 0.12
	grade.Contrast = 0.06
	grade.Brightness = 0
	grade.TintColor = Color3.fromRGB(255, 248, 238)
	local bloom = ensure(Lighting, "BloomEffect", "Bloom")
	bloom.Intensity = 0.35
	bloom.Size = 22
	bloom.Threshold = 1.4
	local rays = ensure(Lighting, "SunRaysEffect", "SunRays")
	rays.Intensity = 0.05
	rays.Spread = 0.6

	-- Flash floods are muddy, not tropical.
	local terrain = workspace.Terrain
	terrain.WaterColor = Color3.fromRGB(92, 84, 58)
	terrain.WaterTransparency = 0.35
	terrain.WaterReflectance = 0.25
	terrain.WaterWaveSize = 0.25
	terrain.WaterWaveSpeed = 14
end

---------------------------------------------------------------------------- Scrapyard

local yardRng = Random.new(7)

local function buildScrapyard(yard: Model, sellPart: BasePart, shopPart: BasePart, rampStartZ: number)
	local top = PLATEAU_HEIGHT
	prop({
		Parent = yard,
		Name = "YardFloor",
		Size = Vector3.new(PLATEAU_SIZE.X, 0.2, PLATEAU_SIZE.Z),
		Position = PLATEAU_CENTER + Vector3.new(0, top + 0.1, 0),
		Color = Palette.Swatches.RustDark:Lerp(Palette.Swatches.Sand, 0.45),
		Material = Enum.Material.Ground,
	})
	prop({
		Parent = yard,
		Name = "Pad",
		Size = Vector3.new(100, 0.3, 34),
		Position = Vector3.new(0, top + 0.15, sellPart.Position.Z),
		Color = CONCRETE,
		Material = Enum.Material.Concrete,
	})

	-- Shops: the model's counter sits 4.4 studs in front of its origin, so step back from the
	-- (invisible) prompt part along its facing.
	for _, info in
		{
			{ sellPart, "SellShack", "SCRAP BUYER", Palette.Swatches.NeonGreen },
			{ shopPart, "GearShack", "GEAR SHOP", Palette.Swatches.StormCyan },
		}
	do
		local counter: BasePart = info[1]
		local look = counter.CFrame.LookVector
		local ground = Vector3.new(counter.Position.X, top, counter.Position.Z)
		local shack = placeAsset("scrapyard", info[2], facing(ground, look) * CFrame.new(0, 0, 4.4), yard)
		labelAsset(shack, "HazardBlack", Enum.NormalId.Front, info[3], info[4])
	end

	-- Fence panels around the three outer edges.
	local minX, maxX = -PLATEAU_SIZE.X / 2 + 1, PLATEAU_SIZE.X / 2 - 1
	local minZ = PLATEAU_CENTER.Z - PLATEAU_SIZE.Z / 2 + 1
	for x = minX + 5.25, maxX - 5, 10.5 do
		placeAsset("scrapyard", "FencePanel", facing(Vector3.new(x, top, minZ), Vector3.new(0, 0, 1)), yard)
	end
	for _, x in { minX, maxX } do
		for z = minZ + 5.25, rampStartZ - 6, 10.5 do
			placeAsset(
				"scrapyard",
				"FencePanel",
				facing(Vector3.new(x, top, z), Vector3.new(-math.sign(x), 0, 0)),
				yard
			)
		end
	end

	-- Back of the yard: scrap mountains, the crusher, and the crushed-car stack.
	for _, spot in
		{
			Vector3.new(-68, 1.8, 11),
			Vector3.new(-22, 1.5, 9),
			Vector3.new(22, 1.6, 10),
			Vector3.new(66, 1.4, 9),
			Vector3.new(-74, 1.2, 50),
			Vector3.new(0, 1.2, 8),
		}
	do
		local pile = placeAsset(
			"scrapyard",
			"ScrapPile",
			CFrame.new(spot.X, top, minZ + spot.Z) * CFrame.Angles(0, yardRng:NextNumber(0, math.pi * 2), 0),
			yard
		)
		if pile then
			pile:ScaleTo(spot.Y)
		end
	end
	placeAsset("scrapyard", "Crusher", facing(Vector3.new(-48, top, -306), Vector3.new(0, 0, 1)), yard)
	placeAsset("scrapyard", "CarStack", CFrame.new(-70, top, -282) * CFrame.Angles(0, math.rad(12), 0), yard)

	-- East side: stacked containers, pallets, and a workbench by the gear shop.
	placeAsset("scrapyard", "Container", CFrame.new(72, top, -262), yard)
	placeAsset("scrapyard", "Container", CFrame.new(72, top, -284) * CFrame.Angles(0, math.rad(4), 0), yard)
	placeAsset(
		"scrapyard",
		"Container",
		CFrame.new(71, top + 8.5, -273) * CFrame.Angles(0, math.rad(-6), 0),
		yard
	)
	placeAsset(
		"scrapyard",
		"PalletStack",
		CFrame.new(50, top, -282) * CFrame.Angles(0, math.rad(20), 0),
		yard
	)
	placeAsset("scrapyard", "Workbench", facing(Vector3.new(52, top, -250), Vector3.new(-1, 0, 0)), yard)

	-- West side and around the counters.
	placeAsset(
		"scrapyard",
		"TireStack",
		CFrame.new(-50, top, -282) * CFrame.Angles(0, math.rad(-30), 0),
		yard
	)
	placeAsset("scrapyard", "OilDrums", CFrame.new(-38, top, -247) * CFrame.Angles(0, math.rad(40), 0), yard)
	placeAsset("scrapyard", "OilDrums", CFrame.new(40, top, -243) * CFrame.Angles(0, math.rad(-70), 0), yard)
	placeAsset("scrapyard", "Wreck", CFrame.new(-52, top, -234) * CFrame.Angles(0, math.rad(35), 0), yard)

	-- Floodlights in the corners light the yard at storm time.
	for _, pos in
		{
			Vector3.new(-78, top, -320),
			Vector3.new(78, top, -320),
			Vector3.new(-78, top, -232),
			Vector3.new(78, top, -232),
		}
	do
		placeAsset("scrapyard", "Floodlight", facing(pos, Vector3.new(-math.sign(pos.X), 0, 0)), yard)
	end

	-- Crane: the landmark you can see from anywhere in town. Its jib reaches over the yard (-X).
	-- Blender +X becomes Roblox -X on import (Y-up conversion), so the jib modeled along -X points
	-- +X here; turn it around so it reaches into the yard.
	placeAsset("scrapyard", "Crane", CFrame.new(58, top, -300) * CFrame.Angles(0, math.pi, 0), yard)
	placeAsset("scrapyard", "TireStack", CFrame.new(-20, top, -312) * CFrame.Angles(0, math.rad(60), 0), yard)
	placeAsset("scrapyard", "Wreck", CFrame.new(28, top, -310) * CFrame.Angles(0, math.rad(-80), 0), yard)
	placeAsset("scrapyard", "OilDrums", CFrame.new(46, top, -318) * CFrame.Angles(0, math.rad(15), 0), yard)

	-- Gate arch over the top of the ramp, front (with its bulbs) facing the town.
	local gate = placeAsset(
		"scrapyard",
		"GateArch",
		facing(Vector3.new(0, top, rampStartZ - 1.5), Vector3.new(0, 0, 1)),
		yard
	)
	labelAsset(gate, "HazardBlack", Enum.NormalId.Front, "STORM SALVAGE YARD", Palette.Swatches.SafetyYellow)
	labelAsset(gate, "HazardBlack", Enum.NormalId.Back, "GOOD LUCK OUT THERE", Palette.Swatches.SafetyYellow)
end

---------------------------------------------------------------------------- District upgrade

-- Swaps the primitive district dressing for the Blender kit (assets/roblox/districts) when it's
-- present. Gameplay parts (canopy shelter, columns, fountain basin) stay as invisible collision.
local function upgradeDistricts()
	local districts = assetRoot and assetRoot:FindFirstChild("districts")
	if not districts then
		return
	end
	local function place(name: string, cf: CFrame): Model?
		return placeAsset("districts", name, cf, map)
	end
	local function eachNamed(names: { [string]: "hide" | "remove" })
		for _, d in map:GetChildren() do
			local action = names[d.Name]
			if action == "remove" then
				d:Destroy()
			elseif action == "hide" and d:IsA("BasePart") then
				d.Transparency = 1
			end
		end
	end

	-- Gas station: canopy (turned so its pump islands sit on the old pump spots), pumps, pylon.
	eachNamed({
		CanopyTrim = "remove",
		PumpBlock = "remove",
		PriceSignPole = "remove",
		PriceSign = "remove",
		CanopyColumn = "hide",
	})
	local canopyShelter = roofs:FindFirstChild("Canopy") :: BasePart?
	if canopyShelter then
		canopyShelter.Transparency = 1
	end
	place("FuelCanopy", CFrame.new(-120, 0, -45) * CFrame.Angles(0, math.pi, 0))
	for _, x in { -128, -98 } do
		place("FuelPump", facing(Vector3.new(x, 0.6, -45), Vector3.new(0, 0, 1)))
	end
	local pylon = place("PriceSign", facing(Vector3.new(-146, 0, -30), Vector3.new(0, 0, 1)))
	labelAsset(pylon, "Signboard", Enum.NormalId.Front, "GAS\n$3.99", Palette.Swatches.White)
	labelAsset(pylon, "Signboard", Enum.NormalId.Back, "GAS\n$3.99", Palette.Swatches.White)
	place("Dumpster", facing(Vector3.new(-132, 0, -101), Vector3.new(0, 0, 1)))

	-- Supermarket (door faces +Z): aisle shelves in rows between the loot rows (z offsets
	-- -17.5, -3.5, 10.5), gaps between units so the aisles connect; side shelves along the walls.
	local market = Vector3.new(120, 0, -80)
	eachNamed({ SideShelf = "remove" })
	for _, dz in { -17.5, -3.5, 10.5 } do
		for _, dx in { -22, -7, 8, 23 } do
			place("AisleShelf", CFrame.new(market + Vector3.new(dx, 1, dz)))
		end
	end
	-- Wall shelves on the east side only: the grid's west column is 1.5 studs from that wall.
	for _, sx in { 1 } do
		for _, dz in { -13, 0, 13 } do
			place("AisleShelf", facing(market + Vector3.new(sx * 33.4, 1, dz), Vector3.new(-sx, 0, 0)))
		end
	end
	for _, info in
		{
			{ Vector3.new(110, 0.25, -30), 25 },
			{ Vector3.new(141, 0.25, -47), -60 },
			{ Vector3.new(127, 0.25, -51), 95 },
		}
	do
		place("ShoppingCart", CFrame.new(info[1]) * CFrame.Angles(0, math.rad(info[2]), 0))
	end
	place("Dumpster", facing(Vector3.new(146, 0, -109), Vector3.new(0, 0, 1)))

	-- Warehouse (door faces -Z): pallet racks between loot rows (z offsets -22.5, -8.5, 5.5,
	-- 19.5) with a center aisle in line with the door; forklift parked outside.
	local warehouse = Vector3.new(125, 0, 90)
	for _, dz in { -22.5, -8.5, 5.5, 19.5 } do
		for _, dx in { -16, 16 } do
			place("PalletRack", CFrame.new(warehouse + Vector3.new(dx, 1, dz)))
		end
	end
	place("Forklift", facing(Vector3.new(114, 0, 50), Vector3.new(-1, 0, 0)))
	place("Dumpster", facing(Vector3.new(98, 0, 125), Vector3.new(0, 0, -1)))

	-- Motel (door faces -Z): beds along the back wall, machines on the walkway, new pole sign.
	local motel = Vector3.new(0, 0, 165)
	for _, dx in { -42, -28, -14, 14, 28, 42 } do
		local bed = assetRoot and assetRoot:FindFirstChild("town") and assetRoot.town:FindFirstChild("Bed")
		if bed then
			placeAsset(
				"town",
				"Bed",
				CFrame.new(motel + Vector3.new(dx, 1, 13.2)) * CFrame.Angles(0, math.pi / 2, 0),
				map
			)
		end
	end
	place("VendingMachine", facing(Vector3.new(-30, 0.4, 146.5), Vector3.new(0, 0, -1)))
	place("IceMachine", facing(Vector3.new(26, 0.4, 146.5), Vector3.new(0, 0, -1)))
	eachNamed({ MotelSignPole = "remove", MotelSign = "remove", MotelSignGlow = "remove" })
	local motelSign = place("MotelSign", facing(Vector3.new(-64, 0, 142), Vector3.new(0, 0, -1)))
	labelAsset(motelSign, "Signboard", Enum.NormalId.Front, "MOTEL\nVACANCY", Palette.Swatches.NeonPink)
	labelAsset(motelSign, "Signboard", Enum.NormalId.Back, "MOTEL\nVACANCY", Palette.Swatches.NeonPink)

	-- Town square: tiered fountain over the old basin (kept invisible for collision and the spray),
	-- siren tower, and a memorial outside the loot grid.
	eachNamed({ FountainColumn = "remove", Fountain = "hide", FountainWater = "hide" })
	place("Fountain", CFrame.new(-50, 0.4, -55))
	local water = map:FindFirstChild("FountainWater") :: BasePart?
	local spray = water and water:FindFirstChildOfClass("ParticleEmitter")
	if spray then
		local nozzle = prop({
			Name = "FountainNozzle",
			Size = Vector3.one,
			Position = Vector3.new(-50, 11, -55),
			Transparency = 1,
			CanCollide = false,
		})
		spray.Parent = nozzle
	end
	eachNamed({ SirenBase = "remove", SirenPole = "remove", Siren = "remove", SirenHorn = "remove" })
	place("SirenTower", CFrame.new(-92, 0, -40))
	place("Statue", facing(Vector3.new(-88, 0, -82), Vector3.new(1, 0, 0.6)))

	-- Props merged from the five-district source pack (assets/roblox/districtprops).
	if not (assetRoot and assetRoot:FindFirstChild("districtprops")) then
		return
	end
	local function packProp(name: string, cf: CFrame): Model?
		return placeAsset("districtprops", name, cf, map)
	end
	local function lightNeon(model: Model?, range: number)
		if not model then
			return
		end
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") and p.Material == Enum.Material.Neon then
				local light = Instance.new("PointLight")
				light.Range = range
				light.Brightness = 1.4
				light.Color = Color3.fromRGB(255, 225, 170)
				light.Parent = p
			end
		end
	end

	-- Supermarket: cart corral in the lot, produce out front, stock pallets by the loading door.
	packProp("CartCorral", CFrame.new(150, 0.25, -34))
	packProp("ProduceStand", facing(Vector3.new(100, 0.25, -51), Vector3.new(0, 0, 1)))
	packProp("FoodPallet", CFrame.new(132, 0, -109) * CFrame.Angles(0, math.rad(12), 0))

	-- Gas station: an open-air repair bay on the west side.
	prop({
		Name = "RepairPad",
		Size = Vector3.new(18, 0.3, 22),
		Position = Vector3.new(-153, 0.15, -82),
		Color = CONCRETE,
		Material = Enum.Material.Concrete,
		CanQuery = true,
	})
	packProp("GarageLift", facing(Vector3.new(-153, 0.3, -80), Vector3.new(1, 0, 0)))
	packProp("ToolCabinet", facing(Vector3.new(-147, 0.3, -91), Vector3.new(0, 0, 1)))
	packProp("OilRack", facing(Vector3.new(-157, 0.3, -91.5), Vector3.new(0, 0, 1)))
	packProp("Extinguisher", facing(Vector3.new(-112.5, 0.3, -63.6), Vector3.new(0, 0, 1)))

	-- Warehouse: loading dock at the east bay, cargo and a pallet jack in the yard, hanging lamps
	-- and a duct inside (the lamp model hangs 3.7-7.7 studs above its pivot).
	eachNamed({ YardCrate = "remove" })
	-- The yard's primitive containers become the Scrapyard's Blender container (same 8 x 8.5 x 20
	-- footprint). The source part's center is mid-height, the asset's pivot is its base.
	for _, d in map:GetChildren() do
		if d.Name == "Container" and d:IsA("BasePart") then
			local base = d.CFrame * CFrame.new(0, -d.Size.Y / 2, 0)
			placeAsset("scrapyard", "Container", base, map)
			d.Transparency = 1 -- keep the collision box
		end
	end
	packProp("LoadingDock", facing(Vector3.new(147, 0, 53.4), Vector3.new(0, 0, -1)))
	-- Beside the building, not in front of a bay door.
	packProp("CargoStack", facing(Vector3.new(84, 0, 66), Vector3.new(1, 0, 0)))
	packProp("PalletJack", CFrame.new(134, 0, 49) * CFrame.Angles(0, math.rad(-20), 0))
	for _, pos in
		{
			Vector3.new(125, 14.3, 72),
			Vector3.new(125, 14.3, 98),
			Vector3.new(105, 14.3, 85),
			Vector3.new(145, 14.3, 85),
		}
	do
		lightNeon(packProp("IndustryLamp", CFrame.new(pos)), 32)
	end
	packProp("VentDuct", CFrame.new(125, 17, 116))

	-- Motel: dressers between the beds and a sink on the back wall; luggage cart on the walkway;
	-- AC units outside the back.
	for _, dx in { -35, -21, 21, 35 } do
		packProp("MotelDresser", CFrame.new(dx, 1, 177.9))
	end
	packProp("BathroomSink", CFrame.new(0, 1, 178.0))
	packProp("LuggageCart", facing(Vector3.new(8, 0.4, 147), Vector3.new(0, 0, -1)))
	for _, x in { -40, -10, 20, 45 } do
		packProp("OutdoorAC", facing(Vector3.new(x, 0, 183), Vector3.new(0, 0, 1)))
	end

	-- Town square: clock tower landmark behind the plaza, planters beside it, and a bus stop on
	-- the cross road. The bus stop's roof looks like cover, so it counts as shelter.
	packProp("ClockTower", facing(Vector3.new(-50, 0, -98), Vector3.new(0, 0, 1)))
	for _, x in { -62, -38 } do
		packProp("RoundPlanter", CFrame.new(x, 0, -92))
	end
	packProp("BusStop", facing(Vector3.new(-62, 0, -14), Vector3.new(0, 0, 1)))
	local busRoof = part({
		Parent = roofs,
		Name = "BusStopShelter",
		Size = Vector3.new(17, 0.6, 6),
		Position = Vector3.new(-62, 10.1, -14),
		Transparency = 1,
		CanCollide = false,
	})
	CollectionService:AddTag(busRoof, "Shelter")
	packProp("NoticeBoard", facing(Vector3.new(-36, 0, -15), Vector3.new(0, 0, 1)))
end

---------------------------------------------------------------------------- Build

function MapBuilder.build()
	local existing = workspace:FindFirstChild("Map")
	if existing then
		existing:Destroy()
	end
	map = Instance.new("Model")
	map.Name = "Map"
	map.Parent = workspace
	roofs = Instance.new("Folder")
	roofs.Name = "Roofs"
	roofs.Parent = map

	setupEnvironment()

	-- Ground, roads, boundary
	part({
		Name = "Ground",
		Size = Vector3.new(TOWN_HALF * 2, 4, TOWN_HALF * 2),
		Position = Vector3.new(0, -2, 0),
		Color = Color3.fromRGB(88, 135, 72),
		Material = Enum.Material.Grass,
	})
	-- Main road runs from the foot of the plateau to the motel's covered walkway (z=144).
	local roadEndZ = 144
	part({
		Name = "MainRoad",
		Size = Vector3.new(24, 0.2, TOWN_HALF + roadEndZ),
		Position = Vector3.new(0, 0.1, (roadEndZ - TOWN_HALF) / 2),
		Color = ASPHALT,
		Material = Enum.Material.Asphalt,
	})
	part({
		Name = "CrossRoad",
		Size = Vector3.new(TOWN_HALF * 2, 0.2, 24),
		Position = Vector3.new(0, 0.1, 10),
		Color = ASPHALT,
		Material = Enum.Material.Asphalt,
	})
	for z = -TOWN_HALF + 10, roadEndZ - 10, 20 do
		if z < -6 or z > 26 then
			prop({
				Size = Vector3.new(0.6, 0.05, 8),
				Position = Vector3.new(0, 0.22, z),
				Color = Color3.fromRGB(240, 220, 90),
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
			})
		end
	end
	-- Sidewalks (raised 0.4; humanoids step up automatically)
	for _, sx in { -1, 1 } do
		prop({
			Name = "Sidewalk",
			Size = Vector3.new(6, 0.4, 132),
			Position = Vector3.new(sx * 15, 0.2, -74),
			Color = CONCRETE,
			Material = Enum.Material.Concrete,
			CanQuery = true,
		})
		prop({
			Name = "Sidewalk",
			Size = Vector3.new(6, 0.4, roadEndZ - 28),
			Position = Vector3.new(sx * 15, 0.2, (roadEndZ + 28) / 2),
			Color = CONCRETE,
			Material = Enum.Material.Concrete,
			CanQuery = true,
		})
		prop({
			Name = "Sidewalk",
			Size = Vector3.new(192, 0.4, 6),
			Position = Vector3.new(sx * 114, 0.2, -5),
			Color = CONCRETE,
			Material = Enum.Material.Concrete,
			CanQuery = true,
		})
		prop({
			Name = "Sidewalk",
			Size = Vector3.new(192, 0.4, 6),
			Position = Vector3.new(sx * 114, 0.2, 25),
			Color = CONCRETE,
			Material = Enum.Material.Concrete,
			CanQuery = true,
		})
	end
	-- Crosswalks at the junction
	for i = -2, 2 do
		for _, z in { -5, 25 } do
			prop({
				Size = Vector3.new(1.4, 0.05, 5),
				Position = Vector3.new(i * 4, 0.22, z),
				Color = TRIM,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
			})
		end
		for _, x in { -15, 15 } do
			prop({
				Size = Vector3.new(5, 0.05, 1.4),
				Position = Vector3.new(x, 0.22, 10 + i * 4),
				Color = TRIM,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
			})
		end
	end
	for _, info in
		{
			{ Vector3.new(0, 30, -TOWN_HALF - 130), Vector3.new(TOWN_HALF * 2, 60, 1) },
			{ Vector3.new(0, 30, TOWN_HALF), Vector3.new(TOWN_HALF * 2, 60, 1) },
			{ Vector3.new(TOWN_HALF, 30, -65), Vector3.new(1, 60, TOWN_HALF * 2 + 130) },
			{ Vector3.new(-TOWN_HALF, 30, -65), Vector3.new(1, 60, TOWN_HALF * 2 + 130) },
		}
	do
		part({ Name = "Boundary", Position = info[1], Size = info[2], Transparency = 1, CanQuery = false })
	end

	-- Scrapyard plateau (safe hub) + ramp
	local plateauTop = PLATEAU_HEIGHT
	part({
		Name = "Plateau",
		Size = PLATEAU_SIZE,
		Position = PLATEAU_CENTER + Vector3.new(0, PLATEAU_HEIGHT / 2, 0),
		Color = Color3.fromRGB(110, 100, 90),
		Material = Enum.Material.Rock,
	})
	part({
		Name = "NorthGround",
		Size = Vector3.new(TOWN_HALF * 2, 4, 135),
		Position = Vector3.new(0, -2, -TOWN_HALF - 67.5),
		Color = Color3.fromRGB(110, 100, 90),
		Material = Enum.Material.Rock,
	})
	local rampLength = 80
	local rampStartZ = PLATEAU_CENTER.Z + PLATEAU_SIZE.Z / 2 -- plateau front edge
	local ramp = Instance.new("WedgePart")
	ramp.Name = "Ramp"
	ramp.Anchored = true
	ramp.Size = Vector3.new(24, PLATEAU_HEIGHT, rampLength)
	-- A wedge's tall end is at +Z; rotating 180 puts it against the plateau (-Z).
	ramp.CFrame = CFrame.new(0, PLATEAU_HEIGHT / 2, rampStartZ + rampLength / 2)
		* CFrame.Angles(0, math.rad(180), 0)
	ramp.Color = ASPHALT
	ramp.Material = Enum.Material.Asphalt
	ramp.Parent = map
	-- Fill under the ramp's sides so nobody gets stuck
	for _, sx in { -1, 1 } do
		part({
			Size = Vector3.new(1, 4, rampLength),
			Position = Vector3.new(sx * 12.5, 0, rampStartZ + rampLength / 2),
			Transparency = 1,
		})
	end
	-- Side stairs, a second route up
	for i = 0, PLATEAU_HEIGHT - 1 do
		part({
			Name = "Stair",
			Size = Vector3.new(12, i + 1, 2),
			Position = Vector3.new(-70, (i + 1) / 2, rampStartZ + 1 + 2 * (PLATEAU_HEIGHT - 1 - i)),
			Color = Color3.fromRGB(130, 120, 110),
			Material = Enum.Material.Concrete,
		})
	end

	-- Scrapyard contents
	local yard = Instance.new("Model")
	yard.Name = "Scrapyard"
	yard.Parent = map
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	-- Rotated so players spawn facing south, toward the town and the sell/shop counters.
	spawn.CFrame = CFrame.new(PLATEAU_CENTER + Vector3.new(0, plateauTop + 0.5, -20))
		* CFrame.Angles(0, math.pi, 0)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(240, 170, 40)
	spawn.Material = Enum.Material.DiamondPlate
	spawn.Parent = yard

	-- The two counters face each other across the aisle from the spawn to the gate.
	local counterZ = PLATEAU_CENTER.Z + 10
	local sellPos = Vector3.new(-32, plateauTop + 2, counterZ)
	local shopPos = Vector3.new(32, plateauTop + 2, counterZ)
	local sellPart = part({
		Parent = yard,
		Name = "SellCounter",
		Size = Vector3.new(14, 4, 5),
		CFrame = CFrame.lookAt(sellPos, sellPos + Vector3.new(1, 0, 0)),
		Transparency = 1, -- prompt holder; the SellShack model draws the counter
		CanCollide = false,
	})
	local sellPrompt = Instance.new("ProximityPrompt")
	sellPrompt.Name = "SellPrompt"
	sellPrompt.ActionText = "Sell Salvage"
	sellPrompt.ObjectText = "Scrap Buyer"
	sellPrompt.MaxActivationDistance = 14
	sellPrompt.RequiresLineOfSight = false
	sellPrompt.Parent = sellPart

	local shopPart = part({
		Parent = yard,
		Name = "UpgradeShop",
		Size = Vector3.new(14, 4, 5),
		CFrame = CFrame.lookAt(shopPos, shopPos - Vector3.new(1, 0, 0)),
		Transparency = 1, -- prompt holder; the GearShack model draws the counter
		CanCollide = false,
	})
	local shopPrompt = Instance.new("ProximityPrompt")
	shopPrompt.Name = "UpgradePrompt"
	shopPrompt.ActionText = "Upgrades"
	shopPrompt.ObjectText = "Gear Shop"
	shopPrompt.MaxActivationDistance = 14
	shopPrompt.RequiresLineOfSight = false
	shopPrompt.Parent = shopPart

	for x = -80, 80, 8 do
		if math.abs(x) > 14 and math.abs(x + 70) > 10 then
			prop({
				Parent = yard,
				Size = Vector3.new(8, 4, 0.4),
				Position = Vector3.new(x, plateauTop + 2, rampStartZ - 1),
				Color = Color3.fromRGB(150, 150, 150),
				Material = Enum.Material.DiamondPlate,
				Transparency = 0.2,
				CanCollide = true,
			})
		end
	end
	buildScrapyard(yard, sellPart, shopPart, rampStartZ)

	-- Town buildings
	local zones = {}
	local wallWood = Enum.Material.WoodPlanks
	local brick = Enum.Material.Brick
	local concrete = Enum.Material.Concrete

	local housePoints = {}
	local houseColors = {
		Palette.Swatches.Mustard,
		Palette.Swatches.Cobalt,
		Palette.Swatches.Coral,
		Palette.Swatches.Teal,
	}
	local roofColors = {
		Palette.Swatches.RoofRed,
		Palette.Swatches.RoofSlate,
		Palette.Swatches.RoofBrown,
		Palette.Swatches.RoofRed,
	}
	local housePositions = {
		Vector3.new(-150, 0, 55),
		Vector3.new(-95, 0, 55),
		Vector3.new(-150, 0, 120),
		Vector3.new(-95, 0, 120),
	}
	for i, pos in housePositions do
		local pts = building(
			"House " .. i,
			pos,
			Vector3.new(30, 12, 28),
			houseColors[i],
			wallWood,
			"N",
			roofColors[i],
			true, -- ladder: flood escape onto the roof
			{
				Gable = i % 2 == 1 and 7 or 6, -- ridge heights of HouseA / HouseB in build_town.py
				Label = false,
				Shell = {
					Name = i % 2 == 1 and "HouseA" or "HouseB",
					Porch = i % 2 == 1 and 17 or 32, -- porch roof widths in build_town.py
					Wall = houseColors[i],
					Roof = roofColors[i],
					Interior = true,
				},
				LootMargin = 6,
			}
		)
		for _, p in pts do
			table.insert(housePoints, p)
		end
		-- Front path, mailbox, and a couple of bushes
		local frontZ = pos.Z - 14
		local pathEnd = i <= 2 and 28 or 72
		prop({
			Size = Vector3.new(5, 0.3, frontZ - pathEnd),
			Position = Vector3.new(pos.X, 0.15, (frontZ + pathEnd) / 2),
			Color = CONCRETE,
			Material = Enum.Material.Concrete,
		})
		local town = assetRoot and assetRoot:FindFirstChild("town")
		if town then
			placeAsset(
				"town",
				"Mailbox",
				facing(Vector3.new(pos.X + 5, 0, pathEnd + 3), Vector3.new(0, 0, -1)),
				map
			)
			-- Picket fence along the front yard, with a gap for the path.
			local fenceZ = pathEnd + 4
			for _, x in { -16.5, -7.5, 7.5, 16.5 } do
				local fence = placeAsset("town", "PicketFence", CFrame.new(pos.X + x, 0, fenceZ), map)
				if fence and (i * 7 + x) % 3 < 1 then
					-- One leaning, storm-battered section per yard or so.
					fence:PivotTo(fence:GetPivot() * CFrame.Angles(math.rad(-14), 0, 0))
				end
			end
			placeAsset("town", "BushRound", CFrame.new(pos.X - 10, 0, frontZ - 6.5), map)
			placeAsset(
				"town",
				"BushRound",
				CFrame.new(pos.X + 10, 0, frontZ - 6.5) * CFrame.Angles(0, 2, 0),
				map
			)
			placeAsset("town", "TrashCan", CFrame.new(pos.X + 18, 0, pos.Z + 8), map)
		else
			bush(Vector3.new(pos.X - 10, 0, frontZ - 2), 4)
			bush(Vector3.new(pos.X + 10, 0, frontZ - 2), 3.5)
		end
	end
	-- Lane between the two rows of houses, joining the main road sidewalk.
	prop({
		Name = "Lane",
		Size = Vector3.new(165, 0.3, 6),
		Position = Vector3.new(-94.5, 0.15, 72),
		Color = Color3.fromRGB(150, 140, 120),
		Material = Enum.Material.Pebble,
	})
	local houseLabel = prop({
		Name = "HousesLabel",
		Size = Vector3.one,
		Position = Vector3.new(-122, 22, 88),
		Transparency = 1,
		CanCollide = false,
	})
	sign(houseLabel, "Houses", Color3.new(1, 1, 1), 0, 180)
	zones.Houses = { Points = housePoints, Label = "Houses" }

	zones.Warehouse = {
		Points = building(
			"Warehouse",
			Vector3.new(125, 0, 90),
			Vector3.new(70, 22, 60),
			Color3.fromRGB(150, 120, 90),
			concrete,
			"N",
			Color3.fromRGB(80, 80, 85),
			true,
			{
				Sign = "WAREHOUSE 7",
				SignColor = Color3.fromRGB(45, 60, 85),
				Parapet = true,
				Shell = {
					Set = "districts",
					Name = "WarehouseShell",
					SignText = "WAREHOUSE 7",
					SignColor = Palette.Swatches.SafetyYellow,
				},
			}
		),
		Label = "Warehouse",
	}
	zones.GasStation = {
		Points = building(
			"Gas Station",
			Vector3.new(-120, 0, -80),
			Vector3.new(40, 14, 30),
			Color3.fromRGB(230, 230, 230),
			concrete,
			"S",
			Color3.fromRGB(200, 40, 40),
			true,
			{
				Sign = "FUEL & GO",
				SignColor = Color3.fromRGB(200, 40, 40),
				Parapet = true,
				Shell = {
					Set = "districts",
					Name = "GasStationShell",
					SignText = "FUEL & GO",
					SignColor = Palette.Swatches.White,
				},
			}
		),
		Label = "Gas Station",
	}
	zones.Supermarket = {
		Points = building(
			"Supermarket",
			Vector3.new(120, 0, -80),
			Vector3.new(70, 18, 50),
			Color3.fromRGB(200, 180, 140),
			brick,
			"S",
			Color3.fromRGB(60, 120, 60),
			true,
			{
				Sign = "SUPER SAVER",
				SignColor = Color3.fromRGB(50, 120, 60),
				SignTextColor = Color3.fromRGB(255, 240, 150),
				Parapet = true,
				Shell = {
					Set = "districts",
					Name = "SupermarketShell",
					SignText = "SUPER SAVER",
					SignColor = Palette.Swatches.Mustard,
				},
			}
		),
		Label = "Supermarket",
	}
	zones.Motel = {
		Points = building(
			"Motel",
			Vector3.new(0, 0, 165),
			Vector3.new(110, 14, 30),
			Color3.fromRGB(210, 150, 110),
			brick,
			"N",
			Color3.fromRGB(70, 90, 130),
			true,
			{
				Sign = "STARLITE MOTEL",
				SignColor = Color3.fromRGB(70, 90, 130),
				SignTextColor = Color3.fromRGB(255, 120, 160),
				Awning = true,
				LootMargin = 5, -- keeps the back loot row clear of the dressers
				Shell = {
					Set = "districts",
					Name = "MotelShell",
					SignText = "STARLITE MOTEL",
					SignColor = Palette.Swatches.NeonPink,
				},
			}
		),
		Label = "Motel",
	}

	-- Gas station canopy + pumps + forecourt + price sign
	prop({
		Name = "Forecourt",
		Size = Vector3.new(44, 0.3, 30),
		Position = Vector3.new(-120, 0.15, -47),
		Color = CONCRETE,
		Material = Enum.Material.Concrete,
		CanQuery = true,
	})
	local canopy = part({
		Name = "Canopy",
		Size = Vector3.new(36, 1, 20),
		Position = Vector3.new(-120, 12, -45),
		Color = Color3.fromRGB(200, 40, 40),
		Material = Enum.Material.Metal,
	})
	canopy.Parent = roofs
	CollectionService:AddTag(canopy, "Shelter")
	prop({
		Name = "CanopyTrim",
		Size = Vector3.new(36.4, 0.4, 20.4),
		Position = Vector3.new(-120, 11.3, -45),
		Color = TRIM,
		Material = Enum.Material.Neon,
		Transparency = 0.3,
	})
	for _, x in { -135, -105 } do
		part({
			Name = "CanopyColumn",
			Size = Vector3.new(1, 12, 1),
			Position = Vector3.new(x, 6, -45),
			Color = Color3.fromRGB(220, 220, 220),
			Material = Enum.Material.Metal,
		})
		part({
			Name = "PumpBlock",
			Size = Vector3.new(2, 4, 1.5),
			Position = Vector3.new(x + 7, 2, -45),
			Color = Color3.fromRGB(240, 200, 40),
			Material = Enum.Material.SmoothPlastic,
		})
	end
	prop({
		Name = "PriceSignPole",
		Size = Vector3.new(1, 18, 1),
		Position = Vector3.new(-146, 9, -30),
		Color = Color3.fromRGB(70, 70, 75),
		Material = Enum.Material.Metal,
		CastShadow = true,
	})
	local priceSign = prop({
		Name = "PriceSign",
		Size = Vector3.new(8, 6, 0.6),
		Position = Vector3.new(-146, 20, -30),
		Color = Color3.fromRGB(200, 40, 40),
		Material = Enum.Material.SmoothPlastic,
		CastShadow = true,
	})
	surfaceSign(priceSign, Enum.NormalId.Back, "GAS\n$3.99", Color3.new(1, 1, 1))
	surfaceSign(priceSign, Enum.NormalId.Front, "GAS\n$3.99", Color3.new(1, 1, 1))
	car(Vector3.new(-150, 0, -15), Color3.fromRGB(40, 90, 160), 90)
	car(Vector3.new(-170, 0, -120), Color3.fromRGB(220, 200, 60), 10)
	car(Vector3.new(160, 0, 140), Color3.fromRGB(80, 80, 80), 0)

	-- Supermarket parking lot
	prop({
		Name = "ParkingLot",
		Size = Vector3.new(70, 0.25, 34),
		Position = Vector3.new(120, 0.12, -36),
		Color = ASPHALT,
		Material = Enum.Material.Asphalt,
		CanQuery = true,
	})
	for x = 88, 152, 8 do
		prop({
			Size = Vector3.new(0.4, 0.05, 10),
			Position = Vector3.new(x, 0.27, -40),
			Color = TRIM,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
	end
	car(Vector3.new(100, 0.25, -40), Color3.fromRGB(200, 60, 60), 0)
	car(Vector3.new(132, 0.25, -40), Color3.fromRGB(230, 230, 235), 180)

	-- Supermarket shelves (against side walls, outside the loot grid)
	for _, sx in { -1, 1 } do
		part({
			Name = "SideShelf",
			Size = Vector3.new(2, 6, 40),
			Position = Vector3.new(120 + sx * 32.5, 4, -80),
			Color = Color3.fromRGB(220, 220, 220),
			Material = Enum.Material.Metal,
		})
	end

	-- Warehouse yard: stacked shipping containers and pallets
	local containerColors =
		{ Color3.fromRGB(170, 70, 45), Color3.fromRGB(40, 95, 130), Color3.fromRGB(60, 120, 80) }
	for i, info in
		{
			{ Vector3.new(182, 4.25, 70), 0 },
			{ Vector3.new(182, 4.25, 96), 0 },
			{ Vector3.new(182, 12.75, 83), 8 },
		}
	do
		part({
			Name = "Container",
			Size = Vector3.new(8, 8.5, 20),
			CFrame = CFrame.new(info[1]) * CFrame.Angles(0, math.rad(info[2]), 0),
			Color = containerColors[i],
			Material = Enum.Material.CorrodedMetal,
		})
	end
	for _, pos in { Vector3.new(100, 0, 52), Vector3.new(104.5, 0, 51), Vector3.new(146, 0, 52) } do
		prop({
			Name = "YardCrate",
			Size = Vector3.new(4, 0.6, 4),
			Position = pos + Vector3.new(0, 0.3, 0),
			Color = Color3.fromRGB(160, 125, 85),
			Material = Enum.Material.WoodPlanks,
		})
		prop({
			Name = "YardCrate",
			Size = Vector3.new(3.4, 3, 3.4),
			Position = pos + Vector3.new(0, 2.1, 0),
			Color = Color3.fromRGB(175, 140, 95),
			Material = Enum.Material.WoodPlanks,
			CanCollide = true,
		})
	end

	-- Motel: neon pole sign
	prop({
		Name = "MotelSignPole",
		Size = Vector3.new(1.2, 24, 1.2),
		Position = Vector3.new(-64, 12, 142),
		Color = Color3.fromRGB(70, 70, 75),
		Material = Enum.Material.Metal,
		CastShadow = true,
	})
	local motelSign = prop({
		Name = "MotelSign",
		Size = Vector3.new(12, 6, 1),
		Position = Vector3.new(-64, 26, 142),
		Color = Color3.fromRGB(30, 35, 60),
		Material = Enum.Material.SmoothPlastic,
		CastShadow = true,
	})
	surfaceSign(motelSign, Enum.NormalId.Front, "MOTEL\nVACANCY", Color3.fromRGB(255, 110, 160))
	surfaceSign(motelSign, Enum.NormalId.Back, "MOTEL\nVACANCY", Color3.fromRGB(255, 110, 160))
	prop({
		Name = "MotelSignGlow",
		Size = Vector3.new(12.4, 6.4, 0.6),
		Position = Vector3.new(-64, 26, 142),
		Color = Color3.fromRGB(255, 110, 160),
		Material = Enum.Material.Neon,
		Transparency = 0.4,
	})

	-- Town square: open plaza with a fountain (no shelter = risky)
	part({
		Name = "Plaza",
		Size = Vector3.new(60, 0.4, 60),
		Position = Vector3.new(-50, 0.2, -55),
		Color = Color3.fromRGB(190, 180, 165),
		Material = Enum.Material.Cobblestone,
	})
	part({
		Name = "Fountain",
		Size = Vector3.new(3, 14, 14),
		Position = Vector3.new(-50, 1.5, -55),
		Shape = Enum.PartType.Cylinder,
		Orientation = Vector3.new(0, 0, 90),
		Color = Color3.fromRGB(160, 160, 170),
		Material = Enum.Material.Marble,
	})
	local fountainWater = part({
		Name = "FountainWater",
		Size = Vector3.new(1, 12, 12),
		Position = Vector3.new(-50, 3.2, -55),
		Shape = Enum.PartType.Cylinder,
		Orientation = Vector3.new(0, 0, 90),
		Color = Color3.fromRGB(80, 160, 230),
		Material = Enum.Material.Glass,
		Transparency = 0.3,
		CanCollide = false,
	})
	prop({
		Name = "FountainColumn",
		Size = Vector3.new(6, 1.6, 1.6),
		Position = Vector3.new(-50, 6, -55),
		Shape = Enum.PartType.Cylinder,
		Orientation = Vector3.new(0, 0, 90),
		Color = Color3.fromRGB(150, 150, 160),
		Material = Enum.Material.Marble,
	})
	local spray = Instance.new("ParticleEmitter")
	spray.Rate = 40
	spray.Lifetime = NumberRange.new(0.8, 1.1)
	spray.Speed = NumberRange.new(12, 15)
	spray.SpreadAngle = Vector2.new(12, 12)
	spray.Acceleration = Vector3.new(0, -30, 0)
	spray.Size = NumberSequence.new(0.5, 0.2)
	spray.Transparency = NumberSequence.new(0.3, 1)
	spray.Color = ColorSequence.new(Color3.fromRGB(200, 230, 255))
	spray.Parent = fountainWater
	sign(fountainWater, "Town Square", Color3.fromRGB(255, 255, 255), 10, 180)
	local squarePoints = {}
	for x = -75, -25, 10 do
		for z = -80, -30, 10 do
			if (Vector3.new(x, 0, z) - Vector3.new(-50, 0, -55)).Magnitude > 12 then
				table.insert(squarePoints, Vector3.new(x, 1.9, z)) -- floor = point - 1.5 = plaza top
			end
		end
	end
	zones.TownSquare = { Points = squarePoints, Label = "Town Square" }
	-- Benches on the plaza edge, outside the loot grid
	for _, info in
		{
			{ Vector3.new(-62, 0, -23), 0 },
			{ Vector3.new(-38, 0, -23), 0 },
			{ Vector3.new(-82, 0, -45), 90 },
			{ Vector3.new(-82, 0, -65), 90 },
		}
	do
		local cf = CFrame.new(info[1]) * CFrame.Angles(0, math.rad(info[2]), 0)
		if townAsset("Bench", cf) then
			continue
		end
		prop({
			Size = Vector3.new(6, 0.4, 1.8),
			CFrame = cf * CFrame.new(0, 1.5, 0),
			Color = Color3.fromRGB(130, 90, 60),
			Material = Enum.Material.Wood,
			CanCollide = true,
		})
		prop({
			Size = Vector3.new(6, 1.6, 0.3),
			CFrame = cf * CFrame.new(0, 2.4, 0.8),
			Color = Color3.fromRGB(130, 90, 60),
			Material = Enum.Material.Wood,
		})
		prop({
			Size = Vector3.new(5.6, 1.3, 1.2),
			CFrame = cf * CFrame.new(0, 0.65, 0),
			Color = Color3.fromRGB(50, 50, 55),
			Material = Enum.Material.Metal,
		})
	end
	-- Storm siren tower: the town's landmark, and where warnings come from.
	local sirenBase = Vector3.new(-92, 0, -40)
	prop({
		Name = "SirenBase",
		Size = Vector3.new(4, 1, 4),
		Position = sirenBase + Vector3.new(0, 0.5, 0),
		Color = CONCRETE,
		Material = Enum.Material.Concrete,
		CanCollide = true,
	})
	prop({
		Name = "SirenPole",
		Size = Vector3.new(1.2, 30, 1.2),
		Position = sirenBase + Vector3.new(0, 15, 0),
		Color = Color3.fromRGB(120, 120, 125),
		Material = Enum.Material.Metal,
		CanCollide = true,
		CastShadow = true,
	})
	local sirenHead = prop({
		Name = "Siren",
		Size = Vector3.new(3, 3, 3),
		Position = sirenBase + Vector3.new(0, 31, 0),
		Color = Color3.fromRGB(200, 50, 40),
		Material = Enum.Material.Metal,
		CastShadow = true,
	})
	for _, dir in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0) } do
		prop({
			Name = "SirenHorn",
			Size = Vector3.new(3, 2.4, 2.4),
			Position = sirenHead.Position + dir * 2.6,
			Shape = Enum.PartType.Cylinder,
			Color = Color3.fromRGB(180, 180, 185),
			Material = Enum.Material.Metal,
		})
	end
	sirenHead:SetAttribute("SirenLight", true)

	-- Dressing
	for _, pos in
		{
			Vector3.new(-30, 0, 60),
			Vector3.new(30, 0, 60),
			Vector3.new(-30, 0, 130),
			Vector3.new(40, 0, 120),
			Vector3.new(-185, 0, -150),
			Vector3.new(185, 0, -150),
			Vector3.new(-185, 0, 185),
			Vector3.new(185, 0, 185),
			Vector3.new(-90, 0, -150),
			Vector3.new(80, 0, -160),
			Vector3.new(-20, 0, -110),
			Vector3.new(30, 0, -120),
			Vector3.new(-185, 0, 40),
			Vector3.new(-185, 0, 140),
			Vector3.new(70, 0, 40),
			Vector3.new(196, 0, 48),
			Vector3.new(-120, 0, 180),
			Vector3.new(120, 0, 185),
			Vector3.new(-150, 0, -185),
			Vector3.new(150, 0, -130),
		}
	do
		tree(pos)
	end
	for _, pos in
		{
			Vector3.new(-25, 0, 40),
			Vector3.new(25, 0, 45),
			Vector3.new(60, 0, 130),
			Vector3.new(-60, 0, 120),
			Vector3.new(-165, 0, -40),
			Vector3.new(165, 0, -10),
			Vector3.new(-20, 0, -150),
		}
	do
		bush(pos, 4)
	end
	for z = -135, 90, 45 do
		streetLight(Vector3.new(14, 0, z), Vector3.new(-1, 0, 0))
		streetLight(Vector3.new(-14, 0, z + 22), Vector3.new(1, 0, 0))
	end
	-- Power lines along the cross road
	local previous: Vector3? = nil
	for _, x in { -190, -170, -130, -90, -50, 50, 90, 130, 170, 190 } do
		local top = powerPole(Vector3.new(x, 0, 30))
		if previous and math.abs(previous.X - x) <= 45 then
			wire(previous + Vector3.new(0, 0, 2.5), top + Vector3.new(0, 0, 2.5))
			wire(previous - Vector3.new(0, 0, 2.5), top - Vector3.new(0, 0, 2.5))
		end
		previous = top
	end

	-- Street furniture and storm damage (Blender kit only).
	if assetRoot and assetRoot:FindFirstChild("town") then
		for _, info in
			{
				{ "StopSign", Vector3.new(20, 0, -9), Vector3.new(0, 0, 1) },
				{ "StopSign", Vector3.new(-20, 0, 29), Vector3.new(0, 0, -1) },
				{ "Hydrant", Vector3.new(-20, 0, 33), nil },
				{ "Hydrant", Vector3.new(-122, 0, 30), nil },
				{ "Hydrant", Vector3.new(20, 0, -13), nil },
				{ "TrashCan", Vector3.new(-20, 0, -16), nil },
				{ "TrashCan", Vector3.new(-84, 0, -30), nil },
				{ "Planter", Vector3.new(-62, 0, -89), Vector3.new(0, 0, -1) },
				{ "Planter", Vector3.new(-38, 0, -89), Vector3.new(0, 0, -1) },
				-- The houses took the last storm hardest: branches, sheet metal, a closed lane.
				{ "DebrisBranch", Vector3.new(-122, 0, 46), Vector3.new(1, 0, 0.4) },
				{ "DebrisBranch", Vector3.new(-176, 0, 95), Vector3.new(0.3, 0, 1) },
				{ "DebrisSheet", Vector3.new(-128, 0, 100), Vector3.new(-1, 0, 0.2) },
				{ "DebrisSheet", Vector3.new(-60, 0, 36), Vector3.new(0.5, 0, -1) },
				{ "Barrier", Vector3.new(-178, 0, 72), Vector3.new(1, 0, 0) },
				{ "Cone", Vector3.new(-174, 0, 68), nil },
				{ "Cone", Vector3.new(-174, 0, 76), nil },
			}
		do
			local dir = info[3] or Vector3.new(math.cos(#info[1]), 0, math.sin(#info[1]))
			townAsset(info[1], facing(info[2], dir))
		end
	end

	upgradeDistricts()

	return {
		Zones = zones,
		Roofs = roofs,
		SellPrompt = sellPrompt,
		SpawnPosition = spawn.Position,
		TownMin = Vector3.new(-TOWN_HALF + 5, 0, -TOWN_HALF + 5),
		TownMax = Vector3.new(TOWN_HALF - 5, 0, TOWN_HALF - 5),
		FloodMaxY = 12,
		SafeZoneZ = Config.SafeZoneMaxZ, -- plateau front edge is at rampStartZ (-220)
	}
end

return MapBuilder
