-- Runs the weather cycle: Calm -> Warning -> Storm -> Aftermath, forever.
-- Storms: Wind (flying debris), Flood (rising terrain water), Lightning (telegraphed strikes).

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

local StormService = {}

local T = Config.StormTuning

local stormStateRemote = Remotes.get("StormState")
local lightningRemote = Remotes.get("LightningWarning")

local map
local rng = Random.new()
local state = { Phase = "Calm", Storm = nil :: string?, EndsAt = 0, WindDir = Vector3.new(1, 0, 0) }
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

local function randomTownPoint(): Vector3
	return Vector3.new(rng:NextNumber(map.TownMin.X, map.TownMax.X), 0, rng:NextNumber(map.TownMin.Z + 30, map.TownMax.Z))
end

local function tweenSky(stormy: boolean, color: Color3?)
	local info = TweenInfo.new(6, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, {
		Brightness = stormy and 0.8 or 2,
		ClockTime = stormy and 17.6 or 14.5,
		OutdoorAmbient = stormy and Color3.fromRGB(90, 95, 110) or Color3.fromRGB(128, 128, 128),
	}):Play()
	TweenService:Create(atmosphere, info, {
		Density = stormy and 0.5 or 0.28,
		Haze = stormy and 2.5 or 0.5,
		Color = stormy and (color or Color3.fromRGB(150, 160, 175)):Lerp(Color3.fromRGB(110, 110, 120), 0.6) or Color3.fromRGB(199, 199, 199),
	}):Play()
	TweenService:Create(clouds, info, { Cover = stormy and 0.95 or 0.5, Density = stormy and 0.9 or 0.4 }):Play()
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
	p.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(-10, 10), rng:NextNumber(-10, 10))
	p.Touched:Connect(function(hit)
		if p.AssemblyLinearVelocity.Magnitude < 25 then
			return
		end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and os.clock() - (debrisCooldown[player] or 0) > 0.8 then
			debrisCooldown[player] = os.clock()
			PlayerService.damage(player, T.DebrisDamage)
		end
	end)
	Debris:AddItem(p, 5)
end

local function runWind(token: number)
	local dir = state.WindDir
	local perp = Vector3.new(-dir.Z, 0, dir.X)
	while stormToken == token do
		local exposed = exposedPlayers()
		local origin, target
		if #exposed > 0 and rng:NextNumber() < 0.55 then
			local root = exposed[rng:NextInteger(1, #exposed)].Root
			target = root.Position + perp * rng:NextNumber(-8, 8)
			origin = target - dir * 70 + Vector3.new(0, rng:NextNumber(4, 9), 0)
		else
			target = randomTownPoint()
			origin = target - dir * 120 + perp * rng:NextNumber(-60, 60) + Vector3.new(0, rng:NextNumber(5, 14), 0)
		end
		local speed = rng:NextNumber(70, 95)
		local flatDir = Vector3.new(target.X - origin.X, 0, target.Z - origin.Z).Unit
		launchDebris(origin, flatDir * speed + Vector3.new(0, 12, 0))
		task.wait(T.DebrisInterval)
	end
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
	workspace.Terrain:FillBlock(CFrame.new(0, 10, 0), Vector3.new(FLOOD_HALF * 2 + 8, 24, FLOOD_HALF * 2 + 8), Enum.Material.Air)
	floodLevel = 0
end

local function runFlood(token: number)
	local maxY = map.FloodMaxY
	local riseStep = (Config.Cycle.Storm * T.FloodRiseFraction) / (maxY / 4)
	task.spawn(function()
		local bottom = 0
		while stormToken == token and bottom < maxY do
			setWaterLayer(bottom, Enum.Material.Water)
			bottom += 4
			floodLevel = bottom
			task.wait(riseStep)
		end
	end)
	while stormToken == token do
		for _, player in Players:GetPlayers() do
			local root = rootOf(player)
			if root and floodLevel > 0 and root.Position.Y < floodLevel and not inSafeZone(root.Position) then
				PlayerService.damage(player, T.FloodDamagePerSecond / 2)
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
			task.wait(2)
		end
		clearFlood()
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

local function runLightning(token: number)
	local radius, warnTime = T.LightningRadius, T.LightningWarnSeconds
	while stormToken == token do
		local exposed = exposedPlayers()
		local target
		if #exposed > 0 and rng:NextNumber() < T.LightningTargetChance then
			target = exposed[rng:NextInteger(1, #exposed)].Root.Position * Vector3.new(1, 0, 1)
				+ Vector3.new(rng:NextNumber(-5, 5), 0, rng:NextNumber(-5, 5))
		else
			target = randomTownPoint()
		end
		lightningRemote:FireAllClients(target, radius, warnTime)
		task.delay(warnTime, function()
			if stormToken ~= token then
				return
			end
			bolt(target)
			for _, entry in exposedPlayers() do
				local flat = (entry.Root.Position - target) * Vector3.new(1, 0, 1)
				if flat.Magnitude <= radius then
					PlayerService.damage(entry.Player, T.LightningDamage)
				end
			end
		end)
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
			if root and not inSafeZone(root.Position) then
				townSeconds[player] = (townSeconds[player] or 0) + 1
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
			PlayerService.addCoins(player, T.SurvivorBonus)
			PlayerService.notify(player, ("Survived the storm in town! +%d coins"):format(T.SurvivorBonus), Color3.fromRGB(255, 220, 90))
		end
	end
	table.clear(townSeconds)
end

local function cycle()
	local stormNames = { "Wind", "Flood", "Lightning" }
	local last: string? = nil
	while true do
		state.Storm = nil
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
		tweenSky(true, Config.Storms[storm].Color)
		waitPhase(Config.Cycle.Warning)

		stormToken += 1
		local token = stormToken
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
		rewardSurvivors(os.clock() - stormStarted)
		if storm == "Flood" then
			recedeFlood()
		end
		tweenSky(false)
		setPhase("Aftermath", Config.Cycle.Aftermath)
		LootService.refillAll()
		waitPhase(Config.Cycle.Aftermath)
	end
end

-- Studio QA hooks (see DebugService). Not reachable from clients.
function StormService.skipPhase()
	skipRequested = true
end

function StormService.forceNextStorm(name: string)
	forcedStorm = name
end

function StormService.getState()
	return { Phase = state.Phase, Storm = state.Storm, FloodLevel = floodLevel, EndsIn = state.EndsAt - workspace:GetServerTimeNow() }
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
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		debrisCooldown[player] = nil
		townSeconds[player] = nil
	end)

	task.spawn(cycle)
end

return StormService
