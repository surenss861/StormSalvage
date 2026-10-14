-- @file Always-on HUD
-- @domain ui
-- @status stable
-- @see [[V3-UI-WORKSHOP]]
-- The always-on HUD, built from objects in the salvage yard (docs/art/V3-UI-STUDIES.md):
--   cash tag      coins (top left)
--   crate         the bag: one slot per capacity, coloured by what's in it, and its sell value
--   storm sign    a tin sign at the top: storm type, countdown, and what to do right now
--   tool tag      the Gear Shop button, and a tin plate for Settings (right edge)
-- Everything else (cards, notices, alerts, the objective note) lives in Notifications.
-- Values shown here come from the server's player and storm state.
--
-- Two compositions: desktop, and compact for phones. Compact keeps the left side inside the top
-- third of the screen, because Roblox's dynamic thumbstick starts anywhere in the left 40% of
-- the bottom two thirds (PlayerModule DynamicThumbstick), and leaves the bottom right to the
-- jump button. In Studio, ReplicatedStorage attribute QA_PhoneFrame previews the compact layout
-- inside an 844 x 390 pt phone frame with those control zones drawn in.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UI = require(script.Parent:WaitForChild("UI"))
local BigMoney = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BigMoney"))

local Hud = {}
local M = UI.Mat

local screen: Frame -- the device screen (the whole GUI, or the Studio phone frame)
local screenScale: UIScale
local root: Frame -- design space inside the screen, scaled by rootScale
local rootScale: UIScale
local topStack: Frame
local phoneChrome: Frame? = nil

-- Left cluster.
local cluster: Frame
local cashTag: Frame
local cashLabel: TextLabel
local cashScale: UIScale
local crate: Frame
local crateCount: TextLabel
local crateLabel: Frame
local crateWorth: TextLabel
local crateSlots: Frame
local crateScale: UIScale
local boostSticker: Frame
local boostLabel: TextLabel

-- Storm sign.
local signHolder: Frame
local swing: Frame
local sign: Frame
local signStroke: UIStroke
local signBand: Frame
local signBandText: TextLabel
local signCaption: TextLabel
local tiles: { TextLabel } = {}
local tileFrames: { Frame } = {}
local orders: Frame
local orderLine: TextLabel
local orderLive: TextLabel
local orderWidth: UISizeConstraint
local coreChip: Frame
local coreLabel: TextLabel

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

---------------------------------------------------------------------------- Cash tag + crate

local function buildCluster()
	cluster = UI.new("Frame", {
		Name = "Cluster",
		Parent = root,
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.fromOffset(250, 180),
		BackgroundTransparency = 1,
	})

	cashTag = UI.new("Frame", {
		Name = "Cash",
		Parent = cluster,
		Size = UDim2.fromOffset(196, 62),
		Rotation = -1.5,
		BackgroundColor3 = M.Kraft,
		BorderSizePixel = 0,
	}, { UI.corner(4), UI.stroke(M.KraftEdge, 2) })
	cashScale = UI.new("UIScale", { Parent = cashTag })
	UI.tape(cashTag, UDim2.fromOffset(6, 4), Vector2.new(44, 15), -38, nil, 3)
	local coin = UI.coinIcon(cashTag, 30)
	coin.AnchorPoint = Vector2.new(0, 0.5)
	coin.Position = UDim2.new(0, 14, 0.5, 0)
	coin.ZIndex = 2
	cashLabel = UI.text({
		Name = "Amount",
		Parent = cashTag,
		Font = UI.Font.Mono,
		TextSize = 32,
		Position = UDim2.fromOffset(52, 0),
		Size = UDim2.new(1, -62, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = M.Marker,
		Text = "0",
		ZIndex = 2,
	})

	crate = UI.new("Frame", {
		Name = "Crate",
		Parent = cluster,
		Position = UDim2.fromOffset(0, 74),
		Size = UDim2.fromOffset(236, 74),
		BackgroundColor3 = M.Wood,
		BorderSizePixel = 0,
	}, { UI.stroke(M.WoodDark, 3) })
	crateScale = UI.new("UIScale", { Parent = crate })
	for _, y in { 0.34, 0.67 } do
		UI.new("Frame", {
			Parent = crate,
			Position = UDim2.fromScale(0, y),
			Size = UDim2.new(1, 0, 0, 2),
			BackgroundColor3 = M.WoodDark,
			BorderSizePixel = 0,
		})
	end
	for _, x in { 0, 1 } do
		UI.new("Frame", {
			Parent = crate,
			AnchorPoint = Vector2.new(x, 0),
			Position = UDim2.fromScale(x, 0),
			Size = UDim2.new(0, 8, 1, 0),
			BackgroundColor3 = M.WoodDark,
			BorderSizePixel = 0,
		})
	end
	crateWorth = UI.text({
		Name = "Worth",
		Parent = crate,
		Font = UI.Font.Label,
		TextSize = 13,
		Position = UDim2.fromOffset(14, 4),
		Size = UDim2.new(1, -110, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 240, 214),
		Text = "",
		ZIndex = 3,
	})
	crateLabel = UI.tape(crate, UDim2.new(1, -44, 0, 4), Vector2.new(84, 28), 2, nil, 5)
	crateCount = UI.text({
		Name = "Count",
		Parent = crateLabel,
		Font = UI.Font.Mono,
		TextSize = 19,
		Size = UDim2.fromScale(1, 1),
		TextColor3 = M.Marker,
		Text = "0/0",
		ZIndex = 6,
	})
	crateSlots = UI.new("Frame", {
		Name = "Slots",
		Parent = crate,
		Position = UDim2.fromOffset(14, 28),
		Size = UDim2.new(1, -28, 0, 38),
		BackgroundTransparency = 1,
		ZIndex = 3,
	})

	-- 2x Salvage: an orange price-gun sticker on the cash tag.
	boostSticker = UI.new("Frame", {
		Name = "Boost",
		Parent = cluster,
		Position = UDim2.fromOffset(170, -6),
		Size = UDim2.fromOffset(78, 40),
		Rotation = 8,
		BackgroundColor3 = M.Orange,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 6,
	}, { UI.corner(20), UI.stroke(M.Marker, 2) })
	boostLabel = UI.text({
		Parent = boostSticker,
		Font = UI.Font.Mono,
		TextSize = 13,
		Size = UDim2.fromScale(1, 1),
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
		ZIndex = 7,
	})
end

---------------------------------------------------------------------------- Storm sign

local function buildSign()
	topStack = UI.new("Frame", {
		Name = "TopStack",
		Parent = root,
		ZIndex = 25, -- storm info and danger alerts stay readable over the shop and settings
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
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
	signHolder = UI.new("Frame", {
		Name = "StormSign",
		Parent = topStack,
		LayoutOrder = 1,
		Size = UDim2.fromOffset(270, 112),
		BackgroundTransparency = 1,
	})
	swing = UI.new("Frame", {
		Name = "Swing",
		Parent = signHolder,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	})
	-- Hanging wires.
	for _, x in { 0.22, 0.78 } do
		UI.new("Frame", {
			Parent = swing,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(x, 0),
			Size = UDim2.fromOffset(2, 16),
			BackgroundColor3 = M.Marker,
			BorderSizePixel = 0,
		})
	end
	sign = UI.new("Frame", {
		Name = "Sign",
		Parent = swing,
		Position = UDim2.fromOffset(0, 14),
		Size = UDim2.new(1, 0, 1, -14),
		BackgroundColor3 = M.Tin,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, {
		UI.corner(6),
		UI.new("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(226, 232, 236), Color3.fromRGB(170, 176, 182)),
			Rotation = 100,
		}),
	})
	signStroke = UI.stroke(M.TinDark, 3)
	signStroke.Parent = sign
	-- Storm-type band across the top: the storm's own colour, plain bold lettering.
	signBand = UI.new("Frame", {
		Name = "Band",
		Parent = sign,
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = Config.RarityColors.Uncommon,
		BorderSizePixel = 0,
	})
	signBandText = UI.text({
		Parent = signBand,
		Font = UI.Font.Mono,
		TextSize = 16,
		Size = UDim2.fromScale(1, 1),
		TextColor3 = M.Marker,
		Text = "ALL CLEAR",
	})
	for _, p in { UDim2.new(0, 9, 1, -9), UDim2.new(1, -9, 1, -9) } do
		UI.rivet(sign, p, 2)
	end
	signCaption = UI.text({
		Name = "Caption",
		Parent = sign,
		Font = UI.Font.Label,
		TextSize = 12,
		Position = UDim2.fromOffset(14, 34),
		Size = UDim2.new(1, -178, 0, 52),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = M.Marker,
		Text = "NEXT STORM IN",
		ZIndex = 2,
	})
	-- Flip-clock tiles: mm:ss.
	local clock = UI.new("Frame", {
		Name = "Clock",
		Parent = sign,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 36),
		Size = UDim2.fromOffset(150, 48),
		BackgroundTransparency = 1,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 3),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i = 1, 4 do
		local tile = UI.new("Frame", {
			Parent = clock,
			LayoutOrder = if i <= 2 then i else i + 1,
			Size = UDim2.fromOffset(32, 46),
			BackgroundColor3 = M.Tile,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, { UI.corner(4) })
		UI.new("Frame", {
			Parent = tile,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
			ZIndex = 4,
		})
		tiles[i] = UI.text({
			Parent = tile,
			Font = UI.Font.Mono,
			TextSize = 30,
			Size = UDim2.fromScale(1, 1),
			TextColor3 = Color3.fromRGB(248, 244, 232),
			Text = "0",
			ZIndex = 3,
		})
		tileFrames[i] = tile
	end
	UI.text({
		Parent = clock,
		LayoutOrder = 3,
		Font = UI.Font.Mono,
		TextSize = 26,
		Size = UDim2.fromOffset(8, 46),
		TextColor3 = M.Marker,
		Text = ":",
	})

	-- Orders: what to do right now, on a paper strip pinned under the sign. Never scrolls; the
	-- whole instruction is always on screen while the danger lasts.
	orders = UI.new("Frame", {
		Name = "Orders",
		Parent = topStack,
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		BackgroundColor3 = M.Paper,
		BorderSizePixel = 0,
		Visible = false,
	}, {
		UI.corner(3),
		UI.stroke(M.Marker, 2),
		UI.padding(6, 14),
		UI.new("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	orderLive = UI.text({
		Name = "Live",
		Parent = orders,
		LayoutOrder = 1,
		Font = UI.Font.Mono,
		TextSize = 17,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		TextColor3 = M.RedPen,
		Text = "",
		Visible = false,
	})
	orderLine = UI.text({
		Name = "Do",
		Parent = orders,
		LayoutOrder = 2,
		Font = UI.Font.Label,
		TextSize = 15,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		TextWrapped = true,
		TextColor3 = M.Marker,
		Text = "",
	})
	orderWidth = UI.new("UISizeConstraint", { Parent = orderLine, MaxSize = Vector2.new(420, 60) })

	coreChip = UI.new("Frame", {
		Name = "Cores",
		Parent = topStack,
		LayoutOrder = 3,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 26),
		BackgroundColor3 = Config.RarityColors.Legendary,
		BorderSizePixel = 0,
		Rotation = -1,
		Visible = false,
	}, { UI.padding(0, 10) })
	coreLabel = UI.text({
		Parent = coreChip,
		Font = UI.Font.Mono,
		TextSize = 14,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		TextColor3 = M.Marker,
		Text = "",
	})
end

local lastPhase = ""
local jolt = 0
local modalOpen = false

-- While the shop or settings is open the sign keeps the storm and its countdown, but the
-- orders strip steps aside so it doesn't cover the menu's title (it returns on close).
function Hud.setModalOpen(open: boolean)
	modalOpen = open
end -- os.clock() of the last phase change (one-shot sign jolt)

local CALM_BAND = Color3.fromRGB(120, 200, 110)

-- `status` is the storm's live line ("Gust in 1.7s - get behind a wall!") or nil.
function Hud.stepStorm(now: number, storm: any, status: string?, statusColor: Color3?, cores: number)
	local remaining = math.max(0, math.ceil(storm.EndsAt - now))
	local phase = storm.Phase
	local info = storm.Storm and Config.Storms[storm.Storm]
	local danger = (phase == "Warning" or phase == "Storm") and info ~= nil

	local band, bandColor, caption
	if phase == "Warning" and info then
		band, bandColor, caption = info.DisplayName .. " COMING", info.Color, "HITS IN"
	elseif phase == "Storm" and info then
		band, bandColor, caption = info.DisplayName, info.Color, "PASSES IN"
	elseif phase == "Aftermath" then
		band, bandColor, caption = "STORM PASSED", UI.Color.Coin, "CALM IN"
	else
		band, bandColor, caption = "ALL CLEAR", CALM_BAND, if compact then "NEXT STORM" else "NEXT STORM IN"
	end
	signBandText.Text = band
	signBand.BackgroundColor3 = bandColor
	signCaption.Text = caption
	local digits = ("%02d%02d"):format(math.min(remaining // 60, 99), remaining % 60)
	for i = 1, 4 do
		tiles[i].Text = digits:sub(i, i)
	end
	-- Last seconds before a storm hits: red tiles.
	local urgent = (phase == "Warning" or phase == "Calm") and remaining <= 3
	for _, tile in tileFrames do
		tile.BackgroundColor3 = if urgent then Color3.fromRGB(176, 30, 26) else M.Tile
	end
	-- Danger outranks decoration: storm-coloured frame, and the sign holds still.
	signStroke.Color = if danger then (info :: any).Color:Lerp(M.Marker, 0.25) else M.TinDark
	signStroke.Thickness = if danger then 5 else 3

	orders.Visible = danger and not modalOpen
	if danger then
		orderLine.Text = (info :: any).Hint
		local live = phase == "Storm" and status ~= nil
		orderLive.Visible = live
		if live then
			orderLive.Text = string.upper(status :: string)
			-- Darken light status colours so they read on paper.
			orderLive.TextColor3 = (statusColor or M.RedPen):Lerp(M.Marker, 0.6)
		end
	end
	coreChip.Visible = cores > 0 and (phase == "Storm" or phase == "Aftermath") and not modalOpen
	if coreChip.Visible then
		coreLabel.Text = ("%d STORM CORE%s IN TOWN"):format(cores, if cores == 1 then "" else "S")
	end

	if phase ~= lastPhase then
		lastPhase = phase
		jolt = os.clock()
	end
	if UI.reduced() then
		swing.Rotation = 0
	else
		local t = os.clock() - jolt
		-- A short jolt when the phase changes, then a gentle sway in calm weather only.
		local kick = if t < 0.8 then math.sin(t * 18) * 5 * (1 - t / 0.8) else 0
		local sway = if danger then 0 else math.sin(now * 1.3) * 0.8
		swing.Rotation = kick + sway
	end
end

---------------------------------------------------------------------------- Right rail

local function buildRail()
	rail = UI.new("Frame", {
		Name = "Rail",
		Parent = root,
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(150, 170),
		BackgroundTransparency = 1,
	})
	-- Settings: a riveted tin plate.
	local size = UI.buttonSize()
	local settings = UI.new("TextButton", {
		Name = "SettingsButton",
		Parent = rail,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 0),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = M.Tin,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
	}, { UI.corner(6), UI.stroke(M.TinDark, 3) })
	for _, p in
		{ UDim2.fromOffset(7, 7), UDim2.new(1, -7, 0, 7), UDim2.new(0, 7, 1, -7), UDim2.new(1, -7, 1, -7) }
	do
		UI.rivet(settings, p, 2)
	end
	local sliders = UI.slidersIcon(settings, math.floor(size * 0.45))
	for _, d in sliders:GetDescendants() do
		if d:IsA("Frame") then
			d.BackgroundColor3 = M.Marker
		end
	end
	Hud.SettingsButton = settings

	-- Jobs: a clipboard plate left of Settings (the Contract board in the Scrapyard opens it too).
	local jobs = UI.new("TextButton", {
		Name = "JobsButton",
		Parent = rail,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4 - size - 8, 0, 0),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = M.Paper,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Font = UI.Font.Mono,
		TextSize = 14,
		TextColor3 = M.Marker,
		Text = "JOBS",
		Visible = false, -- shown after the first sale (staged discovery, Main)
	}, { UI.corner(4), UI.stroke(M.WoodDark, 3) })
	UI.new("Frame", {
		Parent = jobs,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 2),
		Size = UDim2.fromOffset(math.floor(size * 0.45), 8),
		BackgroundColor3 = M.Tin,
		BorderSizePixel = 0,
	}, { UI.corner(3), UI.stroke(M.TinDark, 1.5) })
	Hud.JobsButton = jobs

	-- Gear Shop: a manila tool tag hanging on a string.
	local shop = UI.new("TextButton", {
		Name = "ShopButton",
		Parent = rail,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, size + 18),
		Size = UDim2.fromOffset(140, 74),
		Rotation = 3,
		BackgroundColor3 = M.Manila,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
	}, { UI.corner(8), UI.stroke(M.KraftEdge, 2) })
	UI.punchHole(shop, UDim2.fromOffset(20, 18), 13, 2)
	local bag = UI.bagIcon(shop, 30)
	bag.Position = UDim2.fromOffset(10, 32)
	UI.text({
		Parent = shop,
		Font = UI.Font.Title,
		TextSize = 21,
		Position = UDim2.fromOffset(42, 6),
		Size = UDim2.new(1, -48, 1, -12),
		TextWrapped = true,
		TextColor3 = M.Marker,
		Text = "GEAR SHOP",
	})
	local scale = UI.new("UIScale", { Parent = shop })
	shop.Activated:Connect(function()
		UI.pop(scale, 0.92, 0.2)
	end)
	Hud.ShopButton = shop
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
		-- Phone: cash and crate side by side in one short row; the sign narrower; the rail on
		-- the right above the jump button.
		cluster.Size = UDim2.fromOffset(420, 66)
		cashTag.Size = UDim2.fromOffset(160, 56)
		cashLabel.TextSize = 28
		crate.Position = UDim2.fromOffset(170, 0)
		crate.Size = UDim2.fromOffset(220, 60)
		crateWorth.Visible = false
		crateSlots.Position = UDim2.fromOffset(14, 24)
		crateSlots.Size = UDim2.new(1, -28, 0, 28)
		boostSticker.Position = UDim2.fromOffset(120, -8)
		signHolder.Size = UDim2.fromOffset(250, 104)
		-- Right of centre, so the orders strip under it stays out of the thumbstick zone.
		topStack.Position = UDim2.new(0.6, 0, 0, 0)
		orderWidth.MaxSize = Vector2.new(300, 80)
		rail.Position = UDim2.new(1, -10, 0.22, 0)
	else
		cluster.Size = UDim2.fromOffset(250, 180)
		cashTag.Size = UDim2.fromOffset(196, 62)
		cashLabel.TextSize = 32
		crate.Position = UDim2.fromOffset(0, 74)
		crate.Size = UDim2.fromOffset(236, 74)
		crateWorth.Visible = true
		crateSlots.Position = UDim2.fromOffset(14, 28)
		crateSlots.Size = UDim2.new(1, -28, 0, 38)
		boostSticker.Position = UDim2.fromOffset(170, -6)
		signHolder.Size = UDim2.fromOffset(270, 112)
		topStack.Position = UDim2.new(0.5, 0, 0, 0)
		orderWidth.MaxSize = Vector2.new(420, 60)
		rail.Position = UDim2.new(1, -12, 0.3, 0)
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

-- "+120" drifting up beside the cash tag.
local function floatDelta(text: string, color: Color3)
	local at = (cashTag.AbsolutePosition - root.AbsolutePosition) / (rootScale.Scale * screenScale.Scale)
	local width = cashTag.AbsoluteSize.X / (rootScale.Scale * screenScale.Scale)
	local label = UI.text({
		Parent = root,
		Font = UI.Font.Mono,
		TextSize = 22,
		Outline = true,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(at.X + width + 8, at.Y + 30),
		Size = UDim2.fromOffset(120, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
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
	crateCount.Text = if full
		then ("FULL %d/%d"):format(carried, s.Capacity)
		else ("%d/%d"):format(carried, s.Capacity)
	crateCount.TextColor3 = if full then M.RedPen else M.Marker
	crateLabel.BackgroundColor3 = if full then Color3.fromRGB(255, 214, 200) else M.Tape
	crateWorth.Text = if carried > 0
		then ("SELLS FOR %s"):format(BigMoney.tag(s.CarriedValue))
		else "EMPTY CRATE"

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
	local slotH = if compact then 24 else 34
	for i = 1, s.Capacity do
		local id = s.Carried[i]
		local def = id and Config.Loot[id]
		UI.new("Frame", {
			Name = "Slot" .. i,
			Parent = crateSlots,
			LayoutOrder = i,
			Size = UDim2.fromOffset(slotW, slotH),
			BackgroundColor3 = if def then Config.RarityColors[def.Rarity] else M.WoodDark,
			BackgroundTransparency = if def then 0 else 0.5,
			BorderSizePixel = 0,
			ZIndex = 4,
		}, if def then { UI.stroke(M.Marker, 1, 0.45) } else nil)
	end
end

function Hud.pulseBag()
	UI.pop(crateScale, 1.06, 0.25)
end

function Hud.stepBoost(secondsLeft: number)
	boostSticker.Visible = secondsLeft > 0
	if secondsLeft > 0 then
		local secs = math.floor(secondsLeft)
		boostLabel.Text = ("2X  %d:%02d"):format(secs // 60, secs % 60)
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
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	if RunService:IsStudio() then
		ReplicatedStorage:GetAttributeChangedSignal("QA_PhoneFrame"):Connect(fit)
	end
	return root, topStack
end

return Hud
