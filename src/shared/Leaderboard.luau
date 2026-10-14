--!strict
-- @file Leaderboard maths: orderable scores for exact big money, and week keys
-- @domain progression
-- @status wip
-- @tested-by [[leaderboard.spec.luau]]
-- @see [[LeaderboardService.luau]]
-- OrderedDataStores sort whole numbers (int64), but money is an exact decimal string of up to
-- 303 digits (BigMoney). A score packs the digit count and the leading 12 digits:
--   score = digits * 10^12 + leading12   (padded with zeros when shorter)
-- so more digits always ranks higher, and equal lengths rank by their leading digits. Below a
-- trillion the score is exact; above it two fortunes that agree in their first 12 digits tie
-- (they display the same compactly anyway). The largest score, 303 * 10^12 + 999999999999, is
-- under 2^53, so it is exact as a Luau number and an int64.

local BigMoney = if script then require(script.Parent.BigMoney) else (require :: any)("./BigMoney")

local Leaderboard = {}

local LEAD = 12
local SHIFT = 10 ^ LEAD

-- The score for an exact money string (nil-safe: bad input scores 0).
function Leaderboard.score(amount: unknown): number
	local big = BigMoney.parse(amount)
	if not big or big == "0" then
		return 0
	end
	local digits = #big
	local lead = string.sub(big, 1, LEAD)
	lead ..= string.rep("0", LEAD - #lead)
	return digits * SHIFT + (tonumber(lead) :: number)
end

-- A money string for display, from a score: exact below a trillion, else the leading 12 digits
-- followed by zeros (compact formatting shows the same either way).
function Leaderboard.amount(score: number): string
	if type(score) ~= "number" or score <= 0 or score ~= score then
		return "0"
	end
	local digits = math.floor(score / SHIFT)
	local lead = string.format("%012d", score % SHIFT)
	if digits <= LEAD then
		local s = string.sub(lead, 1, digits)
		return BigMoney.parse(s) or "0"
	end
	return lead .. string.rep("0", digits - LEAD)
end

-- Server-side check that an exact amount read back matches the index score stored with it (a
-- stale or mismatched pair is dropped, never shown).
function Leaderboard.verify(score: unknown, exact: unknown): boolean
	return type(score) == "number" and BigMoney.parse(exact) ~= nil and Leaderboard.score(exact) == score
end

export type Entry = { Id: string, Score: number, Exact: string?, Rank: number? }

-- Exact ranking of index entries. Scores are monotone in the money they stand for, so ordering
-- by score is right except within equal scores (only possible above 12 digits); those are
-- ordered by their exact amounts. Equal exact amounts share a rank (competition ranking: 1, 2,
-- 2, 4), and are listed by user id so the order is stable. Entries without a verified exact
-- amount use the score's amount, which is exact below a trillion.
function Leaderboard.rank(entries: { Entry }): { Entry }
	local list = table.clone(entries)
	local function amount(e: Entry): string
		return if e.Exact and Leaderboard.verify(e.Score, e.Exact)
			then BigMoney.parse(e.Exact) :: string
			else Leaderboard.amount(e.Score)
	end
	table.sort(list, function(a, b)
		local c = BigMoney.cmp(amount(a), amount(b))
		if c ~= 0 then
			return c > 0
		end
		return a.Id < b.Id
	end)
	for i, e in list do
		local prev = list[i - 1]
		e.Rank = if prev and BigMoney.cmp(amount(prev), amount(e)) == 0 then prev.Rank else i
	end
	return list
end

-- Paging: keep reading index pages while a lower page could still tie or beat the top `n`.
-- With scores sorted descending, once the `n`th best score seen is greater than the last
-- score on the page just read, nothing further down can reach the top `n`.
function Leaderboard.needMore(
	scoresSoFar: { number },
	n: number,
	lastOnPage: number?,
	pageFull: boolean
): boolean
	if not pageFull or lastOnPage == nil then
		return false
	end
	if #scoresSoFar < n then
		return true
	end
	local sorted = table.clone(scoresSoFar)
	table.sort(sorted, function(a, b)
		return a > b
	end)
	return sorted[n] <= lastOnPage
end

-- The exact top `n` from an index whose order may tie (scores equal for different amounts).
--   page(cursor) -> (entries { {Id, Score} } in descending score order, nextCursor | nil)
--   tied(score, cursor) -> (all entries with exactly this score, in any order, nextCursor | nil)
--   exact(id, score) -> the verified exact amount, or nil
-- Proof of exactness: Leaderboard.score is monotone (a > b implies score(a) >= score(b)), so
-- an entry scored below the cutoff s* (the n-th score read) is smaller than every entry scored
-- s* or above. Reading every entry scored above s* (they come first in the index) plus EVERY
-- entry scored exactly s* (the filtered query) therefore holds the true top n, which exact
-- comparison then orders. If the tie group at s* is bigger than `tieCap`, the result is marked
-- Exact = false (the board says so) instead of guessing.
export type Board = { Entries: { Entry }, Exact: boolean, Reads: number }
function Leaderboard.topN(
	page: (cursor: any) -> ({ Entry }, any),
	tied: (score: number, cursor: any) -> ({ Entry }, any),
	exact: (id: string, score: number) -> string?,
	n: number,
	tieCap: number
): Board
	local reads = 0
	local above: { Entry } = {}
	local cursor: any = nil
	local cutoff: number? = nil
	-- 1. Descend until n entries are known; the n-th score is the cutoff.
	repeat
		local entries, nextCursor = page(cursor)
		reads += 1
		for _, e in entries do
			table.insert(above, { Id = e.Id, Score = e.Score })
			if #above == n then
				cutoff = e.Score
			end
		end
		cursor = nextCursor
	until cutoff ~= nil or cursor == nil
	if cutoff == nil then
		-- Fewer than n entries exist: all of them are the board.
		for _, e in above do
			e.Exact = exact(e.Id, e.Score)
		end
		return { Entries = Leaderboard.rank(above), Exact = true, Reads = reads }
	end
	-- 2. Everyone strictly above the cutoff is already read (descending order). Replace the
	-- cutoff group with the complete one from the filtered query.
	local candidates: { Entry } = {}
	for _, e in above do
		if e.Score > (cutoff :: number) then
			table.insert(candidates, e)
		end
	end
	local group = 0
	local complete = true
	cursor = nil
	repeat
		local entries, nextCursor = tied(cutoff :: number, cursor)
		reads += 1
		for _, e in entries do
			if e.Score == cutoff then
				group += 1
				if group > tieCap then
					complete = false
					break
				end
				table.insert(candidates, { Id = e.Id, Score = e.Score })
			end
		end
		cursor = nextCursor
	until cursor == nil or not complete
	-- 3. Exact amounts decide.
	for _, e in candidates do
		e.Exact = exact(e.Id, e.Score)
	end
	local ranked = Leaderboard.rank(candidates)
	local top = {}
	for i = 1, math.min(n, #ranked) do
		top[i] = ranked[i]
	end
	-- Shared ranks can run past n (a tie for 10th): keep everyone sharing the n-th rank.
	for i = n + 1, #ranked do
		if top[n] and ranked[i].Rank == top[n].Rank then
			table.insert(top, ranked[i])
		else
			break
		end
	end
	return { Entries = top, Exact = complete, Reads = reads }
end

-- ISO-8601 week key ("2026W42") for a unix time (UTC). Weeks start on Monday.
function Leaderboard.weekKey(unix: number): string
	local days = math.floor(unix / 86400)
	-- 1970-01-01 was a Thursday; ISO weekday Monday = 1 .. Sunday = 7.
	local weekday = (days + 3) % 7 + 1
	-- The Thursday of this week decides the ISO year.
	local thursday = days - weekday + 4
	local t = os.date("!*t", thursday * 86400) :: any
	local yearStart = os.time({ year = t.year, month = 1, day = 1, hour = 0 }) :: number
	-- os.time uses local time; the offset cancels for a whole-day difference below.
	local jan1 = math.floor((yearStart + 43200) / 86400)
	local week = math.floor((thursday - jan1) / 7) + 1
	return ("%dW%02d"):format(t.year, week)
end

-- Weekly earnings tracking in a profile: { Key = week key, Start = lifetime at the week's start }.
-- Returns the (possibly reset) record and what was earned this week, exact.
function Leaderboard.weekly(
	record: any,
	lifetime: string,
	key: string
): ({ Key: string, Start: string }, string)
	local r = if type(record) == "table" then record else {}
	local start = BigMoney.parse(r.Start)
	if r.Key ~= key or not start or BigMoney.lt(lifetime, start) then
		r = { Key = key, Start = lifetime }
		return r, "0"
	end
	return { Key = key, Start = start }, BigMoney.sub(lifetime, start) or "0"
end

return Leaderboard
