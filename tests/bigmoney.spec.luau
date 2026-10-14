-- @file Exact large-integer money: parsing, arithmetic, formatting and boundaries
-- @domain qa
-- @status stable
-- @see [[BigMoney.luau]]
local B = require("../src/shared/BigMoney")

local function eq(a: any, b: any, what: string)
	if a ~= b then
		error(("%s: expected %s, got %s"):format(what, tostring(b), tostring(a)), 2)
	end
end

local function pow10(n: number): string
	return "1" .. string.rep("0", n)
end

local function below(n: number): string -- 10^n - 1
	return string.rep("9", n)
end

-- A seeded LCG (Lune has no Random), so every run checks the same numbers.
local seed = 20261014
local function rand(n: number): number
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed % n
end
local function randomBig(maxDigits: number): string
	local len = 1 + rand(maxDigits)
	local parts = { tostring(1 + rand(9)) }
	for _ = 2, len do
		table.insert(parts, tostring(rand(10)))
	end
	return table.concat(parts)
end

return {
	["bigmoney: parse accepts canonical strings and exact whole numbers"] = function()
		eq(B.parse("0"), "0", "zero")
		eq(B.parse("000123"), "123", "leading zeros canonicalised")
		eq(B.parse("0000"), "0", "all zeros")
		eq(B.parse(0), "0", "number zero")
		eq(B.parse(999), "999", "number")
		eq(B.parse(9007199254740991), "9007199254740991", "2^53-1 exact")
		eq(B.parse(B.MAX), B.MAX, "MAX")
		eq(#B.MAX, 303, "303 digits")
	end,
	["bigmoney: parse rejects everything else"] = function()
		local bad = {
			-1,
			1.5,
			0 / 0,
			math.huge,
			-math.huge,
			9007199254740992, -- 2^53: no longer exact as a number
			"",
			"-5",
			"+5",
			"1.5",
			"1e10",
			" 5",
			"5 ",
			"12a",
			"0x10",
			"１２", -- full-width digits
			string.rep("9", 304), -- out of range
			string.rep("0", 401), -- too long to read
			{},
			true,
		}
		for i, x in bad do
			eq(B.parse(x), nil, "bad input #" .. i .. " " .. tostring(x))
		end
		eq(B.is("007"), false, "non-canonical is not canonical")
		eq(B.is("7"), true, "canonical")
	end,
	["bigmoney: legacy numbers convert exactly, corrupt ones never become 0 silently"] = function()
		eq(B.fromLegacyNumber(0), "0", "0")
		eq(B.fromLegacyNumber(1e15), "1000000000000000", "1 Qa")
		eq(B.fromLegacyNumber(12.9), "12", "fraction floored")
		eq(B.fromLegacyNumber(2 ^ 60), "1152921504606846976", "past 2^53: the double's exact value")
		eq(B.fromLegacyNumber(0 / 0), nil, "NaN refused")
		eq(B.fromLegacyNumber(-1), nil, "negative refused")
		eq(B.fromLegacyNumber(math.huge), nil, "inf refused")
		eq(B.fromLegacyNumber("5"), nil, "not a number")
	end,
	["bigmoney: compare by value, not text"] = function()
		eq(B.cmp("9", "10"), -1, "9 < 10")
		eq(B.cmp("100", "99"), 1, "100 > 99")
		eq(B.cmp("123", "123"), 0, "equal")
		eq(B.cmp(B.MAX, pow10(302)), 1, "MAX > 10^302")
		eq(B.gte("0", "0"), true, "0 >= 0")
		eq(B.lt("0", "1"), true, "0 < 1")
	end,
	["bigmoney: boundaries at every major threshold, one below and one above"] = function()
		for _, p in { 0, 3, 6, 15, 18, 33, 63, 302 } do
			local x = pow10(p)
			local up = B.add(x, "1")
			local down = B.sub(x, "1") :: string
			eq(B.sub(up, "1"), x, "10^" .. p .. " + 1 - 1")
			eq(B.add(down, "1"), x, "10^" .. p .. " - 1 + 1")
			eq(B.cmp(down, x), -1, "below < at")
			eq(B.cmp(up, x), 1, "above > at")
		end
		eq(B.sub("0", "1"), nil, "0 - 1 refused")
		eq(B.add(B.MAX, "1"), pow10(303), "MAX + 1 is exact (304 digits)")
		eq(B.cap(B.add(B.MAX, "1")), B.MAX, "and caps back to MAX")
		eq(B.sub(B.MAX, B.MAX), "0", "MAX - MAX")
		eq(B.add(below(3), "1"), "1000", "999 + 1")
	end,
	["bigmoney: arithmetic matches native numbers where those are exact (seeded fuzz)"] = function()
		for i = 1, 3000 do
			local a = rand(1000000) * 1000 + rand(1000)
			local b = rand(1000000) * 1000 + rand(1000)
			local A, Bb = B.of(a), B.of(b)
			eq(B.add(A, Bb), ("%d"):format(a + b), "add " .. i)
			if a >= b then
				eq(B.sub(A, Bb), ("%d"):format(a - b), "sub " .. i)
			else
				eq(B.sub(A, Bb), nil, "sub negative " .. i)
			end
			local k = rand(1000001)
			if a * k <= 9007199254740991 then
				eq(B.mulSmall(A, k), ("%d"):format(a * k), "mulSmall " .. i)
			end
			local d = 1 + rand(1000000)
			local q, r = B.divSmall(A, d)
			eq(q, ("%d"):format(a // d), "div " .. i)
			eq(r, a % d, "rem " .. i)
			eq(B.cmp(A, Bb), if a < b then -1 elseif a > b then 1 else 0, "cmp " .. i)
		end
	end,
	["bigmoney: identities hold at 300 digits"] = function()
		for i = 1, 200 do
			local a, b, c = randomBig(150), randomBig(150), randomBig(150)
			eq(B.sub(B.add(a, b), b), a, "(a+b)-b " .. i)
			eq(B.mul(a, b), B.mul(b, a), "commutative " .. i)
			eq(B.mul(a, B.add(b, c)), B.add(B.mul(a, b), B.mul(a, c)), "distributive " .. i)
			local k = 1 + rand(1000000)
			local q, r = B.divSmall(B.mulSmall(a, k), k)
			eq(q, a, "(a*k)/k " .. i)
			eq(r, 0, "no remainder " .. i)
			eq(B.mul(a, B.of(k)), B.mulSmall(a, k), "mul == mulSmall " .. i)
		end
	end,
	["bigmoney: multipliers are exact, rounded down once"] = function()
		eq(B.mulFactors("99", { 1.5 }), "148", "99 x 1.5 = 148.5 -> 148")
		eq(B.mulFactors("13200", { 1.5 }), "19800", "receipt from Studio")
		eq(B.mulFactors("3", { 1.5, 1.5 }), "6", "3 x 2.25 = 6.75 -> 6 (one floor, not two)")
		eq(B.mulFactors(B.MAX, { 8 }), B.sub(B.mulSmall(B.MAX, 8), "0"), "x8 at MAX is exact")
		eq(B.mulFactors(pow10(30), { 1.5 }), "15" .. string.rep("0", 29), "1.5 No")
		eq(B.mulFactors("1000", {}), "1000", "no factors")
		local ok = pcall(B.factor, 1.2345)
		eq(ok, false, "four decimals refused")
		ok = pcall(B.factor, -1)
		eq(ok, false, "negative factor refused")
		ok = pcall(B.factor, 0 / 0)
		eq(ok, false, "NaN factor refused")
	end,
	["format: compact names every tier, rounds down, then goes scientific"] = function()
		local cases = {
			{ "0", "0" },
			{ "1", "1" },
			{ "999", "999" },
			{ "1000", "1.00K" },
			{ "1009", "1.00K" },
			{ "999999", "999K" },
			{ "1000000", "1.00M" },
			{ "1250000000000000000", "1.25Qi" },
			{ below(18), "999Qa" },
			{ pow10(18), "1.00Qi" },
			{ pow10(21), "1.00Sx" },
			{ pow10(24), "1.00Sp" },
			{ pow10(27), "1.00Oc" },
			{ pow10(30), "1.00No" },
			{ pow10(33), "1.00Dc" },
			{ pow10(36), "1.00Ud" },
			{ pow10(39), "1.00Dd" },
			{ pow10(42), "1.00Td" },
			{ pow10(45), "1.00Qad" },
			{ pow10(48), "1.00Qid" },
			{ pow10(51), "1.00Sxd" },
			{ pow10(54), "1.00Spd" },
			{ pow10(57), "1.00Ocd" },
			{ pow10(60), "1.00Nod" },
			{ pow10(63), "1.00Vg" },
			{ below(66), "999Vg" },
			{ pow10(66), "1.00e66" },
			{ "125" .. string.rep("0", 118), "1.25e120" },
			{ B.MAX, "9.99e302" },
		}
		for _, c in cases do
			eq(B.compact(c[1]), c[2], "compact " .. #c[1] .. " digits")
		end
		-- Never shows the next label for one unit less.
		for p = 3, 66, 3 do
			assert(B.compact(below(p)) ~= B.compact(pow10(p)), "10^" .. p .. "-1")
		end
		eq(B.compact("abc"), "0", "invalid shows 0")
		eq(B.compact(1500), "1.50K", "numbers accepted")
	end,
	["format: full digits and the tag"] = function()
		eq(B.full("0"), "0", "0")
		eq(B.full("999"), "999", "999")
		eq(B.full("1000"), "1,000", "1,000")
		eq(B.full("1234567"), "1,234,567", "1,234,567")
		eq(#B.full(B.MAX), 303 + 100, "MAX with 100 separators")
		eq(B.tag("999999"), "999,999", "tag below a million")
		eq(B.tag("1000000"), "1.00M", "tag at a million")
		-- The longest tag is short enough for a phone cash tag.
		for p = 0, 302 do
			assert(#B.tag(pow10(p)) <= 9, "tag 10^" .. p .. " = " .. B.tag(pow10(p)))
		end
	end,
}
