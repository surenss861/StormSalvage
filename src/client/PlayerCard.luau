-- @file V4 player card: inspect any salvager's public record
-- @domain progression
-- @status wip
-- @see [[StatusService.luau]]
-- @see [[V4-STATUS]]
-- Tap or click another player (or MY CARD on the Jobs board's Titles tab) to see their Salvager
-- ID (V4 Storm-Scarred Arcade dossier, owner concept): the earned title over their avatar
-- portrait; reputation (rank, band, XP to the next rank); lifetime earned and net worth in
-- gold; extraction records; the Salvage Log; their three most prestigious title badges.
-- Earned prestige only: nothing here can be bought.
-- The client only asks (Inspect, with a user id); the server answers with public facts from its
-- own records (InspectCard). Everything else stays on the card, not over people's heads.
-- Tap detection ignores drags (camera swipes on phones) and taps on the HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local BigMoney = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BigMoney"))
local Config = require(ReplicatedStorage.Shared:WaitForChild("Config"))
local Remotes = require(ReplicatedStorage.Shared:WaitForChild("Remotes"))
local PlateStyle = require(script.Parent:WaitForChild("PlateStyle"))
local UI = require(script.Parent:WaitForChild("UI"))

local PlayerCard = {}

local modal: UI.Modal
local inspectRemote: RemoteEvent
local nameLabel: TextLabel
local handleLabel: TextLabel
local rankLabel: TextLabel
local bandLabel: TextLabel
local xpFill: Frame
local xpText: TextLabel
local titleBanner: TextLabel
local portrait: ImageLabel
local plateStrip: Frame
local badgeSlots: { Frame } = {}
local trophySlots: { Frame } = {}
local cells: { [string]: { Value: TextLabel, Sub: TextLabel } } = {}
local A = UI.Arcade
local CATEGORY_COLOR = {
	Pursuit = Color3.fromRGB(255, 140, 60),
	Discovery = Color3.fromRGB(90, 180, 240),
	Career = Color3.fromRGB(170, 130, 240),
	Wealth = Color3.fromRGB(255, 206, 74),
}

local HARDEST = { [0] = "-", [1] = "Easy", [2] = "Hard", [3] = "Hardest" }

-- Big tiles (gold wealth, records) and the small stat row.
local BIG = {
	{ "Earned", "LIFETIME EARNED", true },
	{ "NetWorth", "NET WORTH", true },
	{ "Extractions", "EXTRACTIONS", false },
	{ "Best", "BEST TIME HOME", false },
}
local SMALL = {
	{ "Streak", "CLEAN STREAK" },
	{ "Golden", "GOLDEN CORES" },
	{ "Hardest", "HARDEST RUN" },
	{ "Log", "SALVAGE LOG" },
	{ "Titles", "TITLES" },
}

function PlayerCard.request(userId: number)
	inspectRemote:FireServer(userId)
end

function PlayerCard.show(card: any)
	if type(card) ~= "table" then
		return
	end
	nameLabel.Text = string.upper(tostring(card.DisplayName or "?"))
	handleLabel.Text = "@" .. tostring(card.Name or "")
	if type(card.UserId) == "number" then
		portrait.Image = ""
		local userId = card.UserId
		task.spawn(function()
			local ok, image = pcall(function()
				return Players:GetUserThumbnailAsync(
					userId,
					Enum.ThumbnailType.AvatarThumbnail,
					Enum.ThumbnailSize.Size420x420
				)
			end)
			if ok and type(image) == "string" then
				portrait.Image = image
			end
		end)
	end
	rankLabel.Text = string.upper(tostring(card.Rank or ""))
	bandLabel.Text = ("BAND %d · %s"):format(card.Band or 1, string.upper(tostring(card.BandName or "")))
	local xp, from, to = card.XP or 0, card.RankXP or 0, card.NextXP
	if type(to) == "number" and to > from then
		xpFill.Size = UDim2.fromScale(math.clamp((xp - from) / (to - from), 0, 1), 1)
		xpText.Text = ("%s / %s XP"):format(BigMoney.full(math.floor(xp)), BigMoney.full(math.floor(to)))
	else
		xpFill.Size = UDim2.fromScale(1, 1)
		xpText.Text = "MAX RANK"
	end
	local hasTitle = type(card.Title) == "string"
	titleBanner.Text = if hasTitle then string.upper(card.Title) else "NO TITLE YET"
	titleBanner.TextColor3 = if hasTitle then A.Plate else A.Dim
	titleBanner.BackgroundColor3 = if hasTitle then A.Amber else A.Plate2
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
	set("Extractions", tostring(card.Extractions or 0), "cores home")
	set(
		"Best",
		if (card.BestExtract or 0) > 0 then ("%.1f s"):format(card.BestExtract) else "-",
		"fastest extraction"
	)
	set("Streak", tostring(card.BestStreak or 0))
	set("Golden", tostring(card.GoldenExtractions or 0))
	set("Hardest", HARDEST[card.Hardest or 0] or "-")
	set("Log", ("%d / %d"):format(card.Found or 0, card.FoundTotal or 0))
	set("Titles", ("%d / %d"):format(card.Titles or 0, card.TitlesTotal or 0))
	local badges = if type(card.Badges) == "table" then card.Badges else {}
	for i, slot in badgeSlots do
		local b = badges[i]
		slot.Visible = b ~= nil
		if b then
			local color = CATEGORY_COLOR[b.Category] or A.Amber
			local medal = slot:FindFirstChild("Medal") :: Frame;
			(medal:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = color;
			(medal:FindFirstChild("Letter") :: TextLabel).Text =
				string.upper(string.sub(tostring(b.Name), 1, 1));
			(medal:FindFirstChild("Letter") :: TextLabel).TextColor3 = color;
			(slot:FindFirstChild("Name") :: TextLabel).Text = string.upper(tostring(b.Name));
			(slot:FindFirstChild("How") :: TextLabel).Text = tostring(b.How or b.Category or "")
		end
	end
	local trophies = if type(card.Trophies) == "table" then card.Trophies else {}
	for i, chip in trophySlots do
		local t = trophies[i]
		chip.Visible = t ~= nil
		if t then
			(chip:FindFirstChild("Dot") :: Frame).BackgroundColor3 = Config.RarityColors[t.Rarity] or A.Dim;
			(chip:FindFirstChild("Text") :: TextLabel).Text = ("%s · %s"):format(
				string.upper(tostring(t.Name)),
				string.upper(tostring(t.Rarity))
			)
		end
	end
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
	modal = UI.modal(root, "PlayerCard", "SALVAGER ID", Vector2.new(820, 460))
	local content = modal.Content
	local function label(parent: Instance, props: { [string]: any }): TextLabel
		props.Parent = parent
		props.FontFace = props.FontFace or UI.Heading
		props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
		props.ZIndex = props.ZIndex or 23
		return UI.text(props)
	end
	local function panel(parent: Instance, props: { [string]: any }): Frame
		props.Parent = parent
		props.BackgroundColor3 = props.BackgroundColor3 or A.Plate2
		props.BackgroundTransparency = 0
		props.ZIndex = props.ZIndex or 22
		local f = UI.arcadePlate(props)
		return f
	end

	-- Left: the earned title over the portrait, name and handle, the nameplate finish.
	local left = UI.new("Frame", {
		Name = "Left",
		Parent = content,
		Size = UDim2.new(0.27, -8, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 21,
	})
	titleBanner = label(left, {
		Size = UDim2.new(1, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 17,
		Text = "",
	})
	titleBanner.BackgroundTransparency = 0
	UI.corner(4).Parent = titleBanner
	local frame = panel(
		left,
		{ Name = "Portrait", Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 1, -110) }
	)
	UI.stroke(A.Amber, 2).Parent = frame
	portrait = UI.new("ImageLabel", {
		Parent = frame,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 23,
	})
	nameLabel = label(left, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 2, 1, -34),
		Size = UDim2.new(1, -4, 0, 26),
		TextSize = 22,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = A.Text,
		Text = "",
	})
	handleLabel = label(left, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 2, 1, -18),
		Size = UDim2.new(1, -4, 0, 14),
		Font = UI.Font.Label,
		FontFace = Font.fromEnum(UI.Font.Label),
		TextSize = 12,
		TextColor3 = A.Dim,
		Text = "",
	})
	plateStrip = UI.new("Frame", {
		Name = "Plate",
		Parent = left,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 10),
		BorderSizePixel = 0,
		ZIndex = 22,
	}, { UI.corner(3) })

	-- Middle: reputation, wealth and records.
	local mid = UI.new("Frame", {
		Name = "Middle",
		Parent = content,
		Position = UDim2.fromScale(0.27, 0),
		Size = UDim2.new(0.48, -8, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 21,
	})
	local rep = panel(mid, { Name = "Reputation", Size = UDim2.new(1, 0, 0, 92) })
	label(rep, {
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 14),
		TextSize = 12,
		TextColor3 = A.Dim,
		Text = "REPUTATION",
	})
	rankLabel = label(rep, {
		Position = UDim2.fromOffset(12, 20),
		Size = UDim2.new(1, -24, 0, 32),
		TextSize = 30,
		TextColor3 = A.Amber,
		Text = "",
	})
	bandLabel = label(rep, {
		Position = UDim2.fromOffset(12, 52),
		Size = UDim2.new(0.6, 0, 0, 16),
		TextSize = 13,
		TextColor3 = A.Text,
		Text = "",
	})
	xpText = label(rep, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 52),
		Size = UDim2.new(0.4, 0, 0, 16),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = A.Dim,
		Text = "",
	})
	local bar = UI.new("Frame", {
		Parent = rep,
		Position = UDim2.new(0, 12, 1, -16),
		Size = UDim2.new(1, -24, 0, 8),
		BackgroundColor3 = A.Plate,
		BorderSizePixel = 0,
		ZIndex = 23,
	}, { UI.corner(4) })
	xpFill = UI.new("Frame", {
		Parent = bar,
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = A.Amber,
		BorderSizePixel = 0,
		ZIndex = 24,
	}, { UI.corner(4) })
	local tiles = UI.new("Frame", {
		Parent = mid,
		Position = UDim2.fromOffset(0, 100),
		Size = UDim2.new(1, 0, 1, -170),
		BackgroundTransparency = 1,
		ZIndex = 21,
	}, {
		UI.new("UIGridLayout", {
			CellSize = UDim2.new(0.5, -4, 0.5, -4),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, spec in BIG do
		local cell = panel(tiles, { Name = spec[1], LayoutOrder = i })
		label(cell, {
			Position = UDim2.fromOffset(10, 6),
			Size = UDim2.new(1, -20, 0, 14),
			TextSize = 12,
			TextColor3 = A.Dim,
			Text = spec[2],
		})
		local value = label(cell, {
			Position = UDim2.new(0, 10, 0.5, -14),
			Size = UDim2.new(1, -20, 0, 30),
			TextSize = 28,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = if spec[3] then A.Gold else A.Text,
			Text = "",
		})
		local sub = label(cell, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 10, 1, -6),
			Size = UDim2.new(1, -20, 0, 12),
			Font = UI.Font.Label,
			FontFace = Font.fromEnum(UI.Font.Label),
			TextSize = 10,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = A.Dim,
			Text = "",
		})
		cells[spec[1]] = { Value = value, Sub = sub }
	end
	local row = UI.new("Frame", {
		Parent = mid,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 62),
		BackgroundTransparency = 1,
		ZIndex = 21,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, spec in SMALL do
		local cell = panel(row, { Name = spec[1], LayoutOrder = i, Size = UDim2.new(1 / #SMALL, -5, 1, 0) })
		label(cell, {
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.new(1, -12, 0, 12),
			TextSize = 10,
			TextColor3 = A.Dim,
			Text = spec[2],
		})
		local value = label(cell, {
			Position = UDim2.fromOffset(6, 24),
			Size = UDim2.new(1, -12, 0, 24),
			TextSize = 20,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = A.Text,
			Text = "",
		})
		local sub = label(cell, {
			Position = UDim2.fromOffset(6, 48),
			Size = UDim2.new(1, -12, 0, 10),
			TextSize = 9,
			TextColor3 = A.Dim,
			Text = "",
			Visible = false,
		})
		cells[spec[1]] = { Value = value, Sub = sub }
	end

	-- Right: the three most prestigious titles, as medals.
	local right = panel(content, {
		Name = "Badges",
		Position = UDim2.fromScale(0.75, 0),
		Size = UDim2.new(0.25, 0, 1, 0),
	})
	label(right, {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 18),
		TextSize = 16,
		TextColor3 = A.Text,
		Text = "ACHIEVED BADGES",
	})
	label(right, {
		Position = UDim2.fromOffset(12, 26),
		Size = UDim2.new(1, -24, 0, 12),
		TextSize = 10,
		TextColor3 = A.Dim,
		Text = "EARNED IN THE STORM, NEVER BOUGHT",
	})
	for i = 1, 3 do
		local slot = UI.new("Frame", {
			Name = "Badge" .. i,
			Parent = right,
			Position = UDim2.new(0, 10, 0, 44 + (i - 1) * 74),
			Size = UDim2.new(1, -20, 0, 70),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 23,
		})
		local medal = UI.new("Frame", {
			Name = "Medal",
			Parent = slot,
			Size = UDim2.fromOffset(56, 56),
			BackgroundColor3 = A.Plate,
			BorderSizePixel = 0,
			ZIndex = 24,
		}, { UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), UI.stroke(A.Amber, 3) })
		label(medal, {
			Name = "Letter",
			Size = UDim2.fromScale(1, 1),
			TextSize = 28,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = "",
			ZIndex = 25,
		})
		label(slot, {
			Name = "Name",
			Position = UDim2.fromOffset(64, 4),
			Size = UDim2.new(1, -64, 0, 20),
			TextSize = 16,
			TextWrapped = true,
			TextColor3 = A.Text,
			Text = "",
		})
		label(slot, {
			Name = "How",
			Position = UDim2.fromOffset(64, 26),
			Size = UDim2.new(1, -64, 0, 40),
			Font = UI.Font.Label,
			FontFace = Font.fromEnum(UI.Font.Label),
			TextSize = 11,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = A.Dim,
			Text = "",
		})
		table.insert(badgeSlots, slot)
	end
	-- Trophy case: their three rarest finds, in rarity colours.
	label(right, {
		Position = UDim2.new(0, 12, 1, -96),
		Size = UDim2.new(1, -24, 0, 16),
		TextSize = 14,
		TextColor3 = A.Text,
		Text = "TROPHY CASE",
	})
	for i = 1, 3 do
		local chip = UI.new("Frame", {
			Name = "Trophy" .. i,
			Parent = right,
			Position = UDim2.new(0, 12, 1, -76 + (i - 1) * 24),
			Size = UDim2.new(1, -24, 0, 20),
			BackgroundColor3 = A.Plate,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 23,
		}, { UI.corner(4) })
		UI.new("Frame", {
			Name = "Dot",
			Parent = chip,
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.fromOffset(8, 8),
			BorderSizePixel = 0,
			ZIndex = 24,
		}, { UI.corner(4) })
		label(chip, {
			Name = "Text",
			Position = UDim2.fromOffset(20, 0),
			Size = UDim2.new(1, -24, 1, 0),
			TextSize = 13,
			TextColor3 = A.Text,
			Text = "",
			ZIndex = 24,
		})
		table.insert(trophySlots, chip)
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
