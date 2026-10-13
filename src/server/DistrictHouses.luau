-- @file Houses district (V3 C1)
-- @domain world
-- @status stable
-- @see [[V3-C1-HOUSES]]
-- V3 Milestone C1: the Houses district (SW of Town Square). Swaps the V2 house shells for the V3
-- ones, gives each lot a yard with a purpose, and adds the district landmark: an old oak the
-- storm tore out across the west end of the lane. See docs/art/V3-C1-HOUSES.md.
--
-- Gameplay stays where MapBuilder.building() put it: invisible walls, roofs and porch roofs
-- (shelter), the RoofSlope wedges and the back-wall TrussParts (flood escape), and every loot
-- point inside the houses. This module only:
--   - replaces the visual shell (non-colliding) and dresses the climbing truss with a ladder mesh,
--   - adds yard pieces outside the houses, away from doors, trusses and the lane,
--   - adds one collider: the oak's trunk, past the end of the lane.
-- Everything comes from ServerStorage.Assets.v3houses; without it the V2 district stays as is.

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local Palette = require(game:GetService("ReplicatedStorage").Shared.Palette)

local DistrictHouses = {}

local S = Palette.Swatches

-- MapBuilder.building() geometry (MapBuilder.luau): 30 x 28 houses, doors facing -Z, trusses on
-- the back wall at (w/2 - 4, d/2 + 2.5).
local HOUSES = {
	Vector3.new(-150, 0, 55),
	Vector3.new(-95, 0, 55),
	Vector3.new(-150, 0, 120),
	Vector3.new(-95, 0, 120),
}

type Context = {
	Map: Model,
	Part: (props: { [string]: any }) -> Part,
	Prop: (props: { [string]: any }) -> Part,
}

-- Thin repeated pieces don't need shadows (fence boards, ladder rails, the clothesline).
local NO_SHADOW = { PrivacyFence = true, RoofLadder = true, Clothesline = true }

local function source(name: string): Model?
	local assets = ServerStorage:FindFirstChild("Assets")
	local set = assets and assets:FindFirstChild("v3houses")
	local model = set and set:FindFirstChild(name)
	return if model and model:IsA("Model") then model else nil
end

local function place(name: string, cf: CFrame, parent: Instance): Model?
	local src = source(name)
	if not src then
		return nil
	end
	local model = src:Clone()
	model:PivotTo(cf)
	model.Parent = parent
	if NO_SHADOW[name] then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.CastShadow = false
			end
		end
	end
	-- Porch lamps join the bulb flicker and lightning shorts.
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

local function swatchOf(part: Instance): string?
	return string.match(part.Name, "__(%w+)$")
end

local function swatchColor(model: Model, swatch: string): Color3?
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and swatchOf(d) == swatch then
			return d.Color
		end
	end
	return nil
end

local function recolor(model: Model, colors: { [string]: Color3? })
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local swatch = swatchOf(d)
			local color = swatch and colors[swatch]
			if color then
				d.Color = color
			end
		end
	end
end

-- Shell and ladder for one house.
local function upgradeHouse(house: Model)
	local old: Model? = nil
	for _, child in house:GetChildren() do
		if child:IsA("Model") and (child.Name == "HouseA" or child.Name == "HouseB") then
			old = child
		end
	end
	if old then
		local name = if old.Name == "HouseA" then "HouseV3A" else "HouseV3B"
		if source(name) then
			local wall, roof = swatchColor(old, "Plaster"), swatchColor(old, "RoofRed")
			local pivot = old:GetPivot()
			old:Destroy()
			local shell = place(name, pivot, house)
			if shell then
				recolor(shell, { Plaster = wall, RoofRed = roof })
			end
		end
	end
	-- The truss still does the climbing; the ladder mesh is what players see.
	local truss = house:FindFirstChildWhichIsA("TrussPart")
	if truss and source("RoofLadder") then
		place("RoofLadder", CFrame.new(truss.Position.X, 0, truss.Position.Z), house)
		truss.Transparency = 1
	end
end

-- A lane lamp: the town street-lamp model with a small, warm, shadowless pool. Tagged V3Lamp,
-- so EnvironmentFX flickers it in storm warnings and shorts it out when lightning lands within
-- 35 studs (both skipped or reduced under Reduced Effects).
local function laneLamp(pos: Vector3, faceDir: Vector3, parent: Instance)
	local assets = ServerStorage:FindFirstChild("Assets")
	local town = assets and assets:FindFirstChild("town")
	local src = town and town:FindFirstChild("StreetLamp")
	if not src then
		return
	end
	local lamp = src:Clone() :: Model
	lamp:PivotTo(CFrame.lookAt(pos, pos + faceDir))
	lamp.Name = "LaneLamp"
	lamp.Parent = parent
	for _, d in lamp:GetDescendants() do
		if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
			local light = Instance.new("PointLight")
			light.Range = 22
			light.Brightness = 1.1
			light.Color = Color3.fromRGB(255, 200, 140)
			light.Shadows = false
			light.Parent = d
			d:SetAttribute("OnColor", d.Color)
			CollectionService:AddTag(d, "V3Lamp")
		end
	end
end

function DistrictHouses.build(ctx: Context)
	if not source("HouseV3A") then
		return -- assets not imported yet: the V2 district stays
	end
	local t0 = os.clock()
	local map = ctx.Map
	local folder = Instance.new("Folder")
	folder.Name = "V3Houses"
	folder.Parent = map

	for i = 1, #HOUSES do
		local house = map:FindFirstChild("House " .. i)
		if house and house:IsA("Model") then
			upgradeHouse(house)
		end
	end

	-- Back gardens of the lane's south row: a board fence closes the lots off from the open
	-- field, with a side fence between the two gardens. Clear of both ladders (x -139, -84).
	for k = 0, 11 do
		place("PrivacyFence", CFrame.new(-170 + 4 + k * 8, 0, 151), folder)
	end
	for k = 0, 3 do
		place("PrivacyFence", CFrame.new(-122.5, 0, 119 + k * 8) * CFrame.Angles(0, math.pi / 2, 0), folder)
	end
	place("Clothesline", CFrame.new(-157, 0, 144) * CFrame.Angles(0, math.rad(4), 0), folder)
	place("GardenShed", CFrame.new(-104, 0, 144), folder)

	-- Shared driveway between the two street-side houses, the family car under a fallen branch.
	ctx.Prop({
		Parent = folder,
		Name = "Driveway",
		Size = Vector3.new(9, 0.2, 26),
		Position = Vector3.new(-122.5, 0.1, 41),
		Color = S.Concrete,
		Material = Enum.Material.Concrete,
		CanCollide = false,
		CastShadow = false,
	})
	place("Sedan", CFrame.lookAt(Vector3.new(-122.5, 0.2, 44), Vector3.new(-122.5, 0.2, 30)), folder)

	-- Landmark: the oak lies across the end of the lane (trunk north-south, root plate to the
	-- north), behind the V2 road-closed barrier. Visual mesh plus one trunk collider.
	local oakAt = Vector3.new(-185, 0, 74)
	if place("FallenOak", CFrame.new(oakAt) * CFrame.Angles(0, math.rad(90), 0), folder) then
		local trunk = ctx.Part({
			Parent = folder,
			Name = "OakTrunkCollider",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(34, 4.4, 4.4),
			CFrame = CFrame.new(oakAt + Vector3.new(0, 2.2, 0)) * CFrame.Angles(0, math.rad(90), 0),
			Transparency = 1,
			CastShadow = false,
		})
		trunk.CanCollide = true
	end

	-- Lane lamps: one beside the oak, one at the lane mouth (the main road's lamp at x -14 lights
	-- the junction itself). Lightning storms are dark; these keep the route and the oak readable.
	laneLamp(Vector3.new(-174, 0, 77.5), Vector3.new(0, 0, -1), folder)
	laneLamp(Vector3.new(-40, 0, 77.5), Vector3.new(0, 0, -1), folder)

	-- Puddles collect in the lane after a flood (EnvironmentFX).
	for _, pos in { Vector3.new(-140, 0.3, 72), Vector3.new(-60, 0.3, 72) } do
		local spot = ctx.Prop({
			Parent = folder,
			Name = "PuddleSpot",
			Size = Vector3.one,
			Position = pos,
			Transparency = 1,
			CanCollide = false,
		})
		CollectionService:AddTag(spot, "V3PuddleSpot")
	end

	map:SetAttribute("C1HousesBuildMs", math.floor((os.clock() - t0) * 1000))
end

return DistrictHouses
