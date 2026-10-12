-- V3 Milestone C4: Warehouse 7 (SE of Town Square). Turns the V2 hall of identical pallet racks
-- into a logistics building with zones: receiving freight by the door, tall storage racks, a
-- high-value cage at the back, an equipment wall and an overhead crane, plus a working dock
-- outside with a freight truck backed up to it. See docs/art/V3-C4-WAREHOUSE.md.
--
-- Gameplay stays where MapBuilder put it: the invisible 70 x 60 x 22 walls and roof (shelter),
-- the door (-Z), the back truss (roof escape in floods), and the 9 x 8 loot grid. Every rack-row
-- piece takes an existing V2 rack's place (same 24 x 2 footprint, same rows between loot rows)
-- and gets one solid collider. Tall racks' colliders reach just under the roof, so a rack top can
-- never become a ledge above the 12-stud flood line. Everything comes from
-- ServerStorage.Assets.v3ware; without it the V2 warehouse stays as is.

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local Palette = require(game:GetService("ReplicatedStorage").Shared.Palette)

local DistrictWarehouse = {}

local S = Palette.Swatches
local HALL = Vector3.new(125, 0, 90) -- 70 x 60 x 22, door on -Z (z 60)
local FLOOR = 0.5

-- Rack rows (V2 PalletRack positions): which piece replaces each one.
local ROWS: { { z: number, west: string, east: string } } = {
	{ z = 67.5, west = "FreightStack", east = "FreightStack" }, -- receiving
	{ z = 81.5, west = "TallRackA", east = "TallRackB" }, -- storage
	{ z = 95.5, west = "TallRackB", east = "TallRackA" }, -- storage
	{ z = 109.5, west = "TallRackA", east = "MeshCage" }, -- high-value cage at the back
}
local COLLIDER_HEIGHT = { TallRackA = 21, TallRackB = 21, MeshCage = 8.1, FreightStack = 6.4 }

-- Only the big structural surfaces cast shadows inside (see DistrictSupermarket).
local SHADOW_KEEP: { [string]: { [string]: boolean } } = {
	TallRackA = { Metal__Cobalt = true, Metal__Coral = true },
	TallRackB = { Metal__Cobalt = true, Metal__Coral = true },
	FreightStack = { Planks__Bark = true },
	MeshCage = { Metal__Gunmetal = true },
}

type Context = {
	Map: Model,
	Part: (props: { [string]: any }) -> Part,
	Prop: (props: { [string]: any }) -> Part,
	SurfaceSign: (
		target: BasePart,
		face: Enum.NormalId,
		text: string,
		color: Color3,
		font: Enum.Font?
	) -> any,
}

local function source(set: string, name: string): Model?
	local assets = ServerStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild(set)
	local model = folder and folder:FindFirstChild(name)
	return if model and model:IsA("Model") then model else nil
end

local function place(set: string, name: string, cf: CFrame, parent: Instance): Model?
	local src = source(set, name)
	if not src then
		return nil
	end
	local model = src:Clone()
	model:PivotTo(cf)
	model.Parent = parent
	return model
end

local function meshWith(model: Model?, key: string): BasePart?
	if not model then
		return nil
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and string.find(d.Name, key, 1, true) then
			return d
		end
	end
	return nil
end

local function paint(model: Model?, face: Enum.NormalId, text: string, color: Color3, ctx: Context)
	local board = meshWith(model, "Signboard")
	if board then
		ctx.SurfaceSign(board, face, text, color, Enum.Font.LuckiestGuy)
	end
end

local function tagLamps(model: Model, key: string)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Material == Enum.Material.Neon and string.find(d.Name, key, 1, true) then
			d:SetAttribute("OnColor", d.Color)
			CollectionService:AddTag(d, "V3Lamp")
		end
	end
end

local function pointLight(part: BasePart, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Range = range
	light.Brightness = brightness
	light.Color = Color3.fromRGB(255, 210, 150)
	light.Shadows = false
	light.Parent = part
end

-- One invisible solid box over a rack-row piece's footprint; its meshes stop colliding.
local function solidify(model: Model, height: number, ctx: Context, parent: Instance)
	local cf, size = model:GetBoundingBox()
	local base = model:GetPivot().Position.Y
	ctx.Part({
		Parent = parent,
		Name = model.Name .. "Collider",
		Size = Vector3.new(size.X, height, size.Z),
		CFrame = CFrame.new(cf.Position.X, base + height / 2, cf.Position.Z),
		Transparency = 1,
		CastShadow = false,
	})
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
end

local function flat(ctx: Context, parent: Instance, size: Vector3, pos: Vector3, color: Color3)
	return ctx.Prop({
		Parent = parent,
		Size = size,
		Position = pos,
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		CastShadow = false,
	})
end

function DistrictWarehouse.build(ctx: Context)
	if not source("v3ware", "TallRackA") then
		return -- assets not imported yet: the V2 warehouse stays
	end
	local t0 = os.clock()
	local map = ctx.Map
	local folder = Instance.new("Folder")
	folder.Name = "V3Warehouse"
	folder.Parent = map

	-- Floor: sealed concrete instead of wood planks (same part, collision unchanged).
	local hall = map:FindFirstChild("Warehouse")
	local floor = hall and hall:FindFirstChild("Floor")
	if floor and floor:IsA("BasePart") then
		floor.Material = Enum.Material.Concrete
		floor.Color = Color3.fromRGB(150, 148, 142)
	end

	-- Rack rows: each V2 rack becomes its zone's piece, in the same place.
	for rowIndex, row in ROWS do
		for side, dx in { -16, 16 } do
			local pos = Vector3.new(HALL.X + dx, FLOOR, row.z)
			for _, d in map:GetChildren() do
				if
					d:IsA("Model")
					and d.Name == "PalletRack"
					and (Vector3.new(d:GetPivot().Position.X, FLOOR, d:GetPivot().Position.Z) - pos).Magnitude
						< 1
				then
					d:Destroy()
				end
			end
			local name = if side == 1 then row.west else row.east
			local piece = place("v3ware", name, CFrame.new(pos), folder)
			if piece then
				solidify(piece, COLLIDER_HEIGHT[name], ctx, folder)
				if name == "TallRackA" or name == "TallRackB" then
					local label = string.char(64 + rowIndex) .. "-" .. tostring(side)
					paint(piece, Enum.NormalId.Front, label, S.SafetyYellow, ctx)
				elseif name == "MeshCage" then
					paint(piece, Enum.NormalId.Front, "HIGH VALUE", S.Coral, ctx)
				else
					paint(piece, Enum.NormalId.Front, "INBOUND", S.Cream, ctx)
				end
			end
		end
	end

	-- Overhead crane between the two storage rows; the hook hangs over the centre aisle, well
	-- above head height. Visual only.
	local crane = place("v3ware", "OverheadCrane", CFrame.new(HALL.X, 18, 89), folder)
	paint(crane, Enum.NormalId.Front, "10 TON", S.HazardBlack, ctx)
	if crane then
		for _, d in crane:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
			end
		end
	end

	-- Equipment wall: breaker panels on the west wall by the storage aisles.
	local panel = place(
		"v3ware",
		"BreakerPanel",
		CFrame.lookAt(Vector3.new(HALL.X - 34.4, FLOOR, 88.5), Vector3.new(HALL.X - 30, FLOOR, 88.5)),
		folder
	)
	paint(panel, Enum.NormalId.Front, "480V", S.HazardBlack, ctx)

	-- Floor markings: a forklift lane down the centre aisle and a receiving stencil by the door.
	for _, x in { HALL.X - 3.6, HALL.X + 3.6 } do
		flat(ctx, folder, Vector3.new(0.4, 0.05, 56), Vector3.new(x, FLOOR + 0.03, 90), S.SafetyYellow)
	end
	local stencil = flat(
		ctx,
		folder,
		Vector3.new(6.4, 0.05, 2.2),
		Vector3.new(HALL.X, FLOOR + 0.03, 62.5),
		floor and floor.Color or S.Concrete
	)
	ctx.SurfaceSign(stencil, Enum.NormalId.Top, "RECEIVING", S.SafetyYellow, Enum.Font.LuckiestGuy)

	-- The V2 hanging lamps join the work-lamp flicker and lightning shorts.
	for _, d in map:GetChildren() do
		if d:IsA("Model") and d.Name == "IndustryLamp" then
			tagLamps(d, "")
		end
	end

	-- Exterior: dock lights over both bay doors, storm repairs on the siding, roof fans, and a
	-- freight truck backed up to the east loading dock.
	for _, x in { HALL.X - 22, HALL.X + 22 } do
		local lamp = place(
			"v3ware",
			"DockLight",
			CFrame.lookAt(Vector3.new(x + 8.6, 15.6, 59.2), Vector3.new(x + 8.6, 15.6, 55)),
			folder
		)
		if lamp then
			tagLamps(lamp, "Neon")
			local lens = meshWith(lamp, "Neon")
			if lens then
				pointLight(lens, 16, 0.8)
			end
		end
	end
	place("v3ware", "SidingPatch", CFrame.lookAt(Vector3.new(114, 6, 58.8), Vector3.new(114, 6, 50)), folder)
	place(
		"v3ware",
		"SidingPatch",
		CFrame.lookAt(Vector3.new(161, 4.5, 76), Vector3.new(170, 4.5, 76)) * CFrame.Angles(0, 0, math.rad(4)),
		folder
	)
	for _, pos in { Vector3.new(108, 23, 77), Vector3.new(142, 23, 101) } do
		place("v3ware", "RoofFan", CFrame.new(pos), folder)
	end
	local truck =
		place("v3ware", "BoxTruck", CFrame.lookAt(Vector3.new(147, 0, 33.6), Vector3.new(147, 0, 20)), folder)
	if truck then
		for _, d in truck:GetDescendants() do
			if d:IsA("BasePart") and string.find(d.Name, "Signboard", 1, true) then
				local face = if d.Position.X < 147 then Enum.NormalId.Left else Enum.NormalId.Right
				ctx.SurfaceSign(d, face, "GALE FREIGHT", S.Coral, Enum.Font.LuckiestGuy)
			end
		end
	end
	for _, pos in { Vector3.new(140, 0.35, 44), Vector3.new(110, 0.35, 56) } do
		local spot = ctx.Prop({
			Parent = folder,
			Name = "PuddleSpot",
			Size = Vector3.one,
			Position = pos,
			Transparency = 1,
		})
		CollectionService:AddTag(spot, "V3PuddleSpot")
	end

	-- Shadow pass over everything inside the hall.
	for _, model in folder:GetChildren() do
		if model:IsA("Model") then
			local p = model:GetPivot().Position
			if math.abs(p.X - HALL.X) < 35 and math.abs(p.Z - HALL.Z) < 30 then
				local keep = SHADOW_KEEP[model.Name] or {}
				for _, d in model:GetDescendants() do
					if d:IsA("BasePart") then
						local suffix = string.match(d.Name, "__(%w+__%w+)$")
						d.CastShadow = suffix ~= nil and keep[suffix] == true
					end
				end
			end
		end
	end

	map:SetAttribute("C4WarehouseBuildMs", math.floor((os.clock() - t0) * 1000))
end

return DistrictWarehouse
