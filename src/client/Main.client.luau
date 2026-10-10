-- Storm Salvage client: wires the server's state and events into the HUD, cards, shop,
-- settings, storm presentation and audio. The pieces live in their own modules:
--
--   UI             design tokens and builders (docs/ui-design-spec.md)
--   Audio          sound groups, cue throttling, ambience crossfades
--   Hud            storm strip and the right rail (coins, bag, Shop, Settings)
--   Notifications  which message shows where (cards, feed, alerts, hint)
--   Shop/Settings  the two modals
--   SalvageFeedback, StormEffects, Districts   world-facing feedback

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Audio = require(script.Parent:WaitForChild("Audio"))
local Districts = require(script.Parent:WaitForChild("Districts"))
local EnvironmentFX = require(script.Parent:WaitForChild("EnvironmentFX"))
local Hud = require(script.Parent:WaitForChild("Hud"))
local Notifications = require(script.Parent:WaitForChild("Notifications"))
local SalvageFeedback = require(script.Parent:WaitForChild("SalvageFeedback"))
local Settings = require(script.Parent:WaitForChild("Settings"))
local Shop = require(script.Parent:WaitForChild("Shop"))
local StormEffects = require(script.Parent:WaitForChild("StormEffects"))
local UI = require(script.Parent:WaitForChild("UI"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local playerState: any = nil
local stormState: any = { Phase = "Calm", EndsAt = 0 }
local boostEndsAt = 0

---------------------------------------------------------------------------- Setup

Audio.init()
UI.setReducedMotion(StormEffects.isReduced)
UI.setClickSound(function()
	Audio.play("Click")
end)

local gui = UI.new("ScreenGui", {
	Name = "HUD",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	ClipToDeviceSafeArea = false, -- layout stays inside the safe area; only modal dimming reaches past it
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})
local root, topStack = Hud.init(gui)
Notifications.init(root, topStack)

Shop.init(root, {
	Notify = Notifications.feed,
	CanSave = function()
		return playerState == nil or playerState.CanSave ~= false
	end,
})
Settings.init(root, {
	GetVolume = Audio.getVolume,
	SetVolume = Audio.setVolume,
	Preview = function(kind)
		-- A short, recognisable sample from the group being changed.
		if kind == "Weather" then
			Audio.play("Gust", 0.6)
		else
			Audio.play("Sell", 0.7)
		end
	end,
	IsReduced = StormEffects.isReduced,
	SetReduced = StormEffects.setReduced,
})
for _, modal in { Shop.modal(), Settings.modal() } do
	modal.Changed.Event:Connect(function()
		Notifications.setModalOpen(Shop.modal().IsOpen() or Settings.modal().IsOpen())
	end)
end

local shopButton = Hud.ShopButton :: TextButton
local settingsButton = Hud.SettingsButton :: TextButton
shopButton.Activated:Connect(Shop.toggle)
settingsButton.Activated:Connect(Settings.toggle)
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "UpgradePrompt" then
		Shop.open()
	end
end)

SalvageFeedback.init()
StormEffects.init(Remotes.get("LightningWarning"))
Districts.init()
EnvironmentFX.init(StormEffects.getState, StormEffects.gustPhase, StormEffects.isReduced)
StormEffects.setStrikeHook(EnvironmentFX.onStrike)

---------------------------------------------------------------------------- Tutorial hint

-- Guidance only while it's useful: until the first sale, and never during a storm.
local function updateHint()
	local s = playerState
	if not s or s.Stats.ItemsSold > 0 then
		Notifications.setHint(nil)
	elseif #s.Carried == 0 then
		Notifications.setHint("Head down into town and grab glowing salvage!")
	elseif #s.Carried >= s.Capacity then
		Notifications.setHint("Bag full! Sell at the Scrap Buyer on the hill")
	else
		Notifications.setHint("Grab more, or sell at the Scrap Buyer on the hill")
	end
	Notifications.setStormy(stormState.Phase == "Warning" or stormState.Phase == "Storm")
end

---------------------------------------------------------------------------- Server state

local lastCarried = 0
local lastLevels: number? = nil
Remotes.get("PlayerState").OnClientEvent:Connect(function(s)
	playerState = s
	boostEndsAt = os.clock() + (s.BoostRemaining or 0)
	if #s.Carried > lastCarried then
		Hud.pulseBag()
	end
	lastCarried = #s.Carried
	local levels = 0
	for _, level in s.Upgrades do
		levels += level
	end
	if lastLevels and levels > lastLevels then
		Audio.play("Upgrade")
	end
	lastLevels = levels
	Hud.setPlayer(s)
	Shop.setState(s)
	updateHint()
end)

-- Pickup feedback (pops, find cards) and sale receipts come from the server's exact results.
Remotes.get("Pickup").OnClientEvent:Connect(function(info)
	local carried = playerState and #playerState.Carried or 0
	local capacity = playerState and playerState.Capacity or 0
	SalvageFeedback.onPickup(info, carried, capacity)
end)
Remotes.get("SaleReceipt").OnClientEvent:Connect(function(receipt)
	SalvageFeedback.onSale(receipt)
end)

Remotes.get("Notify").OnClientEvent:Connect(function(text, color)
	Notifications.feed(text, color)
end)

local WARNING_CUE = { Wind = "WarnWind", Flood = "WarnFlood", Lightning = "WarnLightning" }

Remotes.get("StormState").OnClientEvent:Connect(function(s)
	local previous = stormState.Phase
	stormState = s
	if s.Phase == "Warning" and previous ~= "Warning" then
		-- The shared siren says "storm coming"; the storm's own cue says which one.
		Audio.play("Siren")
		task.delay(4, Audio.fadeOut, "Siren", 2.5)
		task.delay(0.6, Audio.play, WARNING_CUE[s.Storm] or "WarnWind")
	elseif s.Phase ~= "Warning" and previous == "Warning" then
		Audio.fadeOut("Siren", 1.5)
	end
	local storming = s.Phase == "Storm"
	Audio.setAmbience("Rain", storming and (s.Storm == "Flood" or s.Storm == "Lightning"))
	Audio.setAmbience("Flood", storming and s.Storm == "Flood")
	StormEffects.setState(s)
	updateHint()
end)

---------------------------------------------------------------------------- Loot bob

-- Loot gently floats and spins so it reads as "pick me up". Purely local: the server's
-- anchored parts never move, and only items near the camera are animated.
local lootBase: { [BasePart]: CFrame } = {}
local function trackLoot(item: Instance)
	if item:IsA("BasePart") then
		lootBase[item] = item.CFrame
	end
end
task.spawn(function()
	local lootFolder = workspace:WaitForChild("Loot")
	lootFolder.ChildAdded:Connect(trackLoot)
	lootFolder.ChildRemoved:Connect(function(item)
		lootBase[item :: BasePart] = nil
	end)
	for _, item in lootFolder:GetChildren() do
		trackLoot(item)
	end
end)

local function animateLoot(cameraPosition: Vector3)
	local t = os.clock()
	for item, base in lootBase do
		local pos = base.Position
		if (pos - cameraPosition).Magnitude < 120 then
			local bob = 0.35 + math.sin(t * 2 + pos.X * 0.3) * 0.25
			item.CFrame = CFrame.new(pos + Vector3.new(0, bob, 0))
				* CFrame.Angles(0, t * 1.2 + pos.Z, 0)
				* base.Rotation
		end
	end
end

---------------------------------------------------------------------------- Per frame

RunService.RenderStepped:Connect(function()
	local now = workspace:GetServerTimeNow()
	local status, statusColor = StormEffects.statusLine(now)
	Hud.stepStorm(now, stormState, status, statusColor, SalvageFeedback.coreCount())
	Hud.stepBoost(boostEndsAt - os.clock())

	local camera = workspace.CurrentCamera
	if camera then
		animateLoot(camera.CFrame.Position)
	end
	StormEffects.step(now)
	EnvironmentFX.step(now)
	SalvageFeedback.step(now)
	Notifications.step()
end)

-- Studio QA: lets test scripts read audio asset status without reaching into modules.
if RunService:IsStudio() then
	local probe = Instance.new("BindableFunction")
	probe.Name = "QA_ClientProbe"
	probe.OnInvoke = function(what: string)
		if what == "audio" then
			return Audio.status()
		elseif what == "card" then
			return Notifications.cardPriority()
		elseif what == "settings" then
			-- Studio's device simulator doesn't deliver simulated clicks to buttons.
			Settings.toggle()
			return Settings.modal().IsOpen()
		end
		return nil
	end
	probe.Parent = script
end
