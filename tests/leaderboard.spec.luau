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
	["leaderboard: the index is monotone across random 300-digit fortunes"] = function()
		local B = require("../src/shared/BigMoney")
		local seed = 99
		local function digit(): string
			seed = (seed * 1103515245 + 12345) % 2147483648
			return tostring(math.floor(seed / 65536) % 10)
		end
		local function big(): string
			seed = (seed * 1103515245 + 12345) % 2147483648
			local len = 1 + math.floor(seed / 65536) % 303
			local s = tostring(1 + (math.floor(seed / 7) % 9))
			for _ = 2, len do
				s ..= digit()
			end
			return s
		end
		for _ = 1, 2000 do
			local a, b = big(), big()
			local c = B.cmp(a, b)
			if c > 0 then
				assert(L.score(a) >= L.score(b), "bigger never scores lower")
			elseif c < 0 then
				assert(L.score(a) <= L.score(b), "smaller never scores higher")
			end
		end
	end,
	["leaderboard: exact ranking resolves index ties and shares ranks for equal amounts"] = function()
		-- Three fortunes sharing the first 12 digits (same index score), one far behind.
		local a = "1234567890129" .. string.rep("0", 20)
		local b = "1234567890125" .. string.rep("0", 20)
		local c = "1234567890125" .. string.rep("0", 20)
		eq(L.score(a), L.score(b), "same index")
		local ranked = L.rank({
			{ Id = "u_3", Score = L.score(c), Exact = c },
			{ Id = "u_1", Score = L.score(b), Exact = b },
			{ Id = "u_2", Score = L.score(a), Exact = a },
			{ Id = "u_9", Score = L.score("5"), Exact = "5" },
		})
		eq(ranked[1].Id, "u_2", "the exact biggest first")
		eq(ranked[1].Rank, 1, "rank 1")
		eq(ranked[2].Id, "u_1", "equal amounts by id")
		eq(ranked[2].Rank, 2, "rank 2")
		eq(ranked[3].Id, "u_3", "the tie")
		eq(ranked[3].Rank, 2, "shares rank 2")
		eq(ranked[4].Rank, 4, "competition ranking skips to 4")
	end,
	["leaderboard: a mismatched exact amount is not trusted"] = function()
		eq(L.verify(L.score("1000"), "1000"), true, "matches")
		eq(L.verify(L.score("1000"), "999999999999999999"), false, "an inflated exact is rejected")
		eq(L.verify("1000", "1000"), false, "score must be a number")
		-- An unverified pair ranks by its index amount only.
		local r = L.rank({ { Id = "u_1", Score = L.score("1000"), Exact = "999999999999999999" } })
		eq(r[1].Rank, 1, "still listed")
	end,
	["leaderboard: paging stops once nothing lower can reach the top"] = function()
		eq(L.needMore({ 5, 4 }, 3, 3, true), true, "fewer than n so far")
		eq(L.needMore({ 9, 8, 7 }, 3, 5, true), false, "7 > 5: nothing below can reach")
		eq(L.needMore({ 9, 8, 5 }, 3, 5, true), true, "the last could tie the 3rd")
		eq(L.needMore({ 9 }, 3, 1, false), false, "last page")
	end,
	["leaderboard: purchases never count as earnings"] = function()
		local W = require("../src/shared/Wallet")
		local d = { Coins = 0, Stats = { TotalEarned = 0 } }
		W.load(d)
		W.earn(d, 500)
		W.deposit(d, 1000000)
		eq(W.lifetime(d), "500", "a coin pack adds cash, not lifetime earned")
		eq(L.score(W.lifetime(d)), L.score("500"), "so it can't inflate an earned-wealth board")
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
