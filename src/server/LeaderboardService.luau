-- @file Global leaderboards: all-time earnings and this week's, on a board in the Scrapyard
-- @domain progression
-- @status wip
-- @see [[Leaderboard.luau]]
-- Two OrderedDataStores per data environment (never production unless this build runs there):
--   <store>_LB_Lifetime           lifetime earned (exact BigMoney, as an orderable score)
--   <store>_LB_Week_<2026W42>     earned since the week began (ISO weeks, UTC)
-- Unknown environments (no DataStore) have no leaderboards: the board says so.
-- Writes: at most one per player per WRITE_EVERY, only when their score changed, and once as
-- they leave. Reads: the top 10 of each board every READ_EVERY, with names cached.
-- The board stands on the Scrapyard plateau beside the Contract board, facing the ramp, so
-- everyone sees it on the way to sell. Earned only: purchases (coin packs) never count, because
-- lifetime earned counts earnings, not deposits (Wallet.deposit).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigMoney = require(ReplicatedStorage.Shared.BigMoney)
local Config = require(ReplicatedStorage.Shared.Config)
local Leaderboard = require(ReplicatedStorage.Shared.Leaderboard)
local Wallet = require(ReplicatedStorage.Shared.Wallet)
local PlayerService = require(script.Parent.PlayerService)

local LeaderboardService = {}

local WRITE_EVERY = 120
local READ_EVERY = 60
local TOP = 10
local BOARD_AT = CFrame.new(34, 30, -250) -- on the plateau, facing the ramp (+Z)

type Board = { Title: string, Rows: { TextLabel }, Status: TextLabel }
local boards: { [string]: Board } = {}
local lastWrite: { [Player]: { At: number, Life: number, Week: number } } = {}
local names: { [number]: string } = {}
local enabled = false

local function storeName(kind: string): string?
	local base = Config.DataStoreName
	if not base then
		return nil
	end
	if kind == "Week" then
		return ("%s_LB_Week_%s"):format(base, Leaderboard.weekKey(os.time()))
	end
	return base .. "_LB_Lifetime"
end

local function ordered(kind: string): OrderedDataStore?
	local name = storeName(kind)
	if not name then
		return nil
	end
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(name)
	end)
	return if ok then store else nil
end

-- This player's two scores, from their profile (and the weekly record kept in it).
local function scoresOf(player: Player): (number?, number?)
	local session = PlayerService.get(player)
	if not session then
		return nil, nil
	end
	local data = session.Data
	local lifetime = Wallet.lifetime(data)
	local record, week = Leaderboard.weekly(data.Weekly, lifetime, Leaderboard.weekKey(os.time()))
	data.Weekly = record
	return Leaderboard.score(lifetime), Leaderboard.score(week)
end

local function write(player: Player, force: boolean?)
	if not enabled then
		return
	end
	local life, week = scoresOf(player)
	if not life or not week then
		return
	end
	local last = lastWrite[player]
	if last and not force and (os.clock() - last.At < WRITE_EVERY) then
		return
	end
	if last and last.Life == life and last.Week == week then
		last.At = os.clock()
		return
	end
	lastWrite[player] = { At = os.clock(), Life = life, Week = week }
	local key = "u_" .. player.UserId
	for kind, score in { Lifetime = life, Week = week } do
		local store = ordered(kind)
		if store and score > 0 then
			local ok, err = pcall(function()
				store:SetAsync(key, score)
			end)
			if not ok then
				warn("[LeaderboardService] write failed:", kind, err)
			end
		end
	end
end

local function nameOf(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = if ok and type(name) == "string" then name else ("#%d"):format(userId)
	return names[userId]
end

local function refresh(kind: string)
	local board = boards[kind]
	if not board then
		return
	end
	local store = ordered(kind)
	if not store then
		board.Status.Text = "No leaderboard in this test place"
		return
	end
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, TOP):GetCurrentPage()
	end)
	if not ok then
		board.Status.Text = "Leaderboard unavailable, retrying"
		return
	end
	for i, row in board.Rows do
		local entry = (page :: any)[i]
		if entry then
			local userId = tonumber(string.match(entry.key, "^u_(%d+)$"))
			local who = if userId then nameOf(userId) else "?"
			row.Text = ("%d. %s  ·  %s"):format(i, who, BigMoney.compact(Leaderboard.amount(entry.value)))
		else
			row.Text = ""
		end
	end
	board.Status.Text = if #(page :: any) == 0 then "Nobody yet. Be the first!" else ""
end

local function buildBoard(map: Instance)
	local model = Instance.new("Model")
	model.Name = "Leaderboards"
	local face = Instance.new("Part")
	face.Name = "Board"
	face.Anchored = true
	face.Size = Vector3.new(26, 13, 0.6)
	face.CFrame = BOARD_AT * CFrame.new(0, 9, 0)
	face.Color = Color3.fromRGB(24, 25, 29)
	face.Material = Enum.Material.Metal
	face.Parent = model
	for _, x in { -12, 12 } do
		local post = Instance.new("Part")
		post.Name = "Post"
		post.Anchored = true
		post.Size = Vector3.new(0.8, 16, 0.8)
		post.CFrame = BOARD_AT * CFrame.new(x, 8, 0.6)
		post.Color = Color3.fromRGB(255, 176, 46)
		post.Material = Enum.Material.Metal
		post.Parent = model
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- faces +Z, toward the ramp
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	-- 0.2 like the map's signs: with LightInfluence 0 this place's lighting drew nothing at all
	-- (found in Studio: the same GUI rendered once it was 0.2).
	gui.LightInfluence = 0.2
	gui.MaxDistance = 300
	gui.Parent = face
	local heading = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
	local function column(kind: string, title: string, x: number)
		local col = Instance.new("Frame")
		col.Position = UDim2.fromScale(x, 0)
		col.Size = UDim2.fromScale(0.5, 1)
		col.BackgroundTransparency = 1
		col.Parent = gui
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, 0, 60)
		t.Position = UDim2.fromOffset(0, 10)
		t.FontFace = heading
		t.TextSize = 44
		t.TextColor3 = Color3.fromRGB(255, 176, 46)
		t.Text = title
		t.Parent = col
		local rows = {}
		for i = 1, TOP do
			local r = Instance.new("TextLabel")
			r.BackgroundTransparency = 1
			r.Position = UDim2.fromOffset(44, 74 + (i - 1) * 30)
			r.Size = UDim2.new(1, -70, 0, 28)
			r.FontFace = heading
			r.TextSize = 26
			r.TextXAlignment = Enum.TextXAlignment.Left
			r.TextColor3 = if i == 1 then Color3.fromRGB(255, 206, 74) else Color3.fromRGB(240, 240, 244)
			r.Text = ""
			r.Parent = col
			table.insert(rows, r)
		end
		local status = Instance.new("TextLabel")
		status.BackgroundTransparency = 1
		status.Position = UDim2.fromOffset(44, 104)
		status.Size = UDim2.new(1, -70, 0, 28)
		status.Font = Enum.Font.GothamBold
		status.TextSize = 18
		status.TextColor3 = Color3.fromRGB(170, 172, 180)
		status.Text = "Loading..."
		status.Parent = col
		boards[kind] = { Title = title, Rows = rows, Status = status }
	end
	column("Lifetime", "ALL-TIME EARNERS", 0)
	column("Week", "THIS WEEK", 0.5)
	model.Parent = map
end

function LeaderboardService.init(map: Instance)
	buildBoard(map)
	enabled = Config.DataStoreName ~= nil
	if not enabled then
		for _, b in boards do
			b.Status.Text = "No leaderboard in this test place"
		end
		return
	end
	Players.PlayerRemoving:Connect(function(player)
		write(player, true)
		lastWrite[player] = nil
	end)
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				task.spawn(write, player)
			end
			task.wait(15)
		end
	end)
	task.spawn(function()
		task.wait(5)
		while true do
			refresh("Lifetime")
			refresh("Week")
			task.wait(READ_EVERY)
		end
	end)
end

-- Studio QA: write this player's scores now and refresh both boards.
function LeaderboardService.qaFlush(player: Player)
	write(player, true)
	refresh("Lifetime")
	refresh("Week")
end

return LeaderboardService
