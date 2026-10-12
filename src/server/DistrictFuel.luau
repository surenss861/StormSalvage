-- V3 Milestone C3: Fuel & Go (NW of Town Square). Gives the V2 forecourt, empty store box and
-- open-air repair bay a finished roadside service-centre identity. See docs/art/V3-C3-FUEL.md.
--
-- Gameplay stays where MapBuilder put it: the store's invisible 40 x 30 x 14 walls and roof
-- (shelter), its door (+Z), the back truss, the 5 x 4 interior loot grid
-- (x -136..-108, z -91..-70), and the canopy shelter part (36 x 20 at y 12). New interior
-- colliders are wall-hugging (coolers, rack, counter) or sit between loot columns (gondolas).
-- The repair bay gets no roof, so nothing there looks like shelter. Everything comes from
-- ServerStorage.Assets.v3fuel (plus reused v3houses / v3market pieces); without it V2 stays.

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local Palette = require(game:GetService("ReplicatedStorage").Shared.Palette)

local DistrictFuel = {}

local S = Palette.Swatches
local STORE = Vector3.new(-120, 0, -80) -- 40 x 30, door on +Z
local FLOOR = 1

-- Only the big structural surfaces of interior fixtures cast shadows (see DistrictSupermarket).
local SHADOW_KEEP: { [string]: { [string]: boolean } } = {
	WallCooler = { Metal__White = true },
	SnackGondola = { Metal__Steel = true },
	ShopCounter = { Planks__Teal = true },
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

local function meshWith(model: Model, key: string): BasePart?
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and string.find(d.Name, key, 1, true) then
			return d
		end
	end
	return nil
end

local function tagLamps(model: Model, key: string)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Material == Enum.Material.Neon and string.find(d.Name, key, 1, true) then
			d:SetAttribute("OnColor", d.Color)
			CollectionService:AddTag(d, "V3Lamp")
		end
	end
end

local function pointLight(part: BasePart, range: number, brightness: number, color: Color3)
	local light = Instance.new("PointLight")
	light.Range = range
	light.Brightness = brightness
	light.Color = color
	light.Shadows = false
	light.Parent = part
end

local function paint(
	model: Model?,
	key: string,
	face: Enum.NormalId,
	text: string,
	color: Color3,
	ctx: Context
)
	local board = model and meshWith(model, key)
	if board then
		ctx.SurfaceSign(board, face, text, color, Enum.Font.LuckiestGuy)
	end
end

local function findModel(map: Model, name: string, pos: Vector3, tolerance: number): Model?
	for _, d in map:GetChildren() do
		if d:IsA("Model") and d.Name == name and (d:GetPivot().Position - pos).Magnitude < tolerance then
			return d
		end
	end
	return nil
end

-- MapBuilder's primitive block cars (body, glass, four wheels) around `pos`.
local function removePrimitiveCar(map: Model, pos: Vector3)
	for _, d in map:GetChildren() do
		if d:IsA("BasePart") and d.Position.Y < 7 then
			local off = d.Position - pos
			if math.abs(off.X) < 7 and math.abs(off.Z) < 7 and d.Size.Magnitude < 14 then
				d:Destroy()
			end
		end
	end
end

-- Recoloured Houses sedan without its fallen branch.
local function sedan(cf: CFrame, color: Color3, parent: Instance)
	local car = place("v3houses", "Sedan", cf, parent)
	if not car then
		return
	end
	for _, d in car:GetDescendants() do
		if d:IsA("BasePart") then
			if string.match(d.Name, "__Coral$") and d.Material ~= Enum.Material.Neon then
				d.Color = color
			elseif string.match(d.Name, "__Bark$") or string.match(d.Name, "__Leaf$") then
				d:Destroy()
			end
		end
	end
end

-- Thin-shelved fixtures (0.12-0.2 stud shelves and backs) slip through the pathfinding navmesh,
-- so the QA bot and NPC-style routes would cut through them. Give each one a single solid box
-- the size of its footprint and let its meshes stop colliding.
local function solidify(model: Model?, ctx: Context, parent: Instance)
	if not model then
		return
	end
	local cf, size = model:GetBoundingBox()
	ctx.Part({
		Parent = parent,
		Name = model.Name .. "Collider",
		Size = size,
		CFrame = cf,
		Transparency = 1,
		CastShadow = false,
	})
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
end

function DistrictFuel.build(ctx: Context)
	if not source("v3fuel", "WallCooler") then
		return -- assets not imported yet: the V2 station stays
	end
	local t0 = os.clock()
	local map = ctx.Map
	local folder = Instance.new("Folder")
	folder.Name = "V3Fuel"
	folder.Parent = map

	-- Store floor: worn lino instead of wood planks (same part, collision unchanged).
	local store = map:FindFirstChild("Gas Station")
	local floor = store and store:FindFirstChild("Floor")
	if floor and floor:IsA("BasePart") then
		floor.Material = Enum.Material.Marble
		floor.Color = Color3.fromRGB(176, 170, 158)
	end

	-- Interior: drinks coolers along the back wall, an auto-supplies rack on the west wall, two
	-- snack gondolas between loot columns, the cash counter in the band east of the last column.
	local back = STORE.Z - 14.5 -- inner face of the back wall
	for _, x in { -131, -117 } do
		local cooler = place(
			"v3fuel",
			"WallCooler",
			CFrame.lookAt(Vector3.new(x, FLOOR, back + 0.8), Vector3.new(x, FLOOR, back + 2)),
			folder
		)
		if cooler then
			tagLamps(cooler, "Neon")
		end
	end
	local rack = place(
		"v3fuel",
		"WallRack",
		CFrame.lookAt(Vector3.new(STORE.X - 19.4, FLOOR, -80), Vector3.new(STORE.X - 18, FLOOR, -80)),
		folder
	)
	paint(rack, "Signboard", Enum.NormalId.Front, "AUTO", S.Cream, ctx)
	solidify(rack, ctx, folder)
	for _, info in { { -125.5, "SNACKS" }, { -111.5, "CHIPS" } } do
		local gondola = place(
			"v3fuel",
			"SnackGondola",
			CFrame.new(info[1], FLOOR, -80.5) * CFrame.Angles(0, math.rad(90), 0),
			folder
		)
		paint(gondola, "Signboard", Enum.NormalId.Front, info[2], S.Cream, ctx)
		paint(gondola, "Signboard", Enum.NormalId.Back, info[2], S.Cream, ctx)
		solidify(gondola, ctx, folder)
	end
	local counter = place(
		"v3fuel",
		"ShopCounter",
		CFrame.lookAt(Vector3.new(-104.4, FLOOR, -83), Vector3.new(-104.4, FLOOR, -82)),
		folder
	)
	if counter then
		paint(counter, "Signboard", Enum.NormalId.Right, "LOTTO  •  SMOKES", S.SafetyYellow, ctx)
	end
	-- Ceiling: two fluorescent strips (the supermarket's fixture), one with a soft light.
	for i, z in { -86, -73 } do
		local fixture = place("v3market", "CeilingLight", CFrame.new(-120, 12, z), folder)
		if fixture then
			local tube = meshWith(fixture, "Neon")
			if tube then
				tube.Color = Color3.fromRGB(196, 194, 182)
			end
			tagLamps(fixture, "Neon")
			if tube and i == 1 then
				pointLight(tube, 24, 0.5, Color3.fromRGB(245, 240, 225))
			end
		end
	end
	place("v3market", "SpilledGoods", CFrame.new(-118.5, FLOOR, -76) * CFrame.Angles(0, 1.1, 0), folder)

	-- Storefront: one cracked window boarded, with the owner's note.
	local board = place(
		"v3market",
		"BoardedWindow",
		CFrame.lookAt(Vector3.new(-108, 2.5, -64.2), Vector3.new(-108, 2.5, -60)),
		folder
	)
	local ply = board and meshWith(board, "Signboard")
	if ply then
		ply.Color = S.Sand
		ply.Material = Enum.Material.WoodPlanks
		ctx.SurfaceSign(ply, Enum.NormalId.Front, "NO ICE TILL FRIDAY", S.Coral, Enum.Font.PermanentMarker)
	end

	-- Forecourt: the canopy's light panel joins the lamp flicker and lightning shorts, two
	-- restrained shadowless pools light the pumps in storms, a fascia panel hangs loose, the
	-- east pump is bagged, and there's an air machine at the forecourt edge.
	local canopy = findModel(map, "FuelCanopy", Vector3.new(-120, 0, -45), 2)
	if canopy then
		-- The 30 x 14 light panel is pure-white Neon, the brightest thing in town in calm light and
		-- a glaring rectangle in storms. A warm grey keeps it reading as a lit canopy without bloom.
		-- Even grey Neon blooms at that size, so the panel becomes a plain light panel and the two
		-- pools below (y 6, under the panel rather than against it) carry the light. It stays a
		-- V3Lamp, so it still flickers in warnings and shorts out on nearby strikes.
		for _, d in canopy:GetDescendants() do
			if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
				d.Material = Enum.Material.SmoothPlastic
				d.Color = Color3.fromRGB(196, 192, 180)
				d:SetAttribute("OnColor", d.Color)
				CollectionService:AddTag(d, "V3Lamp")
			end
		end
		local glow = meshWith(canopy, "White")
		if glow then
			for _, x in { -128, -112 } do
				local anchor = ctx.Prop({
					Parent = folder,
					Name = "CanopyLight",
					Size = Vector3.one,
					Position = Vector3.new(x, 6, -45),
					Transparency = 1,
					CanCollide = false,
				})
				pointLight(anchor, 22, 0.8, Color3.fromRGB(240, 236, 220))
			end
		end
	end
	place(
		"v3fuel",
		"CanopyPanel",
		CFrame.new(-135, 10.3, -34.4) * CFrame.Angles(0, math.pi, 0), -- swings back under the canopy
		folder
	)
	local pump = findModel(map, "FuelPump", Vector3.new(-98, 0.6, -45), 2)
	if pump then
		local bag = place("v3fuel", "PumpBag", pump:GetPivot(), folder)
		paint(bag, "Signboard", Enum.NormalId.Front, "OUT OF ORDER", S.HazardBlack, ctx)
	end
	local air = place(
		"v3fuel",
		"AirMachine",
		CFrame.lookAt(Vector3.new(-140.5, 0.3, -56), Vector3.new(-139, 0.3, -56)),
		folder
	)
	paint(air, "Signboard", Enum.NormalId.Front, "AIR 50¢", S.Cream, ctx)
	for _, pos in { Vector3.new(-112, 0.35, -40), Vector3.new(-132, 0.35, -52) } do
		local spot = ctx.Prop({
			Parent = folder,
			Name = "PuddleSpot",
			Size = Vector3.one,
			Position = pos,
			Transparency = 1,
		})
		CollectionService:AddTag(spot, "V3PuddleSpot")
	end

	-- Repair bay: a closed roll-up door on the store's west wall behind the lift (the wall stays
	-- solid), a compressor, and the V2 block cars become real sedans (one waiting for the lift).
	local door = place(
		"v3fuel",
		"GarageDoor",
		CFrame.lookAt(Vector3.new(STORE.X - 20.6, 0.3, -80), Vector3.new(STORE.X - 24, 0.3, -80)),
		folder
	)
	paint(door, "Signboard", Enum.NormalId.Front, "SERVICE", S.Cream, ctx)
	if door then
		-- Painted steel: the Metal material variant's cracks made the door read as wall.
		for _, d in door:GetDescendants() do
			if d:IsA("BasePart") and string.match(d.Name, "__Steel$") then
				d.Material = Enum.Material.SmoothPlastic
				d.Color = Color3.fromRGB(150, 158, 166)
			end
		end
	end
	place("v3fuel", "Compressor", CFrame.new(-160.5, 0.3, -73) * CFrame.Angles(0, math.rad(15), 0), folder)
	for _, info in
		{
			{ Vector3.new(-150, 0, -15), 90, S.Cobalt },
			{ Vector3.new(-170, 0, -120), 10, S.Mustard },
		}
	do
		local pos: Vector3 = info[1]
		removePrimitiveCar(map, pos)
		sedan(CFrame.new(pos) * CFrame.Angles(0, math.rad(info[2]), 0), info[3], folder)
	end

	-- Shadow pass over the interior fixtures.
	for _, model in folder:GetChildren() do
		if model:IsA("Model") then
			local p = model:GetPivot().Position
			if math.abs(p.X - STORE.X) < 20 and math.abs(p.Z - STORE.Z) < 15 then
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

	map:SetAttribute("C3FuelBuildMs", math.floor((os.clock() - t0) * 1000))
end

return DistrictFuel
