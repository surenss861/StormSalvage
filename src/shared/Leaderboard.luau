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
