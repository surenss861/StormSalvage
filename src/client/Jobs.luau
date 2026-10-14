-- @file Jobs board, nameplate locker and Salvage Log
-- @domain progression
-- @status stable
-- @see [[V3-PROGRESSION]]
-- @see [[SalvageLog.luau]]
-- The Jobs board (Salvage Contracts + Salvager Reputation), the nameplate locker and the Salvage
-- Log, as one modal in the Workshop style: a corkboard with three pinned job slips, the rank strip
-- on top, a second tab of nameplate finishes bought with coins, and a third tab with every kind
-- of salvage (found ones with their model, count and where they turn up; the rest a mystery). Everything shown comes from the server's
-- player state; buttons only send requests (ProgressAction) that the server validates.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Bands = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Bands"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Progression = require(ReplicatedStorage.Shared:WaitForChild("Progression"))
local SalvageLog = require(ReplicatedStorage.Shared:WaitForChild("SalvageLog"))
local Titles = require(ReplicatedStorage.Shared:WaitForChild("Titles"))
local BigMoney = require(ReplicatedStorage.Shared:WaitForChild("BigMoney"))
local PlayerCard = require(script.Parent:WaitForChild("PlayerCard"))
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

type LogTile = {
	Id: string,
	Frame: TextButton,
	View: ViewportFrame,
	Mystery: TextLabel,
	Name: TextLabel,
	Rarity: TextLabel,
	Count: TextLabel,
	Hint: TextLabel,
	Stamp: TextLabel,
	Shown: boolean?,
}
local logTiles: { LogTile } = {}
local logFilter = "All"
local RARITY_FILTERS = { "All", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
local logSelected: string? = nil
local detail: { [string]: any } = {}

type TitleRow = { Id: string, Frame: Frame, Button: TextButton, State: TextLabel }
local titleRows: { TitleRow } = {}
local showingLabel: TextLabel
local rankButton: TextButton
local logCount: TextLabel
local logFill: Frame
local logTotal: TextLabel

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
		BackgroundColor3 = M.BarTrack,
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
		TextColor3 = M.Reward,
		Text = "",
		ZIndex = 23,
	})
	local buttons = UI.new("Frame", {
		Name = "Buttons",
		Parent = frame,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -16, 0, if UI.compact() then UI.buttonSize() else 44),
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
		BackgroundColor3 = M.BarTrack,
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
	local all: { any } = table.clone(Progression.Finishes)
	for _, f in Progression.PremiumFinishes do
		table.insert(all, f)
	end
	for i, f in all do
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
			local paid = (f :: any).Paid == true
			if state.Cosmetics.Owned[f.Id] or (paid and (state.Passes or {})[(f :: any).Pass]) then
				action:FireServer("equipFinish", f.Id)
			elseif not paid then
				action:FireServer("buyFinish", f.Id)
			end
		end)
		table.insert(finishRows, row)
	end
	return view
end

---------------------------------------------------------------------------- Salvage Log tab

-- Where a kind turns up, shown only once it has been found (never for undiscovered kinds).
local function whereFound(id: string): string
	local class = Config.Loot[id] and Config.Loot[id].Class
	if class == "Industrial" then
		return "Industrial yards · Pro license"
	elseif class == "Artifact" then
		local storm = Config.Loot[id].Storm
		local name = storm and Config.Storms[storm] and Config.Storms[storm].DisplayName or "a storm"
		return ("Mid-%s, out in the open · Hunter"):format(string.lower(name))
	elseif class == "StormHeart" then
		return "The Storm's Eye · Storm Hunter license"
	elseif class == "Vault" then
		return "The Armored Wreck · Heavy license"
	elseif class == "Mythic" then
		for _, m in Bands.Mythic do
			if m.Id == id then
				return ("The Storm Titan · %d%% of cores · Legend"):format(math.floor(m.Odds * 100 + 0.5))
			end
		end
		return "The Storm Titan · Legend license"
	elseif id == "StormCore" then
		return "Mid-storm, anywhere in town"
	elseif id == "GoldenCore" then
		return "The rare prize of a cache event"
	end
	local zones = {}
	for _, zone in Progression.ZoneOrder do
		for _, entry in Config.ZonePools[zone] or {} do
			if entry.Id == id then
				table.insert(
					zones,
					{ Name = (Progression.Zones[zone] or zone):gsub("^the ", ""), Weight = entry.Weight }
				)
			end
		end
	end
	table.sort(zones, function(a, b)
		return a.Weight > b.Weight
	end)
	local names = {}
	for i, z in zones do
		if i <= 3 then
			table.insert(names, z.Name)
		end
	end
	return if #names > 0 then table.concat(names, " · ") else "Around town"
end

-- Puts the salvage model in a tile's viewport, framed three-quarter view. The models come from
-- ReplicatedStorage.SalvageModels (the server's copy); without them the tile keeps its "?".
local function frameModel(id: string, view: ViewportFrame, spin: number?): Model?
	local models = ReplicatedStorage:FindFirstChild("SalvageModels")
	local source = models and models:FindFirstChild(id)
	if not source or not source:IsA("Model") then
		return nil
	end
	view:ClearAllChildren()
	local model = source:Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	model.Parent = view
	local cf, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local distance = size.Magnitude / 2 / math.tan(math.rad(15)) * 1.05
	local a = spin or 0
	camera.CFrame = CFrame.lookAt(
		cf.Position + Vector3.new(math.cos(a + 0.8), 0.6, -math.sin(a + 0.8)).Unit * distance,
		cf.Position
	)
	camera.Parent = view
	view.CurrentCamera = camera
	return model
end

local function showModel(tile: LogTile): boolean
	local models = ReplicatedStorage:FindFirstChild("SalvageModels")
	local source = models and models:FindFirstChild(tile.Id)
	if not source or not source:IsA("Model") then
		return false
	end
	local model = source:Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	model.Parent = tile.View
	local cf, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local distance = size.Magnitude / 2 / math.tan(math.rad(15)) * 1.05
	camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(1, 0.6, -1).Unit * distance, cf.Position)
	camera.Parent = tile.View
	tile.View.CurrentCamera = camera
	return true
end

local refreshLog: () -> ()

local function buildLog(parent: Instance): Frame
	local view = UI.new("Frame", {
		Name = "LogView",
		Parent = parent,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 21,
	})
	-- Progress strip: a manila label with a ruled fill bar.
	local strip = UI.new("Frame", {
		Name = "Progress",
		Parent = view,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = M.Manila,
		BorderSizePixel = 0,
		ZIndex = 22,
	}, { UI.corner(6), UI.stroke(M.KraftEdge, 1.5) })
	logCount = UI.text({
		Parent = strip,
		Font = UI.Font.Mono,
		TextSize = 16,
		Position = UDim2.fromOffset(12, 3),
		Size = UDim2.new(0.6, -12, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = M.Marker,
		Text = "",
		ZIndex = 23,
	})
	logTotal = UI.text({
		Parent = strip,
		Font = UI.Font.Label,
		TextSize = 12,
		Position = UDim2.new(0.6, 0, 0, 4),
		Size = UDim2.new(0.4, -12, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = M.Pencil,
		Text = "",
		ZIndex = 23,
	})
	local track = UI.new("Frame", {
		Parent = strip,
		Position = UDim2.new(0, 12, 0, 26),
		Size = UDim2.new(1, -24, 0, 7),
		BackgroundColor3 = M.Kraft,
		BorderSizePixel = 0,
		ZIndex = 23,
	}, { UI.corner(3) })
	logFill = UI.new("Frame", {
		Parent = track,
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = M.Orange,
		BorderSizePixel = 0,
		ZIndex = 24,
	}, { UI.corner(3) })

	-- Rarity filter: chips on desktop; on phones, where seven chips can't each be a thumb
	-- target, one full-size button that steps through the rarities.
	local compact = UI.compact()
	local filterH = if compact then UI.buttonSize() else 26
	local chips = UI.new("Frame", {
		Name = "Filters",
		Parent = view,
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(0.66, 0, 0, filterH),
		BackgroundTransparency = 1,
		ZIndex = 22,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 5),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	if compact then
		local cycle = UI.new("TextButton", {
			Name = "Cycle",
			Parent = chips,
			Size = UDim2.new(0.6, 0, 1, 0),
			BackgroundColor3 = M.Manila,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			FontFace = UI.Heading,
			TextSize = 16,
			TextColor3 = M.Marker,
			Text = "",
			ZIndex = 23,
		}, { UI.corner(10), UI.stroke(M.KraftEdge, 2) })
		cycle.Activated:Connect(function()
			logFilter = RARITY_FILTERS[(table.find(RARITY_FILTERS, logFilter) or 1) % #RARITY_FILTERS + 1]
			refreshLog()
		end)
		detail.Cycle = cycle
	end
	for k, r in RARITY_FILTERS do
		if compact then
			break
		end
		local chip = UI.new("TextButton", {
			Name = r,
			Parent = chips,
			LayoutOrder = k,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 24),
			BackgroundColor3 = M.Manila,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			FontFace = UI.Heading,
			TextSize = 12,
			TextColor3 = M.Marker,
			Text = string.upper(r),
			ZIndex = 23,
		}, {
			UI.corner(12),
			UI.padding(0, 10),
			UI.stroke(if r == "All" then M.KraftEdge else (Config.RarityColors[r] or M.KraftEdge), 1.5),
		})
		chip.Activated:Connect(function()
			logFilter = r
			refreshLog()
		end)
		detail["Chip" .. r] = chip
	end

	-- The detail panel: the selected find, large and turning.
	local panel = UI.new("Frame", {
		Name = "Detail",
		Parent = view,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 46),
		Size = UDim2.new(0.33, -6, 1, -46),
		BackgroundColor3 = M.Manila,
		BorderSizePixel = 0,
		ZIndex = 22,
	}, { UI.corner(6), UI.stroke(M.KraftEdge, 1.5) })
	detail.Panel = panel
	detail.View = UI.new("ViewportFrame", {
		Parent = panel,
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 0.55, -8),
		BackgroundColor3 = M.Paper,
		BackgroundTransparency = 0,
		Ambient = Color3.fromRGB(170, 160, 150),
		LightColor = Color3.fromRGB(255, 244, 225),
		LightDirection = Vector3.new(-1, -1.5, 0.6),
		ZIndex = 23,
	}, { UI.corner(6) })
	detail.Name = UI.text({
		Parent = panel,
		FontFace = UI.Heading,
		TextSize = 22,
		Position = UDim2.new(0, 10, 0.55, 6),
		Size = UDim2.new(1, -20, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = M.Marker,
		Text = "",
		ZIndex = 23,
	})
	detail.Rarity = UI.text({
		Parent = panel,
		FontFace = UI.Heading,
		TextSize = 13,
		Position = UDim2.new(0, 10, 0.55, 34),
		Size = UDim2.new(1, -20, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		ZIndex = 23,
	})
	detail.Value = UI.text({
		Parent = panel,
		FontFace = UI.Heading,
		TextSize = 18,
		Position = UDim2.new(0, 10, 0.55, 54),
		Size = UDim2.new(1, -20, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Arcade.Gold,
		Text = "",
		ZIndex = 23,
	})
	detail.Where = UI.text({
		Parent = panel,
		Font = UI.Font.Label,
		TextSize = 12,
		Position = UDim2.new(0, 10, 0.55, 80),
		Size = UDim2.new(1, -20, 0.45, -88),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = M.Pencil,
		Text = "",
		ZIndex = 23,
	})

	local grid = UI.new("ScrollingFrame", {
		Name = "Entries",
		Parent = view,
		Position = UDim2.fromOffset(0, 46 + filterH + 6),
		Size = UDim2.new(0.67, -6, 1, -(46 + filterH + 6)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 21,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.new(0.5, -6, 0, 96),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		UI.padding(0, 6, 4, 0),
	})
	for i, id in SalvageLog.order(Config.Loot) do
		local def = Config.Loot[id]
		local frame = UI.new("TextButton", {
			Name = id,
			Parent = grid,
			LayoutOrder = i,
			BackgroundColor3 = M.Paper,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			ZIndex = 22,
		}, { UI.corner(5), UI.stroke(M.KraftEdge, 1.5) })
		frame.Activated:Connect(function()
			logSelected = id
			refreshLog()
		end)
		-- Rarity edge down the left side, like a coloured file tab.
		UI.new("Frame", {
			Name = "Edge",
			Parent = frame,
			Size = UDim2.new(0, 5, 1, 0),
			BackgroundColor3 = Config.RarityColors[def.Rarity] or M.Pencil,
			BorderSizePixel = 0,
			ZIndex = 23,
		}, { UI.corner(3) })
		local well = UI.new("Frame", {
			Name = "Well",
			Parent = frame,
			Position = UDim2.fromOffset(11, 8),
			Size = UDim2.fromOffset(62, 62),
			BackgroundColor3 = M.Manila,
			BorderSizePixel = 0,
			ZIndex = 23,
		}, { UI.corner(5) })
		local vp = UI.new("ViewportFrame", {
			Parent = well,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Ambient = Color3.fromRGB(170, 160, 150),
			LightColor = Color3.fromRGB(255, 244, 225),
			LightDirection = Vector3.new(-1, -1.5, 0.6),
			ZIndex = 24,
		})
		local mystery = UI.text({
			Parent = well,
			Font = UI.Font.Mono,
			TextSize = 30,
			Size = UDim2.fromScale(1, 1),
			TextColor3 = M.Paper,
			Text = "?",
			ZIndex = 25,
		})
		local name = UI.text({
			Parent = frame,
			Font = UI.Font.Label,
			TextSize = 14,
			Position = UDim2.fromOffset(80, 6),
			Size = UDim2.new(1, -86, 0, 32),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = M.Marker,
			Text = "",
			ZIndex = 23,
		})
		-- Rarity as a coloured pill, readable on both the paper and the kraft (mystery) card.
		local rarity = UI.text({
			Parent = frame,
			Font = UI.Font.Mono,
			TextSize = 10,
			Position = UDim2.fromOffset(80, 38),
			Size = UDim2.fromOffset(84, 15),
			BackgroundColor3 = Config.RarityColors[def.Rarity] or M.Pencil,
			TextColor3 = UI.inkOn(Config.RarityColors[def.Rarity] or M.Pencil),
			Text = string.upper(def.Rarity),
			ZIndex = 23,
		})
		rarity.BackgroundTransparency = 0 -- UI.text makes labels clear
		UI.corner(4).Parent = rarity
		local count = UI.text({
			Parent = frame,
			Font = UI.Font.Mono,
			TextSize = 14,
			Position = UDim2.fromOffset(80, 53),
			Size = UDim2.new(1, -86, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = M.Marker,
			Text = "",
			ZIndex = 23,
		})
		local hint = UI.text({
			Parent = frame,
			Font = UI.Font.Label,
			TextSize = 11,
			Position = UDim2.fromOffset(11, 74),
			Size = UDim2.new(1, -17, 0, 16),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = M.Pencil,
			Text = "",
			ZIndex = 23,
		})
		-- JACKPOT stamp across the bottom of the model well.
		local stamp = UI.text({
			Name = "Stamp",
			Parent = frame,
			Font = UI.Font.Mono,
			TextSize = 11,
			Position = UDim2.fromOffset(8, 58),
			Size = UDim2.fromOffset(68, 16),
			Rotation = if UI.reduced() then 0 else -6,
			BackgroundColor3 = M.Note,
			TextColor3 = M.RedPen,
			Text = "JACKPOT",
			Visible = false,
			ZIndex = 26,
		})
		stamp.BackgroundTransparency = 0
		UI.stroke(M.RedPen, 1.5).Parent = stamp
		table.insert(logTiles, {
			Id = id,
			Frame = frame,
			View = vp,
			Mystery = mystery,
			Name = name,
			Rarity = rarity,
			Count = count,
			Hint = hint,
			Stamp = stamp,
		})
	end
	-- The detail model turns slowly (still in Reduced Effects).
	game:GetService("RunService").RenderStepped:Connect(function(dt)
		local model = detail.Model :: Model?
		if model and model.Parent and view.Visible and not UI.reduced() then
			model:PivotTo(model:GetPivot() * CFrame.Angles(0, dt * 0.7, 0))
		end
	end)
	return view
end

function refreshLog()
	local collection = SalvageLog.reconcile(state and state.Collection)
	local found, total = SalvageLog.progress(collection, Config.Loot)
	local finds = 0
	for _, n in collection.Counts do
		finds += n
	end
	logCount.Text = ("SALVAGE LOG   %d / %d FOUND"):format(found, total)
	logTotal.Text = if found == total
		then ("Complete! %s finds logged"):format(UI.comma(finds))
		else ("%s finds logged"):format(UI.comma(finds))
	logFill.Size = UDim2.fromScale(if total > 0 then found / total else 0, 1)
	for _, tile in logTiles do
		local def = Config.Loot[tile.Id]
		local known = collection.Found[tile.Id] == true
		if known then
			tile.Frame.BackgroundColor3 = if def.Jackpot then M.Note else M.Paper
			tile.Name.Text = def.Name
			tile.Count.Text = ("x%s  ·  %s c"):format(
				UI.comma(collection.Counts[tile.Id] or 1),
				UI.comma(def.Value)
			)
			tile.Hint.Text = whereFound(tile.Id)
			tile.Stamp.Visible = def.Jackpot == true
		else
			-- Undiscovered: rarity only. No name, value, model or where to look.
			tile.Frame.BackgroundColor3 = M.Kraft
			tile.Name.Text = "???"
			tile.Count.Text = "Not found yet"
			tile.Hint.Text = "Keep salvaging"
			tile.Stamp.Visible = false
		end
		if not tile.Shown then
			tile.Shown = showModel(tile)
		end
		-- Undiscovered kinds show only their silhouette: a shape to look for, nothing else.
		tile.View.Visible = tile.Shown == true
		tile.View.ImageColor3 = if known then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
		tile.View.ImageTransparency = if known then 0 else 0.15
		tile.Mystery.Visible = not tile.View.Visible
		tile.Mystery.Text = if known then "" else "?"
		tile.Mystery.Parent.BackgroundColor3 = if known then M.Manila else M.KraftEdge
		tile.Frame.Visible = logFilter == "All" or def.Rarity == logFilter
		local stroke = tile.Frame:FindFirstChildOfClass("UIStroke") :: UIStroke
		stroke.Color = if logSelected == tile.Id then M.Orange else M.KraftEdge
		stroke.Thickness = if logSelected == tile.Id then 3 else 1.5
	end
	for _, r in RARITY_FILTERS do
		local chip = detail["Chip" .. r] :: TextButton?
		if chip then
			chip.BackgroundColor3 = if logFilter == r then M.Orange else M.Manila
			chip.TextColor3 = UI.inkOn(chip.BackgroundColor3)
		end
	end
	local cycle = detail.Cycle :: TextButton?
	if cycle then
		cycle.Text = ("SHOWING: %s  >"):format(string.upper(logFilter))
		local stroke = cycle:FindFirstChildOfClass("UIStroke") :: UIStroke
		stroke.Color = if logFilter == "All"
			then M.KraftEdge
			else (Config.RarityColors[logFilter] or M.KraftEdge)
	end
	-- Detail: the selected kind, or the rarest one found so far.
	local pick = logSelected
	if not pick then
		for i = #logTiles, 1, -1 do
			if collection.Found[logTiles[i].Id] then
				pick = logTiles[i].Id
				break
			end
		end
	end
	local def = pick and Config.Loot[pick]
	local known = pick ~= nil and collection.Found[pick] == true
	if def and pick then
		if detail.Shown ~= pick then
			detail.Shown = pick
			detail.Model = frameModel(pick, detail.View, 0)
		end
		detail.View.ImageColor3 = if known then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
		detail.Name.Text = if known then string.upper(def.Name) else "???"
		detail.Rarity.Text = string.upper(def.Rarity)
		detail.Rarity.TextColor3 = Config.RarityColors[def.Rarity] or M.Pencil
		detail.Value.Text = if known then ("WORTH %s"):format(BigMoney.full(def.Value)) else ""
		detail.Where.Text = if known
			then ("%s\nLogged x%s"):format(whereFound(pick), UI.comma(collection.Counts[pick] or 1))
			else "Not found yet. Keep salvaging: its shape is your clue."
	end
end

---------------------------------------------------------------------------- Titles tab

local CATEGORY_COLORS = {
	Pursuit = Color3.fromRGB(240, 128, 36),
	Discovery = Color3.fromRGB(90, 170, 220),
	Career = Color3.fromRGB(150, 120, 210),
	Wealth = Color3.fromRGB(240, 196, 70),
}

local function buildTitles(parent: Instance): Frame
	local view = UI.new("Frame", {
		Name = "TitlesView",
		Parent = parent,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 21,
	})
	local strip = UI.new("Frame", {
		Name = "Showing",
		Parent = view,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = M.Manila,
		BorderSizePixel = 0,
		ZIndex = 22,
	}, { UI.corner(6), UI.stroke(M.KraftEdge, 1.5) })
	showingLabel = UI.text({
		Parent = strip,
		Font = UI.Font.Mono,
		TextSize = 14,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -250, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = M.Marker,
		Text = "",
		ZIndex = 23,
	})
	rankButton = UI.button({
		Name = "ShowRank",
		Parent = strip,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -118, 0.5, 0),
		Size = UDim2.fromOffset(110, 30),
		TextSize = 11,
		Color = UI.Color.Slate,
		Text = "SHOW RANK",
		ZIndex = 23,
	})
	rankButton.Font = UI.Font.Mono
	rankButton.Activated:Connect(function()
		action:FireServer("showTitle", nil)
	end)
	local myCard = UI.button({
		Name = "MyCard",
		Parent = strip,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(106, 30),
		TextSize = 11,
		Color = M.Orange,
		Text = "MY CARD",
		ZIndex = 23,
	})
	myCard.Font = UI.Font.Mono
	myCard.Activated:Connect(function()
		PlayerCard.request(Players.LocalPlayer.UserId)
	end)
	local grid = UI.new("ScrollingFrame", {
		Name = "List",
		Parent = view,
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 1, -48),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 21,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.new(1 / 3, -6, 0, 92),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		UI.padding(0, 6, 4, 0),
	})
	for i, def in Titles.List do
		local frame = UI.new("Frame", {
			Name = def.Id,
			Parent = grid,
			LayoutOrder = i,
			BackgroundColor3 = M.Paper,
			BorderSizePixel = 0,
			ZIndex = 22,
		}, { UI.corner(5), UI.stroke(M.KraftEdge, 1.5) })
		UI.new("Frame", {
			Parent = frame,
			Size = UDim2.new(0, 5, 1, 0),
			BackgroundColor3 = CATEGORY_COLORS[def.Category] or M.Pencil,
			BorderSizePixel = 0,
			ZIndex = 23,
		}, { UI.corner(3) })
		UI.text({
			Parent = frame,
			Font = UI.Font.Title,
			TextSize = 15,
			Position = UDim2.fromOffset(12, 5),
			Size = UDim2.new(1, -18, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = M.Marker,
			Text = def.Name,
			ZIndex = 23,
		})
		UI.text({
			Parent = frame,
			Font = UI.Font.Label,
			TextSize = 11,
			Position = UDim2.fromOffset(12, 26),
			Size = UDim2.new(1, -18, 0, 28),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = M.Pencil,
			Text = def.How,
			ZIndex = 23,
		})
		local stateLabel = UI.text({
			Parent = frame,
			Font = UI.Font.Mono,
			TextSize = 10,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 12, 1, -8),
			Size = UDim2.new(0.45, -12, 0, 22),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = CATEGORY_COLORS[def.Category] or M.Pencil,
			Text = string.upper(def.Category),
			ZIndex = 23,
		})
		local b = UI.button({
			Name = "Show",
			Parent = frame,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -6, 1, -6),
			Size = UDim2.new(0.55, -6, 0, 26),
			TextSize = 11,
			Color = M.Orange,
			ZIndex = 23,
		})
		b.Font = UI.Font.Mono
		b.Activated:Connect(function()
			action:FireServer("showTitle", def.Id)
		end)
		table.insert(titleRows, { Id = def.Id, Frame = frame, Button = b, State = stateLabel })
	end
	return view
end

local function refreshTitles()
	local t = state and state.Titles
	local owned = if t and type(t.Owned) == "table" then t.Owned else {}
	local shown = t and t.Shown
	local count = 0
	for _, row in titleRows do
		local have = owned[row.Id] == true
		if have then
			count += 1
		end
		row.Frame.BackgroundColor3 = if have then M.Paper else M.Kraft
		if shown == row.Id then
			row.Button.Text = "SHOWING"
			UI.setButtonColor(row.Button, Color3.fromRGB(58, 150, 72))
			row.Button:SetAttribute("Disabled", true)
		elseif have then
			row.Button.Text = "SHOW"
			UI.setButtonColor(row.Button, M.Orange)
			row.Button:SetAttribute("Disabled", false)
		else
			row.Button.Text = "NOT YET"
			UI.setButtonColor(row.Button, UI.Color.Disabled)
			row.Button:SetAttribute("Disabled", true)
		end
	end
	local def = shown and Titles.ById[shown]
	showingLabel.Text = if def
		then ("OVER YOUR NAME: %s   ·   %d / %d EARNED"):format(string.upper(def.Name), count, #Titles.List)
		else ("OVER YOUR NAME: YOUR RANK   ·   %d / %d EARNED"):format(count, #Titles.List)
	rankButton.Visible = def ~= nil
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
		local paid = (f :: any).Paid == true
		local owned = state.Cosmetics.Owned[f.Id] or (paid and (state.Passes or {})[(f :: any).Pass] == true)
		local equipped = state.Cosmetics.Plate == f.Id and owned
		local text, color, disabled, note
		if paid and not owned then
			-- Supporter finishes: Robux only, and only once the catalogue is switched on.
			local pass = Config.GamePasses[(f :: any).Pass]
			local onSale = Config.PurchasesEnabled and pass and pass.Id ~= 0
			text, color, disabled = if onSale then "SUPPORTER" else "NOT ON SALE YET", UI.Color.Disabled, true
			note = "Supporter finish · cosmetic only"
		elseif equipped then
			text, color, disabled, note = "EQUIPPED", Color3.fromRGB(58, 150, 72), true, "On your nameplate"
		elseif owned then
			text, color, disabled, note = "EQUIP", UI.Color.Slate, false, "Owned"
		elseif rank.Index < f.Rank then
			text, color, disabled = "LOCKED", UI.Color.Disabled, true
			note = ("%s at %s"):format(UI.comma(f.Cost), Progression.Ranks[f.Rank].Title)
		elseif BigMoney.lt(state.Coins, BigMoney.of(f.Cost)) then
			text, color, disabled = ("%s COINS"):format(UI.comma(f.Cost)), UI.Color.Disabled, false
			note = ("Need %s more"):format(
				BigMoney.full(BigMoney.sub(BigMoney.of(f.Cost), state.Coins) :: string)
			)
		else
			text, color, disabled, note = ("BUY · %s"):format(UI.comma(f.Cost)), M.Orange, false, "Coins"
		end
		row.Button.Text = text
		UI.setButtonColor(row.Button, color)
		row.Button:SetAttribute("Disabled", disabled)
		row.Note.Text = note
	end
	refreshLog()
	refreshTitles()
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
	panel.BackgroundColor3 = M.Cork -- corkboard (dark plate in Arcade)
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
		Size = UDim2.new(1, -300, 0, UI.tabHeight()),
		BackgroundTransparency = 1,
		ZIndex = 23,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, entry in
		{
			{ "Jobs", "CONTRACTS" },
			{ "Locker", "NAMEPLATE" },
			{ "Log", "SALVAGE LOG" },
			{ "Titles", "TITLES" },
		}
	do
		local b = UI.new("TextButton", {
			Name = entry[1],
			Parent = tabs,
			LayoutOrder = i,
			Size = UDim2.new(1 / 4, -5, 1, 0),
			BackgroundColor3 = M.Manila,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			Font = UI.Font.Mono,
			TextSize = if UI.compact() then 14 else 11, -- phones: two lines in the taller tab
			TextWrapped = true,
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
	views.Log = buildLog(modal.Content)
	views.Titles = buildTitles(modal.Content)
	Jobs.showTab("Jobs")
end

return Jobs
