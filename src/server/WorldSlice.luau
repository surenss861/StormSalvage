-- V3 vertical slice (Milestone B): recomposes the Scrapyard, the departure road and Town Square,
-- and gives the town a world edge (terrain hills, tree lines, distant landmarks) instead of a
-- flat lawn that stops at the sky. See docs/art/V3-ART-DIRECTION.md.
--
-- Rules this module keeps (docs/production/V3-PERFORMANCE-BUDGETS.md and the gameplay QA):
--   - Gameplay geometry is untouched: no new roofs in town (shelter is defined by Map.Roofs),
--     nothing on the loot grids, ladders or the ramp surface, nothing in the flood box's terrain
--     (StormService fills and clears terrain water inside |x|,|z| <= 209).
--   - Decoration is CanQuery = false and doesn't cast shadows; only posts, rails and barriers a
--     player could plausibly bump into collide.
--   - Everything weather-reactive is tagged for the client (EnvironmentFX): V3Flag, V3Lamp,
--     V3Bulb, V3PuddleSpot.

local CollectionService = game:GetService("CollectionService")

local Palette = require(game:GetService("ReplicatedStorage").Shared.Palette)

local WorldSlice = {}

export type Context = {
	Map: Model,
	Roofs: Folder,
	Yard: Model,
	Part: (props: { [string]: any }) -> Part,
	Prop: (props: { [string]: any }) -> Part,
	Wedge: (props: { [string]: any }) -> WedgePart,
	PlaceAsset: (set: string, name: string, cf: CFrame, parent: Instance) -> Model?,
	TownAsset: (name: string, cf: CFrame, scale: number?) -> Model?,
	Tree: (pos: Vector3) -> (),
	Bush: (pos: Vector3, s: number) -> (),
	SurfaceSign: (
		target: BasePart,
		face: Enum.NormalId,
		text: string,
		color: Color3,
		font: Enum.Font?
	) -> any,
	StreetLight: (pos: Vector3, facingDir: Vector3?) -> (),
	PlateauTop: number,
	RampStartZ: number,
}

local S = Palette.Swatches
local rng = Random.new(2026)
local ctx: Context
local folder: Folder

-- Decorative part in the slice folder.
local function deco(props: { [string]: any }): Part
	props.Parent = props.Parent or folder
	if props.CanCollide == nil then
		props.CanCollide = false
	end
	return ctx.Prop(props)
end

-- A solid decorative piece players can bump into (posts, rails, barricades). Still invisible
-- to gameplay raycasts.
local function solid(props: { [string]: any }): Part
	props.CanCollide = true
	return deco(props)
end

-- A beam between two points (rails, wires, poles).
local function beam(a: Vector3, b: Vector3, thickness: number, props: { [string]: any }): Part
	props.Size = Vector3.new(thickness, thickness, (b - a).Magnitude)
	props.CFrame = CFrame.lookAt((a + b) / 2, b)
	return deco(props)
end

local function sign(target: BasePart, face: Enum.NormalId, text: string, color: Color3, font: Enum.Font?)
	ctx.SurfaceSign(target, face, text, color, font or Enum.Font.LuckiestGuy)
end

---------------------------------------------------------------------------- Shared kit

-- Festoon lights: a sagging wire with warm bulbs; a couple of bulbs carry a real light.
local function stringLights(a: Vector3, b: Vector3, bulbs: number, sag: number, lit: number?)
	local points = {}
	local segments = math.max(4, bulbs)
	for i = 0, segments do
		local t = i / segments
		local p = a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
		table.insert(points, p)
	end
	for i = 1, #points - 1 do
		beam(
			points[i],
			points[i + 1],
			0.12,
			{ Color = S.HazardBlack, Material = Enum.Material.SmoothPlastic }
		)
	end
	local litEvery = lit and math.max(1, math.floor(bulbs / lit)) or 0
	for i = 1, bulbs do
		local t = (i - 0.5) / bulbs
		local p = a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t) + 0.45, 0)
		local bulb = deco({
			Name = "Bulb",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.6,
			Position = p,
			Color = Color3.fromRGB(255, 214, 140),
			Material = Enum.Material.Neon,
		})
		CollectionService:AddTag(bulb, "V3Bulb")
		if litEvery > 0 and i % litEvery == 0 then
			local light = Instance.new("PointLight")
			light.Range = 18
			light.Brightness = 0.9
			light.Color = Color3.fromRGB(255, 200, 130)
			light.Shadows = false
			light.Parent = bulb
		end
	end
end

-- A pole with a cloth flag that the client flaps in the wind.
local function flagpole(base: Vector3, height: number, color: Color3)
	solid({
		Name = "FlagPole",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 0.4, 0.4),
		CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = S.Steel,
		Material = Enum.Material.Metal,
	})
	local flag = deco({
		Name = "Flag",
		Size = Vector3.new(0.1, 2.6, 4.2),
		CFrame = CFrame.new(base + Vector3.new(0, height - 1.5, 2.2)),
		Color = color,
		Material = Enum.Material.Fabric,
	})
	-- Pivot (the pole edge) for the client's flapping.
	flag:SetAttribute("Hinge", base + Vector3.new(0, height - 1.5, 0))
	CollectionService:AddTag(flag, "V3Flag")
end

-- Hazard stripes painted on the ground along X, between x0 and x1.
local function hazardStripes(x0: number, x1: number, z: number, depth: number, y: number)
	local n = math.floor((x1 - x0) / 2)
	for i = 0, n - 1 do
		deco({
			Size = Vector3.new(1.2, 0.05, depth),
			CFrame = CFrame.new(x0 + 1 + i * 2, y, z) * CFrame.Angles(0, math.rad(35), 0),
			Color = if i % 2 == 0 then S.SafetyYellow else S.HazardBlack,
			Material = Enum.Material.SmoothPlastic,
		})
	end
end

-- A row of sandbags (storm prep), along `dir` from `start`.
local function sandbags(start: Vector3, dir: Vector3, count: number, rows: number)
	local unit = dir.Unit
	local cf = CFrame.lookAt(start, start + unit)
	for r = 0, rows - 1 do
		for i = 0, count - 1 - r do
			solid({
				Name = "Sandbag",
				Size = Vector3.new(1.4, 0.7, 2.2),
				CFrame = cf
					* CFrame.new(0, 0.35 + r * 0.65, -(i * 2.25 + r * 1.1))
					* CFrame.Angles(0, math.rad(rng:NextNumber(-6, 6)), math.rad(rng:NextNumber(-3, 3))),
				Color = Color3.fromRGB(196, 172, 128):Lerp(Color3.fromRGB(150, 128, 92), rng:NextNumber()),
				Material = Enum.Material.Fabric,
			})
		end
	end
end

-- A two-post road sign with text on both faces. `face` is the direction the front looks.
local function postSign(
	base: Vector3,
	face: Vector3,
	width: number,
	height: number,
	lift: number,
	front: string,
	back: string?,
	board: Color3,
	textColor: Color3
)
	local cf = CFrame.lookAt(base, base + face)
	for _, sx in { -1, 1 } do
		solid({
			Name = "SignPost",
			Size = Vector3.new(0.6, lift + height / 2, 0.6),
			CFrame = cf * CFrame.new(sx * (width / 2 - 1.2), (lift + height / 2) / 2, 0.6),
			Color = S.Gunmetal,
			Material = Enum.Material.Metal,
		})
	end
	local panel = deco({
		Name = "SignBoard",
		Size = Vector3.new(width, height, 0.6),
		CFrame = cf * CFrame.new(0, lift + height / 2, 0),
		Color = board,
		Material = Enum.Material.Metal,
	})
	-- Painted trim: a slightly larger frame behind the board.
	deco({
		Size = Vector3.new(width + 0.8, height + 0.8, 0.4),
		CFrame = cf * CFrame.new(0, lift + height / 2, 0.35),
		Color = S.Cream,
		Material = Enum.Material.WoodPlanks,
	})
	sign(panel, Enum.NormalId.Front, front, textColor)
	if back then
		sign(panel, Enum.NormalId.Back, back, textColor)
	end
	return panel
end

-- Ground decal: a thin, non-colliding patch just above the surface at `y`.
local function patch(
	center: Vector3,
	size: Vector2,
	color: Color3,
	material: Enum.Material,
	rotY: number?,
	round: boolean?
)
	if round then
		return deco({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.06, size.X, size.Y),
			CFrame = CFrame.new(center) * CFrame.Angles(0, math.rad(rotY or 0), math.rad(90)),
			Color = color,
			Material = material,
		})
	end
	return deco({
		Size = Vector3.new(size.X, 0.06, size.Y),
		CFrame = CFrame.new(center) * CFrame.Angles(0, math.rad(rotY or 0), 0),
		Color = color,
		Material = material,
	})
end

---------------------------------------------------------------------------- Scrapyard

local function buildScrapyard()
	local top = ctx.PlateauTop
	local yard = ctx.Yard
	local yardFolder = Instance.new("Folder")
	yardFolder.Name = "V3Yard"
	yardFolder.Parent = yard
	local saved = folder
	folder = yardFolder

	-- The yard road: spawn to gate, concrete apron with painted edge lines. The existing pad
	-- (z -282..-248) already covers the counters; the apron fills in front and behind it.
	for _, seg in { { -305, -282 }, { -248, -223 } } do
		local z0, z1 = seg[1], seg[2]
		ctx.Part({
			Parent = folder,
			Name = "YardRoad",
			Size = Vector3.new(22, 0.3, z1 - z0),
			Position = Vector3.new(0, top + 0.15, (z0 + z1) / 2),
			Color = S.Concrete,
			Material = Enum.Material.Concrete,
			CanQuery = true, -- walkable surface (pathfinding and dropped bags rest on it)
			CastShadow = false,
		})
	end
	for _, x in { -10.4, 10.4 } do
		deco({
			Size = Vector3.new(0.6, 0.05, 80),
			Position = Vector3.new(x, top + 0.33, -264),
			Color = S.SafetyYellow,
			Material = Enum.Material.SmoothPlastic,
		})
	end
	hazardStripes(-11, 11, -227, 3.5, top + 0.33)
	-- Painted arrows toward the counters, readable from the spawn.
	for _, info in { { -6, -275, -1 }, { 6, -275, 1 } } do
		local arrow = deco({
			Size = Vector3.new(6, 0.05, 2.2),
			Position = Vector3.new(info[1], top + 0.33, info[2]),
			Color = S.Cream,
			Material = Enum.Material.SmoothPlastic,
		})
		sign(arrow, Enum.NormalId.Top, if info[3] < 0 then "SELL >" else "< GEAR", S.HazardBlack)
	end

	-- Arrival gantry in front of the spawn: the first thing a player sees.
	local gz = -285
	for _, x in { -14, 14 } do
		solid({
			Name = "GantryLeg",
			Size = Vector3.new(1.6, 18, 1.6),
			Position = Vector3.new(x, top + 9, gz),
			Color = S.SafetyYellow,
			Material = Enum.Material.Metal,
		})
		solid({
			Name = "GantryFoot",
			Size = Vector3.new(3, 1, 3),
			Position = Vector3.new(x, top + 0.5, gz),
			Color = S.Concrete,
			Material = Enum.Material.Concrete,
		})
		-- Diagonal bracing, the crane's lattice language at a smaller scale.
		for i = 0, 2 do
			beam(
				Vector3.new(x, top + 2 + i * 5, gz),
				Vector3.new(x, top + 6.5 + i * 5, gz + if i % 2 == 0 then 0.01 else -0.01),
				0.35,
				{ Color = S.HazardBlack, Material = Enum.Material.Metal }
			)
		end
	end
	deco({
		Name = "GantryBeam",
		Size = Vector3.new(31, 1.6, 1.6),
		Position = Vector3.new(0, top + 18.4, gz),
		Color = S.SafetyYellow,
		Material = Enum.Material.Metal,
	})
	local gantrySign = deco({
		Name = "GantrySign",
		Size = Vector3.new(24, 4.4, 0.8),
		Position = Vector3.new(0, top + 15, gz),
		Color = S.HazardBlack,
		Material = Enum.Material.Metal,
	})
	sign(gantrySign, Enum.NormalId.Back, "STORM SALVAGE CO.", S.SafetyYellow)
	sign(gantrySign, Enum.NormalId.Front, "WE BUY WHAT THE STORM LEAVES", S.SafetyYellow)
	for i = 0, 5 do
		local bulb = deco({
			Name = "GantryBulb",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.7,
			Position = Vector3.new(-11 + i * 4.4, top + 12.4, gz + 0.5),
			Color = Color3.fromRGB(255, 214, 140),
			Material = Enum.Material.Neon,
		})
		CollectionService:AddTag(bulb, "V3Bulb")
	end

	-- Festoon lights over the counters: gantry to both shacks and across the aisle.
	stringLights(Vector3.new(-14, top + 16.5, gz), Vector3.new(-29, top + 11.5, -257), 9, 1.4, 2)
	stringLights(Vector3.new(14, top + 16.5, gz), Vector3.new(29, top + 11.5, -257), 9, 1.4, 2)
	for _, x in { -12, 12 } do
		solid({
			Name = "LightPole",
			Size = Vector3.new(0.5, 13, 0.5),
			Position = Vector3.new(x, top + 6.5, -240),
			Color = S.Gunmetal,
			Material = Enum.Material.Metal,
		})
	end
	stringLights(Vector3.new(-12, top + 12.8, -240), Vector3.new(12, top + 12.8, -240), 8, 1.2, 1)

	-- Certified scale in front of the Scrap Buyer: where you stand to sell.
	solid({
		Name = "ScalePlate",
		Size = Vector3.new(8, 0.4, 12),
		Position = Vector3.new(-21, top + 0.5, -265),
		Color = S.Steel,
		Material = Enum.Material.DiamondPlate,
	})
	for _, z in { -271.2, -258.8 } do
		deco({
			Size = Vector3.new(8.4, 0.45, 0.6),
			Position = Vector3.new(-21, top + 0.52, z),
			Color = S.SafetyYellow,
			Material = Enum.Material.SmoothPlastic,
		})
	end
	solid({
		Name = "ScalePost",
		Size = Vector3.new(0.8, 9, 0.8),
		Position = Vector3.new(-25.5, top + 4.5, -274),
		Color = S.Gunmetal,
		Material = Enum.Material.Metal,
	})
	local dial = deco({
		Name = "ScaleDial",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 5, 5),
		CFrame = CFrame.new(-25.5, top + 9.5, -274) * CFrame.Angles(0, math.rad(90), 0),
		Color = S.Cream,
		Material = Enum.Material.SmoothPlastic,
	})
	sign(dial, Enum.NormalId.Right, "KG", S.HazardBlack)
	sign(dial, Enum.NormalId.Left, "KG", S.HazardBlack)
	beam(
		Vector3.new(-25.5, top + 9.5, -274) + Vector3.new(0, 0, 0.35),
		Vector3.new(-25.5, top + 11.2, -273.2) + Vector3.new(0, 0, 0.35),
		0.18,
		{ Color = S.Coral, Material = Enum.Material.Neon }
	)

	-- Workshop lean-to beside the Gear Shop: the mechanic's corner (yard is storm-safe, so its
	-- roof isn't a shelter question).
	local lx0, lx1, lz0, lz1 = 45, 63, -259, -241
	for _, p in { { lx0, lz0 }, { lx1, lz0 }, { lx0, lz1 }, { lx1, lz1 } } do
		solid({
			Name = "LeanToPost",
			Size = Vector3.new(0.8, 12, 0.8),
			Position = Vector3.new(p[1], top + 6, p[2]),
			Color = S.Rust,
			Material = Enum.Material.Metal,
		})
	end
	deco({
		Name = "LeanToRoof",
		Size = Vector3.new(lx1 - lx0 + 3, 0.4, lz1 - lz0 + 3),
		CFrame = CFrame.new((lx0 + lx1) / 2, top + 12.4, (lz0 + lz1) / 2) * CFrame.Angles(math.rad(6), 0, 0),
		Color = S.Rust,
		Material = Enum.Material.CorrodedMetal,
	})
	-- A patch panel in a different colour: storm repair.
	deco({
		Size = Vector3.new(6, 0.45, 5),
		CFrame = CFrame.new(50, top + 12.75, -247) * CFrame.Angles(math.rad(6), 0, 0),
		Color = S.ContainerBlue,
		Material = Enum.Material.Metal,
	})
	ctx.PlaceAsset(
		"scrapyard",
		"TireStack",
		CFrame.new(60, top, -255) * CFrame.Angles(0, math.rad(15), 0),
		folder
	)
	ctx.PlaceAsset(
		"scrapyard",
		"OilDrums",
		CFrame.new(59, top, -244) * CFrame.Angles(0, math.rad(-35), 0),
		folder
	)
	local lamp = deco({
		Name = "WorkLamp",
		Size = Vector3.new(1.4, 0.5, 1.4),
		Position = Vector3.new(54, top + 11.6, -250),
		Color = Color3.fromRGB(255, 226, 170),
		Material = Enum.Material.Neon,
	})
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Range = 18
	light.Angle = 80
	light.Brightness = 1.6
	light.Color = Color3.fromRGB(255, 220, 160)
	light.Shadows = false
	light.Parent = lamp
	CollectionService:AddTag(lamp, "V3Lamp")

	-- Front corners: container stacks and a scrap wall frame the gate approach so the yard
	-- reads as enclosed, not a plateau with props on it.
	ctx.PlaceAsset(
		"scrapyard",
		"Container",
		CFrame.new(62, top, -236) * CFrame.Angles(0, math.rad(90), 0),
		folder
	)
	ctx.PlaceAsset(
		"scrapyard",
		"Container",
		CFrame.new(64, top + 8.5, -237) * CFrame.Angles(0, math.rad(84), 0),
		folder
	)
	ctx.PlaceAsset(
		"scrapyard",
		"PalletStack",
		CFrame.new(46, top, -232) * CFrame.Angles(0, math.rad(-12), 0),
		folder
	)
	ctx.PlaceAsset(
		"scrapyard",
		"TireStack",
		CFrame.new(-34, top, -230) * CFrame.Angles(0, math.rad(70), 0),
		folder
	)
	local pile = ctx.PlaceAsset(
		"scrapyard",
		"ScrapPile",
		CFrame.new(-60, top, -252) * CFrame.Angles(0, math.rad(140), 0),
		folder
	)
	if pile then
		pile:ScaleTo(0.9)
	end

	-- Ground wear: tyre tracks, oil stains and darker dirt patches break up the flat plateau.
	local dirt = S.RustDark:Lerp(S.Sand, 0.3)
	for _, info in
		{
			{ Vector3.new(-40, 0, -300), Vector2.new(18, 26), 20 },
			{ Vector3.new(36, 0, -298), Vector2.new(22, 18), -15 },
			{ Vector3.new(-62, 0, -236), Vector2.new(16, 12), 40 },
			{ Vector3.new(30, 0, -232), Vector2.new(14, 10), -30 },
			{ Vector3.new(-6, 0, -318), Vector2.new(30, 10), 5 },
		}
	do
		patch(
			Vector3.new(info[1].X, top + 0.24, info[1].Z),
			info[2],
			dirt,
			Enum.Material.Ground,
			info[3],
			true
		)
	end
	for _, pos in
		{
			Vector3.new(-46, 0, -296),
			Vector3.new(-30, 0, -310),
			Vector3.new(40, 0, -306),
			Vector3.new(52, 0, -250),
		}
	do
		patch(
			Vector3.new(pos.X, top + 0.26, pos.Z),
			Vector2.new(rng:NextNumber(3, 6), rng:NextNumber(3, 6)),
			Color3.fromRGB(28, 26, 30),
			Enum.Material.SmoothPlastic,
			rng:NextNumber(0, 180),
			true
		)
	end
	for _, x in { -3.5, 3.5 } do
		deco({
			Size = Vector3.new(1.6, 0.05, 40),
			Position = Vector3.new(x - 40, top + 0.25, -300),
			Color = dirt:Lerp(Color3.new(0, 0, 0), 0.25),
			Material = Enum.Material.Ground,
			Orientation = Vector3.new(0, 25, 0),
		})
	end

	-- Flags on the gate approach: the wind's direction is visible from the yard.
	flagpole(Vector3.new(-20, top, -226), 14, S.Coral)
	flagpole(Vector3.new(20, top, -226), 14, S.SafetyYellow)

	folder = saved
end

---------------------------------------------------------------------------- Departure road

local function rampHeight(z: number): number
	-- The ramp falls from the plateau edge (RampStartZ, 30) to z + 80 (0).
	return ctx.PlateauTop * math.clamp((ctx.RampStartZ + 80 - z) / 80, 0, 1)
end

local function buildRoad()
	local z0, z1 = ctx.RampStartZ, ctx.RampStartZ + 80

	-- The ramp becomes a built embankment: concrete retaining walls on both sides.
	for _, sx in { -1, 1 } do
		local w = ctx.Wedge({
			Parent = folder,
			Name = "RampWall",
			Size = Vector3.new(1.6, ctx.PlateauTop, 80),
			CFrame = CFrame.new(sx * 12.8, ctx.PlateauTop / 2, (z0 + z1) / 2) * CFrame.Angles(0, math.pi, 0),
			Color = S.Concrete,
			Material = Enum.Material.Concrete,
			CastShadow = false,
		})
		w.CanQuery = false
		-- Guard rail along the top of the wall: posts and a two-bar rail.
		for z = z0 + 3, z1 - 2, 8 do
			local y = rampHeight(z)
			solid({
				Name = "RailPost",
				Size = Vector3.new(0.5, 3.4, 0.5),
				Position = Vector3.new(sx * 12.8, y + 1.5, z),
				Color = S.Steel,
				Material = Enum.Material.Metal,
			})
		end
		for _, h in { 2.6, 1.5 } do
			local a = Vector3.new(sx * 12.8, rampHeight(z0 + 1) + h, z0 + 1)
			local b = Vector3.new(sx * 12.8, rampHeight(z1 - 1) + h, z1 - 1)
			local rail = beam(a, b, 0.4, { Color = S.Steel, Material = Enum.Material.Metal })
			rail.CanCollide = true
		end
		-- Chevron boards at the bottom of the ramp.
		local chevron = deco({
			Size = Vector3.new(0.4, 2.4, 3.2),
			Position = Vector3.new(sx * 13.4, 2.4, z1 - 2),
			Color = S.SafetyYellow,
			Material = Enum.Material.SmoothPlastic,
		})
		sign(chevron, if sx < 0 then Enum.NormalId.Right else Enum.NormalId.Left, ">>", S.HazardBlack)
		sign(chevron, Enum.NormalId.Back, "SLOW", S.HazardBlack)
	end

	-- Welcome billboard at the foot of the ramp, readable on the way down; the back points
	-- the way home.
	postSign(
		Vector3.new(-36, 0, -178),
		Vector3.new(0.25, 0, -1),
		26,
		9,
		8,
		"WELCOME TO GALE HOLLOW\nStorm Capital of the County",
		"SCRAPYARD  ^\nSell your salvage up the hill",
		S.Teal,
		S.Cream
	)

	-- Bud's Towing: a fenced lot of storm-wrecked cars east of the ramp.
	local tx0, tx1, tz0, tz1 = 38, 96, -206, -166
	local function fence(a: Vector3, b: Vector3, gapCenter: number?)
		local len = (b - a).Magnitude
		local dir = (b - a).Unit
		local n = math.floor(len / 6)
		for i = 0, n do
			local p = a + dir * (len * i / n)
			if not (gapCenter and math.abs(i * len / n - gapCenter) < 6) then
				solid({
					Name = "FencePost",
					Size = Vector3.new(0.5, 6, 0.5),
					Position = p + Vector3.new(0, 3, 0),
					Color = S.Steel,
					Material = Enum.Material.Metal,
				})
			end
		end
		for _, h in { 5.6, 3, 0.6 } do
			if gapCenter then
				local gapA = a + dir * (gapCenter - 6)
				local gapB = a + dir * (gapCenter + 6)
				beam(
					a + Vector3.new(0, h, 0),
					gapA + Vector3.new(0, h, 0),
					0.2,
					{ Color = S.Steel, Material = Enum.Material.Metal }
				).CanCollide =
					true
				beam(
					gapB + Vector3.new(0, h, 0),
					b + Vector3.new(0, h, 0),
					0.2,
					{ Color = S.Steel, Material = Enum.Material.Metal }
				).CanCollide =
					true
			else
				beam(
					a + Vector3.new(0, h, 0),
					b + Vector3.new(0, h, 0),
					0.2,
					{ Color = S.Steel, Material = Enum.Material.Metal }
				).CanCollide =
					true
			end
		end
	end
	fence(Vector3.new(tx0, 0, tz0), Vector3.new(tx1, 0, tz0))
	fence(Vector3.new(tx1, 0, tz0), Vector3.new(tx1, 0, tz1))
	fence(Vector3.new(tx1, 0, tz1), Vector3.new(tx0, 0, tz1))
	fence(Vector3.new(tx0, 0, tz1), Vector3.new(tx0, 0, tz0), 20) -- gate on the road side
	patch(
		Vector3.new((tx0 + tx1) / 2, 0.04, (tz0 + tz1) / 2),
		Vector2.new(tx1 - tx0, tz1 - tz0),
		S.Stone,
		Enum.Material.Pebble
	)
	for _, info in
		{
			{ Vector3.new(52, 0, -196), 30 },
			{ Vector3.new(70, 0, -192), -60 },
			{ Vector3.new(86, 0, -180), 100 },
			{ Vector3.new(62, 0, -176), 160 },
		}
	do
		ctx.PlaceAsset(
			"scrapyard",
			"Wreck",
			CFrame.new(info[1]) * CFrame.Angles(0, math.rad(info[2]), 0),
			folder
		)
	end
	ctx.PlaceAsset(
		"scrapyard",
		"TireStack",
		CFrame.new(90, 0, -200) * CFrame.Angles(0, math.rad(20), 0),
		folder
	)
	postSign(
		Vector3.new(36, 0, -172),
		Vector3.new(-1, 0, 0),
		12,
		4,
		6,
		"BUD'S TOWING",
		"BUD'S TOWING",
		S.Mustard,
		S.HazardBlack
	)

	-- West of the ramp: a worn path from the side stairs to Town Square through a tree grove.
	local path = {
		Vector3.new(-70, 0, -158),
		Vector3.new(-72, 0, -140),
		Vector3.new(-76, 0, -122),
		Vector3.new(-72, 0, -106),
	}
	for i = 1, #path - 1 do
		local a, b = path[i], path[i + 1]
		deco({
			Name = "Footpath",
			Size = Vector3.new(5, 0.06, (b - a).Magnitude + 3),
			CFrame = CFrame.lookAt((a + b) / 2 + Vector3.new(0, 0.04, 0), b + Vector3.new(0, 0.04, 0)),
			Color = S.Sand:Lerp(S.Bark, 0.35),
			Material = Enum.Material.Ground,
		})
	end
	-- Tree clusters frame the road but leave the gate-to-clock-tower sightline open
	-- (roughly x -35..-10 between the ramp and the square).
	for _, pos in
		{
			Vector3.new(-96, 0, -176),
			Vector3.new(-104, 0, -164),
			Vector3.new(-92, 0, -134),
			Vector3.new(-108, 0, -124),
			Vector3.new(-54, 0, -176),
			Vector3.new(-48, 0, -150),
			Vector3.new(30, 0, -152),
			Vector3.new(108, 0, -186),
			Vector3.new(118, 0, -170),
			Vector3.new(132, 0, -196),
		}
	do
		ctx.Tree(pos)
	end
	for _, pos in
		{
			Vector3.new(-62, 0, -160),
			Vector3.new(-80, 0, -150),
			Vector3.new(-84, 0, -118),
			Vector3.new(-60, 0, -128),
			Vector3.new(24, 0, -146),
			Vector3.new(102, 0, -176),
		}
	do
		ctx.Bush(pos, rng:NextNumber(3.5, 5))
	end
	-- Darker grass patches so the lawn isn't one flat colour.
	for _, info in
		{
			{ Vector3.new(-100, 0, -150), Vector2.new(46, 60) },
			{ Vector3.new(110, 0, -150), Vector2.new(60, 70) },
			{ Vector3.new(-160, 0, -150), Vector2.new(50, 80) },
			{ Vector3.new(160, 0, -160), Vector2.new(60, 60) },
		}
	do
		patch(
			info[1] + Vector3.new(0, 0.03, 0),
			info[2],
			S.GrassDark,
			Enum.Material.Grass,
			rng:NextNumber(0, 40),
			true
		)
	end
	-- Puddle spots for after a flood (client shows them).
	for _, pos in { Vector3.new(6, 0.25, -128), Vector3.new(-5, 0.25, -96), Vector3.new(8, 0.25, -60) } do
		local spot = deco({ Name = "PuddleSpot", Size = Vector3.one, Position = pos, Transparency = 1 })
		CollectionService:AddTag(spot, "V3PuddleSpot")
	end
end

---------------------------------------------------------------------------- Town Square

local function buildSquare()
	-- The square becomes a paved town centre, not a pad on a lawn: warm paving from the clock
	-- tower to the cross road and out to the siren and statue.
	ctx.Part({
		Parent = folder,
		Name = "SquarePaving",
		Size = Vector3.new(78, 0.1, 82),
		Position = Vector3.new(-57, 0.05, -60),
		Color = Color3.fromRGB(196, 178, 150),
		Material = Enum.Material.Pavement,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	-- Stone curb framing the plaza (low: 0.35 above the plaza, players step over it).
	local function curb(pos: Vector3, size: Vector3)
		deco({
			Name = "PlazaCurb",
			Size = size,
			Position = pos,
			Color = S.Stone,
			Material = Enum.Material.Concrete,
			CanCollide = true,
		})
	end
	for _, z in { -84.4, -25.6 } do
		curb(Vector3.new(-50, 0.58, z), Vector3.new(60, 0.35, 1.2))
	end
	for _, x in { -79.4, -20.6 } do
		curb(Vector3.new(x, 0.58, -55), Vector3.new(1.2, 0.35, 57.6))
	end

	-- Corner lamps with festoon lights crossing high over the plaza (above the fountain spray).
	local corners = {
		Vector3.new(-83, 0, -88),
		Vector3.new(-18.5, 0, -88),
		Vector3.new(-18.5, 0, -22),
		Vector3.new(-83, 0, -22),
	}
	for _, c in corners do
		solid({
			Name = "FestoonPole",
			Size = Vector3.new(0.6, 17, 0.6),
			Position = c + Vector3.new(0, 8.5, 0),
			Color = S.HazardBlack,
			Material = Enum.Material.Metal,
		})
		deco({
			Name = "FestoonCap",
			Size = Vector3.new(1.2, 0.6, 1.2),
			Position = c + Vector3.new(0, 17.2, 0),
			Color = S.SafetyYellow,
			Material = Enum.Material.Metal,
		})
	end
	local h = Vector3.new(0, 16.6, 0)
	stringLights(corners[1] + h, corners[3] + h, 14, 2, 2)
	stringLights(corners[2] + h, corners[4] + h, 14, 2, 2)
	for i = 1, 4 do
		stringLights(corners[i] + h, corners[i % 4 + 1] + h, 10, 1.2, 1)
	end

	-- Storm prep: sandbags at the siren tower and the statue, and a shelter sign that points
	-- to real cover (the gas station canopy, west).
	sandbags(Vector3.new(-86.5, 0, -33), Vector3.new(0, 0, -1), 5, 2)
	sandbags(Vector3.new(-86.5, 0, -88), Vector3.new(0, 0, 1), 4, 2)
	postSign(
		Vector3.new(-90, 0, -58),
		Vector3.new(1, 0, 0),
		10,
		3.4,
		5,
		"< STORM SHELTER\nFUEL & GO CANOPY",
		nil,
		S.Coral,
		S.Cream
	)
	-- Boarded panels leaning on the clock tower base: the last storm cracked its windows.
	for i, x in { -55, -45 } do
		deco({
			Name = "Boards",
			Size = Vector3.new(4, 6, 0.4),
			CFrame = CFrame.new(x, 3, -91.5) * CFrame.Angles(math.rad(-12), math.rad(i == 1 and 8 or -6), 0),
			Color = S.Bark:Lerp(S.Sand, 0.4),
			Material = Enum.Material.WoodPlanks,
		})
	end
	-- Planting along the west edge, between the siren and the statue.
	for _, z in { -72, -62, -50 } do
		ctx.Bush(Vector3.new(-87, 0, z), rng:NextNumber(3, 4))
	end
	for _, pos in { Vector3.new(-8, 0.25, -40), Vector3.new(-50, 0.45, -18) } do
		local spot = deco({ Name = "PuddleSpot", Size = Vector3.one, Position = pos, Transparency = 1 })
		CollectionService:AddTag(spot, "V3PuddleSpot")
	end
end

---------------------------------------------------------------------------- World edge

local TOWN = 210

local function terrainHeight(x: number, z: number): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -400, 0), params)
	return hit and hit.Position.Y
end

local function buildWorldEdge()
	local terrain = workspace.Terrain
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(104, 150, 70))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(120, 96, 70))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(118, 108, 100))
	local edge = Instance.new("Folder")
	edge.Name = "V3Backdrop"
	edge.Parent = ctx.Map

	-- Ground skirt: hides the seam between the town's ground part and the terrain.
	ctx.Prop({
		Parent = edge,
		Name = "GroundSkirt",
		Size = Vector3.new(TOWN * 2 + 40, 2, TOWN * 2 + 40),
		Position = Vector3.new(0, -1.1, 0),
		Color = Color3.fromRGB(88, 135, 72),
		Material = Enum.Material.Grass,
		CanCollide = false,
	})

	-- Flat terrain ground outside the town (never inside the flood box, |x|,|z| <= 209).
	local far = 760
	local inner = TOWN + 4
	for _, block in
		{
			{ Vector3.new(-(inner + far) / 2, -4, 0), Vector3.new(far - inner, 8, far * 2) },
			{ Vector3.new((inner + far) / 2, -4, 0), Vector3.new(far - inner, 8, far * 2) },
			{ Vector3.new(0, -4, (inner + far) / 2), Vector3.new(inner * 2, 8, far - inner) },
			{ Vector3.new(0, -4, -(344 + far) / 2), Vector3.new(inner * 2, 8, far - 344) }, -- meets NorthGround (-345)
		}
	do
		terrain:FillBlock(CFrame.new(block[1]), block[2], Enum.Material.Grass)
	end

	-- Rolling hills in two rings: low near the town, taller further out, so the horizon has
	-- layers. Centres sit below ground so only the caps show.
	local function inTown(x: number, z: number, r: number): boolean
		-- Keep each hill clear of the playable box (and the plateau's back wall).
		return math.abs(x) < TOWN + r * 0.6 and z > -350 - r * 0.6 and z < TOWN + r * 0.6
	end
	local placed = 0
	for ring, info in { { 270, 34, 52, 26 }, { 420, 60, 110, 18 } } do
		local radius, rMin, rMax, count = info[1], info[2], info[3], info[4]
		for i = 1, count do
			local angle = (i / count) * math.pi * 2 + rng:NextNumber(-0.12, 0.12)
			local dist = radius + rng:NextNumber(-30, 50)
			local r = rng:NextNumber(rMin, rMax)
			local x, z = math.cos(angle) * dist, math.sin(angle) * dist - 60
			if not inTown(x, z, r) then
				local material = if ring == 2 and rng:NextNumber() < 0.35
					then Enum.Material.Rock
					else Enum.Material.Grass
				terrain:FillBall(Vector3.new(x, -r * 0.55, z), r, material)
				placed += 1
			end
		end
		task.wait() -- let the server breathe between rings
	end

	-- Tree lines on the near hills; far fewer on the distant ring. Named apart from town trees
	-- so the client's wind sway ignores them (they're too far to see sway).
	local trees = 0
	local source = game:GetService("ServerStorage"):FindFirstChild("Assets")
	source = source and source:FindFirstChild("town")
	local treeModel = source and source:FindFirstChild("TreeBlocky")
	if treeModel then
		for _ = 1, 70 do
			local angle = rng:NextNumber(0, math.pi * 2)
			local dist = rng:NextNumber(232, 330)
			local x, z = math.cos(angle) * dist, math.sin(angle) * dist - 40
			if not inTown(x, z, 12) then
				local y = terrainHeight(x, z)
				if y then
					local tree = treeModel:Clone()
					tree.Name = "BackdropTree"
					tree:PivotTo(CFrame.new(x, y - 0.5, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
					tree:ScaleTo(rng:NextNumber(1.3, 2.3))
					for _, p in tree:GetDescendants() do
						if p:IsA("BasePart") then
							p.CastShadow = false
							p.CanCollide = false
							p.CanQuery = false
							p.CanTouch = false
						end
					end
					tree.Parent = edge
					trees += 1
				end
			end
		end
	end

	-- Distant landmarks: the town water tower and a line of power pylons.
	local wx, wz = -330, 240
	local wy = terrainHeight(wx, wz) or 0
	for _, o in { Vector3.new(-6, 0, -6), Vector3.new(6, 0, -6), Vector3.new(-6, 0, 6), Vector3.new(6, 0, 6) } do
		beam(
			Vector3.new(wx, wy, wz) + o * 1.3,
			Vector3.new(wx, wy + 34, wz) + o * 0.8,
			1.2,
			{ Parent = edge, Color = S.Steel, Material = Enum.Material.Metal }
		)
	end
	local tank = ctx.Prop({
		Parent = edge,
		Name = "WaterTower",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(16, 22, 22),
		CFrame = CFrame.new(wx, wy + 42, wz) * CFrame.Angles(0, math.rad(-40), math.rad(90)),
		Color = S.Cream,
		Material = Enum.Material.Metal,
	})
	sign(tank, Enum.NormalId.Front, "GALE HOLLOW", S.Coral)
	ctx.Prop({
		Parent = edge,
		Name = "WaterTowerRoof",
		Size = Vector3.new(22, 4, 22),
		CFrame = CFrame.new(wx, wy + 52, wz),
		Shape = Enum.PartType.Ball,
		Color = S.Coral,
		Material = Enum.Material.Metal,
	})
	local previous: Vector3? = nil
	for i = 0, 5 do
		local px, pz = 260 + i * 60, -380 + i * 70
		local py = terrainHeight(px, pz) or 0
		for _, sx in { -1, 1 } do
			beam(
				Vector3.new(px + sx * 5, py, pz),
				Vector3.new(px + sx * 1.2, py + 40, pz),
				0.9,
				{ Parent = edge, Color = S.Steel, Material = Enum.Material.Metal }
			)
		end
		ctx.Prop({
			Parent = edge,
			Size = Vector3.new(16, 0.8, 0.8),
			Position = Vector3.new(px, py + 36, pz),
			Color = S.Steel,
			Material = Enum.Material.Metal,
		})
		local topPoint = Vector3.new(px, py + 36, pz)
		if previous then
			for _, dx in { -7, 7 } do
				beam(previous + Vector3.new(dx, -0.6, 0), topPoint + Vector3.new(dx, -0.6, 0), 0.15, {
					Parent = edge,
					Color = Color3.fromRGB(30, 30, 34),
					Material = Enum.Material.SmoothPlastic,
				})
			end
		end
		previous = topPoint
	end
	edge:SetAttribute("Hills", placed)
	edge:SetAttribute("Trees", trees)
end

---------------------------------------------------------------------------- Build

function WorldSlice.build(c: Context)
	ctx = c
	folder = Instance.new("Folder")
	folder.Name = "V3Slice"
	folder.Parent = c.Map
	buildScrapyard()
	buildRoad()
	buildSquare()
	buildWorldEdge()
end

return WorldSlice
