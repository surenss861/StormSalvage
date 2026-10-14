-- @file Gale Hollow Rail Yard district (V4 M5)
-- @domain world
-- @status wip
-- @see [[V4-M5]]
-- The north-west ground beside the Scrapyard plateau (x -202..-88, z -334..-214), where the
-- town's scrap used to leave by rail. Four tracks run north-south on a ballast bed, with:
--   * three boxcars you can walk into (doors open both sides; roofs are shelter) and a flatcar
--     with two shipping containers (one open, a ladder to the top: flood refuge);
--   * a boxcar the storm rolled onto its side;
--   * the signal gantry: a footbridge over the tracks at 13 studs (ladders at both ends and the
--     middle), which carries on as a ramp up to the Scrapyard plateau's west fence. That's a
--     shortcut home: from the yard to the sell counter without the main road;
--   * the water tower (ladder to its catwalk at 22 studs: the yard's high ground);
--   * signal lamps that blink (client WorldMotion), buffer stops, crates.
-- Loot points: inside the cars and containers, by the crates. Built from parts (no assets).

local CollectionService = game:GetService("CollectionService")

local Palette = require(game:GetService("ReplicatedStorage").Shared.Palette)

local DistrictRailYard = {}

local S = Palette.Swatches
local BALLAST = Color3.fromRGB(112, 104, 96)
local RAIL = Color3.fromRGB(150, 140, 130)
local TIE = Color3.fromRGB(92, 70, 52)
local RUST = Color3.fromRGB(150, 74, 44)
local CAR_COLORS = { Color3.fromRGB(150, 60, 40), Color3.fromRGB(60, 90, 120), Color3.fromRGB(110, 110, 60) }
local DARK = Color3.fromRGB(40, 40, 44)

DistrictRailYard.Min = Vector3.new(-202, 0, -334)
DistrictRailYard.Max = Vector3.new(-88, 0, -214)
DistrictRailYard.Tracks = { -185, -160, -135, -112 }
DistrictRailYard.GantryZ = -250
DistrictRailYard.Landing = Vector3.new(-84, 30, -250) -- where the ramp meets the plateau

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

-- A walk-in boxcar on a track, its long axis along Z. Returns two loot points inside.
local function boxcar(ctx: Context, parent: Instance, c: Vector3, color: Color3, label: string): { Vector3 }
	local model = Instance.new("Model")
	model.Name = "Boxcar"
	model.Parent = parent
	local floorY = 2.2
	ctx.Part({
		Parent = model,
		Name = "Deck",
		Size = Vector3.new(10, 1, 26),
		Position = c + Vector3.new(0, floorY, 0),
		Color = DARK,
		Material = Enum.Material.DiamondPlate,
	})
	local wallY = floorY + 0.5 + 4
	for _, side in { -1, 1 } do
		for _, dz in { -8, 8 } do -- a 6-stud door gap in the middle of each long wall
			ctx.Part({
				Parent = model,
				Name = "Wall",
				Size = Vector3.new(0.6, 8, 10),
				Position = c + Vector3.new(side * 4.7, wallY, dz),
				Color = color,
				Material = Enum.Material.CorrodedMetal,
			})
		end
		ctx.Prop({
			Parent = model,
			Name = "DoorSlid",
			Size = Vector3.new(0.4, 7.6, 6),
			Position = c + Vector3.new(side * 5.2, wallY, -8),
			Color = color:Lerp(DARK, 0.3),
			Material = Enum.Material.CorrodedMetal,
		})
	end
	for _, dz in { -12.7, 12.7 } do
		ctx.Part({
			Parent = model,
			Name = "End",
			Size = Vector3.new(10, 8, 0.6),
			Position = c + Vector3.new(0, wallY, dz),
			Color = color,
			Material = Enum.Material.CorrodedMetal,
		})
	end
	local roof = ctx.Part({
		Parent = ctx.Roofs,
		Name = "BoxcarRoof",
		Size = Vector3.new(11, 0.6, 27),
		Position = c + Vector3.new(0, floorY + 8.8, 0),
		Color = color:Lerp(DARK, 0.4),
		Material = Enum.Material.Metal,
	})
	roof.CanQuery = true
	for _, dz in { -9, 9 } do
		ctx.Prop({
			Parent = model,
			Name = "Bogie",
			Size = Vector3.new(8, 1.6, 4),
			Position = c + Vector3.new(0, 0.9, dz),
			Color = DARK,
			Material = Enum.Material.Metal,
		})
	end
	local plate = ctx.Prop({
		Parent = model,
		Name = "Plate",
		Size = Vector3.new(0.1, 1.6, 7),
		Position = c + Vector3.new(-5.05, floorY + 6, -8),
		Color = color,
	})
	ctx.SurfaceSign(plate, Enum.NormalId.Left, label, Color3.fromRGB(240, 230, 210))
	-- A step up at each door.
	for _, side in { -1, 1 } do
		ctx.Part({
			Parent = model,
			Name = "Step",
			Size = Vector3.new(1.6, 1.2, 4),
			Position = c + Vector3.new(side * 5.9, 0.6, 0),
			Color = DARK,
			Material = Enum.Material.DiamondPlate,
		})
	end
	local y = floorY + 0.5 + 1.5
	return { c + Vector3.new(0, y, -7), c + Vector3.new(0, y, 7) }
end

function DistrictRailYard.build(ctx: Context): { Vector3 }
	local model = Instance.new("Model")
	model.Name = "RailYard"
	model.Parent = ctx.Map
	local points: { Vector3 } = {}
	local min, max = DistrictRailYard.Min, DistrictRailYard.Max
	local mid = (min + max) / 2
	local depth = max.Z - min.Z

	ctx.Prop({
		Parent = model,
		Name = "Ballast",
		Size = Vector3.new(max.X - min.X, 0.2, depth),
		Position = Vector3.new(mid.X, 0.1, mid.Z),
		Color = BALLAST,
		Material = Enum.Material.Pebble,
	})
	for _, x in DistrictRailYard.Tracks do
		for _, dx in { -2.4, 2.4 } do
			ctx.Prop({
				Parent = model,
				Name = "Rail",
				Size = Vector3.new(0.5, 0.5, depth - 4),
				Position = Vector3.new(x + dx, 0.55, mid.Z),
				Color = RAIL,
				Material = Enum.Material.Metal,
			})
		end
		for z = min.Z + 4, max.Z - 4, 5 do
			ctx.Prop({
				Parent = model,
				Name = "Tie",
				Size = Vector3.new(7, 0.3, 1.2),
				Position = Vector3.new(x, 0.35, z),
				Color = TIE,
				Material = Enum.Material.WoodPlanks,
			})
		end
		local stop = ctx.Part({
			Parent = model,
			Name = "BufferStop",
			Size = Vector3.new(6, 2.4, 1.5),
			Position = Vector3.new(x, 1.2, min.Z + 2),
			Color = S.SafetyYellow,
			Material = Enum.Material.Metal,
		})
		stop.CanQuery = false
	end

	-- Rolling stock.
	for _, p in boxcar(ctx, model, Vector3.new(-160, 0, -300), CAR_COLORS[1], "GHR 1907") do
		table.insert(points, p)
	end
	for _, p in boxcar(ctx, model, Vector3.new(-160, 0, -268), CAR_COLORS[2], "GHR 2214") do
		table.insert(points, p)
	end
	for _, p in boxcar(ctx, model, Vector3.new(-112, 0, -300), CAR_COLORS[3], "GHR 0451") do
		table.insert(points, p)
	end
	-- Flatcar with two containers on track -135; the north one is open, a ladder up the south.
	ctx.Part({
		Parent = model,
		Name = "Flatcar",
		Size = Vector3.new(9, 1, 26),
		Position = Vector3.new(-135, 2.2, -272),
		Color = DARK,
		Material = Enum.Material.DiamondPlate,
	})
	for _, dz in { -9, 9 } do
		ctx.Prop({
			Parent = model,
			Name = "Bogie",
			Size = Vector3.new(8, 1.6, 4),
			Position = Vector3.new(-135, 0.9, -272 + dz),
			Color = DARK,
			Material = Enum.Material.Metal,
		})
	end
	local cTop = 2.7 + 8
	ctx.Part({
		Parent = model,
		Name = "Container",
		Size = Vector3.new(8.4, 8, 12),
		Position = Vector3.new(-135, 2.7 + 4, -265.5),
		Color = S.Cobalt,
		Material = Enum.Material.CorrodedMetal,
	})
	-- The open one: three walls and a roof, door end facing north.
	local oz = -278.5
	for _, dx in { -4, 4 } do
		ctx.Part({
			Parent = model,
			Name = "ContainerWall",
			Size = Vector3.new(0.4, 8, 12),
			Position = Vector3.new(-135 + dx, 2.7 + 4, oz),
			Color = RUST,
			Material = Enum.Material.CorrodedMetal,
		})
	end
	ctx.Part({
		Parent = model,
		Name = "ContainerBack",
		Size = Vector3.new(8.4, 8, 0.4),
		Position = Vector3.new(-135, 2.7 + 4, oz + 5.8),
		Color = RUST,
		Material = Enum.Material.CorrodedMetal,
	})
	local cRoof = ctx.Part({
		Parent = ctx.Roofs,
		Name = "ContainerRoof",
		Size = Vector3.new(8.4, 0.4, 12),
		Position = Vector3.new(-135, cTop + 0.2, oz),
		Color = RUST,
		Material = Enum.Material.CorrodedMetal,
	})
	cRoof.CanQuery = true
	ctx.Prop({
		Parent = model,
		Name = "ContainerDoor",
		Size = Vector3.new(0.3, 7.6, 4),
		Position = Vector3.new(-139.4, 2.7 + 4, oz - 7.8),
		Color = RUST:Lerp(DARK, 0.3),
		Material = Enum.Material.CorrodedMetal,
		Orientation = Vector3.new(0, 35, 0),
	})
	table.insert(points, Vector3.new(-135, 2.7 + 1.5, oz))
	table.insert(points, Vector3.new(-135, cTop + 1.5, -265.5)) -- on top (flood refuge, exposed)
	truss(model, Vector3.new(-130, 0, -260), cTop + 0.4)

	-- The storm's work: a boxcar on its side by the west track.
	local tipped = ctx.Part({
		Parent = model,
		Name = "TippedBoxcar",
		Size = Vector3.new(9, 10, 26),
		Position = Vector3.new(-194, 4.5, -228),
		Color = CAR_COLORS[1]:Lerp(DARK, 0.2),
		Material = Enum.Material.CorrodedMetal,
		Orientation = Vector3.new(0, 12, 0),
	})
	tipped.CastShadow = true
	ctx.Prop({
		Parent = model,
		Name = "TippedBogie",
		Size = Vector3.new(1.6, 8, 4),
		Position = Vector3.new(-189.2, 5, -220),
		Color = DARK,
		Material = Enum.Material.Metal,
		Orientation = Vector3.new(0, 12, 0),
	})
	table.insert(points, Vector3.new(-176, 1.5, -232))

	-- Crates by the tracks (loot beside them).
	for _, c in
		{
			Vector3.new(-198, 0, -290),
			Vector3.new(-124, 0, -228),
			Vector3.new(-96, 0, -320),
			Vector3.new(-172, 0, -330),
		}
	do
		ctx.Part({
			Parent = model,
			Name = "Crate",
			Size = Vector3.new(4, 4, 4),
			Position = c + Vector3.new(0, 2, 0),
			Color = Color3.fromRGB(150, 110, 70),
			Material = Enum.Material.WoodPlanks,
		})
		ctx.Prop({
			Parent = model,
			Name = "Crate",
			Size = Vector3.new(3, 3, 3),
			Position = c + Vector3.new(0.4, 5.5, 0.2),
			Color = Color3.fromRGB(140, 104, 66),
			Material = Enum.Material.WoodPlanks,
			Orientation = Vector3.new(0, 20, 0),
		})
		table.insert(points, c + Vector3.new(4, 1.5, 0))
	end

	-- The signal gantry and the ramp up to the Scrapyard.
	local gz = DistrictRailYard.GantryZ
	local deckY = 13
	local west, east = -197, -124
	ctx.Part({
		Parent = model,
		Name = "GantryDeck",
		Size = Vector3.new(east - west, 1, 5),
		Position = Vector3.new((west + east) / 2, deckY - 0.5, gz),
		Color = DARK,
		Material = Enum.Material.DiamondPlate,
	})
	for _, dz in { -2.6, 2.6 } do
		ctx.Prop({
			Parent = model,
			Name = "Rail",
			Size = Vector3.new(east - west, 0.3, 0.3),
			Position = Vector3.new((west + east) / 2, deckY + 2.6, gz + dz),
			Color = S.SafetyYellow,
			Material = Enum.Material.Metal,
		})
	end
	for _, x in { west + 1, -172, -147, east } do
		ctx.Part({
			Parent = model,
			Name = "Pillar",
			Size = Vector3.new(1.4, deckY - 1, 1.4),
			Position = Vector3.new(x, (deckY - 1) / 2, gz),
			Color = DARK,
			Material = Enum.Material.Metal,
		})
	end
	truss(model, Vector3.new(west - 1, 0, gz), deckY)
	truss(model, Vector3.new(-147, 0, gz + 3.5), deckY)
	local sign = ctx.Prop({
		Parent = model,
		Name = "YardSign",
		Size = Vector3.new(34, 3.2, 0.4),
		Position = Vector3.new(-160, deckY + 4.6, gz - 2.9),
		Color = Color3.fromRGB(40, 54, 70),
	})
	ctx.SurfaceSign(sign, Enum.NormalId.Back, "GALE HOLLOW RAIL YARD", S.SafetyYellow)
	ctx.SurfaceSign(sign, Enum.NormalId.Front, "GALE HOLLOW RAIL YARD", S.SafetyYellow)
	-- Ramp: from the gantry's east end up to the plateau's fence line.
	local a = Vector3.new(east, deckY, gz)
	local b = DistrictRailYard.Landing
	local run = b - a
	local len = run.Magnitude
	local ramp = ctx.Part({
		Parent = model,
		Name = "Ramp",
		Size = Vector3.new(len, 1, 5),
		CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(0, -0.5, 0),
		Color = DARK,
		Material = Enum.Material.DiamondPlate,
	})
	ramp.CanQuery = true
	for _, dz in { -2.6, 2.6 } do
		ctx.Prop({
			Parent = model,
			Name = "RampRail",
			Size = Vector3.new(len, 0.3, 0.3),
			CFrame = CFrame.lookAt((a + b) / 2 + Vector3.new(0, 2.6, dz), b + Vector3.new(0, 2.6, dz))
				* CFrame.Angles(0, math.pi / 2, 0),
			Color = S.SafetyYellow,
			Material = Enum.Material.Metal,
		})
	end
	local m = (a + b) / 2
	ctx.Part({
		Parent = model,
		Name = "RampPillar",
		Size = Vector3.new(1.4, m.Y - 1, 1.4),
		Position = Vector3.new(m.X, (m.Y - 1) / 2, gz),
		Color = DARK,
		Material = Enum.Material.Metal,
	})
	-- Open the plateau fence where the ramp lands (WorldSlice built it before this).
	for _, d in ctx.Map:GetDescendants() do
		if d:IsA("BasePart") and d.Name:find("Fence") and d.Parent ~= model then
			local p = d.Position
			if math.abs(p.X - b.X) < 3 and math.abs(p.Z - gz) < 4.5 and p.Y > 25 then
				d:Destroy()
			end
		end
	end
	ctx.Prop({
		Parent = model,
		Name = "GateArch",
		Size = Vector3.new(0.6, 0.6, 6),
		Position = Vector3.new(b.X, 38, gz),
		Color = S.SafetyYellow,
		Material = Enum.Material.Metal,
	})

	-- Water tower, north-west corner: a ladder to the catwalk.
	local wt = Vector3.new(-197, 0, -322)
	for _, o in { Vector3.new(-4, 0, -4), Vector3.new(4, 0, -4), Vector3.new(-4, 0, 4), Vector3.new(4, 0, 4) } do
		ctx.Part({
			Parent = model,
			Name = "TowerLeg",
			Size = Vector3.new(1, 22, 1),
			Position = wt + o + Vector3.new(0, 11, 0),
			Color = DARK,
			Material = Enum.Material.Metal,
		})
	end
	ctx.Part({
		Parent = model,
		Name = "Catwalk",
		Size = Vector3.new(13, 0.6, 13),
		Position = wt + Vector3.new(0, 21.7, 0),
		Color = DARK,
		Material = Enum.Material.DiamondPlate,
	})
	ctx.Part({
		Parent = model,
		Name = "Tank",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(9, 11, 11),
		Position = wt + Vector3.new(0, 26.5, 0),
		Orientation = Vector3.new(0, 0, 90),
		Color = Color3.fromRGB(176, 150, 110),
		Material = Enum.Material.WoodPlanks,
	})
	ctx.Prop({
		Parent = model,
		Name = "TankCap",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(11, 4, 11),
		Position = wt + Vector3.new(0, 31, 0),
		Color = RUST,
		Material = Enum.Material.CorrodedMetal,
	})
	truss(model, wt + Vector3.new(6.5, 0, 0), 22)
	table.insert(points, wt + Vector3.new(-4, 22 + 1.5, 4.5))

	-- Signal lamps: blink on the client (WorldMotion "Blink").
	for _, at in { Vector3.new(-172, 0, -222), Vector3.new(-122, 0, -330), Vector3.new(-185, 0, -300) } do
		ctx.Prop({
			Parent = model,
			Name = "SignalPost",
			Size = Vector3.new(0.6, 9, 0.6),
			Position = at + Vector3.new(0, 4.5, 0),
			Color = DARK,
			Material = Enum.Material.Metal,
		})
		ctx.Prop({
			Parent = model,
			Name = "SignalHead",
			Size = Vector3.new(1.6, 3, 1.2),
			Position = at + Vector3.new(0, 9.5, 0),
			Color = DARK,
			Material = Enum.Material.Metal,
		})
		for i, color in { Color3.fromRGB(255, 70, 50), Color3.fromRGB(80, 255, 120) } do
			local lamp = ctx.Prop({
				Parent = model,
				Name = "SignalLamp",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.8, 0.8, 0.8),
				Position = at + Vector3.new(0, 10.4 - (i - 1) * 1.2, -0.65),
				Color = color,
				Material = Enum.Material.Neon,
			})
			lamp:SetAttribute("BlinkPhase", i - 1)
			CollectionService:AddTag(lamp, "Blink")
		end
	end
	return points
end

return DistrictRailYard
