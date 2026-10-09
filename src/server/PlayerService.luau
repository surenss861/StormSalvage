-- Owns each player's session: saved data, the salvage they are carrying,
-- character stats from upgrades, selling, and buying upgrades.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local PlayerService = {}

export type Session = {
	Data: DataService.Data,
	CanSave: boolean,
	Carried: { string }, -- loot ids
	OwnsBigBag: boolean,
	OwnsVIP: boolean,
	LastDamage: number,
}

local sessions: { [Player]: Session } = {}
local loadedCallbacks: { (Player, Session) -> () } = {}
local diedCallbacks: { (Player, Model) -> () } = {}

local playerStateRemote = Remotes.get("PlayerState")
local notifyRemote = Remotes.get("Notify")
local buyUpgradeRemote = Remotes.get("BuyUpgrade")

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
	return upgradeValue(session, "Backpack") + (session.OwnsBigBag and Config.GamePasses.BigBag.BonusCapacity or 0)
end

function PlayerService.boostRemaining(session: Session): number
	return math.max(0, session.Data.BoostUntil - os.time())
end

function PlayerService.sellMultiplier(session: Session): number
	local m = 1
	if session.OwnsVIP then
		m *= Config.GamePasses.VIP.SellMultiplier
	end
	if PlayerService.boostRemaining(session) > 0 then
		m *= 2
	end
	return m
end

local function carriedValue(session: Session): number
	local total = 0
	for _, id in session.Carried do
		total += Config.Loot[id].Value
	end
	return total
end

function PlayerService.pushState(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	playerStateRemote:FireClient(player, {
		Coins = session.Data.Coins,
		Carried = session.Carried,
		CarriedValue = math.floor(carriedValue(session) * PlayerService.sellMultiplier(session)),
		Capacity = PlayerService.getCapacity(session),
		Upgrades = session.Data.Upgrades,
		BoostRemaining = PlayerService.boostRemaining(session),
		OwnsVIP = session.OwnsVIP,
		OwnsBigBag = session.OwnsBigBag,
		Stats = session.Data.Stats,
		CanSave = session.CanSave,
	})
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if coins then
		(coins :: IntValue).Value = session.Data.Coins
	end
end

function PlayerService.applyCharacterStats(player: Player)
	local session = sessions[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if session and humanoid then
		humanoid.WalkSpeed = upgradeValue(session, "Boots")
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

function PlayerService.addCoins(player: Player, amount: number)
	local session = sessions[player]
	if not session then
		return
	end
	session.Data.Coins += amount
	session.Data.Stats.TotalEarned += amount
	PlayerService.pushState(player)
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
	local earned = math.floor(carriedValue(session) * PlayerService.sellMultiplier(session))
	session.Data.Stats.ItemsSold += #session.Carried
	session.Carried = {}
	PlayerService.addCoins(player, earned)
	PlayerService.notify(player, ("Sold for %d coins!"):format(earned), Color3.fromRGB(120, 255, 140))
end

local function buyUpgrade(player: Player, upgradeId: unknown)
	local session = sessions[player]
	if not session or type(upgradeId) ~= "string" then
		return
	end
	local def = Config.Upgrades[upgradeId]
	if not def then
		return
	end
	local level = session.Data.Upgrades[upgradeId] or 0
	local cost = def.Costs[level + 1]
	if not cost then
		PlayerService.notify(player, def.DisplayName .. " is maxed out!")
		return
	end
	if session.Data.Coins < cost then
		PlayerService.notify(player, ("Need %d more coins."):format(cost - session.Data.Coins), Color3.fromRGB(255, 120, 90))
		return
	end
	session.Data.Coins -= cost
	session.Data.Upgrades[upgradeId] = level + 1
	PlayerService.applyCharacterStats(player)
	PlayerService.pushState(player)
	PlayerService.notify(player, ("%s upgraded to level %d!"):format(def.DisplayName, level + 1), Color3.fromRGB(140, 200, 255))
end

local function onPlayerAdded(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = leaderstats
	leaderstats.Parent = player

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
		OwnsBigBag = false,
		OwnsVIP = false,
		LastDamage = 0,
	}
	sessions[player] = session

	-- The first character usually spawns while data is still loading, so handle it too.
	local function onCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		PlayerService.applyCharacterStats(player)
		PlayerService.pushState(player)
		humanoid.Died:Connect(function()
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
		PlayerService.notify(player, "Progress won't save in this session (DataStores unavailable).", Color3.fromRGB(255, 200, 80))
	end
end

function PlayerService.save(player: Player, release: boolean): boolean
	local session = sessions[player]
	if not session or not session.CanSave then
		return false
	end
	return DataService.save(player, session.Data, release)
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	PlayerService.save(player, true)
	sessions[player] = nil
end

function PlayerService.init()
	-- CharacterAutoLoads stays on; spawn happens before data loads, which is fine.
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	buyUpgradeRemote.OnServerEvent:Connect(buyUpgrade)

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
