-- @file Client entry: wires server state into the HUD
-- @domain ui
-- @status stable
-- @see [[Remotes.luau]]
-- Storm Salvage client: wires the server's state and events into the HUD, cards, shop,
-- settings, storm presentation and audio. The pieces live in their own modules:
--
--   UI             design tokens and builders (docs/ui-design-spec.md)
--   Audio          sound groups, cue throttling, ambience crossfades
--   Hud            cash tag, crate, storm sign, Gear Shop tag and Settings plate
--   Notifications  which message shows where (cards, feed, alerts, hint)
--   Shop/Settings  the two modals
--   SalvageFeedback, StormEffects, Districts   world-facing feedback

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Audio = require(script.Parent:WaitForChild("Audio"))
local CameraOcclusion = require(script.Parent:WaitForChild("CameraOcclusion"))
local Districts = require(script.Parent:WaitForChild("Districts"))
local EnvironmentFX = require(script.Parent:WaitForChild("EnvironmentFX"))
local Hud = require(script.Parent:WaitForChild("Hud"))
local Jobs = require(script.Parent:WaitForChild("Jobs"))
local DetectorHud = require(script.Parent:WaitForChild("DetectorHud"))
local Movement = require(script.Parent:WaitForChild("Movement"))
local Dodge = require(script.Parent:WaitForChild("Dodge"))
local CharacterAnims = require(script.Parent:WaitForChild("CharacterAnims"))
local PlayerCard = require(script.Parent:WaitForChild("PlayerCard"))
local StormEyeHud = require(script.Parent:WaitForChild("StormEyeHud"))
local WreckHud = require(script.Parent:WaitForChild("WreckHud"))
local TitanHud = require(script.Parent:WaitForChild("TitanHud"))
local WorldMotion = require(script.Parent:WaitForChild("WorldMotion"))
local EventStrip = require(script.Parent:WaitForChild("EventStrip"))
local BigMoney = require(ReplicatedStorage.Shared:WaitForChild("BigMoney"))
local PursuitHud = require(script.Parent:WaitForChild("PursuitHud"))
local Nameplates = require(script.Parent:WaitForChild("Nameplates"))
local Notifications = require(script.Parent:WaitForChild("Notifications"))
local SalvageFeedback = require(script.Parent:WaitForChild("SalvageFeedback"))
local Settings = require(script.Parent:WaitForChild("Settings"))
local Shop = require(script.Parent:WaitForChild("Shop"))
local StormEffects = require(script.Parent:WaitForChild("StormEffects"))
local UI = require(script.Parent:WaitForChild("UI"))
local PerfProbe = require(script.Parent:WaitForChild("PerfProbe"))
local ViewHealth = require(script.Parent:WaitForChild("ViewHealth"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local playerState: any = nil
local stormState: any = { Phase = "Calm", EndsAt = 0 }
local boostEndsAt = 0

---------------------------------------------------------------------------- Setup

-- Interface theme (UI.useTheme): Workshop, the V3 direction. Studio QA can preview Classic
-- with the ReplicatedStorage attribute "UITheme" set before players join.
UI.useTheme(ReplicatedStorage:GetAttribute("UITheme") or "Workshop")
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
EventStrip.init(topStack)
Hud.onLayout(EventStrip.setCompact)
Notifications.init(root, topStack)
Hud.onLayout(Notifications.applyLayout)

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
Jobs.init(root)
PlayerCard.init(root)
DetectorHud.init(root, Hud.onLayout)
Movement.init(function(text)
	Notifications.feed(text, Color3.fromRGB(255, 226, 110), 5)
end)
PursuitHud.init(topStack)
StormEyeHud.init(topStack)
WreckHud.init(topStack)
TitanHud.init(topStack)
CharacterAnims.init()
Dodge.init()
Nameplates.init()
for _, modal in { Shop.modal(), Settings.modal(), Jobs.modal(), PlayerCard.modal() } do
	modal.Changed.Event:Connect(function()
		local open = Shop.modal().IsOpen()
			or Settings.modal().IsOpen()
			or Jobs.modal().IsOpen()
			or PlayerCard.modal().IsOpen()
		Notifications.setModalOpen(open)
		Hud.setModalOpen(open)
	end)
end

local shopButton = Hud.ShopButton :: TextButton
local settingsButton = Hud.SettingsButton :: TextButton
shopButton.Activated:Connect(Shop.toggle)
settingsButton.Activated:Connect(Settings.toggle);
(Hud.JobsButton :: TextButton).Activated:Connect(Jobs.toggle)
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "UpgradePrompt" then
		Shop.open()
	elseif prompt.Name == "JobsPrompt" then
		Jobs.open()
	end
end)

SalvageFeedback.init()
StormEffects.init(Remotes.get("LightningWarning"))
Districts.init()
WorldMotion.init()
EnvironmentFX.init(StormEffects.getState, StormEffects.gustPhase, StormEffects.isReduced)
StormEffects.setStrikeHook(EnvironmentFX.onStrike)
CameraOcclusion.init()
ViewHealth.init()
PerfProbe.init() -- staging and Studio only

---------------------------------------------------------------------------- Tutorial hint

-- Guidance only while it's useful: until the first sale, and never during a storm.
-- The first expedition as a short chain of objectives; it fades out after the first upgrade.
local function cheapestUpgrade(s: any): number?
	local best: number? = nil
	for id, def in Config.Upgrades do
		local cost = def.Costs[(s.Upgrades[id] or 0) + 1]
		if cost and (best == nil or cost < best) then
			best = cost
		end
	end
	return best
end

local function updateHint()
	local s = playerState
	local upgraded = 0
	if s then
		for _, level in s.Upgrades do
			upgraded += level
		end
	end
	if not s or (s.Stats.ItemsSold > 0 and upgraded > 0) then
		-- After the first-session chain, the note shows the pinned job.
		Notifications.setHint(Jobs.pinnedLine(s))
	elseif s.Stats.ItemsSold > 0 then
		local cost = cheapestUpgrade(s)
		if cost and BigMoney.gte(s.Coins, BigMoney.of(cost)) then
			Notifications.setHint("You can afford gear! Visit the Gear Shop in the Scrapyard")
		elseif #s.Carried == 0 then
			Notifications.setHint(
				("Salvage more: next upgrade costs %s coins"):format(BigMoney.full(cost or 0))
			)
		else
			Notifications.setHint(Jobs.pinnedLine(s))
		end
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

-- Staged discovery (first session): learn to salvage and survive first. The Jobs board (and its
-- notices) appears after the first sale, the Supply Counter tab after the first upgrade.
-- Contract progress and XP still accrue from the start, server-side; only the UI waits.
local jobsUnlocked = false
local jobsSeenLocked = false
local function stageDiscovery(s: any)
	local levels = 0
	for _, level in s.Upgrades do
		levels += level
	end
	local unlocked = s.Stats.ItemsSold > 0
	if not unlocked then
		jobsSeenLocked = true
	elseif not jobsUnlocked and jobsSeenLocked then
		-- Unlocked during this session: say so once.
		Notifications.feed(
			"NEW: the JOBS board. Bonus contracts for coins and Salvager rank!",
			Color3.fromRGB(255, 226, 110),
			6
		)
	end
	jobsUnlocked = unlocked
	local jobsButton = Hud.JobsButton :: TextButton
	jobsButton.Visible = unlocked
	-- The Tools tab (Detector, and the Pro licence) appears after the first upgrade, or once the
	-- player has extracted a core: the licence's requirements start there.
	local extracted = type(s.Records) == "table" and (s.Records.Extractions or 0) > 0
	Shop.setSupplyVisible(levels > 0 or extracted)
end

local lastCarried = 0
local lastLevels: number? = nil
Remotes.get("PlayerState").OnClientEvent:Connect(function(s)
	playerState = s
	boostEndsAt = os.clock() + (s.BoostRemaining or 0)
	if #s.Carried > lastCarried then
		Hud.pulseBag()
	end
	lastCarried = #s.Carried
	local core = false
	for _, id in s.Carried do
		if Config.CoreIds[id] then
			core = true
		end
	end
	CharacterAnims.setCarrying(core)
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
	Jobs.setState(s)
	DetectorHud.setState(s)
	stageDiscovery(s)
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

-- Contract completions and rank-ups (server-confirmed; the coins and XP are already in the state).
Remotes.get("ProgressEvent").OnClientEvent:Connect(function(e)
	if type(e) ~= "table" then
		return
	end
	if e.Kind == "Title" then
		-- An earned title (server-granted): its own card, always shown.
		Notifications.card({
			Priority = 7,
			Accent = Color3.fromRGB(255, 196, 48),
			Height = 96,
			Width = 290,
			Seconds = 5,
			Surface = "Tag",
			Build = function(card)
				UI.text({
					Parent = card,
					Font = UI.Font.Mono,
					TextSize = 13,
					Position = UDim2.fromOffset(16, 10),
					Size = UDim2.new(1, -32, 0, 16),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = Color3.fromRGB(150, 100, 20),
					Text = "TITLE EARNED",
				})
				UI.text({
					Parent = card,
					Font = UI.Font.Title,
					TextSize = 24,
					Position = UDim2.fromOffset(16, 28),
					Size = UDim2.new(1, -32, 0, 30),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = UI.Mat.Marker,
					Text = tostring(e.Name),
				})
				UI.text({
					Parent = card,
					Font = UI.Font.Label,
					TextSize = 12,
					Position = UDim2.fromOffset(16, 62),
					Size = UDim2.new(1, -32, 0, 26),
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = UI.Mat.Pencil,
					Text = tostring(e.How) .. "  ·  Show it from Jobs > Titles",
				})
			end,
		})
		Audio.play("CoreDelivered", 0.5)
		return
	end
	if e.Kind == "Discovery" then
		-- Every kind is logged from the first pickup; early on, only Rare and better say so, so
		-- a new player's first minute isn't a stream of "new" notices for cans and pipes.
		local rare = e.Rarity == "Rare" or e.Rarity == "Epic" or e.Rarity == "Legendary"
		if jobsUnlocked or rare then
			Notifications.feed(
				("NEW IN YOUR SALVAGE LOG: %s  (%d/%d)"):format(tostring(e.Name), e.Count or 0, e.Total or 0),
				Color3.fromRGB(255, 226, 110),
				4
			)
		end
		return
	end
	if not jobsUnlocked then
		return -- rewards are already in the state; the notices wait until Jobs are introduced
	end
	if e.Kind == "Job" then
		Notifications.feed(
			("JOB DONE: %s  +%d coins  +%d XP"):format(tostring(e.Text), e.Coins or 0, e.XP or 0),
			Color3.fromRGB(140, 230, 140),
			4.5
		)
		Audio.play("Upgrade", 0.6)
	elseif e.Kind == "RankUp" then
		local unlocked = if type(e.Unlocked) == "table" and #e.Unlocked > 0
			then ("New nameplate finish: %s"):format(table.concat(e.Unlocked, ", "))
			else "Check the Jobs board"
		Notifications.card({
			Priority = 6,
			Accent = Color3.fromRGB(80, 150, 230),
			Height = 96,
			Width = 270,
			Seconds = 4,
			Surface = "Tag",
			Build = function(card)
				UI.text({
					Parent = card,
					Font = UI.Font.Mono,
					TextSize = 16,
					Position = UDim2.fromOffset(24, 8),
					Size = UDim2.new(1, -34, 0, 26),
					TextColor3 = Color3.new(1, 1, 1),
					Text = "RANK UP!",
					ZIndex = 7,
				})
				UI.text({
					Parent = card,
					Font = UI.Font.Title,
					TextSize = 24,
					Position = UDim2.fromOffset(0, 40),
					Size = UDim2.new(1, 0, 0, 28),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = UI.Mat.Marker,
					Text = tostring(e.Title),
					ZIndex = 7,
				})
				UI.text({
					Parent = card,
					Font = UI.Font.Label,
					TextSize = 12,
					Position = UDim2.fromOffset(0, 70),
					Size = UDim2.new(1, 0, 0, 16),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextColor3 = UI.Mat.Pencil,
					Text = unlocked,
					ZIndex = 7,
				})
			end,
		})
		Audio.play("Upgrade")
	end
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
		elseif what == "shop" then
			Shop.toggle()
			return Shop.modal().IsOpen()
		elseif what == "settings" then
			-- Studio's device simulator doesn't deliver simulated clicks to buttons.
			Settings.toggle()
			return Settings.modal().IsOpen()
		end
		return nil
	end
	probe.Parent = script
end
