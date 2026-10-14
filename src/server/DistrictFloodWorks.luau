-- @file Gale Hollow Flood Control Works district (V4 M5)
-- @domain world
-- @status wip
-- @see [[V4-M5]]
-- The north-east ground beside the Scrapyard plateau (x 88..202, z -334..-214): the works that
-- were meant to keep Gale Hollow dry. On a concrete apron:
--   * a spillway channel between two walkable banks, with a sluice gate across it;
--   * the pump house (walk in: pumps and a control panel; roof is shelter and, at 14 studs,
--     above the flood line; ladder up the side);
--   * the sluice tower (ladder to its 26-stud deck; its valve wheel turns), and from its deck a
--     catwalk bridge west to the Scrapyard plateau's east fence: the second shortcut home;
--   * two settling tanks (ladders, walkable rims) and three big outfall pipes you can run along.
-- Loot points: in the pump house, on the tank rims, along the pipes. Built from parts.
-- Spinning parts (valve wheel, roof vents) and the gate's warning lamps animate on the client
-- (WorldMotion tags), so the server does no per-frame work here.

local CollectionService = game:GetService("CollectionService")

local Palette = require(game:GetService("ReplicatedStorage").Shared.Palette)

local DistrictFloodWorks = {}

local S = Palette.Swatches
local CONCRETE = Color3.fromRGB(168, 164, 156)
local CONCRETE_DARK = Color3.fromRGB(128, 124, 118)
local STEEL = Color3.fromRGB(64, 92, 112)
local DARK = Color3.fromRGB(40, 42, 46)
local WATER = Color3.fromRGB(70, 120, 140)
local PIPE = Color3.fromRGB(70, 110, 80)

DistrictFloodWorks.Min = Vector3.new(88, 0, -334)
DistrictFloodWorks.Max = Vector3.new(202, 0, -214)
DistrictFloodWorks.BridgeZ = -232
DistrictFloodWorks.Landing = Vector3.new(84, 30, -232)

type Context = {
	Map: Model,
	Roofs: Folder,
	Part: (props: { [string]: any }) -> Part,
	Prop: (props: { [string]: any }) -> Part,
	SurfaceSign: (BasePart, Enum.NormalId, string, Color3, Enum.Font?) -> any,
}

local function truss(parent: Instance, pos: Vector3, height: number)
	local t = Instance.new("TrussPart")
	t.Name = "Ladder"
	t.Anchored = true
	t.Size = Vector3.new(2, height, 2)
	t.Position = pos + Vector3.new(0, height / 2, 0)
	t.Color = S.SafetyYellow
	t.Parent = parent
	CollectionService:AddTag(t, "FloodLadder")
	return t
end

local function spin(p: BasePart, speed: number, axis: string)
	p:SetAttribute("SpinSpeed", speed)
	p:SetAttribute("SpinAxis", axis)
	CollectionService:AddTag(p, "Spin")
end

function DistrictFloodWorks.build(ctx: Context): { Vector3 }
	local model = Instance.new("Model")
	model.Name = "FloodWorks"
	model.Parent = ctx.Map
	local points: { Vector3 } = {}
	local min, max = DistrictFloodWorks.Min, DistrictFloodWorks.Max
	local mid = (min + max) / 2
	local depth = max.Z - min.Z

	ctx.Prop({
		Parent = model,
		Name = "Apron",
		Size = Vector3.new(max.X - min.X, 0.2, depth),
		Position = Vector3.new(mid.X, 0.1, mid.Z),
		Color = CONCRETE,
		Material = Enum.Material.Concrete,
	})

	-- Spillway channel (x 141..159) between banks you can walk along.
	for _, x in { 139.5, 160.5 } do
		ctx.Part({
			Parent = model,
			Name = "Bank",
			Size = Vector3.new(3, 2.4, depth),
			Position = Vector3.new(x, 1.2, mid.Z),
			Color = CONCRETE_DARK,
			Material = Enum.Material.Concrete,
		})
	end
	ctx.Prop({
		Parent = model,
		Name = "ChannelWater",
		Size = Vector3.new(18, 0.3, depth),
		Position = Vector3.new(150, 0.5, mid.Z),
		Color = WATER,
		Material = Enum.Material.Glass,
		Transparency = 0.25,
	})
	-- Sluice gate across the channel, lamps that blink while the works "run".
	local gz = -258
	ctx.Part({
		Parent = model,
		Name = "SluiceGate",
		Size = Vector3.new(18, 7, 1.2),
		Position = Vector3.new(150, 4.9, gz),
		Color = STEEL,
		Material = Enum.Material.CorrodedMetal,
	})
	ctx.Part({
		Parent = model,
		Name = "GateFrame",
		Size = Vector3.new(24, 1.2, 2),
		Position = Vector3.new(150, 11, gz),
		Color = DARK,
		Material = Enum.Material.Metal,
	})
	for _, x in { 138.5, 161.5 } do
		ctx.Part({
			Parent = model,
			Name = "GatePost",
			Size = Vector3.new(1.4, 11, 2),
			Position = Vector3.new(x, 5.5, gz),
			Color = DARK,
			Material = Enum.Material.Metal,
		})
		local lamp = ctx.Prop({
			Parent = model,
			Name = "GateLamp",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.9, 0.9, 0.9),
			Position = Vector3.new(x, 12.2, gz),
			Color = Color3.fromRGB(255, 170, 40),
			Material = Enum.Material.Neon,
		})
		lamp:SetAttribute("BlinkPhase", if x < 150 then 0 else 1)
		CollectionService:AddTag(lamp, "Blink")
	end
	local sign = ctx.Prop({
		Parent = model,
		Name = "GateSign",
		Size = Vector3.new(18, 2.4, 0.3),
		Position = Vector3.new(150, 13.4, gz),
		Color = Color3.fromRGB(30, 44, 60),
	})
	ctx.SurfaceSign(sign, Enum.NormalId.Front, "GALE HOLLOW FLOOD CONTROL", S.White)
	ctx.SurfaceSign(sign, Enum.NormalId.Back, "GALE HOLLOW FLOOD CONTROL", S.White)

	-- Pump house: 30 x 22, 14 high, door on the north side (toward the tower).
	local ph = Vector3.new(112, 0, -300)
	local w, d, h = 30, 22, 14
	ctx.Part({
		Parent = model,
		Name = "PumpFloor",
		Size = Vector3.new(w, 1, d),
		Position = ph + Vector3.new(0, 0.5, 0),
		Color = CONCRETE_DARK,
		Material = Enum.Material.Concrete,
	})
	for _, dx in { -w / 2, w / 2 } do
		ctx.Part({
			Parent = model,
			Name = "PumpWall",
			Size = Vector3.new(1, h, d),
			Position = ph + Vector3.new(dx, h / 2, 0),
			Color = Color3.fromRGB(176, 120, 90),
			Material = Enum.Material.Brick,
		})
	end
	ctx.Part({
		Parent = model,
		Name = "PumpWall",
		Size = Vector3.new(w, h, 1),
		Position = ph + Vector3.new(0, h / 2, d / 2),
		Color = Color3.fromRGB(176, 120, 90),
		Material = Enum.Material.Brick,
	})
	for _, dx in { -9.5, 9.5 } do -- north wall with an 8-stud door
		ctx.Part({
			Parent = model,
			Name = "PumpWall",
			Size = Vector3.new(11, h, 1),
			Position = ph + Vector3.new(dx, h / 2, -d / 2),
			Color = Color3.fromRGB(176, 120, 90),
			Material = Enum.Material.Brick,
		})
	end
	ctx.Part({
		Parent = model,
		Name = "Lintel",
		Size = Vector3.new(8, h - 9, 1),
		Position = ph + Vector3.new(0, 9 + (h - 9) / 2, -d / 2),
		Color = Color3.fromRGB(176, 120, 90),
		Material = Enum.Material.Brick,
	})
	local roof = ctx.Part({
		Parent = ctx.Roofs,
		Name = "PumpHouseRoof",
		Size = Vector3.new(w + 2, 1, d + 2),
		Position = ph + Vector3.new(0, h + 0.5, 0),
		Color = DARK,
		Material = Enum.Material.Metal,
	})
	roof.CanQuery = true
	local plate = ctx.Prop({
		Parent = model,
		Name = "PumpSign",
		Size = Vector3.new(16, 2.4, 0.3),
		Position = ph + Vector3.new(0, 11, -d / 2 - 0.7),
		Color = Color3.fromRGB(30, 44, 60),
	})
	ctx.SurfaceSign(plate, Enum.NormalId.Front, "PUMP HOUSE 2", S.White)
	truss(model, ph + Vector3.new(w / 2 + 1.2, 0, 5), h + 1)
	for _, dx in { -7, 7 } do -- the pumps
		ctx.Part({
			Parent = model,
			Name = "Pump",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(6, 5, 5),
			Position = ph + Vector3.new(dx, 4, 4),
			Orientation = Vector3.new(0, 0, 90),
			Color = STEEL,
			Material = Enum.Material.Metal,
		})
		ctx.Prop({
			Parent = model,
			Name = "PumpMotor",
			Size = Vector3.new(3, 3, 3),
			Position = ph + Vector3.new(dx, 2.5, -1),
			Color = S.Coral,
			Material = Enum.Material.Metal,
		})
	end
	ctx.Prop({
		Parent = model,
		Name = "ControlPanel",
		Size = Vector3.new(6, 4, 1),
		Position = ph + Vector3.new(-10, 3, d / 2 - 1.2),
		Color = Color3.fromRGB(200, 200, 190),
		Material = Enum.Material.SmoothPlastic,
	})
	for _, dx in { -7, 7 } do
		local vent = ctx.Prop({
			Parent = model,
			Name = "RoofVent",
			Size = Vector3.new(4, 0.4, 0.8),
			Position = ph + Vector3.new(dx, h + 2, -4),
			Color = DARK,
			Material = Enum.Material.Metal,
		})
		spin(vent, 3, "Y")
		ctx.Prop({
			Parent = model,
			Name = "VentHousing",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.2, 5, 5),
			Position = ph + Vector3.new(dx, h + 1.4, -4),
			Orientation = Vector3.new(0, 0, 90),
			Color = CONCRETE_DARK,
			Material = Enum.Material.Metal,
		})
	end
	for _, o in
		{ Vector3.new(-9, 0, -4), Vector3.new(9, 0, -4), Vector3.new(0, 0, 6), Vector3.new(-11, 0, 7) }
	do
		table.insert(points, ph + o + Vector3.new(0, 1 + 1.5, 0))
	end
	table.insert(points, ph + Vector3.new(0, h + 1 + 1.5, 6)) -- on the roof

	-- Sluice tower beside the channel, and the catwalk to the plateau.
	local tw = Vector3.new(124, 0, DistrictFloodWorks.BridgeZ)
	local th = 26
	ctx.Part({
		Parent = model,
		Name = "Tower",
		Size = Vector3.new(10, th, 10),
		Position = tw + Vector3.new(0, th / 2, 0),
		Color = CONCRETE,
		Material = Enum.Material.Concrete,
	})
	ctx.Part({
		Parent = model,
		Name = "TowerDeck",
		Size = Vector3.new(13, 1, 13),
		Position = tw + Vector3.new(0, th + 0.5, 0),
		Color = DARK,
		Material = Enum.Material.DiamondPlate,
	})
	truss(model, tw + Vector3.new(6, 0, 0), th + 1)
	local wheel = ctx.Prop({
		Parent = model,
		Name = "ValveWheel",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 6, 6),
		Position = tw + Vector3.new(0, 16, -5.4),
		Orientation = Vector3.new(0, 90, 0),
		Color = Color3.fromRGB(200, 40, 40),
		Material = Enum.Material.Metal,
	})
	spin(wheel, 0.8, "X")
	table.insert(points, tw + Vector3.new(-3, th + 1 + 1.5, 3))
	local a = tw + Vector3.new(-6.5, th + 1, 0)
	local b = DistrictFloodWorks.Landing
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)
	local bridge = ctx.Part({
		Parent = model,
		Name = "Catwalk",
		Size = Vector3.new(len, 1, 5),
		CFrame = cf * CFrame.new(0, -0.5, 0),
		Color = DARK,
		Material = Enum.Material.DiamondPlate,
	})
	bridge.CanQuery = true
	for _, dz in { -2.6, 2.6 } do
		ctx.Prop({
			Parent = model,
			Name = "CatwalkRail",
			Size = Vector3.new(len, 0.3, 0.3),
			CFrame = cf * CFrame.new(0, 2.6, dz),
			Color = S.SafetyYellow,
			Material = Enum.Material.Metal,
		})
	end
	local m = (a + b) / 2
	ctx.Part({
		Parent = model,
		Name = "CatwalkPillar",
		Size = Vector3.new(1.4, m.Y - 1, 1.4),
		Position = Vector3.new(m.X, (m.Y - 1) / 2, b.Z),
		Color = DARK,
		Material = Enum.Material.Metal,
	})
	for _, dd in ctx.Map:GetDescendants() do
		if dd:IsA("BasePart") and dd.Name:find("Fence") and dd.Parent ~= model then
			local p = dd.Position
			if math.abs(p.X - b.X) < 3 and math.abs(p.Z - b.Z) < 4.5 and p.Y > 25 then
				dd:Destroy()
			end
		end
	end

	-- Settling tanks east of the channel.
	for _, c in { Vector3.new(184, 0, -290), Vector3.new(184, 0, -246) } do
		ctx.Part({
			Parent = model,
			Name = "Tank",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(7, 24, 24),
			Position = c + Vector3.new(0, 3.5, 0),
			Orientation = Vector3.new(0, 0, 90),
			Color = CONCRETE,
			Material = Enum.Material.Concrete,
		})
		ctx.Prop({
			Parent = model,
			Name = "TankWater",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 20, 20),
			Position = c + Vector3.new(0, 7.05, 0),
			Orientation = Vector3.new(0, 0, 90),
			Color = WATER,
			Material = Enum.Material.Glass,
			Transparency = 0.2,
		})
		local stir = ctx.Prop({
			Parent = model,
			Name = "Stirrer",
			Size = Vector3.new(19, 0.4, 0.8),
			Position = c + Vector3.new(0, 7.4, 0),
			Color = DARK,
			Material = Enum.Material.Metal,
		})
		spin(stir, 0.4, "Y")
		truss(model, c + Vector3.new(-12.6, 0, 0), 7.5)
		table.insert(points, c + Vector3.new(-9.5, 7 + 1.5, 6))
	end

	-- Outfall pipes from the pump house to the east wall: run along their tops.
	for i, z in { -322, -316, -310 } do
		ctx.Part({
			Parent = model,
			Name = "Outfall",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(70, 5, 5),
			Position = Vector3.new(165, 2.5 + (i - 1) * 0.0, z),
			Color = PIPE,
			Material = Enum.Material.CorrodedMetal,
		})
	end
	for _, x in { 140, 175 } do
		ctx.Prop({
			Parent = model,
			Name = "PipeClamp",
			Size = Vector3.new(1.4, 6, 18),
			Position = Vector3.new(x, 3, -316),
			Color = DARK,
			Material = Enum.Material.Metal,
		})
	end
	table.insert(points, Vector3.new(196, 1.5, -328))
	table.insert(points, Vector3.new(160, 5 + 1.5, -316)) -- on the pipes
	table.insert(points, Vector3.new(100, 1.5, -228))
	return points
end

return DistrictFloodWorks
