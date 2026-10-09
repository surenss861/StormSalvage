-- Where every message goes, and which one wins. One slot per kind of message so nothing
-- overlaps (see docs/ui-design-spec.md, "Notifications"):
--
--   P4  danger(text)      Alert slot under the storm strip. Personal danger, always shown.
--   P2  card(spec)        Event card slot, left side. Finds, bag full, sale receipts.
--   P1  feed(text)        Bottom centre, above the hint. Short server notices, max 3.
--   P0  location(...)     Alert slot, only while there's no danger. District titles.
--   P0  setHint(text)     Bottom centre. Hidden while danger, a modal or a storm is up.
--
-- This module only draws; it never decides what the player has or earns.

local RunService = game:GetService("RunService")

local UI = require(script.Parent:WaitForChild("UI"))

local Notifications = {}

local root: Frame
local alertSlot: Frame
local alertLabel: TextLabel
local alertSub: TextLabel
local alertStroke: UIStroke
local feedHolder: Frame
local hintLabel: TextLabel
local hintPlate: Frame
local cardSlot: GuiObject
local cardScale: UIScale

---------------------------------------------------------------------------- Event cards

export type CardSpec = {
	Priority: number, -- 1 bag full, 2 rare, 3 epic, 4 Storm Core, 5 sale receipt
	Accent: Color3,
	Height: number,
	Seconds: number,
	Build: (card: Frame) -> (),
}

local CARD_WIDTH = 260
local HOLD = 1.5 -- a card can't be replaced by a lower-priority one for this long
local current: { Priority: number, ShownAt: number }? = nil
local pending: { Spec: CardSpec, At: number }? = nil
local cardToken = 0

local showCard: (spec: CardSpec) -> ()

local function hideCard(token: number)
	if token ~= cardToken then
		return
	end
	current = nil
	local function finish()
		if token == cardToken then
			cardSlot.Visible = false
			-- A lower-priority card that was waiting gets its turn if it's still fresh.
			local waiting = pending
			pending = nil
			if waiting and os.clock() - waiting.At < 4 then
				showCard(waiting.Spec)
			end
		end
	end
	if UI.reduced() then
		finish()
	else
		UI.tween(
			cardSlot,
			UI.Time.Exit,
			{ Position = UDim2.new(0, -CARD_WIDTH - 20, 0.46, 0) },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		).Completed
			:Once(finish)
	end
end

function showCard(spec: CardSpec)
	cardToken += 1
	local token = cardToken
	current = { Priority = spec.Priority, ShownAt = os.clock() }
	for _, c in cardSlot:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	cardSlot.Size = UDim2.fromOffset(CARD_WIDTH, spec.Height)
	local stroke = cardSlot:FindFirstChildOfClass("UIStroke") :: UIStroke
	stroke.Color = spec.Accent
	UI.new("Frame", {
		Parent = cardSlot,
		Name = "Accent",
		Size = UDim2.new(0, 6, 1, 0),
		BackgroundColor3 = spec.Accent,
		BorderSizePixel = 0,
	}, { UI.corner(3) })
	local body = UI.new("Frame", {
		Parent = cardSlot,
		Name = "Body",
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -26, 1, 0),
		BackgroundTransparency = 1,
	})
	spec.Build(body)
	cardSlot.Visible = true
	local rest = UDim2.new(0, 12, 0.46, 0)
	if UI.reduced() then
		cardSlot.Position = rest
	else
		cardSlot.Position = UDim2.new(0, -24, 0.46, 0)
		UI.tween(cardSlot, UI.Time.Enter, { Position = rest })
		UI.pop(cardScale, 0.92)
	end
	-- Studio QA can stretch cards (workspace attribute QA_CardHold) so screenshots catch them.
	local stretch = if RunService:IsStudio() then workspace:GetAttribute("QA_CardHold") or 1 else 1
	task.delay(spec.Seconds * stretch, hideCard, token)
end

-- Shows a card now, or queues it if a more important card is still being read.
function Notifications.card(spec: CardSpec)
	local cur = current
	if cur and spec.Priority < cur.Priority and os.clock() - cur.ShownAt < HOLD then
		pending = { Spec = spec, At = os.clock() }
		return
	end
	pending = nil
	showCard(spec)
end

-- Priority of the card on screen (0 if none). Used by QA.
function Notifications.cardPriority(): number
	return if current then current.Priority else 0
end

---------------------------------------------------------------------------- Feed

local feedCount = 0

local function fadeOut(plate: Frame, label: TextLabel, seconds: number)
	UI.tween(plate, seconds, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
	UI.tween(label, seconds, { TextTransparency = 1 }, Enum.EasingStyle.Quad)
	local stroke = plate:FindFirstChildOfClass("UIStroke")
	if stroke then
		UI.tween(stroke, seconds, { Transparency = 1 }, Enum.EasingStyle.Quad)
	end
end

-- A short notice in the feed. The same text twice in a row refreshes the visible one.
function Notifications.feed(text: string, color: Color3?, seconds: number?)
	local duration = seconds or 3.5
	for _, plate in feedHolder:GetChildren() do
		if
			plate:IsA("Frame")
			and plate:GetAttribute("Text") == text
			and plate:GetAttribute("Leaving") ~= true
		then
			plate:SetAttribute("Until", os.clock() + duration)
			return
		end
	end
	feedCount += 1
	local plate = UI.plate({
		Name = "Notice",
		Parent = feedHolder,
		LayoutOrder = feedCount,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 30),
		BackgroundTransparency = 1,
	})
	plate:SetAttribute("Text", text)
	plate:SetAttribute("Until", os.clock() + duration)
	UI.padding(5, 12).Parent = plate
	UI.new("UISizeConstraint", { Parent = plate, MaxSize = Vector2.new(560, 80) })
	local label = UI.text({
		Parent = plate,
		Role = "Label",
		TextSize = 15,
		Text = text,
		TextColor3 = color or UI.Color.Text,
		TextTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		TextWrapped = true,
	})
	UI.new("UISizeConstraint", { Parent = label, MaxSize = Vector2.new(536, 80) })
	UI.tween(plate, 0.15, { BackgroundTransparency = UI.PlateTransparency }, Enum.EasingStyle.Quad)
	UI.tween(label, 0.15, { TextTransparency = 0 }, Enum.EasingStyle.Quad)
	task.spawn(function()
		while os.clock() < (plate:GetAttribute("Until") or 0) do
			task.wait(0.2)
		end
		plate:SetAttribute("Leaving", true)
		fadeOut(plate, label, 0.4)
		task.wait(0.4)
		plate:Destroy()
	end)
	-- Max three on screen: the oldest goes first.
	local live = {}
	for _, c in feedHolder:GetChildren() do
		if c:IsA("Frame") and c:GetAttribute("Leaving") ~= true then
			table.insert(live, c)
		end
	end
	table.sort(live, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #live - 3 do
		live[i]:SetAttribute("Until", 0)
	end
end

---------------------------------------------------------------------------- Alert slot

local dangerText = ""
local locationUntil = 0
local suppress = { Modal = false, Storm = false }

-- Personal danger (P4). Empty text clears it.
function Notifications.danger(text: string, color: Color3?)
	if text == dangerText then
		if color then
			alertLabel.TextColor3 = color
			alertStroke.Color = color
		end
		return
	end
	local wasEmpty = dangerText == ""
	dangerText = text
	if text == "" then
		-- Back to the district title if one is still on its timer.
		alertSlot.Visible = os.clock() < locationUntil
		if alertSlot.Visible then
			alertLabel.Text = tostring(alertSlot:GetAttribute("LocationTitle") or "")
			alertLabel.TextColor3 = UI.Color.Text
			alertStroke.Color = UI.Color.Outline
			alertSub.Visible = alertSub.Text ~= ""
		end
		return
	end
	alertLabel.Text = text
	alertLabel.TextColor3 = color or UI.Color.Danger
	alertStroke.Color = color or UI.Color.Danger
	alertSub.Visible = false
	alertSlot.Visible = true
	if wasEmpty and not UI.reduced() then
		local scale = alertSlot:FindFirstChildOfClass("UIScale") :: UIScale
		UI.pop(scale, 1.08, 0.2)
	end
end

function Notifications.hasDanger(): boolean
	return dangerText ~= ""
end

-- District title (P0): shown for a few seconds, never over a danger alert.
function Notifications.location(title: string, sub: string)
	if suppress.Modal then
		return -- lowest priority: never over the shop or settings
	end
	locationUntil = os.clock() + 3.2
	alertSlot:SetAttribute("LocationTitle", title)
	alertSub.Text = sub
	if dangerText ~= "" then
		return
	end
	alertLabel.Text = title
	alertLabel.TextColor3 = UI.Color.Text
	alertStroke.Color = UI.Color.Outline
	alertSub.Visible = sub ~= ""
	alertSlot.Visible = true
	local token = locationUntil
	task.delay(3.2, function()
		if locationUntil == token and dangerText == "" then
			alertSlot.Visible = false
		end
	end)
end

---------------------------------------------------------------------------- Hint

local hintText: string? = nil

local function refreshHint()
	local show = hintText ~= nil and not suppress.Modal and not suppress.Storm and dangerText == ""
	hintPlate.Visible = show
	if show then
		hintLabel.Text = hintText :: string
	end
end

function Notifications.setHint(text: string?)
	hintText = text
	refreshHint()
end

function Notifications.setModalOpen(open: boolean)
	suppress.Modal = open
	if open and dangerText == "" then
		-- A district title would sit over the modal's top edge; danger alerts still show.
		locationUntil = 0
		alertSlot.Visible = false
	end
	refreshHint()
end

function Notifications.setStormy(stormy: boolean)
	suppress.Storm = stormy
	refreshHint()
end

---------------------------------------------------------------------------- Per frame

function Notifications.step()
	if dangerText ~= "" and not UI.reduced() then
		-- Slow pulse on the danger outline so it reads as urgent without flashing.
		alertStroke.Transparency = 0.25 + 0.25 * math.sin(os.clock() * 10)
	else
		alertStroke.Transparency = 0
	end
	refreshHint()
end

---------------------------------------------------------------------------- Init

-- `topStack` is the vertical list under the storm strip (the alert slot goes in it).
function Notifications.init(hudRoot: Frame, topStack: Frame)
	root = hudRoot

	alertSlot = UI.plate({
		Name = "AlertSlot",
		Parent = topStack,
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		Visible = false,
	})
	UI.new("UIScale", { Parent = alertSlot })
	alertStroke = alertSlot:FindFirstChildOfClass("UIStroke") :: UIStroke
	alertStroke.Thickness = 2.5
	UI.padding(5, 14).Parent = alertSlot
	UI.new("UIListLayout", {
		Parent = alertSlot,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	alertLabel = UI.text({
		Name = "Text",
		Parent = alertSlot,
		Role = "Title",
		TextSize = 18,
		LayoutOrder = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		Text = "",
	})
	alertSub = UI.text({
		Name = "Sub",
		Parent = alertSlot,
		Role = "Caption",
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		TextColor3 = UI.Color.TextDim,
		Text = "",
		Visible = false,
	})

	-- On touch screens the card sits where Roblox's dynamic thumbstick starts, so there it's a
	-- plain frame that lets touches through (it hides itself). With a mouse it's a button you
	-- can click to dismiss.
	local touch = UI.isTouch()
	cardSlot = UI.new(if touch then "Frame" else "TextButton", {
		Name = "EventCard",
		Parent = root,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.46, 0), -- clear of chat above
		Size = UDim2.fromOffset(CARD_WIDTH, 92),
		BackgroundColor3 = UI.Color.Plate,
		BackgroundTransparency = 0.1,
		Active = false,
		Visible = false,
		ZIndex = 4,
	}, { UI.corner(UI.Radius.Panel), UI.stroke(UI.Color.Text, 2) })
	cardScale = UI.new("UIScale", { Parent = cardSlot })
	if cardSlot:IsA("TextButton") then
		cardSlot.AutoButtonColor = false
		cardSlot.Text = ""
		cardSlot.Activated:Connect(function()
			hideCard(cardToken)
		end)
	end

	feedHolder = UI.new("Frame", {
		Name = "Feed",
		Parent = root,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -62),
		Size = UDim2.new(0.5, 0, 0, 120),
		BackgroundTransparency = 1,
		ZIndex = 30, -- above modals, so "Need 40 more coins" shows over the shop
	}, {
		UI.new("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	hintPlate = UI.plate({
		Name = "Hint",
		Parent = root,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		BackgroundTransparency = 0.35,
		Visible = false,
	})
	UI.padding(5, 14).Parent = hintPlate
	hintLabel = UI.text({
		Name = "Text",
		Parent = hintPlate,
		Role = "Label",
		TextSize = 15,
		TextColor3 = Color3.fromRGB(255, 236, 160),
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		Text = "",
	})
end

return Notifications
