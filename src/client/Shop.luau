-- The Gear Shop as a mechanic's workbench: the three pieces of equipment on a rack on the left,
-- the selected one on the bench on the right (big icon, what it does now, what the next level
-- gives, the price, one BUY button). Buying asks the server (BuyUpgrade); the bench only
-- celebrates once the server's player state shows the new level, so the UI never runs ahead of
-- what was actually bought.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage.Shared:WaitForChild("Remotes"))
local UI = require(script.Parent:WaitForChild("UI"))

local Shop = {}

export type Hooks = {
	Notify: (text: string, color: Color3?) -> (),
	CanSave: () -> boolean,
}

local modal: UI.Modal
local hooks: Hooks
local state: any = nil
local selected = Config.UpgradeOrder[1]

type Tile = { Frame: TextButton, Stroke: UIStroke, Pips: { Frame }, Level: number? }
local tiles: { [string]: Tile } = {}

-- Bench widgets.
local benchIconHolder: Frame
local benchTitle: TextLabel
local benchDesc: TextLabel
local benchLevel: TextLabel
local benchNow: TextLabel
local benchNext: TextLabel
local benchArrow: TextLabel
local benchBuy: TextButton
local benchStroke: UIStroke
local benchScale: UIScale

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

local function formatCoins(n: number): string
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

---------------------------------------------------------------------------- Rack (left)

local function makeTile(rack: Instance, id: string, order: number): Tile
	local def = Config.Upgrades[id]
	local frame = UI.new("TextButton", {
		Name = id,
		Parent = rack,
		LayoutOrder = order,
		Size = UDim2.new(1, -6, 0, 72),
		BackgroundColor3 = UI.Color.PlateLight,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		ZIndex = 21,
	}, { UI.corner(UI.Radius.Panel) })
	local stroke = UI.stroke(UI.Color.Outline, 1.5, 0.75)
	stroke.Parent = frame
	local icon = UI.upgradeIcon(id, frame, 40)
	icon.Position = UDim2.fromOffset(10, 16)
	icon.ZIndex = 22
	UI.text({
		Parent = frame,
		Role = "Title",
		TextSize = 18,
		Position = UDim2.fromOffset(60, 12),
		Size = UDim2.new(1, -66, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = string.upper(def.DisplayName),
		ZIndex = 22,
	})
	local pips = {}
	for i = 1, #def.Costs do
		local pip = UI.new("Frame", {
			Name = "Pip" .. i,
			Parent = frame,
			Position = UDim2.fromOffset(60 + (i - 1) * 14, 44),
			Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = UI.Color.Disabled,
			BorderSizePixel = 0,
			ZIndex = 22,
		}, { UI.corner(2) })
		UI.new("UIScale", { Parent = pip })
		table.insert(pips, pip)
	end
	frame.Activated:Connect(function()
		selected = id
		Shop.refresh()
	end)
	return { Frame = frame, Stroke = stroke, Pips = pips }
end

---------------------------------------------------------------------------- Bench (right)

local function buildBench(parent: Instance)
	local bench = UI.new("Frame", {
		Name = "Bench",
		Parent = parent,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.62, 0, 1, 0),
		BackgroundColor3 = UI.Color.PlateLight,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 21,
	}, { UI.corner(UI.Radius.Panel) })
	benchStroke = UI.stroke(UI.Color.Outline, 1.5, 0.5)
	benchStroke.Parent = bench
	benchScale = UI.new("UIScale", { Parent = bench })
	-- Hazard tape along the top edge of the bench.
	local tape = UI.new("Frame", {
		Name = "Tape",
		Parent = bench,
		Size = UDim2.new(1, 0, 0, 5),
		BackgroundColor3 = Color3.fromRGB(232, 160, 52),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 22,
	})
	for i = 0, 40 do
		UI.new("Frame", {
			Parent = tape,
			Position = UDim2.fromOffset(i * 16, -4),
			Size = UDim2.fromOffset(6, 14),
			Rotation = 35,
			BackgroundColor3 = Color3.fromRGB(26, 24, 22),
			BorderSizePixel = 0,
			ZIndex = 22,
		})
	end
	benchIconHolder = UI.new("Frame", {
		Name = "Icon",
		Parent = bench,
		Position = UDim2.fromOffset(14, 18),
		Size = UDim2.fromOffset(84, 84),
		BackgroundColor3 = UI.Color.Plate,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		ZIndex = 22,
	}, { UI.corner(UI.Radius.Panel) })
	benchTitle = UI.text({
		Name = "Title",
		Parent = bench,
		Role = "Display",
		TextSize = 28,
		Position = UDim2.fromOffset(110, 16),
		Size = UDim2.new(1, -120, 0, 32),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		ZIndex = 22,
	})
	benchLevel = UI.text({
		Name = "Level",
		Parent = bench,
		Font = UI.Font.Mono,
		TextSize = 14,
		Position = UDim2.fromOffset(110, 50),
		Size = UDim2.new(1, -120, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Color.Outline,
		Text = "",
		ZIndex = 22,
	})
	benchDesc = UI.text({
		Name = "Desc",
		Parent = bench,
		Role = "Body",
		TextSize = 14,
		Position = UDim2.fromOffset(110, 70),
		Size = UDim2.new(1, -120, 0, 32),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextColor3 = UI.Color.TextDim,
		Text = "",
		ZIndex = 22,
	})
	-- Now -> next, the biggest numbers on the bench.
	local stats = UI.new("Frame", {
		Name = "Stats",
		Parent = bench,
		Position = UDim2.fromOffset(14, 114),
		Size = UDim2.new(1, -28, 0, 44),
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
			Role = "Title",
			TextSize = 24,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 30),
			TextColor3 = color,
			Text = "",
			ZIndex = 22,
		})
	end
	benchNow = stat(1, UI.Color.TextDim)
	benchArrow = stat(2, UI.Color.TextMuted)
	benchArrow.Text = "→"
	benchNext = stat(3, UI.Color.Safe)
	benchBuy = UI.button({
		Name = "Buy",
		Parent = bench,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(1, -28, 0, math.min(UI.buttonSize(), 58)),
		TextSize = 20,
		Color = UI.Color.Buy,
		ZIndex = 22,
	})
	benchBuy.Activated:Connect(function()
		-- Unaffordable presses still go to the server, which explains what's missing.
		Remotes.get("BuyUpgrade"):FireServer(selected)
	end)
end

local shownIcon: string? = nil

function Shop.refresh()
	if not state then
		return
	end
	for id, tile in tiles do
		local level = state.Upgrades[id] or 0
		for i, pip in tile.Pips do
			pip.BackgroundColor3 = if i <= level then UI.Color.Outline else UI.Color.Disabled
		end
		local active = id == selected
		tile.Stroke.Transparency = if active then 0 else 0.75
		tile.Stroke.Thickness = if active then 2 else 1.5
		tile.Frame.BackgroundTransparency = if active then 0 else 0.4
	end

	local def = Config.Upgrades[selected]
	local level = state.Upgrades[selected] or 0
	if shownIcon ~= selected then
		shownIcon = selected
		for _, child in benchIconHolder:GetChildren() do
			if not child:IsA("UICorner") then
				child:Destroy()
			end
		end
		local icon = UI.upgradeIcon(selected, benchIconHolder, 64)
		icon.Position = UDim2.fromOffset(10, 10)
		icon.ZIndex = 23
	end
	benchTitle.Text = string.upper(def.DisplayName)
	benchDesc.Text = def.Description
	benchLevel.Text = ("LEVEL %d / %d"):format(level, #def.Costs)
	if benchBuy.Text == "UPGRADED!" then
		return
	end
	local cost = def.Costs[level + 1]
	benchNow.Text = formatValue(selected, def.Values[level + 1])
	if cost then
		benchNext.Text = formatValue(selected, def.Values[level + 2])
		benchArrow.Visible = true
		benchNext.Visible = true
		local short = cost - state.Coins
		if short > 0 then
			benchBuy.Text = ("%s COINS  ·  NEED %s MORE"):format(formatCoins(cost), formatCoins(short))
			benchBuy:SetAttribute("Disabled", true)
		else
			benchBuy.Text = ("UPGRADE  ·  %s COINS"):format(formatCoins(cost))
			benchBuy:SetAttribute("Disabled", false)
		end
	else
		benchArrow.Visible = false
		benchNext.Visible = false
		benchBuy.Text = "FULLY UPGRADED"
		benchBuy:SetAttribute("Disabled", true)
	end
end

-- The server confirmed a level-up: light the new pip, flash the bench.
local function celebrate(id: string, level: number)
	local tile = tiles[id]
	local pip = tile and tile.Pips[level]
	if pip then
		UI.pop(pip:FindFirstChildOfClass("UIScale") :: UIScale, 1.8, 0.35)
	end
	if id ~= selected then
		return
	end
	benchStroke.Color = UI.Color.Safe
	benchStroke.Transparency = 0
	benchStroke.Thickness = 3
	UI.pop(benchScale, 1.03, 0.3)
	benchBuy.Text = "UPGRADED!"
	task.delay(0.9, function()
		benchStroke.Color = UI.Color.Outline
		benchStroke.Transparency = 0.5
		benchStroke.Thickness = 1.5
		if benchBuy.Text == "UPGRADED!" then
			benchBuy.Text = ""
			Shop.refresh()
		end
	end)
end

function Shop.setState(s: any)
	local previous = state
	state = s
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
	Shop.refresh()
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

function Shop.init(root: Frame, h: Hooks)
	hooks = h
	modal = UI.modal(root, "Shop", "GEAR SHOP", Vector2.new(640, 380))
	local rack = UI.new("ScrollingFrame", {
		Name = "List",
		Parent = modal.Content,
		Size = UDim2.new(0.36, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 21,
	}, { UI.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	buildBench(modal.Content)

	for i, id in Config.UpgradeOrder do
		tiles[id] = makeTile(rack, id, i)
	end

	-- Robux items (only once their IDs are configured) go under the rack as plain buttons.
	local order = 100
	local player = Players.LocalPlayer
	local function robuxButton(label: string, prompt: () -> ())
		order += 1
		local b = UI.button({
			Name = label,
			Parent = rack,
			LayoutOrder = order,
			Size = UDim2.new(1, -6, 0, 44),
			Text = label,
			TextSize = 15,
			Color = UI.Color.Slate,
			ZIndex = 22,
		})
		b.Activated:Connect(function()
			if not hooks.CanSave() then
				hooks.Notify("Purchases are paused: your progress can't be saved right now.", UI.Color.Danger)
				return
			end
			prompt()
		end)
	end
	for _, pass in Config.GamePasses do
		if pass.Id ~= 0 then
			robuxButton(pass.DisplayName .. "  (Pass)", function()
				MarketplaceService:PromptGamePassPurchase(player, pass.Id)
			end)
		end
	end
	for _, product in Config.DevProducts do
		if product.Id ~= 0 then
			robuxButton(product.DisplayName, function()
				MarketplaceService:PromptProductPurchase(player, product.Id)
			end)
		end
	end
end

return Shop
