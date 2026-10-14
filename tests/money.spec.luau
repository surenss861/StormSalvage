-- @file Safe coin arithmetic and formatter boundary tests
-- @domain qa
-- @status stable
-- @see [[Money.luau]]
local Money = require("../src/shared/Money")

local function eq(a: any, b: any, what: string)
	if a ~= b then
		error(("%s: expected %s, got %s"):format(what, tostring(b), tostring(a)), 2)
	end
end

local NAN = 0 / 0
local INF = math.huge

return {
	["money: MAX is below 2^53 and exact"] = function()
		assert(Money.MAX < 2 ^ 53, "MAX under 2^53")
		eq(Money.MAX + 1 - Money.MAX, 1, "integers exact at MAX")
	end,
	["money: clamp handles every bad input"] = function()
		eq(Money.clamp(NAN), 0, "NaN")
		eq(Money.clamp(INF), 0, "inf")
		eq(Money.clamp(-INF), 0, "-inf")
		eq(Money.clamp(-5), 0, "negative")
		eq(Money.clamp(12.9), 12, "floored")
		eq(Money.clamp(Money.MAX * 3), Money.MAX, "capped")
		eq(Money.clamp("100" :: any), 0, "string")
		eq(Money.clamp(nil), 0, "nil")
	end,
	["money: grant caps at MAX and reports what was added"] = function()
		local b, added = Money.grant(Money.MAX - 10, 25)
		eq(b, Money.MAX, "capped")
		eq(added, 10, "only the room left")
		b, added = Money.grant(100, NAN)
		eq(b, 100, "NaN adds nothing")
		eq(added, 0, "NaN added 0")
		b, added = Money.grant(100, -50)
		eq(b, 100, "negative adds nothing")
		b, added = Money.grant(100, 2.75)
		eq(b, 102, "fraction floored")
		eq(added, 2, "added 2")
	end,
	["money: spend refuses invalid, short and negative costs"] = function()
		local ok, b = Money.spend(100, 100)
		eq(ok, true, "exact")
		eq(b, 0, "to zero")
		ok, b = Money.spend(100, 101)
		eq(ok, false, "short")
		eq(b, 100, "unchanged")
		ok = Money.spend(100, -1)
		eq(ok, false, "negative cost")
		ok = Money.spend(100, 1.5)
		eq(ok, false, "fractional cost")
		ok = Money.spend(100, NAN)
		eq(ok, false, "NaN cost")
		ok = Money.spend(Money.MAX, Money.MAX)
		eq(ok, true, "MAX - MAX")
	end,
	["money: scale floors and clamps"] = function()
		eq(Money.scale(99, 1.5), 148, "floor")
		eq(Money.scale(Money.MAX, 2), Money.MAX, "capped")
		eq(Money.scale(100, NAN), 0, "NaN factor")
		eq(Money.scale(100, -2), 0, "negative factor")
		eq(Money.scale(100, INF), 0, "infinite factor")
	end,
	["format: compact boundaries (rounded down)"] = function()
		local cases = {
			{ 0, "0" },
			{ 7, "7" },
			{ 999, "999" },
			{ 1000, "1.00K" },
			{ 1001, "1.00K" },
			{ 1009, "1.00K" },
			{ 1010, "1.01K" },
			{ 9999, "9.99K" },
			{ 10000, "10.0K" },
			{ 99999, "99.9K" },
			{ 100000, "100K" },
			{ 999999, "999K" },
			{ 1000000, "1.00M" },
			{ 1234567, "1.23M" },
			{ 45600000, "45.6M" },
			{ 789000000000, "789B" },
			{ 1e12, "1.00T" },
			{ 999999999999999, "999T" },
			{ 1e15, "1.00Qa" },
			{ 2 ^ 53 - 1, "9.00Qa" },
			{ -1500, "-1.50K" },
			{ 12.9, "12" },
		}
		for _, c in cases do
			eq(Money.compact(c[1]), c[2], "compact " .. tostring(c[1]))
		end
		eq(Money.compact(NAN), "0", "NaN")
		eq(Money.compact(INF), "0", "inf")
	end,
	["format: compact at every power of ten"] = function()
		local expect = {
			"1",
			"10",
			"100",
			"1.00K",
			"10.0K",
			"100K",
			"1.00M",
			"10.0M",
			"100M",
			"1.00B",
			"10.0B",
			"100B",
			"1.00T",
			"10.0T",
			"100T",
			"1.00Qa",
		}
		for p = 0, 15 do
			eq(Money.compact(10 ^ p), expect[p + 1], "10^" .. p)
			if p > 0 then
				-- One less never rounds up to the next label.
				local below = Money.compact(10 ^ p - 1)
				assert(below ~= expect[p + 1], "10^" .. p .. "-1 shows " .. below)
			end
		end
	end,
	["format: full digits"] = function()
		eq(Money.full(0), "0", "0")
		eq(Money.full(999), "999", "999")
		eq(Money.full(1000), "1,000", "1000")
		eq(Money.full(1234567), "1,234,567", "1234567")
		eq(Money.full(Money.MAX), "1,000,000,000,000,000", "MAX")
		eq(Money.full(-1234), "-1,234", "negative")
	end,
	["format: tag switches to compact at a million"] = function()
		eq(Money.tag(999999), "999,999", "below")
		eq(Money.tag(1000000), "1.00M", "at")
	end,
}
