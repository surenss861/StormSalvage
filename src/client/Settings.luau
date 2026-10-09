-- Settings panel: master, effects and weather volume, and Reduced Effects.
--
-- Persistence: these are client preferences, kept for the whole play session (the HUD
-- survives respawns) but not saved between sessions. Roblox gives a client no local storage,
-- and saving them would mean changing the player's DataStore profile for a volume slider,
-- which isn't worth the risk to save data. Revisit if players ask for it.

local UserInputService = game:GetService("UserInputService")

local UI = require(script.Parent:WaitForChild("UI"))

local Settings = {}

export type Hooks = {
	GetVolume: (kind: string) -> number,
	SetVolume: (kind: string, value: number) -> (),
	Preview: (kind: string) -> (), -- play a short sample at the new volume
	IsReduced: () -> boolean,
	SetReduced: (on: boolean) -> (),
}

local modal: UI.Modal
local hooks: Hooks

local function rowFrame(list: Instance, order: number, title: string, desc: string): Frame
	local frame = UI.new("Frame", {
		Name = title,
		Parent = list,
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 56),
		BackgroundColor3 = UI.Color.PlateLight,
		BorderSizePixel = 0,
	}, { UI.corner(UI.Radius.Panel) })
	UI.text({
		Parent = frame,
		Role = "Title",
		TextSize = 18,
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(0.42, -12, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = title,
	})
	UI.text({
		Parent = frame,
		Role = "Body",
		TextSize = 13,
		Position = UDim2.fromOffset(12, 31),
		Size = UDim2.new(0.42, -12, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Color.TextDim,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = desc,
	})
	return frame
end

-- A slider with a big touch area: tap or drag anywhere on the track. Snaps to 5%.
local function slider(frame: Frame, kind: string)
	local area = UI.new("TextButton", {
		Name = "Slider",
		Parent = frame,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -70, 0.5, 0),
		Size = UDim2.new(0.58, -80, 1, -4),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	})
	local track = UI.new("Frame", {
		Name = "Track",
		Parent = area,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 10),
		BackgroundColor3 = UI.Color.Disabled,
		BorderSizePixel = 0,
	}, { UI.corner(5) })
	local fill = UI.new("Frame", {
		Name = "Fill",
		Parent = track,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UI.Color.Coin,
		BorderSizePixel = 0,
	}, { UI.corner(5) })
	local knob = UI.new("Frame", {
		Name = "Knob",
		Parent = track,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = UI.Color.Text,
		BorderSizePixel = 0,
	}, { UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), UI.stroke(UI.Color.Outline, 2) })
	local percent = UI.text({
		Name = "Percent",
		Parent = frame,
		Role = "Title",
		TextSize = 18,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(56, 24),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "100%",
	})

	local function show(value: number)
		fill.Size = UDim2.fromScale(value, 1)
		knob.Position = UDim2.fromScale(value, 0.5)
		percent.Text = ("%d%%"):format(math.floor(value * 100 + 0.5))
		percent.TextColor3 = if value == 0 then UI.Color.TextMuted else UI.Color.Text
	end
	local lastPreview = 0
	local function setFromX(x: number)
		local f = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
		f = math.floor(f * 20 + 0.5) / 20
		if f ~= hooks.GetVolume(kind) then
			hooks.SetVolume(kind, f)
			show(f)
			if os.clock() - lastPreview > 0.25 then
				lastPreview = os.clock()
				hooks.Preview(kind)
			end
		end
	end

	local dragging: InputObject? = nil
	area.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = input
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseMovement
			or (input.UserInputType == Enum.UserInputType.Touch and input == dragging)
		then
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input == dragging or input.UserInputType == Enum.UserInputType.MouseButton1) then
			dragging = nil
		end
	end)
	show(hooks.GetVolume(kind))
end

function Settings.toggle()
	if modal.IsOpen() then
		modal.Close()
	else
		modal.Open()
	end
end

function Settings.modal(): UI.Modal
	return modal
end

function Settings.init(root: Frame, h: Hooks)
	hooks = h
	modal = UI.modal(root, "Settings", "SETTINGS", Vector2.new(540, 370))
	local list = UI.new("ScrollingFrame", {
		Name = "List",
		Parent = modal.Content,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, { UI.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })

	slider(rowFrame(list, 1, "Master", "Everything you hear."), "Master")
	slider(rowFrame(list, 2, "Effects", "Pickups, sales, warnings, buttons."), "Effects")
	slider(rowFrame(list, 3, "Weather", "Rain, wind, flood water, thunder."), "Weather")

	local reducedRow = rowFrame(list, 4, "Reduced Effects", "No flashes, swaying or UI motion.")
	local toggle = UI.button({
		Name = "Toggle",
		Parent = reducedRow,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(96, math.min(UI.buttonSize(), 56)),
		TextSize = 18,
	})
	local function show()
		local on = hooks.IsReduced()
		toggle.Text = if on then "ON" else "OFF"
		UI.setButtonColor(toggle, if on then UI.Color.Buy else UI.Color.Slate)
	end
	toggle.Activated:Connect(function()
		hooks.SetReduced(not hooks.IsReduced())
		show()
	end)
	show()

	-- Under the title, so the four rows fit on small phones without scrolling.
	UI.text({
		Name = "Footnote",
		Parent = modal.Panel,
		Role = "Caption",
		Position = UDim2.fromOffset(18, 46),
		Size = UDim2.new(1, -110, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Color.TextMuted,
		Text = "Settings last until you leave the game.",
	})
end

return Settings
