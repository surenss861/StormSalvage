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
			0.07,
			{ Color = Color3.fromRGB(52, 50, 56), Material = Enum.Material.SmoothPlastic }
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

-- Swaps in the Blender hero assets (assets/roblox/v3hero, imported through Studio's 3D Importer)
-- where they exist. Until then the primitive versions stay as fallbacks.
local function heroSource(name: string): Model?
	local assets = game:GetService("ServerStorage"):FindFirstChild("Assets")
	local set = assets and assets:FindFirstChild("v3hero")
	local source = set and set:FindFirstChild(name)
	return if source and source:IsA("Model") then source else nil
end

local function placeHero(name: string, cf: CFrame, parent: Instance): Model?
	local source = heroSource(name)
	if not source then
		return nil
	end
	local model = source:Clone()
	model:PivotTo(cf)
	model.Parent = parent
	-- Neon bulbs join the festoon flicker and lightning shorts.
	for _, d in model:GetDescendants() do
		if
			d:IsA("BasePart")
			and d.Material == Enum.Material.Neon
			and string.find(d.Name, "WindowWarm", 1, true)
		then
			CollectionService:AddTag(d, "V3Bulb")
		end
	end
	return model
end

-- A row of sandbags (storm prep), along `dir` from `start`.
local function sandbags(start: Vector3, dir: Vector3, count: number, rows: number)
	local unit = dir.Unit
	local cf = CFrame.lookAt(start, start + unit)
	if heroSource("SandbagWall") then
		-- Blender wall sections (two courses, 7.4 studs) laid end to end along the run.
		local sections = math.max(1, math.floor(count * 2.25 / 7.4 + 0.5))
		for i = 0, sections - 1 do
			placeHero(
				"SandbagWall",
				cf
					* CFrame.new(0, 0, -(i * 7.4 + 3.7))
					* CFrame.Angles(0, math.pi / 2 + math.rad(rng:NextNumber(-4, 4)), 0),
				folder
			)
		end
		return
	end
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

-- Builds `fn`'s pieces into a named sub-folder, so a hero asset can replace the whole set.
local function group(name: string, fn: () -> ()): Folder
	local sub = Instance.new("Folder")
	sub.Name = name
	sub.Parent = folder
	local saved = folder
	folder = sub
	fn()
	folder = saved
	return sub
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
	-- Arrival gantry in front of the spawn: the first thing a player sees.
	local gz = -285
	group("GantryPrimitive", function()
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
		sign(gantrySign, Enum.NormalId.Front, "STORM SALVAGE CO.", S.SafetyYellow)
		sign(gantrySign, Enum.NormalId.Back, "WE BUY WHAT THE STORM LEAVES", S.SafetyYellow)
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
	end)

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

	-- Certified scale in front of the Scrap Buyer: where you stand to sell. Flush with the pad
	-- and non-colliding, so the selling spot has no new step (a raised plate here made the QA
	-- bot's approach fail and wander behind the counter).
	deco({
		Name = "ScalePlate",
		Size = Vector3.new(8, 0.06, 12),
		Position = Vector3.new(-21, top + 0.33, -265),
		Color = S.Steel,
		Material = Enum.Material.DiamondPlate,
	})
	for _, z in { -271.2, -258.8 } do
		deco({
			Size = Vector3.new(8.4, 0.08, 0.6),
			Position = Vector3.new(-21, top + 0.35, z),
			Color = S.SafetyYellow,
			Material = Enum.Material.SmoothPlastic,
		})
	end
	group("ScaleDialPrimitive", function()
		solid({
			Name = "ScalePost",
			Size = Vector3.new(0.6, 5, 0.6),
			Position = Vector3.new(-25.5, top + 2.5, -273),
			Color = S.Gunmetal,
			Material = Enum.Material.Metal,
		})
		local dial = deco({
			Name = "ScaleDial",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.5, 3, 3),
			CFrame = CFrame.new(-25.5, top + 6, -273) * CFrame.Angles(0, math.rad(90), 0),
			Color = S.Cream,
			Material = Enum.Material.SmoothPlastic,
		})
		sign(dial, Enum.NormalId.Right, "KG", S.HazardBlack)
		sign(dial, Enum.NormalId.Left, "KG", S.HazardBlack)
		beam(
			Vector3.new(-25.5, top + 6, -273) + Vector3.new(0, 0, 0.3),
			Vector3.new(-25.5, top + 7, -272.5) + Vector3.new(0, 0, 0.3),
			0.14,
			{ Color = S.Coral, Material = Enum.Material.Neon }
		)
	end)

	-- Workshop lean-to beside the Gear Shop: the mechanic's corner (yard is storm-safe, so its
	-- roof isn't a shelter question).
	group("LeanToPrimitive", function()
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
			CFrame = CFrame.new((lx0 + lx1) / 2, top + 12.4, (lz0 + lz1) / 2)
				* CFrame.Angles(math.rad(6), 0, 0),
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
	end)

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
	-- Close to the yard floor colour (MapBuilder: RustDark -> Sand 0.45) so patches read as wear,
	-- not holes.
	local floor = S.RustDark:Lerp(S.Sand, 0.45)
	local dirt = floor:Lerp(S.RustDark, 0.3)
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
			Vector2.new(rng:NextNumber(2, 3.5), rng:NextNumber(2, 3.5)),
			floor:Lerp(Color3.new(0, 0, 0), 0.4),
			Enum.Material.SmoothPlastic,
			rng:NextNumber(0, 180),
			true
		)
	end
	for _, x in { -3.5, 3.5 } do
		deco({
			Size = Vector3.new(1.6, 0.05, 40),
			Position = Vector3.new(x - 40, top + 0.25, -300),
			Color = dirt:Lerp(Color3.new(0, 0, 0), 0.12),
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
		-- W-beam guard rail along the top of the wall, matching the GuardRail kit piece but built
		-- here so the posts stay upright while the beam follows the slope.
		local inward = -sx * 0.45 -- the beam and blocks sit on the road side of the posts
		for z = z0 + 3, z1 - 2, 8 do
			local y = rampHeight(z)
			solid({
				Name = "RailPost",
				Size = Vector3.new(0.45, 2.9, 0.45),
				Position = Vector3.new(sx * 12.8, y + 1.3, z),
				Color = S.Gunmetal,
				Material = Enum.Material.Metal,
			})
			deco({
				Name = "RailBlock",
				Size = Vector3.new(0.5, 0.7, 0.4),
				Position = Vector3.new(sx * 12.8 + inward, y + 2, z),
				Color = S.Gunmetal,
				Material = Enum.Material.Metal,
			})
			deco({
				Name = "RailReflector",
				Size = Vector3.new(0.1, 0.18, 0.25),
				Position = Vector3.new(sx * 12.8 + inward * 2.3, y + 1.95, z),
				Color = S.SafetyYellow,
				Material = Enum.Material.Neon,
			})
		end
		for _, info in { { 2.25, 0.32 }, { 1.95, 0.42 }, { 1.65, 0.32 } } do
			local x = sx * 12.8 + inward * 1.8
			local a = Vector3.new(x, rampHeight(z0 + 1) + info[1], z0 + 1)
			local b = Vector3.new(x, rampHeight(z1 - 1) + info[1], z1 - 1)
			local rail = deco({
				Name = "RailBeam",
				Size = Vector3.new(0.3, info[2], (b - a).Magnitude),
				CFrame = CFrame.lookAt((a + b) / 2, b),
				Color = S.Steel,
				-- Smooth galvanised finish: the Metal variant's streaks get noisy over an 80-stud beam.
				Material = Enum.Material.SmoothPlastic,
				Reflectance = 0.12,
			})
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

	-- Stone side walls on the side stairs (V2 left both sides open): a finished edge, and the
	-- pathfinder stops routing up the sheer side faces, which the QA bot got stuck on.
	for i = 0, ctx.PlateauTop - 1 do
		local z = z0 + 1 + 2 * (ctx.PlateauTop - 1 - i)
		local h = i + 1
		for _, x in { -76.4, -63.6 } do
			deco({
				Name = "StairWall",
				Size = Vector3.new(0.8, h + 2.6, 2),
				Position = Vector3.new(x, (h + 2.6) / 2, z),
				Color = S.Stone,
				Material = Enum.Material.Concrete,
				CanCollide = true,
			})
		end
	end

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
		-- Non-colliding: the NE pole sits on the walking line between the square and the ramp,
		-- and the QA bot wedged itself against it on the way to sell.
		deco({
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
	group("ClockBoardsPrimitive", function()
		for i, x in { -55, -45 } do
			deco({
				Name = "Boards",
				Size = Vector3.new(4, 6, 0.4),
				CFrame = CFrame.new(x, 3, -91.5)
					* CFrame.Angles(math.rad(-12), math.rad(i == 1 and 8 or -6), 0),
				Color = S.Bark:Lerp(S.Sand, 0.4),
				Material = Enum.Material.WoodPlanks,
			})
		end
	end)
	-- Planting along the west edge, between the siren and the statue.
	for _, z in { -72, -62, -50 } do
		ctx.Bush(Vector3.new(-87, 0, z), rng:NextNumber(3, 4))
	end
	for _, pos in { Vector3.new(-8, 0.25, -40), Vector3.new(-50, 0.45, -18) } do
		local spot = deco({ Name = "PuddleSpot", Size = Vector3.one, Position = pos, Transparency = 1 })
		CollectionService:AddTag(spot, "V3PuddleSpot")
	end
end

---------------------------------------------------------------------------- Roadside midground

-- Breaks up the open lawn either side of the departure road with deliberate pieces: grass
-- banks with stone retaining walls, a fenced utility substation, a storm-wrecked billboard and a
-- couple of dense tree groups. Everything stays clear of the tow-yard gate, the footpath and the
-- road. All of it is parts (terrain inside the town would be wiped by the flood).
local function bank(x0: number, x1: number, z0: number, z1: number, height: number, wallSide: number)
	-- A grass berm rising away from the road, faced on the road side by a low stone wall.
	local w, d = x1 - x0, z1 - z0
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local slope = ctx.Wedge({
		Parent = folder,
		Name = "Bank",
		Size = Vector3.new(d, height, w),
		-- the wedge's tall end faces local +Z; turned so it's tall at the wall
		CFrame = CFrame.new(cx, height / 2, cz) * CFrame.Angles(0, math.rad(wallSide > 0 and 90 or -90), 0),
		Color = S.GrassDark:Lerp(S.Grass, 0.5),
		Material = Enum.Material.Grass,
		CastShadow = false,
	})
	slope.CanQuery = false
	local wx = if wallSide > 0 then x1 else x0
	deco({
		Name = "RetainingWall",
		Size = Vector3.new(1.2, height + 0.6, d),
		Position = Vector3.new(wx, (height + 0.6) / 2, cz),
		Color = S.Stone,
		Material = Enum.Material.Concrete,
		CanCollide = true,
	})
	deco({
		Name = "WallCap",
		Size = Vector3.new(1.6, 0.4, d + 0.4),
		Position = Vector3.new(wx, height + 0.8, cz),
		Color = S.Concrete,
		Material = Enum.Material.Concrete,
	})
end

local function grove(center: Vector3, trees: number, bushes: number, spread: number)
	for i = 1, trees do
		local a = (i / trees) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local r = rng:NextNumber(spread * 0.2, spread)
		ctx.Tree(center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
	end
	for _ = 1, bushes do
		ctx.Bush(
			center + Vector3.new(rng:NextNumber(-spread, spread), 0, rng:NextNumber(-spread, spread)),
			rng:NextNumber(3, 5)
		)
	end
end

local function buildRoadside()
	-- Banks: east (between road and tow yard, gap left at the tow-yard gate z -192..-180) and
	-- west (stopping short of the footpath at x -70).
	bank(22, 33, -210, -194, 2.6, -1)
	bank(22, 33, -178, -150, 2.2, -1)
	bank(-40, -26, -205, -160, 2.4, 1)

	-- Utility substation west of the road: fenced transformer yard with a corrugated hut.
	local sx, sz = -56, -194
	deco({
		Name = "SubstationPad",
		Size = Vector3.new(16, 0.4, 12),
		Position = Vector3.new(sx, 0.2, sz),
		Color = S.Concrete,
		Material = Enum.Material.Concrete,
		CanCollide = true,
	})
	solid({
		Name = "Hut",
		Size = Vector3.new(6, 6, 5),
		Position = Vector3.new(sx - 4, 3.4, sz + 2),
		Color = S.ContainerGreen,
		Material = Enum.Material.Metal,
	})
	deco({
		Name = "HutRoof",
		Size = Vector3.new(7, 0.4, 6),
		CFrame = CFrame.new(sx - 4, 6.6, sz + 2) * CFrame.Angles(math.rad(8), 0, 0),
		Color = S.Rust,
		Material = Enum.Material.CorrodedMetal,
	})
	for i = 0, 1 do
		solid({
			Name = "Transformer",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(5, 3.2, 3.2),
			CFrame = CFrame.new(sx + 2 + i * 4, 2.9, sz - 1) * CFrame.Angles(0, 0, math.rad(90)),
			Color = S.Steel,
			Material = Enum.Material.Metal,
		})
		for k = 0, 2 do
			deco({
				Size = Vector3.new(0.3, 1.4, 0.3),
				Position = Vector3.new(sx + 1 + i * 4 + k, 6.1, sz - 1),
				Color = S.Cream,
				Material = Enum.Material.SmoothPlastic,
			})
		end
	end
	local fenceY = 2.6
	for _, edge in
		{
			{ Vector3.new(sx - 8, 0, sz - 6), Vector3.new(sx + 8, 0, sz - 6) },
			{ Vector3.new(sx + 8, 0, sz - 6), Vector3.new(sx + 8, 0, sz + 6) },
			{ Vector3.new(sx + 8, 0, sz + 6), Vector3.new(sx - 8, 0, sz + 6) },
			{ Vector3.new(sx - 8, 0, sz + 6), Vector3.new(sx - 8, 0, sz - 6) },
		}
	do
		local a, b = edge[1], edge[2]
		for t = 0, 1, 0.25 do
			solid({
				Name = "FencePost",
				Size = Vector3.new(0.4, 5.2, 0.4),
				Position = a:Lerp(b, t) + Vector3.new(0, fenceY, 0),
				Color = S.Steel,
				Material = Enum.Material.Metal,
			})
		end
		beam(
			a + Vector3.new(0, 5, 0),
			b + Vector3.new(0, 5, 0),
			0.15,
			{ Color = S.Steel, Material = Enum.Material.Metal }
		)
		local mesh = beam(a + Vector3.new(0, 2.5, 0), b + Vector3.new(0, 2.5, 0), 0.1, {
			Color = S.Steel,
			Material = Enum.Material.Metal,
		})
		mesh.Size = Vector3.new(0.1, 5, mesh.Size.Z)
		mesh.Transparency = 0.6
		mesh.CanCollide = true
	end
	postSign(
		Vector3.new(sx + 8.4, 0, sz),
		Vector3.new(1, 0, 0),
		5,
		2.4,
		2.4,
		"DANGER\nHIGH VOLTAGE",
		nil,
		S.SafetyYellow,
		S.HazardBlack
	)

	-- A billboard the last windstorm folded over, east of the road near the ramp foot.
	local bx, bz = 46, -142
	for i, x in { -6, 6 } do
		solid({
			Name = "BillboardLeg",
			Size = Vector3.new(0.8, 9, 0.8),
			CFrame = CFrame.new(bx + x, 4.4, bz) * CFrame.Angles(0, 0, math.rad(i == 1 and 4 or 18)),
			Color = S.Gunmetal,
			Material = Enum.Material.Metal,
		})
	end
	local board = deco({
		Name = "FallenBillboard",
		Size = Vector3.new(16, 7, 0.5),
		CFrame = CFrame.new(bx + 1, 6.5, bz + 1.5) * CFrame.Angles(math.rad(-38), 0, math.rad(9)),
		Color = S.Cream,
		Material = Enum.Material.WoodPlanks,
	})
	sign(board, Enum.NormalId.Back, "STORM-PROOF\nROOFING", S.Coral)
	ctx.TownAsset("DebrisSheet", CFrame.new(bx - 6, 0, bz + 5) * CFrame.Angles(0, math.rad(40), 0))
	ctx.TownAsset("DebrisBranch", CFrame.new(bx + 8, 0, bz + 6) * CFrame.Angles(0, math.rad(-20), 0))
	-- A guard-rail section the same storm tore off and dropped against the billboard legs.
	placeHero(
		"GuardRail",
		CFrame.new(bx - 3, 0.3, bz + 4)
			* CFrame.Angles(0, math.rad(-12), 0)
			* CFrame.Angles(math.rad(-80), 0, 0),
		folder
	)

	-- Dense tree groups instead of single trees dotted on the lawn.
	grove(Vector3.new(-120, 0, -196), 5, 3, 12)
	grove(Vector3.new(74, 0, -132), 4, 3, 10)
	grove(Vector3.new(150, 0, -196), 5, 2, 14)
end

---------------------------------------------------------------------------- Hero assets (B2)

local function heroSign(model: Model, faces: { [Enum.NormalId]: string }, color: Color3)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and string.find(d.Name, "Signboard", 1, true) then
			for face, text in faces do
				sign(d, face, text, color)
			end
			return
		end
	end
end

local function replaceModel(parent: Instance, oldName: string, near: Vector3, heroName: string): Model?
	if not heroSource(heroName) then
		return nil
	end
	local best: Model? = nil
	local bestD = math.huge
	for _, d in parent:GetDescendants() do
		if d:IsA("Model") and d.Name == oldName then
			local dist = (d:GetPivot().Position - near).Magnitude
			if dist < bestD then
				best, bestD = d, dist
			end
		end
	end
	if not best or bestD > 25 then
		return nil
	end
	local cf = best:GetPivot()
	local parentOf = best.Parent :: Instance
	best:Destroy()
	return placeHero(heroName, cf, parentOf)
end

local function dropGroup(parent: Instance, name: string)
	local g = parent:FindFirstChild(name, true)
	if g then
		g:Destroy()
	end
end

local function buildHeroes()
	local top = ctx.PlateauTop
	local yard = ctx.Yard
	local placed = {}

	local station = replaceModel(yard, "SellShack", Vector3.new(-36, top, -265), "WeighStation")
	if station then
		heroSign(station, { [Enum.NormalId.Front] = "SCRAP BUYER" }, S.NeonGreen)
		dropGroup(yard, "ScaleDialPrimitive")
		table.insert(placed, "WeighStation")
	end
	local workshop = replaceModel(yard, "GearShack", Vector3.new(36, top, -265), "GearWorkshop")
	if workshop then
		heroSign(workshop, { [Enum.NormalId.Front] = "GEAR SHOP" }, S.StormCyan)
		dropGroup(yard, "LeanToPrimitive")
		table.insert(placed, "GearWorkshop")
	end
	local gantry =
		placeHero("ArrivalGantry", CFrame.lookAt(Vector3.new(0, top, -285), Vector3.new(0, top, -290)), yard)
	if gantry then
		heroSign(gantry, { [Enum.NormalId.Front] = "STORM SALVAGE CO." }, S.SafetyYellow)
		-- The sign frame covers the board's back, so the gate-side message goes on a thin panel
		-- just behind the frame (frame rear face is 0.6 studs in front of the pivot).
		local back = deco({
			Name = "GantryBackSign",
			Size = Vector3.new(21, 3.4, 0.1),
			CFrame = gantry:GetPivot() * CFrame.new(0, 14, -0.52),
			Color = S.HazardBlack,
			Material = Enum.Material.SmoothPlastic,
		})
		back.Parent = gantry
		sign(back, Enum.NormalId.Back, "WE BUY WHAT THE STORM LEAVES", S.SafetyYellow)
		dropGroup(yard, "GantryPrimitive")
		table.insert(placed, "ArrivalGantry")
	end
	-- The shredder stands behind the spawn as the yard's working silhouette, seen from the gate
	-- and the town; the scrap pile that sat there goes.
	local shredderCf = CFrame.lookAt(Vector3.new(0, top, -322), Vector3.new(0, top, -310))
	if heroSource("Shredder") then
		for _, d in yard:GetChildren() do
			if
				d:IsA("Model")
				and d.Name == "ScrapPile"
				and (d:GetPivot().Position - shredderCf.Position).Magnitude < 14
			then
				d:Destroy()
			end
		end
		local machine = placeHero("Shredder", shredderCf, yard)
		if machine then
			heroSign(machine, { [Enum.NormalId.Front] = "SHREDDER #2" }, S.SafetyYellow)
			table.insert(placed, "Shredder")
		end
	end

	-- Town Square centrepiece: the stone fountain replaces the district pack's. The old basin
	-- cylinder stays as invisible collision, widened to the new basin; a column collider stops
	-- players walking through the pedestal, and the spray moves down to the top bowl.
	local fountain = replaceModel(ctx.Map, "Fountain", Vector3.new(-50, 0.4, -55), "FountainV3")
	if fountain then
		local base = fountain:GetPivot().Position
		for _, d in ctx.Map:GetChildren() do
			if d:IsA("BasePart") and d.Name == "Fountain" then
				d.Size = Vector3.new(2.6, 15.6, 15.6)
				d.Position = Vector3.new(base.X, base.Y + 1.3 - 0.4, base.Z)
			end
		end
		local column = ctx.Part({
			Parent = folder,
			Name = "FountainColumnCollider",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(10, 2.4, 2.4),
			CFrame = CFrame.new(base + Vector3.new(0, 5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Transparency = 1,
			CanQuery = false,
			CastShadow = false,
		})
		column.CanCollide = true
		local nozzle = ctx.Map:FindFirstChild("FountainNozzle", true)
		if nozzle and nozzle:IsA("BasePart") then
			nozzle.Position = base + Vector3.new(0, 10.2, 0)
		end
		table.insert(placed, "FountainV3")
	end

	-- Town Square: the clock tower and two storefronts framing the plaza's north side.
	local tower = replaceModel(ctx.Map, "ClockTower", Vector3.new(-50, 0, -98), "ClockTowerV3")
	if tower then
		dropGroup(ctx.Map, "ClockBoardsPrimitive")
		table.insert(placed, "ClockTowerV3")
	end
	if heroSource("StorefrontA") then
		-- A dressing tree stood where the east storefront goes.
		for _, d in ctx.Map:GetChildren() do
			if
				d:IsA("Model")
				and d.Name == "TreeBlocky"
				and (d:GetPivot().Position - Vector3.new(-20, 0, -110)).Magnitude < 4
			then
				d:Destroy()
			end
		end
	end
	for _, info in
		{
			{ "StorefrontA", Vector3.new(-92, 0, -112), "GALE HARDWARE & BAIT" },
			{ "StorefrontB", Vector3.new(-27, 0, -112), "STORMY'S DINER" },
		}
	do
		local shop = placeHero(info[1], CFrame.lookAt(info[2], info[2] + Vector3.new(0, 0, 1)), folder)
		if shop then
			heroSign(shop, { [Enum.NormalId.Front] = info[3] }, S.Cream)
			table.insert(placed, info[1])
		end
	end
	if heroSource("StorefrontA") or heroSource("StorefrontB") then
		-- Shopfront sidewalk: joins the storefronts to the plaza paving so they don't stand on
		-- the lawn. Flat like the paving (the ground underneath is what players walk on).
		ctx.Part({
			Parent = folder,
			Name = "ShopSidewalk",
			Size = Vector3.new(86, 0.1, 8),
			Position = Vector3.new(-59, 0.06, -104.8),
			Color = Color3.fromRGB(168, 156, 138),
			Material = Enum.Material.Pavement,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
		})
		for _, x in { -102.3, -15.7 } do
			deco({
				Name = "SidewalkEdge",
				Size = Vector3.new(0.6, 0.2, 8),
				Position = Vector3.new(x, 0.1, -104.8),
				Color = S.Stone,
				Material = Enum.Material.Concrete,
			})
		end
		-- Planters either side of each shop door.
		for _, x in { -97, -87, -32, -22 } do
			deco({
				Name = "Planter",
				Size = Vector3.new(2.6, 1.2, 1.4),
				Position = Vector3.new(x, 0.6, -103.6),
				Color = S.Terracotta,
				Material = Enum.Material.Brick,
				CanCollide = true,
			})
			ctx.Bush(Vector3.new(x, 1.2, -103.6), 1.6)
		end
	end
	ctx.Map:SetAttribute("V3Heroes", table.concat(placed, ","))
end

---------------------------------------------------------------------------- Yard edges (B2 polish)

-- A concrete bollard: the Blender asset when imported, else a primitive post.
local function bollard(pos: Vector3, parent: Instance?)
	local model = placeHero("Bollard", CFrame.new(pos), parent or folder)
	if model then
		return
	end
	solid({
		Name = "Bollard",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.8, 1.2, 1.2),
		CFrame = CFrame.new(pos + Vector3.new(0, 1.4, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = S.Concrete,
		Material = Enum.Material.Concrete,
		Parent = parent,
	})
	deco({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 1.26, 1.26),
		CFrame = CFrame.new(pos + Vector3.new(0, 2.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = S.SafetyYellow,
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})
end

-- A painted arrow on the ground pointing along `dir`.
local function groundArrow(pos: Vector3, dir: Vector3, color: Color3)
	local cf = CFrame.lookAt(pos, pos + dir)
	deco({ Size = Vector3.new(1.2, 0.05, 4), CFrame = cf * CFrame.new(0, 0, 0.5), Color = color })
	for _, s in { -1, 1 } do
		deco({
			Size = Vector3.new(0.9, 0.05, 3),
			CFrame = cf * CFrame.new(s * 0.9, 0, -1.2) * CFrame.Angles(0, math.rad(s * 40), 0),
			Color = color,
		})
	end
end

-- Spawn and shredder: the spawn plate becomes a framed platform with work areas on either side
-- (tool wall and bench to the west, loading bay to the east), and the shredder stands on a
-- concrete plinth with a hazard apron. The aisle from the plate to the gate stays clear.
local function buildYardEdges()
	local top = ctx.PlateauTop
	local yard = ctx.Yard
	local saved = folder
	folder = Instance.new("Folder")
	folder.Name = "V3YardEdges"
	folder.Parent = yard

	local spawn = yard:FindFirstChildWhichIsA("SpawnLocation")
	local c = if spawn
		then Vector3.new(spawn.Position.X, top, spawn.Position.Z)
		else Vector3.new(0, top, -295)
	-- Chamfered steel frame: walkable slopes off the 1-stud plate, bollards in the corners.
	for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local mid = c + dir * 7 + Vector3.new(0, 0.5, 0)
		local wedge = ctx.Wedge({
			Parent = folder,
			Name = "SpawnChamfer",
			Size = Vector3.new(12, 1, 2),
			CFrame = CFrame.lookAt(mid, mid + dir),
			Color = S.Gunmetal,
			Material = Enum.Material.DiamondPlate,
			CastShadow = false,
		})
		wedge.CanQuery = true
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			bollard(c + Vector3.new(sx * 7, 0, sz * 7))
		end
	end
	-- Hazard border painted on the concrete just outside the frame.
	for _, sz in { -1, 1 } do
		hazardStripes(c.X - 9, c.X + 9, c.Z + sz * 9, 1.4, top + 0.33)
	end
	-- Walkway arrows from the plate toward the gate.
	for _, z in { c.Z + 13, c.Z + 20 } do
		groundArrow(Vector3.new(c.X, top + 0.33, z), Vector3.zAxis, S.SafetyYellow)
	end

	-- West: tool wall and workbench facing the plate.
	local wx, wz = c.X - 19, c.Z - 3
	local wall = CFrame.lookAt(Vector3.new(wx, top, wz), Vector3.new(wx + 1, top, wz))
	for _, s in { -1, 1 } do
		solid({
			Name = "RackPost",
			Size = Vector3.new(0.4, 7, 0.4),
			CFrame = wall * CFrame.new(s * 4, 3.5, 0.3),
			Color = S.Gunmetal,
			Material = Enum.Material.Metal,
		})
	end
	deco({
		Name = "Pegboard",
		Size = Vector3.new(8, 4, 0.2),
		CFrame = wall * CFrame.new(0, 4, 0.4),
		Color = Color3.fromRGB(176, 140, 96),
		Material = Enum.Material.WoodPlanks,
	})
	deco({
		Size = Vector3.new(8.4, 0.5, 0.5),
		CFrame = wall * CFrame.new(0, 6.3, 0.3),
		Color = S.SafetyYellow,
		Material = Enum.Material.Metal,
	})
	-- Hanging tools: wrenches, a saw, a coil of hose.
	for i, info in
		{
			{ -2.9, Vector3.new(0.3, 2.2, 0.15), S.Steel },
			{ -2.2, Vector3.new(0.3, 1.8, 0.15), S.Steel },
			{ -1.5, Vector3.new(0.3, 1.4, 0.15), S.Steel },
			{ 0.2, Vector3.new(2.4, 1.0, 0.1), S.Steel },
			{ 2.6, Vector3.new(1.6, 1.6, 0.4), S.Coral },
		}
	do
		deco({
			Name = "Tool",
			Size = info[2],
			CFrame = wall * CFrame.new(info[1], 4.4 - (i % 2) * 0.3, 0.15),
			Color = info[3],
			Material = Enum.Material.Metal,
		})
	end
	ctx.PlaceAsset(
		"scrapyard",
		"Workbench",
		CFrame.lookAt(Vector3.new(wx, top, c.Z + 5), Vector3.new(wx + 1, top, c.Z + 5)),
		folder
	)
	for i = 0, 1 do
		solid({
			Name = "GasCylinder",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3.4, 1, 1),
			CFrame = CFrame.new(wx + 0.2, top + 1.7, c.Z - 9 + i * 1.2) * CFrame.Angles(0, 0, math.rad(90)),
			Color = if i == 0 then S.Teal else S.Coral,
			Material = Enum.Material.Metal,
		})
	end
	patch(Vector3.new(c.X - 17, top + 0.24, c.Z - 1), Vector2.new(12, 18), S.Concrete, Enum.Material.Concrete)

	-- East: a painted loading bay with pallets, drums and a small sorted salvage pile.
	local bx, bz = c.X + 17.5, c.Z - 1
	patch(Vector3.new(bx, top + 0.24, bz), Vector2.new(12, 16), S.Concrete, Enum.Material.Concrete)
	for _, sx in { -1, 1 } do
		deco({
			Size = Vector3.new(0.5, 0.05, 16),
			Position = Vector3.new(bx + sx * 5.5, top + 0.3, bz),
			Color = S.SafetyYellow,
		})
	end
	deco({
		Size = Vector3.new(11.5, 0.05, 0.5),
		Position = Vector3.new(bx, top + 0.3, bz - 8),
		Color = S.SafetyYellow,
	})
	local stencil = deco({
		Name = "BayStencil",
		Size = Vector3.new(8, 0.05, 3),
		Position = Vector3.new(bx, top + 0.29, bz + 5.5),
		Color = S.Concrete,
		Material = Enum.Material.Concrete,
	})
	sign(stencil, Enum.NormalId.Top, "LOADING", S.SafetyYellow)
	ctx.PlaceAsset(
		"scrapyard",
		"PalletStack",
		CFrame.new(bx + 1.5, top, bz - 5) * CFrame.Angles(0, math.rad(8), 0),
		folder
	)
	ctx.PlaceAsset(
		"scrapyard",
		"OilDrums",
		CFrame.new(bx + 2, top, bz + 0.5) * CFrame.Angles(0, math.rad(-20), 0),
		folder
	)
	local sorted = ctx.PlaceAsset(
		"scrapyard",
		"ScrapPile",
		CFrame.new(bx + 9, top, bz - 2) * CFrame.Angles(0, math.rad(200), 0),
		folder
	)
	if sorted then
		sorted:ScaleTo(0.45)
	end

	-- Shredder plinth: lift the machine onto a concrete base with a steel edge and a hazard apron
	-- (behind the spawn, off every route).
	local shredder = yard:FindFirstChild("Shredder")
	if shredder and shredder:IsA("Model") then
		local PLINTH = 1.2
		local cf, size = shredder:GetBoundingBox()
		local pz = cf.Position.Z + 0.5
		ctx.Part({
			Parent = folder,
			Name = "ShredderPlinth",
			Size = Vector3.new(size.X + 3, PLINTH, size.Z + 3),
			Position = Vector3.new(cf.Position.X, top + PLINTH / 2, pz),
			Color = S.Concrete:Lerp(S.Stone, 0.4),
			Material = Enum.Material.Concrete,
			CanQuery = true,
			CastShadow = false,
		})
		deco({
			Name = "PlinthEdge",
			Size = Vector3.new(size.X + 3.2, 0.3, 0.3),
			Position = Vector3.new(cf.Position.X, top + PLINTH, pz + (size.Z + 3) / 2),
			Color = S.SafetyYellow,
			Material = Enum.Material.Metal,
		})
		shredder:PivotTo(shredder:GetPivot() + Vector3.new(0, PLINTH, 0))
		local front = pz + (size.Z + 3) / 2
		hazardStripes(cf.Position.X - size.X / 2, cf.Position.X + size.X / 2, front + 1.2, 2.4, top + 0.33)
		local keep = deco({
			Name = "KeepClear",
			Size = Vector3.new(12, 0.05, 2.6),
			Position = Vector3.new(cf.Position.X, top + 0.31, front + 4),
			Color = S.Concrete,
			Material = Enum.Material.Concrete,
		})
		sign(keep, Enum.NormalId.Top, "KEEP CLEAR", S.SafetyYellow)
	end

	folder = saved
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
	local far = 1400 -- past the horizon seen from the crane top
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
	-- The west and south edges sit closest to the playable box, so the rings leave them flat;
	-- a row of low hills just outside each edge closes the horizon there.
	for i = 0, 7 do
		local along = -260 + i * 70 + rng:NextNumber(-15, 15)
		for _, pos in
			{
				Vector2.new(-(TOWN + 68 + rng:NextNumber(0, 40)), along), -- west
				Vector2.new(TOWN + 68 + rng:NextNumber(0, 40), along), -- east
				Vector2.new(along + 40, TOWN + 68 + rng:NextNumber(0, 40)), -- south
			}
		do
			-- Tall enough to break the horizon from the far side of town (peaks ~25-40 studs).
			local r = rng:NextNumber(44, 66)
			if not inTown(pos.X, pos.Y, r) then
				terrain:FillBall(Vector3.new(pos.X, -r * 0.4, pos.Y), r, Enum.Material.Grass)
				placed += 1
			end
		end
	end

	-- A distant ridge all the way round, tall enough to break the skyline from the highest
	-- reachable spots (the Scrapyard and the shredder platform, eye ~y 45): peaks ~75-100 studs,
	-- overlapping so the flat ground never meets the sky. Hazed out so it reads as far away.
	for i = 0, 23 do
		local angle = i / 24 * math.pi * 2 + rng:NextNumber(-0.04, 0.04)
		local dist = rng:NextNumber(560, 620)
		local r = rng:NextNumber(110, 140)
		terrain:FillBall(
			Vector3.new(math.cos(angle) * dist, -r * 0.3, math.sin(angle) * dist - 60),
			r,
			if i % 3 == 0 then Enum.Material.Rock else Enum.Material.Grass
		)
		placed += 1
	end
	task.wait()

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
	local tower = placeHero(
		"WaterTowerV3",
		CFrame.lookAt(Vector3.new(wx, wy - 0.5, wz), Vector3.new(0, wy - 0.5, -60)),
		edge
	)
	if tower then
		heroSign(tower, { [Enum.NormalId.Front] = "GALE HOLLOW" }, S.Coral)
	else
		for _, o in
			{ Vector3.new(-6, 0, -6), Vector3.new(6, 0, -6), Vector3.new(-6, 0, 6), Vector3.new(6, 0, 6) }
		do
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
	end
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
	local t0 = os.clock()
	buildScrapyard()
	buildRoad()
	buildSquare()
	buildRoadside()
	buildHeroes()
	buildYardEdges()
	local t1 = os.clock()
	buildWorldEdge()
	-- Startup cost, for the performance report.
	c.Map:SetAttribute("SliceBuildMs", math.floor((t1 - t0) * 1000))
	c.Map:SetAttribute("WorldEdgeBuildMs", math.floor((os.clock() - t1) * 1000))
end

return WorldSlice
