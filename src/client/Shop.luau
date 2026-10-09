-- The Gear Shop: upgrade rows with level pips, current -> next values and a price button.
-- Buying asks the server (BuyUpgrade); the row only celebrates once the server's player
-- state shows the new level, so the UI never runs ahead of what was actually bought.

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

type Row = {
	Frame: Frame,
	Stroke: UIStroke,
	Info: TextLabel,
	Buy: TextButton,
	Pips: { Frame },
	Level: number?,
}
local rows: { [string]: Row } = {}

local function formatValue(id: string, value: any): string
	if id == "Backpack" then
		return ("%d slots"):format(value)
	elseif id == "Boots" then
		return ("speed %d"):format(value)
	elseif value == 0 then
		return "no protection"
	end
	return ("-%d%% damage"):format(math.floor(value * 100 + 0.5))
end

local function makeRow(
	list: Instance,
	name: string,
	order: number,
	title: string,
	desc: string,
	levels: number
): Row
	local frame = UI.new("Frame", {
		Name = name,
		Parent = list,
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 74),
		BackgroundColor3 = UI.Color.PlateLight,
		BorderSizePixel = 0,
	}, { UI.corner(UI.Radius.Panel) })
	local stroke = UI.stroke(UI.Color.Outline, 2)
	stroke.Parent = frame
	local buttonWidth = 132
	UI.text({
		Parent = frame,
		Role = "Title",
		TextSize = 19,
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -buttonWidth - 30, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = title,
	})
	UI.text({
		Parent = frame,
		Role = "Body",
		TextSize = 14,
		Position = UDim2.fromOffset(12, 28),
		Size = UDim2.new(1, -buttonWidth - 30, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Color.TextDim,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = desc,
	})
	local info = UI.text({
		Name = "Info",
		Parent = frame,
		Role = "Label",
		TextSize = 14,
		Position = UDim2.fromOffset(12, 47),
		Size = UDim2.new(1, -buttonWidth - 30 - levels * 14, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Color.Safe,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	})
	-- Level pips, bottom right of the text column.
	local pips = {}
	for i = 1, levels do
		local pip = UI.new("Frame", {
			Name = "Pip" .. i,
			Parent = frame,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -buttonWidth - 20 - (levels - i) * 14, 0, 51),
			Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = UI.Color.Disabled,
			BorderSizePixel = 0,
		}, { UI.corner(3) })
		UI.new("UIScale", { Parent = pip })
		table.insert(pips, pip)
	end
	local buy = UI.button({
		Name = "Buy",
		Parent = frame,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(buttonWidth, math.min(UI.buttonSize(), 62)),
		TextSize = 17,
		Color = UI.Color.Buy,
	})
	return { Frame = frame, Stroke = stroke, Info = info, Buy = buy, Pips = pips }
end

-- The server confirmed a level-up: light the new pip and flash the row.
local function celebrate(row: Row, level: number)
	local pip = row.Pips[level]
	if pip then
		UI.pop(pip:FindFirstChildOfClass("UIScale") :: UIScale, 1.8, 0.35)
	end
	row.Stroke.Color = UI.Color.Safe
	row.Stroke.Thickness = 3
	local label = row.Buy.Text
	row.Buy.Text = "UPGRADED!"
	task.delay(0.9, function()
		row.Stroke.Color = UI.Color.Outline
		row.Stroke.Thickness = 2
		if row.Buy.Text == "UPGRADED!" then
			row.Buy.Text = label
			Shop.refresh()
		end
	end)
end

function Shop.refresh()
	if not state then
		return
	end
	for id, row in rows do
		local def = Config.Upgrades[id]
		local level = state.Upgrades[id] or 0
		for i, pip in row.Pips do
			pip.BackgroundColor3 = if i <= level then UI.Color.Safe else UI.Color.Disabled
		end
		local cost = def.Costs[level + 1]
		if row.Buy.Text == "UPGRADED!" then
			continue
		end
		if cost then
			row.Info.Text = ("%s  ->  %s"):format(
				formatValue(id, def.Values[level + 1]),
				formatValue(id, def.Values[level + 2])
			)
			local short = cost - state.Coins
			row.Buy.Text = if short > 0
				then ("%d coins\nneed %d more"):format(cost, short)
				else ("%d coins"):format(cost)
			row.Buy:SetAttribute("Disabled", short > 0)
		else
			row.Info.Text = ("%s  (max level)"):format(formatValue(id, def.Values[level + 1]))
			row.Buy.Text = "MAXED"
			row.Buy:SetAttribute("Disabled", true)
		end
	end
end

function Shop.setState(s: any)
	local previous = state
	state = s
	for id, row in rows do
		local level = s.Upgrades[id] or 0
		if previous and row.Level and level > row.Level then
			celebrate(row, level)
		end
		row.Level = level
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
	modal = UI.modal(root, "Shop", "GEAR SHOP", Vector2.new(560, 360))
	local list = UI.new("ScrollingFrame", {
		Name = "List",
		Parent = modal.Content,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 21,
	}, { UI.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })

	for i, id in Config.UpgradeOrder do
		local def = Config.Upgrades[id]
		local row = makeRow(list, id, i, def.DisplayName, def.Description, #def.Costs)
		rows[id] = row
		row.Buy.Activated:Connect(function()
			-- Unaffordable presses still go to the server, which explains what's missing.
			Remotes.get("BuyUpgrade"):FireServer(id)
		end)
	end

	-- Robux items only show once their IDs are configured.
	local order = 100
	local function robuxRow(name: string, desc: string, label: string, prompt: () -> ())
		order += 1
		local row = makeRow(list, name, order, name, desc, 0)
		row.Buy.Text = label
		row.Info.Text = ""
		row.Buy.Activated:Connect(function()
			if not hooks.CanSave() then
				hooks.Notify("Purchases are paused: your progress can't be saved right now.", UI.Color.Danger)
				return
			end
			prompt()
		end)
	end
	local player = Players.LocalPlayer
	for _, pass in Config.GamePasses do
		if pass.Id ~= 0 then
			robuxRow(pass.DisplayName, pass.Description, "R$ Pass", function()
				MarketplaceService:PromptGamePassPurchase(player, pass.Id)
			end)
		end
	end
	for _, product in Config.DevProducts do
		if product.Id ~= 0 then
			robuxRow(product.DisplayName, "One-time purchase", "R$ Buy", function()
				MarketplaceService:PromptProductPurchase(player, product.Id)
			end)
		end
	end
end

return Shop
