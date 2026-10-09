-- The always-on HUD: a compact storm strip at the top and a right rail with coins, the bag,
-- and the Shop and Settings buttons. Everything else (cards, notices, alerts) lives in
-- Notifications. Values shown here come from the server's player and storm state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UI = require(script.Parent:WaitForChild("UI"))

local Hud = {}

local root: Frame
local rootScale: UIScale
local topStack: Frame

local strip: Frame
local stripStroke: UIStroke
local stripDot: Frame
local stripTitle: TextLabel
local stripTimer: TextLabel
local timerChip: Frame
local coreChip: Frame
local coreLabel: TextLabel
local stripStatus: TextLabel

local rail: Frame
local coinsPlate: Frame
local coinsLabel: TextLabel
local coinsScale: UIScale
local bagPlate: Frame
local bagCount: TextLabel
local bagBar: Frame
local bagFill: Frame
local bagValue: TextLabel
local bagScale: UIScale
local boostChip: Frame
local boostLabel: TextLabel

Hud.ShopButton = nil :: TextButton?
Hud.SettingsButton = nil :: TextButton?

---------------------------------------------------------------------------- Scale

local function fit()
	local camera = workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else 600
	-- Phones in landscape (about 340-400 pt tall) land on 0.7; laptops on 1-1.15.
	local scale = math.clamp(height / 600, 0.7, 1.15)
	rootScale.Scale = scale
	root.Size = UDim2.fromScale(1 / scale, 1 / scale)
	rail.Position = UDim2.new(1, -12, if UI.isTouch() then 0.2 else 0.3, 0)
end

---------------------------------------------------------------------------- Storm strip

local function chip(parent: Instance, order: number, color: Color3): (Frame, TextLabel)
	local frame = UI.new("Frame", {
		Parent = parent,
		LayoutOrder = order,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.75,
		BorderSizePixel = 0,
	}, { UI.corner(UI.Radius.Chip), UI.padding(0, 8) })
	local label = UI.text({
		Parent = frame,
		Role = "Label",
		TextSize = 14,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		Text = "",
		TextColor3 = color,
	})
	return frame, label
end

local function buildStrip()
	topStack = UI.new("Frame", {
		Name = "TopStack",
		Parent = root,
		ZIndex = 25, -- storm info and danger alerts stay readable over the shop and settings
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		BackgroundTransparency = 1,
	}, {
		UI.new("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	strip = UI.plate({
		Name = "StormStrip",
		Parent = topStack,
		LayoutOrder = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
	})
	stripStroke = strip:FindFirstChildOfClass("UIStroke") :: UIStroke
	UI.padding(6, 12).Parent = strip
	UI.new("UIListLayout", {
		Parent = strip,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local row = UI.new("Frame", {
		Name = "Row",
		Parent = strip,
		LayoutOrder = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		BackgroundTransparency = 1,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	stripDot = UI.new("Frame", {
		Name = "Dot",
		Parent = row,
		LayoutOrder = 1,
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = UI.Color.Safe,
		BorderSizePixel = 0,
	}, { UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	stripTitle = UI.text({
		Name = "Title",
		Parent = row,
		LayoutOrder = 2,
		Role = "Title",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 24),
		Text = "CALM SKIES",
	})
	timerChip, stripTimer = chip(row, 3, UI.Color.TextDim)
	timerChip.Name = "Timer"
	coreChip, coreLabel = chip(row, 4, Config.RarityColors.Legendary)
	coreChip.Name = "Cores"
	coreChip.Visible = false
	stripStatus = UI.text({
		Name = "Status",
		Parent = strip,
		LayoutOrder = 2,
		Role = "Label",
		TextSize = 15,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		Text = "",
		Visible = false,
	})
	UI.new("UISizeConstraint", { Parent = stripStatus, MaxSize = Vector2.new(520, 60) })
end

local lastPhase = ""

-- `status` is the storm's live line ("Gust in 1.7s - get behind a wall!") or nil.
function Hud.stepStorm(now: number, storm: any, status: string?, statusColor: Color3?, cores: number)
	local remaining = math.max(0, math.ceil(storm.EndsAt - now))
	local phase = storm.Phase
	local info = storm.Storm and Config.Storms[storm.Storm]
	local title, accent, timer, line, lineColor

	if phase == "Warning" and info then
		title = info.DisplayName .. " INCOMING"
		accent = info.Color
		timer = ("%ds"):format(remaining)
		line, lineColor = info.Hint, UI.Color.Text
	elseif phase == "Storm" and info then
		title = info.DisplayName
		accent = info.Color
		timer = ("%ds left"):format(remaining)
		line, lineColor = status, statusColor or UI.Color.Text
	elseif phase == "Aftermath" then
		title = "STORM PASSED"
		accent = UI.Color.Coin
		timer = ("calm in %ds"):format(remaining)
	else
		title = "CALM SKIES"
		accent = UI.Color.Safe
		timer = ("storm in %ds"):format(remaining)
	end

	stripTitle.Text = title
	stripTitle.TextColor3 = if phase == "Calm" or phase == "Aftermath" then UI.Color.Text else accent
	stripDot.BackgroundColor3 = accent
	stripTimer.Text = timer
	local urgent = (phase == "Warning" or phase == "Calm") and remaining <= 3
	stripTimer.TextColor3 = if urgent then UI.Color.Warn else UI.Color.TextDim
	-- The strip only stands out while a storm is coming or running.
	local loud = phase == "Warning" or phase == "Storm"
	stripStroke.Color = if loud then accent else UI.Color.Outline
	stripStroke.Thickness = if loud then 2.5 else 2
	if phase == "Warning" and not UI.reduced() then
		stripStroke.Transparency = 0.2 + 0.2 * math.sin(now * 8)
	else
		stripStroke.Transparency = 0
	end
	stripStatus.Visible = line ~= nil
	if line then
		stripStatus.Text = line
		stripStatus.TextColor3 = lineColor
	end
	coreChip.Visible = cores > 0 and (phase == "Storm" or phase == "Aftermath")
	if coreChip.Visible then
		coreLabel.Text = ("%d STORM CORE%s"):format(cores, if cores == 1 then "" else "S")
	end

	if phase ~= lastPhase then
		lastPhase = phase
		local scale = strip:FindFirstChildOfClass("UIScale") or UI.new("UIScale", { Parent = strip })
		if phase == "Warning" or phase == "Storm" then
			UI.pop(scale, 1.06, 0.3)
		end
	end
end

---------------------------------------------------------------------------- Right rail

local function buildRail()
	rail = UI.new("Frame", {
		Name = "Rail",
		Parent = root,
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(200, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, {
		UI.new("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- Coins: the only gold number on screen, because it's the only real money.
	coinsPlate = UI.plate({
		Name = "Coins",
		Parent = rail,
		LayoutOrder = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 40),
	})
	UI.padding(0, 12, 0, 8).Parent = coinsPlate
	UI.new("UIListLayout", {
		Parent = coinsPlate,
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	UI.coinIcon(coinsPlate, 22).LayoutOrder = 1
	coinsLabel = UI.text({
		Name = "Amount",
		Parent = coinsPlate,
		LayoutOrder = 2,
		Role = "Title",
		TextSize = 22,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 26),
		TextColor3 = UI.Color.Coin,
		Text = "0",
	})
	coinsScale = UI.new("UIScale", { Parent = coinsPlate })

	-- Bag: count, fill bar, and what it would sell for (value, not money yet).
	bagPlate = UI.plate({
		Name = "Bag",
		Parent = rail,
		LayoutOrder = 2,
		Size = UDim2.fromOffset(190, 58),
	})
	UI.padding(6, 10).Parent = bagPlate
	bagScale = UI.new("UIScale", { Parent = bagPlate })
	local icon = UI.bagIcon(bagPlate, 20)
	icon.Position = UDim2.fromOffset(0, 0)
	bagCount = UI.text({
		Name = "Count",
		Parent = bagPlate,
		Role = "Title",
		TextSize = 18,
		Position = UDim2.fromOffset(28, 0),
		Size = UDim2.new(1, -28, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Bag 0/3",
	})
	bagBar = UI.new("Frame", {
		Name = "Bar",
		Parent = bagPlate,
		Position = UDim2.fromOffset(0, 25),
		Size = UDim2.new(1, 0, 0, 8),
		BackgroundColor3 = UI.Color.PlateLight,
		BorderSizePixel = 0,
	}, { UI.corner(4) })
	bagFill = UI.new("Frame", {
		Name = "Fill",
		Parent = bagBar,
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = UI.Color.Safe,
		BorderSizePixel = 0,
	}, { UI.corner(4) })
	bagValue = UI.text({
		Name = "Value",
		Parent = bagPlate,
		Role = "Caption",
		TextSize = 13,
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Color.TextDim,
		Text = "Empty",
	})

	local buttons = UI.new("Frame", {
		Name = "Buttons",
		Parent = rail,
		LayoutOrder = 3,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		BackgroundTransparency = 1,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local size = UI.buttonSize()
	Hud.ShopButton = UI.button({
		Name = "ShopButton",
		Parent = buttons,
		LayoutOrder = 1,
		Text = "SHOP",
		TextSize = 18,
		Color = Color3.fromRGB(206, 122, 34), -- rusty orange: the salvage yard's color
		Size = UDim2.fromOffset(math.floor(size * 1.5), size),
	})
	local settingsButton = UI.button({
		Name = "SettingsButton",
		Parent = buttons,
		LayoutOrder = 2,
		Color = UI.Color.Slate,
		Size = UDim2.fromOffset(size, size),
	})
	UI.slidersIcon(settingsButton, math.floor(size * 0.42))
	Hud.SettingsButton = settingsButton

	boostChip, boostLabel = chip(rail, 4, UI.Color.Coin)
	boostChip.Name = "Boost"
	boostChip.Visible = false
end

---------------------------------------------------------------------------- Player state

local shownCoins: number? = nil
local cancelCount: (() -> ())? = nil

local function formatCoins(n: number): string
	local s = tostring(math.floor(n))
	-- 12345 -> 12,345
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

-- "+120" drifting up beside the coin plate. Floats live on the root (the rail is a list
-- layout), so the plate's screen position is converted back into root design pixels.
local function floatDelta(text: string, color: Color3)
	local at = (coinsPlate.AbsolutePosition - root.AbsolutePosition) / rootScale.Scale
	local label = UI.text({
		Parent = root,
		Role = "Title",
		TextSize = 20,
		Outline = true,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromOffset(at.X - 8, at.Y + coinsPlate.AbsoluteSize.Y / rootScale.Scale / 2),
		Size = UDim2.fromOffset(120, 24),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = color,
		Text = text,
		ZIndex = 6,
	})
	local goal = label.Position - UDim2.fromOffset(0, 22)
	UI.tween(label, 0.9, { Position = goal }, Enum.EasingStyle.Quad)
	UI.tween(label, 0.4, { TextTransparency = 1 }, Enum.EasingStyle.Quad).Completed:Wait()
	label:Destroy()
end

-- Coins changed: count up to the new balance (gains) or drop straight to it (spending).
local function showCoins(coins: number)
	if cancelCount then
		cancelCount()
		cancelCount = nil
	end
	local previous = shownCoins
	shownCoins = coins
	if previous == nil or coins == previous then
		coinsLabel.Text = formatCoins(coins)
		return
	end
	if coins > previous then
		local from = previous
		cancelCount = UI.countUp(coinsLabel, from, coins, UI.Time.Count, "%d")
		task.delay(UI.Time.Count + 0.05, function()
			if shownCoins == coins then
				coinsLabel.Text = formatCoins(coins)
			end
		end)
		UI.pop(coinsScale, 1.12, 0.35)
		task.spawn(floatDelta, ("+%s"):format(formatCoins(coins - from)), UI.Color.Coin)
	else
		coinsLabel.Text = formatCoins(coins)
		task.spawn(floatDelta, ("-%s"):format(formatCoins(previous - coins)), UI.Color.TextDim)
	end
end

function Hud.setPlayer(s: any)
	showCoins(s.Coins)
	local carried = #s.Carried
	local capacity = math.max(1, s.Capacity)
	local fill = math.clamp(carried / capacity, 0, 1)
	bagCount.Text = ("Bag %d/%d"):format(carried, s.Capacity)
	UI.tween(bagFill, 0.25, { Size = UDim2.fromScale(fill, 1) })
	local full = carried >= s.Capacity
	bagFill.BackgroundColor3 = if full
		then UI.Color.Danger
		elseif fill >= 0.7 then UI.Color.Warn
		else UI.Color.Safe
	bagCount.TextColor3 = if full then UI.Color.Danger else UI.Color.Text
	bagValue.Text = if carried > 0 then ("Sell value %d"):format(s.CarriedValue) else "Empty - go salvage!"
end

function Hud.pulseBag()
	UI.pop(bagScale, 1.08, 0.25)
end

function Hud.stepBoost(secondsLeft: number)
	boostChip.Visible = secondsLeft > 0
	if secondsLeft > 0 then
		local secs = math.floor(secondsLeft)
		boostLabel.Text = ("2x SALVAGE  %d:%02d"):format(secs // 60, secs % 60)
	end
end

---------------------------------------------------------------------------- Init

function Hud.init(gui: ScreenGui): (Frame, Frame)
	root = UI.new(
		"Frame",
		{ Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui }
	)
	rootScale = UI.new("UIScale", { Parent = root })
	buildStrip()
	buildRail()
	fit()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	return root, topStack
end

return Hud
