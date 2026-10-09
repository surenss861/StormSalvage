-- Storm Salvage client: HUD, upgrade shop, tutorial hints, storm visuals.

local Debris = game:GetService("Debris")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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
	return new("UIStroke", { Color = color or Color3.new(0, 0, 0), Thickness = thickness or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
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
	new("UIPadding", { Parent = b, PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) })
	return b
end

---------------------------------------------------------------------------- HUD

local gui = new("ScreenGui", { Name = "HUD", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = playerGui })

-- Storm banner (top centre)
local banner = new("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.new(0.42, 0, 0, 62),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.2,
}, { corner(12), stroke(), new("UISizeConstraint", { MaxSize = Vector2.new(440, 62), MinSize = Vector2.new(220, 50) }) })
local bannerTitle = label({ Parent = banner, Size = UDim2.new(1, -16, 0.55, 0), Position = UDim2.new(0, 8, 0, 4), Text = "CALM" })
local bannerSub = label({ Parent = banner, Size = UDim2.new(1, -16, 0.35, 0), Position = UDim2.new(0, 8, 0.6, -2), Text = "", TextColor3 = Color3.fromRGB(200, 200, 210) })

-- Stats (top left)
local stats = new("Frame", {
	Parent = gui,
	Position = UDim2.new(0, 10, 0, 76),
	Size = UDim2.new(0.22, 0, 0, 118),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.25,
}, { corner(12), stroke(), new("UISizeConstraint", { MaxSize = Vector2.new(250, 118), MinSize = Vector2.new(160, 118) }) })
local coinsLabel = label({ Parent = stats, Position = UDim2.new(0, 10, 0, 6), Size = UDim2.new(1, -20, 0, 34), Text = "0", TextColor3 = Color3.fromRGB(255, 215, 80), TextXAlignment = Enum.TextXAlignment.Left })
local bagLabel = label({ Parent = stats, Position = UDim2.new(0, 10, 0, 44), Size = UDim2.new(1, -20, 0, 22), Text = "Bag 0/3", TextXAlignment = Enum.TextXAlignment.Left })
local bagBarBack = new("Frame", { Parent = stats, Position = UDim2.new(0, 10, 0, 70), Size = UDim2.new(1, -20, 0, 10), BackgroundColor3 = Color3.fromRGB(50, 55, 65) }, { corner(5) })
local bagBar = new("Frame", { Parent = bagBarBack, Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(90, 220, 110) }, { corner(5) })
local bagValue = label({ Parent = stats, Position = UDim2.new(0, 10, 0, 86), Size = UDim2.new(1, -20, 0, 22), Text = "", TextColor3 = Color3.fromRGB(170, 230, 180), TextXAlignment = Enum.TextXAlignment.Left })

local boostLabel = label({ Parent = gui, Position = UDim2.new(0, 10, 0, 198), Size = UDim2.new(0, 220, 0, 24), Text = "", TextColor3 = Color3.fromRGB(255, 220, 90), TextXAlignment = Enum.TextXAlignment.Left, Visible = false })

-- Shop button (right)
local shopButton = button({
	Parent = gui,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -10, 0.45, 0),
	Size = UDim2.new(0, 120, 0, 48),
	BackgroundColor3 = Color3.fromRGB(60, 120, 200),
	Text = "UPGRADES",
})

-- Toasts (bottom centre)
local toastHolder = new("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0.78, 0),
	Size = UDim2.new(0.6, 0, 0, 150),
	BackgroundTransparency = 1,
}, {
	new("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local toastCount = 0

local function toast(text: string, color: Color3?)
	toastCount += 1
	local l = label({ Parent = toastHolder, Size = UDim2.new(1, 0, 0, 30), Text = text, TextColor3 = color or WHITE, LayoutOrder = toastCount })
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
	Parent = gui,
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
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.9, 0.75),
	BackgroundColor3 = PANEL,
	Visible = false,
}, { corner(16), stroke(Color3.new(0, 0, 0), 3), new("UISizeConstraint", { MaxSize = Vector2.new(520, 560) }) })
label({ Parent = shop, Position = UDim2.new(0, 16, 0, 10), Size = UDim2.new(1, -80, 0, 40), Text = "GEAR SHOP", TextXAlignment = Enum.TextXAlignment.Left })
local closeButton = button({ Parent = shop, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.new(0, 40, 0, 40), BackgroundColor3 = Color3.fromRGB(200, 60, 60), Text = "X" })
local list = new("ScrollingFrame", {
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
	else
		return ("-%d%% damage"):format(math.floor(value * 100 + 0.5))
	end
end

local upgradeRows: { [string]: { Info: TextLabel, Buy: TextButton } } = {}

local function shopRow(order: number, title: string, desc: string, buttonColor: Color3): (TextLabel, TextButton)
	local row = new("Frame", { Parent = list, LayoutOrder = order, Size = UDim2.new(1, -8, 0, 84), BackgroundColor3 = Color3.fromRGB(40, 45, 58) }, { corner(10) })
	label({ Parent = row, Position = UDim2.new(0, 12, 0, 6), Size = UDim2.new(0.62, -12, 0, 28), Text = title, TextXAlignment = Enum.TextXAlignment.Left })
	label({ Parent = row, Position = UDim2.new(0, 12, 0, 36), Size = UDim2.new(0.62, -12, 0, 18), Text = desc, TextColor3 = Color3.fromRGB(190, 190, 200), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamMedium })
	local sub = label({ Parent = row, Name = "Sub", Position = UDim2.new(0, 12, 0, 56), Size = UDim2.new(0.62, -12, 0, 18), Text = "", TextColor3 = Color3.fromRGB(140, 220, 160), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamMedium })
	local buy = button({ Parent = row, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0.34, 0, 0, 52), BackgroundColor3 = buttonColor, Text = "" })
	return sub, buy
end

for i, id in Config.UpgradeOrder do
	local def = Config.Upgrades[id]
	local sub, buy = shopRow(i, def.DisplayName, def.Description, Color3.fromRGB(60, 170, 80))
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
		local _, buy = shopRow(order, pass.DisplayName, pass.Description, Color3.fromRGB(40, 170, 90))
		buy.Text = "R$ Pass"
		buy.Activated:Connect(function()
			MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		end)
	end
end
for _, product in Config.DevProducts do
	if product.Id ~= 0 then
		order += 1
		local _, buy = shopRow(order, product.DisplayName, "One-time purchase", Color3.fromRGB(40, 170, 90))
		buy.Text = "R$ Buy"
		buy.Activated:Connect(function()
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
			row.Info.Text = ("Lv %d: %s  ->  %s"):format(level, formatValue(id, def.Values[level + 1]), formatValue(id, def.Values[level + 2]))
			row.Buy.Text = ("%d coins"):format(cost)
			row.Buy.BackgroundColor3 = playerState.Coins >= cost and Color3.fromRGB(60, 170, 80) or Color3.fromRGB(90, 90, 100)
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
Remotes.get("PlayerState").OnClientEvent:Connect(function(s)
	playerState = s
	boostEndsAt = os.clock() + (s.BoostRemaining or 0)
	if #s.Carried > lastCarried then
		local id = s.Carried[#s.Carried]
		local def = Config.Loot[id]
		if def then
			toast(("+ %s (%d)"):format(def.Name, def.Value), Config.RarityColors[def.Rarity])
		end
	end
	lastCarried = #s.Carried
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
	end
end)

---------------------------------------------------------------------------- Lightning warnings

local effects = new("Folder", { Name = "ClientEffects", Parent = workspace })

Remotes.get("LightningWarning").OnClientEvent:Connect(function(position: Vector3, radius: number, delay: number)
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
end)

---------------------------------------------------------------------------- Weather: rain + wind push

local rainAnchor = new("Part", { Parent = effects, Anchored = true, CanCollide = false, CanQuery = false, Transparency = 1, Size = Vector3.new(90, 1, 90) })
local rain = new("ParticleEmitter", {
	Parent = rainAnchor,
	Enabled = false,
	Rate = 600,
	Lifetime = NumberRange.new(0.8, 1.2),
	Speed = NumberRange.new(70, 90),
	EmissionDirection = Enum.NormalId.Bottom,
	Size = NumberSequence.new(0.12),
	Color = ColorSequence.new(Color3.fromRGB(180, 200, 230)),
	Transparency = NumberSequence.new(0.35),
	Orientation = Enum.ParticleOrientation.VelocityParallel,
	LightEmission = 0.2,
})

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
	if camera then
		rainAnchor.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 40, 0))
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
			force.Force = stormState.WindDir * root.AssemblyMass * 55
		end
	end
end)
