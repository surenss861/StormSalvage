-- Design tokens and small builders shared by every client UI module, so the HUD, cards,
-- modals and world markers all use one type scale, palette, shape language and motion
-- timing. See docs/ui-design-spec.md for the reasoning behind each value.

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UI = {}

UI.Font = {
	Display = Enum.Font.FredokaOne,
	Title = Enum.Font.FredokaOne,
	Label = Enum.Font.GothamBold,
	Body = Enum.Font.GothamMedium,
}

UI.TextSize = { Display = 28, Title = 20, Label = 14, Body = 14, Caption = 13 }

UI.Color = {
	Plate = Color3.fromRGB(24, 26, 32),
	PlateLight = Color3.fromRGB(40, 44, 54),
	Outline = Color3.fromRGB(10, 10, 14),
	Text = Color3.fromRGB(245, 244, 238),
	TextDim = Color3.fromRGB(185, 188, 198),
	TextMuted = Color3.fromRGB(130, 135, 145),
	Coin = Color3.fromRGB(255, 205, 70),
	Safe = Color3.fromRGB(110, 220, 130),
	Warn = Color3.fromRGB(255, 172, 64),
	Danger = Color3.fromRGB(255, 84, 70),
	Water = Color3.fromRGB(96, 172, 255),
	Buy = Color3.fromRGB(56, 168, 84),
	Slate = Color3.fromRGB(70, 76, 90),
	Disabled = Color3.fromRGB(62, 64, 72),
}

UI.PlateTransparency = 0.18
UI.Radius = { Chip = 6, Panel = 10, Modal = 14 }
UI.Time = { Press = 0.08, Enter = 0.22, Exit = 0.18, Count = 0.5 }

-- Set by Main: whether Reduced Effects is on (motion becomes plain fades) and the click cue.
local reducedMotion: () -> boolean = function()
	return false
end
local clickSound: () -> () = function() end

function UI.setReducedMotion(fn: () -> boolean)
	reducedMotion = fn
end

function UI.setClickSound(fn: () -> ())
	clickSound = fn
end

function UI.reduced(): boolean
	return reducedMotion()
end

function UI.isTouch(): boolean
	return UserInputService.TouchEnabled
end

-- Touch targets: 64 design px is about 45 pt on the smallest phone tested (HUD scale 0.7).
function UI.buttonSize(): number
	return if UI.isTouch() then 64 else 52
end

---------------------------------------------------------------------------- Builders

function UI.new(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = props.Parent
	props.Parent = nil
	for k, v in props do
		(inst :: any)[k] = v
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	inst.Parent = parent
	return inst
end

function UI.corner(radius: number?): UICorner
	return UI.new("UICorner", { CornerRadius = UDim.new(0, radius or UI.Radius.Panel) })
end

function UI.stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return UI.new("UIStroke", {
		Color = color or UI.Color.Outline,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UI.padding(top: number, right: number?, bottom: number?, left: number?): UIPadding
	return UI.new("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right or top),
		PaddingBottom = UDim.new(0, bottom or top),
		PaddingLeft = UDim.new(0, left or right or top),
	})
end

-- A standard panel: dark plate, rounded, outlined.
function UI.plate(props: { [string]: any }, children: { Instance }?): Frame
	props.BackgroundColor3 = props.BackgroundColor3 or UI.Color.Plate
	props.BackgroundTransparency = props.BackgroundTransparency or UI.PlateTransparency
	props.BorderSizePixel = 0
	local radius = props.Radius or UI.Radius.Panel
	props.Radius = nil
	local frame = UI.new("Frame", props, children)
	UI.corner(radius).Parent = frame
	UI.stroke().Parent = frame
	return frame
end

-- Text in one of the type roles. Text on plates has no outline; pass Outline = true for text
-- drawn straight over the world.
function UI.text(props: { [string]: any }): TextLabel
	local role = props.Role or "Body"
	local outline = props.Outline
	props.Role = nil
	props.Outline = nil
	props.BackgroundTransparency = 1
	props.Font = props.Font or (UI.Font :: any)[role] or UI.Font.Body
	props.TextSize = props.TextSize or (UI.TextSize :: any)[role] or UI.TextSize.Body
	props.TextColor3 = props.TextColor3 or UI.Color.Text
	local label = UI.new("TextLabel", props)
	if outline then
		UI.new("UIStroke", { Parent = label, Thickness = 1.5, Color = UI.Color.Outline, Transparency = 0.15 })
	end
	return label
end

---------------------------------------------------------------------------- Motion

function UI.tween(
	inst: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween
	local tween = TweenService:Create(
		inst,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out),
		goal
	)
	tween:Play()
	return tween
end

-- A quick scale pop on a UIScale (skipped with Reduced Effects).
function UI.pop(scale: UIScale, from: number, seconds: number?)
	if reducedMotion() then
		scale.Scale = 1
		return
	end
	scale.Scale = from
	UI.tween(scale, seconds or UI.Time.Enter, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Counts a label up from `from` to `to` over `seconds`, formatting each value with `format`.
-- Returns a cancel function. Purely visual: the true number is always shown at the end.
function UI.countUp(label: TextLabel, from: number, to: number, seconds: number, format: string): () -> ()
	local cancelled = false
	task.spawn(function()
		local t0 = os.clock()
		while not cancelled and label.Parent and os.clock() - t0 < seconds do
			local f = (os.clock() - t0) / seconds
			f = 1 - (1 - f) * (1 - f) -- ease out
			label.Text = format:format(math.floor(from + (to - from) * f))
			task.wait()
		end
		if not cancelled then
			label.Text = format:format(to)
		end
	end)
	return function()
		cancelled = true
	end
end

---------------------------------------------------------------------------- Buttons

export type ButtonProps = {
	Parent: Instance?,
	Name: string?,
	Text: string?,
	Color: Color3?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	TextSize: number?,
	ZIndex: number?,
}

-- A chunky button with hover, press and disabled states. `button:SetAttribute("Disabled",
-- true)` grays it out and silences it; `Activated` still fires so callers can explain why.
function UI.button(props: ButtonProps): TextButton
	local color = props.Color or UI.Color.Slate
	local b = UI.new("TextButton", {
		Name = props.Name or "Button",
		Parent = props.Parent,
		Text = props.Text or "",
		Font = UI.Font.Title,
		TextSize = props.TextSize or 18,
		TextColor3 = UI.Color.Text,
		TextWrapped = true,
		AutoButtonColor = false,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.fromOffset(UI.buttonSize(), UI.buttonSize()),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
	}, { UI.corner(UI.Radius.Panel), UI.stroke(), UI.padding(4, 6) })
	b:SetAttribute("BaseColor", color)
	local scale = UI.new("UIScale", { Parent = b })

	local function base(): Color3
		if b:GetAttribute("Disabled") then
			return UI.Color.Disabled
		end
		return b:GetAttribute("BaseColor") :: Color3
	end
	local function refresh(hover: boolean)
		local c = base()
		b.BackgroundColor3 = if hover and not b:GetAttribute("Disabled")
			then c:Lerp(Color3.new(1, 1, 1), 0.08)
			else c
		b.TextColor3 = if b:GetAttribute("Disabled") then UI.Color.TextMuted else UI.Color.Text
	end
	b:GetAttributeChangedSignal("Disabled"):Connect(function()
		refresh(false)
	end)
	b:GetAttributeChangedSignal("BaseColor"):Connect(function()
		refresh(false)
	end)
	b.MouseEnter:Connect(function()
		refresh(true)
	end)
	b.MouseLeave:Connect(function()
		refresh(false)
	end)
	b.Activated:Connect(function()
		if not b:GetAttribute("Disabled") then
			clickSound()
		end
		if not reducedMotion() then
			scale.Scale = 0.94
			UI.tween(scale, UI.Time.Press * 2, { Scale = 1 }, Enum.EasingStyle.Quad)
		end
	end)
	refresh(false)
	return b
end

function UI.setButtonColor(b: GuiButton, color: Color3)
	b:SetAttribute("BaseColor", color)
end

---------------------------------------------------------------------------- Modals

export type Modal = {
	Panel: Frame,
	Content: Frame,
	IsOpen: () -> boolean,
	Open: () -> (),
	Close: () -> (),
	Changed: BindableEvent, -- fires (open: boolean)
}

local openModal: Modal? = nil

-- A centred panel over a dimmed backdrop. Tapping the backdrop or X closes it, and only one
-- modal is open at a time.
function UI.modal(parent: Instance, name: string, title: string, maxSize: Vector2): Modal
	-- Oversized and centred so the dim reaches under the notch and the screen edges (the HUD
	-- itself is laid out inside the safe area).
	local backdrop = UI.new("TextButton", {
		Name = name .. "Backdrop",
		Parent = parent,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 2000, 1, 2000),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		ZIndex = 19,
	})
	local panel = UI.plate({
		Name = name,
		Parent = parent,
		AnchorPoint = Vector2.new(0.5, 0.5),
		-- Below the storm strip; on a 340 pt phone (about 280 pt under Roblox's top bar) this
		-- still fits three shop rows or four settings rows without scrolling.
		Position = UDim2.fromScale(0.5, 0.57),
		Size = UDim2.fromScale(0.9, 0.86),
		BackgroundTransparency = 0.04,
		Visible = false,
		ZIndex = 20,
		Radius = UI.Radius.Modal,
	})
	UI.new("UISizeConstraint", { Parent = panel, MaxSize = maxSize })
	local scale = UI.new("UIScale", { Parent = panel })
	UI.text({
		Name = "Title",
		Parent = panel,
		Role = "Title",
		TextSize = 24,
		Position = UDim2.fromOffset(18, 12),
		Size = UDim2.new(1, -110, 0, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = title,
		ZIndex = 21,
	})
	local size = math.min(UI.buttonSize(), 56)
	local close = UI.button({
		Name = "Close",
		Parent = panel,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(size, size),
		Text = "X",
		TextSize = 22,
		Color = UI.Color.Slate,
		ZIndex = 21,
	})
	local content = UI.new("Frame", {
		Name = "Content",
		Parent = panel,
		Position = UDim2.fromOffset(12, 12 + size + 4),
		Size = UDim2.new(1, -24, 1, -(12 + size + 4) - 12),
		BackgroundTransparency = 1,
		ZIndex = 21,
	})
	local changed = Instance.new("BindableEvent")

	local modal: Modal
	local function setOpen(open: boolean)
		if open == panel.Visible then
			return
		end
		if open and openModal and openModal ~= modal then
			openModal.Close()
		end
		openModal = if open then modal else (if openModal == modal then nil else openModal)
		panel.Visible = open
		backdrop.Visible = open
		if open then
			backdrop.BackgroundTransparency = 1
			UI.tween(backdrop, UI.Time.Enter, { BackgroundTransparency = 0.55 })
			UI.pop(scale, 0.94)
		end
		changed:Fire(open)
	end
	modal = {
		Panel = panel,
		Content = content,
		IsOpen = function()
			return panel.Visible
		end,
		Open = function()
			setOpen(true)
		end,
		Close = function()
			setOpen(false)
		end,
		Changed = changed,
	}
	close.Activated:Connect(function()
		setOpen(false)
	end)
	backdrop.Activated:Connect(function()
		setOpen(false)
	end)
	return modal
end

---------------------------------------------------------------------------- Icons

-- Simple drawn icons (no image assets): a coin, a bag, a wrench-ish gear and a settings icon.

function UI.coinIcon(parent: Instance, size: number): Frame
	local coin = UI.new("Frame", {
		Name = "CoinIcon",
		Parent = parent,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = UI.Color.Coin,
		BorderSizePixel = 0,
	}, {
		UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		UI.new("UIStroke", { Thickness = 2, Color = Color3.fromRGB(150, 100, 20) }),
	})
	UI.new("Frame", {
		Parent = coin,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.42, 0.42),
		BackgroundColor3 = Color3.fromRGB(255, 232, 140),
		BorderSizePixel = 0,
	}, { UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	return coin
end

-- A backpack: body, front pocket and a carry handle (no ring, which read as a padlock).
function UI.bagIcon(parent: Instance, size: number, color: Color3?): Frame
	local tan = color or Color3.fromRGB(196, 140, 80)
	local holder = UI.new("Frame", {
		Name = "BagIcon",
		Parent = parent,
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
	})
	UI.new("Frame", {
		Name = "Handle",
		Parent = holder,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(0.4, 0.2),
		BackgroundColor3 = tan:Lerp(Color3.new(0, 0, 0), 0.35),
		BorderSizePixel = 0,
	}, { UI.corner(2) })
	local body = UI.new("Frame", {
		Name = "Body",
		Parent = holder,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(0.82, 0.84),
		BackgroundColor3 = tan,
		BorderSizePixel = 0,
	}, {
		UI.corner(math.max(3, size // 5)),
		UI.new("UIStroke", { Thickness = 1.5, Color = UI.Color.Outline }),
	})
	UI.new("Frame", {
		Name = "Pocket",
		Parent = body,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.9),
		Size = UDim2.fromScale(0.64, 0.38),
		BackgroundColor3 = tan:Lerp(Color3.new(0, 0, 0), 0.25),
		BorderSizePixel = 0,
	}, { UI.corner(2) })
	return holder
end

-- Three slider lines: reads as "settings" without needing an image asset.
function UI.slidersIcon(parent: Instance, size: number): Frame
	local holder = UI.new("Frame", {
		Name = "SettingsIcon",
		Parent = parent,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
	})
	for i, knobX in { 0.3, 0.7, 0.45 } do
		local y = (i - 0.5) / 3
		UI.new("Frame", {
			Parent = holder,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, y),
			Size = UDim2.new(1, 0, 0, 3),
			BackgroundColor3 = UI.Color.Text,
			BorderSizePixel = 0,
		}, { UI.corner(2) })
		UI.new("Frame", {
			Parent = holder,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(knobX, y),
			Size = UDim2.fromOffset(size * 0.26, size * 0.26),
			BackgroundColor3 = UI.Color.Text,
			BorderSizePixel = 0,
		}, { UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), UI.stroke(UI.Color.Outline, 1.5) })
	end
	return holder
end

return UI
