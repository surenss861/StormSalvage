-- @file Design tokens and UI builders
-- @domain ui
-- @status stable
-- @see [[ui-design-spec]]
-- @see [[V3-UI-WORKSHOP]]
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
	Mono = Enum.Font.GothamBold, -- timers and counts
}

UI.TextSize = { Display = 28, Title = 20, Label = 14, Body = 14, Caption = 13 }

-- V4 "Storm-Scarred Arcade" (docs/art/v4/HUD.md): dark industrial plates, amber hazard edges,
-- gold for wealth, bold condensed type. The always-on HUD and the objective strip use it; the
-- menus move onto it in M9.
UI.Arcade = {
	Plate = Color3.fromRGB(24, 25, 29),
	Plate2 = Color3.fromRGB(36, 38, 43),
	Edge = Color3.fromRGB(62, 64, 71),
	Amber = Color3.fromRGB(255, 176, 46),
	Gold = Color3.fromRGB(255, 206, 74),
	Text = Color3.fromRGB(246, 246, 248),
	Dim = Color3.fromRGB(170, 172, 180),
	Health = Color3.fromRGB(64, 214, 120),
	Hurt = Color3.fromRGB(235, 70, 60),
}
UI.Heading = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)

-- A dark Arcade plate (rounded, thin edge, slightly see-through so the world reads behind it).
function UI.arcadePlate(props: { [string]: any }): Frame
	props.BackgroundColor3 = props.BackgroundColor3 or UI.Arcade.Plate
	props.BackgroundTransparency = props.BackgroundTransparency or 0.08
	props.BorderSizePixel = 0
	local f = UI.new("Frame", props)
	UI.corner(6).Parent = f
	UI.stroke(UI.Arcade.Edge, 1.5).Parent = f
	return f
end

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
UI.StrokeTransparency = 0
UI.Accent = Color3.fromRGB(206, 122, 34) -- primary action colour (Shop button, Buy)

-- Interface theme. Applied once by Main before anything is built; every module reads the token
-- tables above, so the theme re-skins the HUD, cards and modals together.
--   Classic   the V2 look (the defaults above)
--   Workshop  the V3 direction (docs/art/V3-UI-STUDIES.md): the HUD is built from objects in
--             the salvage yard. Marker lettering for titles only; every number (coins, prices,
--             timers, counts) uses a bold plain face so it reads at a glance.
local THEMES = {
	Workshop = {
		Font = {
			Display = Enum.Font.PermanentMarker,
			Title = Enum.Font.PermanentMarker,
			Label = Enum.Font.GothamBold,
			Body = Enum.Font.GothamMedium,
			Mono = Enum.Font.GothamBlack,
		},
		Color = {
			Plate = Color3.fromRGB(46, 40, 34), -- dark workbench wood
			PlateLight = Color3.fromRGB(72, 62, 52),
			Outline = Color3.fromRGB(22, 18, 14),
			Text = Color3.fromRGB(248, 240, 222),
			TextDim = Color3.fromRGB(214, 200, 176),
			TextMuted = Color3.fromRGB(156, 144, 126),
			Slate = Color3.fromRGB(96, 102, 108), -- galvanised tin
			Disabled = Color3.fromRGB(78, 72, 64),
			Buy = Color3.fromRGB(58, 150, 72),
		},
		Radius = { Chip = 3, Panel = 6, Modal = 10 },
		PlateTransparency = 0.08,
		StrokeTransparency = 0,
		Accent = Color3.fromRGB(232, 120, 30),
		TextSize = { Display = 30, Title = 21 },
	},
}

-- Salvage-yard materials for the Workshop surfaces (cash tag, crate, tin sign, notes, tags).
UI.Mat = {
	Kraft = Color3.fromRGB(206, 168, 118),
	KraftEdge = Color3.fromRGB(146, 108, 66),
	Manila = Color3.fromRGB(240, 220, 170),
	Tape = Color3.fromRGB(238, 228, 190),
	Marker = Color3.fromRGB(34, 30, 28),
	Pencil = Color3.fromRGB(96, 90, 84),
	RedPen = Color3.fromRGB(204, 40, 36),
	Tin = Color3.fromRGB(184, 190, 194),
	TinDark = Color3.fromRGB(104, 110, 116),
	Wood = Color3.fromRGB(162, 110, 62),
	WoodDark = Color3.fromRGB(110, 72, 38),
	Peg = Color3.fromRGB(148, 104, 60),
	PegHole = Color3.fromRGB(88, 60, 32),
	Note = Color3.fromRGB(255, 226, 110),
	Paper = Color3.fromRGB(250, 248, 238),
	Rule = Color3.fromRGB(170, 200, 230),
	Orange = Color3.fromRGB(240, 128, 36),
	Tile = Color3.fromRGB(34, 34, 36),
}

function UI.useTheme(name: string?)
	local theme = THEMES[name or ""]
	if not theme then
		return -- Classic: the defaults above
	end
	for group, values in theme do
		local target = (UI :: any)[group]
		if type(values) == "table" and type(target) == "table" then
			for k, v in values do
				target[k] = v
			end
		else
			(UI :: any)[group] = values
		end
	end
end

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

-- Compact (phone) composition: touch devices, or Studio's phone-frame preview (Hud).
local compactOverride = false
function UI.setCompactOverride(on: boolean)
	compactOverride = on
end

function UI.compact(): boolean
	return compactOverride or UserInputService.TouchEnabled
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
		Transparency = transparency or UI.StrokeTransparency,
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
	if props.FontFace == nil then -- a FontFace (e.g. a weight of a family) wins over Font
		props.Font = props.Font or (UI.Font :: any)[role] or UI.Font.Body
	else
		props.Font = nil
	end
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
-- `format` is a string.format pattern ("%d") or a function (e.g. BigMoney.tag).
function UI.countUp(
	label: TextLabel,
	from: number,
	to: number,
	seconds: number,
	format: string | (number) -> string
): () -> ()
	local cancelled = false
	local function show(n: number): string
		return if type(format) == "function" then format(n) else (format :: string):format(n)
	end
	task.spawn(function()
		local t0 = os.clock()
		while not cancelled and label.Parent and os.clock() - t0 < seconds do
			local f = (os.clock() - t0) / seconds
			f = 1 - (1 - f) * (1 - f) -- ease out
			label.Text = show(math.floor(from + (to - from) * f))
			task.wait()
		end
		if not cancelled then
			label.Text = show(to)
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

-- Whether any modal is open (taps on the world are ignored while one is).
function UI.modalOpen(): boolean
	return openModal ~= nil
end

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
	backdrop.Activated:Connect(function(input: InputObject?)
		-- Only a tap on the dimmed area closes the modal. GuiButtons receive clicks through
		-- non-button frames above them, so a tap on empty panel space also reaches the backdrop:
		-- ignore it when the panel is under the pointer.
		if input then
			local gui = backdrop:FindFirstAncestorWhichIsA("BasePlayerGui")
			if gui then
				for _, obj in gui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y) do
					if obj == panel or obj:IsDescendantOf(panel) then
						return
					end
				end
			end
		end
		setOpen(false)
	end)
	return modal
end

---------------------------------------------------------------------------- Workshop pieces

-- A strip of masking tape (or coloured tape) centred at `pos`.
function UI.tape(
	parent: Instance,
	pos: UDim2,
	size: Vector2,
	rotation: number,
	color: Color3?,
	z: number?
): Frame
	return UI.new("Frame", {
		Name = "Tape",
		Parent = parent,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos,
		Size = UDim2.fromOffset(size.X, size.Y),
		Rotation = rotation,
		BackgroundColor3 = color or UI.Mat.Tape,
		BackgroundTransparency = if color then 0.04 else 0.12,
		BorderSizePixel = 0,
		ZIndex = z or 1,
	})
end

function UI.rivet(parent: Instance, pos: UDim2, z: number?): Frame
	return UI.new("Frame", {
		Name = "Rivet",
		Parent = parent,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos,
		Size = UDim2.fromOffset(7, 7),
		BackgroundColor3 = UI.Mat.TinDark,
		BorderSizePixel = 0,
		ZIndex = z or 1,
	}, { UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
end

-- A punched hole with a reinforcement ring (tags, cards).
function UI.punchHole(parent: Instance, pos: UDim2, size: number, z: number?): Frame
	return UI.new("Frame", {
		Name = "Hole",
		Parent = parent,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = UI.Mat.Paper,
		BorderSizePixel = 0,
		ZIndex = z or 1,
	}, {
		UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		UI.new("UIStroke", { Thickness = 3, Color = UI.Mat.KraftEdge }),
	})
end

function UI.comma(n: number): string
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
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

-- Running boot: shaft, foot, toe cap, sole and laces.
function UI.bootIcon(parent: Instance, size: number, color: Color3?): Frame
	local leather = color or Color3.fromRGB(150, 96, 56)
	local holder = UI.new("Frame", {
		Name = "BootIcon",
		Parent = parent,
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
	})
	local function piece(name: string, pos: UDim2, sz: UDim2, c: Color3, radius: number)
		return UI.new("Frame", {
			Name = name,
			Parent = holder,
			Position = pos,
			Size = sz,
			BackgroundColor3 = c,
			BorderSizePixel = 0,
		}, {
			UI.corner(radius),
			UI.new("UIStroke", { Thickness = 1.5, Color = UI.Color.Outline, Transparency = 0.2 }),
		})
	end
	piece("Shaft", UDim2.fromScale(0.18, 0.05), UDim2.fromScale(0.38, 0.62), leather, math.max(2, size // 12))
	piece("Foot", UDim2.fromScale(0.18, 0.5), UDim2.fromScale(0.7, 0.3), leather, math.max(3, size // 7))
	piece("Sole", UDim2.fromScale(0.14, 0.8), UDim2.fromScale(0.78, 0.13), Color3.fromRGB(40, 38, 36), 2)
	piece("Cuff", UDim2.fromScale(0.15, 0.03), UDim2.fromScale(0.44, 0.12), Color3.fromRGB(232, 160, 52), 2)
	for i = 0, 2 do
		UI.new("Frame", {
			Parent = holder,
			Position = UDim2.fromScale(0.28, 0.24 + i * 0.12),
			Size = UDim2.fromScale(0.18, 0.04),
			BackgroundColor3 = Color3.fromRGB(242, 236, 222),
			BorderSizePixel = 0,
		})
	end
	return holder
end

-- Storm armor: a chest plate with shoulder guards and a hazard stripe.
function UI.armorIcon(parent: Instance, size: number, color: Color3?): Frame
	local steel = color or Color3.fromRGB(110, 124, 136)
	local holder = UI.new("Frame", {
		Name = "ArmorIcon",
		Parent = parent,
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
	})
	for _, x in { 0.04, 0.66 } do
		UI.new("Frame", {
			Name = "Shoulder",
			Parent = holder,
			Position = UDim2.fromScale(x, 0.08),
			Size = UDim2.fromScale(0.3, 0.22),
			BackgroundColor3 = steel:Lerp(Color3.new(0, 0, 0), 0.25),
			BorderSizePixel = 0,
		}, {
			UI.corner(math.max(2, size // 8)),
			UI.new("UIStroke", { Thickness = 1.5, Color = UI.Color.Outline, Transparency = 0.2 }),
		})
	end
	local plate = UI.new("Frame", {
		Name = "Plate",
		Parent = holder,
		Position = UDim2.fromScale(0.18, 0.16),
		Size = UDim2.fromScale(0.64, 0.78),
		BackgroundColor3 = steel,
		BorderSizePixel = 0,
	}, {
		UI.corner(math.max(3, size // 5)),
		UI.new("UIStroke", { Thickness = 1.5, Color = UI.Color.Outline, Transparency = 0.2 }),
	})
	UI.new("Frame", {
		Name = "Stripe",
		Parent = plate,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromScale(1, 0.16),
		BackgroundColor3 = Color3.fromRGB(232, 160, 52),
		BorderSizePixel = 0,
	})
	UI.new("Frame", {
		Name = "Bolt",
		Parent = plate,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.7),
		Size = UDim2.fromScale(0.22, 0.14),
		BackgroundColor3 = Color3.fromRGB(242, 236, 222),
		BorderSizePixel = 0,
	}, { UI.corner(2) })
	return holder
end

-- The icon for an upgrade id.
-- A press: a heavy plate over a block on a base. Reads as "Salvage Press" without an image asset.
function UI.pressIcon(parent: Instance, size: number): Frame
	local holder = UI.new("Frame", {
		Name = "PressIcon",
		Parent = parent,
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
	})
	local function bar(x: number, y: number, w: number, h: number, color: Color3)
		UI.new("Frame", {
			Parent = holder,
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(w, h),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
		}, { UI.corner(2), UI.stroke(UI.Mat.Marker, 2) })
	end
	bar(0.1, 0.78, 0.8, 0.14, UI.Mat.TinDark) -- base
	bar(0.28, 0.5, 0.44, 0.26, Color3.fromRGB(200, 116, 60)) -- the block being pressed
	bar(0.15, 0.3, 0.7, 0.16, UI.Mat.Orange) -- the plate
	bar(0.44, 0.06, 0.12, 0.24, UI.Mat.Tin) -- the ram
	return holder
end

-- A harness: two shoulder straps and a chest buckle, in storm violet.
function UI.harnessIcon(parent: Instance, size: number): Frame
	local holder = UI.new("Frame", {
		Name = "HarnessIcon",
		Parent = parent,
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
	})
	local function strap(x: number, rot: number)
		UI.new("Frame", {
			Parent = holder,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.5),
			Size = UDim2.fromScale(0.16, 0.9),
			Rotation = rot,
			BackgroundColor3 = Color3.fromRGB(150, 110, 210),
			BorderSizePixel = 0,
		}, { UI.corner(3), UI.stroke(UI.Mat.Marker, 2) })
	end
	strap(0.33, -14)
	strap(0.67, 14)
	UI.new("Frame", {
		Parent = holder,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(0.42, 0.26),
		BackgroundColor3 = UI.Mat.Tin,
		BorderSizePixel = 0,
	}, { UI.corner(3), UI.stroke(UI.Mat.Marker, 2) })
	return holder
end

-- A cutting torch: a tank, a nozzle and an orange flame.
function UI.cutterIcon(parent: Instance, size: number): Frame
	local holder = UI.new("Frame", {
		Name = "CutterIcon",
		Parent = parent,
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
	})
	UI.new("Frame", {
		Parent = holder,
		Position = UDim2.fromScale(0.1, 0.3),
		Size = UDim2.fromScale(0.3, 0.6),
		BackgroundColor3 = Color3.fromRGB(200, 60, 50),
		BorderSizePixel = 0,
	}, { UI.corner(4), UI.stroke(UI.Mat.Marker, 2) })
	UI.new("Frame", {
		Parent = holder,
		Position = UDim2.fromScale(0.35, 0.36),
		Size = UDim2.fromScale(0.4, 0.12),
		Rotation = -20,
		BackgroundColor3 = UI.Mat.Tin,
		BorderSizePixel = 0,
	}, { UI.stroke(UI.Mat.Marker, 2) })
	UI.new("Frame", {
		Parent = holder,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.84, 0.24),
		Size = UDim2.fromScale(0.22, 0.22),
		Rotation = 45,
		BackgroundColor3 = Color3.fromRGB(255, 170, 50),
		BorderSizePixel = 0,
	}, { UI.corner(3) })
	return holder
end

-- A containment rig: a ring with a glowing core held in it.
function UI.rigIcon(parent: Instance, size: number): Frame
	local holder = UI.new("Frame", {
		Name = "RigIcon",
		Parent = parent,
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
	})
	UI.new("Frame", {
		Parent = holder,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.86, 0.86),
		BackgroundTransparency = 1,
	}, { UI.corner(size), UI.stroke(Color3.fromRGB(110, 110, 130), 4) })
	UI.new("Frame", {
		Parent = holder,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.42, 0.42),
		BackgroundColor3 = Color3.fromRGB(255, 90, 200),
		BorderSizePixel = 0,
	}, { UI.corner(size), UI.stroke(UI.Mat.Marker, 2) })
	return holder
end

function UI.upgradeIcon(id: string, parent: Instance, size: number): Frame
	if id == "Press" then
		return UI.pressIcon(parent, size)
	elseif id == "Harness" then
		return UI.harnessIcon(parent, size)
	elseif id == "Cutter" then
		return UI.cutterIcon(parent, size)
	elseif id == "Rig" then
		return UI.rigIcon(parent, size)
	elseif id == "Boots" then
		return UI.bootIcon(parent, size)
	elseif id == "Armor" then
		return UI.armorIcon(parent, size)
	end
	return UI.bagIcon(parent, size)
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
