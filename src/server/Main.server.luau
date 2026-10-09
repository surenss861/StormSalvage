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

local map = MapBuilder.build()

PlayerService.init()
MonetizationService.init()
LootService.init(map)
StormService.init(map)
DebugService.init()

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	if prompt == map.SellPrompt and PlayerService.isNear(player, prompt) then
		PlayerService.sell(player)
	end
end)
