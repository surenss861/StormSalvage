-- @file The south edge: Gale Hollow Ballpark and Pine Rest Trailer Park (V4 M5)
-- @domain world
-- @status wip
-- @see [[V4-M5]]
-- The open grass either side of the Starlite Motel, filled with two small districts, both far
-- from the Scrapyard (the hardest runs home):
--   Ballpark (SW, x -200..-70, z 138..204): an infield, a backstop, two dugouts (roofed:
--     shelter; loot inside), stepped bleachers you can climb, light towers, and the scoreboard
--     tower (ladder to its 16-stud deck: above the flood line).
--   Trailer park (SE, x 62..200, z 138..204): five single-wide trailers round a gravel loop.
--     Walk in through the door; roofs are shelter. The storm has taken one roof off and tipped
--     another trailer onto its side. A laundry line and a mailbox row between them.
-- Built from parts. Returns two loot-point lists.

local CollectionService = game:GetService("CollectionService")

local Palette = require(game:GetService("ReplicatedStorage").Shared.Palette)

local DistrictSouth = {}

local S = Palette.Swatches
local DIRT = Color3.fromRGB(176, 128, 86)
local DARK = Color3.fromRGB(44, 44, 48)
local GRAVEL = Color3.fromRGB(150, 142, 128)
local TRAILER = {
	Color3.fromRGB(226, 214, 180),
	Color3.fromRGB(150, 196, 190),
	Color3.fromRGB(230, 180, 150),
	Color3.fromRGB(190, 200, 150),
	Color3.fromRGB(210, 210, 214),
}

DistrictSouth.BallparkMin = Vector3.new(-200, 0, 138)
DistrictSouth.BallparkMax = Vector3.new(-70, 0, 204)
DistrictSouth.TrailersMin = Vector3.new(62, 0, 138)
DistrictSouth.TrailersMax = Vector3.new(200, 0, 204)

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
end

local function roof(ctx: Context, name: string, size: Vector3, pos: Vector3, color: Color3): Part
	local r = ctx.Part({
		Parent = ctx.Roofs,
		Name = name,
		Size = size,
		Position = pos,
		Color = color,
		Material = Enum.Material.Metal,
	})
	r.CanQuery = true
	return r
end

local function ballpark(ctx: Context, model: Model): { Vector3 }
	local points = {}
	local home = Vector3.new(-160, 0, 194) -- home plate, field opens north
	-- Infield: a dirt diamond and the bases.
	ctx.Prop({
		Parent = model,
		Name = "Infield",
		Size = Vector3.new(34, 0.2, 34),
		CFrame = CFrame.new(home + Vector3.new(0, 0.12, -24)) * CFrame.Angles(0, math.rad(45), 0),
		Color = DIRT,
		Material = Enum.Material.Sand,
	})
	for _, o in
		{ Vector3.new(0, 0, -48), Vector3.new(-24, 0, -24), Vector3.new(24, 0, -24), Vector3.new(0, 0, 0) }
	do
		ctx.Prop({
			Parent = model,
			Name = "Base",
			Size = Vector3.new(1.6, 0.3, 1.6),
			Position = home + o + Vector3.new(0, 0.3, 0),
			Color = S.White,
		})
	end
	ctx.Prop({
		Parent = model,
		Name = "Mound",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 7, 7),
		Position = home + Vector3.new(0, 0.3, -24),
		Orientation = Vector3.new(0, 0, 90),
		Color = DIRT,
		Material = Enum.Material.Sand,
	})
	-- Backstop behind home.
	ctx.Part({
		Parent = model,
		Name = "BackstopWall",
		Size = Vector3.new(26, 2.5, 0.8),
		Position = home + Vector3.new(0, 1.25, 7),
		Color = Color3.fromRGB(40, 70, 50),
		Material = Enum.Material.Concrete,
	})
	ctx.Prop({
		Parent = model,
		Name = "BackstopMesh",
		Size = Vector3.new(26, 10, 0.2),
		Position = home + Vector3.new(0, 7.5, 7),
		Color = Color3.fromRGB(150, 150, 150),
		Material = Enum.Material.DiamondPlate,
		Transparency = 0.55,
	})
	-- Dugouts either side of home: roofed (shelter), open to the field.
	for _, side in { -1, 1 } do
		local c = home + Vector3.new(side * 24, 0, 4)
		ctx.Part({
			Parent = model,
			Name = "DugoutBack",
			Size = Vector3.new(14, 6, 0.8),
			Position = c + Vector3.new(0, 3, 3),
			Color = Color3.fromRGB(40, 70, 50),
			Material = Enum.Material.Concrete,
		})
		for _, dx in { -7, 7 } do
			ctx.Part({
				Parent = model,
				Name = "DugoutEnd",
				Size = Vector3.new(0.8, 6, 6),
				Position = c + Vector3.new(dx, 3, 0),
				Color = Color3.fromRGB(40, 70, 50),
				Material = Enum.Material.Concrete,
			})
		end
		roof(
			ctx,
			"DugoutRoof",
			Vector3.new(15, 0.6, 7.5),
			c + Vector3.new(0, 6.3, 0),
			Color3.fromRGB(30, 50, 40)
		)
		ctx.Prop({
			Parent = model,
			Name = "Bench",
			Size = Vector3.new(11, 1.2, 1.4),
			Position = c + Vector3.new(0, 0.6, 2),
			Color = Color3.fromRGB(120, 90, 60),
			Material = Enum.Material.WoodPlanks,
		})
		table.insert(points, c + Vector3.new(-3, 1.5, 0))
		table.insert(points, c + Vector3.new(3.5, 1.5, -1))
	end
	-- Bleachers along the first-base line: four steps you can climb.
	local b = home + Vector3.new(44, 0, -14)
	for i = 0, 3 do
		ctx.Part({
			Parent = model,
			Name = "Bleacher",
			Size = Vector3.new(6, 1.6 * (i + 1), 22),
			Position = b + Vector3.new(i * 3 + 3, 0.8 * (i + 1), 0),
			Color = Color3.fromRGB(150, 150, 160),
			Material = Enum.Material.DiamondPlate,
		})
	end
	table.insert(points, b + Vector3.new(12, 6.4 + 1.5, -6))
	-- Scoreboard tower in deep centre: the high ground here.
	local sb = Vector3.new(-160, 0, 140)
	ctx.Part({
		Parent = model,
		Name = "ScoreboardPost",
		Size = Vector3.new(3, 16, 3),
		Position = sb + Vector3.new(0, 8, 0),
		Color = DARK,
		Material = Enum.Material.Metal,
	})
	ctx.Part({
		Parent = model,
		Name = "ScoreboardDeck",
		Size = Vector3.new(10, 1, 6),
		Position = sb + Vector3.new(0, 16, 1),
		Color = DARK,
		Material = Enum.Material.DiamondPlate,
	})
	local board = ctx.Part({
		Parent = model,
		Name = "Scoreboard",
		Size = Vector3.new(18, 7, 1),
		Position = sb + Vector3.new(0, 20.5, -2.2),
		Color = Color3.fromRGB(30, 60, 40),
		Material = Enum.Material.SmoothPlastic,
	})
	ctx.SurfaceSign(board, Enum.NormalId.Back, "STORM 0  ·  VISITORS 7", S.SafetyYellow)
	truss(model, sb + Vector3.new(2.6, 0, 1), 16.5)
	table.insert(points, sb + Vector3.new(-3, 16.5 + 1.5, 2))
	-- Light towers on the foul lines (lamps blink in a storm-flicker on the client).
	for _, at in { home + Vector3.new(-40, 0, -40), home + Vector3.new(40, 0, -40) } do
		ctx.Prop({
			Parent = model,
			Name = "LightMast",
			Size = Vector3.new(1, 22, 1),
			Position = at + Vector3.new(0, 11, 0),
			Color = DARK,
			Material = Enum.Material.Metal,
		})
		local lamp = ctx.Prop({
			Parent = model,
			Name = "Floodlight",
			Size = Vector3.new(5, 2.4, 0.8),
			Position = at + Vector3.new(0, 22.5, 0),
			Color = Color3.fromRGB(255, 244, 210),
			Material = Enum.Material.Neon,
		})
		lamp:SetAttribute("BlinkPhase", if at.X < home.X then 0 else 1)
		CollectionService:AddTag(lamp, "Blink")
	end
	table.insert(points, home + Vector3.new(-12, 1.5, -36))
	table.insert(points, home + Vector3.new(18, 1.5, -44))
	return points
end

-- A single-wide trailer, long axis along X, door on the north (-Z) side.
local function trailer(
	ctx: Context,
	model: Model,
	c: Vector3,
	color: Color3,
	roofOn: boolean
): ({ Vector3 }, Model)
	local m = Instance.new("Model")
	m.Name = "Trailer"
	m.Parent = model
	ctx.Part({
		Parent = m,
		Name = "Floor",
		Size = Vector3.new(24, 1, 9),
		Position = c + Vector3.new(0, 1.5, 0),
		Color = DARK,
		Material = Enum.Material.Metal,
	})
	ctx.Part({
		Parent = m,
		Name = "Wall",
		Size = Vector3.new(24, 7, 0.5),
		Position = c + Vector3.new(0, 5.5, 4.25),
		Color = color,
		Material = Enum.Material.Metal,
	})
	for _, dx in { -12, 12 } do
		ctx.Part({
			Parent = m,
			Name = "Wall",
			Size = Vector3.new(0.5, 7, 9),
			Position = c + Vector3.new(dx, 5.5, 0),
			Color = color,
			Material = Enum.Material.Metal,
		})
	end
	for _, seg in { { -7.5, 9 }, { 7.5, 9 } } do -- north wall, a 6-stud door gap in the middle
		ctx.Part({
			Parent = m,
			Name = "Wall",
			Size = Vector3.new(seg[2], 7, 0.5),
			Position = c + Vector3.new(seg[1], 5.5, -4.25),
			Color = color,
			Material = Enum.Material.Metal,
		})
	end
	ctx.Prop({
		Parent = m,
		Name = "Stripe",
		Size = Vector3.new(24.2, 0.6, 9.2),
		Position = c + Vector3.new(0, 6.6, 0),
		Color = color:Lerp(Color3.fromRGB(120, 60, 50), 0.6),
		Material = Enum.Material.SmoothPlastic,
	})
	ctx.Part({
		Parent = m,
		Name = "Steps",
		Size = Vector3.new(3, 1.6, 2),
		Position = c + Vector3.new(0, 0.8, -5.5),
		Color = Color3.fromRGB(120, 90, 60),
		Material = Enum.Material.WoodPlanks,
	})
	if roofOn then
		roof(ctx, "TrailerRoof", Vector3.new(25, 0.6, 10), c + Vector3.new(0, 9.3, 0), color:Lerp(DARK, 0.3))
	else
		-- The storm took it: a sheet lies crumpled beside the trailer.
		ctx.Prop({
			Parent = m,
			Name = "TornRoof",
			Size = Vector3.new(14, 0.4, 8),
			CFrame = CFrame.new(c + Vector3.new(4, 0.6, 9))
				* CFrame.Angles(math.rad(8), math.rad(20), math.rad(-6)),
			Color = color:Lerp(DARK, 0.3),
			Material = Enum.Material.CorrodedMetal,
		})
	end
	return { c + Vector3.new(-6, 2 + 1.5, 0), c + Vector3.new(6, 2 + 1.5, 1) }, m
end

local function trailerPark(ctx: Context, model: Model): { Vector3 }
	local points = {}
	local min, max = DistrictSouth.TrailersMin, DistrictSouth.TrailersMax
	local mid = (min + max) / 2
	ctx.Prop({
		Parent = model,
		Name = "Loop",
		Size = Vector3.new(max.X - min.X - 16, 0.2, 8),
		Position = Vector3.new(mid.X, 0.12, 170),
		Color = GRAVEL,
		Material = Enum.Material.Pebble,
	})
	local spots = {
		{ Vector3.new(84, 0, 154), true },
		{ Vector3.new(116, 0, 154), true },
		{ Vector3.new(148, 0, 154), false },
		{ Vector3.new(100, 0, 188), true },
		{ Vector3.new(170, 0, 190), true },
	}
	for i, s in spots do
		local c = s[1]
		-- Trailers on the north row face the loop (door to the south): turn them round.
		local list, m = trailer(ctx, model, c, TRAILER[i], s[2])
		if c.Z < 170 then
			m:PivotTo(CFrame.new(c) * CFrame.Angles(0, math.pi, 0) * CFrame.new(-c) * m:GetPivot())
			for k, p in list do
				list[k] = c + (c - p) * Vector3.new(1, 0, 1) + Vector3.new(0, p.Y - c.Y, 0)
			end
		end
		for _, p in list do
			table.insert(points, p)
		end
	end
	-- The tipped trailer.
	ctx.Part({
		Parent = model,
		Name = "TippedTrailer",
		Size = Vector3.new(24, 9, 8),
		CFrame = CFrame.new(186, 4.5, 154) * CFrame.Angles(0, math.rad(-15), math.rad(4)),
		Color = TRAILER[2]:Lerp(DARK, 0.15),
		Material = Enum.Material.CorrodedMetal,
	})
	table.insert(points, Vector3.new(178, 1.5, 164))
	-- Laundry line and the mailbox row.
	for _, x in { 128, 144 } do
		ctx.Prop({
			Parent = model,
			Name = "LinePost",
			Size = Vector3.new(0.4, 6, 0.4),
			Position = Vector3.new(x, 3, 182),
			Color = DARK,
			Material = Enum.Material.Metal,
		})
	end
	ctx.Prop({
		Parent = model,
		Name = "Line",
		Size = Vector3.new(16, 0.1, 0.1),
		Position = Vector3.new(136, 5.8, 182),
		Color = S.White,
	})
	for i, color in { S.Coral, S.Teal, S.Mustard } do
		ctx.Prop({
			Parent = model,
			Name = "Laundry",
			Size = Vector3.new(2, 2.6, 0.1),
			Position = Vector3.new(130 + i * 3.5, 4.5, 182),
			Color = color,
			Material = Enum.Material.Fabric,
			Orientation = Vector3.new(0, 0, (i - 2) * 8),
		})
	end
	for i = 0, 4 do
		ctx.Prop({
			Parent = model,
			Name = "Mailbox",
			Size = Vector3.new(1.2, 1, 1.8),
			Position = Vector3.new(72 + i * 2, 3.5, 168),
			Color = S.Cobalt,
			Material = Enum.Material.Metal,
		})
	end
	ctx.Prop({
		Parent = model,
		Name = "MailboxRail",
		Size = Vector3.new(11, 0.4, 0.4),
		Position = Vector3.new(76, 3, 168),
		Color = DARK,
		Material = Enum.Material.Metal,
	})
	local sign = ctx.Prop({
		Parent = model,
		Name = "ParkSign",
		Size = Vector3.new(14, 3, 0.4),
		Position = Vector3.new(66, 4.5, 172),
		Color = Color3.fromRGB(60, 90, 70),
		Orientation = Vector3.new(0, 90, 0),
	})
	ctx.SurfaceSign(sign, Enum.NormalId.Front, "PINE REST", S.White)
	ctx.SurfaceSign(sign, Enum.NormalId.Back, "PINE REST", S.White)
	return points
end

function DistrictSouth.build(ctx: Context): ({ Vector3 }, { Vector3 })
	local park = Instance.new("Model")
	park.Name = "Ballpark"
	park.Parent = ctx.Map
	local trailers = Instance.new("Model")
	trailers.Name = "TrailerPark"
	trailers.Parent = ctx.Map
	return ballpark(ctx, park), trailerPark(ctx, trailers)
end

return DistrictSouth
