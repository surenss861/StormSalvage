--!strict
-- @file Prices, upgrade costs and sell values
-- @domain salvage-economy
-- @status stable
-- @tested-by [[economy.spec.luau]]
-- Pure economy rules, shared by the server (which is authoritative) and the unit tests
-- (tests/economy.spec.luau, run with Lune in CI). No Roblox APIs here, so it runs anywhere.
-- V4: all amounts are exact (BigMoney); nothing here converts a balance to a Luau number.

-- Roblox resolves the sibling ModuleScript; Lune (unit tests) resolves the file path.
local BigMoney = if script then require(script.Parent.BigMoney) else (require :: any)("./BigMoney")

local Economy = {}

type Big = string

-- A sale: the exact base value of everything carried and the payout after multipliers. Item
-- values may be numbers or BigMoney strings. Multipliers stack by multiplying (each is exact to
-- three decimals, BigMoney.factor) and the payout is rounded down once.
function Economy.sellTotal(values: { number | string }, factors: { number }): (Big, Big)
	local base = "0"
	for _, v in values do
		local amount = BigMoney.parse(v)
		assert(amount, "invalid item value")
		base = BigMoney.add(base, amount)
	end
	for _, f in factors do
		assert(type(f) == "number" and f > 0 and f == f and f < math.huge, "invalid multiplier")
	end
	return base, BigMoney.mulFactors(base, factors)
end

export type UpgradeCheck = {
	Ok: boolean,
	Reason: ("maxed" | "short" | "invalid")?,
	Cost: Big?,
	Short: Big?,
}

local function affordable(cost: Big, coins: Big): UpgradeCheck
	if BigMoney.lt(coins, cost) then
		return { Ok = false, Reason = "short", Cost = cost, Short = BigMoney.sub(cost, coins) }
	end
	return { Ok = true, Cost = cost }
end

-- Can a player at `level` with `coins` buy the next level of an upgrade priced by `costs`?
-- Coins and costs may be numbers or BigMoney strings; results are exact strings.
function Economy.checkUpgrade(costs: { number | string }, level: unknown, coins: unknown): UpgradeCheck
	local have = BigMoney.parse(coins)
	if type(level) ~= "number" or level ~= level or not have then
		return { Ok = false, Reason = "invalid" }
	end
	if level < 0 or level % 1 ~= 0 then
		return { Ok = false, Reason = "invalid" }
	end
	local raw = costs[level + 1]
	if raw == nil then
		return { Ok = false, Reason = "maxed" }
	end
	local cost = BigMoney.parse(raw)
	if not cost then
		return { Ok = false, Reason = "invalid" }
	end
	return affordable(cost, have)
end

-- Can a player buy a permanent tool (Gear Shop Tools tab)? One price, owned once.
function Economy.checkTool(cost: unknown, owned: unknown, coins: unknown): UpgradeCheck
	local price, have = BigMoney.parse(cost), BigMoney.parse(coins)
	if not price or not have then
		return { Ok = false, Reason = "invalid" }
	end
	if owned == true then
		return { Ok = false, Reason = "maxed" }
	end
	return affordable(price, have)
end

return Economy
