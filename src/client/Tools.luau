-- @file Gear Shop Tools tab: permanent coin tools
-- @domain salvage-economy
-- @status stable
-- @see [[Shop.luau]]
-- @see [[V3-SUPPLY-DEPOT]]
-- The Tools tab of the Gear Shop pegboard: permanent unlocks bought with earned coins (the
-- Salvage Detector first). Same Workshop dressing as the Equipment workbench: a tool tag on the
-- left, a spec sheet on the right with what it does, the price sticker and one BUY button.
-- Buying asks the server (BuyTool); the sheet only shows OWNED once the server's player state
-- says so.
-- V4 M3: salvage licences hang here too (ids "License:<id>"). A licence's sheet is a checklist of
-- its requirements with live progress (rank, extractions) and its price; buying asks the server
-- (BuyLicense), which checks everything again.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Bands = require(ReplicatedStorage.Shared:WaitForChild("Bands"))
local BigMoney = require(ReplicatedStorage.Shared:WaitForChild("BigMoney"))
local Progression = require(ReplicatedStorage.Shared:WaitForChild("Progression"))
local Remotes = require(ReplicatedStorage.Shared:WaitForChild("Remotes"))
local UI = require(script.Parent:WaitForChild("UI"))

local Tools = {}
local M = UI.Mat

local state: any = nil
local selected = Config.ToolOrder[1]
local view: Frame
local tags: { [string]: { Frame: TextButton, Stroke: UIStroke, Price: Frame, PriceText: TextLabel } } = {}
local title: TextLabel
local desc: TextLabel
local facts: TextLabel
local wallet: TextLabel
local buy: TextButton
local stamp: Frame
local stampScale: UIScale
local stampText: TextLabel
local iconPlate: Frame
local shownIcon: string? = nil

local ENTRIES = table.clone(Config.ToolOrder)
for _, id in Bands.LicenseOrder do
	table.insert(ENTRIES, "License:" .. id)
end

local function licenseOf(id: string): Bands.License?
	local key = id:match("^License:(.+)$")
	return if key then Bands.Licenses[key] else nil
end

-- A licence card: a little ID badge with the licence's tag, coloured by band.
local BAND_COLORS = { [2] = Color3.fromRGB(240, 196, 70), [3] = Color3.fromRGB(190, 150, 255) }
local function licenseIcon(parent: Instance, size: number, license: Bands.License): Frame
	local card = UI.new("Frame", {
		Name = "LicenseIcon",
		Parent = parent,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size * 0.72),
		BackgroundColor3 = BAND_COLORS[license.Band] or Color3.fromRGB(240, 196, 70),
		BorderSizePixel = 0,
	}, { UI.corner(4), UI.stroke(M.Marker, 2.5) })
	UI.new("Frame", {
		Parent = card,
		Position = UDim2.fromScale(0.1, 0.18),
		Size = UDim2.fromScale(0.28, 0.5),
		BackgroundColor3 = M.TinDark,
		BorderSizePixel = 0,
	}, { UI.corner(2) })
	UI.text({
		Parent = card,
		Font = UI.Font.Mono,
		TextScaled = true,
		Position = UDim2.fromScale(0.44, 0.18),
		Size = UDim2.fromScale(0.5, 0.5),
		TextColor3 = M.Marker,
		Text = license.Tag,
	})
	return card
end

local function iconFor(id: string, parent: Instance, size: number): Frame
	local license = licenseOf(id)
	return if license then licenseIcon(parent, size, license) else Tools.detectorIcon(parent, size)
end

-- A dial with a needle and two blips: reads as "detector" without an image asset.
function Tools.detectorIcon(parent: Instance, size: number): Frame
	local holder = UI.new("Frame", {
		Name = "DetectorIcon",
		Parent = parent,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Color3.fromRGB(46, 58, 52),
		BorderSizePixel = 0,
	}, { UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), UI.stroke(M.Marker, 2.5) })
	UI.new("Frame", {
		Parent = holder,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 2, 0.42, 0),
		Rotation = 35,
		BackgroundColor3 = Color3.fromRGB(150, 230, 160),
		BorderSizePixel = 0,
	})
	for _, p in { Vector2.new(0.7, 0.3), Vector2.new(0.32, 0.62) } do
		UI.new("Frame", {
			Parent = holder,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(p.X, p.Y),
			Size = UDim2.fromOffset(size * 0.14, size * 0.14),
			BackgroundColor3 = M.Orange,
			BorderSizePixel = 0,
		}, { UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	end
	return holder
end

local function owned(id: string): boolean
	local license = licenseOf(id)
	if license then
		local held = state and state.Licenses
		return type(held) == "table" and held[license.Id] == true
	end
	local tools = state and state.Tools
	return tools ~= nil and type(tools.Owned) == "table" and tools.Owned[id] == true
end

local function costOf(id: string): number
	local license = licenseOf(id)
	return if license then license.Cost else Config.Tools[id].Cost
end

-- One line per requirement: done or progress, from the server's own numbers (the same
-- Bands.progressOf the server checks with).
local function checklist(license: Bands.License): (string, boolean)
	local rank = Progression.rankFor(state.Rep and state.Rep.XP or 0)
	local collection = state.Collection
	local progress: Bands.Progress = {
		Rank = rank.Index,
		Extractions = state.Records and state.Records.Extractions or 0,
		Coins = state.Coins,
		Owned = false,
		Found = Bands.foundByClass(collection and collection.Found, Config.Loot),
		Records = state.Records,
	}
	local lines, all = {}, true
	for _, r in license.Requirements do
		local have, need = Bands.progressOf(r, progress)
		local done = have >= need
		all = all and done
		local show = if r.Kind == "Rank" then rank.Title else ("%d / %d"):format(math.min(have, need), need)
		table.insert(lines, ("%s  %s  (%s)"):format(if done then "DONE" else "TODO", r.Text, show))
	end
	return table.concat(lines, "\n"), all
end

function Tools.refresh()
	if not state or not view then
		return
	end
	for id, tag in tags do
		local cost = costOf(id)
		local have = owned(id)
		tag.PriceText.Text = if have
			then "OWNED"
			elseif cost < 100000 then UI.comma(cost)
			else BigMoney.compact(cost)
		tag.Price.BackgroundColor3 = if have
			then Color3.fromRGB(80, 170, 90)
			elseif BigMoney.gte(state.Coins, BigMoney.of(cost)) then M.Orange
			else M.Muted
		local active = id == selected
		tag.Stroke.Color = if active then M.Orange else M.KraftEdge
		tag.Stroke.Thickness = if active then 4 else 2
	end
	if shownIcon ~= selected then
		shownIcon = selected
		for _, child in iconPlate:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local icon = iconFor(selected, iconPlate, 56)
		for _, d in icon:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex = 24
			end
		end
		icon.ZIndex = 23
	end
	local license = licenseOf(selected)
	local cost = costOf(selected)
	local ready = true
	if license then
		title.Text = license.DisplayName
		desc.Text = license.Description
		local text, all = checklist(license)
		facts.Text = text
		-- A licence has a longer description and a two-line checklist: give both room, and keep
		-- the LICENSED stamp clear of them.
		desc.Size = UDim2.new(1, -112, 0, 100)
		facts.Position = UDim2.fromOffset(14, 158)
		facts.Size = UDim2.new(1, -28, 0, 20 * #license.Requirements)
		stamp.Position = UDim2.new(0.5, 0, 0, 216 + 20 * #license.Requirements)
		facts.TextColor3 = if all then Color3.fromRGB(34, 130, 56) else M.RedPen
		ready = all
		stampText.Text = "LICENSED"
	else
		local def = Config.Tools[selected]
		title.Text = def.DisplayName
		desc.Text = def.Description
		facts.Text = ("RANGE %d STUDS  ·  NEAREST %d  ·  PERMANENT"):format(def.Range, def.MaxBlips)
		desc.Size = UDim2.new(1, -112, 0, 58)
		facts.Position = UDim2.fromOffset(14, 116)
		facts.Size = UDim2.new(1, -28, 0, 18)
		stamp.Position = UDim2.new(0.5, 0, 0, 168)
		facts.TextColor3 = Color3.fromRGB(34, 130, 56)
		stampText.Text = "OWNED"
	end
	wallet.Text = ("YOU HAVE %s COINS"):format(BigMoney.full(state.Coins))
	stamp.Visible = owned(selected)
	if owned(selected) then
		buy.Text = if license
			then "LICENSED  ·  INDUSTRIAL SALVAGE OPEN"
			else "OWNED  ·  ACTIVE ON YOUR HUD"
		buy:SetAttribute("Disabled", true)
	elseif not ready then
		buy.Text = "FINISH THE CHECKLIST FIRST"
		buy:SetAttribute("Disabled", true)
	elseif BigMoney.lt(state.Coins, BigMoney.of(cost)) then
		buy.Text = ("NEED %s MORE"):format(
			BigMoney.full(BigMoney.sub(BigMoney.of(cost), state.Coins) :: string)
		)
		buy:SetAttribute("Disabled", true)
	else
		buy.Text = ("BUY  ·  %s COINS"):format(BigMoney.full(cost))
		buy:SetAttribute("Disabled", false)
	end
end

function Tools.setState(s: any)
	local had = owned(selected)
	state = s
	if not had and owned(selected) and stamp then
		-- The server confirmed the purchase: stamp the sheet.
		stamp.Visible = true
		if UI.reduced() then
			stampScale.Scale = 1
		else
			stampScale.Scale = 1.8
			UI.tween(stampScale, 0.14, { Scale = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
	end
	Tools.refresh()
end

local function makeTag(rack: Instance, id: string, order: number)
	local license = licenseOf(id)
	local def = if license then license else Config.Tools[id]
	local holder = UI.new("Frame", {
		Name = id,
		Parent = rack,
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 84),
		BackgroundTransparency = 1,
		ZIndex = 21,
	})
	local frame = UI.new("TextButton", {
		Name = "Tag",
		Parent = holder,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -8, 1, -8),
		Rotation = if UI.reduced() then 0 else -1.2,
		BackgroundColor3 = M.Manila,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		ZIndex = 22,
	}, { UI.corner(8) })
	local stroke = UI.stroke(M.KraftEdge, 2)
	stroke.Parent = frame
	UI.punchHole(frame, UDim2.fromOffset(14, 14), 11, 23)
	local icon = iconFor(id, frame, 44)
	icon.Position = UDim2.fromOffset(40, 42)
	for _, d in icon:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = 24
		end
	end
	icon.ZIndex = 23
	UI.text({
		Parent = frame,
		Font = UI.Font.Title,
		TextSize = 15,
		Position = UDim2.fromOffset(70, 6),
		Size = UDim2.new(1, -156, 0, 38),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextColor3 = M.Marker,
		Text = def.DisplayName,
		ZIndex = 23,
	})
	UI.text({
		Parent = frame,
		Font = UI.Font.Label,
		TextSize = 11,
		Position = UDim2.fromOffset(70, 50),
		Size = UDim2.new(1, -150, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = M.Pencil,
		Text = if license then "SALVAGE LICENSE" else "PERMANENT TOOL",
		ZIndex = 23,
	})
	local price = UI.new("Frame", {
		Name = "Price",
		Parent = frame,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(70, 44),
		Rotation = -6,
		BackgroundColor3 = M.Orange,
		BorderSizePixel = 0,
		ZIndex = 23,
	}, { UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	local priceText = UI.text({
		Parent = price,
		Font = UI.Font.Mono,
		TextSize = 15,
		Size = UDim2.fromScale(1, 1),
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
		ZIndex = 24,
	})
	frame.Activated:Connect(function()
		selected = id
		Tools.refresh()
	end)
	tags[id] = { Frame = frame, Stroke = stroke, Price = price, PriceText = priceText }
end

function Tools.build(parent: Instance): Frame
	view = UI.new("Frame", {
		Name = "Tools",
		Parent = parent,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 21,
	})
	local rack = UI.new("ScrollingFrame", {
		Name = "List",
		Parent = view,
		Size = UDim2.new(0.4, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 21,
	}, { UI.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
	for i, id in ENTRIES do
		makeTag(rack, id, i)
	end

	local sheet = UI.new("Frame", {
		Name = "Sheet",
		Parent = view,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.new(0.6, -4, 1, -8),
		BackgroundColor3 = M.Paper,
		BorderSizePixel = 0,
		ZIndex = 21,
	}, { UI.corner(3), UI.stroke(M.KraftEdge, 2) })
	UI.tape(sheet, UDim2.new(0.5, 0, 0, 0), Vector2.new(90, 20), 2, nil, 26)
	iconPlate = UI.new("Frame", {
		Name = "Icon",
		Parent = sheet,
		Position = UDim2.fromOffset(14, 18),
		Size = UDim2.fromOffset(76, 76),
		BackgroundColor3 = M.Manila,
		BorderSizePixel = 0,
		ZIndex = 22,
	}, { UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), UI.stroke(M.KraftEdge, 2) })
	title = UI.text({
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
	desc = UI.text({
		Name = "Desc",
		Parent = sheet,
		Font = UI.Font.Body,
		TextSize = 14,
		Position = UDim2.fromOffset(102, 50),
		Size = UDim2.new(1, -112, 0, 58),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextColor3 = M.Pencil,
		Text = "",
		ZIndex = 22,
	})
	facts = UI.text({
		Name = "Facts",
		Parent = sheet,
		Font = UI.Font.Mono,
		TextSize = 13,
		Position = UDim2.fromOffset(14, 116),
		Size = UDim2.new(1, -28, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(34, 130, 56),
		Text = "",
		ZIndex = 22,
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
		TextSize = 18,
		Color = UI.Color.Buy,
		ZIndex = 22,
	})
	buy.Font = UI.Font.Mono
	buy.Activated:Connect(function()
		if owned(selected) then
			return
		end
		-- Unaffordable presses still go to the server, which explains what's missing.
		local license = licenseOf(selected)
		if license then
			Remotes.get("BuyLicense"):FireServer(license.Id)
		else
			Remotes.get("BuyTool"):FireServer(selected)
		end
	end)
	stamp = UI.new("Frame", {
		Name = "Owned",
		Parent = sheet,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 168),
		Size = UDim2.fromOffset(150, 44),
		Rotation = -10,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 30,
	}, { UI.corner(6), UI.stroke(Color3.fromRGB(34, 130, 56), 4) })
	stampText = UI.text({
		Parent = stamp,
		Font = UI.Font.Mono,
		TextSize = 24,
		Size = UDim2.fromScale(1, 1),
		TextColor3 = Color3.fromRGB(34, 130, 56),
		Text = "OWNED",
		ZIndex = 30,
	})
	stampScale = UI.new("UIScale", { Parent = stamp })
	return view
end

return Tools
