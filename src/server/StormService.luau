-- Runs the weather cycle: Calm -> Warning -> Storm -> Aftermath, forever.
-- Storms play differently:
--   Wind: steady wind plus telegraphed gusts that carry the push and the debris. Cross open
--         ground in the lulls.
--   Flood: terrain water rises in announced steps. Get onto a roof (yellow ladders) or uphill.
--   Lightning: telegraphed strikes whose discs never overlap, so each one can be dodged.

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shelter = require(ReplicatedStorage.Shared.Shelter)
local PlayerService = require(script.Parent.PlayerService)
local LootService = require(script.Parent.LootService)
local SessionStats = require(script.Parent.SessionStats)
local StormStats = require(script.Parent.StormStats)
local LookService = require(script.Parent.LookService)

local StormService = {}

local T = Config.StormTuning

local stormStateRemote = Remotes.get("StormState")
local lightningRemote = Remotes.get("LightningWarning")

local map
local rng = Random.new()
-- Replicated to every client (and re-sent to anyone who joins). Gust and flood fields are
-- server timestamps so all clients agree on timing.
local state = {
	Phase = "Calm",
	Storm = nil :: string?,
	EndsAt = 0,
	WindDir = Vector3.new(1, 0, 0),
	GustAt = 0, -- next (or current) gust start
	GustEnd = 0,
	FloodLevel = 0,
	FloodMax = 0,
	FloodNextAt = 0, -- 0 when the water isn't rising
}
local stormToken = 0 -- incremented to stop the running storm effect loop
local skipRequested = false
local forcedStorm: string? = nil
local townSeconds: { [Player]: number } = {}
local floodLevel = 0
local effectsFolder: Folder
local atmosphere: Atmosphere
local clouds: Clouds

local function broadcast()
	stormStateRemote:FireAllClients(state)
end

local function inSafeZone(position: Vector3): boolean
	return position.Z < map.SafeZoneZ and position.Y > 20
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Players in town and not under a roof.
local function exposedPlayers(): { { Player: Player, Root: BasePart } }
	local list = {}
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and not inSafeZone(root.Position) and not Shelter.isSheltered(root.Position) then
			table.insert(list, { Player = player, Root = root })
		end
	end
	return list
end

-- All storm damage goes through here so StormStats can count what armor let through.
local function hurt(player: Player, amount: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local before = humanoid and humanoid.Health or 0
	PlayerService.damage(player, amount)
	if humanoid then
		StormStats.damage(player, before - humanoid.Health)
	end
end

local function randomTownPoint(): Vector3
	return Vector3.new(
		rng:NextNumber(map.TownMin.X, map.TownMax.X),
		0,
		rng:NextNumber(map.TownMin.Z + 30, map.TownMax.Z)
	)
end

-- Tweens the sky to the active look profile's goals for a storm-cycle phase (LookService).
local function tweenSky(phase: string, storm: string?)
	local info = TweenInfo.new(6, Enum.EasingStyle.Sine)
	local goals = LookService.targetsFor(phase, storm, storm and Config.Storms[storm].Color or nil)
	TweenService:Create(Lighting, info, goals.Lighting):Play()
	local grade = Lighting:FindFirstChild("Grade")
	if grade then
		TweenService:Create(grade, info, goals.Grade):Play()
	end
	TweenService:Create(atmosphere, info, goals.Atmosphere):Play()
	TweenService:Create(clouds, info, goals.Clouds):Play()
end

---------------------------------------------------------------------------- Wind

local debrisCooldown: { [Player]: number } = {}

local function launchDebris(origin: Vector3, velocity: Vector3)
	local plank = rng:NextNumber() < 0.5
	local p = Instance.new("Part")
	p.Size = plank and Vector3.new(0.6, 0.4, rng:NextNumber(4, 7)) or Vector3.one * rng:NextNumber(1.5, 3)
	p.Material = plank and Enum.Material.WoodPlanks or Enum.Material.CorrodedMetal
	p.Color = plank and Color3.fromRGB(150, 110, 70) or Color3.fromRGB(120, 100, 90)
	p.CFrame = CFrame.new(origin) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
	p.CanQuery = false
	p.Parent = effectsFolder
	p:SetNetworkOwner(nil)
	p.AssemblyLinearVelocity = velocity
	p.AssemblyAngularVelocity =
		Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(-10, 10), rng:NextNumber(-10, 10))
	p.Touched:Connect(function(hit)
		if p.AssemblyLinearVelocity.Magnitude < 25 then
			return
		end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and os.clock() - (debrisCooldown[player] or 0) > 0.8 then
			debrisCooldown[player] = os.clock()
			hurt(player, T.DebrisDamage)
		end
	end)
	Debris:AddItem(p, 5)
end

-- Launch velocity that carries a piece from origin to target under gravity in `flight` seconds.
local function ballistic(origin: Vector3, target: Vector3, flight: number): Vector3
	local g = workspace.Gravity
	local delta = target - origin
	return Vector3.new(delta.X / flight, (delta.Y + 0.5 * g * flight * flight) / flight, delta.Z / flight)
end

-- One piece of debris, aimed at chest height near an exposed player some of the time.
local function throwDebris(aimChance: number)
	local dir = state.WindDir
	local perp = Vector3.new(-dir.Z, 0, dir.X)
	local exposed = exposedPlayers()
	local origin, target
	if #exposed > 0 and rng:NextNumber() < aimChance then
		local root = exposed[rng:NextInteger(1, #exposed)].Root
		target = root.Position + perp * rng:NextNumber(-T.DebrisSpread, T.DebrisSpread)
		origin = target - dir * 45 + Vector3.new(0, rng:NextNumber(3, 6), 0)
	else
		target = randomTownPoint() + Vector3.new(0, 2, 0)
		origin = target - dir * 70 + perp * rng:NextNumber(-40, 40) + Vector3.new(0, rng:NextNumber(5, 12), 0)
	end
	local speed = rng:NextNumber(70, 95)
	local flight = (Vector3.new(target.X - origin.X, 0, target.Z - origin.Z)).Magnitude / speed
	launchDebris(origin, ballistic(origin, target, flight))
end

-- Lull -> warning -> gust, repeating. Clients read GustAt/GustEnd from the storm state to
-- show the warning and apply the stronger push, so everyone sees the same gust.
local function runWind(token: number)
	local function now(): number
		return workspace:GetServerTimeNow()
	end
	local function schedule(lull: number)
		state.GustAt = now() + lull + T.GustWarnSeconds
		state.GustEnd = state.GustAt + T.GustSeconds
		broadcast()
	end
	schedule(rng:NextNumber(1, 2)) -- first gust shortly after the storm starts
	while stormToken == token do
		local t = now()
		if t >= state.GustEnd then
			schedule(rng:NextNumber(T.GustLull[1], T.GustLull[2]))
		end
		local gusting = t >= state.GustAt and t < state.GustEnd
		throwDebris(if gusting then 0.55 else 0.15)
		task.wait(if gusting then T.GustDebrisInterval else T.DebrisInterval)
	end
	state.GustAt, state.GustEnd = 0, 0
end

---------------------------------------------------------------------------- Flood

local FLOOD_HALF = 205

local function setWaterLayer(bottom: number, material: Enum.Material)
	workspace.Terrain:FillBlock(
		CFrame.new(0, bottom + 2, 0),
		Vector3.new(FLOOD_HALF * 2, 4, FLOOD_HALF * 2),
		material
	)
end

local function clearFlood()
	workspace.Terrain:FillBlock(
		CFrame.new(0, 10, 0),
		Vector3.new(FLOOD_HALF * 2 + 8, 24, FLOOD_HALF * 2 + 8),
		Enum.Material.Air
	)
	floodLevel = 0
end

local function runFlood(token: number)
	local maxY = map.FloodMaxY
	state.FloodMax = maxY
	task.spawn(function()
		local bottom = 0
		local wait = T.FloodFirstRiseSeconds
		while stormToken == token and bottom < maxY do
			state.FloodNextAt = workspace:GetServerTimeNow() + wait
			broadcast()
			task.wait(wait)
			if stormToken ~= token then
				return
			end
			setWaterLayer(bottom, Enum.Material.Water)
			bottom += 4
			floodLevel = bottom
			state.FloodLevel = bottom
			wait = T.FloodStepSeconds
		end
		state.FloodNextAt = 0
		broadcast()
	end)
	while stormToken == token do
		for _, player in Players:GetPlayers() do
			local root = rootOf(player)
			if root and floodLevel > 0 and root.Position.Y < floodLevel and not inSafeZone(root.Position) then
				hurt(player, T.FloodDamagePerSecond / 2)
			end
		end
		task.wait(0.5)
	end
end

local function recedeFlood()
	task.spawn(function()
		local top = floodLevel
		while top > 0 do
			top -= 4
			setWaterLayer(top, Enum.Material.Air)
			floodLevel = top
			state.FloodLevel = top
			broadcast()
			task.wait(2)
		end
		clearFlood()
		state.FloodLevel = 0
		broadcast()
	end)
end

---------------------------------------------------------------------------- Lightning

local function bolt(target: Vector3)
	local points = { target + Vector3.new(0, 160, 0) }
	for i = 1, 7 do
		local t = i / 8
		local base = target + Vector3.new(0, 160 * (1 - t), 0)
		table.insert(points, base + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6)))
	end
	table.insert(points, target)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local seg = Instance.new("Part")
		seg.Anchored = true
		seg.CanCollide = false
		seg.CanQuery = false
		seg.Material = Enum.Material.Neon
		seg.Color = Color3.fromRGB(220, 230, 255)
		seg.Size = Vector3.new(0.6, 0.6, (a - b).Magnitude)
		seg.CFrame = CFrame.lookAt((a + b) / 2, b)
		seg.Parent = effectsFolder
		Debris:AddItem(seg, 0.25)
	end
	local flash = Instance.new("Part")
	flash.Anchored = true
	flash.CanCollide = false
	flash.Transparency = 1
	flash.Position = target + Vector3.new(0, 4, 0)
	local light = Instance.new("PointLight")
	light.Range = 60
	light.Brightness = 8
	light.Color = Color3.fromRGB(200, 220, 255)
	light.Parent = flash
	flash.Parent = effectsFolder
	Debris:AddItem(flash, 0.2)
end

-- Strikes that have been announced but haven't landed yet.
local pending: { { Position: Vector3, Target: Player? } } = {}

local function clearOfPending(position: Vector3): boolean
	for _, strike in pending do
		if ((strike.Position - position) * Vector3.new(1, 0, 1)).Magnitude < T.LightningMinSpacing then
			return false
		end
	end
	return true
end

local function isTargeted(player: Player): boolean
	for _, strike in pending do
		if strike.Target == player then
			return true
		end
	end
	return false
end

-- Picks where the next strike lands. Never overlaps a pending disc (so stepping out of one
-- disc can't put you in another), and never aims twice at the same player at once.
local function pickStrike(): (Vector3?, Player?)
	local exposed = exposedPlayers()
	if #exposed > 0 and rng:NextNumber() < T.LightningTargetChance then
		local entry = exposed[rng:NextInteger(1, #exposed)]
		if not isTargeted(entry.Player) then
			local spot = entry.Root.Position * Vector3.new(1, 0, 1)
				+ Vector3.new(rng:NextNumber(-5, 5), 0, rng:NextNumber(-5, 5))
			if clearOfPending(spot) then
				return spot, entry.Player
			end
		end
	end
	for _ = 1, 6 do
		local spot = randomTownPoint()
		if clearOfPending(spot) then
			return spot, nil
		end
	end
	return nil, nil
end

local function runLightning(token: number)
	local radius, warnTime = T.LightningRadius, T.LightningWarnSeconds
	while stormToken == token do
		local target, aimedAt = pickStrike()
		if target then
			local strike = { Position = target, Target = aimedAt }
			table.insert(pending, strike)
			lightningRemote:FireAllClients(target, radius, warnTime)
			task.delay(warnTime, function()
				local index = table.find(pending, strike)
				if index then
					table.remove(pending, index)
				end
				if stormToken ~= token then
					return
				end
				bolt(target)
				for _, entry in exposedPlayers() do
					local flat = (entry.Root.Position - target) * Vector3.new(1, 0, 1)
					if flat.Magnitude <= radius then
						hurt(entry.Player, T.LightningDamage)
					end
				end
			end)
		end
		task.wait(rng:NextNumber(T.LightningInterval[1], T.LightningInterval[2]))
	end
end

---------------------------------------------------------------------------- Cycle

local runners = { Wind = runWind, Flood = runFlood, Lightning = runLightning }

local function setPhase(phase: string, duration: number)
	state.Phase = phase
	state.EndsAt = workspace:GetServerTimeNow() + duration
	broadcast()
end

-- Waits out a phase, returning early if a Studio debug command asked to skip it.
local function waitPhase(duration: number)
	local endsAt = os.clock() + duration
	skipRequested = false
	while os.clock() < endsAt and not skipRequested do
		task.wait(0.1)
	end
	skipRequested = false
end

-- Counts how long each living player spends in town while a storm is running.
local function trackTownTime(token: number)
	table.clear(townSeconds)
	while stormToken == token do
		for _, player in Players:GetPlayers() do
			local root = rootOf(player)
			if root then
				local inTown = not inSafeZone(root.Position)
				if inTown then
					townSeconds[player] = (townSeconds[player] or 0) + 1
				end
				StormStats.sample(player, inTown, Shelter.isSheltered(root.Position))
			end
		end
		task.wait(1)
	end
end

-- Bonus for players alive in town at the end who also spent most of the storm there,
-- so walking down in the last few seconds doesn't count.
local function rewardSurvivors(stormSeconds: number)
	local needed = math.max(1, math.floor(stormSeconds * T.SurvivorMinTownFraction))
	for _, player in Players:GetPlayers() do
		local session = PlayerService.get(player)
		local root = rootOf(player)
		if session and root and not inSafeZone(root.Position) and (townSeconds[player] or 0) >= needed then
			session.Data.Stats.StormsSurvived += 1
			StormStats.survived(player)
			SessionStats.survivedStorm(player)
			PlayerService.addCoins(player, T.SurvivorBonus)
			PlayerService.notify(
				player,
				("Survived the storm in town! +%d coins"):format(T.SurvivorBonus),
				Color3.fromRGB(255, 220, 90)
			)
		end
	end
	table.clear(townSeconds)
end

local function cycle()
	local stormNames = { "Wind", "Flood", "Lightning" }
	local last: string? = nil
	local first = true
	while true do
		state.Storm = nil
		if not first then
			tweenSky("Calm") -- out of the aftermath's golden light
		end
		first = false
		setPhase("Calm", Config.Cycle.Calm)
		waitPhase(Config.Cycle.Calm)

		local choices = {}
		for _, name in stormNames do
			if name ~= last then
				table.insert(choices, name)
			end
		end
		local storm = forcedStorm or choices[rng:NextInteger(1, #choices)]
		forcedStorm = nil
		last = storm
		local angle = rng:NextNumber(0, math.pi * 2)
		state.Storm = storm
		state.WindDir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		setPhase("Warning", Config.Cycle.Warning)
		tweenSky("Warning", storm)
		waitPhase(Config.Cycle.Warning)

		stormToken += 1
		local token = stormToken
		StormStats.beginStorm(storm)
		SessionStats.stormStarted()
		setPhase("Storm", Config.Cycle.Storm)
		task.spawn(runners[storm], token)
		task.spawn(trackTownTime, token)
		local stormStarted = os.clock()
		task.delay(Config.Cycle.Storm * 0.3, function()
			if stormToken == token then
				LootService.spawnStormCores(Config.StormCoresPerStorm)
				PlayerService.notifyAll("Storm Cores have appeared in town!", Config.RarityColors.Legendary)
			end
		end)
		waitPhase(Config.Cycle.Storm)

		stormToken += 1
		state.GustAt, state.GustEnd, state.FloodNextAt = 0, 0, 0
		rewardSurvivors(os.clock() - stormStarted)
		StormStats.endStorm()
		if storm == "Flood" then
			recedeFlood()
		end
		tweenSky("Aftermath")
		setPhase("Aftermath", Config.Cycle.Aftermath)
		LootService.refillAll()
		waitPhase(Config.Cycle.Aftermath)
	end
end

-- Studio QA hooks (see DebugService). Not reachable from clients.
function StormService.skipPhase()
	skipRequested = true
end

-- Re-applies the sky for the current phase immediately (after a look profile change).
function StormService.refreshSky()
	local goals = LookService.targetsFor(
		state.Phase,
		state.Storm,
		state.Storm and Config.Storms[state.Storm].Color or nil
	)
	for _, pair in
		{ { Lighting, goals.Lighting }, { atmosphere, goals.Atmosphere }, { clouds, goals.Clouds } }
	do
		for k, v in pair[2] do
			(pair[1] :: any)[k] = v
		end
	end
	local grade = Lighting:FindFirstChild("Grade")
	if grade then
		for k, v in goals.Grade do
			(grade :: any)[k] = v
		end
	end
end

function StormService.forceNextStorm(name: string)
	forcedStorm = name
end

function StormService.getState()
	return {
		Phase = state.Phase,
		Storm = state.Storm,
		FloodLevel = floodLevel,
		EndsIn = state.EndsAt - workspace:GetServerTimeNow(),
		GustIn = if state.GustAt > 0 then state.GustAt - workspace:GetServerTimeNow() else nil,
		FloodNextIn = if state.FloodNextAt > 0 then state.FloodNextAt - workspace:GetServerTimeNow() else nil,
	}
end

function StormService.init(mapInfo)
	map = mapInfo
	effectsFolder = Instance.new("Folder")
	effectsFolder.Name = "StormEffects"
	effectsFolder.Parent = workspace

	atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Parent = Lighting
	clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.5
	clouds.Parent = workspace.Terrain

	clearFlood()

	Players.PlayerAdded:Connect(function(player)
		stormStateRemote:FireClient(player, state)
	end)
	-- Dying disqualifies you from this storm's survivor bonus.
	PlayerService.onDied(function(player)
		if state.Phase == "Storm" then
			townSeconds[player] = -math.huge
			StormStats.died(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		debrisCooldown[player] = nil
		townSeconds[player] = nil
	end)

	task.spawn(cycle)
end

return StormService
