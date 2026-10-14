-- @file Storm Pursuit event (server): the rare cache, the twister chase, extraction
-- @domain world
-- @status wip
-- @see [[Pursuit.luau]]
-- @see [[PursuitHud.luau]]
-- @see [[V4-GAMEPLAY]]
-- V4 vertical slice. After a storm passes, a rare cache (a real Storm Core) drops in one district
-- and everyone is told. Whoever grabs it is chased by a rogue twister: a server-moved hazard that
-- is faster than running and slower than sprinting, passes through buildings, and throws
-- telegraphed debris strikes ahead of the carrier. Reaching the Scrapyard plateau extracts it:
-- an extraction bonus (once per event) and a personal record; the core itself still sells at the
-- Scrap Buyer for its normal value. Caught: the core drops at your feet for anyone to grab and
-- the twister stalls for a moment. Out of time: the core destabilises and is gone.
--
-- Authority: every step runs here. The pickup is the normal server-checked prompt
-- (LootService.spawnSpecial); the bag is changed only through PlayerService; the bonus is granted
-- only by the state machine's single transition to Done. Clients get PursuitState and draw.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Pursuit = require(ReplicatedStorage.Shared.Pursuit)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ContractService = require(script.Parent.ContractService)
local LootService = require(script.Parent.LootService)
local PlayerService = require(script.Parent.PlayerService)
local SessionStats = require(script.Parent.SessionStats)
local StormService = require(script.Parent.StormService)

local PursuitService = {}

local P = Config.Pursuit
local stateRemote = Remotes.get("PursuitState")
local strikeRemote = Remotes.get("LightningWarning")

type Event = {
	Id: number,
	Phase: string, -- "Race" | "Chase" | "Loose" | "Done"
	EndsAt: number, -- os.clock() deadline for the current window
	Cache: Instance?, -- the item in the world (race, or loose after a catch)
	Carrier: Player?,
	StartedAt: number?, -- first grab (extraction time is measured from here)
	Twister: BasePart?,
	StunnedUntil: number,
	NextStrike: number,
	LastPos: Vector3,
}

local map: any
local current: Event? = nil
local stormAt = math.huge -- os.clock() when the next storm hits (from the Calm phase)
local nextId = 0

local function serverTime(clockDeadline: number): number
	return workspace:GetServerTimeNow() + (clockDeadline - os.clock())
end

local function rootOf(player: Player?): BasePart?
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function onPlateau(position: Vector3): boolean
	return position.Z < map.SafeZoneZ and position.Y > 20
end

local function flat(v: Vector3): Pursuit.Vec2
	return { X = v.X, Z = v.Z }
end

local function broadcast(e: Event, extra: { [string]: any }?)
	local msg: { [string]: any } = {
		Id = e.Id,
		Phase = e.Phase,
		District = P.District,
		EndsAt = serverTime(e.EndsAt),
		CarrierId = e.Carrier and e.Carrier.UserId or nil,
		CarrierName = e.Carrier and e.Carrier.DisplayName or nil,
		Target = if e.Cache and (e.Cache :: any).Parent then (e.Cache :: BasePart).Position else nil,
	}
	if extra then
		for k, v in extra do
			msg[k] = v
		end
	end
	stateRemote:FireAllClients(msg)
end

local function finish(e: Event, result: string, extra: { [string]: any }?)
	if current ~= e or e.Phase == "Done" then
		return
	end
	e.Phase = "Done"
	if e.Cache and e.Cache.Parent then
		e.Cache:Destroy()
	end
	e.Cache = nil
	if e.Twister then
		e.Twister:Destroy()
		e.Twister = nil
	end
	local payload = { Result = result }
	if extra then
		for k, v in extra do
			payload[k] = v
		end
	end
	broadcast(e, payload)
	current = nil
end

local spawnCache: (e: Event, position: Vector3, lifetime: number) -> ()

local function takeCore(e: Event, player: Player)
	e.Cache = nil
	e.Carrier = player
	if not e.StartedAt then
		e.StartedAt = os.clock()
		e.EndsAt = math.min(os.clock() + P.ExtractSeconds, stormAt - 1)
		local root = rootOf(player)
		local from = if root then root.Position else P.Spot
		local spawn = Pursuit.spawnPoint(flat(from), flat(P.Spot), P.SpawnBehind)
		local twister = Instance.new("Part")
		twister.Name = "PursuitTwister"
		twister.Anchored = true
		twister.CanCollide = false
		twister.CanQuery = false
		twister.CanTouch = false
		twister.Transparency = 1
		twister.Size = Vector3.new(1, 1, 1)
		twister.Position = Vector3.new(spawn.X, 0, spawn.Z)
		twister.Parent = workspace
		e.Twister = twister
		e.StunnedUntil = os.clock() + P.FormSeconds
		e.NextStrike = os.clock() + P.FormSeconds + 2.5
	else
		-- A re-grab after a catch: a short grace so the scramble isn't an instant re-catch.
		e.StunnedUntil = math.max(e.StunnedUntil, os.clock() + P.RegrabGrace)
	end
	e.Phase = "Chase"
	SessionStats.event(player, "PursuitGrab")
	broadcast(e)
end

spawnCache = function(e: Event, position: Vector3, lifetime: number)
	local item = LootService.spawnSpecial(P.CacheLootId, position, lifetime, function(player)
		if current ~= e or e.Phase == "Done" then
			return
		end
		if player then
			takeCore(e, player)
		elseif e.Phase == "Race" then
			finish(e, "Unclaimed")
		end
	end)
	item:SetAttribute("PursuitCache", true)
	e.Cache = item
end

-- The carrier lost the core (caught, died or left): it drops at `at` for anyone to grab.
local function dropLoose(e: Event, at: Vector3)
	e.Carrier = nil
	e.Phase = "Loose"
	local left = math.max(1, e.EndsAt - os.clock())
	spawnCache(e, at, left)
	broadcast(e)
end

local function strike(root: BasePart)
	local v = root.AssemblyLinearVelocity
	local aim = Pursuit.leadPoint(flat(root.Position), { X = v.X, Z = v.Z }, P.StrikeLead)
	local pos = Vector3.new(aim.X, root.Position.Y - 2.5, aim.Z)
	strikeRemote:FireAllClients(pos, P.StrikeRadius, P.StrikeWarn)
	task.delay(P.StrikeWarn, function()
		for _, player in Players:GetPlayers() do
			local r = rootOf(player)
			if
				r
				and not onPlateau(r.Position)
				and Pursuit.distance(flat(r.Position), aim) <= P.StrikeRadius
			then
				PlayerService.damage(player, P.StrikeDamage)
			end
		end
	end)
end

local function extracted(e: Event, player: Player)
	local seconds = os.clock() - (e.StartedAt :: number)
	local session = PlayerService.get(player)
	local best = false
	if session then
		if type(session.Data.Records) ~= "table" then
			session.Data.Records = { Extractions = 0, BestExtract = 0 }
		end
		best = Pursuit.record(session.Data.Records, seconds)
	end
	-- The single transition to Done happens first, so nothing can grant twice.
	finish(
		e,
		"Extracted",
		{ Seconds = math.floor(seconds * 10 + 0.5) / 10, Best = best, CarrierName = player.DisplayName }
	)
	PlayerService.addCoins(player, P.ExtractCoins)
	ContractService.awardXP(player, P.ExtractXP)
	SessionStats.event(player, "PursuitExtracted", seconds)
end

local function tick(e: Event, dt: number)
	local now = os.clock()
	if now >= e.EndsAt then
		if e.Phase == "Race" then
			finish(e, "Unclaimed")
		else
			if e.Carrier then
				PlayerService.removeCarried(e.Carrier, P.CacheLootId)
			end
			finish(e, "Expired")
		end
		return
	end
	if e.Phase ~= "Chase" and e.Phase ~= "Loose" then
		return
	end
	local twister = e.Twister
	if not twister then
		return
	end
	-- Chase the carrier. With the core loose the twister holds where it is: it never guards the
	-- core, so recovering it is always possible.
	local target: Vector3? = nil
	local root = rootOf(e.Carrier)
	if e.Phase == "Chase" then
		if not root then
			return -- death and leaving are handled by their own hooks
		end
		e.LastPos = root.Position
		if onPlateau(root.Position) then
			extracted(e, e.Carrier :: Player)
			return
		end
		target = root.Position
	end
	if target and now >= e.StunnedUntil then
		local chased = now - (e.StartedAt or now)
		local speed = Pursuit.speedAt(chased, P.SpeedStart, P.SpeedRamp, P.SpeedMax)
		local pos = Pursuit.step(flat(twister.Position), flat(target), speed, dt)
		-- It stops at the foot of the climb up to the Scrapyard: reaching the climb is the safe
		-- line. (Catches on the incline, where everyone slows down, read as unfair in testing.)
		local z = math.max(pos.Z, map.SafeZoneZ + P.SafeLine)
		twister.Position = Vector3.new(pos.X, 0, z)
	end
	if e.Phase == "Chase" and root then
		if
			now >= e.StunnedUntil
			and Pursuit.caught(flat(twister.Position), flat(root.Position), P.CatchRadius)
		then
			local carrier = e.Carrier :: Player
			if PlayerService.removeCarried(carrier, P.CacheLootId) then
				PlayerService.damage(carrier, P.CatchDamage)
				PlayerService.notify(
					carrier,
					"CAUGHT! The core dropped. Grab it back!",
					Color3.fromRGB(255, 90, 70)
				)
				SessionStats.event(carrier, "PursuitCaught")
				e.StunnedUntil = now + P.StunSeconds
				-- Flung sideways (not forward, not back into the twister): recovering costs time.
				local away = (root.Position - twister.Position) * Vector3.new(1, 0, 1)
				local side = if away.Magnitude > 0.1
					then Vector3.new(-away.Z, 0, away.X).Unit
					else Vector3.xAxis
				if e.Id % 2 == 0 then
					side = -side
				end
				-- Only onto open ground: a wall or building on that side flips it, and if both
				-- sides are blocked the core drops at the carrier's feet.
				local params = RaycastParams.new()
				local exclude: { Instance } = { twister }
				for _, pl in Players:GetPlayers() do
					if pl.Character then
						table.insert(exclude, pl.Character)
					end
				end
				local loot = LootService.folder()
				if loot then
					table.insert(exclude, loot)
				end
				params.FilterDescendantsInstances = exclude
				local function clear(dir: Vector3): boolean
					return workspace:Raycast(root.Position, dir * (P.DropFling + 2), params) == nil
				end
				if not clear(side) then
					side = if clear(-side) then -side else Vector3.zero
				end
				local drop = root.Position + side * P.DropFling
				dropLoose(e, drop)
			else
				-- Somehow not carrying it any more (sold? impossible off the plateau): end cleanly.
				finish(e, "Lost")
			end
			return
		end
		if now >= e.NextStrike and now >= e.StunnedUntil then
			e.NextStrike = now + P.StrikeEvery
			strike(root)
		end
	end
end

function PursuitService.start(): boolean
	if current or not P.Enabled then
		return false
	end
	nextId += 1
	local e: Event = {
		Id = nextId,
		Phase = "Race",
		EndsAt = math.min(os.clock() + P.ClaimSeconds, stormAt - 1),
		Carrier = nil,
		StunnedUntil = 0,
		NextStrike = 0,
		LastPos = P.Spot,
	}
	current = e
	spawnCache(e, P.Spot + Vector3.new(0, 5, 0), P.ClaimSeconds)
	broadcast(e)
	task.spawn(function()
		local last = os.clock()
		while current == e do
			local now = os.clock()
			-- Real elapsed time: server steps run a little over StepSeconds, and moving by the
			-- nominal step made the twister ~15% slower than its configured speed.
			local dt = math.min(now - last, 0.5)
			last = now
			local ok, err = pcall(tick, e, dt)
			if not ok then
				warn("[PursuitService] tick failed:", err)
			end
			task.wait(P.StepSeconds)
		end
	end)
	return true
end

function PursuitService.state(): any
	local e = current
	return e
			and {
				Phase = e.Phase,
				Carrier = e.Carrier and e.Carrier.Name,
				Twister = e.Twister and e.Twister.Position,
			}
		or nil
end

-- Must be initialised before LootService.init: its death hook runs first, so the pursuit core
-- comes out of the bag before the rest of the bag is dropped.
function PursuitService.init(mapInfo)
	map = mapInfo
	PlayerService.onDied(function(player, character)
		local e = current
		if e and e.Phase == "Chase" and e.Carrier == player then
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if PlayerService.removeCarried(player, P.CacheLootId) then
				dropLoose(e, if root then root.Position else e.LastPos)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local e = current
		if e and e.Phase == "Chase" and e.Carrier == player then
			dropLoose(e, e.LastPos)
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		local e = current
		if e then
			task.defer(function()
				if current == e then
					stateRemote:FireClient(player, {
						Id = e.Id,
						Phase = e.Phase,
						District = P.District,
						EndsAt = serverTime(e.EndsAt),
						CarrierId = e.Carrier and e.Carrier.UserId or nil,
						CarrierName = e.Carrier and e.Carrier.DisplayName or nil,
					})
				end
			end)
		end
	end)
	StormService.onPhase(function(phase, duration)
		if phase == "Calm" then
			stormAt = os.clock() + duration + Config.Cycle.Warning
		elseif phase == "Storm" then
			stormAt = math.huge
		end
		if phase == "Calm" and P.Enabled then
			task.wait(P.StartAfterCalm)
			PursuitService.start()
		end
	end)
end

return PursuitService
