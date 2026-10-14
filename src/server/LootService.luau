-- @file Salvage spawning, pickups and storm loot
-- @domain salvage-economy
-- @status stable
-- @see [[2026-10-09-salvage-progression]]
-- Spawns salvage around town, handles pickups, storm-only legendary loot,
-- and dropping a player's bag where they die.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Bands = require(ReplicatedStorage.Shared.Bands)
local Config = require(ReplicatedStorage.Shared.Config)
local BigMoney = require(ReplicatedStorage.Shared.BigMoney)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shelter = require(ReplicatedStorage.Shared.Shelter)
local RewardClaims = require(script.Parent.RewardClaims)
local PlayerService = require(script.Parent.PlayerService)
local SessionStats = require(script.Parent.SessionStats)
local StormStats = require(script.Parent.StormStats)
local ContractService = require(script.Parent.ContractService)

local LootService = {}

type Zone = {
	Points: { Vector3 },
	Label: string,
	Occupied: { [number]: Instance },
	Pool: { { Id: string, Weight: number } },
}

local zones: { [string]: Zone } = {}
local folder: Folder
local rng = require(game:GetService("ReplicatedStorage").Shared.QASeed).random(1)
local pickupRemote = Remotes.get("Pickup")
local townMin: Vector3, townMax: Vector3

-- Blender-made salvage models (assets/roblox/salvage). Each loot item is an invisible anchored
-- root part (prompt, light, marker) with the model's MeshParts welded to it, so the client's
-- bob/spin moves the whole item by setting one CFrame.
local salvageModels: Instance? = nil
do
	local assets = ServerStorage:FindFirstChild("Assets")
	salvageModels = assets and assets:FindFirstChild("salvage")
	-- A copy for the client's Salvage Log thumbnails (display only; the server never reads it).
	if salvageModels then
		local copy = salvageModels:Clone()
		copy.Name = "SalvageModels"
		copy.Parent = game:GetService("ReplicatedStorage")
	end
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

local STARTER_AT = Vector3.new(6, 0, -128) -- on the main road just past the foot of the ramp

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
	onTaken: ((Player?) -> ())?,
	lifetime: number?,
	owner: Player?,
	ownerOnlyUntil: number?,
	zone: string?,
	recovered: boolean?
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
	-- Commons are most of the loot on screen, so their dots are small and short-range (the bob
	-- and the prompt still find them); rarer finds keep a bigger dot visible from further away.
	local markerSize, markerRange = 18, 80
	if def.Rarity == "Common" then
		markerSize, markerRange = 10, 40
	elseif def.Rarity == "Uncommon" then
		markerSize, markerRange = 13, 60
	end
	local marker = Instance.new("BillboardGui")
	marker.Size = UDim2.fromOffset(markerSize, markerSize)
	marker.StudsOffset = Vector3.new(0, height / 2 + 1.5, 0)
	marker.MaxDistance = markerRange
	marker.LightInfluence = 0
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromScale(1, 1)
	dot.BackgroundColor3 = rarityColor
	dot.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = dot
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = if def.Rarity == "Common" then 1 else 2
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = dot
	dot.Parent = marker
	marker.Parent = item

	-- Rare and up glow in their rarity colour; each tier above adds its own motion, so a Mythic
	-- reads differently from a Legendary at a glance (client LootFx tones them down in Reduced
	-- Effects). Rare: light. Epic: + drifting motes. Legendary: + a rising column. Mythic: +
	-- a fast swirl and a stronger light.
	local tier = ({ Rare = 1, Epic = 2, Legendary = 3, Mythic = 4 } :: { [string]: number })[def.Rarity]
	if tier then
		local light = Instance.new("PointLight")
		light.Color = rarityColor
		light.Range = 8 + tier * 3
		light.Brightness = 1.5 + tier * 0.5
		light.Parent = item
		if tier >= 2 then
			local motes = Instance.new("ParticleEmitter")
			motes.Name = "Motes"
			motes.Color = ColorSequence.new(rarityColor)
			motes.LightEmission = 1
			motes.Size = NumberSequence.new(0.25, 0)
			motes.Lifetime = NumberRange.new(1.2, 2)
			motes.Speed = NumberRange.new(0.5, 1.5)
			motes.SpreadAngle = Vector2.new(180, 180)
			motes.Rate = 4 * tier
			motes:SetAttribute("BaseRate", motes.Rate)
			motes.Parent = item
			CollectionService:AddTag(motes, "LootFx")
		end
		if tier >= 3 then
			local column = Instance.new("ParticleEmitter")
			column.Name = "Column"
			column.Color = ColorSequence.new(rarityColor)
			column.LightEmission = 1
			column.Size =
				NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
			column.Transparency = NumberSequence.new(0.2, 1)
			column.Lifetime = NumberRange.new(1, 1.6)
			column.Speed = NumberRange.new(4, 6)
			column.EmissionDirection = Enum.NormalId.Top
			column.SpreadAngle = Vector2.new(6, 6)
			column.Rate = if tier >= 4 then 18 else 8
			column:SetAttribute("BaseRate", column.Rate)
			column.Parent = item
			CollectionService:AddTag(column, "LootFx")
		end
		if tier >= 4 then
			local swirl = Instance.new("ParticleEmitter")
			swirl.Name = "Swirl"
			swirl.Color = ColorSequence.new(rarityColor, Color3.new(1, 1, 1))
			swirl.LightEmission = 1
			swirl.Size = NumberSequence.new(0.35, 0)
			swirl.Lifetime = NumberRange.new(0.8, 1.2)
			swirl.Speed = NumberRange.new(3, 4)
			swirl.RotSpeed = NumberRange.new(-360, 360)
			swirl.SpreadAngle = Vector2.new(180, 30)
			swirl.Rate = 24
			swirl:SetAttribute("BaseRate", swirl.Rate)
			swirl.Parent = item
			CollectionService:AddTag(swirl, "LootFx")
		end
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Grab"
	prompt.ObjectText = ("%s  (%s)"):format(def.Name, BigMoney.full(def.Value))
	if def.License then
		-- Band 2 salvage: everyone sees it, only licence holders can take it.
		item:SetAttribute("Class", def.Class)
		item:SetAttribute("License", def.License)
		prompt.ObjectText ..= "  ·  PRO"
	end
	prompt.HoldDuration = math.clamp(def.Value / 150, 0.2, 1.2)
	-- Storm Cores and dropped bags can sit under a flood, so reach them from the water's surface.
	prompt.MaxActivationDistance = if def.Rarity == "Legendary"
			or def.Rarity == "Mythic"
			or owner
		then 16
		else 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = item

	local taken = false
	if owner then
		prompt.ObjectText = ("%s's %s  (%d)"):format(owner.DisplayName, def.Name, def.Value)
		-- Lets clients mark the owner's bag and show when it opens up to everyone.
		item:SetAttribute("OwnerId", owner.UserId)
		item:SetAttribute(
			"OwnerUntil",
			workspace:GetServerTimeNow() + ((ownerOnlyUntil or os.clock()) - os.clock())
		)
	end

	prompt.Triggered:Connect(function(player)
		if taken or not PlayerService.isNear(player, prompt) then
			return
		end
		if def.License and not PlayerService.licensed(player, def.License) then
			PlayerService.notify(
				player,
				("Needs the %s (Gear Shop)."):format(
					Bands.Licenses[def.License] and Bands.Licenses[def.License].DisplayName or "licence"
				),
				Color3.fromRGB(255, 200, 120)
			)
			return
		end
		-- A share (Armored Wreck, Storm Titan) is only ever its owner's, even if they leave.
		if owner and player ~= owner and item:GetAttribute("Share") then
			PlayerService.notify(
				player,
				if item:GetAttribute("Share") == "Starter"
					then ("That's %s's welcome find."):format(owner.DisplayName)
					else ("That's %s's share. Earn your own: help with the work."):format(
						owner.DisplayName
					),
				Color3.fromRGB(255, 200, 120)
			)
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
		SessionStats.collected(player, lootId)
		-- A dropped bag or a knocked-loose event core was already counted when first picked up.
		ContractService.collected(player, lootId, zone, owner ~= nil or recovered == true)
		taken = true
		item:Destroy()
		pickupRemote:FireClient(player, { Id = lootId, Position = item.Position })
		-- Only the signature find goes to everyone; Epic finds get the finder's own card.
		if (def.Rarity == "Legendary" or def.Rarity == "Mythic") and def.Class ~= "StormHeart" then -- the Eye announces its own
			PlayerService.notifyAll(("%s grabbed a %s!"):format(player.DisplayName, def.Name), rarityColor)
		end
		if onTaken then
			onTaken(player)
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

-- Areas kept clear of zone salvage for a while (the Armored Wreck: a "Grab" prompt next to a lock
-- would take the cutting prompt's key).
type Clear = { Center: Vector3, Radius: number, Until: number }
local clearAreas: { Clear } = {}

local function blocked(point: Vector3): boolean
	local now = os.clock()
	for i = #clearAreas, 1, -1 do
		local a = clearAreas[i]
		if now >= a.Until then
			table.remove(clearAreas, i)
		elseif ((point - a.Center) * Vector3.new(1, 0, 1)).Magnitude <= a.Radius then
			return true
		end
	end
	return false
end

local function spawnInZone(zoneName: string)
	local zone = zones[zoneName]
	local free = {}
	for i in zone.Points do
		if not zone.Occupied[i] and not blocked(zone.Points[i]) then
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
	end, nil, nil, nil, zoneName)
end

-- Items in a zone of one class: ordinary town salvage (class nil) or "Industrial". Each class has
-- its own cap, so industrial salvage never crowds out the ordinary kind.
local function zoneCount(zone: Zone, class: string?): number
	local n = 0
	for _, item in zone.Occupied do
		if item:GetAttribute("Class") == class then
			n += 1
		end
	end
	return n
end

local function spawnIndustrial(zoneName: string)
	local zone = zones[zoneName]
	local free = {}
	for i in zone.Points do
		if not zone.Occupied[i] and not blocked(zone.Points[i]) then
			table.insert(free, i)
		end
	end
	if #free == 0 then
		return
	end
	local index = free[rng:NextInteger(1, #free)]
	local floor = zone.Points[index] - Vector3.new(0, 1.5, 0)
	zone.Occupied[index] = createLoot(pickWeighted(Bands.Industrial :: any), floor, function()
		zone.Occupied[index] = nil
	end, nil, nil, nil, zoneName)
end

local function refillZone(name: string, all: boolean)
	local zone = zones[name]
	repeat
		local before = zoneCount(zone) + zoneCount(zone, "Industrial")
		if zoneCount(zone) < Config.MaxLootPerZone then
			spawnInZone(name)
		end
		if Bands.IndustrialZones[name] and zoneCount(zone, "Industrial") < Bands.IndustrialPerZone then
			spawnIndustrial(name)
		end
		local after = zoneCount(zone) + zoneCount(zone, "Industrial")
	until not all or after == before
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

-- Band 3: the storm's artifacts (the kind its storm type forms), out in the open, melting away
-- after `lifetime`. Only Storm Hunter licence holders can take them (createLoot's licence gate).
-- Returns how many formed.
function LootService.spawnArtifacts(storm: string, lifetime: number): number
	local id: string? = nil
	for _, a in Bands.Artifacts do
		if a.Storm == storm then
			id = a.Id
		end
	end
	if not id then
		return 0
	end
	local n = 0
	for _ = 1, Bands.ArtifactsPerStorm do
		local point = exposedTownPoint()
		if point then
			createLoot(id :: string, point, nil, lifetime)
			n += 1
		end
	end
	return n
end

function LootService.artifactName(storm: string): string
	for _, a in Bands.Artifacts do
		if a.Storm == storm then
			return a.Name .. "s"
		end
	end
	return "artifacts"
end

-- A random point on open ground in town (for events that drift across it, e.g. the Storm's Eye).
function LootService.randomExposedPoint(): Vector3?
	return exposedTownPoint()
end

-- Studio QA (DebugService): one item of any kind on the floor at `position`.
-- A one-off item for an event (Storm Pursuit). `onTaken(player)` runs when someone takes it, or
-- with nil when it expires after `lifetime`. Anyone can grab it (no owner window).
-- `recovered`: the same item back on the ground (an event core knocked loose), so grabbing it
-- again isn't a new find (Salvage Log, contracts).
function LootService.spawnSpecial(
	lootId: string,
	position: Vector3,
	lifetime: number,
	onTaken: (Player?) -> (),
	recovered: boolean?
): Part
	return createLoot(
		lootId,
		Vector3.new(position.X, groundY(position), position.Z),
		onTaken,
		lifetime,
		nil,
		nil,
		nil,
		recovered
	)
end

-- A reward only `owner` can take, for `lifetime` seconds (then it's gone): a cooperative
-- event's share, so nobody can sweep up a crew's rewards.
function LootService.spawnFor(
	owner: Player,
	lootId: string,
	position: Vector3,
	lifetime: number,
	onTaken: (Player?) -> (),
	kind: string?
): Part
	local item = createLoot(
		lootId,
		Vector3.new(position.X, groundY(position), position.Z),
		onTaken,
		lifetime,
		owner,
		os.clock() + lifetime
	)
	item:SetAttribute("Share", kind or "Coop")
	item:SetAttribute("ShareId", HttpService:GenerateGUID(false))
	return item
end

function LootService.spawnForTest(lootId: string, position: Vector3): Instance
	assert(RunService:IsStudio(), "Studio only")
	assert(Config.Loot[lootId], "unknown loot " .. lootId)
	return createLoot(lootId, position)
end

-- Keep zone salvage out of a circle for `seconds`: what's there now goes, nothing respawns there.
function LootService.keepClear(center: Vector3, radius: number, seconds: number)
	table.insert(clearAreas, { Center = center, Radius = radius, Until = os.clock() + seconds })
	for _, zone in zones do
		for index, item in zone.Occupied do
			local point = zone.Points[index]
			if point and ((point - center) * Vector3.new(1, 0, 1)).Magnitude <= radius then
				zone.Occupied[index] = nil
				item:Destroy()
			end
		end
	end
end

-- Refill every zone instantly (used after a storm so the town feels "fresh").
function LootService.refillAll()
	for name in zones do
		refillZone(name, true)
	end
end

local function dropBag(player: Player, character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local carried = PlayerService.takeCarried(player)
	if not root or #carried == 0 then
		return
	end
	SessionStats.lostBag(player)
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

-- The live loot parts (each has a LootId attribute; dropped bags also have OwnerId). Read-only
-- for other services, e.g. DetectorService's scans.
function LootService.folder(): Folder?
	return folder
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
	-- Leaving with cooperative shares still on the ground: they wait for the owner's next join
	-- (RewardClaims), never for anyone else. (Welcome finds are just gone: they're a gift.)
	Players.PlayerRemoving:Connect(function(player)
		local items = {}
		local ids = {}
		for _, item in folder:GetChildren() do
			if item:GetAttribute("OwnerId") == player.UserId and item:GetAttribute("Share") == "Coop" then
				table.insert(items, item:GetAttribute("LootId") :: string)
				table.insert(ids, item:GetAttribute("ShareId") :: string)
				item:Destroy()
			end
		end
		if #items > 0 then
			table.sort(ids)
			RewardClaims.hold(player.UserId, "left:" .. ids[1], items, "Left behind")
		end
	end)
	-- The first meaningful reward arrives fast: a brand-new player (nothing sold yet) finds a
	-- glowing Jukebox (140 coins) for them alone at the foot of the ramp, a few seconds' walk from
	-- spawn, enough for their first gear once sold. Once per session, only until the first sale.
	PlayerService.onLoaded(function(player, session)
		if (session.Data.Stats.ItemsSold or 0) > 0 then
			return
		end
		task.delay(3, function()
			if player.Parent then
				LootService.spawnFor(player, "Jukebox", STARTER_AT, 600, function() end, "Starter")
			end
		end)
	end)

	task.spawn(function()
		while true do
			task.wait(Config.LootRespawnSeconds)
			for name in zones do
				refillZone(name, false)
			end
		end
	end)
end

return LootService
