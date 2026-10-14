-- @file Leaderboard scores (exact big money into int64 order) and week keys
-- @domain qa
-- @status stable
-- @see [[Leaderboard.luau]]
local L = require("../src/shared/Leaderboard")

local function eq(a: any, b: any, what: string)
	if a ~= b then
		error(("%s: expected %s, got %s"):format(what, tostring(b), tostring(a)), 2)
	end
end

return {
	["leaderboard: scores order like the money they stand for"] = function()
		local amounts = {
			"0",
			"1",
			"9",
			"10",
			"999999",
			"1000000",
			"999999999999",
			"1000000000000",
			"1000000000001",
			"25725235195000",
			"62700000000000000000",
			"1" .. string.rep("0", 302),
		}
		local last = -1
		for _, a in amounts do
			local s = L.score(a)
			assert(s >= last, a .. " ranks below the one before it")
			last = s
		end
		assert(L.score("1" .. string.rep("0", 302)) < 2 ^ 53, "the largest score stays exact")
		eq(L.score("garbage"), 0, "bad input")
		eq(L.score(nil), 0, "nil")
	end,
	["leaderboard: exact below a trillion, leading digits above"] = function()
		for _, a in { "1", "42", "1700000095", "999999999999" } do
			eq(L.amount(L.score(a)), a, "round trip " .. a)
		end
		eq(L.amount(L.score("1234567890123456")), "1234567890120000", "16 digits keep 12")
		eq(L.amount(0), "0", "zero")
	end,
	["leaderboard: ISO week keys"] = function()
		-- Fixtures from Python's isocalendar (midnight UTC, and the last second of that day).
		for _, case in
			{
				{ 1791936000, "2026W42" }, -- Wed 2026-10-14
				{ 1609632000, "2020W53" }, -- Sun 2021-01-03 belongs to 2020
				{ 1735516800, "2025W01" }, -- Mon 2024-12-30 belongs to 2025
				{ 1767225600, "2026W01" }, -- Thu 2026-01-01
				{ 1609372800, "2020W53" }, -- Thu 2020-12-31
			}
		do
			eq(L.weekKey(case[1]), case[2], "midnight " .. case[2])
			eq(L.weekKey(case[1] + 86399), case[2], "end of day " .. case[2])
		end
	end,
	["leaderboard: weekly earnings reset on a new week and never go negative"] = function()
		local r, earned = L.weekly(nil, "5000", "2026W42")
		eq(earned, "0", "a fresh record starts the week at zero")
		eq(r.Start, "5000", "from the lifetime now")
		r, earned = L.weekly(r, "12000", "2026W42")
		eq(earned, "7000", "earned this week")
		r, earned = L.weekly(r, "13000", "2026W43")
		eq(earned, "0", "a new week starts over")
		eq(r.Start, "13000", "at the new lifetime")
		r, earned = L.weekly({ Key = "2026W43", Start = "99999" }, "100", "2026W43")
		eq(earned, "0", "a restored (lower) lifetime resets rather than going negative")
	end,
}
