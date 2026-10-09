-- Storm Salvage client: HUD, upgrade shop, tutorial hints, storm visuals.

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage.Shared:WaitForChild("Remotes"))
local Shelter = require(ReplicatedStorage.Shared:WaitForChild("Shelter"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local PANEL = Color3.fromRGB(25, 28, 36)

local playerState: any = nil
local stormState: any = { Phase = "Calm", EndsAt = 0 }
local boostEndsAt = 0

---------------------------------------------------------------------------- UI helpers

local function new(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = props.Parent
	props.Parent = nil
	for k, v in props do
		(inst :: any)[k] = v
	end
	for _, child in (children or {}) :: { Instance } do
		child.Parent = inst
	end
	inst.Parent = parent
	return inst
end

local function corner(radius: number?)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

local function stroke(color: Color3?, thickness: number?)
	return new("UIStroke", {
		Color = color or Color3.new(0, 0, 0),
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function label(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or WHITE
	props.TextScaled = if props.TextScaled == nil then true else props.TextScaled
	local l = new("TextLabel", props)
	new("UIStroke", { Parent = l, Thickness = 1.5, Color = Color3.new(0, 0, 0), Transparency = 0.3 })
	return l
end

local function button(props: { [string]: any }): TextButton
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or WHITE
	props.TextScaled = true
	props.AutoButtonColor = true
	local b = new("TextButton", props, { corner(8), stroke(Color3.new(0, 0, 0), 2) })
	new("UIPadding", {
		Parent = b,
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
	})
	return b
end

---------------------------------------------------------------------------- Sound

local sounds: { [string]: Sound } = {}
for name, info in Config.Sounds do
	if info.Id ~= "" then
		sounds[name] =
			new("Sound", { Name = name, SoundId = info.Id, Volume = info.Volume, Parent = SoundService })
	end
end
for _, name in { "Rain", "Flood", "Wind" } do
	if sounds[name] then
		sounds[name].Looped = true
	end
end

local function playSound(name: string, volumeScale: number?)
	local sound = sounds[name]
	if sound then
		sound.Volume = Config.Sounds[name].Volume * (volumeScale or 1)
		sound.TimePosition = 0
		sound:Play()
	end
end

-- Fades a looping ambience in or out without restarting it every frame.
local function setAmbience(name: string, on: boolean)
	local sound = sounds[name]
	if not sound then
		return
	end
	local target = on and Config.Sounds[name].Volume or 0
	if sound:GetAttribute("Target") == target then
		return
	end
	sound:SetAttribute("Target", target)
	if on and not sound.IsPlaying then
		sound.Volume = 0
		sound:Play()
	end
	local tween = TweenService:Create(sound, TweenInfo.new(2.5), { Volume = target })
	tween:Play()
	if not on then
		tween.Completed:Once(function()
			if sound:GetAttribute("Target") == 0 then
				sound:Stop()
			end
		end)
	end
end

---------------------------------------------------------------------------- HUD

local gui = new(
	"ScreenGui",
	{ Name = "HUD", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = playerGui }
)

-- Everything hangs off one root frame scaled to the screen height, so the HUD shrinks on
-- phones (~370px tall in landscape) instead of covering a third of the view. The root is
-- sized 1/scale so that after scaling it still fills the screen.
local hudRoot =
	new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
local rootScale = new("UIScale", { Parent = hudRoot })
local function fitHud()
	local camera = workspace.CurrentCamera
	local scale = camera and math.clamp(camera.ViewportSize.Y / 560, 0.62, 1) or 1
	rootScale.Scale = scale
	hudRoot.Size = UDim2.fromScale(1 / scale, 1 / scale)
end
fitHud()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitHud)

-- Storm banner (top centre)
local banner = new("Frame", {
	Name = "Banner",
	Parent = hudRoot,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.new(0.42, 0, 0, 62),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.2,
}, {
	corner(12),
	stroke(),
	new("UISizeConstraint", { MaxSize = Vector2.new(440, 62), MinSize = Vector2.new(220, 50) }),
})
local bannerTitle = label({
	Parent = banner,
	Size = UDim2.new(1, -16, 0.55, 0),
	Position = UDim2.new(0, 8, 0, 4),
	Text = "CALM",
})
local bannerSub = label({
	Parent = banner,
	Size = UDim2.new(1, -16, 0.35, 0),
	Position = UDim2.new(0, 8, 0.6, -2),
	Text = "",
	TextColor3 = Color3.fromRGB(200, 200, 210),
})

-- Stats strip directly under the banner (top-left belongs to Roblox chat, top-right to the player list)
local stats = new("Frame", {
	Name = "Stats",
	Parent = hudRoot,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 76),
	Size = UDim2.new(0.42, 0, 0, 58),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.25,
}, {
	corner(12),
	stroke(),
	new("UISizeConstraint", { MaxSize = Vector2.new(440, 58), MinSize = Vector2.new(260, 58) }),
})
local coinsLabel: TextLabel = label({
	Name = "Coins",
	Parent = stats,
	Position = UDim2.new(0, 12, 0, 6),
	Size = UDim2.new(0.4, -12, 0, 30),
	Text = "0",
	TextColor3 = Color3.fromRGB(255, 215, 80),
	TextXAlignment = Enum.TextXAlignment.Left,
})
local bagLabel = label({
	Name = "Bag",
	Parent = stats,
	Position = UDim2.new(0.4, 6, 0, 6),
	Size = UDim2.new(0.6, -18, 0, 22),
	Text = "Bag 0/3",
	TextXAlignment = Enum.TextXAlignment.Left,
})
local bagBarBack = new("Frame", {
	Name = "BagBar",
	Parent = stats,
	Position = UDim2.new(0.4, 6, 0, 32),
	Size = UDim2.new(0.6, -18, 0, 10),
	BackgroundColor3 = Color3.fromRGB(50, 55, 65),
}, { corner(5) })
local bagBar = new("Frame", {
	Name = "Fill",
	Parent = bagBarBack,
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Color3.fromRGB(90, 220, 110),
}, { corner(5) })
local bagValue = label({
	Name = "BagValue",
	Parent = stats,
	Position = UDim2.new(0, 12, 0, 36),
	Size = UDim2.new(0.4, -12, 0, 16),
	Text = "",
	TextColor3 = Color3.fromRGB(170, 230, 180),
	TextXAlignment = Enum.TextXAlignment.Left,
})

local coinsScale = new("UIScale", { Parent = coinsLabel })
local function popCoins(amount: number)
	coinsScale.Scale = 1.25
	TweenService
		:Create(
			coinsScale,
			TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		)
		:Play()
	local gain = label({
		Parent = stats,
		Position = UDim2.new(0, 12, 0, 40),
		Size = UDim2.new(0.4, -12, 0, 24),
		Text = ("+%d"):format(amount),
		TextColor3 = Color3.fromRGB(255, 225, 90),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5,
	})
	TweenService:Create(
		gain,
		TweenInfo.new(0.9, Enum.EasingStyle.Quad),
		{ Position = UDim2.new(0, 12, 0, -10), TextTransparency = 1 }
	):Play()
	Debris:AddItem(gain, 1)
end

local boostLabel = label({
	Name = "Boost",
	Parent = hudRoot,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 138),
	Size = UDim2.new(0, 220, 0, 24),
	Text = "",
	TextColor3 = Color3.fromRGB(255, 220, 90),
	Visible = false,
})

-- Shop button (right)
local shopButton = button({
	Name = "ShopButton",
	Parent = hudRoot,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -10, 0.45, 0),
	Size = UDim2.new(0, 150, 0, 64), -- ~44px tall after the HUD scale on small phones
	BackgroundColor3 = Color3.fromRGB(60, 120, 200),
	Text = "UPGRADES",
})

-- Toasts (bottom centre)
local toastHolder = new("Frame", {
	Name = "Toasts",
	Parent = hudRoot,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0.78, 0),
	Size = UDim2.new(0.6, 0, 0, 150),
	BackgroundTransparency = 1,
	ZIndex = 10, -- above the shop so "Need X more coins" is readable while it's open
}, {
	new("UIListLayout", {
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})
local toastCount = 0

local function toast(text: string, color: Color3?)
	toastCount += 1
	local l = label({
		Parent = toastHolder,
		Size = UDim2.new(1, 0, 0, 30),
		Text = text,
		TextColor3 = color or WHITE,
		LayoutOrder = toastCount,
	})
	task.delay(3, function()
		TweenService:Create(l, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		local s = l:FindFirstChildOfClass("UIStroke")
		if s then
			TweenService:Create(s, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		end
		task.wait(0.5)
		l:Destroy()
	end)
	local children = toastHolder:GetChildren()
	if #children > 6 then
		for _, c in children do
			if c:IsA("TextLabel") and c.LayoutOrder <= toastCount - 5 then
				c:Destroy()
			end
		end
	end
end

-- Tutorial hint
local hint = label({
	Name = "Hint",
	Parent = hudRoot,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -96),
	Size = UDim2.new(0.7, 0, 0, 34),
	Text = "",
	TextColor3 = Color3.fromRGB(255, 240, 150),
	Visible = false,
})

local function updateHint()
	if not playerState then
		return
	end
	local s = playerState
	if s.Stats.ItemsSold > 0 then
		hint.Visible = false
	elseif #s.Carried == 0 then
		hint.Text = "Head down into town and grab glowing salvage!"
		hint.Visible = true
	else
		hint.Text = "Bring your salvage back to SELL HERE at the Scrapyard"
		hint.Visible = true
	end
end

---------------------------------------------------------------------------- Shop

local shop = new("Frame", {
	Name = "Shop",
	Parent = hudRoot,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.9, 0.75),
	BackgroundColor3 = PANEL,
	Visible = false,
}, {
	corner(16),
	stroke(Color3.new(0, 0, 0), 3),
	new("UISizeConstraint", { MaxSize = Vector2.new(520, 380) }),
})
label({
	Parent = shop,
	Position = UDim2.new(0, 16, 0, 10),
	Size = UDim2.new(1, -80, 0, 40),
	Text = "GEAR SHOP",
	TextXAlignment = Enum.TextXAlignment.Left,
})
local closeButton = button({
	Name = "Close",
	Parent = shop,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 10),
	Size = UDim2.new(0, 40, 0, 40),
	BackgroundColor3 = Color3.fromRGB(200, 60, 60),
	Text = "X",
})
local list = new("ScrollingFrame", {
	Name = "List",
	Parent = shop,
	Position = UDim2.new(0, 10, 0, 60),
	Size = UDim2.new(1, -20, 1, -70),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
}, { new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

local function formatValue(id: string, value: any): string
	if id == "Backpack" then
		return ("%d slots"):format(value)
	elseif id == "Boots" then
		return ("%d speed"):format(value)
	elseif value == 0 then
		return "no protection"
	else
		return ("-%d%% damage"):format(math.floor(value * 100 + 0.5))
	end
end

local upgradeRows: { [string]: { Info: TextLabel, Buy: TextButton } } = {}

local function shopRow(
	name: string,
	order: number,
	title: string,
	desc: string,
	buttonColor: Color3
): (TextLabel, TextButton)
	local row = new("Frame", {
		Name = name,
		Parent = list,
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 84),
		BackgroundColor3 = Color3.fromRGB(40, 45, 58),
	}, { corner(10) })
	label({
		Parent = row,
		Position = UDim2.new(0, 12, 0, 6),
		Size = UDim2.new(0.62, -12, 0, 28),
		Text = title,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	label({
		Parent = row,
		Position = UDim2.new(0, 12, 0, 36),
		Size = UDim2.new(0.62, -12, 0, 18),
		Text = desc,
		TextColor3 = Color3.fromRGB(190, 190, 200),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamMedium,
	})
	local sub = label({
		Parent = row,
		Name = "Sub",
		Position = UDim2.new(0, 12, 0, 56),
		Size = UDim2.new(0.62, -12, 0, 18),
		Text = "",
		TextColor3 = Color3.fromRGB(140, 220, 160),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamMedium,
	})
	local buy = button({
		Name = "Buy",
		Parent = row,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0.34, 0, 0, 52),
		BackgroundColor3 = buttonColor,
		Text = "",
	})
	return sub, buy
end

for i, id in Config.UpgradeOrder do
	local def = Config.Upgrades[id]
	local sub, buy = shopRow(id, i, def.DisplayName, def.Description, Color3.fromRGB(60, 170, 80))
	upgradeRows[id] = { Info = sub, Buy = buy }
	buy.Activated:Connect(function()
		Remotes.get("BuyUpgrade"):FireServer(id)
	end)
end

-- Robux items only show once their IDs are configured.
local order = 100
for _, pass in Config.GamePasses do
	if pass.Id ~= 0 then
		order += 1
		local _, buy =
			shopRow(pass.DisplayName, order, pass.DisplayName, pass.Description, Color3.fromRGB(40, 170, 90))
		buy.Text = "R$ Pass"
		buy.Activated:Connect(function()
			if playerState and not playerState.CanSave then
				toast(
					"Purchases are paused: your progress can't be saved right now.",
					Color3.fromRGB(255, 120, 90)
				)
				return
			end
			MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		end)
	end
end
for _, product in Config.DevProducts do
	if product.Id ~= 0 then
		order += 1
		local _, buy = shopRow(
			product.DisplayName,
			order,
			product.DisplayName,
			"One-time purchase",
			Color3.fromRGB(40, 170, 90)
		)
		buy.Text = "R$ Buy"
		buy.Activated:Connect(function()
			if playerState and not playerState.CanSave then
				toast(
					"Purchases are paused: your progress can't be saved right now.",
					Color3.fromRGB(255, 120, 90)
				)
				return
			end
			MarketplaceService:PromptProductPurchase(player, product.Id)
		end)
	end
end

local function refreshShop()
	if not playerState then
		return
	end
	for id, row in upgradeRows do
		local def = Config.Upgrades[id]
		local level = playerState.Upgrades[id] or 0
		local cost = def.Costs[level + 1]
		if cost then
			row.Info.Text = ("Lv %d: %s  ->  %s"):format(
				level,
				formatValue(id, def.Values[level + 1]),
				formatValue(id, def.Values[level + 2])
			)
			row.Buy.Text = ("%d coins"):format(cost)
			row.Buy.BackgroundColor3 = playerState.Coins >= cost and Color3.fromRGB(60, 170, 80)
				or Color3.fromRGB(90, 90, 100)
		else
			row.Info.Text = ("Lv %d: %s  (MAX)"):format(level, formatValue(id, def.Values[level + 1]))
			row.Buy.Text = "MAXED"
			row.Buy.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
		end
	end
end

local function setShopOpen(open: boolean)
	shop.Visible = open
	if open then
		refreshShop()
	end
end

shopButton.Activated:Connect(function()
	setShopOpen(not shop.Visible)
end)
closeButton.Activated:Connect(function()
	setShopOpen(false)
end)
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "UpgradePrompt" then
		setShopOpen(true)
	end
end)

---------------------------------------------------------------------------- State handlers

local function render()
	local s = playerState
	if not s then
		return
	end
	coinsLabel.Text = ("%s coins"):format(tostring(s.Coins))
	local carried = #s.Carried
	bagLabel.Text = ("Bag %d/%d"):format(carried, s.Capacity)
	local fill = math.clamp(carried / math.max(1, s.Capacity), 0, 1)
	TweenService:Create(bagBar, TweenInfo.new(0.2), { Size = UDim2.fromScale(fill, 1) }):Play()
	bagBar.BackgroundColor3 = fill >= 1 and Color3.fromRGB(240, 90, 70) or Color3.fromRGB(90, 220, 110)
	bagValue.Text = carried > 0 and ("Worth %d coins"):format(s.CarriedValue) or "Empty"
	if shop.Visible then
		refreshShop()
	end
	updateHint()
end

local lastCarried = 0
local lastCoins: number? = nil
local lastLevels = 0
Remotes.get("PlayerState").OnClientEvent:Connect(function(s)
	playerState = s
	boostEndsAt = os.clock() + (s.BoostRemaining or 0)
	if #s.Carried > lastCarried then
		local id = s.Carried[#s.Carried]
		local def = Config.Loot[id]
		if def then
			toast(("+ %s (%d)"):format(def.Name, def.Value), Config.RarityColors[def.Rarity])
			-- Rarer finds sound brighter.
			local rank = ({ Common = 0, Uncommon = 1, Rare = 2, Epic = 3, Legendary = 4 })[def.Rarity] or 0
			playSound("Pickup")
			if rank >= 2 then
				playSound("Sell", 0.5 + rank * 0.1)
			end
		end
	end
	local levels = 0
	for _, level in s.Upgrades do
		levels += level
	end
	if lastCoins and s.Coins > lastCoins then
		popCoins(s.Coins - lastCoins)
		if #s.Carried < lastCarried then
			playSound("Sell")
		end
	end
	if lastCoins and levels > lastLevels then
		playSound("Upgrade")
	end
	lastCarried = #s.Carried
	lastCoins = s.Coins
	lastLevels = levels
	render()
end)

Remotes.get("Notify").OnClientEvent:Connect(function(text, color)
	toast(text, color)
end)

Remotes.get("StormState").OnClientEvent:Connect(function(s)
	local previous = stormState.Phase
	stormState = s
	if s.Phase == "Warning" and previous ~= "Warning" then
		local info = Config.Storms[s.Storm]
		toast(("%s INCOMING! %s"):format(info.DisplayName, info.Hint), info.Color)
		playSound("Siren")
	elseif s.Phase ~= "Warning" and sounds.Siren and sounds.Siren.IsPlaying then
		TweenService:Create(sounds.Siren, TweenInfo.new(2), { Volume = 0 }):Play()
	end
	local storming = s.Phase == "Storm"
	setAmbience("Rain", storming and (s.Storm == "Flood" or s.Storm == "Lightning"))
	setAmbience("Flood", storming and s.Storm == "Flood")
	setAmbience("Wind", storming and s.Storm == "Wind")
end)

---------------------------------------------------------------------------- Lightning warnings

local effects = new("Folder", { Name = "ClientEffects", Parent = workspace })
-- Client-only grade for lightning flashes, separate from the server's storm grade.
local flash = new("ColorCorrectionEffect", { Name = "LightningFlash", Parent = Lighting })

local function lightningFlash(position: Vector3)
	local camera = workspace.CurrentCamera
	if not camera or (camera.CFrame.Position - position).Magnitude > 220 then
		return
	end
	local distance = (camera.CFrame.Position - position).Magnitude
	local closeness = 1 - distance / 220
	flash.Brightness = 0.35 * closeness
	TweenService
		:Create(
			flash,
			TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Brightness = 0 }
		)
		:Play()
	-- Thunder arrives a beat after the flash, quieter with distance.
	task.delay(distance / 400, playSound, "Thunder", 0.4 + closeness * 0.6)
end

Remotes.get("LightningWarning").OnClientEvent
	:Connect(function(position: Vector3, radius: number, delay: number)
		local disc = new("Part", {
			Parent = effects,
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, 1, 1),
			CFrame = CFrame.new(position + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 230, 80),
			Transparency = 0.35,
		})
		TweenService:Create(disc, TweenInfo.new(delay, Enum.EasingStyle.Linear), {
			Size = Vector3.new(0.2, radius * 2, radius * 2),
			Color = Color3.fromRGB(255, 60, 40),
		}):Play()
		Debris:AddItem(disc, delay + 0.1)
		task.delay(delay, lightningFlash, position)
	end)

---------------------------------------------------------------------------- Weather: rain + wind push

local rainAnchor = new("Part", {
	Parent = effects,
	Anchored = true,
	CanCollide = false,
	CanQuery = false,
	Transparency = 1,
	Size = Vector3.new(90, 1, 90),
})
local rain = new("ParticleEmitter", {
	Parent = rainAnchor,
	Enabled = false,
	Rate = 600,
	Lifetime = NumberRange.new(0.8, 1.2),
	Speed = NumberRange.new(70, 90),
	EmissionDirection = Enum.NormalId.Bottom,
	Size = NumberSequence.new(0.18),
	Squash = NumberSequence.new(2.5), -- stretch into streaks
	Color = ColorSequence.new(Color3.fromRGB(190, 210, 235)),
	Transparency = NumberSequence.new(0.2),
	Orientation = Enum.ParticleOrientation.VelocityParallel,
	LightEmission = 0.3,
})

-- Wind streaks blow past the camera from upwind during windstorms.
local windAnchor = new("Part", {
	Parent = effects,
	Anchored = true,
	CanCollide = false,
	CanQuery = false,
	Transparency = 1,
	Size = Vector3.new(120, 40, 1),
})
local windStreaks = new("ParticleEmitter", {
	Parent = windAnchor,
	Enabled = false,
	Rate = 160,
	Lifetime = NumberRange.new(1, 1.4),
	Speed = NumberRange.new(90, 120),
	EmissionDirection = Enum.NormalId.Front,
	Size = NumberSequence.new(0.14),
	Squash = NumberSequence.new(3),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.5),
		NumberSequenceKeypoint.new(0.8, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	}),
	Color = ColorSequence.new(Color3.fromRGB(225, 220, 205)),
	Orientation = Enum.ParticleOrientation.VelocityParallel,
	LightEmission = 0.1,
})

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

local windForce: VectorForce? = nil
local function getWindForce(): VectorForce?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	if windForce and windForce.Parent == root then
		return windForce
	end
	local attachment = root:FindFirstChild("RootAttachment") or new("Attachment", { Parent = root })
	windForce = new("VectorForce", {
		Parent = root,
		Attachment0 = attachment,
		RelativeTo = Enum.ActuatorRelativeTo.World,
		ApplyAtCenterOfMass = true,
		Enabled = false,
	})
	return windForce
end

local function inSafeZone(position: Vector3): boolean
	return position.Z < Config.SafeZoneMaxZ and position.Y > 20
end

local shelterCheckAt = 0
local sheltered = false

RunService.RenderStepped:Connect(function()
	local now = workspace:GetServerTimeNow()
	local remaining = math.max(0, math.ceil(stormState.EndsAt - now))
	local phase = stormState.Phase
	local storm = stormState.Storm and Config.Storms[stormState.Storm]

	if phase == "Calm" then
		bannerTitle.Text = "CALM SKIES"
		bannerTitle.TextColor3 = Color3.fromRGB(150, 230, 160)
		bannerSub.Text = ("Next storm in %ds"):format(remaining)
	elseif phase == "Warning" and storm then
		bannerTitle.Text = storm.DisplayName .. " INCOMING"
		bannerTitle.TextColor3 = storm.Color
		bannerSub.Text = ("%s  %ds"):format(storm.Hint, remaining)
	elseif phase == "Storm" and storm then
		bannerTitle.Text = storm.DisplayName
		bannerTitle.TextColor3 = (os.clock() % 0.6 < 0.3) and storm.Color or WHITE
		bannerSub.Text = ("Survive in town for a bonus!  %ds"):format(remaining)
	elseif phase == "Aftermath" then
		bannerTitle.Text = "STORM PASSED"
		bannerTitle.TextColor3 = Color3.fromRGB(255, 220, 90)
		bannerSub.Text = ("Fresh salvage everywhere!  %ds"):format(remaining)
	end

	local boostLeft = boostEndsAt - os.clock()
	boostLabel.Visible = boostLeft > 0
	if boostLeft > 0 then
		local secs = math.floor(boostLeft)
		boostLabel.Text = ("2x SALVAGE  %d:%02d"):format(secs // 60, secs % 60)
	end

	local camera = workspace.CurrentCamera
	local stormActive = phase == "Storm"
	rain.Enabled = stormActive and (stormState.Storm == "Flood" or stormState.Storm == "Lightning")
	windStreaks.Enabled = stormActive and stormState.Storm == "Wind"
	if camera then
		local camPos = camera.CFrame.Position
		rainAnchor.CFrame = CFrame.new(camPos + Vector3.new(0, 40, 0))
		if windStreaks.Enabled then
			local dir = stormState.WindDir
			windAnchor.CFrame =
				CFrame.lookAt(camPos - dir * 60 + Vector3.new(0, 4, 0), camPos + Vector3.new(0, 4, 0))
		end
		animateLoot(camPos)
	end

	local force = getWindForce()
	if force then
		local root = force.Parent :: BasePart
		if os.clock() > shelterCheckAt then
			shelterCheckAt = os.clock() + 0.25
			sheltered = Shelter.isSheltered(root.Position) or inSafeZone(root.Position)
		end
		local windy = stormActive and stormState.Storm == "Wind" and not sheltered
		force.Enabled = windy
		if windy then
			force.Force = stormState.WindDir * root.AssemblyMass * Config.StormTuning.WindPush
		end
	end
end)
