-- @file V4 dodge authority and movement plausibility
-- @domain world
-- @status wip
-- @see [[Dodge.luau]]
-- @see [[MoveRules.luau]]
-- @see [[PursuitService.luau]]
-- The server's side of the dodge. The client moves its own character (Roblox physics is
-- client-owned), so the server can't stop the burst itself; it decides what the burst counts for:
--   * A dodge request (Dodge remote) is honoured only when alive, on the ground and off cooldown
--     (server clock). Honoured dodges are shown to everyone else (DodgeFx); refused ones are
--     counted as anomalies (SessionStats) and shown to no one.
--   * Every character's position is sampled; a move further than running plus one honoured dodge
--     could cover (a teleport, a speed cheat, a spammed dodge) isn't trusted, and hits are judged
--     at the last plausible position instead (DodgeService.judgedPosition). So no client-side
--     position change can dodge damage that an honest player in the same spot would take.
-- Collision, gaps and walls stay physical: the burst is a velocity, never a teleport.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local MoveRules = require(ReplicatedStorage.Shared.MoveRules)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SessionStats = require(script.Parent.SessionStats)

local DodgeService = {}

local D = Config.Dodge
local SAMPLE_EVERY = 0.1
local WINDOW = 0.5 -- compare each sample with the one about this long before
local KEEP = 1.0
local SUSPECT_SECONDS = 1.0
local REQUESTS_PER_SECOND = 6 -- a request budget; anything more is spam and dropped unread

type Sample = { T: number, P: Vector3 }
type Track = {
	Samples: { Sample },
	LastGood: Vector3?,
	SuspectUntil: number,
	LastDodge: number?,
	Window: number,
	Requests: number,
	Refused: number,
	Flags: number,
}
local tracks: { [Player]: Track } = {}
local fxRemote: RemoteEvent

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function track(player: Player): Track
	local t = tracks[player]
	if not t then
		t = { Samples = {}, SuspectUntil = 0, Window = 0, Requests = 0, Refused = 0, Flags = 0 }
		tracks[player] = t
	end
	return t
end

local function grounded(root: BasePart): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { root.Parent :: Instance }
	-- Hip height (about 2) plus half the root (1) plus a little for slopes and steps.
	return workspace:Raycast(root.Position, Vector3.new(0, -4.5, 0), params) ~= nil
end

local function maxSpeed(player: Player): number
	local character = player.Character
	local sprint = character and character:GetAttribute("SprintSpeed")
	-- Generous: a sprinter pushed downwind by a gust, or sliding off a roof, is honest.
	return (if type(sprint) == "number" then sprint else 34) * 1.75
end

local function refuse(player: Player, t: Track, why: string)
	t.Refused += 1
	SessionStats.count(player, "DodgeRefused" .. why)
end

local function onDodge(player: Player, dirX: unknown, dirZ: unknown)
	local t = track(player)
	local now = os.clock()
	if now - t.Window >= 1 then
		t.Window, t.Requests = now, 0
	end
	t.Requests += 1
	if t.Requests > REQUESTS_PER_SECOND then
		return
	end
	if type(dirX) ~= "number" or type(dirZ) ~= "number" or dirX ~= dirX or dirZ ~= dirZ then
		refuse(player, t, "Bad")
		return
	end
	local dir = Vector3.new(math.clamp(dirX, -1, 1), 0, math.clamp(dirZ, -1, 1))
	local root = rootOf(player)
	if not root or dir.Magnitude < 0.1 then
		refuse(player, t, "Bad")
		return
	end
	if not MoveRules.dodgeAllowed(now, t.LastDodge, D.Cooldown, D.Tolerance) then
		refuse(player, t, "Cooldown")
		return
	end
	if not grounded(root) then
		refuse(player, t, "Air")
		return
	end
	t.LastDodge = now
	for _, other in Players:GetPlayers() do
		if other ~= player then
			fxRemote:FireClient(other, player, root.Position, dir.Unit)
		end
	end
end

local function sample(now: number)
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		local t = track(player)
		if not root then
			t.Samples = {}
			t.LastGood = nil
			continue
		end
		local p = root.Position
		local flat = Vector3.new(p.X, 0, p.Z)
		-- The oldest sample at least WINDOW old (or the oldest kept).
		local ref: Sample? = nil
		for _, s in t.Samples do
			if now - s.T >= WINDOW then
				ref = s
			end
		end
		ref = ref or t.Samples[1]
		local ok = true
		if ref then
			local dodged = t.LastDodge ~= nil and now - t.LastDodge <= WINDOW + D.Seconds
			ok = MoveRules.plausible(
				(flat - Vector3.new(ref.P.X, 0, ref.P.Z)).Magnitude,
				now - ref.T,
				maxSpeed(player),
				if dodged then D.Speed * D.Seconds else 0,
				D.Slack
			)
		end
		if ok and now >= t.SuspectUntil then
			t.LastGood = p
		elseif not ok then
			if now >= t.SuspectUntil then
				t.Flags += 1
				SessionStats.count(player, "MoveImplausible")
				-- Roblox replicates even a teleport as a fast slide over a few frames, so the
				-- samples just before this one may already be part of it. Fall back to the start
				-- of the window, from before the implausible move began.
				if ref then
					t.LastGood = ref.P
				end
			end
			t.SuspectUntil = now + SUSPECT_SECONDS
		end
		table.insert(t.Samples, { T = now, P = p })
		while #t.Samples > 0 and now - t.Samples[1].T > KEEP do
			table.remove(t.Samples, 1)
		end
	end
end

-- Where hits on this player are judged: the live position, unless the player's recent movement
-- was implausible, then the last position that wasn't. nil when not alive.
function DodgeService.judgedPosition(player: Player): Vector3?
	local root = rootOf(player)
	if not root then
		return nil
	end
	local t = tracks[player]
	if t and os.clock() < t.SuspectUntil and t.LastGood then
		return t.LastGood
	end
	return root.Position
end

-- Extra seconds to wait before judging a telegraphed hit on this player: their network lag, so a
-- dodge made at the last moment they could see still counts. Capped, so lag can't buy much.
local MAX_LAG_ALLOWANCE = 0.25
function DodgeService.lagAllowance(player: Player): number
	-- Studio QA: Studio's replication-lag setting doesn't show in GetNetworkPing, so a test can
	-- stand in a ping with the QA_Ping attribute. Ignored outside Studio.
	local qa = if RunService:IsStudio() then player:GetAttribute("QA_Ping") else nil
	if type(qa) == "number" then
		return math.clamp(qa, 0, MAX_LAG_ALLOWANCE)
	end
	local ok, ping = pcall(function()
		return player:GetNetworkPing()
	end)
	if not ok or type(ping) ~= "number" or ping ~= ping then
		return 0
	end
	return math.clamp(ping, 0, MAX_LAG_ALLOWANCE)
end

-- Studio QA: the counters for a player.
function DodgeService.stats(player: Player): { [string]: any }
	local t = tracks[player]
	if not t then
		return {}
	end
	return {
		Refused = t.Refused,
		Flags = t.Flags,
		Suspect = os.clock() < t.SuspectUntil,
		LastDodge = t.LastDodge,
	}
end

function DodgeService.init()
	fxRemote = Remotes.get("DodgeFx")
	Remotes.get("Dodge").OnServerEvent:Connect(onDodge)
	Players.PlayerRemoving:Connect(function(player)
		tracks[player] = nil
	end)
	-- A respawn moves the character legitimately: start its history fresh.
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			local t = track(player)
			t.Samples = {}
			t.LastGood = nil
			t.SuspectUntil = 0
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= SAMPLE_EVERY then
			acc = 0
			sample(os.clock())
		end
	end)
end

return DodgeService
