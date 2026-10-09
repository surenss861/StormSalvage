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

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

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

	-- Windows on the side walls (cosmetic)
	for _, sx in { -1, 1 } do
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
	local face = FACES[doorFace]
	local faceWidth = face.Tangent.X ~= 0 and w or d
	local halfDepth = face.Tangent.X ~= 0 and d / 2 or w / 2
	local function onFace(along: number, y: number, out: number): Vector3
		return center + face.Tangent * along + face.Normal * (halfDepth + out) + Vector3.new(0, y, 0)
	end
	local function faceSize(width: number, height: number, thickness: number): Vector3
		return face.Tangent.X ~= 0 and Vector3.new(width, height, thickness)
			or Vector3.new(thickness, height, width)
	end
	for _, s in { -1, 1 } do
		prop({
			Parent = model,
			Size = faceSize(0.8, 9.6, 0.6),
			Position = onFace(s * 4.4, 4.8, 0.4),
			Color = trim,
			Material = Enum.Material.SmoothPlastic,
		})
	end
	prop({
		Parent = model,
		Size = faceSize(9.6, 0.8, 0.6),
		Position = onFace(0, 9.4, 0.4),
		Color = trim,
		Material = Enum.Material.SmoothPlastic,
	})
	if faceWidth >= 26 then
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
	if o.Sign then
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
		for along = -faceWidth / 2 + 2, faceWidth / 2 - 2, 15 do
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

	if o.Gable then
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
	if o.Parapet then
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
	local margin = 4
	for x = -w / 2 + margin, w / 2 - margin, 7 do
		for z = -d / 2 + margin, d / 2 - margin, 7 do
			table.insert(points, center + Vector3.new(x, 2.5, z))
		end
	end
	return points
end

local treeRng = Random.new(11)
local function tree(pos: Vector3)
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
	prop({
		Size = Vector3.new(s, s * 0.7, s),
		Position = pos + Vector3.new(0, s * 0.3, 0),
		Shape = Enum.PartType.Ball,
		Color = Color3.fromRGB(70, 125, 60),
		Material = Enum.Material.Grass,
		CanCollide = false,
	})
end

local function streetLight(pos: Vector3)
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

-- A corrugated shack behind a counter. The counter's front (-Z of its CFrame) faces the aisle.
local function shack(parent: Instance, counter: BasePart, color: Color3, title: string, titleColor: Color3)
	local frame = counter.CFrame - Vector3.new(0, counter.Size.Y / 2, 0) -- counter base, on the ground
	local function at(x: number, y: number, z: number): CFrame
		return frame * CFrame.new(x, y, z)
	end
	part({
		Parent = parent,
		Size = Vector3.new(18, 10, 0.6),
		CFrame = at(0, 5, 11),
		Color = color,
		Material = Enum.Material.CorrodedMetal,
	})
	for _, s in { -1, 1 } do
		part({
			Parent = parent,
			Size = Vector3.new(0.6, 10, 9),
			CFrame = at(s * 9, 5, 6.5),
			Color = color,
			Material = Enum.Material.CorrodedMetal,
		})
		prop({
			Parent = parent,
			Size = Vector3.new(0.5, 10, 0.5),
			CFrame = at(s * 9.5, 5, -2.5),
			Color = Color3.fromRGB(70, 70, 75),
			Material = Enum.Material.Metal,
		})
	end
	-- Roof runs out over the counter as an awning.
	part({
		Parent = parent,
		Size = Vector3.new(20, 0.6, 15),
		CFrame = at(0, 10.3, 4),
		Color = Color3.fromRGB(80, 80, 86),
		Material = Enum.Material.CorrodedMetal,
	})
	prop({
		Parent = parent,
		Size = Vector3.new(20, 0.3, 0.3),
		CFrame = at(0, 9.9, -3.4),
		Color = titleColor,
		Material = Enum.Material.Neon,
	})
	local board = prop({
		Parent = parent,
		Size = Vector3.new(16, 3.2, 0.5),
		CFrame = at(0, 12.3, -2),
		Color = Color3.fromRGB(30, 32, 38),
		Material = Enum.Material.SmoothPlastic,
	})
	surfaceSign(board, Enum.NormalId.Front, title, titleColor)
	local lamp = prop({
		Parent = parent,
		Size = Vector3.new(1, 0.6, 1),
		CFrame = at(0, 9.6, 3),
		Color = Color3.fromRGB(255, 240, 200),
		Material = Enum.Material.Neon,
	})
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Color = titleColor
	light.Brightness = 1.2
	light.Parent = lamp
end

local function scrapPile(parent: Instance, center: Vector3, radius: number)
	local rust = {
		Color3.fromRGB(125, 72, 50),
		Color3.fromRGB(95, 85, 80),
		Color3.fromRGB(140, 110, 70),
		Color3.fromRGB(70, 75, 85),
	}
	for i = 1, 7 do
		local s = yardRng:NextNumber(3, 7) * (i == 1 and 1.6 or 1)
		local offset = Vector3.new(
			yardRng:NextNumber(-radius, radius),
			s * 0.3,
			yardRng:NextNumber(-radius, radius) * 0.6
		)
		prop({
			Parent = parent,
			Size = Vector3.new(s, s * 0.7, s * 1.3),
			CFrame = CFrame.new(center + offset) * CFrame.Angles(
				yardRng:NextNumber(-0.4, 0.4),
				yardRng:NextNumber(0, 6.28),
				yardRng:NextNumber(-0.4, 0.4)
			),
			Color = rust[yardRng:NextInteger(1, #rust)],
			Material = i % 3 == 0 and Enum.Material.DiamondPlate or Enum.Material.CorrodedMetal,
			CastShadow = true,
		})
	end
	for _ = 1, 2 do
		prop({
			Parent = parent,
			Size = Vector3.new(1, 3, 3),
			CFrame = CFrame.new(center + Vector3.new(yardRng:NextNumber(-radius, radius), 1.5, radius * 0.7))
				* CFrame.Angles(0, yardRng:NextNumber(0, 6.28), yardRng:NextNumber(-0.3, 0.3)),
			Shape = Enum.PartType.Cylinder,
			Color = Color3.fromRGB(30, 30, 32),
			Material = Enum.Material.Rubber,
		})
	end
end

local function buildScrapyard(yard: Model, sellPart: BasePart, shopPart: BasePart, rampStartZ: number)
	local top = PLATEAU_HEIGHT
	prop({
		Parent = yard,
		Name = "YardFloor",
		Size = Vector3.new(PLATEAU_SIZE.X, 0.2, PLATEAU_SIZE.Z),
		Position = PLATEAU_CENTER + Vector3.new(0, top + 0.1, 0),
		Color = Color3.fromRGB(122, 108, 92),
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

	shack(yard, sellPart, Color3.fromRGB(70, 130, 80), "SCRAP BUYER", Color3.fromRGB(120, 255, 140))
	shack(yard, shopPart, Color3.fromRGB(60, 100, 170), "GEAR SHOP", Color3.fromRGB(140, 200, 255))

	-- Corrugated fence on the three outer edges.
	local fenceColors =
		{ Color3.fromRGB(120, 85, 65), Color3.fromRGB(105, 100, 95), Color3.fromRGB(135, 100, 70) }
	local minX, maxX = -PLATEAU_SIZE.X / 2 + 1, PLATEAU_SIZE.X / 2 - 1
	local minZ = PLATEAU_CENTER.Z - PLATEAU_SIZE.Z / 2 + 1
	local i = 0
	for x = minX + 5, maxX - 5, 10 do
		i += 1
		prop({
			Parent = yard,
			Size = Vector3.new(10, 9 + (i % 2), 0.5),
			Position = Vector3.new(x, top + 4.5, minZ),
			Color = fenceColors[i % 3 + 1],
			Material = Enum.Material.CorrodedMetal,
			CanCollide = true,
		})
	end
	for _, x in { minX, maxX } do
		for z = minZ + 5, rampStartZ - 6, 10 do
			i += 1
			prop({
				Parent = yard,
				Size = Vector3.new(0.5, 9 + (i % 2), 10),
				Position = Vector3.new(x, top + 4.5, z),
				Color = fenceColors[i % 3 + 1],
				Material = Enum.Material.CorrodedMetal,
				CanCollide = true,
			})
		end
	end

	-- Scrap mountains along the back fence (the spawn faces away from them, toward town).
	for _, x in { -65, -40, 35, 62 } do
		scrapPile(yard, Vector3.new(x, top, minZ + 9), 8)
	end

	-- Crushed-car stack
	local carColors =
		{ Color3.fromRGB(150, 60, 45), Color3.fromRGB(70, 95, 130), Color3.fromRGB(200, 170, 70) }
	for level = 0, 2 do
		prop({
			Parent = yard,
			Size = Vector3.new(6, 1.8, 11),
			CFrame = CFrame.new(-62, top + 0.9 + level * 1.8, -285)
				* CFrame.Angles(0, math.rad(level * 9 - 9), 0),
			Color = carColors[level + 1],
			Material = Enum.Material.CorrodedMetal,
			CanCollide = true,
			CastShadow = true,
		})
	end

	-- Oil drums by the counters
	for _, offset in
		{
			Vector3.new(-36, 0, -248),
			Vector3.new(-38.5, 0, -246),
			Vector3.new(36, 0, -248),
			Vector3.new(38.5, 0, -250),
		}
	do
		prop({
			Parent = yard,
			Size = Vector3.new(3.6, 2.4, 2.4),
			Position = Vector3.new(offset.X, top + 1.8, offset.Z),
			Orientation = Vector3.new(0, 0, 90),
			Shape = Enum.PartType.Cylinder,
			Color = yardRng:NextNumber() < 0.5 and Color3.fromRGB(40, 90, 150) or Color3.fromRGB(170, 60, 40),
			Material = Enum.Material.Metal,
			CanCollide = true,
		})
	end

	-- Crane: the landmark you can see from anywhere in town.
	local craneBase = Vector3.new(58, top, -300)
	local tower = Instance.new("TrussPart")
	tower.Anchored = true
	tower.Size = Vector3.new(4, 56, 4)
	tower.Position = craneBase + Vector3.new(0, 28, 0)
	tower.Color = Color3.fromRGB(230, 170, 30)
	tower.Parent = yard
	prop({
		Parent = yard,
		Size = Vector3.new(6, 5, 6),
		Position = craneBase + Vector3.new(0, 58.5, 0),
		Color = Color3.fromRGB(230, 170, 30),
		Material = Enum.Material.Metal,
		CastShadow = true,
	})
	-- Boom reaches out over the yard; its back end carries the counterweight.
	local towerTop = craneBase + Vector3.new(0, 56, 0)
	local reach = Vector3.new(-1, 0, 0.35).Unit
	local boomCenter = towerTop + reach * 14 + Vector3.new(0, 2, 0)
	local boom = Instance.new("TrussPart")
	boom.Anchored = true
	boom.Size = Vector3.new(2, 2, 46)
	boom.CFrame = CFrame.lookAt(boomCenter, boomCenter + reach)
	boom.Color = Color3.fromRGB(230, 170, 30)
	boom.CanQuery = false
	boom.Parent = yard
	local tip = boom.CFrame * Vector3.new(0, 0, -22)
	prop({
		Parent = yard,
		Size = Vector3.new(0.3, 22, 0.3),
		Position = tip - Vector3.new(0, 11, 0),
		Color = Color3.fromRGB(30, 30, 30),
		Material = Enum.Material.Metal,
		CanCollide = false,
	})
	prop({
		Parent = yard,
		Size = Vector3.new(1.5, 6, 6),
		Position = tip - Vector3.new(0, 22.5, 0),
		Orientation = Vector3.new(0, 0, 90),
		Shape = Enum.PartType.Cylinder,
		Color = Color3.fromRGB(60, 60, 65),
		Material = Enum.Material.DiamondPlate,
		CastShadow = true,
	})
	prop({
		Parent = yard,
		Size = Vector3.new(6, 4, 6),
		Position = boom.CFrame * Vector3.new(0, -1, 20),
		Color = Color3.fromRGB(80, 80, 85),
		Material = Enum.Material.Concrete,
	})

	-- Gate arch over the top of the ramp
	for _, s in { -1, 1 } do
		prop({
			Parent = yard,
			Size = Vector3.new(1.5, 16, 1.5),
			Position = Vector3.new(s * 13.5, top + 8, rampStartZ - 1.5),
			Color = Color3.fromRGB(70, 70, 75),
			Material = Enum.Material.Metal,
			CanCollide = true,
		})
	end
	local beam = prop({
		Parent = yard,
		Name = "GateSign",
		Size = Vector3.new(30, 4, 1),
		Position = Vector3.new(0, top + 17, rampStartZ - 1.5),
		Color = Color3.fromRGB(35, 35, 40),
		Material = Enum.Material.Metal,
		CastShadow = true,
	})
	surfaceSign(
		beam,
		Enum.NormalId.Back,
		"STORM SALVAGE YARD",
		Color3.fromRGB(255, 200, 60),
		Enum.Font.LuckiestGuy
	)
	surfaceSign(
		beam,
		Enum.NormalId.Front,
		"GOOD LUCK OUT THERE",
		Color3.fromRGB(255, 200, 60),
		Enum.Font.LuckiestGuy
	)
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
		Color = Color3.fromRGB(60, 170, 80),
		Material = Enum.Material.DiamondPlate,
	})
	local sellPrompt = Instance.new("ProximityPrompt")
	sellPrompt.Name = "SellPrompt"
	sellPrompt.ActionText = "Sell Salvage"
	sellPrompt.ObjectText = "Scrap Buyer"
	sellPrompt.MaxActivationDistance = 14
	sellPrompt.RequiresLineOfSight = false
	sellPrompt.Parent = sellPart
	sign(sellPart, "SELL HERE", Color3.fromRGB(120, 255, 140), 15, 2000)

	local shopPart = part({
		Parent = yard,
		Name = "UpgradeShop",
		Size = Vector3.new(14, 4, 5),
		CFrame = CFrame.lookAt(shopPos, shopPos - Vector3.new(1, 0, 0)),
		Color = Color3.fromRGB(60, 120, 200),
		Material = Enum.Material.DiamondPlate,
	})
	local shopPrompt = Instance.new("ProximityPrompt")
	shopPrompt.Name = "UpgradePrompt"
	shopPrompt.ActionText = "Upgrades"
	shopPrompt.ObjectText = "Gear Shop"
	shopPrompt.MaxActivationDistance = 14
	shopPrompt.RequiresLineOfSight = false
	shopPrompt.Parent = shopPart
	sign(shopPart, "UPGRADES", Color3.fromRGB(140, 200, 255), 15)

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
	car(PLATEAU_CENTER + Vector3.new(55, plateauTop, 25), Color3.fromRGB(160, 60, 40), 20)
	buildScrapyard(yard, sellPart, shopPart, rampStartZ)

	-- Town buildings
	local zones = {}
	local wallWood = Enum.Material.WoodPlanks
	local brick = Enum.Material.Brick
	local concrete = Enum.Material.Concrete

	local housePoints = {}
	local houseColors = {
		Color3.fromRGB(230, 200, 150),
		Color3.fromRGB(170, 200, 220),
		Color3.fromRGB(220, 160, 160),
		Color3.fromRGB(200, 220, 170),
	}
	local roofColors = {
		Color3.fromRGB(110, 60, 50),
		Color3.fromRGB(60, 70, 90),
		Color3.fromRGB(90, 85, 80),
		Color3.fromRGB(120, 75, 45),
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
			false,
			{ Gable = 6, Label = false }
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
		prop({
			Size = Vector3.new(0.4, 3.5, 0.4),
			Position = Vector3.new(pos.X + 5, 1.75, pathEnd + 2),
			Color = Color3.fromRGB(90, 70, 50),
			Material = Enum.Material.Wood,
		})
		prop({
			Size = Vector3.new(1.2, 1, 1.8),
			Position = Vector3.new(pos.X + 5, 3.9, pathEnd + 2),
			Color = Color3.fromRGB(60, 80, 140),
			Material = Enum.Material.Metal,
		})
		bush(Vector3.new(pos.X - 10, 0, frontZ - 2), 4)
		bush(Vector3.new(pos.X + 10, 0, frontZ - 2), 3.5)
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
			{ Sign = "WAREHOUSE 7", SignColor = Color3.fromRGB(45, 60, 85), Parapet = true }
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
			{ Sign = "FUEL & GO", SignColor = Color3.fromRGB(200, 40, 40), Parapet = true }
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
		Size = Vector3.new(36.4, 0.4, 20.4),
		Position = Vector3.new(-120, 11.3, -45),
		Color = TRIM,
		Material = Enum.Material.Neon,
		Transparency = 0.3,
	})
	for _, x in { -135, -105 } do
		part({
			Size = Vector3.new(1, 12, 1),
			Position = Vector3.new(x, 6, -45),
			Color = Color3.fromRGB(220, 220, 220),
			Material = Enum.Material.Metal,
		})
		part({
			Size = Vector3.new(2, 4, 1.5),
			Position = Vector3.new(x + 7, 2, -45),
			Color = Color3.fromRGB(240, 200, 40),
			Material = Enum.Material.SmoothPlastic,
		})
	end
	prop({
		Size = Vector3.new(1, 18, 1),
		Position = Vector3.new(-146, 9, -30),
		Color = Color3.fromRGB(70, 70, 75),
		Material = Enum.Material.Metal,
		CastShadow = true,
	})
	local priceSign = prop({
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
			Size = Vector3.new(4, 0.6, 4),
			Position = pos + Vector3.new(0, 0.3, 0),
			Color = Color3.fromRGB(160, 125, 85),
			Material = Enum.Material.WoodPlanks,
		})
		prop({
			Size = Vector3.new(3.4, 3, 3.4),
			Position = pos + Vector3.new(0, 2.1, 0),
			Color = Color3.fromRGB(175, 140, 95),
			Material = Enum.Material.WoodPlanks,
			CanCollide = true,
		})
	end

	-- Motel: neon pole sign
	prop({
		Size = Vector3.new(1.2, 24, 1.2),
		Position = Vector3.new(-64, 12, 142),
		Color = Color3.fromRGB(70, 70, 75),
		Material = Enum.Material.Metal,
		CastShadow = true,
	})
	local motelSign = prop({
		Size = Vector3.new(12, 6, 1),
		Position = Vector3.new(-64, 26, 142),
		Color = Color3.fromRGB(30, 35, 60),
		Material = Enum.Material.SmoothPlastic,
		CastShadow = true,
	})
	surfaceSign(motelSign, Enum.NormalId.Front, "MOTEL\nVACANCY", Color3.fromRGB(255, 110, 160))
	surfaceSign(motelSign, Enum.NormalId.Back, "MOTEL\nVACANCY", Color3.fromRGB(255, 110, 160))
	prop({
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
		Size = Vector3.new(4, 1, 4),
		Position = sirenBase + Vector3.new(0, 0.5, 0),
		Color = CONCRETE,
		Material = Enum.Material.Concrete,
		CanCollide = true,
	})
	prop({
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
		streetLight(Vector3.new(14, 0, z))
		streetLight(Vector3.new(-14, 0, z + 22))
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
