-- @file Jobs board and nameplate locker
-- @domain progression
-- @status stable
-- @see [[V3-PROGRESSION]]
-- The Jobs board (Salvage Contracts + Salvager Reputation) and the nameplate locker, as one modal
-- in the Workshop style: a corkboard with three pinned job slips, the rank strip on top, and a
-- second tab of nameplate finishes bought with coins. Everything shown comes from the server's
-- player state; buttons only send requests (ProgressAction) that the server validates.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Progression = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Progression"))
local Remotes = require(ReplicatedStorage.Shared:WaitForChild("Remotes"))
local PlateStyle = require(script.Parent:WaitForChild("PlateStyle"))
local UI = require(script.Parent:WaitForChild("UI"))

local Jobs = {}
local M = UI.Mat

local modal: UI.Modal
local state: any = nil
local action: RemoteEvent
local views: { [string]: GuiObject } = {}
local tabButtons: { [string]: TextButton } = {}

-- Rank strip.
local rankTitle: TextLabel
local rankXP: TextLabel
local rankFill: Frame

type Slip = {
	Frame: Frame,
	Text: TextLabel,
	Count: TextLabel,
	Fill: Frame,
	Reward: TextLabel,
	Pin: TextButton,
	Swap: TextButton,
	Id: string?,
}
local slips: { Slip } = {}

type FinishRow = { Button: TextButton, Note: TextLabel, Finish: Progression.Finish }
local finishRows: { FinishRow } = {}

---------------------------------------------------------------------------- Jobs tab

local function buildSlip(parent: Instance, i: number): Slip
	local frame = UI.new("Frame", {
		Name = "Job" .. i,
		Parent = parent,
		LayoutOrder = i,
		Size = UDim2.new(1 / 3, -8, 1, 0),
		Rotation = if UI.reduced() then 0 else (i - 2) * 1.2,
		BackgroundColor3 = if i == 2 then M.Note else M.Paper,
		BorderSizePixel = 0,
		ZIndex = 22,
	}, { UI.corner(3), UI.stroke(M.KraftEdge, 1.5) })
	UI.tape(frame, UDim2.new(0.5, 0, 0, 0), Vector2.new(60, 16), -3, nil, 24)
	local text = UI.text({
		Parent = frame,
		Font = UI.Font.Label,
		TextSize = 16,
		Position = UDim2.fromOffset(10, 16),
		Size = UDim2.new(1, -20, 0, 44),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = M.Marker,
		Text = "",
		ZIndex = 23,
	})
	local count = UI.text({
		Parent = frame,
		Font = UI.Font.Mono,
		TextSize = 22,
		Position = UDim2.fromOffset(10, 64),
		Size = UDim2.new(1, -20, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = M.Marker,
		Text = "",
		ZIndex = 23,
	})
	local bar = UI.new("Frame", {
		Parent = frame,
		Position = UDim2.fromOffset(10, 92),
		Size = UDim2.new(1, -20, 0, 10),
		BackgroundColor3 = Color3.fromRGB(220, 212, 194),
		BorderSizePixel = 0,
		ZIndex = 23,
	}, { UI.corner(3) })
	local fill = UI.new("Frame", {
		Parent = bar,
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = M.Orange,
		BorderSizePixel = 0,
		ZIndex = 24,
	}, { UI.corner(3) })
	local reward = UI.text({
		Parent = frame,
		Font = UI.Font.Mono,
		TextSize = 13,
		Position = UDim2.fromOffset(10, 108),
		Size = UDim2.new(1, -20, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(34, 120, 50),
		Text = "",
		ZIndex = 23,
	})
	local buttons = UI.new("Frame", {
		Name = "Buttons",
		Parent = frame,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -16, 0, math.min(UI.buttonSize(), 44)),
		BackgroundTransparency = 1,
		ZIndex = 23,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local function small(name: string, order: number, color: Color3): TextButton
		local b = UI.button({
			Name = name,
			Parent = buttons,
			LayoutOrder = order,
			Size = UDim2.new(0.5, -3, 1, 0),
			TextSize = 13,
			Color = color,
			ZIndex = 24,
		})
		b.Font = UI.Font.Mono
		return b
	end
	local slip: Slip = {
		Frame = frame,
		Text = text,
		Count = count,
		Fill = fill,
		Reward = reward,
		Pin = small("Pin", 1, M.Orange),
		Swap = small("Swap", 2, UI.Color.Slate),
	}
	slip.Pin.Activated:Connect(function()
		if slip.Id then
			action:FireServer("pin", slip.Id)
		end
	end)
	slip.Swap.Activated:Connect(function()
		if slip.Id then
			action:FireServer("swap", slip.Id)
		end
	end)
	return slip
end

local function buildJobs(parent: Instance): Frame
	local view = UI.new("Frame", {
		Name = "JobsView",
		Parent = parent,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 21,
	})
	-- Rank strip: title, XP bar, what's next.
	local strip = UI.new("Frame", {
		Name = "Rank",
		Parent = view,
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = M.Manila,
		BorderSizePixel = 0,
		ZIndex = 22,
	}, { UI.corner(6), UI.stroke(M.KraftEdge, 2) })
	rankTitle = UI.text({
		Parent = strip,
		Font = UI.Font.Title,
		TextSize = 22,
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(0.5, 0, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = M.Marker,
		Text = "",
		ZIndex = 23,
	})
	rankXP = UI.text({
		Parent = strip,
		Font = UI.Font.Label,
		TextSize = 13,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.new(0.5, -12, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = M.Pencil,
		Text = "",
		ZIndex = 23,
	})
	local bar = UI.new("Frame", {
		Parent = strip,
		Position = UDim2.fromOffset(12, 36),
		Size = UDim2.new(1, -24, 0, 12),
		BackgroundColor3 = Color3.fromRGB(220, 212, 194),
		BorderSizePixel = 0,
		ZIndex = 23,
	}, { UI.corner(4) })
	rankFill = UI.new("Frame", {
		Parent = bar,
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.fromRGB(80, 150, 230),
		BorderSizePixel = 0,
		ZIndex = 24,
	}, { UI.corner(4) })
	local row = UI.new("Frame", {
		Name = "Slips",
		Parent = view,
		Position = UDim2.fromOffset(4, 70),
		Size = UDim2.new(1, -8, 1, -74),
		BackgroundTransparency = 1,
		ZIndex = 21,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i = 1, Progression.ACTIVE do
		slips[i] = buildSlip(row, i)
	end
	return view
end

---------------------------------------------------------------------------- Nameplate tab

-- A small preview of a nameplate in a finish.
local function plate(parent: Instance, f: Progression.Finish, title: string, z: number): Frame
	local p = UI.new("Frame", {
		Parent = parent,
		Size = UDim2.fromOffset(150, 40),
		BorderSizePixel = 0,
		ZIndex = z,
	}, { UI.corner(6), UI.stroke(Color3.new(), 3) })
	local textColor = PlateStyle.apply(p, f.Id, z)
	UI.text({
		Parent = p,
		Font = UI.Font.Mono,
		TextSize = 14,
		Position = UDim2.fromOffset(0, 3),
		Size = UDim2.new(1, 0, 0, 18),
		TextColor3 = textColor,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = Players.LocalPlayer.DisplayName,
		ZIndex = z + 1,
	})
	UI.text({
		Parent = p,
		Font = UI.Font.Label,
		TextSize = 11,
		Position = UDim2.fromOffset(0, 21),
		Size = UDim2.new(1, 0, 0, 14),
		TextColor3 = textColor,
		Text = title,
		ZIndex = z + 1,
	})
	return p
end

local function buildLocker(parent: Instance): Frame
	local view = UI.new("ScrollingFrame", {
		Name = "LockerView",
		Parent = parent,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Visible = false,
		ZIndex = 21,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.new(0.5, -6, 0, 64),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, f in Progression.Finishes do
		local cell = UI.new("Frame", {
			Name = f.Id,
			Parent = view,
			LayoutOrder = i,
			BackgroundColor3 = M.Manila,
			BorderSizePixel = 0,
			ZIndex = 22,
		}, { UI.corner(6), UI.stroke(M.KraftEdge, 1.5) })
		local preview = plate(cell, f, f.Name, 23)
		preview.Position = UDim2.fromOffset(8, 12)
		local note = UI.text({
			Parent = cell,
			Font = UI.Font.Label,
			TextSize = 11,
			Position = UDim2.new(0, 166, 0, 6),
			Size = UDim2.new(1, -174, 0, 14),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = M.Pencil,
			Text = "",
			ZIndex = 23,
		})
		local b = UI.button({
			Name = "Buy",
			Parent = cell,
			Position = UDim2.new(0, 166, 0, 22),
			Size = UDim2.new(1, -174, 0, 36),
			TextSize = 12,
			Color = M.Orange,
			ZIndex = 23,
		})
		b.Font = UI.Font.Mono
		local row: FinishRow = { Button = b, Note = note, Finish = f }
		b.Activated:Connect(function()
			if not state then
				return
			end
			if state.Cosmetics.Owned[f.Id] then
				action:FireServer("equipFinish", f.Id)
			else
				action:FireServer("buyFinish", f.Id)
			end
		end)
		table.insert(finishRows, row)
	end
	return view
end

---------------------------------------------------------------------------- Refresh

function Jobs.refresh()
	if not state or not state.Rep then
		return
	end
	local xp = state.Rep.XP
	local rank = Progression.rankFor(xp)
	local nextRank = Progression.nextRank(xp)
	rankTitle.Text = rank.Title
	if nextRank then
		rankXP.Text = ("%s / %s XP to %s"):format(UI.comma(xp), UI.comma(nextRank.XP), nextRank.Title)
		rankFill.Size = UDim2.fromScale(math.clamp((xp - rank.XP) / (nextRank.XP - rank.XP), 0, 1), 1)
	else
		rankXP.Text = ("%s XP · top rank"):format(UI.comma(xp))
		rankFill.Size = UDim2.fromScale(1, 1)
	end
	local c = state.Contracts
	for i, slip in slips do
		local job = c.Active[i]
		slip.Frame.Visible = job ~= nil
		if job then
			slip.Id = job.Id
			slip.Text.Text = Progression.describe(job)
			slip.Count.Text = ("%s / %s"):format(UI.comma(job.Progress), UI.comma(job.Target))
			slip.Fill.Size = UDim2.fromScale(math.clamp(job.Progress / job.Target, 0, 1), 1)
			slip.Reward.Text = ("+%d coins · +%d XP"):format(job.Coins, job.XP)
			local pinned = c.Pinned == job.Id
			slip.Pin.Text = if pinned then "PINNED" else "PIN"
			UI.setButtonColor(slip.Pin, if pinned then Color3.fromRGB(58, 150, 72) else M.Orange)
			slip.Swap.Text = "SWAP"
		end
	end
	for _, row in finishRows do
		local f = row.Finish
		local owned = state.Cosmetics.Owned[f.Id]
		local equipped = state.Cosmetics.Plate == f.Id
		local text, color, disabled, note
		if equipped then
			text, color, disabled, note = "EQUIPPED", Color3.fromRGB(58, 150, 72), true, "On your nameplate"
		elseif owned then
			text, color, disabled, note = "EQUIP", UI.Color.Slate, false, "Owned"
		elseif rank.Index < f.Rank then
			text, color, disabled = "LOCKED", UI.Color.Disabled, true
			note = ("%s at %s"):format(UI.comma(f.Cost), Progression.Ranks[f.Rank].Title)
		elseif state.Coins < f.Cost then
			text, color, disabled = ("%s COINS"):format(UI.comma(f.Cost)), UI.Color.Disabled, false
			note = ("Need %s more"):format(UI.comma(f.Cost - state.Coins))
		else
			text, color, disabled, note = ("BUY · %s"):format(UI.comma(f.Cost)), M.Orange, false, "Coins"
		end
		row.Button.Text = text
		UI.setButtonColor(row.Button, color)
		row.Button:SetAttribute("Disabled", disabled)
		row.Note.Text = note
	end
end

function Jobs.setState(s: any)
	state = s
	if modal.IsOpen() then
		Jobs.refresh()
	end
end

-- The pinned job (or the first) for the HUD's objective note, e.g. "Sell 8 salvage  3/8".
function Jobs.pinnedLine(s: any): string?
	local c = s and s.Contracts
	if not c or not c.Active or #c.Active == 0 then
		return nil
	end
	local job = c.Active[1]
	for _, j in c.Active do
		if j.Id == c.Pinned then
			job = j
		end
	end
	return ("JOB: %s  %d/%d"):format(Progression.describe(job), job.Progress, job.Target)
end

function Jobs.showTab(name: string)
	for key, view in views do
		view.Visible = key == name
	end
	for key, b in tabButtons do
		local on = key == name
		b.BackgroundColor3 = if on then M.Manila else M.Kraft:Lerp(M.Marker, 0.25)
		b.TextColor3 = if on then M.Marker else M.Paper
	end
	Jobs.refresh()
end

function Jobs.open()
	Jobs.showTab("Jobs")
	modal.Open()
end

function Jobs.toggle()
	if modal.IsOpen() then
		modal.Close()
	else
		Jobs.open()
	end
end

function Jobs.modal(): UI.Modal
	return modal
end

function Jobs.init(root: Frame)
	action = Remotes.get("ProgressAction")
	modal = UI.modal(root, "Jobs", "JOBS", Vector2.new(660, 380))
	local panel = modal.Panel
	panel.BackgroundColor3 = Color3.fromRGB(176, 136, 92) -- corkboard
	panel.BackgroundTransparency = 0
	local stroke = panel:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = M.WoodDark
		stroke.Thickness = 5
	end
	local title = panel:FindFirstChild("Title") :: TextLabel?
	if title then
		title.TextColor3 = M.Marker
		title.TextXAlignment = Enum.TextXAlignment.Center
		title.Size = UDim2.fromOffset(180, 34)
		title.ZIndex = 23
		UI.tape(panel, UDim2.fromOffset(18 + 90, 12 + 17), Vector2.new(190, 36), -1.5, nil, 22).BackgroundTransparency =
			0
	end
	local tabs = UI.new("Frame", {
		Name = "Tabs",
		Parent = panel,
		Position = UDim2.fromOffset(220, 14),
		Size = UDim2.new(1, -300, 0, 40),
		BackgroundTransparency = 1,
		ZIndex = 23,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, entry in { { "Jobs", "CONTRACTS" }, { "Locker", "NAMEPLATE" } } do
		local b = UI.new("TextButton", {
			Name = entry[1],
			Parent = tabs,
			LayoutOrder = i,
			Size = UDim2.new(0.5, -3, 1, 0),
			BackgroundColor3 = M.Manila,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			Font = UI.Font.Mono,
			TextSize = 13,
			TextColor3 = M.Marker,
			Text = entry[2],
			ZIndex = 24,
		}, { UI.corner(6), UI.stroke(M.KraftEdge, 2) })
		b.Activated:Connect(function()
			Jobs.showTab(entry[1])
		end)
		tabButtons[entry[1]] = b
	end
	views.Jobs = buildJobs(modal.Content)
	views.Locker = buildLocker(modal.Content)
	Jobs.showTab("Jobs")
end

return Jobs
