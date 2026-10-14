-- @file V4 player card: inspect any salvager's public record
-- @domain progression
-- @status wip
-- @see [[StatusService.luau]]
-- @see [[V4-STATUS]]
-- Tap or click another player (or MY CARD on the Jobs board's Titles tab) to see their Salvager
-- ID: rank, band, earned title, lifetime earnings, extraction records and Salvage Log progress.
-- The client only asks (Inspect, with a user id); the server answers with public facts from its
-- own records (InspectCard). Everything else stays on the card, not over people's heads.
-- Tap detection ignores drags (camera swipes on phones) and taps on the HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local BigMoney = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BigMoney"))
local Remotes = require(ReplicatedStorage.Shared:WaitForChild("Remotes"))
local PlateStyle = require(script.Parent:WaitForChild("PlateStyle"))
local UI = require(script.Parent:WaitForChild("UI"))

local PlayerCard = {}
local M = UI.Mat

local modal: UI.Modal
local inspectRemote: RemoteEvent
local nameLabel: TextLabel
local handleLabel: TextLabel
local rankLabel: TextLabel
local bandBadge: TextLabel
local titleChip: TextLabel
local plateStrip: Frame
local cells: { [string]: { Value: TextLabel, Sub: TextLabel } } = {}

local HARDEST = { [0] = "-", [1] = "Easy", [2] = "Hard", [3] = "Hardest" }

local CELLS = {
	{ "Earned", "LIFETIME EARNED" },
	{ "NetWorth", "NET WORTH" },
	{ "Extractions", "EXTRACTIONS" },
	{ "Best", "BEST EXTRACTION" },
	{ "Streak", "BEST CLEAN STREAK" },
	{ "Golden", "GOLDEN CORES OUT" },
	{ "Hardest", "HARDEST EXTRACTION" },
	{ "Log", "SALVAGE LOG" },
	{ "Titles", "TITLES EARNED" },
}

function PlayerCard.request(userId: number)
	inspectRemote:FireServer(userId)
end

function PlayerCard.show(card: any)
	if type(card) ~= "table" then
		return
	end
	nameLabel.Text = tostring(card.DisplayName or "?")
	handleLabel.Text = "@" .. tostring(card.Name or "")
	rankLabel.Text = string.upper(tostring(card.Rank or ""))
	bandBadge.Text = ("BAND %d · %s"):format(card.Band or 1, string.upper(tostring(card.BandName or "")))
	bandBadge.BackgroundColor3 = if (card.Band or 1) >= 2 then Color3.fromRGB(240, 196, 70) else M.Tin
	titleChip.Visible = type(card.Title) == "string"
	titleChip.Text = if type(card.Title) == "string" then string.upper(card.Title) else ""
	PlateStyle.apply(plateStrip, card.Plate, 2)
	local function set(key: string, value: string, sub: string?)
		cells[key].Value.Text = value
		cells[key].Sub.Text = sub or ""
	end
	-- Exact strings from the server: compact on the card, every digit underneath while it fits.
	local function wealth(key: string, v: unknown)
		local amount = BigMoney.parse(v) or "0"
		set(key, BigMoney.compact(amount), if #amount <= 15 then BigMoney.full(amount) else "")
	end
	wealth("Earned", card.LifetimeEarned)
	wealth("NetWorth", card.NetWorth)
	set("Extractions", tostring(card.Extractions or 0))
	set("Best", if (card.BestExtract or 0) > 0 then ("%.1f s"):format(card.BestExtract) else "-")
	set("Streak", tostring(card.BestStreak or 0), "in a row, never caught")
	set("Golden", tostring(card.GoldenExtractions or 0))
	set("Hardest", HARDEST[card.Hardest or 0] or "-", if (card.Hardest or 0) > 0 then "site" else "none yet")
	set("Log", ("%d / %d"):format(card.Found or 0, card.FoundTotal or 0), "kinds found")
	set("Titles", ("%d / %d"):format(card.Titles or 0, card.TitlesTotal or 0))
	if not modal.IsOpen() then
		modal.Open()
	end
end

function PlayerCard.modal(): UI.Modal
	return modal
end

-- A tap or click on another player's character opens their card.
local function playerAt(screen: Vector2): Player?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local ray = camera:ScreenPointToRay(screen.X, screen.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { Players.LocalPlayer.Character :: Instance }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 120, params)
	local model = hit and hit.Instance:FindFirstAncestorOfClass("Model")
	while model do
		local p = Players:GetPlayerFromCharacter(model)
		if p then
			return p
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

function PlayerCard.init(root: Frame)
	inspectRemote = Remotes.get("Inspect")
	modal = UI.modal(root, "PlayerCard", "SALVAGER ID", Vector2.new(480, 330))
	-- A kraft ID card, like the Jobs corkboard, so the dark marker text reads.
	local panel = modal.Panel
	panel.BackgroundColor3 = M.Kraft
	panel.BackgroundTransparency = 0
	local edge = panel:FindFirstChildOfClass("UIStroke")
	if edge then
		edge.Color = M.KraftEdge
		edge.Thickness = 4
	end
	local heading = panel:FindFirstChild("Title") :: TextLabel?
	if heading then
		heading.TextColor3 = M.Marker
	end
	local content = modal.Content
	-- ID badge header: name, handle, rank, band, the earned title, and their nameplate finish.
	plateStrip = UI.new("Frame", {
		Name = "Plate",
		Parent = content,
		Size = UDim2.new(1, 0, 0, 8),
		BorderSizePixel = 0,
		ZIndex = 22,
	}, { UI.corner(3) })
	nameLabel = UI.text({
		Parent = content,
		Font = UI.Font.Title,
		TextSize = 24,
		Position = UDim2.fromOffset(4, 12),
		Size = UDim2.new(0.6, 0, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = M.Marker,
		Text = "",
		ZIndex = 22,
	})
	handleLabel = UI.text({
		Parent = content,
		Font = UI.Font.Label,
		TextSize = 12,
		Position = UDim2.fromOffset(4, 40),
		Size = UDim2.new(0.6, 0, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = M.Pencil,
		Text = "",
		ZIndex = 22,
	})
	rankLabel = UI.text({
		Parent = content,
		Font = UI.Font.Mono,
		TextSize = 13,
		Position = UDim2.fromOffset(4, 56),
		Size = UDim2.new(0.6, 0, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = M.Marker,
		Text = "",
		ZIndex = 22,
	})
	bandBadge = UI.text({
		Parent = content,
		Font = UI.Font.Mono,
		TextSize = 12,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 16),
		Size = UDim2.fromOffset(150, 22),
		TextColor3 = M.Marker,
		Text = "",
		ZIndex = 22,
	})
	bandBadge.BackgroundTransparency = 0
	UI.corner(4).Parent = bandBadge
	titleChip = UI.text({
		Parent = content,
		Font = UI.Font.Mono,
		TextSize = 13,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 44),
		Size = UDim2.fromOffset(150, 24),
		Rotation = if UI.reduced() then 0 else -3,
		TextColor3 = M.RedPen,
		Text = "",
		Visible = false,
		ZIndex = 23,
	})
	titleChip.BackgroundTransparency = 0
	titleChip.BackgroundColor3 = M.Note
	UI.stroke(M.RedPen, 2).Parent = titleChip
	-- The record: a grid of manila cells.
	local grid = UI.new("Frame", {
		Name = "Record",
		Parent = content,
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 1, -80),
		BackgroundTransparency = 1,
		ZIndex = 21,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.new(1 / 3, -6, 1 / 3, -6),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, spec in CELLS do
		local cell = UI.new("Frame", {
			Name = spec[1],
			Parent = grid,
			LayoutOrder = i,
			BackgroundColor3 = M.Manila,
			BorderSizePixel = 0,
			ZIndex = 22,
		}, { UI.corner(5), UI.stroke(M.KraftEdge, 1.5) })
		UI.text({
			Parent = cell,
			Font = UI.Font.Label,
			TextSize = 10,
			Position = UDim2.fromOffset(6, 4),
			Size = UDim2.new(1, -12, 0, 12),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = M.Pencil,
			Text = spec[2],
			ZIndex = 23,
		})
		local value = UI.text({
			Parent = cell,
			Font = UI.Font.Mono,
			TextSize = 20,
			TextScaled = false,
			Position = UDim2.new(0, 6, 0.5, -12),
			Size = UDim2.new(1, -12, 0, 24),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = M.Marker,
			Text = "",
			ZIndex = 23,
		})
		local sub = UI.text({
			Parent = cell,
			Font = UI.Font.Label,
			TextSize = 10,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 6, 1, -4),
			Size = UDim2.new(1, -12, 0, 12),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = M.Pencil,
			Text = "",
			ZIndex = 23,
		})
		cells[spec[1]] = { Value = value, Sub = sub }
	end

	Remotes.get("InspectCard").OnClientEvent:Connect(PlayerCard.show)

	-- Tap/click detection: a short press that didn't drag, not on the HUD.
	local pressAt: Vector2? = nil
	local pressTime = 0
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			pressAt = Vector2.new(input.Position.X, input.Position.Y)
			pressTime = os.clock()
		end
	end)
	UserInputService.InputEnded:Connect(function(input, processed)
		if processed or not pressAt then
			return
		end
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		local at = Vector2.new(input.Position.X, input.Position.Y)
		local tap = (at - pressAt).Magnitude < 12 and os.clock() - pressTime < 0.35
		pressAt = nil
		if not tap or UI.modalOpen() then
			return
		end
		local target = playerAt(at)
		if target and target ~= Players.LocalPlayer then
			PlayerCard.request(target.UserId)
		end
	end)
end

return PlayerCard
