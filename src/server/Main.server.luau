-- @file Server entry point
-- @domain core
-- @status stable
-- @see [[V3-PRODUCTION-TRACKER]]
-- Storm Salvage server entry point.

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

require(ReplicatedStorage.Shared.Remotes) -- creates the remotes before anything uses them

local MapBuilder = require(script.Parent.MapBuilder)
local PlayerService = require(script.Parent.PlayerService)
local LootService = require(script.Parent.LootService)
local StormService = require(script.Parent.StormService)
local MonetizationService = require(script.Parent.MonetizationService)
local DebugService = require(script.Parent.DebugService)
local SessionStats = require(script.Parent.SessionStats)
local ServerPerf = require(script.Parent.ServerPerf)
local ContractService = require(script.Parent.ContractService)
local DetectorService = require(script.Parent.DetectorService)

require(script.Parent.AssetPivotFix).apply() -- before anything places an asset

local map = MapBuilder.build()

SessionStats.init()
PlayerService.init()
MonetizationService.init()
ContractService.init()
LootService.init(map)
DetectorService.init()
StormService.init(map)
DebugService.init()
ServerPerf.init() -- staging and Studio only

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	if prompt == map.SellPrompt and PlayerService.isNear(player, prompt) then
		PlayerService.sell(player)
	end
end)
