-- @file Gear Shop pegboard (Equipment and Supply tabs)
-- @domain salvage-economy
-- @status stable
-- @see [[V3-UI-WORKSHOP]]
-- The Gear Shop as the Scrapyard's pegboard (Workshop direction). The three pieces of equipment
-- hang on the left as tool tags (level punched in, price sticker); the selected one is laid out
-- on a spec sheet on the right in a strict order: what it is, level, what it does now -> next
-- level, the level track, your coins, the price, one BUY button.
-- Buying asks the server (BuyUpgrade); the sheet only celebrates once the server's player state
-- shows the new level, so the UI never runs ahead of what was actually bought.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage.Shared:WaitForChild("Remotes"))
local SupplyCounter = require(script.Parent:WaitForChild("SupplyCounter"))
local UI = require(script.Parent:WaitForChild("UI"))

local Shop = {}
local M = UI.Mat

export type Hooks = {
	Notify: (text: string, color: Color3?) -> (),
	CanSave: () -> boolean,
}

local modal: UI.Modal
local hooks: Hooks
local state: any = nil
local selected = Config.UpgradeOrder[1]

type Tile = {
	Frame: TextButton,
	Stroke: UIStroke,
	Holes: { Frame },
	Price: Frame,
	PriceText: TextLabel,
	Tilt: number,
	Level: number?,
}
local tiles: { [string]: Tile } = {}

-- Spec sheet widgets.
local sheet: Frame
local sheetScale: UIScale
local sheetIcon: Frame
local sheetTitle: TextLabel
local sheetLevel: TextLabel
local sheetDesc: TextLabel
local sheetNow: TextLabel
local sheetArrow: TextLabel
local sheetNext: TextLabel
local track: Frame
local wallet: TextLabel
local buy: TextButton
local installed: Frame

local function formatValue(id: string, value: any): string
	if id == "Backpack" then
		return ("%d SLOTS"):format(value)
	elseif id == "Boots" then
		return ("SPEED %d"):format(value)
	elseif value == 0 then
		return "NO ARMOR"
	end
	return ("-%d%% DAMAGE"):format(math.floor(value * 100 + 0.5))
end

---------------------------------------------------------------------------- Pegboard tags

local TILTS = { -1.5, 1.2, -0.8 }

local function makeTile(rack: Instance, id: string, order: number): Tile
	local def = Config.Upgrades[id]
	local holder = UI.new("Frame", {
		Name = id,
		Parent = rack,
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 84),
		BackgroundTransparency = 1,
		ZIndex = 21,
	})
	local tilt = TILTS[order] or 0
	local frame = UI.new("TextButton", {
		Name = "Tag",
		Parent = holder,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -8, 1, -8),
		Rotation = tilt,
		BackgroundColor3 = M.Manila,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		ZIndex = 22,
	}, { UI.corner(8) })
	local stroke = UI.stroke(M.KraftEdge, 2)
	stroke.Parent = frame
	UI.punchHole(frame, UDim2.fromOffset(14, 14), 11, 23)
	local icon = UI.upgradeIcon(id, frame, 44)
	icon.Position = UDim2.fromOffset(18, 22)
	for _, d in icon:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = 24
		end
	end
	UI.text({
		Parent = frame,
		Font = UI.Font.Title,
		TextSize = 17,
		Position = UDim2.fromOffset(70, 8),
		Size = UDim2.new(1, -140, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = M.Marker,
		Text = def.DisplayName,
		ZIndex = 23,
	})
	-- Level, punched into the tag.
	local holes = {}
	for i = 1, #def.Costs do
		local hole = UI.new("Frame", {
			Name = "Level" .. i,
			Parent = frame,
			Position = UDim2.fromOffset(70 + (i - 1) * 17, 44),
			Size = UDim2.fromOffset(12, 12),
			BackgroundColor3 = M.Manila,
			BorderSizePixel = 0,
			ZIndex = 23,
		}, { UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), UI.stroke(M.Marker, 2) })
		UI.new("UIScale", { Parent = hole })
		table.insert(holes, hole)
	end
	-- Price sticker.
	local price = UI.new("Frame", {
		Name = "Price",
		Parent = frame,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(60, 44),
		Rotation = -6,
		BackgroundColor3 = M.Orange,
		BorderSizePixel = 0,
		ZIndex = 23,
	}, { UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	local priceText = UI.text({
		Parent = price,
		Font = UI.Font.Mono,
		TextSize = 16,
		Size = UDim2.fromScale(1, 1),
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
		ZIndex = 24,
	})
	frame.Activated:Connect(function()
		selected = id
		Shop.refresh()
	end)
	return {
		Frame = frame,
		Stroke = stroke,
		Holes = holes,
		Price = price,
		PriceText = priceText,
		Tilt = tilt,
	}
end

---------------------------------------------------------------------------- Spec sheet

local function buildSheet(parent: Instance)
	sheet = UI.new("Frame", {
		Name = "Sheet",
		Parent = parent,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.new(0.6, -4, 1, -8),
		BackgroundColor3 = M.Paper,
		BorderSizePixel = 0,
		ZIndex = 21,
	}, { UI.corner(3), UI.stroke(M.KraftEdge, 2) })
	sheetScale = UI.new("UIScale", { Parent = sheet })
	UI.tape(sheet, UDim2.new(0.5, 0, 0, 0), Vector2.new(90, 20), 2, nil, 26)

	sheetIcon = UI.new("Frame", {
		Name = "Icon",
		Parent = sheet,
		Position = UDim2.fromOffset(14, 18),
		Size = UDim2.fromOffset(76, 76),
		BackgroundColor3 = M.Manila,
		BorderSizePixel = 0,
		ZIndex = 22,
	}, { UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), UI.stroke(M.KraftEdge, 2) })
	sheetTitle = UI.text({
		Name = "Title",
		Parent = sheet,
		Font = UI.Font.Title,
		TextSize = 25,
		Position = UDim2.fromOffset(102, 16),
		Size = UDim2.new(1, -112, 0, 32),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = M.Marker,
		Text = "",
		ZIndex = 22,
	})
	sheetLevel = UI.text({
		Name = "Level",
		Parent = sheet,
		Font = UI.Font.Mono,
		TextSize = 13,
		Position = UDim2.fromOffset(102, 48),
		Size = UDim2.new(1, -112, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = M.Pencil,
		Text = "",
		ZIndex = 22,
	})
	sheetDesc = UI.text({
		Name = "Desc",
		Parent = sheet,
		Font = UI.Font.Body,
		TextSize = 14,
		Position = UDim2.fromOffset(102, 66),
		Size = UDim2.new(1, -112, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextColor3 = M.Pencil,
		Text = "",
		ZIndex = 22,
	})
	-- Now -> next: the biggest numbers on the sheet.
	local stats = UI.new("Frame", {
		Name = "Stats",
		Parent = sheet,
		Position = UDim2.fromOffset(14, 104),
		Size = UDim2.new(1, -28, 0, 34),
		BackgroundTransparency = 1,
		ZIndex = 22,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local function stat(order: number, color: Color3): TextLabel
		return UI.text({
			Parent = stats,
			LayoutOrder = order,
			Font = UI.Font.Mono,
			TextSize = 22,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 30),
			TextColor3 = color,
			Text = "",
			ZIndex = 22,
		})
	end
	sheetNow = stat(1, M.Pencil)
	sheetArrow = stat(2, M.Pencil)
	sheetArrow.Text = "→"
	sheetNext = stat(3, Color3.fromRGB(34, 130, 56))
	-- Level track: installed levels filled, the next one orange, the rest empty.
	track = UI.new("Frame", {
		Name = "Track",
		Parent = sheet,
		Position = UDim2.fromOffset(14, 142),
		Size = UDim2.new(1, -28, 0, 14),
		BackgroundTransparency = 1,
		ZIndex = 22,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	wallet = UI.text({
		Name = "Wallet",
		Parent = sheet,
		Font = UI.Font.Label,
		TextSize = 13,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -70),
		Size = UDim2.new(1, -28, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = M.Pencil,
		Text = "",
		ZIndex = 22,
	})
	buy = UI.button({
		Name = "Buy",
		Parent = sheet,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -28, 0, math.min(UI.buttonSize(), 56)),
		TextSize = 20,
		Color = UI.Color.Buy,
		ZIndex = 22,
	})
	buy.Font = UI.Font.Mono
	buy.Activated:Connect(function()
		-- Unaffordable presses still go to the server, which explains what's missing.
		Remotes.get("BuyUpgrade"):FireServer(selected)
	end)
	-- "INSTALLED" stamp, shown when the server confirms a purchase.
	installed = UI.new("Frame", {
		Name = "Installed",
		Parent = sheet,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 196),
		Size = UDim2.fromOffset(170, 44),
		Rotation = -10,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 30,
	}, { UI.corner(6), UI.stroke(Color3.fromRGB(34, 130, 56), 4) })
	UI.text({
		Parent = installed,
		Font = UI.Font.Mono,
		TextSize = 24,
		Size = UDim2.fromScale(1, 1),
		TextColor3 = Color3.fromRGB(34, 130, 56),
		Text = "INSTALLED",
		ZIndex = 30,
	})
	UI.new("UIScale", { Parent = installed })
end

local shownIcon: string? = nil
local celebrating = false

function Shop.refresh()
	if not state then
		return
	end
	for id, tile in tiles do
		local def = Config.Upgrades[id]
		local level = state.Upgrades[id] or 0
		for i, hole in tile.Holes do
			hole.BackgroundColor3 = if i <= level then M.Marker else M.Manila
		end
		local cost = def.Costs[level + 1]
		if cost then
			tile.PriceText.Text = UI.comma(cost)
			tile.Price.BackgroundColor3 = if state.Coins >= cost
				then M.Orange
				else Color3.fromRGB(176, 166, 148)
		else
			tile.PriceText.Text = "MAX"
			tile.Price.BackgroundColor3 = Color3.fromRGB(80, 170, 90)
		end
		local active = id == selected
		tile.Stroke.Color = if active then M.Orange else M.KraftEdge
		tile.Stroke.Thickness = if active then 4 else 2
		tile.Frame.Rotation = if active or UI.reduced() then 0 else tile.Tilt
		tile.Frame.BackgroundColor3 = if active then Color3.fromRGB(252, 236, 196) else M.Manila
	end

	local def = Config.Upgrades[selected]
	local level = state.Upgrades[selected] or 0
	if shownIcon ~= selected then
		shownIcon = selected
		for _, child in sheetIcon:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local icon = UI.upgradeIcon(selected, sheetIcon, 54)
		icon.Position = UDim2.fromOffset(11, 11)
		for _, d in icon:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex = 24
			end
		end
		icon.ZIndex = 23
	end
	sheetTitle.Text = def.DisplayName
	sheetDesc.Text = def.Description
	sheetLevel.Text = ("LEVEL %d / %d"):format(level, #def.Costs)
	wallet.Text = ("YOU HAVE %s COINS"):format(UI.comma(state.Coins))

	for _, c in track:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local steps = #def.Costs
	for i = 1, steps do
		UI.new("Frame", {
			Parent = track,
			LayoutOrder = i,
			Size = UDim2.new(1 / steps, -4, 1, 0),
			BackgroundColor3 = if i <= level
				then M.Marker
				elseif i == level + 1 then M.Orange
				else Color3.fromRGB(226, 220, 204),
			BorderSizePixel = 0,
			ZIndex = 22,
		}, { UI.corner(2) })
	end

	if celebrating then
		return
	end
	local cost = def.Costs[level + 1]
	sheetNow.Text = formatValue(selected, def.Values[level + 1])
	if cost then
		sheetNext.Text = formatValue(selected, def.Values[level + 2])
		sheetArrow.Visible = true
		sheetNext.Visible = true
		local short = cost - state.Coins
		if short > 0 then
			buy.Text = ("NEED %s MORE"):format(UI.comma(short))
			buy:SetAttribute("Disabled", true)
		else
			buy.Text = ("BUY  ·  %s COINS"):format(UI.comma(cost))
			buy:SetAttribute("Disabled", false)
		end
	else
		sheetArrow.Visible = false
		sheetNext.Visible = false
		buy.Text = "MAXED OUT"
		buy:SetAttribute("Disabled", true)
	end
end

-- The server confirmed a level-up: punch the new hole, stamp the sheet.
local function celebrate(id: string, level: number)
	local tile = tiles[id]
	local hole = tile and tile.Holes[level]
	if hole then
		UI.pop(hole:FindFirstChildOfClass("UIScale") :: UIScale, 1.8, 0.35)
	end
	if id ~= selected then
		return
	end
	celebrating = true
	UI.pop(sheetScale, 1.03, 0.3)
	installed.Visible = true
	local scale = installed:FindFirstChildOfClass("UIScale") :: UIScale
	if UI.reduced() then
		scale.Scale = 1
	else
		scale.Scale = 1.8
		UI.tween(scale, 0.14, { Scale = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	buy.Text = "UPGRADED!"
	buy:SetAttribute("Disabled", true)
	task.delay(1.1, function()
		installed.Visible = false
		celebrating = false
		Shop.refresh()
	end)
end

function Shop.setState(s: any)
	local previous = state
	state = s
	SupplyCounter.setState(s)
	for id, tile in tiles do
		local level = s.Upgrades[id] or 0
		if previous and tile.Level and level > tile.Level then
			celebrate(id, level)
		end
		tile.Level = level
	end
	if modal.IsOpen() then
		Shop.refresh()
	end
end

function Shop.open()
	Shop.showTab("Equipment")
	modal.Open()
end

function Shop.toggle()
	if modal.IsOpen() then
		modal.Close()
	else
		Shop.open()
	end
end

function Shop.modal(): UI.Modal
	return modal
end

-- Re-dress the standard modal as a pegboard with a tape title.
local function dressPanel(panel: Frame)
	panel.BackgroundColor3 = M.Peg
	panel.BackgroundTransparency = 0
	local stroke = panel:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = M.WoodDark
		stroke.Thickness = 5
	end
	local holes = UI.new("Frame", {
		Name = "Pegholes",
		Parent = panel,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 20,
	})
	for x = 1, 20 do
		for y = 1, 12 do
			UI.new("Frame", {
				Parent = holes,
				Position = UDim2.fromOffset(x * 34 - 14, y * 34 - 14),
				Size = UDim2.fromOffset(5, 5),
				BackgroundColor3 = M.PegHole,
				BorderSizePixel = 0,
				ZIndex = 20,
			}, { UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		end
	end
	local title = panel:FindFirstChild("Title") :: TextLabel?
	if title then
		title.TextColor3 = M.Marker
		title.TextXAlignment = Enum.TextXAlignment.Center
		title.Size = UDim2.fromOffset(230, 36)
		title.ZIndex = 23
		local tape = UI.tape(panel, UDim2.fromOffset(18 + 115, 12 + 18), Vector2.new(240, 40), -1.5, nil, 22)
		tape.BackgroundTransparency = 0
	end
end

-- Two tabs in the pegboard header: the coin-funded Equipment workbench (default) and the optional
-- Supply Counter (Robux).
local tabButtons: { [string]: TextButton } = {}
local views: { [string]: GuiObject } = {}

-- Staged discovery: the Supply Counter tab appears once the player has bought their first
-- equipment upgrade, so a new player's shop is just the workbench.
function Shop.setSupplyVisible(visible: boolean)
	local b = tabButtons.Supply
	if b then
		b.Visible = visible
		tabButtons.Equipment.Size = if visible then UDim2.new(0.5, -3, 1, 0) else UDim2.new(1, 0, 1, 0)
	end
	if not visible and views.Supply and views.Supply.Visible then
		Shop.showTab("Equipment")
	end
end

function Shop.showTab(name: string)
	for key, view in views do
		view.Visible = key == name
	end
	for key, b in tabButtons do
		local on = key == name
		b.BackgroundColor3 = if on then M.Manila else M.Kraft:Lerp(M.Marker, 0.25)
		b.TextColor3 = if on then M.Marker else M.Paper
		b:SetAttribute("Active", on)
	end
	if name == "Equipment" then
		Shop.refresh()
	end
end

local function buildTabs(panel: Frame)
	local holder = UI.new("Frame", {
		Name = "Tabs",
		Parent = panel,
		Position = UDim2.fromOffset(268, 14),
		Size = UDim2.new(1, -350, 0, 40),
		BackgroundTransparency = 1,
		ZIndex = 23,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, entry in { { "Equipment", "EQUIPMENT" }, { "Supply", "SUPPLY COUNTER" } } do
		local b = UI.new("TextButton", {
			Name = entry[1],
			Parent = holder,
			LayoutOrder = i,
			Size = UDim2.new(0.5, -3, 1, 0),
			BackgroundColor3 = M.Manila,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			Font = UI.Font.Mono,
			TextSize = 13,
			TextColor3 = M.Marker,
			Text = entry[2],
			ZIndex = 24,
		}, { UI.corner(6), UI.stroke(M.KraftEdge, 2) })
		b.Activated:Connect(function()
			Shop.showTab(entry[1])
		end)
		tabButtons[entry[1]] = b
	end
end

function Shop.init(root: Frame, h: Hooks)
	hooks = h
	modal = UI.modal(root, "Shop", "GEAR SHOP", Vector2.new(660, 400))
	dressPanel(modal.Panel)
	buildTabs(modal.Panel)
	local equipment = UI.new("Frame", {
		Name = "Equipment",
		Parent = modal.Content,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 21,
	})
	views.Equipment = equipment
	local rack = UI.new("ScrollingFrame", {
		Name = "List",
		Parent = equipment,
		Size = UDim2.new(0.4, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 21,
	}, { UI.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
	buildSheet(equipment)

	for i, id in Config.UpgradeOrder do
		tiles[id] = makeTile(rack, id, i)
	end

	views.Supply = SupplyCounter.build(modal.Content, { Notify = hooks.Notify })
	Shop.showTab("Equipment")
end

return Shop
