-- V3 Milestone C2: the Super Saver supermarket (NE of Town Square). Turns the V2 box of identical
-- shelves into a store with departments, a checkout line, a staff door, a receiving dock and
-- storm damage. See docs/art/V3-C2-SUPERMARKET.md.
--
-- Gameplay stays where MapBuilder put it: the invisible 70 x 50 x 18 walls and roof (shelter),
-- the door, the back truss, and the 9 x 7 interior loot grid. Every new collider is either a
-- shelf variant on an existing shelf's footprint (12 x 2) or a 1.6 x 4.8 checkout counter set in
-- the gap between two loot columns. Ceiling pieces hang above 11 studs; floor clutter never
-- collides. Everything comes from ServerStorage.Assets.v3market; without it V2 stays as is.

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local Palette = require(game:GetService("ReplicatedStorage").Shared.Palette)

local DistrictSupermarket = {}

local S = Palette.Swatches
local CENTER = Vector3.new(120, 0, -80) -- MapBuilder: 70 x 50, door on +Z
local FLOOR = 1 -- top of the store's floor part
local FRONT, BACK = CENTER.Z + 25, CENTER.Z - 25

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

-- Neon pieces whose name contains `key` become work lamps for EnvironmentFX: they flicker in
-- storm warnings and short out when lightning lands within 35 studs.
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

-- V2 pieces placed by MapBuilder that this pass replaces, found by name and position.
local function findModel(map: Model, name: string, pos: Vector3, tolerance: number): Model?
	for _, d in map:GetChildren() do
		if d:IsA("Model") and d.Name == name and (d:GetPivot().Position - pos).Magnitude < tolerance then
			return d
		end
	end
	return nil
end

local function removePrimitiveCar(map: Model, pos: Vector3)
	for _, d in map:GetChildren() do
		if d:IsA("BasePart") and d.Name ~= "ParkingLot" and d.Size.Y >= 0.3 and d.Position.Y < 7 then
			local off = d.Position - pos
			if math.abs(off.X) < 6.5 and math.abs(off.Z) < 7 then
				d:Destroy()
			end
		end
	end
end

function DistrictSupermarket.build(ctx: Context)
	if not source("v3market", "ShelfFreezer") then
		return -- assets not imported yet: the V2 store stays
	end
	local t0 = os.clock()
	local map = ctx.Map
	local folder = Instance.new("Folder")
	folder.Name = "V3Supermarket"
	folder.Parent = map

	-- Floor: shop tile instead of the V2 wood planks (same part, so collision is unchanged).
	local store = map:FindFirstChild("Supermarket")
	local floor = store and store:FindFirstChild("Floor")
	if floor and floor:IsA("BasePart") then
		floor.Material = Enum.Material.Marble
		floor.Color = Color3.fromRGB(184, 178, 164)
	end

	-- Departments: the front shelf row becomes produce islands, the back row freezers, the middle
	-- row stays the V2 pantry shelving. Same footprints, so the loot rows are untouched.
	local rows = { [10.5] = "ShelfProduce", [-17.5] = "ShelfFreezer" }
	for dz, replacement in rows do
		for _, dx in { -22, -7, 8, 23 } do
			local pos = CENTER + Vector3.new(dx, FLOOR, dz)
			local old = findModel(map, "AisleShelf", pos, 1)
			if old then
				old:Destroy()
				place("v3market", replacement, CFrame.new(pos), folder)
			end
		end
	end

	-- Aisle signs over the centre aisle, readable from the door.
	for _, info in { { 10.5, "PRODUCE" }, { -3.5, "PANTRY" }, { -17.5, "FROZEN" } } do
		local sign = place(
			"v3market",
			"AisleSign",
			CFrame.lookAt(CENTER + Vector3.new(0.5, 12, info[1]), CENTER + Vector3.new(0.5, 12, info[1] + 1)),
			folder
		)
		local board = sign and meshWith(sign, "Signboard")
		if board then
			ctx.SurfaceSign(board, Enum.NormalId.Front, info[2], S.Cream, Enum.Font.LuckiestGuy)
			ctx.SurfaceSign(board, Enum.NormalId.Back, info[2], S.Cream, Enum.Font.LuckiestGuy)
		end
	end

	-- Fluorescent strips over the aisles. Three carry a soft light; all of them stutter when a
	-- storm is coming.
	for _, dz in { -10.5, 3.5, 17.5 } do
		for i, dx in { -22, -7, 8, 23 } do
			local fixture =
				place("v3market", "CeilingLight", CFrame.new(CENTER + Vector3.new(dx, 15, dz)), folder)
			if fixture then
				tagLamps(fixture, "Neon")
				local tube = meshWith(fixture, "Neon")
				if tube and i == 2 then
					pointLight(tube, 30, 0.7, Color3.fromRGB(235, 245, 255))
				end
			end
		end
	end

	-- Checkout line along the front windows: four lanes in the gaps between loot columns, the
	-- centre (door) lanes left open. Queue side faces into the store.
	for lane, dx in { -20.5, -13.5, 14.5, 21.5 } do
		local counter =
			place("v3market", "CheckoutCounter", CFrame.new(CENTER + Vector3.new(dx, FLOOR, 17.5)), folder)
		if counter then
			tagLamps(counter, "Mustard")
			local box = meshWith(counter, "Signboard")
			if box then
				ctx.SurfaceSign(
					box,
					Enum.NormalId.Front,
					tostring(lane),
					S.SafetyYellow,
					Enum.Font.LuckiestGuy
				)
				ctx.SurfaceSign(
					box,
					Enum.NormalId.Back,
					tostring(lane),
					S.SafetyYellow,
					Enum.Font.LuckiestGuy
				)
			end
		end
	end

	-- Stockroom doors on the back wall (the gameplay wall behind them stays solid).
	local doors = place(
		"v3market",
		"StaffDoors",
		CFrame.lookAt(Vector3.new(CENTER.X, FLOOR, BACK + 0.7), Vector3.new(CENTER.X, FLOOR, BACK + 2)),
		folder
	)
	local staff = doors and meshWith(doors, "Signboard")
	if staff then
		ctx.SurfaceSign(staff, Enum.NormalId.Front, "STAFF ONLY", S.Cream, Enum.Font.LuckiestGuy)
	end

	-- Storm damage inside: a leak with a bucket, spilled stock in two aisles (flat, no collision).
	place("v3market", "RoofLeak", CFrame.new(CENTER + Vector3.new(-13.5, FLOOR, -10.5)), folder)
	place(
		"v3market",
		"SpilledGoods",
		CFrame.new(CENTER + Vector3.new(-6.5, FLOOR, 3.5)) * CFrame.Angles(0, 0.6, 0),
		folder
	)
	place(
		"v3market",
		"SpilledGoods",
		CFrame.new(CENTER + Vector3.new(19.5, FLOOR, -10.5)) * CFrame.Angles(0, 2.2, 0),
		folder
	)

	-- Storefront: one cracked window boarded up, with the staff's message.
	local board = place(
		"v3market",
		"BoardedWindow",
		CFrame.lookAt(
			Vector3.new(CENTER.X + 14, 2.7, FRONT + 1.1),
			Vector3.new(CENTER.X + 14, 2.7, FRONT + 5)
		),
		folder
	)
	local ply = board and meshWith(board, "Signboard")
	if ply then
		ply.Color = S.Sand
		ply.Material = Enum.Material.WoodPlanks
		ctx.SurfaceSign(ply, Enum.NormalId.Front, "STILL OPEN!", S.Coral, Enum.Font.PermanentMarker)
	end

	-- Receiving dock behind the store, by the loading door: baler, stock pallets.
	place("v3market", "Baler", CFrame.new(88, 0, -110), folder)
	place("v3market", "BoxStack", CFrame.new(108, 0, -110.5) * CFrame.Angles(0, 0.15, 0), folder)
	place("v3market", "BoxStack", CFrame.new(113, 0, -111) * CFrame.Angles(0, -0.2, 0), folder)

	-- Parking lot: the V2 block cars become the sedan from the Houses kit (recoloured), carts
	-- the wind pushed across the lot, and one restrained lot lamp for storms.
	for _, info in
		{
			{ Vector3.new(100, 0.25, -40), 0, S.Cobalt },
			{ Vector3.new(132, 0.25, -40), 180, S.Mint },
		}
	do
		local pos: Vector3 = info[1]
		removePrimitiveCar(map, pos)
		local sedan =
			place("v3houses", "Sedan", CFrame.new(pos) * CFrame.Angles(0, math.rad(info[2]), 0), folder)
		if sedan then
			for _, d in sedan:GetDescendants() do
				if
					d:IsA("BasePart")
					and string.match(d.Name, "__Coral$")
					and d.Material ~= Enum.Material.Neon
				then
					d.Color = info[3]
				elseif
					d:IsA("BasePart") and (string.match(d.Name, "__Bark$") or string.match(d.Name, "__Leaf$"))
				then
					-- The Houses car carries a fallen branch; these lot cars don't.
					d:Destroy()
				end
			end
		end
	end
	for _, info in { { Vector3.new(112, 0.25, -30), 70, 85 }, { Vector3.new(141, 0.25, -27), -40, 0 } } do
		place(
			"districts",
			"ShoppingCart",
			CFrame.new(info[1]) * CFrame.Angles(0, math.rad(info[2]), math.rad(info[3])),
			folder
		)
	end
	local town = ServerStorage:FindFirstChild("Assets") and ServerStorage.Assets:FindFirstChild("town")
	local lampSrc = town and town:FindFirstChild("StreetLamp")
	if lampSrc then
		local lamp = lampSrc:Clone() :: Model
		lamp.Name = "LotLamp"
		lamp:PivotTo(CFrame.lookAt(Vector3.new(120, 0.25, -21), Vector3.new(120, 0.25, -30)))
		lamp.Parent = folder
		tagLamps(lamp, "WindowWarm")
		local head = meshWith(lamp, "WindowWarm")
		if head then
			pointLight(head, 24, 1.1, Color3.fromRGB(255, 200, 140))
		end
	end

	map:SetAttribute("C2SupermarketBuildMs", math.floor((os.clock() - t0) * 1000))
end

return DistrictSupermarket
