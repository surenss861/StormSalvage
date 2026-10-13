-- @file Message slots and priority
-- @domain ui
-- @status stable
-- @see [[V3-UI-WORKSHOP]]
-- Where every message goes, and which one wins. One slot per kind of message so nothing
-- overlaps (see docs/ui-design-spec.md, "Notifications"):
--
--   P4  danger(text)      Alert slot under the storm sign. Personal danger, always shown.
--   P2  card(spec)        Event card slot. Finds, bag full, sale receipts.
--   P1  feed(text)        Short server notices, max 3.
--   P0  location(...)     Alert slot, only while there's no danger. District titles.
--   P0  setHint(text)     The objective, on a sticky note. Hidden while danger, a modal or a
--                         storm is up.
--
-- Cards are physical objects (Workshop direction): a manila tag for finds, a clipboard tally for
-- sales, a sticky note for reminders. Positions follow Hud's layout: on phones the cards sit on
-- the right and the objective under the storm sign, clear of the thumbstick (Hud.luau).
--
-- This module only draws; it never decides what the player has or earns.

local RunService = game:GetService("RunService")

local UI = require(script.Parent:WaitForChild("UI"))

local Notifications = {}
local M = UI.Mat

local root: Frame
local topStack: Frame
local alertSlot: Frame
local alertLabel: TextLabel
local alertSub: TextLabel
local alertStroke: UIStroke
local feedHolder: Frame
local hintLabel: TextLabel
local hintPlate: Frame
local cardSlot: GuiObject
local cardScale: UIScale
local compact = false
local dangerText = ""
local locationUntil = 0
local suppress = { Modal = false, Storm = false }

---------------------------------------------------------------------------- Event cards

export type CardSpec = {
	Priority: number, -- 1 bag full, 2 rare, 3 epic, 4 Storm Core, 5 sale receipt
	Accent: Color3,
	Height: number,
	Width: number?,
	Seconds: number,
	-- "Tag" (manila tag, accent tape), "Clipboard" (wood board, paper), "Note" (sticky note).
	Surface: string?,
	Build: (card: Frame) -> (),
}

local CARD_WIDTH = 260
local HOLD = 1.5 -- a card can't be replaced by a lower-priority one for this long
local current: { Priority: number, ShownAt: number }? = nil
local pending: { Spec: CardSpec, At: number }? = nil
local cardToken = 0

local showCard: (spec: CardSpec) -> ()

local function restPosition(): UDim2
	if compact then
		-- Right side, left of the Gear Shop and Settings rail.
		return UDim2.new(1, -176, 0.36, 0)
	end
	return UDim2.new(0, 14, 0.62, 0)
end

local function offscreenPosition(width: number): UDim2
	local rest = restPosition()
	if compact then
		return rest + UDim2.fromOffset(width + 200, 0)
	end
	return UDim2.new(0, -width - 30, rest.Y.Scale, rest.Y.Offset)
end

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
			{ Position = offscreenPosition(cardSlot.Size.X.Offset) },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		).Completed
			:Once(finish)
	end
end

-- Paints the card's surface and returns the frame its content goes in.
local function surface(spec: CardSpec): Frame
	local kind = spec.Surface or "Note"
	local stroke = cardSlot:FindFirstChildOfClass("UIStroke") :: UIStroke
	local corner = cardSlot:FindFirstChildOfClass("UICorner") :: UICorner
	if kind == "Clipboard" then
		cardSlot.BackgroundColor3 = M.Wood
		cardSlot.Rotation = 0 -- rotated frames don't clip, and the paper must
		stroke.Color = M.WoodDark
		stroke.Thickness = 3
		corner.CornerRadius = UDim.new(0, 10)
		local paper = UI.new("Frame", {
			Name = "Paper",
			Parent = cardSlot,
			Position = UDim2.fromOffset(10, 22),
			Size = UDim2.new(1, -20, 1, -32),
			BackgroundColor3 = M.Paper,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 5,
		})
		for y = 46, spec.Height, 22 do
			UI.new("Frame", {
				Parent = paper,
				Position = UDim2.fromOffset(0, y),
				Size = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = M.Rule,
				BorderSizePixel = 0,
				ZIndex = 5,
			})
		end
		UI.new("Frame", {
			Parent = paper,
			Position = UDim2.fromOffset(26, 0),
			Size = UDim2.new(0, 1, 1, 0),
			BackgroundColor3 = Color3.fromRGB(236, 140, 140),
			BorderSizePixel = 0,
			ZIndex = 5,
		})
		UI.new("Frame", {
			Name = "Clip",
			Parent = cardSlot,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 6),
			Size = UDim2.fromOffset(110, 28),
			BackgroundColor3 = M.Tin,
			BorderSizePixel = 0,
			ZIndex = 8,
		}, {
			UI.corner(7),
			UI.stroke(M.TinDark, 2.5),
			UI.new("UIGradient", {
				Color = ColorSequence.new(Color3.fromRGB(230, 234, 238), Color3.fromRGB(150, 156, 162)),
				Rotation = 90,
			}),
		})
		local body = UI.new("Frame", {
			Name = "Body",
			Parent = paper,
			Position = UDim2.fromOffset(34, 18),
			Size = UDim2.new(1, -44, 1, -22),
			BackgroundTransparency = 1,
			ZIndex = 6,
		})
		return body
	elseif kind == "Tag" then
		cardSlot.BackgroundColor3 = M.Manila
		cardSlot.Rotation = if UI.reduced() then 0 else -1.5
		stroke.Color = M.KraftEdge
		stroke.Thickness = 2
		corner.CornerRadius = UDim.new(0, 10)
		UI.punchHole(cardSlot, UDim2.fromOffset(20, 20), 14, 6)
		-- The grade: tape in the rarity colour across the top.
		UI.new("Frame", {
			Name = "Grade",
			Parent = cardSlot,
			Position = UDim2.fromOffset(36, 8),
			Size = UDim2.new(1, -46, 0, 26),
			Rotation = -1,
			BackgroundColor3 = spec.Accent,
			BorderSizePixel = 0,
			ZIndex = 5,
		})
	else
		cardSlot.BackgroundColor3 = spec.Accent:Lerp(M.Note, 0.55)
		cardSlot.Rotation = if UI.reduced() then 0 else 1.5
		stroke.Color = spec.Accent:Lerp(M.Marker, 0.4)
		stroke.Thickness = 2
		corner.CornerRadius = UDim.new(0, 2)
		UI.tape(cardSlot, UDim2.new(0.5, 0, 0, 0), Vector2.new(64, 18), -3, nil, 7)
	end
	return UI.new("Frame", {
		Name = "Body",
		Parent = cardSlot,
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -26, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 6,
	})
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
	local width = spec.Width or CARD_WIDTH
	cardSlot.Size = UDim2.fromOffset(width, spec.Height)
	cardSlot.AnchorPoint = if compact then Vector2.new(1, 0) else Vector2.new(0, 0.5)
	spec.Build(surface(spec))
	cardSlot.Visible = true
	if compact and dangerText == "" then
		locationUntil = 0
		alertSlot.Visible = false
	end
	local rest = restPosition()
	if UI.reduced() then
		cardSlot.Position = rest
	else
		cardSlot.Position = if compact then rest + UDim2.fromOffset(40, 0) else rest - UDim2.fromOffset(30, 0)
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
	if suppress.Modal or (compact and cardSlot.Visible) then
		-- Lowest priority: never over the shop or settings, and on phones never over a card
		-- (both sit in the right half there).
		return
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

---------------------------------------------------------------------------- Objective note

local hintText: string? = nil

local function refreshHint()
	-- The note steps aside while an event card is up (they share the left side on desktop).
	local show = hintText ~= nil
		and not suppress.Modal
		and not suppress.Storm
		and dangerText == ""
		and not (cardSlot and cardSlot.Visible)
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
	-- With a modal up, server notices move to the top right, clear of the storm sign and the
	-- modal's buttons.
	if feedHolder then
		Notifications.applyLayout(compact)
	end
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

---------------------------------------------------------------------------- Layout

-- Desktop: objective note on the left under the crate, cards on the left, notices bottom
-- centre. Phone: the note joins the stack under the storm sign, cards move right, notices sit
-- right of the thumbstick zone.
function Notifications.applyLayout(isCompact: boolean)
	compact = isCompact
	-- Notices stack downwards from the top while a menu is open, upwards from the bottom otherwise.
	local feedList = feedHolder:FindFirstChildOfClass("UIListLayout")
	if feedList then
		feedList.VerticalAlignment = if suppress.Modal
			then Enum.VerticalAlignment.Top
			else Enum.VerticalAlignment.Bottom
		feedList.HorizontalAlignment = if suppress.Modal
			then Enum.HorizontalAlignment.Right
			else Enum.HorizontalAlignment.Center
	end
	if isCompact then
		hintPlate.Parent = topStack
		hintPlate.LayoutOrder = 10
		hintPlate.Rotation = 0
		hintPlate.AnchorPoint = Vector2.zero
		hintPlate.Position = UDim2.new()
		feedHolder.AnchorPoint = if suppress.Modal then Vector2.new(1, 0) else Vector2.new(0.5, 1)
		feedHolder.Position = if suppress.Modal then UDim2.new(1, -12, 0, 6) else UDim2.new(0.6, 0, 1, -10)
		feedHolder.Size = UDim2.new(0.38, 0, 0, 120)
	else
		hintPlate.Parent = root
		hintPlate.Rotation = if UI.reduced() then 0 else 1.2
		hintPlate.AnchorPoint = Vector2.zero
		hintPlate.Position = UDim2.fromOffset(18, 200)
		feedHolder.AnchorPoint = if suppress.Modal then Vector2.new(1, 0) else Vector2.new(0.5, 1)
		feedHolder.Position = if suppress.Modal then UDim2.new(1, -12, 0, 6) else UDim2.new(0.5, 0, 1, -18)
		feedHolder.Size = UDim2.new(0.5, 0, 0, 120)
	end
	if cardSlot.Visible then
		cardSlot.AnchorPoint = if compact then Vector2.new(1, 0) else Vector2.new(0, 0.5)
		cardSlot.Position = restPosition()
	end
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

-- `stack` is the vertical list under the storm sign (the alert slot goes in it).
function Notifications.init(hudRoot: Frame, stack: Frame)
	root = hudRoot
	topStack = stack

	alertSlot = UI.plate({
		Name = "AlertSlot",
		Parent = topStack,
		LayoutOrder = 5,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		Visible = false,
	})
	UI.new("UIScale", { Parent = alertSlot })
	alertStroke = alertSlot:FindFirstChildOfClass("UIStroke") :: UIStroke
	alertStroke.Thickness = 3
	UI.padding(5, 14).Parent = alertSlot
	UI.new("UIListLayout", {
		Parent = alertSlot,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	alertLabel = UI.text({
		Name = "Text",
		Parent = alertSlot,
		Font = UI.Font.Mono,
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

	-- On touch screens cards let touches through (camera drags still work under them). With a
	-- mouse a card is a button you can click to dismiss.
	local touch = UI.isTouch()
	cardSlot = UI.new(if touch then "Frame" else "TextButton", {
		Name = "EventCard",
		Parent = root,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.62, 0),
		Size = UDim2.fromOffset(CARD_WIDTH, 92),
		BackgroundColor3 = M.Manila,
		Active = false,
		Visible = false,
		ZIndex = 4,
	}, { UI.corner(8), UI.stroke(M.KraftEdge, 2) })
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
		Position = UDim2.new(0.5, 0, 1, -18),
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

	-- The objective: a sticky note with a plain, bold line (the "TO DO" is the only
	-- handwriting).
	hintPlate = UI.new("Frame", {
		Name = "Objective",
		Parent = root,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		BackgroundColor3 = M.Note,
		BorderSizePixel = 0,
		Visible = false,
	}, {
		UI.stroke(Color3.fromRGB(200, 160, 40), 1.5),
		UI.padding(8, 14, 8, 12),
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	UI.text({
		Name = "Kicker",
		Parent = hintPlate,
		LayoutOrder = 1,
		Font = UI.Font.Title,
		TextSize = 17,
		TextColor3 = M.RedPen,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		Text = "TO DO",
	})
	hintLabel = UI.text({
		Name = "Text",
		Parent = hintPlate,
		LayoutOrder = 2,
		Font = UI.Font.Label,
		TextSize = 16,
		TextColor3 = M.Marker,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromOffset(290, 0),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	})
	Notifications.applyLayout(false)
end

return Notifications
