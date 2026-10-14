-- @file Studio-only QA commands
-- @domain qa
-- @status stable
-- @see [[V3-PRELAUNCH-TEST-PLAN]]
-- Studio-only QA hooks so storms and progression can be tested without waiting out
-- the full cycle. Exposed as a BindableFunction in ServerStorage, which clients can't
-- reach, and only created when running inside Studio.
--
--   local debug = game.ServerStorage.StormSalvageDebug
--   debug:Invoke("storm", "Lightning")  -- next storm type, then skip to it
--   debug:Invoke("skip")                -- end the current phase now
--   debug:Invoke("coins", 500)          -- give every player coins
--   debug:Invoke("state")               -- storm + player summary
--   debug:Invoke("receipt", "Player1", "purchase-1")  -- simulated receipt -> decision name
--   debug:Invoke("save", "Player1")     -- save now -> true if persisted
--   debug:Invoke("give", "Player1", "Safe", "Tv")  -- loot straight into the bag
--   debug:Invoke("faults", "grant", 1)  -- next DataStore grant fails (purchase-safety tests)
--   debug:Invoke("stats")               -- recent StormStats records
--   debug:Invoke("session")             -- first-session progression per player
--   debug:Invoke("spawn", "Safe", pos)  -- one loot item on the floor at pos
--   debug:Invoke("boost", 60)           -- 2x Salvage for everyone, for testing sale multipliers
--   debug:Invoke("look", "A")           -- switch the world look profile (V2, A, B, C)
--   debug:Invoke("dodge", "Player1")    -- dodge counters (honoured, refused, flags, judged pos)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Wallet = require(game:GetService("ReplicatedStorage").Shared.Wallet)
local DataService = require(script.Parent.DataService)
local DodgeService = require(script.Parent.DodgeService)
local LookService = require(script.Parent.LookService)
local LootService = require(script.Parent.LootService)
local MonetizationService = require(script.Parent.MonetizationService)
local PlayerService = require(script.Parent.PlayerService)
local EventService = require(script.Parent.EventService)
local PursuitService = require(script.Parent.PursuitService)
local StormService = require(script.Parent.StormService)
local SessionStats = require(script.Parent.SessionStats)
local StormStats = require(script.Parent.StormStats)

local DebugService = {}

local commands: { [string]: (...any) -> any } = {
	skip = function()
		StormService.skipPhase()
		return "skipped"
	end,
	storm = function(name: string)
		assert(Config.Storms[name], "unknown storm " .. tostring(name))
		StormService.forceNextStorm(name)
		local phase = StormService.getState().Phase
		if phase == "Calm" then
			StormService.skipPhase()
		end
		return "next storm: " .. name .. " (was in " .. phase .. ")"
	end,
	coins = function(amount: number)
		for _, player in Players:GetPlayers() do
			PlayerService.addCoins(player, amount)
		end
		return "granted " .. amount
	end,
	receipt = function(playerName: string, purchaseId: string, productKey: string?)
		local player = Players:FindFirstChild(playerName)
		assert(player and player:IsA("Player"), "no player " .. tostring(playerName))
		return MonetizationService.simulateReceipt(player, purchaseId, productKey).Name
	end,
	-- Salvager XP through the real rank-up path (Contracts/Reputation tests).
	xp = function(playerName: string, amount: number)
		local player = Players:FindFirstChild(playerName)
		assert(player and player:IsA("Player"), "no player " .. tostring(playerName))
		require(script.Parent.ContractService).addXPForTest(player, amount)
		return player:GetAttribute("RankTitle")
	end,
	-- Simulate Roblox reporting a completed Heavy-Duty Pack purchase.
	passbuy = function(playerName: string)
		local player = Players:FindFirstChild(playerName)
		assert(player and player:IsA("Player"), "no player " .. tostring(playerName))
		MonetizationService.simulatePassPurchase(player)
		return PlayerService.getCapacity(PlayerService.get(player) :: any)
	end,
	-- Make the next `count` DataStore calls of one kind fail: "grant", "save", "historyWrite"
	-- (purchase-safety tests).
	faults = function(operation: string, count: number)
		DataService.failNextForTest(operation, count)
		return ("next %d %s calls fail"):format(count, operation)
	end,
	-- Drop a PurchaseId from the live profile's receipt list (fault-injection tests).
	forgetreceipt = function(playerName: string, purchaseId: string)
		local player = Players:FindFirstChild(playerName)
		local session = player and player:IsA("Player") and PlayerService.get(player)
		assert(session, "no session")
		local index = table.find(session.Data.ProcessedReceipts, purchaseId)
		if index then
			table.remove(session.Data.ProcessedReceipts, index)
		end
		return index ~= nil
	end,
	-- Set a player's cash exactly (a number or a digit string; restoring a test account after
	-- purchase tests, or big-number tests).
	setcoins = function(playerName: string, amount: number | string)
		local player = Players:FindFirstChild(playerName)
		local session = player and player:IsA("Player") and PlayerService.get(player)
		assert(session, "no session")
		Wallet.setCashForTest(session.Data, amount)
		PlayerService.pushState(player :: Player)
		return Wallet.cash(session.Data)
	end,
	-- V4 events: start one now. event("Pursuit" | "Extraction" | "Rush", siteId) or eventnext().
	event = function(kind: string, siteId: string, prize: string?)
		return EventService.start(kind, siteId, prize) -- prize "GoldenCore" forces the jackpot (Studio QA)
	end,
	eventnext = function()
		return EventService.startNext()
	end,
	-- Back-compat for the QA runner: a Storm Pursuit at Warehouse 7.
	pursuit = function()
		return (EventService.start("Pursuit", "Warehouse"))
	end,
	pursuitstate = function()
		return PursuitService.state()
	end,
	strikehits = function()
		return PursuitService.takeQaHits()
	end,
	-- V4 M3 tests (Studio only, the _STUDIO store): clear licences and Press, or set progress.
	clearlicense = function(playerName: string)
		local player = Players:FindFirstChild(playerName)
		local session = player and player:IsA("Player") and PlayerService.get(player)
		assert(session, "no session")
		session.Data.Licenses = {}
		session.Data.Upgrades.Press = 0
		PlayerService.pushState(player :: Player)
		return true
	end,
	progress = function(playerName: string, xp: number?, extractions: number?)
		local player = Players:FindFirstChild(playerName)
		local session = player and player:IsA("Player") and PlayerService.get(player)
		assert(session, "no session")
		if xp then
			session.Data.Rep.XP = xp
		end
		if extractions then
			(session.Data.Records :: any).Extractions = extractions
		end
		PlayerService.pushState(player :: Player)
		return { XP = session.Data.Rep.XP, Extractions = (session.Data.Records :: any).Extractions }
	end,
	profile = function(playerName: string)
		local player = Players:FindFirstChild(playerName)
		local session = player and player:IsA("Player") and PlayerService.get(player)
		assert(session, "no session")
		local d = session.Data
		return {
			Coins = Wallet.cash(d),
			TotalEarned = Wallet.lifetime(d),
			Mirror = { Coins = d.Coins, TotalEarned = d.Stats.TotalEarned },
			XP = d.Rep.XP,
			Records = d.Records,
			Licenses = d.Licenses,
			Press = d.Upgrades.Press,
			Titles = d.Titles,
			Band = PlayerService.bandOf(player :: Player),
		}
	end,
	-- A harmless debris strike on a player (0 damage); its verdict lands in strikehits.
	strikeat = function(playerName: string)
		local player = Players:FindFirstChild(playerName)
		assert(player and player:IsA("Player"), "no player")
		PursuitService.qaStrike(player)
		return true
	end,
	-- Dodge authority counters and the position hits are judged at.
	dodge = function(playerName: string)
		local player = Players:FindFirstChild(playerName)
		assert(player and player:IsA("Player"), "no player")
		local stats = DodgeService.stats(player)
		stats.Judged = DodgeService.judgedPosition(player)
		return stats
	end,
	-- Clear a player's tool ownership (repeatable Tools-tab purchase tests).
	cleartools = function(playerName: string)
		local player = Players:FindFirstChild(playerName)
		local session = player and player:IsA("Player") and PlayerService.get(player)
		assert(session, "no session")
		session.Data.Tools = { Owned = {} }
		PlayerService.pushState(player :: Player)
		return true
	end,
	-- Append `count` synthetic PurchaseIds to a player's receipt list (long-lived profile tests).
	padreceipts = function(playerName: string, count: number)
		local player = Players:FindFirstChild(playerName)
		local session = player and player:IsA("Player") and PlayerService.get(player)
		assert(session, "no session")
		local list = session.Data.ProcessedReceipts
		local start = #list
		for i = 1, count do
			table.insert(list, ("pad-%d-%d"):format(start + i, 1000000000 + start + i))
		end
		return #list
	end,
	-- Put loot straight into a player's bag (UI captures), up to capacity.
	give = function(playerName: string, ...: string)
		local player = Players:FindFirstChild(playerName)
		local session = player and player:IsA("Player") and PlayerService.get(player)
		assert(session, "no session")
		for _, id in { ... } do
			assert(Config.Loot[id], "no loot " .. tostring(id))
			if #session.Carried < PlayerService.getCapacity(session) then
				table.insert(session.Carried, id)
			end
		end
		PlayerService.pushState(player :: Player)
		return #session.Carried
	end,
	-- Race test: start `times` sales for one player in the same frame.
	sellrace = function(playerName: string, times: number)
		local player = Players:FindFirstChild(playerName)
		assert(player and player:IsA("Player"), "no player " .. tostring(playerName))
		for _ = 1, times do
			task.spawn(PlayerService.sell, player)
		end
		return "started " .. times
	end,
	save = function(playerName: string)
		local player = Players:FindFirstChild(playerName)
		assert(player and player:IsA("Player"), "no player " .. tostring(playerName))
		return PlayerService.save(player, false)
	end,
	spawn = function(lootId: string, position: Vector3)
		return LootService.spawnForTest(lootId, position):GetFullName()
	end,
	boost = function(seconds: number)
		for _, player in Players:GetPlayers() do
			local session = PlayerService.get(player)
			if session then
				session.Data.BoostUntil = os.time() + seconds
				PlayerService.pushState(player)
			end
		end
		return "boost " .. seconds
	end,
	look = function(name: string)
		LookService.apply(name)
		StormService.refreshSky()
		return "look " .. name
	end,
	session = function()
		return SessionStats.all()
	end,
	stats = function()
		return StormStats.history()
	end,
	state = function()
		local players = {}
		for _, player in Players:GetPlayers() do
			local session = PlayerService.get(player)
			if session then
				players[player.Name] = {
					Coins = Wallet.cash(session.Data),
					Carried = table.clone(session.Carried),
					Capacity = PlayerService.getCapacity(session),
					Upgrades = table.clone(session.Data.Upgrades),
					Stats = table.clone(session.Data.Stats),
					Tools = table.clone(session.Data.Tools.Owned),
					CanSave = session.CanSave,
				}
			end
		end
		return { Storm = StormService.getState(), Players = players }
	end,
}

function DebugService.init()
	if not RunService:IsStudio() then
		return
	end
	local fn = Instance.new("BindableFunction")
	fn.Name = "StormSalvageDebug"
	fn.OnInvoke = function(command: string, ...)
		local handler = commands[command]
		assert(handler, "unknown debug command " .. tostring(command))
		return handler(...)
	end
	fn.Parent = ServerStorage
end

return DebugService
