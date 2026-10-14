-- @file The Storm Titan: band 5's signature event
-- @domain world
-- @status wip
-- @see [[Bands.luau]]
-- @see [[TitanHud.luau]]
-- During a storm, when someone in the server holds the Storm Legend licence, a colossal twister
-- forms and roams town along straight legs between open-ground points. Legend holders siphon it
-- with the Containment Rig by working the ring around it:
--   * between InnerRadius and OuterRadius you siphon (Rig level = speed), fast only in the
--     charge node, the spot where its energy pours onto the ring; the node sweeps round the
--     ring and sometimes reverses, so you run after it;
--   * every few seconds it inhales (telegraphed): the pull spikes and the core hurts double;
--   * inside InnerRadius it hurts and drains your siphon;
--   * the pull drags you inward (drawn and applied on your client, like the storm's wind; the
--     Rig resists it), and telegraphed debris strikes fall where siphoners are heading.
-- A full siphon forms a Mythic Core at your feet (going down loses your siphon). Its kind is drawn at the published odds
-- (Bands.Mythic) and announced with those odds; anyone licensed can grab it, so carry it home.
-- Server-authoritative: the Titan's position, each siphon and every draw are decided here.
-- Clients get TitanState (where it is) and their own siphon as the TitanSiphon attribute.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bands = require(ReplicatedStorage.Shared.Bands)
local Config = require(ReplicatedStorage.Shared.Config)
local Pursuit = require(ReplicatedStorage.Shared.Pursuit)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ContractService = require(script.Parent.ContractService)
local LootService = require(script.Parent.LootService)
local PlayerService = require(script.Parent.PlayerService)
local PursuitService = require(script.Parent.PursuitService)
local SessionStats = require(script.Parent.SessionStats)
local StormService = require(script.Parent.StormService)

local TitanService = {}

local T = Bands.Titan
local COLOR = Color3.fromRGB(255, 90, 200)
local remote: RemoteEvent

type Titan = {
	Center: Vector3,
	Siphon: { [Player]: number },
	Formed: number,
	Rng: Random,
	NodeAngle: number,
	NodeDir: number,
	FlipAt: number,
	InhaleAt: number, -- server time the next inhale starts (its warning runs before it)
}
local current: Titan? = nil
local rngSeed = os.time()

local function broadcast()
	local t = current
	if not t then
		remote:FireAllClients({ Active = false })
		return
	end
	remote:FireAllClients({
		Active = true,
		Center = t.Center,
		Inner = T.InnerRadius,
		Outer = T.OuterRadius,
		Pull = T.Pull,
		NodeAngle = t.NodeAngle,
		NodeDir = t.NodeDir,
		SentAt = workspace:GetServerTimeNow(),
		InhaleAt = t.InhaleAt,
	})
end

local function anyLegend(): boolean
	for _, player in Players:GetPlayers() do
		if PlayerService.bandOf(player) >= T.MinBand then
			return true
		end
	end
	return false
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function rigSpeed(player: Player): number
	local v = PlayerService.gearValue(player, "Rig")
	return if type(v) == "number" and v > 0 then v else 1
end

local function formCore(t: Titan, player: Player, at: Vector3)
	local m = Bands.drawMythic(t.Rng:NextNumber())
	t.Formed += 1
	local session = PlayerService.get(player)
	if session then
		session.Data.Records = Pursuit.reconcile(session.Data.Records)
		session.Data.Records.TitanCores += 1
	end
	ContractService.awardXP(player, 80)
	SessionStats.event(player, "TitanCore_" .. m.Id, 1)
	LootService.spawnSpecial(m.Id, at, T.CoreSeconds, function(taker)
		if taker then
			SessionStats.event(taker, "TitanCoreTaken", 1)
		end
	end)
	PlayerService.notifyAll(
		("%s siphoned a %s from the Storm Titan! (%d%% of Mythic Cores)"):format(
			player.DisplayName,
			string.upper(m.Name),
			math.floor(m.Odds * 100 + 0.5)
		),
		COLOR
	)
	PlayerService.pushState(player)
end

-- A debris strike where a siphoner is heading.
local function strike(t: Titan)
	local siphoners = {}
	for player in t.Siphon do
		if player.Parent then
			table.insert(siphoners, player)
		end
	end
	if #siphoners == 0 then
		return
	end
	local target = siphoners[t.Rng:NextInteger(1, #siphoners)]
	local root = rootOf(target)
	if not root then
		return
	end
	local v = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	local at = root.Position + v * T.StrikeWarn * 0.8 - Vector3.new(0, 2.5, 0)
	PursuitService.strike("Debris", at, T.StrikeRadius, T.StrikeWarn, T.StrikeDamage, function()
		return current == t
	end)
end

-- One Titan for a storm of `duration` seconds. `force` skips the band check (Studio QA).
function TitanService.run(duration: number, force: boolean?)
	if current or (not force and not anyLegend()) then
		return
	end
	local start = LootService.randomExposedPoint()
	if not start then
		return
	end
	rngSeed += 1
	local rng = Random.new(rngSeed)
	local t: Titan = {
		Center = start,
		Siphon = {},
		Formed = 0,
		Rng = rng,
		NodeAngle = rng:NextNumber() * math.pi * 2,
		NodeDir = if rng:NextNumber() < 0.5 then -1 else 1,
		FlipAt = os.clock() + rng:NextNumber(6, 11),
		InhaleAt = workspace:GetServerTimeNow() + T.InhaleEvery,
	}
	current = t
	broadcast()
	PlayerService.notifyAll("THE STORM TITAN has formed! Storm Legends: hold its ring to siphon it.", COLOR)
	print(("[TitanService] titan at (%d, %d) for %ds"):format(start.X, start.Z, duration))
	local legs = {}
	for _ = 1, T.Legs do
		local p = LootService.randomExposedPoint()
		if p then
			table.insert(legs, p)
		end
	end
	local leg = 1
	local endsAt = os.clock() + duration
	local lastSend, lastStrike = 0, os.clock()
	while current == t and os.clock() < endsAt and (force or StormService.getState().Phase == "Storm") do
		local dt = task.wait(0.1)
		local target = legs[leg]
		if target then
			local flat = (target - t.Center) * Vector3.new(1, 0, 1)
			local step = T.Speed * dt
			if flat.Magnitude <= step then
				t.Center = Vector3.new(target.X, t.Center.Y, target.Z)
				leg = if leg >= #legs then 1 else leg + 1
			else
				t.Center += flat.Unit * step
			end
		end
		-- The charge node sweeps round the ring, now and then reversing.
		t.NodeAngle += t.NodeDir * T.NodeSpeed * dt
		if os.clock() >= t.FlipAt then
			t.FlipAt = os.clock() + t.Rng:NextNumber(6, 11)
			if t.Rng:NextNumber() < 0.5 then
				t.NodeDir = -t.NodeDir
				broadcast()
			end
		end
		local node = t.Center + Vector3.new(math.cos(t.NodeAngle), 0, math.sin(t.NodeAngle)) * T.NodeRadius
		local now = workspace:GetServerTimeNow()
		local inhaling = now >= t.InhaleAt and now < t.InhaleAt + T.InhaleSeconds
		if now >= t.InhaleAt + T.InhaleSeconds then
			t.InhaleAt = now + T.InhaleEvery
			broadcast()
		end
		for _, player in Players:GetPlayers() do
			local root = rootOf(player)
			local licensed = PlayerService.licensed(player, T.License)
			local d = if root
				then ((root.Position - t.Center) * Vector3.new(1, 0, 1)).Magnitude
				else math.huge
			local inNode = root ~= nil
				and ((root.Position - node) * Vector3.new(1, 0, 1)).Magnitude <= T.NodeHit
			if licensed then
				player:SetAttribute("TitanInNode", inNode or nil)
			end
			if root and d < T.InnerRadius then
				PlayerService.damage(player, T.CoreDamagePerSecond * dt * (if inhaling then 2 else 1))
				if licensed and t.Siphon[player] then
					t.Siphon[player] = math.max(0, t.Siphon[player] - T.DrainPerSecond * dt)
				end
			elseif root and licensed and d <= T.OuterRadius then
				local rate = rigSpeed(player) / T.SiphonSeconds * (if inNode then 1 else T.RingRate)
				local s = (t.Siphon[player] or 0) + dt * rate
				if s >= 1 then
					s = 0
					formCore(t, player, root.Position)
				end
				t.Siphon[player] = s
			end
			if not root then
				t.Siphon[player] = nil -- down: the siphon is lost
			end
			if licensed then
				local s = t.Siphon[player]
				player:SetAttribute("TitanSiphon", if s then math.floor(s * 100) / 100 else nil)
			end
		end
		if os.clock() - lastStrike >= T.StrikeEvery then
			lastStrike = os.clock()
			strike(t)
		end
		if os.clock() - lastSend > 0.25 then
			lastSend = os.clock()
			broadcast()
		end
	end
	if current == t then
		current = nil
		for _, player in Players:GetPlayers() do
			player:SetAttribute("TitanSiphon", nil)
			player:SetAttribute("TitanInNode", nil)
		end
		broadcast()
		print(("[TitanService] titan over, %d Mythic Cores formed"):format(t.Formed))
	end
end

function TitanService.state(): { [string]: any }?
	local t = current
	if not t then
		return nil
	end
	local siphon = {}
	for player, s in t.Siphon do
		siphon[player.Name] = s
	end
	local node = t.Center + Vector3.new(math.cos(t.NodeAngle), 0, math.sin(t.NodeAngle)) * T.NodeRadius
	return { Center = t.Center, Siphon = siphon, Formed = t.Formed, Node = node, NodeDir = t.NodeDir }
end

-- Studio QA: set a player's siphon so the formation path can be checked quickly.
function TitanService.qaSiphon(player: Player, value: number): boolean
	local t = current
	if not t then
		return false
	end
	t.Siphon[player] = math.clamp(value, 0, 0.999)
	return true
end

function TitanService.init()
	remote = Remotes.get("TitanState")
	StormService.onPhase(function(phase, duration)
		if phase == "Storm" then
			task.delay(T.StartAfter, TitanService.run, duration - T.StartAfter - 1)
		end
	end)
	Players.PlayerAdded:Connect(function()
		if current then
			task.delay(2, broadcast)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		if current then
			current.Siphon[player] = nil
		end
	end)
	-- `Config` is read for the cycle so a Titan never outlives its storm.
	assert(Config.Cycle.Storm > T.StartAfter, "the Titan needs a storm long enough to form")
end

return TitanService
