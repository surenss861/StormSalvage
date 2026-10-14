-- @file The one objective strip at the top of the screen: the most important thing right now
-- @domain ui
-- @status wip
-- @see [[V4-HUD]]
-- Everything that used to stack its own banner under the storm sign (the storm, personal danger,
-- the cache events, the Storm's Eye, the Armored Wreck, the Storm Titan, Storm Cores in town,
-- district titles) now submits an entry here, keyed by its source:
--   EventStrip.set(key, { Priority, Title, Sub?, Accent, EndsAt? (server time), Progress?,
--                         Pill? (short form), Seconds? (expires after this long) })
--   EventStrip.clear(key)
-- The highest priority entry gets the strip: accent stripe, title, one short line, a countdown
-- on the right and an optional progress bar. Up to two others shrink to pills beneath it, so
-- the top of the screen never holds more than one strip and one row of pills. Under immediate
-- danger (priority 95+: lightning on you, the Titan's core or inhale) the pills hide too.
-- Priorities (higher wins): personal danger 100; your own active objective 80-90 (carrying a
-- core, cutting, siphoning, inside the Eye with the Heart); events 55-70; the storm 45-50;
-- a district title 35; calm 20. A menu hides everything but personal danger.

local RunService = game:GetService("RunService")

local UI = require(script.Parent:WaitForChild("UI"))

local EventStrip = {}

export type Entry = {
	Priority: number,
	Title: string,
	Sub: string?,
	Accent: Color3,
	EndsAt: number?,
	Progress: number?,
	Pill: string?,
	Seconds: number?,
}

-- Storm-Scarred Arcade: dark industrial plate, amber hazard edge, bold white type.
local PLATE = Color3.fromRGB(26, 27, 31)
local EDGE = Color3.fromRGB(58, 60, 66)
local DIM = Color3.fromRGB(184, 186, 194)
local WIDTH, WIDTH_COMPACT = 440, 340

type Live = Entry & { Key: string, Expires: number? }
local entries: { [string]: Live } = {}

local holder: Frame
local strip: Frame
local stripe: Frame
local title: TextLabel
local sub: TextLabel
local timer: TextLabel
local barBack: Frame
local barFill: Frame
local pills: Frame
local pillFrames: { Frame } = {}
local compact = false
local shownKey: string? = nil
local scale: UIScale

local function fmt(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return ("%d:%02d"):format(s // 60, s % 60)
end

function EventStrip.set(key: string, e: Entry)
	local live = e :: Live
	live.Key = key
	live.Expires = if e.Seconds then os.clock() + e.Seconds else nil
	entries[key] = live
end

function EventStrip.clear(key: string)
	entries[key] = nil
end

function EventStrip.get(key: string): Entry?
	return entries[key]
end

-- Sorted live entries, highest first (expired ones dropped).
function EventStrip.ranked(): { Live }
	local now = os.clock()
	local list = {}
	for key, e in entries do
		if e.Expires and now >= e.Expires then
			entries[key] = nil
		else
			table.insert(list, e)
		end
	end
	table.sort(list, function(a, b)
		if a.Priority ~= b.Priority then
			return a.Priority > b.Priority
		end
		return a.Key < b.Key
	end)
	return list
end

local function pill(i: number): Frame
	local f = pillFrames[i]
	if f then
		return f
	end
	f = UI.new("Frame", {
		Name = "Pill" .. i,
		Parent = pills,
		LayoutOrder = i,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22),
		BackgroundColor3 = PLATE,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
	}, {
		UI.corner(11),
		UI.stroke(EDGE, 1),
		UI.padding(0, 10, 0, 8),
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	UI.new("Frame", {
		Name = "Dot",
		Parent = f,
		LayoutOrder = 1,
		Size = UDim2.fromOffset(8, 8),
		BorderSizePixel = 0,
	}, { UI.corner(4) })
	UI.text({
		Name = "Text",
		Parent = f,
		LayoutOrder = 2,
		Font = UI.Font.Mono,
		TextSize = 13,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22),
		TextColor3 = DIM,
		Text = "",
	})
	pillFrames[i] = f
	return f
end

local function step()
	local list = EventStrip.ranked()
	local modal = UI.modalOpen()
	if modal then
		-- A menu is up: only personal danger stays (it can still kill you).
		local keep = {}
		for _, e in list do
			if e.Priority >= 100 then
				table.insert(keep, e)
			end
		end
		list = keep
	end
	local top = list[1]
	holder.Visible = top ~= nil
	if not top then
		shownKey = nil
		return
	end
	if top.Key ~= shownKey then
		shownKey = top.Key
		if not UI.reduced() then
			UI.pop(scale, 1.05, 0.18)
		end
	end
	stripe.BackgroundColor3 = top.Accent
	local edge = strip:FindFirstChildOfClass("UIStroke") :: UIStroke
	edge.Color = if top.Priority >= 100 then top.Accent else EDGE
	title.Text = string.upper(top.Title)
	sub.Text = top.Sub or ""
	sub.Visible = top.Sub ~= nil and top.Sub ~= ""
	local nowServer = workspace:GetServerTimeNow()
	timer.Visible = top.EndsAt ~= nil
	if top.EndsAt then
		timer.Text = fmt(top.EndsAt - nowServer)
		timer.TextColor3 = if top.EndsAt - nowServer <= 5 then Color3.fromRGB(255, 96, 70) else top.Accent
	end
	barBack.Visible = top.Progress ~= nil
	if top.Progress then
		barFill.Size = UDim2.fromScale(math.clamp(top.Progress, 0, 1), 1)
		barFill.BackgroundColor3 = top.Accent
	end
	-- Pills: the next two, short.
	for i = 1, 2 do
		local e = list[i + 1]
		local f = pill(i)
		f.Visible = e ~= nil and (not compact or i == 1)
		if e then
			(f:FindFirstChild("Dot") :: Frame).BackgroundColor3 = e.Accent
			local text = e.Pill or e.Title
			if e.EndsAt then
				text ..= " " .. fmt(e.EndsAt - nowServer)
			end
			(f:FindFirstChild("Text") :: TextLabel).Text = string.upper(text)
		end
	end
	-- Immediate danger gets the player's whole attention: no pills under it.
	pills.Visible = list[2] ~= nil and top.Priority < 95
end

function EventStrip.setCompact(on: boolean)
	compact = on
	if strip then
		strip.Size = UDim2.fromOffset(if on then WIDTH_COMPACT else WIDTH, 0)
		title.TextSize = if on then 17 else 20
	end
end

function EventStrip.init(topStack: Frame)
	holder = UI.new("Frame", {
		Name = "EventStrip",
		Parent = topStack,
		LayoutOrder = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		BackgroundTransparency = 1,
		Visible = false,
	}, {
		UI.new("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	strip = UI.new("Frame", {
		Name = "Strip",
		Parent = holder,
		LayoutOrder = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromOffset(WIDTH, 0),
		BackgroundColor3 = PLATE,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
	}, {
		UI.corner(6),
		UI.stroke(EDGE, 2),
		UI.padding(7, 14, 7, 18),
	})
	scale = UI.new("UIScale", { Parent = strip })
	stripe = UI.new("Frame", {
		Name = "Stripe",
		Parent = strip,
		Position = UDim2.new(0, -12, 0, -3),
		Size = UDim2.new(0, 5, 1, 6),
		BorderSizePixel = 0,
	}, { UI.corner(2) })
	local body = UI.new("Frame", {
		Name = "Body",
		Parent = strip,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -64, 0, 0),
		BackgroundTransparency = 1,
	}, {
		UI.new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	title = UI.text({
		Name = "Title",
		FontFace = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold),
		Parent = body,
		LayoutOrder = 1,
		Font = UI.Font.Display,
		TextSize = 20,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
	})
	sub = UI.text({
		Name = "Sub",
		Parent = body,
		LayoutOrder = 2,
		Font = UI.Font.Body,
		TextSize = 14,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		TextColor3 = DIM,
		Text = "",
	})
	barBack = UI.new("Frame", {
		Name = "Bar",
		Parent = body,
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = Color3.fromRGB(50, 52, 58),
		BorderSizePixel = 0,
		Visible = false,
	}, { UI.corner(3) })
	barFill = UI.new("Frame", {
		Name = "Fill",
		Parent = barBack,
		Size = UDim2.fromScale(0, 1),
		BorderSizePixel = 0,
	}, { UI.corner(3) })
	timer = UI.text({
		Name = "Timer",
		Parent = strip,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(60, 26),
		Font = UI.Font.Mono,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
	})
	pills = UI.new("Frame", {
		Name = "Pills",
		Parent = holder,
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		BackgroundTransparency = 1,
		Visible = false,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	RunService.RenderStepped:Connect(step)
end

return EventStrip
