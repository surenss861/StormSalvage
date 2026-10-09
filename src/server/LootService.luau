-- Spawns salvage around town, handles pickups, storm-only legendary loot,
-- and dropping a player's bag where they die.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Shelter = require(ReplicatedStorage.Shared.Shelter)
local PlayerService = require(script.Parent.PlayerService)
local StormStats = require(script.Parent.StormStats)

local LootService = {}

type Zone = {
	Points: { Vector3 },
	Label: string,
	Occupied: { [number]: Instance },
	Pool: { { Id: string, Weight: number } },
}

local zones: { [string]: Zone } = {}
local folder: Folder
local rng = Random.new()
local townMin: Vector3, townMax: Vector3

-- Blender-made salvage models (assets/roblox/salvage). Each loot item is an invisible anchored
-- root part (prompt, light, marker) with the model's MeshParts welded to it, so the client's
-- bob/spin moves the whole item by setting one CFrame.
local salvageModels: Instance? = nil
do
	local assets = ServerStorage:FindFirstChild("Assets")
	salvageModels = assets and assets:FindFirstChild("salvage")
end

local function attachModel(item: Part, model: Model, height: number)
	local pivot = model:GetPivot()
	local base = item.CFrame * CFrame.new(0, -height / 2, 0)
	for _, piece in model:GetChildren() do
		if piece:IsA("BasePart") then
			local clone = piece:Clone()
			clone.CFrame = base * pivot:ToObjectSpace(piece.CFrame)
			clone.Anchored = false
			clone.CanCollide = false
			clone.CanQuery = false
			clone.CanTouch = false
			clone.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = item
			weld.Part1 = clone
			weld.Parent = clone
			clone.Parent = item
		end
	end
end

local function pickWeighted(pool: { { Id: string, Weight: number } }): string
	local total = 0
	for _, entry in pool do
		total += entry.Weight
	end
	local roll = rng:NextNumber(0, total)
	for _, entry in pool do
		roll -= entry.Weight
		if roll <= 0 then
			return entry.Id
		end
	end
	return pool[1].Id
end

local function groundY(position: Vector3): number
	local params = RaycastParams.new()
	local exclude = { folder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true -- drops during a flood should land on the ground, not float
	local hit = workspace:Raycast(position + Vector3.new(0, 3, 0), Vector3.new(0, -60, 0), params)
	return hit and hit.Position.Y or position.Y
end

-- owner: for a death drop, only this player can grab it until ownerOnlyUntil (os.clock()).
local function createLoot(
	lootId: string,
	floorPosition: Vector3,
	onTaken: (() -> ())?,
	lifetime: number?,
	owner: Player?,
	ownerOnlyUntil: number?
): Part
	local def = Config.Loot[lootId]
	local rarityColor = Config.RarityColors[def.Rarity]

	local item = Instance.new("Part")
	item.Name = lootId
	item.Anchored = true
	item.CanCollide = false
	item.CanTouch = false
	local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local model = salvageModels and salvageModels:FindFirstChild(lootId)
	local height
	if model and model:IsA("Model") then
		local size = model:GetExtentsSize()
		height = size.Y
		item.Size = size
		item.Transparency = 1
		item.CFrame = CFrame.new(floorPosition + Vector3.new(0, height / 2, 0)) * yaw
		attachModel(item, model, height)
	else
		-- Primitive fallback if the asset library is missing.
		if def.Shape then
			item.Shape = def.Shape
		end
		item.Size = def.Size
		item.Color = def.Color
		item.Material = def.Material
		height = if def.Upright then def.Size.X else def.Size.Y
		item.CFrame = CFrame.new(floorPosition + Vector3.new(0, height / 2, 0))
			* yaw
			* (if def.Upright then CFrame.Angles(0, 0, math.pi / 2) else CFrame.identity)
	end
	item:SetAttribute("LootId", lootId)

	-- Floating rarity marker (Highlights are capped at 31 on screen, so avoid them here).
	local marker = Instance.new("BillboardGui")
	marker.Size = UDim2.fromOffset(18, 18)
	marker.StudsOffset = Vector3.new(0, height / 2 + 1.5, 0)
	marker.MaxDistance = 80
	marker.LightInfluence = 0
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromScale(1, 1)
	dot.BackgroundColor3 = rarityColor
	dot.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = dot
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = dot
	dot.Parent = marker
	marker.Parent = item

	if def.Rarity ~= "Common" and def.Rarity ~= "Uncommon" then
		local light = Instance.new("PointLight")
		light.Color = rarityColor
		light.Range = 10
		light.Brightness = 2
		light.Parent = item
		local sparkle = Instance.new("Sparkles")
		sparkle.SparkleColor = rarityColor
		sparkle.Parent = item
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Grab"
	prompt.ObjectText = ("%s  (%d)"):format(def.Name, def.Value)
	prompt.HoldDuration = math.clamp(def.Value / 150, 0.2, 1.2)
	-- Storm Cores can sit under a flood, so reach them from the water's surface.
	prompt.MaxActivationDistance = def.Rarity == "Legendary" and 16 or 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = item

	local taken = false
	if owner then
		prompt.ObjectText = ("%s's %s  (%d)"):format(owner.DisplayName, def.Name, def.Value)
	end

	prompt.Triggered:Connect(function(player)
		if taken or not PlayerService.isNear(player, prompt) then
			return
		end
		if owner and player ~= owner and owner.Parent and os.clock() < (ownerOnlyUntil or 0) then
			PlayerService.notify(
				player,
				("That's %s's bag. Free to grab in %ds."):format(
					owner.DisplayName,
					math.ceil((ownerOnlyUntil :: number) - os.clock())
				),
				Color3.fromRGB(255, 200, 120)
			)
			return
		end
		if not PlayerService.tryCarry(player, lootId) then
			return
		end
		StormStats.collected(player, lootId)
		taken = true
		item:Destroy()
		if def.Rarity == "Legendary" or def.Rarity == "Epic" then
			PlayerService.notifyAll(("%s grabbed a %s!"):format(player.DisplayName, def.Name), rarityColor)
		end
		if onTaken then
			onTaken()
		end
	end)

	item.Parent = folder

	if lifetime then
		task.delay(lifetime, function()
			if not taken and item.Parent then
				taken = true
				item:Destroy()
				if onTaken then
					onTaken()
				end
			end
		end)
	end
	return item
end

local function spawnInZone(zoneName: string)
	local zone = zones[zoneName]
	local free = {}
	for i in zone.Points do
		if not zone.Occupied[i] then
			table.insert(free, i)
		end
	end
	if #free == 0 then
		return
	end
	local index = free[rng:NextInteger(1, #free)]
	local point = zone.Points[index]
	local floor = point - Vector3.new(0, 1.5, 0)
	zone.Occupied[index] = createLoot(pickWeighted(zone.Pool), floor, function()
		zone.Occupied[index] = nil
	end)
end

local function zoneCount(zone: Zone): number
	local n = 0
	for _ in zone.Occupied do
		n += 1
	end
	return n
end

-- A random spot on open ground in town (roads, grass, plaza): never indoors or under a roof.
local function exposedTownPoint(): Vector3?
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { folder }
	params.IgnoreWater = true
	for _ = 1, 25 do
		local x = rng:NextNumber(townMin.X, townMax.X)
		local z = rng:NextNumber(townMin.Z + 30, townMax.Z) -- stay off the foot of the ramp
		local hit = workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -100, 0), params)
		-- Building floors are at y=1, so anything lower is outdoor ground.
		if hit and hit.Position.Y < 0.9 and not Shelter.isSheltered(hit.Position + Vector3.new(0, 2, 0)) then
			return hit.Position
		end
	end
	return nil
end

-- Legendary loot that only appears mid-storm, deliberately in exposed spots.
function LootService.spawnStormCores(count: number)
	for _ = 1, count do
		local point = exposedTownPoint()
		if point then
			createLoot("StormCore", point, nil, Config.Cycle.Storm + Config.Cycle.Aftermath)
		end
	end
end

-- Refill every zone instantly (used after a storm so the town feels "fresh").
function LootService.refillAll()
	for name, zone in zones do
		while zoneCount(zone) < Config.MaxLootPerZone and zoneCount(zone) < #zone.Points do
			spawnInZone(name)
		end
	end
end

local function dropBag(player: Player, character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local carried = PlayerService.takeCarried(player)
	if not root or #carried == 0 then
		return
	end
	local origin = root.Position
	local ownerOnlyUntil = os.clock() + Config.BagOwnerOnlySeconds
	for i = 1, #carried do
		local pos = origin + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6))
		pos = Vector3.new(pos.X, groundY(pos), pos.Z)
		createLoot(carried[i], pos, nil, Config.BagLifetimeSeconds, player, ownerOnlyUntil)
	end
	PlayerService.notify(
		player,
		("You dropped your bag! It's yours alone for %ds, then anyone can grab it."):format(
			Config.BagOwnerOnlySeconds
		),
		Color3.fromRGB(255, 120, 90)
	)
end

function LootService.init(map)
	folder = Instance.new("Folder")
	folder.Name = "Loot"
	folder.Parent = workspace
	townMin, townMax = map.TownMin, map.TownMax

	for name, info in map.Zones do
		zones[name] =
			{ Points = info.Points, Label = info.Label, Occupied = {}, Pool = Config.ZonePools[name] }
	end
	LootService.refillAll()

	PlayerService.onDied(dropBag)

	task.spawn(function()
		while true do
			task.wait(Config.LootRespawnSeconds)
			for name, zone in zones do
				if zoneCount(zone) < Config.MaxLootPerZone then
					spawnInZone(name)
				end
			end
		end
	end)
end

return LootService
