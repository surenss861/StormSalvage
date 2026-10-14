-- @file Player session: saved data, carried salvage, selling, upgrades
-- @domain salvage-economy
-- @status stable
-- @see [[DataService.luau]]
-- Owns each player's session: saved data, the salvage they are carrying,
-- character stats from upgrades, selling, and buying upgrades.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bands = require(ReplicatedStorage.Shared.Bands)
local Economy = require(ReplicatedStorage.Shared.Economy)
local BigMoney = require(ReplicatedStorage.Shared.BigMoney)
local Wallet = require(ReplicatedStorage.Shared.Wallet)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local SessionStats = require(script.Parent.SessionStats)
local StormStats = require(script.Parent.StormStats)

local PlayerService = {}

export type Session = {
	Data: DataService.Data,
	CanSave: boolean,
	Carried: { string }, -- loot ids
	OwnsHeavyDuty: boolean, -- Heavy-Duty Pack pass, verified with Roblox (never saved, never stacks)
	LastDamage: number,
	Sales: number, -- sales this session; numbers each receipt so clients never show one twice
}

local sessions: { [Player]: Session } = {}
local loadedCallbacks: { (Player, Session) -> () } = {}
local diedCallbacks: { (Player, Model) -> () } = {}
-- Called synchronously after each sale with (player, items sold, coins paid, Storm Cores sold).
-- Callbacks must not yield, so a sale and its contract progress land in the same frame.
local soldCallbacks: { (Player, number, number, number) -> () } = {}
-- Run just before each player state push (StatusService grants newly earned titles here, so
-- every change that reaches the client has been checked).
local beforePushCallbacks: { (Player, any) -> () } = {}

function PlayerService.onSold(callback: (Player, number, number, number) -> ())
	table.insert(soldCallbacks, callback)
end

local playerStateRemote = Remotes.get("PlayerState")
local notifyRemote = Remotes.get("Notify")
local buyUpgradeRemote = Remotes.get("BuyUpgrade")
local saleReceiptRemote = Remotes.get("SaleReceipt")

function PlayerService.get(player: Player): Session?
	return sessions[player]
end

function PlayerService.onLoaded(callback: (Player, Session) -> ())
	table.insert(loadedCallbacks, callback)
	for player, session in sessions do
		task.spawn(callback, player, session)
	end
end

function PlayerService.onDied(callback: (Player, Model) -> ())
	table.insert(diedCallbacks, callback)
end

function PlayerService.notify(player: Player, text: string, color: Color3?)
	notifyRemote:FireClient(player, text, color or Color3.new(1, 1, 1))
end

function PlayerService.notifyAll(text: string, color: Color3?)
	notifyRemote:FireAllClients(text, color or Color3.new(1, 1, 1))
end

local function upgradeValue(session: Session, id: string): any
	local def = Config.Upgrades[id]
	return def.Values[(session.Data.Upgrades[id] or 0) + 1]
end

function PlayerService.getCapacity(session: Session): number
	return upgradeValue(session, "Backpack")
		+ (if session.OwnsHeavyDuty then Config.GamePasses.HeavyDuty.BonusCapacity else 0)
end

function PlayerService.boostRemaining(session: Session): number
	return math.max(0, session.Data.BoostUntil - os.time())
end

-- Every active sell bonus, for the sale receipt. Multipliers stack by multiplying.
-- V4 M3: licences held, and the band they put the player in.
function PlayerService.hasLicense(session: Session, id: string): boolean
	local held = session.Data.Licenses
	return type(held) == "table" and held[id] == true
end

function PlayerService.licensed(player: Player, id: string): boolean
	local session = sessions[player]
	return session ~= nil and PlayerService.hasLicense(session, id)
end

function PlayerService.bandOf(player: Player): number
	local session = sessions[player]
	return if session then Bands.bandOf(session.Data.Licenses) else 1
end

function PlayerService.sellMultipliers(session: Session): { { Name: string, Factor: number } }
	local list = {}
	local press = session.Data.Upgrades.Press or 0
	if press > 0 and PlayerService.hasLicense(session, "Pro") then
		local factor = Config.Upgrades.Press.Values[press + 1]
		if factor and factor > 1 then
			table.insert(list, { Name = "Salvage Press", Factor = factor })
		end
	end
	if PlayerService.boostRemaining(session) > 0 then
		table.insert(list, { Name = "2x Salvage", Factor = 2 })
	end
	return list
end

local function factorsOf(session: Session): { number }
	local out = {}
	for _, bonus in PlayerService.sellMultipliers(session) do
		table.insert(out, bonus.Factor)
	end
	return out
end

-- Anyone carrying a Storm Core glows, so everyone can see who's holding the big prize. A Golden
-- Storm Core glows gold, brighter and further, so the jackpot carrier stands out in a crowd.
local function refreshCoreGlow(player: Player, session: Session)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local kind: string? = nil
	for _, id in session.Carried do
		if id == "GoldenCore" then
			kind = id
			break
		elseif Config.CoreIds[id] then
			kind = id
		end
	end
	local glow = root:FindFirstChild("CoreGlow")
	if glow and glow:GetAttribute("Kind") ~= kind then
		glow:Destroy()
		glow = nil
	end
	if kind and not glow then
		local golden = kind == "GoldenCore"
		local color = if golden then Config.Loot.GoldenCore.Color else Config.RarityColors.Legendary
		local light = Instance.new("PointLight")
		light.Name = "CoreGlow"
		light:SetAttribute("Kind", kind)
		light.Color = color
		light.Range = if golden then 18 else 12
		light.Brightness = if golden then 3.5 else 2.5
		light.Parent = root
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = color
		sparkles.Parent = light -- removed together with the light
	end
end

-- The exact base value of the bag (BigMoney string).
local function carriedValue(session: Session): string
	local total = "0"
	for _, id in session.Carried do
		total = BigMoney.add(total, BigMoney.of(Config.Loot[id].Value))
	end
	return total
end

function PlayerService.beforePush(callback: (Player, any) -> ())
	table.insert(beforePushCallbacks, callback)
end

function PlayerService.pushState(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	for _, cb in beforePushCallbacks do
		cb(player, session)
	end
	local band = Bands.bandOf(session.Data.Licenses)
	if player:GetAttribute("Band") ~= band then
		player:SetAttribute("Band", band)
	end
	playerStateRemote:FireClient(player, {
		-- Money as exact BigMoney strings: the client formats and compares them with BigMoney.
		Coins = Wallet.cash(session.Data),
		Lifetime = Wallet.lifetime(session.Data),
		Carried = session.Carried,
		CarriedValue = BigMoney.mulFactors(carriedValue(session), factorsOf(session)),
		Capacity = PlayerService.getCapacity(session),
		Upgrades = session.Data.Upgrades,
		BoostRemaining = PlayerService.boostRemaining(session),
		OwnsHeavyDuty = session.OwnsHeavyDuty,
		Stats = session.Data.Stats,
		CanSave = session.CanSave,
		Rep = session.Data.Rep,
		Contracts = session.Data.Contracts,
		Cosmetics = session.Data.Cosmetics,
		Tools = session.Data.Tools,
		Records = session.Data.Records,
		Collection = session.Data.Collection,
		Licenses = session.Data.Licenses,
		Band = band,
		Titles = session.Data.Titles,
	})
	-- The player list shows the compact balance as text: an IntValue can't hold big numbers.
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if coins then
		(coins :: StringValue).Value = BigMoney.tag(Wallet.cash(session.Data))
	end
end

function PlayerService.applyCharacterStats(player: Player)
	local session = sessions[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if session and humanoid then
		-- V4: run speed by default; the client sprints up to SprintSpeed (Movement.client).
		local level = (session.Data.Upgrades.Boots or 0) + 1
		local boots = Config.Upgrades.Boots
		humanoid.WalkSpeed = boots.Values[level]
		character:SetAttribute("RunSpeed", boots.Values[level])
		character:SetAttribute("SprintSpeed", boots.SprintValues[level])
	end
end

-- Server-side check that a living player is actually standing near a prompt. Prompts
-- are fired by the client, so this guards against triggering them from across the map.
function PlayerService.isNear(player: Player, prompt: ProximityPrompt): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local target = prompt.Parent
	if not humanoid or humanoid.Health <= 0 or not root or not (target and target:IsA("BasePart")) then
		return false
	end
	return (root.Position - target.Position).Magnitude <= prompt.MaxActivationDistance + 8
end

-- All storm damage goes through here so armor applies consistently.
function PlayerService.damage(player: Player, amount: number)
	local session = sessions[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or character:FindFirstChildOfClass("ForceField") then
		return
	end
	local reduction = session and upgradeValue(session, "Armor") or 0
	humanoid:TakeDamage(amount * (1 - reduction))
	if session then
		session.LastDamage = os.clock()
	end
end

-- Earned coins (a number or a BigMoney string), exact, into cash and lifetime earnings through
-- Wallet. Returns what was actually added (less than `amount` only at BigMoney.MAX, 10^303 - 1).
function PlayerService.addCoins(player: Player, amount: number | string): string
	local session = sessions[player]
	if not session then
		return "0"
	end
	local added = Wallet.earn(session.Data, amount)
	PlayerService.pushState(player)
	return added
end

-- The exact cash balance (BigMoney string).
function PlayerService.cash(player: Player): string
	local session = sessions[player]
	return if session then Wallet.cash(session.Data) else "0"
end

-- Returns true if the item fit in the bag.
function PlayerService.tryCarry(player: Player, lootId: string): boolean
	local session = sessions[player]
	if not session then
		return false
	end
	if #session.Carried >= PlayerService.getCapacity(session) then
		PlayerService.notify(player, "Bag full! Sell at the Scrapyard.", Color3.fromRGB(255, 120, 90))
		return false
	end
	table.insert(session.Carried, lootId)
	refreshCoreGlow(player, session)
	PlayerService.pushState(player)
	return true
end

-- Removes one `lootId` from the bag (Storm Pursuit: a caught or expired cache core).
function PlayerService.removeCarried(player: Player, lootId: string): boolean
	local session = sessions[player]
	if not session then
		return false
	end
	local index = table.find(session.Carried, lootId)
	if not index then
		return false
	end
	table.remove(session.Carried, index)
	refreshCoreGlow(player, session)
	PlayerService.pushState(player)
	return true
end

-- Empties the bag (used on death so the loot can be dropped in the world).
function PlayerService.takeCarried(player: Player): { string }
	local session = sessions[player]
	if not session then
		return {}
	end
	local carried = session.Carried
	session.Carried = {}
	refreshCoreGlow(player, session)
	PlayerService.pushState(player)
	return carried
end

function PlayerService.sell(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	if #session.Carried == 0 then
		PlayerService.notify(player, "Your bag is empty. Go salvage in town!", Color3.fromRGB(255, 220, 120))
		return
	end
	-- The receipt is built from the same numbers that pay out, so what the player sees is
	-- exactly what they got. Lines are grouped by item, most valuable first.
	local counts: { [string]: number } = {}
	for _, id in session.Carried do
		counts[id] = (counts[id] or 0) + 1
	end
	local lines = {}
	for id, count in counts do
		local value = BigMoney.of(Config.Loot[id].Value)
		table.insert(
			lines,
			{ Id = id, Count = count, Value = value, Total = BigMoney.mulSmall(value, count) }
		)
	end
	table.sort(lines, function(a, b)
		return BigMoney.cmp(a.Total, b.Total) > 0
	end)
	local multipliers = PlayerService.sellMultipliers(session) -- read before clearing the bag
	local values, factors = {}, {}
	for _, id in session.Carried do
		table.insert(values, Config.Loot[id].Value)
	end
	for _, bonus in multipliers do
		table.insert(factors, bonus.Factor)
	end
	local base, earned = Economy.sellTotal(values, factors)
	local cores = (counts.StormCore or 0) + (counts.GoldenCore or 0)
	local hadCore = cores > 0
	local itemsSold = #session.Carried
	session.Data.Stats.ItemsSold += #session.Carried
	session.Carried = {}
	session.Sales += 1
	refreshCoreGlow(player, session)
	-- The receipt shows what was really paid: only at the coin cap (10^303 - 1) is that less.
	local paid = PlayerService.addCoins(player, earned)
	local capLoss = BigMoney.sub(earned, paid) :: string
	earned = paid
	-- Contracts and stats count progress, not money: an approximate number is fine there.
	local approx = BigMoney.approx(earned)
	for _, cb in soldCallbacks do
		cb(player, itemsSold, approx, cores)
	end
	StormStats.sold(player, approx)
	SessionStats.sold(player, approx)
	saleReceiptRemote:FireClient(player, {
		Sale = session.Sales,
		Lines = lines,
		Base = base,
		Multipliers = multipliers,
		Total = earned,
		CapLoss = if capLoss ~= "0" then capLoss else nil,
		Balance = Wallet.cash(session.Data),
		HadCore = hadCore,
	})
	if hadCore then
		local coreValue = BigMoney.add(
			BigMoney.mulSmall(BigMoney.of(Config.Loot.StormCore.Value), counts.StormCore or 0),
			BigMoney.mulSmall(BigMoney.of(Config.Loot.GoldenCore.Value), counts.GoldenCore or 0)
		)
		local coreCoins = BigMoney.mulFactors(coreValue, factors)
		local what = if (counts.GoldenCore or 0) > 0
			then (if counts.GoldenCore > 1
				then counts.GoldenCore .. " GOLDEN Storm Cores"
				else "a GOLDEN Storm Core")
			elseif cores > 1 then cores .. " Storm Cores"
			else "a Storm Core"
		PlayerService.notifyAll(
			("%s delivered %s! +%s"):format(player.DisplayName, what, BigMoney.full(coreCoins)),
			Config.RarityColors.Legendary
		)
	end
end

-- Per-player request budget for BuyUpgrade: generous for real tapping, drops spam.
local BUY_LIMIT, BUY_WINDOW = 8, 1
local buyWindows: { [Player]: { Start: number, Count: number } } = {}

local function buyUpgrade(player: Player, upgradeId: unknown)
	local session = sessions[player]
	if not session or type(upgradeId) ~= "string" or #upgradeId > 32 then
		return
	end
	local now = os.clock()
	local window = buyWindows[player]
	if not window or now - window.Start > BUY_WINDOW then
		window = { Start = now, Count = 0 }
		buyWindows[player] = window
	end
	window.Count += 1
	if window.Count > BUY_LIMIT then
		return
	end
	local def = Config.Upgrades[upgradeId]
	if not def then
		return
	end
	if def.License and not PlayerService.hasLicense(session, def.License) then
		PlayerService.notify(
			player,
			("%s needs the %s."):format(def.DisplayName, Bands.Licenses[def.License].DisplayName),
			Color3.fromRGB(255, 120, 90)
		)
		return
	end
	local level = session.Data.Upgrades[upgradeId] or 0
	local check = Economy.checkUpgrade(def.Costs, level, Wallet.cash(session.Data))
	if check.Reason == "maxed" then
		PlayerService.notify(player, def.DisplayName .. " is maxed out!")
		return
	elseif check.Reason == "short" then
		PlayerService.notify(
			player,
			("Need %s more coins."):format(BigMoney.full(check.Short)),
			Color3.fromRGB(255, 120, 90)
		)
		return
	elseif not check.Ok then
		return
	end
	if not Wallet.spend(session.Data, check.Cost) then
		return
	end
	session.Data.Upgrades[upgradeId] = level + 1
	SessionStats.upgraded(player, upgradeId, level + 1)
	PlayerService.applyCharacterStats(player)
	PlayerService.pushState(player)
	PlayerService.notify(
		player,
		("%s upgraded to level %d!"):format(def.DisplayName, level + 1),
		Color3.fromRGB(140, 200, 255)
	)
end

-- Permanent coin tools (Gear Shop Tools tab). Same request budget as upgrades. Coins and
-- ownership change together in the session profile, so they save (or fail to save) together.
function PlayerService.ownsTool(player: Player, toolId: string): boolean
	local session = sessions[player]
	local tools = session and session.Data.Tools
	return tools ~= nil and type(tools.Owned) == "table" and tools.Owned[toolId] == true
end

local function buyTool(player: Player, toolId: unknown)
	local session = sessions[player]
	if not session or type(toolId) ~= "string" or #toolId > 32 then
		return
	end
	local now = os.clock()
	local window = buyWindows[player]
	if not window or now - window.Start > BUY_WINDOW then
		window = { Start = now, Count = 0 }
		buyWindows[player] = window
	end
	window.Count += 1
	if window.Count > BUY_LIMIT then
		return
	end
	local def = Config.Tools[toolId]
	if not def then
		return
	end
	if type(session.Data.Tools) ~= "table" or type(session.Data.Tools.Owned) ~= "table" then
		session.Data.Tools = { Owned = {} }
	end
	local check = Economy.checkTool(def.Cost, session.Data.Tools.Owned[toolId], Wallet.cash(session.Data))
	if check.Reason == "maxed" then
		PlayerService.notify(player, "You already own the " .. def.DisplayName .. ".")
		return
	elseif check.Reason == "short" then
		PlayerService.notify(
			player,
			("Need %s more coins."):format(BigMoney.full(check.Short)),
			Color3.fromRGB(255, 120, 90)
		)
		return
	elseif not check.Ok then
		return
	end
	if not Wallet.spend(session.Data, check.Cost) then
		return
	end
	session.Data.Tools.Owned[toolId] = true
	SessionStats.toolBought(player, toolId)
	PlayerService.pushState(player)
	PlayerService.notify(player, ("%s unlocked!"):format(def.DisplayName), Color3.fromRGB(140, 200, 255))
end

-- V4 M3: buying a licence (Gear Shop Tools tab). Needs every requirement (rank, extractions:
-- things you did, which coins can't buy) AND the coins. Same request budget as upgrades.
local function buyLicense(player: Player, licenseId: unknown)
	local session = sessions[player]
	if not session or type(licenseId) ~= "string" or #licenseId > 32 then
		return
	end
	local now = os.clock()
	local window = buyWindows[player]
	if not window or now - window.Start > BUY_WINDOW then
		window = { Start = now, Count = 0 }
		buyWindows[player] = window
	end
	window.Count += 1
	if window.Count > BUY_LIMIT then
		return
	end
	local def = Bands.Licenses[licenseId]
	if not def then
		return
	end
	if type(session.Data.Licenses) ~= "table" then
		session.Data.Licenses = {}
	end
	local records = session.Data.Records :: any
	local check = Bands.checkLicense(licenseId, {
		Rank = Progression.rankFor(session.Data.Rep.XP).Index,
		Extractions = records and records.Extractions or 0,
		Coins = Wallet.cash(session.Data),
		Owned = session.Data.Licenses[licenseId] == true,
	})
	if check.Reason == "owned" then
		PlayerService.notify(player, "You already hold the " .. def.DisplayName .. ".")
		return
	elseif check.Reason == "requirements" then
		PlayerService.notify(
			player,
			"Not yet: " .. table.concat(check.Missing, "; ") .. ".",
			Color3.fromRGB(255, 120, 90)
		)
		return
	elseif check.Reason == "short" then
		PlayerService.notify(
			player,
			("Need %s more coins."):format(BigMoney.full(Wallet.shortBy(session.Data, def.Cost))),
			Color3.fromRGB(255, 120, 90)
		)
		return
	elseif not check.Ok then
		return
	end
	if not Wallet.spend(session.Data, def.Cost) then
		return
	end
	session.Data.Licenses[licenseId] = true
	SessionStats.event(player, "License_" .. licenseId, 1)
	PlayerService.pushState(player)
	PlayerService.notify(
		player,
		("%s earned! Industrial salvage is yours to haul."):format(def.DisplayName),
		Color3.fromRGB(255, 200, 60)
	)
end

local function onPlayerAdded(player: Player)
	SessionStats.joined(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coins = Instance.new("StringValue")
	coins.Name = "Coins"
	coins.Parent = leaderstats
	leaderstats.Parent = player

	-- A profile still held by another server can take ~40s of retries; say so.
	task.delay(3, function()
		if player.Parent and not sessions[player] then
			PlayerService.notify(player, "Loading your save...", Color3.fromRGB(255, 220, 120))
		end
	end)
	local data, canSave = DataService.load(player)
	if not player.Parent then
		if data and canSave then
			DataService.save(player, data, true)
		end
		return
	end
	if not data then
		player:Kick("Couldn't load your save data. Please rejoin in a minute.")
		return
	end

	local session: Session = {
		Data = data,
		CanSave = canSave,
		Carried = {},
		OwnsHeavyDuty = false,
		LastDamage = 0,
		Sales = 0,
	}
	sessions[player] = session

	-- The first character usually spawns while data is still loading, so handle it too.
	local function onCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		PlayerService.applyCharacterStats(player)
		PlayerService.pushState(player)
		humanoid.Died:Connect(function()
			SessionStats.died(player)
			for _, cb in diedCallbacks do
				task.spawn(cb, player, character)
			end
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end

	for _, cb in loadedCallbacks do
		task.spawn(cb, player, session)
	end
	PlayerService.pushState(player)
	if not canSave then
		PlayerService.notify(
			player,
			"Progress won't save in this session (DataStores unavailable).",
			Color3.fromRGB(255, 200, 80)
		)
	end
end

function PlayerService.save(player: Player, release: boolean): boolean
	local session = sessions[player]
	if not session or not session.CanSave then
		return false
	end
	local saved, lostLock = DataService.save(player, session.Data, release)
	if lostLock then
		-- Another server took over this profile. Stop saving (and granting purchases) here
		-- instead of letting the player keep earning progress that can never be written.
		session.CanSave = false
		PlayerService.pushState(player)
		PlayerService.notify(
			player,
			"Your save is open in another server. Rejoin to keep your progress.",
			Color3.fromRGB(255, 120, 90)
		)
	end
	return saved
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	PlayerService.save(player, true)
	-- Released: nothing may write this profile from here again (an autosave or BindToClose
	-- already in flight is refused by DataService because the lock is gone).
	session.CanSave = false
	sessions[player] = nil
	buyWindows[player] = nil
end

function PlayerService.init()
	-- CharacterAutoLoads stays on; spawn happens before data loads, which is fine.
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	buyUpgradeRemote.OnServerEvent:Connect(buyUpgrade)
	Remotes.get("BuyTool").OnServerEvent:Connect(buyTool)
	Remotes.get("BuyLicense").OnServerEvent:Connect(buyLicense)

	task.spawn(function()
		while true do
			task.wait(Config.AutosaveSeconds)
			for player in sessions do
				task.spawn(PlayerService.save, player, false)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in sessions do
			pending += 1
			task.spawn(function()
				PlayerService.save(player, true)
				pending -= 1
			end)
		end
		local start = os.clock()
		while pending > 0 and os.clock() - start < 25 do
			task.wait(0.1)
		end
	end)
end

return PlayerService
