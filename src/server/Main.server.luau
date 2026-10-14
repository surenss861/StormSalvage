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
local PursuitService = require(script.Parent.PursuitService)
local EventService = require(script.Parent.EventService)
local DodgeService = require(script.Parent.DodgeService)
local StatusService = require(script.Parent.StatusService)
local StormEyeService = require(script.Parent.StormEyeService)
local WreckService = require(script.Parent.WreckService)
local TitanService = require(script.Parent.TitanService)

require(script.Parent.AssetPivotFix).apply() -- before anything places an asset

local map = MapBuilder.build()

-- Studio only: the authored animations, for previews before they're uploaded (CharacterAnims).
if game:GetService("RunService"):IsStudio() then
	local anims = game:GetService("ServerStorage"):FindFirstChild("Assets")
	anims = anims and anims:FindFirstChild("animations")
	if anims then
		local copy = anims:Clone()
		copy.Name = "StudioAnimations"
		copy.Parent = ReplicatedStorage
	end
end

SessionStats.init()
PlayerService.init()
MonetizationService.init()
ContractService.init()
PursuitService.init(map) -- before LootService: its death hook must run first
EventService.init(map) -- before StormService: it schedules off the storm phases
LootService.init(map)
DetectorService.init()
DodgeService.init()
StatusService.init()
StormEyeService.init()
WreckService.init()
TitanService.init()
StormService.init(map)
DebugService.init()
ServerPerf.init() -- staging and Studio only

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	if prompt == map.SellPrompt and PlayerService.isNear(player, prompt) then
		PlayerService.sell(player)
	end
end)
