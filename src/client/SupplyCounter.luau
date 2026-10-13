-- @file Supply Counter: optional Robux tickets
-- @domain salvage-economy
-- @status stable
-- @see [[V3-MONETIZATION]]
-- The Supply Counter: the optional Robux side of the Gear Shop (the Equipment workbench stays
-- coins-only). One supply-order ticket per catalog item (Config.DevProducts / GamePasses) that
-- states exactly what you get, the price, whether it's repeatable or permanent, and where the
-- purchase is: waiting for Roblox's window, delivering, delivered (server-confirmed), cancelled.
--
-- The client only asks Roblox to show its purchase window. Coins are granted by the server from
-- Roblox's receipt and announced here only after they're saved (PurchaseDelivered); the client
-- never adds coins itself. Nothing here pops up on its own: it's only seen inside the shop.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage.Shared:WaitForChild("Remotes"))
local UI = require(script.Parent:WaitForChild("UI"))

local SupplyCounter = {}
local M = UI.Mat

export type Hooks = {
	Notify: (text: string, color: Color3?) -> (),
}

type Item = {
	Key: string,
	Kind: "Product" | "Pass",
	Def: any,
	Button: TextButton,
	Price: TextLabel,
	PriceNote: TextLabel,
	State: string,
	Token: number,
}
local items: { [string]: Item } = {}
local state: any = nil
local DELIVERY_PATIENCE = 20 -- seconds before "still processing" (it still arrives later)

local GREEN = Color3.fromRGB(58, 150, 72)

local function available(item: Item): (boolean, string?)
	if not Config.PurchasesEnabled or item.Def.Id == 0 then
		return false, "NOT ON SALE YET"
	end
	if state and state.CanSave == false then
		return false, "PAUSED: SAVES OFF"
	end
	return true, nil
end

local function render(item: Item)
	local b = item.Button
	local s = item.State
	local ok, reason = available(item)
	local owned = item.Kind == "Pass" and state and state.OwnsHeavyDuty
	local text, color, disabled
	if owned then
		text, color, disabled = "OWNED", GREEN, true
	elseif s == "waiting" then
		text, color, disabled = "CHECK THE ROBLOX WINDOW", UI.Color.Slate, true
	elseif s == "delivering" then
		text, color, disabled = "DELIVERING...", UI.Color.Slate, true
	elseif s == "slow" then
		text, color, disabled = "STILL PROCESSING: IT WILL ARRIVE", UI.Color.Slate, true
	elseif s == "delivered" then
		text = if item.Kind == "Pass" then "UNLOCKED!" else ("DELIVERED +%s"):format(UI.comma(item.Def.Coins))
		color, disabled = GREEN, true
	elseif s == "cancelled" then
		text, color, disabled = "CANCELLED", UI.Color.Slate, true
	elseif not ok then
		text, color, disabled = reason :: string, UI.Color.Disabled, true
	else
		text, color, disabled = "BUY", M.Orange, false
	end
	b.Text = text
	UI.setButtonColor(b, color)
	b:SetAttribute("Disabled", disabled)
	b:SetAttribute("State", if owned then "owned" else s)
end

local function stateOf(item: Item): string
	return item.State
end

local function setState(item: Item, s: string, holdSeconds: number?)
	item.Token += 1
	local token = item.Token
	item.State = s
	render(item)
	if holdSeconds then
		task.delay(holdSeconds, function()
			if item.Token == token then
				item.State = "idle"
				render(item)
			end
		end)
	end
end

local function ticket(parent: Instance, order: number, key: string, kind: "Product" | "Pass", def: any): Item
	local card = UI.new("Frame", {
		Name = key,
		Parent = parent,
		LayoutOrder = order,
		Size = UDim2.new(0.25, -6, 1, 0),
		BackgroundColor3 = M.Manila,
		BorderSizePixel = 0,
		ZIndex = 22,
	}, { UI.corner(8), UI.stroke(M.KraftEdge, 2) })
	UI.punchHole(card, UDim2.new(0.5, 0, 0, 12), 11, 23)
	-- Repeatable / permanent on coloured tape.
	local band = UI.new("Frame", {
		Parent = card,
		Position = UDim2.fromOffset(6, 24),
		Size = UDim2.new(1, -12, 0, 22),
		Rotation = -1,
		BackgroundColor3 = if kind == "Pass"
			then Color3.fromRGB(80, 150, 230)
			else Color3.fromRGB(110, 190, 100),
		BorderSizePixel = 0,
		ZIndex = 23,
	})
	UI.text({
		Parent = band,
		Font = UI.Font.Mono,
		TextSize = 12,
		Size = UDim2.fromScale(1, 1),
		TextColor3 = M.Marker,
		Text = if kind == "Pass" then "PERMANENT" else "REPEATABLE",
		ZIndex = 24,
	})
	-- What you get, biggest thing on the ticket.
	local icon = UI.new("Frame", {
		Parent = card,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 54),
		Size = UDim2.fromOffset(48, 40),
		BackgroundTransparency = 1,
		ZIndex = 23,
	})
	if kind == "Pass" then
		local bag = UI.bagIcon(icon, 40)
		bag.Position = UDim2.fromOffset(4, 0)
	else
		local stacks = if def.Coins >= 5000 then 3 elseif def.Coins >= 2000 then 2 else 1
		for i = 1, stacks do
			local c = UI.coinIcon(icon, 28)
			c.Position = UDim2.fromOffset(10 + (i - 2) * 9 + (if stacks == 1 then 9 else 0), 12 - (i - 1) * 6)
		end
	end
	for _, d in icon:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = 24
		end
	end
	UI.text({
		Parent = card,
		Font = UI.Font.Mono,
		TextSize = 30,
		Position = UDim2.fromOffset(0, 96),
		Size = UDim2.new(1, 0, 0, 32),
		TextColor3 = M.Marker,
		Text = if kind == "Pass" then ("+%d"):format(def.BonusCapacity) else UI.comma(def.Coins),
		ZIndex = 23,
	})
	UI.text({
		Parent = card,
		Font = UI.Font.Label,
		TextSize = 12,
		Position = UDim2.fromOffset(0, 126),
		Size = UDim2.new(1, 0, 0, 14),
		TextColor3 = M.Pencil,
		Text = if kind == "Pass" then "BAG SLOTS, FOREVER" else "COINS",
		ZIndex = 23,
	})
	UI.text({
		Parent = card,
		Font = UI.Font.Title,
		TextSize = 16,
		Position = UDim2.fromOffset(6, 144),
		Size = UDim2.new(1, -12, 0, 20),
		TextColor3 = M.Marker,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = def.DisplayName,
		ZIndex = 23,
	})
	-- Price sticker.
	local sticker = UI.new("Frame", {
		Parent = card,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 168),
		Size = UDim2.fromOffset(86, 30),
		Rotation = -4,
		BackgroundColor3 = Color3.fromRGB(250, 248, 238),
		BorderSizePixel = 0,
		ZIndex = 23,
	}, { UI.corner(15), UI.stroke(M.Marker, 2) })
	local price = UI.text({
		Parent = sticker,
		Font = UI.Font.Mono,
		TextSize = 16,
		Size = UDim2.fromScale(1, 1),
		TextColor3 = M.Marker,
		Text = ("R$ %d"):format(def.RobuxPrice),
		ZIndex = 24,
	})
	local priceNote = UI.text({
		Parent = card,
		Font = UI.Font.Label,
		TextSize = 10,
		Position = UDim2.fromOffset(0, 200),
		Size = UDim2.new(1, 0, 0, 12),
		TextColor3 = M.Pencil,
		Text = if def.Id == 0 then "planned price" else "",
		ZIndex = 23,
	})
	local button = UI.button({
		Name = "Buy",
		Parent = card,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -12, 0, math.min(UI.buttonSize(), 48)),
		TextSize = 12,
		Color = M.Orange,
		ZIndex = 24,
	})
	button.Font = UI.Font.Mono
	local item: Item = {
		Key = key,
		Kind = kind,
		Def = def,
		Button = button,
		Price = price,
		PriceNote = priceNote,
		State = "idle",
		Token = 0,
	}
	return item
end

-- The real price, from Roblox, once the product exists.
local function loadPrice(item: Item)
	if item.Def.Id == 0 then
		return
	end
	task.spawn(function()
		local ok, info = pcall(
			MarketplaceService.GetProductInfo,
			MarketplaceService,
			item.Def.Id,
			if item.Kind == "Pass" then Enum.InfoType.GamePass else Enum.InfoType.Product
		)
		if ok and info and type(info.PriceInRobux) == "number" then
			item.Price.Text = ("R$ %d"):format(info.PriceInRobux)
			item.PriceNote.Text = ""
		end
	end)
end

local function buy(item: Item, hooks: Hooks)
	local ok, reason = available(item)
	if not ok then
		hooks.Notify(
			if reason == "NOT ON SALE YET"
				then "This isn't on sale yet."
				else "Purchases are paused: your progress can't be saved right now.",
			UI.Color.Warn
		)
		return
	end
	if item.State ~= "idle" and item.State ~= "cancelled" then
		return
	end
	setState(item, "waiting")
	local player = Players.LocalPlayer
	if item.Kind == "Pass" then
		MarketplaceService:PromptGamePassPurchase(player, item.Def.Id)
	else
		MarketplaceService:PromptProductPurchase(player, item.Def.Id)
	end
end

function SupplyCounter.setState(s: any)
	state = s
	for _, item in items do
		render(item)
	end
end

function SupplyCounter.build(parent: Instance, hooks: Hooks): Frame
	local view = UI.new("Frame", {
		Name = "SupplyCounter",
		Parent = parent,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 21,
	})
	local row = UI.new("Frame", {
		Name = "Tickets",
		Parent = view,
		Size = UDim2.new(1, 0, 1, -28),
		BackgroundTransparency = 1,
		ZIndex = 21,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local ordered = {}
	for key, def in Config.DevProducts do
		table.insert(ordered, { key, def })
	end
	table.sort(ordered, function(a, b)
		return a[2].Order < b[2].Order
	end)
	for i, entry in ordered do
		items[entry[1]] = ticket(row, i, entry[1], "Product", entry[2])
	end
	items.HeavyDuty = ticket(row, 10, "HeavyDuty", "Pass", Config.GamePasses.HeavyDuty)
	UI.text({
		Name = "Footnote",
		Parent = view,
		Font = UI.Font.Label,
		TextSize = 12,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 24),
		TextWrapped = true,
		TextColor3 = M.Paper,
		Text = "Optional. Coins arrive after Roblox confirms the payment, even if you leave mid-purchase. Equipment can always be earned by salvaging.",
		ZIndex = 22,
	})

	for _, item in items do
		item.Button.Activated:Connect(function()
			buy(item, hooks)
		end)
		loadPrice(item)
		render(item)
	end

	-- Roblox's purchase window closed (client-side). Not trusted for rewards: if bought, wait
	-- for the server to confirm delivery.
	local localId = Players.LocalPlayer.UserId
	local function closed(kind: string, id: number, purchased: boolean)
		for _, item in items do
			if item.Kind == kind and item.Def.Id == id and item.State == "waiting" then
				if purchased then
					setState(item, "delivering")
					local token = item.Token
					task.delay(DELIVERY_PATIENCE, function()
						if item.Token == token and stateOf(item) == "delivering" then
							setState(item, "slow", 8)
						end
					end)
				else
					setState(item, "cancelled", 2)
				end
			end
		end
	end
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
		if userId == localId then
			closed("Product", productId, purchased)
		end
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if player == Players.LocalPlayer then
			closed("Pass", passId, purchased)
		end
	end)
	-- The server saved the reward.
	Remotes.get("PurchaseDelivered").OnClientEvent:Connect(function(info)
		local item = info and items[info.Key]
		if item then
			setState(item, "delivered", 3)
		end
	end)
	return view
end

return SupplyCounter
