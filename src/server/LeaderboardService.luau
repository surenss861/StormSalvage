-- @file Global leaderboards: all-time earnings and this week's, on a board in the Scrapyard
-- @domain progression
-- @status wip
-- @see [[Leaderboard.luau]]
-- @see [[V4-LEADERBOARDS]]
-- Exact ranking of exact money (docs/production/V4-LEADERBOARDS.md). Per data environment
-- (Studio, LIVETEST, production: never another environment's data; none in unknown places):
--   <store>_LB_Lifetime, <store>_LB_Week_<2026W42>   OrderedDataStores holding an INDEX score
--       (Leaderboard.score: digit count and leading 12 digits, monotone in the amount)
--   <store>_LB_Exact   a DataStore with each entry's exact amount ("L_<id>", "W_<week>_<id>")
-- Writes (server only, from the profile's Wallet lifetime, which never includes purchases):
--   exact first, then the index; recorded as done only when both succeed, so a failure is
--   retried next cycle. At most one write per kind per player per WRITE_EVERY, only on change,
--   and a final one as they leave.
-- Reads: index pages (PAGE) until nothing further down can reach the top TOP
--   (Leaderboard.needMore), exact amounts for those entries (cached by score, so unchanged
--   entries cost no reads), each checked against its index score (Leaderboard.verify), then
--   exact ranking with shared ranks for equal amounts (Leaderboard.rank). A failed read keeps
--   the last good board and says it's paused.

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
local PAGE = 25
local MAX_PAGES = 4
local BOARD_AT = CFrame.new(34, 30, -250) -- on the plateau, facing the ramp (+Z)

type Board = { Title: string, Rows: { TextLabel }, Status: TextLabel }
local boards: { [string]: Board } = {}
local lastWrite: { [Player]: { [string]: { At: number, Score: number } } } = {}
local exactCache: { [string]: { Score: number, Exact: string? } } = {} -- by exact key
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

local function exactStore(): DataStore?
	local base = Config.DataStoreName
	if not base then
		return nil
	end
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(base .. "_LB_Exact")
	end)
	return if ok then store else nil
end

local function exactKey(kind: string, id: string): string
	return if kind == "Week" then ("W_%s_%s"):format(Leaderboard.weekKey(os.time()), id) else "L_" .. id
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

-- This player's two exact amounts, from their profile (and the weekly record kept in it).
local function amountsOf(player: Player): { [string]: string }?
	local session = PlayerService.get(player)
	if not session then
		return nil
	end
	local data = session.Data
	local lifetime = Wallet.lifetime(data)
	local record, week = Leaderboard.weekly(data.Weekly, lifetime, Leaderboard.weekKey(os.time()))
	data.Weekly = record
	return { Lifetime = lifetime, Week = week }
end

local function write(player: Player, force: boolean?)
	if not enabled then
		return
	end
	local amounts = amountsOf(player)
	if not amounts then
		return
	end
	local id = tostring(player.UserId)
	local done = lastWrite[player] or {}
	lastWrite[player] = done
	for kind, exact in amounts do
		local score = Leaderboard.score(exact)
		local last = done[kind]
		local due = force or not last or os.clock() - last.At >= WRITE_EVERY
		if score > 0 and due and (not last or last.Score ~= score) then
			local store, exacts = ordered(kind), exactStore()
			if store and exacts then
				-- Exact first: a reader never finds an index score without its exact amount.
				local ok, err = pcall(function()
					(exacts :: DataStore):SetAsync(exactKey(kind, id), exact)
					store:SetAsync("u_" .. id, score)
				end)
				if ok then
					done[kind] = { At = os.clock(), Score = score }
				else
					warn("[LeaderboardService] write failed (retrying next cycle):", kind, err)
				end
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

-- The exact amount behind an index entry, cached while its score is unchanged.
local function exactFor(kind: string, id: string, score: number): string?
	local key = exactKey(kind, id)
	local cached = exactCache[key]
	if cached and cached.Score == score then
		return cached.Exact
	end
	local exacts = exactStore()
	if not exacts then
		return nil
	end
	local ok, value = pcall(function()
		return (exacts :: DataStore):GetAsync(key)
	end)
	local exact = if ok and Leaderboard.verify(score, value) then value :: string else nil
	exactCache[key] = { Score = score, Exact = exact }
	return exact
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
	local entries: { Leaderboard.Entry } = {}
	local scores: { number } = {}
	local ok, err = pcall(function()
		local pages = store:GetSortedAsync(false, PAGE)
		for _ = 1, MAX_PAGES do
			local page = pages:GetCurrentPage()
			local last: number? = nil
			for _, entry in page do
				local id = string.match(entry.key, "^u_(%d+)$")
				if id and type(entry.value) == "number" then
					table.insert(entries, { Id = id, Score = entry.value })
					table.insert(scores, entry.value)
					last = entry.value
				end
			end
			if not Leaderboard.needMore(scores, TOP, last, #page >= PAGE and not pages.IsFinished) then
				break
			end
			pages:AdvanceToNextPageAsync()
		end
	end)
	if not ok then
		warn("[LeaderboardService] read failed:", kind, err)
		board.Status.Text = "Leaderboard paused, retrying"
		return
	end
	-- Exact amounts only where they decide order or are shown: the top TOP by index, plus any
	-- entry sharing an index score with one of them.
	table.sort(entries, function(a, b)
		return a.Score > b.Score
	end)
	local cutoff = if entries[TOP] then entries[TOP].Score else -1
	for _, e in entries do
		if e.Score >= cutoff then
			e.Exact = exactFor(kind, e.Id, e.Score)
		end
	end
	local ranked = Leaderboard.rank(entries)
	for i, row in board.Rows do
		local e = ranked[i]
		if e then
			local userId = tonumber(e.Id)
			local who = if userId then nameOf(userId) else "?"
			local amount = e.Exact or Leaderboard.amount(e.Score)
			row.Text = ("%d. %s  ·  %s"):format(e.Rank or i, who, BigMoney.compact(amount))
		else
			row.Text = ""
		end
	end
	board.Status.Text = if #ranked == 0 then "Nobody yet. Be the first!" else ""
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
