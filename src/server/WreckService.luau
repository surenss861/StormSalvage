-- @file The Armored Wreck: band 4's signature event
-- @domain world
-- @status wip
-- @see [[Bands.luau]]
-- @see [[WreckHud.luau]]
-- In the calm after a storm, an armored bank truck lies wrecked at an event site (never the one
-- the ordinary event is using). It has three locks:
--   * the rear doors at standing height,
--   * the side hatch facing the sky (climb the toppled crates),
--   * the roof hatch facing sideways.
-- Heavy Salvage licence holders cut them with the Thermal Cutter. Press the lock's prompt to
-- start cutting; you cut while within reach. Step out to dodge and the cut pauses, then resumes
-- when you're back (wander past the leash and you've stopped). Progress stays on the lock, and
-- several cutters on one lock add up.
-- While anyone cuts, the truck's security charges fire telegraphed shocks at a cutter (the same
-- strike judgement and dodge as the twister's). A hit hurts and stops your cutting until you
-- press the prompt again.
-- A crew splits up: every lock being cut at once speeds up all of them (Bands.crewBonus), and
-- the charges keep one pace for the whole wreck, so each cutter dodges fewer.
-- Fair shares: work is the cut progress each player actually added (by user id, so a rejoin
-- keeps it). A lock's Strongbox goes to whoever cut most of it; the vault's bars are split by
-- work among everyone with at least MinShare of it (Coop.shares), as owner-only salvage at
-- their feet; the Crown Jewels (announced odds) are drawn weighted by work. Standing nearby,
-- touching a lock for a second or arriving at the end earns nothing. Vault salvage is
-- Heavy-licence loot, sold at the Scrap Buyer like any salvage.
-- It runs when someone in the server holds the Heavy licence, and ends before the storm warning.
-- Server-authoritative: progress, hits and drops are all decided here; clients draw WreckState.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Bands = require(ReplicatedStorage.Shared.Bands)
local Config = require(ReplicatedStorage.Shared.Config)
local Coop = require(ReplicatedStorage.Shared.Coop)
local Pursuit = require(ReplicatedStorage.Shared.Pursuit)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ContractService = require(script.Parent.ContractService)
local EventService = require(script.Parent.EventService)
local LootService = require(script.Parent.LootService)
local PlayerService = require(script.Parent.PlayerService)
local PursuitService = require(script.Parent.PursuitService)
local SessionStats = require(script.Parent.SessionStats)
local StormService = require(script.Parent.StormService)

local WreckService = {}

local W = Bands.Wreck
local COLOR = Color3.fromRGB(255, 190, 80)
local remote: RemoteEvent

type Lock = {
	Part: BasePart,
	Progress: number,
	Cut: boolean,
	Cutters: { [Player]: true },
	Bar: Frame?,
	Work: { [string]: number }, -- cut progress each player added to this lock, by user id
}
type Wreck = {
	Id: number,
	Site: string,
	Model: Model,
	Locks: { Lock },
	EndsAt: number,
	Work: { [string]: number }, -- all cut progress each player added, by user id (survives a rejoin)
	Opened: boolean,
	Items: { Instance },
	ActiveLocks: number, -- locks being cut this tick (the crew bonus)
	Crew: number, -- players cutting this tick
}
local current: Wreck? = nil
local nextId = 0
local stormAt = math.huge

local function serverTime(clock: number): number
	return workspace:GetServerTimeNow() + (clock - os.clock())
end

local function broadcast()
	local w = current
	if not w then
		remote:FireAllClients({ Active = false })
		return
	end
	local locks = {}
	for _, lock in w.Locks do
		local n = 0
		for _ in lock.Cutters do
			n += 1
		end
		table.insert(
			locks,
			{ Position = lock.Part.Position, Progress = lock.Progress, Cut = lock.Cut, Cutters = n }
		)
	end
	remote:FireAllClients({
		Active = true,
		Id = w.Id,
		Site = w.Site,
		Position = w.Model:GetPivot().Position,
		Locks = locks,
		Opened = w.Opened,
		EndsAt = serverTime(w.EndsAt),
		Crew = w.Crew,
		Bonus = Bands.crewBonus(w.ActiveLocks),
	})
end

-- The progress bar on a lock (a server BillboardGui, so everyone sees the same number).
local function makeBar(lock: Lock)
	local gui = Instance.new("BillboardGui")
	gui.Name = "CutBar"
	gui.Size = UDim2.fromOffset(90, 12)
	gui.StudsOffset = Vector3.new(0, 1.8, 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 34)
	back.BorderSizePixel = 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = COLOR
	fill.BorderSizePixel = 0
	fill.Parent = back
	gui.Parent = lock.Part
	lock.Bar = fill
end

local function cutterSpeed(player: Player): number
	local v = PlayerService.gearValue(player, "Cutter")
	return if type(v) == "number" and v > 0 then v else 1
end

local function records(player: Player): any
	local session = PlayerService.get(player)
	if not session then
		return nil
	end
	session.Data.Records = Pursuit.reconcile(session.Data.Records)
	return session.Data.Records
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- A reward that only `owner` can pick up (their share: nobody can sweep the vault).
local function award(w: Wreck, owner: Player, lootId: string, at: Vector3)
	local item = LootService.spawnFor(owner, lootId, at, W.ItemSeconds, function(player)
		if player then
			SessionStats.event(player, "Vault_" .. lootId, 1)
		end
	end)
	table.insert(w.Items, item)
end

local function playerOf(id: string): Player?
	local userId = tonumber(id)
	return if userId then Players:GetPlayerByUserId(userId) else nil
end

-- The vault: every contributor (by measured cutting, at least MinShare of the work) gets their
-- share of the bars as owner-only salvage at their feet, and the Crown Jewels (at the announced
-- odds) go to one of them, drawn weighted by work. Players who left before it opened forfeit
-- (their share is not paid to anyone else either: the split is by work, not by who's left).
local function openVault(w: Wreck)
	w.Opened = true
	local eligible = Coop.eligible(w.Work, W.MinShare)
	local bars = Bands.barsFor(#eligible)
	local split = Coop.shares(w.Work, bars, W.MinShare)
	local total = 0
	for _, v in w.Work do
		total += v
	end
	local rear = w.Model:GetPivot() * CFrame.new(-11, 0, 0)
	for _, id in eligible do
		local player = playerOf(id)
		if player then
			local r = records(player)
			if r then
				r.VaultsOpened += 1
			end
			ContractService.awardXP(player, 60)
			local root = rootOf(player)
			local at = if root then root.Position else rear.Position
			for k = 1, split[id] or 0 do
				local a = k * 1.3
				award(w, player, "BullionBar", at + Vector3.new(math.cos(a) * 3, 0, math.sin(a) * 3))
			end
			PlayerService.notify(
				player,
				("Your share of the vault: %d bullion bar%s (%d%% of the cutting)."):format(
					split[id] or 0,
					if (split[id] or 0) == 1 then "" else "s",
					math.floor((w.Work[id] or 0) / math.max(total, 1e-9) * 100 + 0.5)
				),
				COLOR
			)
			PlayerService.pushState(player)
		end
	end
	local winner: Player? = nil
	if math.random() < W.JewelChance then
		local id = Coop.weightedPick(w.Work, math.random(), W.MinShare)
		winner = if id then playerOf(id) else nil
		if winner then
			local root = rootOf(winner)
			award(
				w,
				winner,
				"CrownJewels",
				if root then root.Position + Vector3.new(0, 0, 3) else rear.Position
			)
		end
	end
	PlayerService.notifyAll(
		if winner
			then ("THE VAULT IS OPEN! %s won the CROWN JEWELS draw. %d bars shared by the crew."):format(
				winner.DisplayName,
				bars
			)
			else ("THE VAULT IS OPEN: %d bullion bars shared by the crew."):format(bars),
		COLOR
	)
	for _, light in w.Model:GetChildren() do
		if light.Name:match("^Light%d") and light:IsA("BasePart") then
			light.Color = Color3.fromRGB(80, 255, 120)
		end
	end
	broadcast()
end

local function cutLock(w: Wreck, lock: Lock)
	lock.Cut = true
	lock.Progress = 1
	for player in lock.Cutters do
		player:SetAttribute("WreckCutting", nil)
	end
	lock.Cutters = {}
	-- Credit and the strongbox go by work on this lock: everyone with a real share of it gets
	-- the lock on their record; the strongbox goes to whoever cut most of it.
	local lockers = Coop.eligible(lock.Work, W.MinShare)
	for _, id in lockers do
		local player = playerOf(id)
		local r = player and records(player)
		if r then
			r.WreckLocks += 1
		end
	end
	local prompt = lock.Part:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt:Destroy()
	end
	local light = w.Model:FindFirstChild("Light" .. string.sub(lock.Part.Name, -1))
	if light and light:IsA("BasePart") then
		light.Color = Color3.fromRGB(80, 255, 120)
	end
	-- The strongbox is thrown clear, in front of the cab: away from every lock (a "Grab" prompt
	-- next to a lock would steal the cutting prompt's key).
	local cut = 0
	for _, l in w.Locks do
		if l.Cut then
			cut += 1
		end
	end
	local out = w.Model:GetPivot() * CFrame.new(12, 0, (cut - 2) * 3)
	local top = lockers[1] and playerOf(lockers[1])
	if top then
		award(w, top, "Strongbox", out.Position + Vector3.new(0, 4, 0))
	end
	local left = 0
	for _, l in w.Locks do
		if not l.Cut then
			left += 1
		end
	end
	if left == 0 then
		openVault(w)
	else
		broadcast()
	end
end

local function stopCutting(player: Player)
	local w = current
	if not w then
		return
	end
	for _, lock in w.Locks do
		lock.Cutters[player] = nil
	end
	player:SetAttribute("WreckCutting", nil)
end

local function startCutting(w: Wreck, lock: Lock, player: Player)
	if current ~= w or lock.Cut or w.Opened then
		return
	end
	if not PlayerService.licensed(player, W.License) then
		PlayerService.notify(
			player,
			("Cutting the wreck needs the %s (Gear Shop)."):format(Bands.Licenses[W.License].DisplayName),
			Color3.fromRGB(255, 200, 120)
		)
		return
	end
	local root = rootOf(player)
	if not root or (root.Position - lock.Part.Position).Magnitude > W.CutReach + 1 then
		return
	end
	stopCutting(player)
	lock.Cutters[player] = true
	player:SetAttribute("WreckCutting", lock.Part.Name)
end

local function makePrompt(w: Wreck, lock: Lock)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Cut lock"
	prompt.ObjectText = "Armored Wreck"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = W.CutReach
	prompt.RequiresLineOfSight = false
	prompt.Parent = lock.Part
	prompt.Triggered:Connect(function(player)
		if PlayerService.isNear(player, prompt) then
			startCutting(w, lock, player)
		end
	end)
end

-- One security charge, aimed at a random cutter's feet (dodge or step out of it).
local function charge(w: Wreck)
	local cutters = {}
	for _, lock in w.Locks do
		for player in lock.Cutters do
			table.insert(cutters, player)
		end
	end
	if #cutters == 0 then
		return
	end
	local target = cutters[math.random(1, #cutters)]
	local root = rootOf(target)
	if not root then
		return
	end
	local jitter = Vector3.new((math.random() - 0.5) * 3, 0, (math.random() - 0.5) * 3)
	PursuitService.strike(
		"Surge",
		root.Position - Vector3.new(0, 2.5, 0) + jitter,
		W.ChargeRadius,
		W.ChargeWarn,
		W.ChargeDamage,
		function()
			return current == w
		end,
		function(player)
			if player:GetAttribute("WreckCutting") then
				stopCutting(player)
				PlayerService.notify(
					player,
					"The security charge knocked you off the lock! Cut again.",
					COLOR
				)
			end
		end
	)
end

local function finish(w: Wreck)
	if current ~= w then
		return
	end
	for _, player in Players:GetPlayers() do
		player:SetAttribute("WreckCutting", nil)
	end
	current = nil
	broadcast()
	if not w.Opened then
		PlayerService.notifyAll(
			"The Armored Wreck's vault stayed shut. The salvage crew hauled it away.",
			COLOR
		)
	end
	w.Model:Destroy()
	print(("[WreckService] wreck %d over (opened %s)"):format(w.Id, tostring(w.Opened)))
end

local function anyHeavy(): boolean
	for _, player in Players:GetPlayers() do
		if PlayerService.bandOf(player) >= W.MinBand then
			return true
		end
	end
	return false
end

local function template(): Model?
	local assets = ServerStorage:FindFirstChild("Assets")
	local events = assets and assets:FindFirstChild("events")
	local m = events and events:FindFirstChild("ArmoredWreck")
	return if m and m:IsA("Model") then m else nil
end

-- Starts a wreck now at `siteId` (or a site the ordinary event isn't using). `force` skips the
-- band check (Studio QA). Returns why not, on failure.
function WreckService.start(siteId: string?, force: boolean?, seconds: number?): (boolean, string?)
	if current then
		return false, "a wreck is already out"
	end
	if not force and not anyHeavy() then
		return false, "nobody holds the Heavy licence"
	end
	local model = template()
	if not model then
		return false, "no ArmoredWreck asset"
	end
	local busy = EventService.lastSiteId()
	local order = {}
	for _, site in Config.Events.Sites do
		if (siteId and site.Id == siteId) or (not siteId and site.Id ~= busy) then
			table.insert(order, math.random(1, #order + 1), site)
		end
	end
	local resolved = nil
	for _, site in order do
		resolved = EventService.resolveSite(site)
		if resolved then
			break
		end
	end
	if not resolved then
		return false, "no open site"
	end
	if not force and stormAt - os.clock() < 20 then
		return false, "too close to the storm"
	end
	nextId += 1
	local clone = model:Clone()
	clone.Name = "ArmoredWreck"
	-- Face the rear doors (Lock1) toward the street the site's route home starts on: any yaw is
	-- fine visually; a random one keeps the climb to the side hatch from being the same each time.
	clone:PivotTo(CFrame.new(resolved.Spot) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
	clone.Parent = workspace
	LootService.keepClear(resolved.Spot, 18, (seconds or W.Seconds) + 2)
	local w: Wreck = {
		Id = nextId,
		Site = resolved.Name,
		Model = clone,
		Locks = {},
		-- Studio QA (`force`) ignores the storm clock; a scheduled wreck always ends before it.
		EndsAt = if force
			then os.clock() + (seconds or W.Seconds)
			else math.min(os.clock() + W.Seconds, stormAt - 2),
		Work = {},
		Opened = false,
		Items = {},
		ActiveLocks = 0,
		Crew = 0,
	}
	for i = 1, W.Locks do
		local part = clone:FindFirstChild("Lock" .. i)
		if part and part:IsA("BasePart") then
			local lock: Lock = { Part = part, Progress = 0, Cut = false, Cutters = {}, Work = {} }
			makeBar(lock)
			makePrompt(w, lock)
			table.insert(w.Locks, lock)
		end
	end
	current = w
	PlayerService.notifyAll(
		("AN ARMORED WRECK at %s! Heavy salvagers: cut its locks for the vault."):format(resolved.Name),
		COLOR
	)
	print(
		("[WreckService] wreck %d at %s (%d, %d)"):format(
			w.Id,
			resolved.Name,
			resolved.Spot.X,
			resolved.Spot.Z
		)
	)
	broadcast()
	task.spawn(function()
		local lastCharge = os.clock()
		local lastSend = 0
		while current == w and os.clock() < w.EndsAt do
			local dt = task.wait(0.2)
			local cutting = false
			local rates: { [Lock]: number } = {}
			local speeds: { [Player]: number } = {}
			local crew = 0
			for _, lock in w.Locks do
				if lock.Cut then
					continue
				end
				-- Within reach you cut; stepped out (dodging a charge) the cut pauses and resumes
				-- when you're back; past the leash you've left the job.
				local rate = 0
				for player in lock.Cutters do
					local root = rootOf(player)
					local d = if root then (root.Position - lock.Part.Position).Magnitude else math.huge
					if not player.Parent or d > W.Leash then
						lock.Cutters[player] = nil
						if player.Parent then
							player:SetAttribute("WreckCutting", nil)
						end
					else
						cutting = true -- someone is on the job: the charges keep coming
						if d <= W.CutReach + 1 then
							local speed = cutterSpeed(player)
							rate += speed
							crew += 1
							speeds[player] = speed
						end
					end
				end
				if rate > 0 then
					rates[lock] = rate
				end
			end
			-- The crew bonus: every lock being cut at once speeds up all of them.
			local active = 0
			for _ in rates do
				active += 1
			end
			w.ActiveLocks, w.Crew = active, crew
			local bonus = Bands.crewBonus(active)
			for lock, rate in rates do
				local add = math.min(1 - lock.Progress, dt * rate * bonus / W.CutSeconds)
				-- Work: each cutter's part of what this lock gained (by their cutter speed).
				for player in lock.Cutters do
					local speed = speeds[player]
					if speed then
						local id = tostring(player.UserId)
						local share = add * speed / rate
						lock.Work[id] = (lock.Work[id] or 0) + share
						w.Work[id] = (w.Work[id] or 0) + share
					end
				end
				lock.Progress = math.min(1, lock.Progress + add)
				lock.Part:SetAttribute("Sparking", true)
				if lock.Bar then
					lock.Bar.Size = UDim2.fromScale(lock.Progress, 1)
				end
				if lock.Progress >= 1 then
					cutLock(w, lock)
				end
			end
			for _, lock in w.Locks do
				if not rates[lock] and lock.Part.Parent then
					lock.Part:SetAttribute("Sparking", nil)
				end
			end
			if cutting and os.clock() - lastCharge >= W.ChargeEvery then
				lastCharge = os.clock()
				charge(w)
			elseif not cutting then
				lastCharge = math.max(lastCharge, os.clock() - W.ChargeEvery + 1) -- a beat's grace on starting
			end
			if cutting and os.clock() - lastSend > 0.5 then
				lastSend = os.clock()
				broadcast()
			end
		end
		finish(w)
	end)
	return true
end

-- Studio QA: set lock `index`'s progress (0..1) so the vault path can be checked without a full
-- solo cut. The next cutting tick finishes a lock set to 1 only while someone is cutting it.
function WreckService.qaProgress(index: number, progress: number): boolean
	local w = current
	local lock = w and w.Locks[index]
	if not lock or lock.Cut then
		return false
	end
	lock.Progress = math.clamp(progress, 0, 0.999)
	if lock.Bar then
		lock.Bar.Size = UDim2.fromScale(lock.Progress, 1)
	end
	return true
end

-- Studio QA: add `amount` of cutting work for `userId` (a stand-in for a crew member, who may
-- not be in the server: that tests the forfeit rule).
function WreckService.qaWork(userId: number, amount: number): boolean
	local w = current
	if not w then
		return false
	end
	local id = tostring(userId)
	w.Work[id] = (w.Work[id] or 0) + amount
	return true
end

function WreckService.state(): { [string]: any }?
	local w = current
	if not w then
		return nil
	end
	local locks = {}
	for _, lock in w.Locks do
		local cutters = {}
		for player in lock.Cutters do
			table.insert(cutters, player.Name)
		end
		table.insert(locks, {
			Name = lock.Part.Name,
			Progress = lock.Progress,
			Cut = lock.Cut,
			Cutters = cutters,
			Position = lock.Part.Position,
		})
	end
	return {
		Id = w.Id,
		Site = w.Site,
		Opened = w.Opened,
		Locks = locks,
		Left = w.EndsAt - os.clock(),
		Work = table.clone(w.Work),
	}
end

function WreckService.init()
	remote = Remotes.get("WreckState")
	Players.PlayerRemoving:Connect(stopCutting)
	StormService.onPhase(function(phase, duration)
		if phase == "Calm" then
			stormAt = os.clock() + duration + Config.Cycle.Warning
			task.delay(W.StartAfterCalm, function()
				local ok, why = WreckService.start()
				if not ok and why ~= "nobody holds the Heavy licence" then
					warn("[WreckService] no wreck this cycle:", why)
				end
			end)
		elseif phase == "Warning" then
			stormAt = os.clock()
		end
	end)
	-- Late joiners see a wreck already out.
	Players.PlayerAdded:Connect(function()
		if current then
			task.delay(2, broadcast)
		end
	end)
end

return WreckService
