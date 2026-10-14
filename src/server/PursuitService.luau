-- @file Cache events (server): Storm Pursuit and Dangerous Extraction
-- @domain world
-- @status wip
-- @see [[Pursuit.luau]]
-- @see [[EventService.luau]]
-- @see [[V4-GAMEPLAY]]
-- The two cache events EventService schedules after a storm passes. A rare cache (a real Storm
-- Core) drops at a site and everyone is told; whoever grabs it has to get it to the Scrapyard
-- plateau before time runs out.
--   Pursuit     a rogue twister forms and chases the carrier. It is route-bound: it paths along
--               the streets with a wide agent (PathfindingService), so gaps narrower than about
--               ten studs (alleys, fenced yards) are escapes, and a roof is out of its reach.
--               Its speed builds; every few seconds it winds up and throws a telegraphed debris
--               strike where the carrier is heading. Caught: the core is flung sideways for
--               anyone to grab and the twister stalls.
--   Extraction  no pursuer; the core is unstable and telegraphed surges erupt ahead on the
--               straight line home, so the obvious route is the dangerous one.
-- Extracting pays a bonus once per event and updates the carrier's records (time, streak,
-- hardest site); the core then sells at the Scrap Buyer for its normal value.
--
-- Authority: every rule runs here. The pickup is the normal server-checked prompt
-- (LootService.spawnSpecial); the bag changes only through PlayerService; the bonus is granted
-- only by the state machine's single transition to Done. Clients get PursuitState and draw.

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Pursuit = require(ReplicatedStorage.Shared.Pursuit)
local DodgeService = require(script.Parent.DodgeService)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ContractService = require(script.Parent.ContractService)
local LootService = require(script.Parent.LootService)
local PlayerService = require(script.Parent.PlayerService)
local SessionStats = require(script.Parent.SessionStats)

local PursuitService = {}

local P = Config.Pursuit
local X = Config.Extraction
local stateRemote = Remotes.get("PursuitState")
local strikeRemote = Remotes.get("PursuitStrike")

export type Site = { Id: string, Name: string, Spot: Vector3, Difficulty: number }

type Event = {
	Id: number,
	Kind: string, -- "Pursuit" | "Extraction"
	Prize: string, -- "StormCore", or "GoldenCore" (Config.Events.GoldenChance, decided at spawn)
	Site: Site,
	Phase: string, -- "Race" | "Chase" | "Loose" | "Done"
	EndsAt: number, -- os.clock() deadline for the current window
	Cache: Instance?, -- the item in the world (race, or loose after a catch)
	Carrier: Player?,
	StartedAt: number?, -- first grab (extraction time is measured from here)
	Caught: { [Player]: boolean }, -- who was caught this event (streaks)
	Twister: BasePart?,
	Waypoints: { Vector3 },
	WaypointIndex: number,
	PathOk: boolean, -- the last route search found a way to the carrier
	StunnedUntil: number,
	NextStrike: number,
	NextSurge: number,
	LastPos: Vector3,
}

local map: any
local current: Event? = nil
local nextId = 0
local stormAt = math.huge -- os.clock() when the next storm hits
local onFinished: ((string, string) -> ())? = nil

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

-- Open ground near y = 0 at (x, z) (not a dock, roof, crate or vehicle), or nil.
local function groundAt(x: number, z: number): Vector3?
	local params = RaycastParams.new()
	local exclude: { Instance } = {}
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
	params.IgnoreWater = true
	local hit = workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -160, 0), params)
	if hit and hit.Position.Y < 2 and hit.Normal.Y > 0.8 then
		return hit.Position
	end
	return nil
end

local function onPlateau(position: Vector3): boolean
	return position.Z < map.SafeZoneZ and position.Y > 20
end

local function flat(v: Vector3): Pursuit.Vec2
	return { X = v.X, Z = v.Z }
end

local function message(e: Event): { [string]: any }
	return {
		Id = e.Id,
		Kind = e.Kind,
		Phase = e.Phase,
		Site = e.Site.Name,
		District = e.Site.Name,
		Difficulty = e.Site.Difficulty,
		EndsAt = serverTime(e.EndsAt),
		CarrierId = e.Carrier and e.Carrier.UserId or nil,
		CarrierName = e.Carrier and e.Carrier.DisplayName or nil,
		Target = if e.Cache and (e.Cache :: any).Parent then (e.Cache :: BasePart).Position else nil,
		Prize = e.Prize,
		Golden = e.Prize == "GoldenCore",
	}
end

local function broadcast(e: Event, extra: { [string]: any }?)
	local msg = message(e)
	if extra then
		for k, v in extra do
			msg[k] = v
		end
	end
	stateRemote:FireAllClients(msg)
end

local function recordsOf(player: Player): Pursuit.Records?
	local session = PlayerService.get(player)
	if not session then
		return nil
	end
	session.Data.Records = Pursuit.reconcile(session.Data.Records)
	return session.Data.Records
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
	local payload: { [string]: any } = { Result = result }
	if extra then
		for k, v in extra do
			payload[k] = v
		end
	end
	broadcast(e, payload)
	current = nil
	if onFinished then
		onFinished(e.Kind, result)
	end
end

local function setTwisterState(e: Event, state: string)
	if e.Twister and e.Twister:GetAttribute("State") ~= state then
		e.Twister:SetAttribute("State", state)
	end
end

local spawnCache: (e: Event, position: Vector3, lifetime: number, recovered: boolean?) -> ()

local function takeCore(e: Event, player: Player)
	e.Cache = nil
	e.Carrier = player
	if not e.StartedAt then
		e.StartedAt = os.clock()
		local window = if e.Kind == "Extraction" then X.ExtractSeconds else P.ExtractSeconds
		e.EndsAt = math.min(os.clock() + window, stormAt - 1)
		e.NextSurge = os.clock() + 1.5
		if e.Kind == "Pursuit" then
			local root = rootOf(player)
			local from = if root then root.Position else e.Site.Spot
			-- Behind the carrier toward the cache, on open street: rotate round the carrier until
			-- the spot is open ground (a dock or a roof would leave it with no route).
			local base = Pursuit.spawnPoint(flat(from), flat(e.Site.Spot), P.SpawnBehind)
			local start = Vector3.new(base.X, from.Y - 3, base.Z)
			local dx, dz = base.X - from.X, base.Z - from.Z
			for step = 0, 11 do
				local a = math.pi / 6 * math.ceil(step / 2) * (if step % 2 == 1 then 1 else -1)
				local x = from.X + dx * math.cos(a) - dz * math.sin(a)
				local z = from.Z + dx * math.sin(a) + dz * math.cos(a)
				local g = groundAt(x, z)
				if g then
					start = g
					break
				end
			end
			local twister = Instance.new("Part")
			twister.Name = "PursuitTwister"
			twister.Anchored = true
			twister.CanCollide = false
			twister.CanQuery = false
			twister.CanTouch = false
			twister.Transparency = 1
			twister.Size = Vector3.new(1, 1, 1)
			twister.Position = start
			twister:SetAttribute("State", "Forming")
			twister:SetAttribute("FormSeconds", P.FormSeconds)
			twister.Parent = workspace
			e.Twister = twister
			e.StunnedUntil = os.clock() + P.FormSeconds
			e.NextStrike = os.clock() + P.FormSeconds + 2.5
		end
	else
		-- A re-grab after a catch: a short grace so the scramble isn't an instant re-catch.
		e.StunnedUntil = math.max(e.StunnedUntil, os.clock() + P.RegrabGrace)
	end
	e.Phase = "Chase"
	e.Waypoints = {}
	SessionStats.event(player, "EventGrab_" .. e.Kind)
	broadcast(e)
end

spawnCache = function(e: Event, position: Vector3, lifetime: number, recovered: boolean?)
	local item = LootService.spawnSpecial(e.Prize, position, lifetime, function(player)
		if current ~= e or e.Phase == "Done" then
			return
		end
		if player then
			takeCore(e, player)
		elseif e.Phase == "Race" then
			finish(e, "Unclaimed")
		end
	end, recovered)
	item:SetAttribute("PursuitCache", true)
	e.Cache = item
end

-- The carrier lost the core (caught, died or left): it drops at `at` for anyone to grab.
local function dropLoose(e: Event, at: Vector3)
	e.Carrier = nil
	e.Phase = "Loose"
	e.Waypoints = {}
	local left = math.max(1, e.EndsAt - os.clock())
	spawnCache(e, at, left, true) -- the same core: grabbing it back isn't a new find
	broadcast(e)
end

local qaHits: { string } = {} -- Studio QA: each strike's outcome as the server judged it

-- One player's hit check for a zone. Judged where the server trusts the player is
-- (DodgeService): a teleport or a spammed dodge doesn't escape a hit an honest player in the same
-- spot would take.
local function hitPlayer(player: Player, at: Pursuit.Vec2, radius: number, damage: number, y: number)
	local pos = DodgeService.judgedPosition(player)
	if pos and RunService:IsStudio() then
		table.insert(
			qaHits,
			("%s d=%.1f r=%.1f lag=%.2f"):format(
				player.Name,
				Pursuit.distance(flat(pos), at),
				radius,
				DodgeService.lagAllowance(player)
			)
		)
	end
	if
		pos
		and not onPlateau(pos)
		and math.abs(pos.Y - y) < 12
		and Pursuit.distance(flat(pos), at) <= radius
	then
		PlayerService.damage(player, damage)
	end
end

-- A telegraphed strike: everyone sees the warning now; each player is judged at the end of the
-- warning plus HitGrace plus their own network lag (capped, DodgeService.lagAllowance), because a
-- dodge made at the last visible moment reaches the server that much later.
local function strikeZone(
	style: string,
	at: Pursuit.Vec2,
	radius: number,
	warn: number,
	damage: number,
	y: number,
	live: () -> boolean
)
	strikeRemote:FireAllClients(style, Vector3.new(at.X, y, at.Z), radius, warn)
	for _, player in Players:GetPlayers() do
		local allowance = DodgeService.lagAllowance(player)
		-- Real-server evidence for the allowance: the report shows the largest one applied.
		SessionStats.peak(player, "StrikeLagAllowanceMs", math.floor(allowance * 1000))
		task.delay(warn + P.HitGrace + allowance, function()
			if live() and player.Parent then
				hitPlayer(player, at, radius - P.HitTolerance, damage, y)
			end
		end)
	end
end

local function debrisStrike(e: Event, root: BasePart)
	local v = root.AssemblyLinearVelocity
	local aim = Pursuit.leadPoint(flat(root.Position), { X = v.X, Z = v.Z }, P.StrikeLead)
	strikeZone("Debris", aim, P.StrikeRadius, P.StrikeWarn, P.StrikeDamage, root.Position.Y - 2.5, function()
		return current == e
	end)
end

local function surge(e: Event, root: BasePart)
	local goal = { X = 0, Z = map.SafeZoneZ }
	local lo, hi = X.SurgeAhead[1], X.SurgeAhead[2]
	local ahead = lo + math.random() * (hi - lo)
	local at = Pursuit.surgePoint(flat(root.Position), goal, ahead)
	-- A little sideways jitter so the line home is dangerous, not a single predictable spot.
	at = { X = at.X + (math.random() - 0.5) * 10, Z = at.Z + (math.random() - 0.5) * 10 }
	strikeZone("Surge", at, X.SurgeRadius, X.SurgeWarn, X.SurgeDamage, root.Position.Y - 2.5, function()
		return current == e
	end)
end

local function extracted(e: Event, player: Player)
	local seconds = os.clock() - (e.StartedAt :: number)
	local records = recordsOf(player)
	local result: Pursuit.RecordResult? = nil
	if records then
		result = Pursuit.record(records, seconds, e.Site.Difficulty, not e.Caught[player])
	end
	local coins = if e.Kind == "Extraction" then X.ExtractCoins else P.ExtractCoins
	local xp = if e.Kind == "Extraction" then X.ExtractXP else P.ExtractXP
	-- The single transition to Done happens first, so nothing can grant twice.
	finish(e, "Extracted", {
		Seconds = math.floor(seconds * 10 + 0.5) / 10,
		Best = result and result.Best or false,
		Streak = result and result.Streak or 0,
		NewHardest = result and result.NewHardest or false,
		Bonus = coins,
		CarrierName = player.DisplayName,
		CarrierId = player.UserId,
	})
	PlayerService.addCoins(player, coins)
	ContractService.awardXP(player, xp)
	SessionStats.event(player, "EventExtracted_" .. e.Kind, seconds)
end

-- Background path planner for the twister: keeps e.Waypoints toward the carrier (or the loose
-- core). With no path (the carrier is somewhere too narrow or high for it) the list empties and
-- the twister holds and searches.
local function planPaths(e: Event)
	local path = PathfindingService:CreatePath({
		AgentRadius = P.AgentRadius,
		AgentHeight = 8,
		AgentCanJump = false,
		AgentCanClimb = false,
	})
	while current == e and e.Phase ~= "Done" do
		local twister = e.Twister
		local target: Vector3? = nil
		if e.Phase == "Chase" then
			local root = rootOf(e.Carrier)
			target = root and root.Position
		end
		if twister and target and os.clock() >= e.StunnedUntil then
			local ok = pcall(function()
				path:ComputeAsync(twister.Position + Vector3.new(0, 3, 0), target :: Vector3)
			end)
			if current ~= e then
				break
			end
			if ok and path.Status == Enum.PathStatus.Success then
				local list = {}
				for i, wp in path:GetWaypoints() do
					if i > 1 then
						table.insert(list, wp.Position)
					end
				end
				e.Waypoints = list
				e.WaypointIndex = 1
				e.PathOk = true
			else
				e.Waypoints = {}
				e.PathOk = false
			end
		end
		task.wait(P.RepathSeconds)
	end
end

local function moveTwister(e: Event, twister: BasePart, speed: number, dt: number)
	local budget = speed * dt
	local pos = twister.Position
	while budget > 0 and e.WaypointIndex <= #e.Waypoints do
		local wp = e.Waypoints[e.WaypointIndex]
		local to = Vector3.new(wp.X, wp.Y, wp.Z)
		local d = (to - pos).Magnitude
		if d <= budget then
			pos = to
			budget -= d
			e.WaypointIndex += 1
		else
			pos += (to - pos).Unit * budget
			budget = 0
		end
	end
	-- It stops at the foot of the climb up to the Scrapyard: reaching the climb is the safe line.
	local z = math.max(pos.Z, map.SafeZoneZ + P.SafeLine)
	twister.Position = Vector3.new(pos.X, pos.Y, z)
end

local function tick(e: Event, dt: number)
	local now = os.clock()
	if now >= e.EndsAt then
		if e.Phase == "Race" then
			finish(e, "Unclaimed")
		else
			if e.Carrier then
				PlayerService.removeCarried(e.Carrier, e.Prize)
				local records = recordsOf(e.Carrier)
				if records then
					Pursuit.breakStreak(records)
				end
			end
			finish(e, "Expired")
		end
		return
	end
	if e.Phase ~= "Chase" and e.Phase ~= "Loose" then
		return
	end
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
	end
	if e.Kind == "Extraction" then
		if e.Phase == "Chase" and root and now >= e.NextSurge then
			e.NextSurge = now + X.SurgeEvery
			surge(e, root)
		end
		return
	end
	local twister = e.Twister
	if not twister then
		return
	end
	if now < e.StunnedUntil then
		setTwisterState(e, if e.StartedAt and now - e.StartedAt < P.FormSeconds then "Forming" else "Stunned")
		return
	end
	if e.Phase ~= "Chase" or not root then
		setTwisterState(e, "Searching") -- the core is loose: it holds and never guards it
		return
	end
	local speed = Pursuit.speedAt(now - (e.StartedAt :: number), P.SpeedStart, P.SpeedRamp, P.SpeedMax)
	if #e.Waypoints == 0 or e.WaypointIndex > #e.Waypoints then
		-- Out of route. If the last search found one, the carrier is just past its end: charge
		-- at them at full speed. With no route (somewhere too narrow or high for it) it pushes
		-- straight at them at reduced speed, so a gap buys real time but nowhere is safe for good.
		local factor = if e.PathOk then 1 else P.SearchSpeedFactor
		setTwisterState(e, if e.PathOk then "Chasing" else "Searching")
		local pos = Pursuit.step(flat(twister.Position), flat(root.Position), speed * factor, dt)
		local z = math.max(pos.Z, map.SafeZoneZ + P.SafeLine)
		local g = groundAt(pos.X, z)
		twister.Position = Vector3.new(pos.X, if g then g.Y else twister.Position.Y, z)
	else
		moveTwister(e, twister, speed, dt)
		setTwisterState(e, if now >= e.NextStrike - P.StrikeWindUp then "WindUp" else "Chasing")
	end
	local judged = DodgeService.judgedPosition(e.Carrier :: Player) or root.Position
	local dy = math.abs(judged.Y - (twister.Position.Y + 3))
	if
		dy <= P.CatchHeight
		and Pursuit.caught(flat(twister.Position), flat(judged), P.CatchRadius - P.HitTolerance)
	then
		local carrier = e.Carrier :: Player
		if PlayerService.removeCarried(carrier, e.Prize) then
			e.Caught[carrier] = true
			PlayerService.damage(carrier, P.CatchDamage)
			PlayerService.notify(
				carrier,
				"CAUGHT! The core dropped. Grab it back!",
				Color3.fromRGB(255, 90, 70)
			)
			SessionStats.event(carrier, "PursuitCaught")
			e.StunnedUntil = now + P.StunSeconds
			twister:SetAttribute("CaughtAt", workspace:GetServerTimeNow())
			-- Flung sideways (not forward, not back into the twister) onto open ground.
			local away = (root.Position - twister.Position) * Vector3.new(1, 0, 1)
			local side = if away.Magnitude > 0.1 then Vector3.new(-away.Z, 0, away.X).Unit else Vector3.xAxis
			if e.Id % 2 == 0 then
				side = -side
			end
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
			dropLoose(e, root.Position + side * P.DropFling)
		else
			finish(e, "Lost")
		end
		return
	end
	if now >= e.NextStrike then
		e.NextStrike = now + P.StrikeEvery
		debrisStrike(e, root)
	end
end

-- Starts a cache event of `kind` ("Pursuit" or "Extraction") at `site`, whose spot has already
-- been checked by EventService. Returns false if an event is already running.
function PursuitService.start(kind: string, site: Site, prize: string?): boolean
	if current then
		return false
	end
	nextId += 1
	local e: Event = {
		Id = nextId,
		Kind = kind,
		Prize = prize or Pursuit.pickPrize(Config.Events.GoldenChance, math.random),
		Site = site,
		Phase = "Race",
		EndsAt = math.min(os.clock() + P.ClaimSeconds, stormAt - 1),
		Carrier = nil,
		Caught = {},
		Waypoints = {},
		WaypointIndex = 1,
		PathOk = false,
		StunnedUntil = 0,
		NextStrike = 0,
		NextSurge = 0,
		LastPos = site.Spot,
	}
	current = e
	spawnCache(e, site.Spot + Vector3.new(0, 5, 0), math.max(1, e.EndsAt - os.clock()))
	broadcast(e)
	task.spawn(function()
		local last = os.clock()
		while current == e do
			local now = os.clock()
			-- Real elapsed time: server steps run a little over StepSeconds.
			local dt = math.min(now - last, 0.5)
			last = now
			local ok, err = pcall(tick, e, dt)
			if not ok then
				warn("[PursuitService] tick failed:", err)
			end
			task.wait(P.StepSeconds)
		end
	end)
	if kind == "Pursuit" then
		task.spawn(planPaths, e)
	end
	return true
end

-- Studio QA: strike outcomes since the last call.
-- Studio QA: a debris strike centred on `player` (no event needed), to test hits and dodges.
function PursuitService.qaStrike(player: Player)
	assert(RunService:IsStudio(), "Studio only")
	local root = rootOf(player)
	assert(root, "no character")
	strikeZone(
		"Debris",
		flat(root.Position),
		P.StrikeRadius,
		P.StrikeWarn,
		0,
		root.Position.Y - 2.5,
		function()
			return true
		end
	)
end

function PursuitService.takeQaHits(): { string }
	local out = qaHits
	qaHits = {}
	return out
end

function PursuitService.running(): boolean
	return current ~= nil
end

function PursuitService.state(): any
	local e = current
	return e
			and {
				Kind = e.Kind,
				Site = e.Site.Id,
				Phase = e.Phase,
				Carrier = e.Carrier and e.Carrier.Name,
				Twister = e.Twister and e.Twister.Position,
				TwisterState = e.Twister and e.Twister:GetAttribute("State"),
				Waypoints = #e.Waypoints,
			}
		or nil
end

-- EventService tells us when storms hit (events must end before) and wants to hear results.
function PursuitService.setStormAt(clock: number)
	stormAt = clock
end

function PursuitService.onFinished(callback: (string, string) -> ())
	onFinished = callback
end

-- Must be initialised before LootService.init: its death hook runs first, so the cache core comes
-- out of the bag before the rest of the bag is dropped.
function PursuitService.init(mapInfo)
	map = mapInfo
	PlayerService.onDied(function(player, character)
		local e = current
		if e and e.Phase == "Chase" and e.Carrier == player then
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if PlayerService.removeCarried(player, e.Prize) then
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
		task.defer(function()
			local e = current
			if e then
				stateRemote:FireClient(player, message(e))
			end
		end)
	end)
end

return PursuitService
