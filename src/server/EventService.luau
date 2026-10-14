-- @file Event director: schedules the post-storm opportunity; runs Salvage Rush
-- @domain world
-- @status wip
-- @see [[PursuitService.luau]]
-- @see [[Pursuit.luau]]
-- @see [[V4-GAMEPLAY]]
-- After each storm passes, one opportunity: a Storm Pursuit, a Dangerous Extraction (both in
-- PursuitService) or a Salvage Rush (here). The kind and the site rotate (never the same kind or
-- the same site twice in a row, Pursuit.pickNext). Every event ends before the next storm hits.
--
-- Sites are checked when they're used: open sky over the spot, solid ground under it, and a
-- walkable route to the Scrapyard. A spot that fails (a prop dropped there, a roof) is nudged to
-- the nearest good spot within 30 studs; a site with none is skipped for this cycle.
--
-- Salvage Rush: valuable salvage (Rare and Epic) scattered around the site for 30 s. Normal
-- server-checked pickups and normal sale values, plus a little XP per find; the bag rules apply.

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Pursuit = require(ReplicatedStorage.Shared.Pursuit)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ContractService = require(script.Parent.ContractService)
local LootService = require(script.Parent.LootService)
local PlayerService = require(script.Parent.PlayerService)
local PursuitService = require(script.Parent.PursuitService)
local SessionStats = require(script.Parent.SessionStats)
local StormService = require(script.Parent.StormService)

local EventService = {}

local E = Config.Events
local R = Config.Rush
local stateRemote = Remotes.get("PursuitState")

local map: any
local lastKind: string? = nil
local lastSite: string? = nil
local stormAt = math.huge
local rushRunning = false
local rng = Random.new()
local nextRushId = 100000 -- distinct from PursuitService ids

local function siteById(id: string): any
	for _, site in E.Sites do
		if site.Id == id then
			return site
		end
	end
	return nil
end

-- Open sky and solid ground at (x, z): returns the ground point or nil.
local function openGround(x: number, z: number): Vector3?
	local params = RaycastParams.new()
	local exclude: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	local loot = LootService.folder()
	if loot then
		table.insert(exclude, loot)
	end
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true
	local hit = workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -160, 0), params)
	-- Town ground sits near y = 0; anything much higher is a roof, a crate or a vehicle.
	if hit and hit.Position.Y < 4 and hit.Normal.Y > 0.8 then
		return hit.Position
	end
	return nil
end

local function routeHome(from: Vector3): boolean
	local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
	local ok = pcall(function()
		path:ComputeAsync(from + Vector3.new(0, 3, 0), Vector3.new(0, 31, map.SafeZoneZ - 15))
	end)
	return ok and path.Status == Enum.PathStatus.Success
end

-- The site's spot if it's good, else the nearest good spot within 30 studs (rings of 6).
function EventService.resolveSite(site: any): any
	for radius = 0, 30, 6 do
		local steps = if radius == 0 then 1 else 12
		for i = 1, steps do
			local a = (i / steps) * math.pi * 2
			local x, z = site.Spot.X + math.cos(a) * radius, site.Spot.Z + math.sin(a) * radius
			local ground = openGround(x, z)
			if ground and routeHome(ground) then
				return { Id = site.Id, Name = site.Name, Spot = ground, Difficulty = site.Difficulty }
			end
		end
	end
	return nil
end

local function serverTime(clockDeadline: number): number
	return workspace:GetServerTimeNow() + (clockDeadline - os.clock())
end

local function startRush(site: any): boolean
	if rushRunning or PursuitService.running() then
		return false
	end
	rushRunning = true
	nextRushId += 1
	local id = nextRushId
	local endsAt = math.min(os.clock() + R.Seconds, stormAt - 1)
	local left = #R.Items
	local finds: { [Player]: number } = {}
	local items: { Instance } = {}
	local function msg(phase: string, extra: { [string]: any }?)
		local m: { [string]: any } = {
			Id = id,
			Kind = "Rush",
			Phase = phase,
			Site = site.Name,
			District = site.Name,
			EndsAt = serverTime(endsAt),
			Left = left,
			Target = site.Spot,
		}
		if extra then
			for k, v in extra do
				m[k] = v
			end
		end
		return m
	end
	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		for _, item in items do
			if item.Parent then
				item:Destroy()
			end
		end
		local top, topCount = nil, 0
		for player, n in finds do
			if n > topCount then
				top, topCount = player, n
			end
		end
		stateRemote:FireAllClients(msg("Done", {
			Result = if topCount > 0 then "RushOver" else "Unclaimed",
			TopName = top and top.DisplayName or nil,
			TopCount = topCount,
		}))
		rushRunning = false
		lastKind = "Rush"
	end
	for i, lootId in R.Items do
		local a = (i / #R.Items) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local r = rng:NextNumber(R.Spread * 0.4, R.Spread)
		local x, z = site.Spot.X + math.cos(a) * r, site.Spot.Z + math.sin(a) * r
		local ground = openGround(x, z) or site.Spot
		local item = LootService.spawnSpecial(
			lootId,
			ground + Vector3.new(0, 5, 0),
			endsAt - os.clock(),
			function(player)
				if done then
					return
				end
				if player then
					left -= 1
					finds[player] = (finds[player] or 0) + 1
					local session = PlayerService.get(player)
					if session then
						session.Data.Records = Pursuit.reconcile(session.Data.Records)
						session.Data.Records.RushFinds += 1
					end
					ContractService.awardXP(player, R.XPPerFind)
					SessionStats.event(player, "RushFind")
					stateRemote:FireAllClients(msg("Rush"))
					if left <= 0 then
						finish()
					end
				end
			end
		)
		item:SetAttribute("RushItem", true)
		table.insert(items, item)
	end
	stateRemote:FireAllClients(msg("Rush"))
	task.delay(math.max(1, endsAt - os.clock()), finish)
	return true
end

-- Starts `kind` at `siteId` now (also used by the Studio debug commands). Returns the reason on failure.
function EventService.start(kind: string, siteId: string): (boolean, string?)
	local site = siteById(siteId)
	if not site then
		return false, "unknown site " .. tostring(siteId)
	end
	if rushRunning or PursuitService.running() then
		return false, "an event is already running"
	end
	local resolved = EventService.resolveSite(site)
	if not resolved then
		return false, "no open spot with a route home near " .. site.Name
	end
	local ok
	if kind == "Rush" then
		ok = startRush(resolved)
	else
		ok = PursuitService.start(kind, resolved)
	end
	if ok then
		lastKind, lastSite = kind, site.Id
		print(("[EventService] %s at %s (%d, %d)"):format(kind, site.Name, resolved.Spot.X, resolved.Spot.Z))
	end
	return ok, if ok then nil else "could not start"
end

-- The next scheduled event: rotate kind and site; if a site fails its check, try the others.
function EventService.startNext(): (boolean, string?)
	local ids = {}
	for _, site in E.Sites do
		table.insert(ids, site.Id)
	end
	local random = function(n: number): number
		return rng:NextInteger(1, n)
	end
	local kind, siteId = Pursuit.pickNext(lastKind, lastSite, E.Kinds, ids, random)
	local ok, why = EventService.start(kind, siteId)
	if not ok and why and string.find(why, "no open spot") then
		for _, id in ids do
			if id ~= siteId and id ~= lastSite then
				ok, why = EventService.start(kind, id)
				if ok then
					break
				end
			end
		end
	end
	return ok, why
end

function EventService.init(mapInfo)
	map = mapInfo
	PursuitService.onFinished(function(kind)
		lastKind = kind
	end)
	StormService.onPhase(function(phase, duration)
		if phase == "Calm" then
			stormAt = os.clock() + duration + Config.Cycle.Warning
			PursuitService.setStormAt(stormAt)
		elseif phase == "Storm" then
			stormAt = math.huge
			PursuitService.setStormAt(stormAt)
		end
		if phase == "Calm" and E.Enabled then
			task.wait(E.StartAfterCalm)
			local ok, why = EventService.startNext()
			if not ok then
				warn("[EventService] no event this cycle:", why)
			end
		end
	end)
end

return EventService
