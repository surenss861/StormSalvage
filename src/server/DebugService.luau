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
--   debug:Invoke("stats")               -- recent StormStats records
--   debug:Invoke("session")             -- first-session progression per player
--   debug:Invoke("spawn", "Safe", pos)  -- one loot item on the floor at pos
--   debug:Invoke("boost", 60)           -- 2x Salvage for everyone, for testing sale multipliers
--   debug:Invoke("look", "A")           -- switch the world look profile (V2, A, B, C)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local LookService = require(script.Parent.LookService)
local LootService = require(script.Parent.LootService)
local MonetizationService = require(script.Parent.MonetizationService)
local PlayerService = require(script.Parent.PlayerService)
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
	receipt = function(playerName: string, purchaseId: string)
		local player = Players:FindFirstChild(playerName)
		assert(player and player:IsA("Player"), "no player " .. tostring(playerName))
		return MonetizationService.simulateReceipt(player, purchaseId).Name
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
					Coins = session.Data.Coins,
					Carried = table.clone(session.Carried),
					Capacity = PlayerService.getCapacity(session),
					Upgrades = table.clone(session.Data.Upgrades),
					Stats = table.clone(session.Data.Stats),
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
