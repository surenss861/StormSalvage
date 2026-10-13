--!strict
-- Pure economy rules, shared by the server (which is authoritative) and the unit tests
-- (tests/economy.spec.luau, run with Lune in CI). No Roblox APIs here, so it runs anywhere.

local Economy = {}

-- A sale: the base value of everything carried and the payout after multipliers. Multipliers
-- stack by multiplying; the payout rounds down.
function Economy.sellTotal(values: { number }, factors: { number }): (number, number)
	local base = 0
	for _, v in values do
		assert(type(v) == "number" and v >= 0 and v == v, "invalid item value")
		base += v
	end
	local m = 1
	for _, f in factors do
		assert(type(f) == "number" and f > 0 and f == f and f < math.huge, "invalid multiplier")
		m *= f
	end
	return base, math.floor(base * m)
end

export type UpgradeCheck = {
	Ok: boolean,
	Reason: ("maxed" | "short" | "invalid")?,
	Cost: number?,
	Short: number?,
}

-- Can a player at `level` with `coins` buy the next level of an upgrade priced by `costs`?
function Economy.checkUpgrade(costs: { number }, level: unknown, coins: unknown): UpgradeCheck
	if type(level) ~= "number" or type(coins) ~= "number" or level ~= level or coins ~= coins then
		return { Ok = false, Reason = "invalid" }
	end
	if level < 0 or level % 1 ~= 0 then
		return { Ok = false, Reason = "invalid" }
	end
	local cost = costs[level + 1]
	if not cost then
		return { Ok = false, Reason = "maxed" }
	end
	if coins < cost then
		return { Ok = false, Reason = "short", Cost = cost, Short = cost - coins }
	end
	return { Ok = true, Cost = cost }
end

return Economy
