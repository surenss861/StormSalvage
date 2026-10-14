--!strict
-- @file Exact large-integer money: arithmetic and the one currency formatter
-- @domain salvage-economy
-- @status wip
-- @tested-by [[bigmoney.spec.luau]]
-- @see [[Wallet.luau]]
-- @see [[V4-BIG-NUMBERS]]
-- Coins are exact non-negative integers of up to 303 decimal digits (just under 10^303), carried
-- as canonical decimal strings ("0", "1500", "1250000000000000000000"): that is what's saved,
-- replicated and shown. Arithmetic works on base-1,000 limbs, never on a whole balance converted
-- to a Luau number, so nothing is ever rounded, lost or invented, at any size.
--   Accepted inputs: canonical digit strings, or whole Luau numbers 0 .. 2^53-1 (exact there).
--   Rejected: negatives, fractions, NaN/infinity, signs, spaces, exponents, empty strings, and
--   anything longer than MAX_DIGITS (raw strings over MAX_INPUT characters are refused unread).
-- Formatting: compact ("1.25Qi") rounds DOWN to three significant digits, so it never shows more
-- than the player has; named suffixes up to Vg (10^63), scientific beyond ("1.25e120"); full
-- gives every digit for receipts.
-- Pure: no Roblox APIs, so `lune` tests and benchmarks it.

local BigMoney = {}

export type Big = string

BigMoney.MAX_DIGITS = 303
BigMoney.MAX = string.rep("9", BigMoney.MAX_DIGITS) :: Big -- 10^303 - 1
BigMoney.ZERO = "0" :: Big
local MAX_INPUT = 400 -- longest raw string even looked at (leading zeros allowed up to this)
local SAFE_INT = 9007199254740991 -- 2^53 - 1

---------------------------------------------------------------------------- Parsing

-- The canonical form of `x`, or nil and why not.
function BigMoney.parse(x: unknown): (Big?, string?)
	if type(x) == "number" then
		if x ~= x or x == math.huge or x == -math.huge then
			return nil, "not finite"
		elseif x < 0 then
			return nil, "negative"
		elseif x % 1 ~= 0 then
			return nil, "fraction"
		elseif x > SAFE_INT then
			return nil, "number too large to be exact"
		end
		return ("%d"):format(x), nil
	elseif type(x) == "string" then
		if #x == 0 then
			return nil, "empty"
		elseif #x > MAX_INPUT then
			return nil, "too long"
		elseif not x:match("^%d+$") then
			return nil, "not digits"
		end
		local s = x:match("^0*(%d-)$") :: string
		if s == "" then
			s = "0"
		end
		if #s > BigMoney.MAX_DIGITS then
			return nil, "out of range"
		end
		return s, nil
	end
	return nil, "not a number or string"
end

-- Is `x` already a canonical amount (no leading zeros, in range)?
function BigMoney.is(x: unknown): boolean
	return type(x) == "string" and BigMoney.parse(x) == x
end

-- Like parse, but errors on bad input: for amounts the code itself supplies (prices, rewards).
function BigMoney.of(x: unknown): Big
	local v, why = BigMoney.parse(x)
	if not v then
		error(("invalid amount %s (%s)"):format(tostring(x), tostring(why)), 2)
	end
	return v
end

-- A legacy saved balance (a Luau number, possibly beyond 2^53 or fractional) converted exactly:
-- the integer part of the double, every digit. nil for NaN, infinity or negatives (the caller
-- must keep the original and report it: never quietly zero a balance).
function BigMoney.fromLegacyNumber(n: unknown): Big?
	if type(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge or n < 0 then
		return nil
	end
	local s = ("%.0f"):format(math.floor(n))
	if #s > BigMoney.MAX_DIGITS then
		return nil
	end
	return s
end

---------------------------------------------------------------------------- Limbs

-- Little-endian base-1000 limbs of a canonical string.
local function limbs(s: Big): { number }
	local out = {}
	local i = #s
	while i >= 1 do
		local j = math.max(1, i - 2)
		table.insert(out, tonumber(s:sub(j, i)) :: number)
		i = j - 1
	end
	return out
end

local function fromLimbs(l: { number }): Big
	local n = #l
	while n > 1 and l[n] == 0 do
		l[n] = nil
		n -= 1
	end
	if n == 0 then
		return "0"
	end
	local parts = table.create(n) :: { string }
	parts[1] = tostring(l[n])
	for k = n - 1, 1, -1 do
		parts[n - k + 1] = ("%03d"):format(l[k])
	end
	return table.concat(parts)
end

---------------------------------------------------------------------------- Comparison

-- -1, 0 or 1. Both arguments must be canonical (use BigMoney.of on anything else).
function BigMoney.cmp(a: Big, b: Big): number
	if #a ~= #b then
		return if #a < #b then -1 else 1
	end
	if a == b then
		return 0
	end
	return if a < b then -1 else 1 -- same length: digit strings compare like numbers
end

function BigMoney.lt(a: Big, b: Big): boolean
	return BigMoney.cmp(a, b) < 0
end

function BigMoney.gte(a: Big, b: Big): boolean
	return BigMoney.cmp(a, b) >= 0
end

function BigMoney.min(a: Big, b: Big): Big
	return if BigMoney.cmp(a, b) <= 0 then a else b
end

function BigMoney.isZero(a: Big): boolean
	return a == "0"
end

---------------------------------------------------------------------------- Arithmetic

-- a + b, exact (may exceed MAX by one digit; callers that store it clamp with BigMoney.cap).
function BigMoney.add(a: Big, b: Big): Big
	local x, y = limbs(a), limbs(b)
	local out = table.create(math.max(#x, #y) + 1) :: { number }
	local carry = 0
	for i = 1, math.max(#x, #y) do
		local s = (x[i] or 0) + (y[i] or 0) + carry
		if s >= 1000 then
			out[i] = s - 1000
			carry = 1
		else
			out[i] = s
			carry = 0
		end
	end
	if carry > 0 then
		table.insert(out, carry)
	end
	return fromLimbs(out)
end

-- a - b, or nil if that would be negative.
function BigMoney.sub(a: Big, b: Big): Big?
	if BigMoney.cmp(a, b) < 0 then
		return nil
	end
	local x, y = limbs(a), limbs(b)
	local borrow = 0
	for i = 1, #x do
		local d = x[i] - (y[i] or 0) - borrow
		if d < 0 then
			x[i] = d + 1000
			borrow = 1
		else
			x[i] = d
			borrow = 0
		end
	end
	return fromLimbs(x)
end

-- a * k for a whole k in 0 .. 1,000,000, exact.
function BigMoney.mulSmall(a: Big, k: number): Big
	assert(
		type(k) == "number" and k >= 0 and k <= 1e6 and k % 1 == 0,
		"mulSmall: k must be a whole number 0..1e6"
	)
	if k == 0 or a == "0" then
		return "0"
	end
	local x = limbs(a)
	local carry = 0
	for i = 1, #x do
		local p = x[i] * k + carry -- at most 999 * 1e6 + carry: exact in a double
		x[i] = p % 1000
		carry = (p - x[i]) / 1000
	end
	while carry > 0 do
		local r = carry % 1000
		table.insert(x, r)
		carry = (carry - r) / 1000
	end
	return fromLimbs(x)
end

-- a * b, exact (schoolbook on limbs; at most 101 x 101 limbs).
function BigMoney.mul(a: Big, b: Big): Big
	if a == "0" or b == "0" then
		return "0"
	end
	local x, y = limbs(a), limbs(b)
	local out = table.create(#x + #y, 0) :: { number }
	for i = 1, #x do
		local carry = 0
		local xi = x[i]
		for j = 1, #y do
			local cur = out[i + j - 1] + xi * y[j] + carry
			out[i + j - 1] = cur % 1000
			carry = (cur - out[i + j - 1]) / 1000
		end
		local k = i + #y
		while carry > 0 do
			local cur = out[k] + carry
			out[k] = cur % 1000
			carry = (cur - out[k]) / 1000
			k += 1
		end
	end
	return fromLimbs(out)
end

-- floor(a / d) and the remainder, for a whole d in 1 .. 1,000,000.
function BigMoney.divSmall(a: Big, d: number): (Big, number)
	assert(
		type(d) == "number" and d >= 1 and d <= 1e6 and d % 1 == 0,
		"divSmall: d must be a whole number 1..1e6"
	)
	local x = limbs(a)
	local rem = 0
	for i = #x, 1, -1 do
		local cur = rem * 1000 + x[i] -- < 1e6 * 1000 + 1000: exact
		local q = math.floor(cur / d)
		x[i] = q
		rem = cur - q * d
	end
	return fromLimbs(x), rem
end

-- A multiplier as an exact fraction of 1000: 1.5 -> 1500. Factors must be 0 .. 1000 with at
-- most three decimals (every game multiplier is: x1.5, x2, x8, the 2x boost).
function BigMoney.factor(f: unknown): number
	assert(type(f) == "number" and f == f and f >= 0 and f <= 1000, "factor out of range")
	local k = math.floor(f * 1000 + 0.5)
	assert(math.abs(f * 1000 - k) < 1e-6, "factor needs at most 3 decimals")
	return k
end

-- floor(a * f1 * f2 * ...): every factor applied exactly, rounded down once at the end.
function BigMoney.mulFactors(a: Big, factors: { number }): Big
	local v = a
	for _, f in factors do
		v = BigMoney.mulSmall(v, BigMoney.factor(f))
	end
	for _ = 1, #factors do
		v = (BigMoney.divSmall(v, 1000))
	end
	return v
end

-- Clamped to [0, MAX].
function BigMoney.cap(a: Big): Big
	return if BigMoney.cmp(a, BigMoney.MAX) > 0 then BigMoney.MAX else a
end

-- An approximate Luau number, for analytics and progress bars ONLY (never for money).
function BigMoney.approx(a: Big): number
	if #a <= 15 then
		return tonumber(a) :: number
	end
	return (tonumber(a:sub(1, 15)) :: number) * 10 ^ (#a - 15)
end

---------------------------------------------------------------------------- Formatting

-- One suffix table for the whole game: 10^(3k).
BigMoney.SUFFIXES = {
	"K", -- thousand 10^3
	"M", -- million 10^6
	"B", -- billion 10^9
	"T", -- trillion 10^12
	"Qa", -- quadrillion 10^15
	"Qi", -- quintillion 10^18
	"Sx", -- sextillion 10^21
	"Sp", -- septillion 10^24
	"Oc", -- octillion 10^27
	"No", -- nonillion 10^30
	"Dc", -- decillion 10^33
	"Ud", -- undecillion 10^36
	"Dd", -- duodecillion 10^39
	"Td", -- tredecillion 10^42
	"Qad", -- quattuordecillion 10^45
	"Qid", -- quindecillion 10^48
	"Sxd", -- sexdecillion 10^51
	"Spd", -- septendecillion 10^54
	"Ocd", -- octodecillion 10^57
	"Nod", -- novemdecillion 10^60
	"Vg", -- vigintillion 10^63
}

local function toBig(x: unknown): Big
	local v = BigMoney.parse(x)
	return v or "0"
end

-- Three significant digits, rounded down: "999", "1.25K", "45.6M", "1.00Qi", "1.25e120".
-- Accepts a Big, or any value parse accepts (anything invalid shows as "0").
function BigMoney.compact(x: unknown): string
	local s = toBig(x)
	if #s <= 3 then
		return s
	end
	local tier = math.floor((#s - 1) / 3) -- 10^(3*tier) <= value
	if tier > #BigMoney.SUFFIXES then
		-- Scientific: mantissa d.dd, exponent = digits - 1.
		return ("%s.%se%d"):format(s:sub(1, 1), s:sub(2, 3), #s - 1)
	end
	local whole = #s - tier * 3
	local text = if whole >= 3 then s:sub(1, whole) else s:sub(1, whole) .. "." .. s:sub(whole + 1, 3)
	return text .. BigMoney.SUFFIXES[tier]
end

-- Every digit with thousands separators: "1,234,567".
function BigMoney.full(x: unknown): string
	local s = toBig(x)
	local first = #s % 3
	if first == 0 then
		first = 3
	end
	local parts = { s:sub(1, first) }
	for i = first + 1, #s, 3 do
		table.insert(parts, s:sub(i, i + 2))
	end
	return table.concat(parts, ",")
end

-- The coin tag: every digit while it fits (under a million), compact after.
function BigMoney.tag(x: unknown): string
	local s = toBig(x)
	return if #s <= 6 then BigMoney.full(s) else BigMoney.compact(s)
end

return BigMoney
