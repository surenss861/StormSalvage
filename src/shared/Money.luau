--!strict
-- @file Safe coin arithmetic and the compact currency formatter
-- @domain salvage-economy
-- @status wip
-- @tested-by [[money.spec.luau]]
-- @see [[V4-ECONOMY]]
-- Coins are whole numbers from 0 to Money.MAX (1 Qa = 10^15), safely below 2^53, where Luau
-- doubles stop being exact integers. Every server grant and spend goes through here, so no
-- balance can become fractional, negative, NaN, infinite or imprecise, whatever the multipliers.
-- Display: Money.compact ("1.23M") rounds DOWN, so a balance never looks bigger than it is (a
-- player with 999,999 sees "999K", not "1.00M"); Money.full gives every digit for receipts.
-- Pure: no Roblox APIs, so `lune` tests it.

local Money = {}

Money.MAX = 1e15 -- 1 Qa; 2^53 is about 9.007e15

local function finite(n: unknown): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

-- A valid stored amount: a finite whole number in [0, MAX].
function Money.valid(n: unknown): boolean
	return finite(n) and (n :: number) >= 0 and (n :: number) <= Money.MAX and (n :: number) % 1 == 0
end

-- Any number to a valid amount: invalid -> 0, floored, clamped to [0, MAX].
function Money.clamp(n: unknown): number
	if not finite(n) then
		return 0
	end
	return math.clamp(math.floor(n :: number), 0, Money.MAX)
end

-- Adds `amount` (floored; invalid or negative adds nothing) to `balance`, capped at MAX.
-- Returns the new balance and how much was actually added.
function Money.grant(balance: number, amount: unknown): (number, number)
	local b = Money.clamp(balance)
	local a = Money.clamp(amount)
	local after = math.min(Money.MAX, b + a)
	return after, after - b
end

-- Takes `cost` from `balance` if it can be afforded. Invalid costs are refused.
function Money.spend(balance: number, cost: unknown): (boolean, number)
	local b = Money.clamp(balance)
	if not Money.valid(cost) then
		return false, b
	end
	if b < (cost :: number) then
		return false, b
	end
	return true, b - (cost :: number)
end

-- `amount` times a multiplier, floored and clamped (an invalid or negative factor gives 0).
function Money.scale(amount: number, factor: unknown): number
	if not finite(factor) or (factor :: number) < 0 then
		return 0
	end
	return Money.clamp(Money.clamp(amount) * (factor :: number))
end

local SUFFIXES = { "K", "M", "B", "T", "Qa" }

-- "999", "1.23K", "45.6M", "789B", "1.00T": three significant figures, rounded down.
function Money.compact(n: number): string
	if not finite(n) then
		return "0"
	end
	local sign = if n < 0 then "-" else ""
	local v = math.floor(math.abs(n))
	if v < 1000 then
		return sign .. tostring(v)
	end
	-- Work on the digits themselves, so no float rounding can round anything up.
	local digits = ("%d"):format(v)
	local tier = math.min(#SUFFIXES, math.floor((#digits - 1) / 3))
	local whole = #digits - tier * 3 -- digits before the decimal point (1-3, more past Qa)
	local text
	if whole >= 3 then
		text = digits:sub(1, whole)
	else
		text = digits:sub(1, whole) .. "." .. digits:sub(whole + 1, 3)
	end
	return sign .. text .. SUFFIXES[tier]
end

-- Every digit with thousands separators: "1,234,567".
function Money.full(n: number): string
	if not finite(n) then
		return "0"
	end
	local sign = if n < 0 then "-" else ""
	local s = ("%d"):format(math.floor(math.abs(n)))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return sign .. out
end

-- The coin tag: every digit while it fits (under a million), compact after.
function Money.tag(n: number): string
	if finite(n) and math.abs(n) < 1e6 then
		return Money.full(n)
	end
	return Money.compact(n)
end

return Money
