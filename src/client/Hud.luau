-- @file Always-on HUD
-- @domain ui
-- @status wip
-- @see [[V4-HUD]]
-- The always-on gameplay HUD, V4 "Storm-Scarred Arcade" (docs/art/v4/HUD.md): restrained dark
-- industrial plates at the edges so the middle of the screen stays on the twister, the debris
-- warnings, the extraction route and other players.
--   top centre    one objective strip (EventStrip): the most important thing right now
--   top left      where you are (district chip)
--   top right     wallet (gold) and your band; under it Shop / Jobs / Settings
--   bottom left   the salvage bag (slots by rarity, what it sells for) and your health
--   bottom right  dodge and sprint (keyboard and gamepad; touch has its own buttons) beside the
--                 detector radar (DetectorHud)
-- Cards, notices and the objective note live in Notifications. Values come from the server.
--
-- Two compositions: desktop, and compact for phones. Compact keeps everything out of the left
-- 40% of the bottom two thirds (Roblox's dynamic thumbstick) and the jump button corner: the bag
-- and health move to the top left. In Studio, ReplicatedStorage attribute QA_PhoneFrame previews
-- the compact layout inside an 844 x 390 pt phone frame with those control zones drawn in.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Bands = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Bands"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local EventStrip = require(script.Parent:WaitForChild("EventStrip"))
local UI = require(script.Parent:WaitForChild("UI"))
local BigMoney = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BigMoney"))

local Hud = {}
local A = UI.Arcade

local screen: Frame -- the device screen (the whole GUI, or the Studio phone frame)
local screenScale: UIScale
local root: Frame -- design space inside the screen, scaled by rootScale
local rootScale: UIScale
local topStack: Frame
local phoneChrome: Frame? = nil

-- Wallet (top right) and bag + health (bottom left).
local cluster: Frame -- the bag panel
local cashTag: Frame
local cashLabel: TextLabel
local cashScale: UIScale
local bandLabel: TextLabel
local crate: Frame
local crateCount: TextLabel
local crateWorth: TextLabel
local crateSlots: Frame
local crateScale: UIScale
local healthFill: Frame
local healthText: TextLabel
local boostSticker: Frame
local boostLabel: TextLabel
local location: Frame
local locationLabel: TextLabel
local controls: Frame
local dodgeRing: Frame
local dodgeKey: TextLabel
local sprintChip: Frame

-- Right rail.
local rail: Frame

Hud.ShopButton = nil :: TextButton?
Hud.SettingsButton = nil :: TextButton?
Hud.JobsButton = nil :: TextButton?

local layoutListeners: { (compact: boolean) -> () } = {}
local compact = false
local laidOut = false
local lastPlayer: any = nil
local slotKey = ""

-- Called with `compact` whenever the composition changes (Notifications and Shop follow it).
function Hud.onLayout(fn: (compact: boolean) -> ())
	table.insert(layoutListeners, fn)
	fn(compact)
end

function Hud.isCompact(): boolean
	return compact
end

---------------------------------------------------------------------------- Wallet, bag, health

local function buildCluster()
	-- Wallet: top right, gold.
	cashTag = UI.arcadePlate({
		Name = "Wallet",
		Parent = root,
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(200, 50),
	})
	cashScale = UI.new("UIScale", { Parent = cashTag })
	local coin = UI.coinIcon(cashTag, 28)
	coin.AnchorPoint = Vector2.new(0, 0.5)
	coin.Position = UDim2.new(0, 12, 0.5, 0)
	coin.ZIndex = 2
	cashLabel = UI.text({
		Name = "Amount",
		Parent = cashTag,
		FontFace = UI.Heading,
		TextSize = 30,
		Position = UDim2.fromOffset(48, 0),
		Size = UDim2.new(1, -58, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = A.Gold,
		Text = "0",
		ZIndex = 2,
	})
	bandLabel = UI.text({
		Name = "Band",
		Parent = cashTag,
		FontFace = UI.Heading,
		TextSize = 13,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -2, 1, 4),
		Size = UDim2.fromOffset(200, 16),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = A.Amber,
		Text = "",
	})

	-- Bag and health: bottom left (top left on phones).
	cluster = UI.new("Frame", {
		Name = "BagPanel",
		Parent = root,
		Size = UDim2.fromOffset(260, 104),
		BackgroundTransparency = 1,
	})
	crate = UI.arcadePlate({
		Name = "Bag",
		Parent = cluster,
		Size = UDim2.new(1, 0, 0, 78),
	})
	crateScale = UI.new("UIScale", { Parent = crate })
	local bag = UI.bagIcon(crate, 34, A.Amber)
	bag.Position = UDim2.fromOffset(12, 10)
	UI.text({
		Name = "Caption",
		Parent = crate,
		FontFace = UI.Heading,
		TextSize = 12,
		Position = UDim2.fromOffset(56, 6),
		Size = UDim2.fromOffset(110, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = A.Dim,
		Text = "SALVAGE BAG",
	})
	crateCount = UI.text({
		Name = "Count",
		Parent = crate,
		FontFace = UI.Heading,
		TextSize = 26,
		Position = UDim2.fromOffset(56, 18),
		Size = UDim2.fromOffset(110, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = A.Text,
		Text = "0 / 0",
	})
	crateWorth = UI.text({
		Name = "Worth",
		Parent = crate,
		FontFace = UI.Heading,
		TextSize = 15,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(100, 36),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextColor3 = A.Gold,
		Text = "",
	})
	crateSlots = UI.new("Frame", {
		Name = "Slots",
		Parent = crate,
		Position = UDim2.fromOffset(12, 52),
		Size = UDim2.new(1, -24, 0, 16),
		BackgroundTransparency = 1,
	})
	local health = UI.arcadePlate({
		Name = "Health",
		Parent = cluster,
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(1, 0, 0, 20),
	})
	local cross = UI.new("Frame", {
		Parent = health,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(12, 12),
		BackgroundTransparency = 1,
	})
	UI.new("Frame", {
		Parent = cross,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = A.Hurt,
		BorderSizePixel = 0,
	})
	UI.new("Frame", {
		Parent = cross,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 4, 1, 0),
		BackgroundColor3 = A.Hurt,
		BorderSizePixel = 0,
	})
	local back = UI.new("Frame", {
		Parent = health,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 28, 0.5, 0),
		Size = UDim2.new(1, -96, 0, 8),
		BackgroundColor3 = A.Plate2,
		BorderSizePixel = 0,
	}, { UI.corner(4) })
	healthFill = UI.new("Frame", {
		Parent = back,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = A.Health,
		BorderSizePixel = 0,
	}, { UI.corner(4) })
	healthText = UI.text({
		Parent = health,
		FontFace = UI.Heading,
		TextSize = 13,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(60, 16),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = A.Text,
		Text = "100 / 100",
	})

	-- 2x Salvage: a gold sticker on the wallet.
	boostSticker = UI.new("Frame", {
		Name = "Boost",
		Parent = cashTag,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(0, -6, 0.5, 0),
		Size = UDim2.fromOffset(72, 28),
		BackgroundColor3 = A.Amber,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 6,
	}, { UI.corner(14) })
	boostLabel = UI.text({
		Parent = boostSticker,
		FontFace = UI.Heading,
		TextSize = 14,
		Size = UDim2.fromScale(1, 1),
		TextColor3 = A.Plate,
		Text = "",
		ZIndex = 7,
	})

	-- Where you are: top left.
	location = UI.arcadePlate({
		Name = "Location",
		Parent = root,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 28),
	})
	UI.padding(0, 12, 0, 10).Parent = location
	UI.new("UIListLayout", {
		Parent = location,
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
	})
	UI.new("Frame", {
		Name = "Dot",
		Parent = location,
		Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = A.Amber,
		BorderSizePixel = 0,
	}, { UI.corner(4) })
	locationLabel = UI.text({
		Parent = location,
		FontFace = UI.Heading,
		TextSize = 15,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 28),
		TextColor3 = A.Text,
		Text = "GALE HOLLOW",
	})

	-- Dodge and sprint (keyboard / gamepad): bottom right, left of the radar.
	controls = UI.new("Frame", {
		Name = "Controls",
		Parent = root,
		AnchorPoint = Vector2.new(1, 1),
		Size = UDim2.fromOffset(150, 64),
		BackgroundTransparency = 1,
	})
	local dodge = UI.arcadePlate({
		Name = "Dodge",
		Parent = controls,
		Size = UDim2.fromOffset(64, 64),
	})
	UI.new("UICorner", { Parent = dodge, CornerRadius = UDim.new(0.5, 0) })
	dodgeRing = UI.new("Frame", {
		Name = "Ring",
		Parent = dodge,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -6, 1, -6),
		BackgroundTransparency = 1,
	}, { UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), UI.stroke(A.Amber, 3) })
	dodgeKey = UI.text({
		Parent = dodge,
		FontFace = UI.Heading,
		TextSize = 22,
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 26),
		TextColor3 = A.Text,
		Text = "Q",
	})
	UI.text({
		Parent = dodge,
		FontFace = UI.Heading,
		TextSize = 11,
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 14),
		TextColor3 = A.Dim,
		Text = "DODGE",
	})
	sprintChip = UI.arcadePlate({
		Name = "Sprint",
		Parent = controls,
		Position = UDim2.fromOffset(72, 18),
		Size = UDim2.fromOffset(76, 30),
	})
	UI.text({
		Parent = sprintChip,
		FontFace = UI.Heading,
		TextSize = 13,
		Size = UDim2.fromScale(1, 1),
		TextColor3 = A.Text,
		Text = "SHIFT · SPRINT",
		TextScaled = false,
	})
end

-- The district you're in (Districts); nil for open town.
function Hud.setLocation(label: string?)
	locationLabel.Text = if label then ("GALE HOLLOW · %s"):format(string.upper(label)) else "GALE HOLLOW"
end

-- Per frame: the dodge cooldown ring and the sprint chip (Main passes both).
function Hud.stepControls(cooldownLeft: number, cooldown: number, sprinting: boolean)
	local ready = cooldownLeft <= 0
	local ring = dodgeRing:FindFirstChildOfClass("UIStroke") :: UIStroke
	ring.Color = if ready then A.Amber else A.Edge
	dodgeKey.Text = if ready then "Q" else ("%.1f"):format(cooldownLeft)
	dodgeKey.TextColor3 = if ready then A.Text else A.Dim
	ring.Transparency = if ready then 0 else 0.4 * (cooldownLeft / math.max(cooldown, 0.01))
	local stroke = sprintChip:FindFirstChildOfClass("UIStroke") :: UIStroke
	stroke.Color = if sprinting then A.Amber else A.Edge
end

local function bindHealth(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	local function refresh()
		local f = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
		healthFill.Size = UDim2.fromScale(f, 1)
		healthFill.BackgroundColor3 = if f < 0.35 then A.Hurt else A.Health
		healthText.Text = ("%d / %d"):format(math.ceil(humanoid.Health), humanoid.MaxHealth)
	end
	humanoid.HealthChanged:Connect(refresh)
	refresh()
end

---------------------------------------------------------------------------- Storm sign

local function buildSign()
	-- V4: the top centre holds one objective strip (EventStrip); the V3 swinging storm sign,
	-- its orders strip and the cores chip are gone (all three are strip entries now).
	topStack = UI.new("Frame", {
		Name = "TopStack",
		Parent = root,
		ZIndex = 25, -- storm info and danger alerts stay readable over the shop and settings
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		BackgroundTransparency = 1,
	}, {
		UI.new("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

-- Menus hide the strip's lower-priority entries themselves (EventStrip reads UI.modalOpen).
function Hud.setModalOpen(_open: boolean) end

local CALM_BAND = Color3.fromRGB(120, 200, 110)

-- The storm as one objective-strip entry. `status` is its live line ("Gust in 1.7s - get behind
-- a wall!") or nil; `cores` is how many Storm Cores are out in town.
function Hud.stepStorm(now: number, storm: any, status: string?, _statusColor: Color3?, cores: number)
	local phase = storm.Phase
	local info = storm.Storm and Config.Storms[storm.Storm]
	local danger = (phase == "Warning" or phase == "Storm") and info ~= nil
	local serverEnds = workspace:GetServerTimeNow() + (storm.EndsAt - now)
	if danger then
		local live = phase == "Storm" and status ~= nil
		EventStrip.set("storm", {
			Priority = if phase == "Storm" then 50 else 48,
			Title = if phase == "Warning"
				then (info :: any).DisplayName .. " coming"
				else (info :: any).DisplayName,
			Sub = if live then string.upper(status :: string) else (info :: any).Hint,
			Accent = (info :: any).Color,
			EndsAt = serverEnds,
			Pill = if phase == "Warning" then "STORM IN" else (info :: any).DisplayName,
		})
	else
		local after = phase == "Aftermath"
		EventStrip.set("storm", {
			Priority = if after then 25 else 20,
			Title = if after then "Storm passed" else "All clear",
			Sub = if after then "Calm in a moment. Go salvage." else "Salvage, sell, upgrade. Next storm in",
			Accent = if after then UI.Color.Coin else CALM_BAND,
			EndsAt = serverEnds,
			Pill = if after then "CALM IN" else "NEXT STORM",
		})
	end
	if cores > 0 and (phase == "Storm" or phase == "Aftermath") then
		EventStrip.set("cores", {
			Priority = 30,
			Title = ("%d Storm Core%s in town"):format(cores, if cores == 1 then "" else "s"),
			Sub = "Legendary loot out in the storm. Grab one and sell it.",
			Accent = Config.RarityColors.Legendary,
			Pill = ("%d CORE%s"):format(cores, if cores == 1 then "" else "S"),
		})
	else
		EventStrip.clear("cores")
	end
end

---------------------------------------------------------------------------- Right rail

local function buildRail()
	-- Shop / Jobs / Settings: dark square buttons in a row under the wallet.
	rail = UI.new("Frame", {
		Name = "Rail",
		Parent = root,
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(200, 60),
		BackgroundTransparency = 1,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local size = UI.buttonSize()
	local function button(name: string, order: number, label: string): TextButton
		local b = UI.new("TextButton", {
			Name = name,
			Parent = rail,
			LayoutOrder = order,
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = A.Plate,
			BackgroundTransparency = 0.08,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			Text = "",
		}, { UI.corner(8), UI.stroke(A.Edge, 1.5) })
		UI.text({
			Parent = b,
			FontFace = UI.Heading,
			TextSize = 11,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -3),
			Size = UDim2.new(1, 0, 0, 13),
			TextColor3 = A.Dim,
			Text = label,
		})
		local scale = UI.new("UIScale", { Parent = b })
		b.Activated:Connect(function()
			UI.pop(scale, 0.92, 0.2)
		end)
		b.MouseEnter:Connect(function()
			(b:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = A.Amber
		end)
		b.MouseLeave:Connect(function()
			(b:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = A.Edge
		end)
		return b
	end
	local shop = button("ShopButton", 1, "SHOP")
	local bag = UI.bagIcon(shop, math.floor(size * 0.46), A.Amber)
	bag.AnchorPoint = Vector2.new(0.5, 0)
	bag.Position = UDim2.new(0.5, 0, 0, 6)
	Hud.ShopButton = shop

	local jobs = button("JobsButton", 2, "JOBS")
	jobs.Visible = false -- shown after the first sale (staged discovery, Main)
	local clip = UI.new("Frame", {
		Parent = jobs,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 7),
		Size = UDim2.fromOffset(math.floor(size * 0.38), math.floor(size * 0.46)),
		BackgroundColor3 = A.Text,
		BorderSizePixel = 0,
	}, { UI.corner(3) })
	for k = 1, 3 do
		UI.new("Frame", {
			Parent = clip,
			Position = UDim2.new(0.18, 0, 0.2 + k * 0.18, 0),
			Size = UDim2.new(0.64, 0, 0, 2),
			BackgroundColor3 = A.Plate,
			BorderSizePixel = 0,
		})
	end
	Hud.JobsButton = jobs

	local settings = button("SettingsButton", 3, "MENU")
	local sliders = UI.slidersIcon(settings, math.floor(size * 0.42))
	sliders.AnchorPoint = Vector2.new(0.5, 0)
	sliders.Position = UDim2.new(0.5, 0, 0, 8)
	for _, d in sliders:GetDescendants() do
		if d:IsA("Frame") then
			d.BackgroundColor3 = A.Text
		end
	end
	Hud.SettingsButton = settings
end

---------------------------------------------------------------------------- Layout

local PHONE = Vector2.new(844, 390) -- iPhone landscape, points
local PHONE_TOPBAR = 36 -- approximate Roblox top bar height on a phone, points

local function drawPhoneChrome(on: boolean)
	if phoneChrome then
		phoneChrome:Destroy()
		phoneChrome = nil
	end
	if not on then
		return
	end
	local chrome = UI.new("Frame", {
		Name = "PhoneChrome",
		Parent = screen,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 200,
	})
	UI.new("Frame", {
		Parent = chrome,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 20, 1, 20),
		BackgroundTransparency = 1,
		ZIndex = 200,
	}, { UI.corner(40), UI.stroke(Color3.fromRGB(12, 12, 14), 10) })
	local function zone(name: string, pos: UDim2, size: UDim2, round: boolean)
		local z = UI.new("Frame", {
			Name = name,
			Parent = chrome,
			Position = pos,
			Size = size,
			BackgroundColor3 = Color3.fromRGB(255, 40, 40),
			BackgroundTransparency = 0.8,
			BorderSizePixel = 0,
			ZIndex = 200,
		}, { UI.stroke(Color3.fromRGB(255, 60, 60), 1.5) })
		if round then
			UI.new("UICorner", { Parent = z, CornerRadius = UDim.new(0.5, 0) })
		end
		UI.text({
			Parent = z,
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			Size = UDim2.new(1, 0, 0, 14),
			Position = UDim2.fromOffset(0, 4),
			TextColor3 = Color3.fromRGB(255, 220, 220),
			Text = name,
			ZIndex = 201,
		})
	end
	-- DynamicThumbstick start area: left 40%, bottom two thirds. TouchJump on a small screen:
	-- 70 pt, 95 pt from the right edge and 90 pt from the bottom.
	zone("THUMBSTICK ZONE", UDim2.fromScale(0, 1 / 3), UDim2.fromScale(0.4, 2 / 3), false)
	zone("JUMP", UDim2.new(1, -95, 1, -90), UDim2.fromOffset(70, 70), true)
	UI.new("Frame", {
		Name = "TopBar",
		Parent = chrome,
		Size = UDim2.new(1, 0, 0, PHONE_TOPBAR),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.75,
		BorderSizePixel = 0,
		ZIndex = 200,
	})
	UI.text({
		Parent = chrome,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 14),
		Size = UDim2.fromOffset(700, 16),
		TextColor3 = Color3.new(1, 1, 1),
		Text = "STUDIO PHONE PREVIEW · 844 × 390 pt · top bar and control zones approximate · not a device test",
		ZIndex = 201,
	})
	phoneChrome = chrome
end

local function fit()
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local phonePreview = RunService:IsStudio() and ReplicatedStorage:GetAttribute("QA_PhoneFrame") == true
	UI.setCompactOverride(phonePreview)
	local height
	if phonePreview then
		local k = math.min(viewport.X * 0.92 / PHONE.X, viewport.Y * 0.84 / PHONE.Y)
		screen.AnchorPoint = Vector2.new(0.5, 0.5)
		screen.Position = UDim2.fromScale(0.5, 0.5)
		screen.Size = UDim2.fromOffset(PHONE.X, PHONE.Y)
		screenScale.Scale = k
		height = PHONE.Y - PHONE_TOPBAR
		root.Position = UDim2.fromOffset(0, PHONE_TOPBAR)
	else
		screen.AnchorPoint = Vector2.zero
		screen.Position = UDim2.new()
		screen.Size = UDim2.fromScale(1, 1)
		screenScale.Scale = 1
		height = viewport.Y
		root.Position = UDim2.new()
	end
	-- Phones in landscape (about 340-400 pt tall) land on 0.7; laptops on 1-1.15.
	local scale = math.clamp(height / 600, 0.7, 1.15)
	rootScale.Scale = scale
	if phonePreview then
		root.Size = UDim2.fromOffset(PHONE.X / scale, height / scale)
	else
		root.Size = UDim2.fromScale(1 / scale, 1 / scale)
	end
	if (phoneChrome ~= nil) ~= phonePreview then
		drawPhoneChrome(phonePreview)
	end

	local wasCompact = compact
	compact = UI.compact()
	if compact then
		-- Phone: bag + health at the top left (the bottom left belongs to the thumbstick), the
		-- strip right of centre, wallet and buttons at the top right above the jump button.
		cluster.Position = UDim2.fromOffset(10, 8)
		cluster.Size = UDim2.fromOffset(230, 92)
		crate.Size = UDim2.new(1, 0, 0, 66)
		crateWorth.Visible = false
		crateSlots.Position = UDim2.fromOffset(12, 44)
		location.Visible = false
		controls.Visible = false
		cashTag.Position = UDim2.new(1, -10, 0, 8)
		cashTag.Size = UDim2.fromOffset(170, 44)
		cashLabel.TextSize = 26
		rail.Position = UDim2.new(1, -10, 0, 74)
		topStack.Position = UDim2.new(0.58, 0, 0, 4)
	else
		cluster.Position = UDim2.new(0, 14, 1, -118)
		cluster.Size = UDim2.fromOffset(260, 104)
		crate.Size = UDim2.new(1, 0, 0, 78)
		crateWorth.Visible = true
		crateSlots.Position = UDim2.fromOffset(12, 52)
		location.Visible = true
		location.Position = UDim2.fromOffset(14, 10)
		controls.Visible = not UI.isTouch()
		controls.Position = UDim2.new(1, -196, 1, -20)
		cashTag.Position = UDim2.new(1, -14, 0, 10)
		cashTag.Size = UDim2.fromOffset(200, 50)
		cashLabel.TextSize = 30
		rail.Position = UDim2.new(1, -14, 0, 84)
		topStack.Position = UDim2.new(0.5, 0, 0, 8)
	end
	if compact ~= wasCompact or not laidOut then
		laidOut = true
		for _, fn in layoutListeners do
			fn(compact)
		end
		if lastPlayer then
			slotKey = ""
			Hud.setPlayer(lastPlayer)
		end
	end
end

---------------------------------------------------------------------------- Player state

local shownCoins: string? = nil
local cancelCount: (() -> ())? = nil

-- "+120" drifting up under the wallet.
local function floatDelta(text: string, color: Color3)
	local at = (cashTag.AbsolutePosition - root.AbsolutePosition) / (rootScale.Scale * screenScale.Scale)
	local width = cashTag.AbsoluteSize.X / (rootScale.Scale * screenScale.Scale)
	local label = UI.text({
		Parent = root,
		FontFace = UI.Heading,
		TextSize = 24,
		Outline = true,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromOffset(at.X + width, at.Y + 70),
		Size = UDim2.fromOffset(160, 26),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = color,
		Text = text,
		ZIndex = 6,
	})
	local goal = label.Position - UDim2.fromOffset(0, if UI.reduced() then 0 else 22)
	UI.tween(label, 0.9, { Position = goal }, Enum.EasingStyle.Quad)
	task.delay(0.5, function()
		UI.tween(label, 0.4, { TextTransparency = 1 }, Enum.EasingStyle.Quad).Completed:Wait()
		label:Destroy()
	end)
end

-- Coins changed (exact BigMoney strings): count up to the new balance (gains) or drop straight to
-- it (spending). The count-up animation runs through plain numbers, so only while both values
-- have at most 15 digits (exact as numbers); bigger balances just pop to the exact new value.
local function showCoins(coins: string)
	if cancelCount then
		cancelCount()
		cancelCount = nil
	end
	local previous = shownCoins
	shownCoins = coins
	if previous == nil or coins == previous then
		cashLabel.Text = BigMoney.tag(coins)
		return
	end
	if BigMoney.cmp(coins, previous) > 0 then
		local gain = BigMoney.sub(coins, previous) :: string
		if #coins <= 15 then
			cancelCount = UI.countUp(
				cashLabel,
				tonumber(previous) :: number,
				tonumber(coins) :: number,
				if UI.reduced() then 0.01 else UI.Time.Count,
				BigMoney.tag
			)
		end
		cashLabel.Text = BigMoney.tag(if #coins <= 15 then previous else coins)
		task.delay(UI.Time.Count + 0.05, function()
			if shownCoins == coins then
				cashLabel.Text = BigMoney.tag(coins)
			end
		end)
		UI.pop(cashScale, 1.1, 0.35)
		task.spawn(floatDelta, "+" .. BigMoney.tag(gain), Color3.fromRGB(255, 214, 80))
	else
		cashLabel.Text = BigMoney.tag(coins)
		task.spawn(floatDelta, "-" .. BigMoney.tag(BigMoney.sub(previous, coins) :: string), UI.Color.TextDim)
	end
end

function Hud.setPlayer(s: any)
	lastPlayer = s
	showCoins(s.Coins)
	local carried = #s.Carried
	local full = carried >= s.Capacity
	crateCount.Text = ("%d / %d"):format(carried, s.Capacity)
	crateCount.TextColor3 = if full then A.Hurt else A.Text
	crateWorth.Text = if carried > 0 then ("SELLS FOR\n%s"):format(BigMoney.tag(s.CarriedValue)) else ""
	local band = tonumber(s.Band) or 1
	bandLabel.Text = if band > 1 then string.upper(Bands.Names[band] or "") else ""

	local key = table.concat(s.Carried, ",") .. "/" .. s.Capacity .. (if compact then "c" else "d")
	if key == slotKey then
		return
	end
	slotKey = key
	crateSlots:ClearAllChildren()
	UI.new("UIListLayout", {
		Parent = crateSlots,
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 3),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local width = crateSlots.AbsoluteSize.X / math.max(0.01, rootScale.Scale * screenScale.Scale)
	if width < 10 then
		width = if compact then 192 else 208
	end
	local slotW = math.clamp(math.floor((width - (s.Capacity - 1) * 3) / s.Capacity), 6, 34)
	local slotH = 14
	for i = 1, s.Capacity do
		local id = s.Carried[i]
		local def = id and Config.Loot[id]
		UI.new("Frame", {
			Name = "Slot" .. i,
			Parent = crateSlots,
			LayoutOrder = i,
			Size = UDim2.fromOffset(slotW, slotH),
			BackgroundColor3 = if def then Config.RarityColors[def.Rarity] else A.Plate2,
			BorderSizePixel = 0,
			ZIndex = 4,
		}, { UI.corner(3) })
	end
end

function Hud.pulseBag()
	UI.pop(crateScale, 1.06, 0.25)
end

function Hud.stepBoost(secondsLeft: number)
	boostSticker.Visible = secondsLeft > 0
	if secondsLeft > 0 then
		local secs = math.floor(secondsLeft)
		boostLabel.Text = ("2X %d:%02d"):format(secs // 60, secs % 60)
	end
end

---------------------------------------------------------------------------- Init

function Hud.init(gui: ScreenGui): (Frame, Frame)
	screen = UI.new("Frame", {
		Name = "Screen",
		Parent = gui,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	})
	screenScale = UI.new("UIScale", { Parent = screen })
	root = UI.new(
		"Frame",
		{ Name = "Root", Parent = screen, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }
	)
	rootScale = UI.new("UIScale", { Parent = root })
	buildCluster()
	buildSign()
	buildRail()
	fit()
	-- Our own health bar replaces Roblox's (bottom left, with the bag).
	pcall(function()
		game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)
	local player = game:GetService("Players").LocalPlayer
	if player.Character then
		task.spawn(bindHealth, player.Character)
	end
	player.CharacterAdded:Connect(bindHealth)
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	if RunService:IsStudio() then
		ReplicatedStorage:GetAttributeChangedSignal("QA_PhoneFrame"):Connect(fit)
	end
	return root, topStack
end

return Hud
