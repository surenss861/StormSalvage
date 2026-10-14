-- @file Progression rules unit tests
-- @domain qa
-- @status stable
-- @see [[Progression.luau]]
local P = require("../src/shared/Progression")

local function eq(a: any, b: any, what: string)
	if a ~= b then
		error(("%s: expected %s, got %s"):format(what, tostring(b), tostring(a)), 2)
	end
end
local function first(_n: number): number
	return 1
end

return {
	["rank: thresholds and titles"] = function()
		eq(P.rankFor(0).Title, "Scrap Rookie", "0")
		eq(P.rankFor(149).Index, 1, "149")
		eq(P.rankFor(150).Index, 2, "150")
		eq(P.rankFor(9000).Title, "Storm Legend", "top")
		eq(P.rankFor(999999).Index, 7, "beyond top")
		eq(P.nextRank(9000), nil, "no next at top")
		eq((P.nextRank(0) :: any).Index, 2, "next from 0")
	end,
	["contract: rank 1 values"] = function()
		local c = P.make("Sell", 1, 7, first)
		eq(c.Id, "c7", "id")
		eq(c.Target, 8, "target")
		eq(c.Coins, 25, "coins")
		eq(c.XP, 25, "xp")
		eq(c.Progress, 0, "progress")
	end,
	["contract: scales with rank, fixed kinds don't"] = function()
		eq(P.make("Sell", 3, 1, first).Target, 14, "sell r3") -- 8 * 1.7 = 13.6
		eq(P.make("Earn", 4, 1, first).Target, 300, "earn r4") -- 150 * 2.05 = 307.5 -> 300
		eq(P.make("Survive", 7, 1, first).Target, 1, "survive fixed")
		eq(P.make("Core", 7, 1, first).Coins, 250, "core coins r7") -- 80 * 3.1 = 248 -> 250
	end,
	["contract: zone jobs name a district"] = function()
		local c = P.make("Zone", 1, 1, function(n)
			return n -- last district
		end)
		eq(c.Zone, "FloodWorks", "zone")
		eq(P.describe(c), "Salvage 4 items at Flood Control", "text")
	end,
	["contract: three active jobs are different kinds"] = function()
		local active = {}
		for i = 1, 3 do
			table.insert(active, P.make(P.pickKind(active, first), 1, i, first))
		end
		eq(
			active[1].Kind ~= active[2].Kind
				and active[2].Kind ~= active[3].Kind
				and active[1].Kind ~= active[3].Kind,
			true,
			"distinct"
		)
	end,
	["events advance only matching jobs"] = function()
		local zone = P.make("Zone", 1, 1, first) -- Houses
		eq(P.advance(zone, { Type = "Collected", Items = 1, Zone = "Houses" }), 1, "zone match")
		eq(P.advance(zone, { Type = "Collected", Items = 1, Zone = "Motel" }), 0, "zone other")
		eq(P.advance(zone, { Type = "Collected", Items = 1 }), 0, "zone nil (core / dropped bag)")
		eq(P.advance(P.make("Earn", 1, 1, first), { Type = "Sold", Items = 3, Coins = 90 }), 90, "earn")
		eq(
			P.advance(P.make("Core", 1, 1, first), { Type = "Sold", Items = 3, Coins = 90, Cores = 0 }),
			0,
			"core none"
		)
		eq(P.advance(P.make("Survive", 1, 1, first), { Type = "Survived" }), 1, "survive")
		eq(P.advance(P.make("Sell", 1, 1, first), { Type = "Survived" }), 0, "sell vs survive")
	end,
	["finishes: rank gate, cost, owned"] = function()
		eq(P.canBuyFinish("Tin", 1000, 0, {}), false, "rank 1 can't buy rank 2 finish")
		local ok, why = P.canBuyFinish("Tin", 400, 150, {})
		eq(ok, false, "short")
		eq(why, "short", "short reason")
		eq(P.canBuyFinish("Tin", 500, 150, {}), true, "exact coins")
		eq(P.canBuyFinish("Tin", 500, 150, { Tin = true }), false, "owned")
		eq(P.canBuyFinish("Nope", 1e9, 1e9, {}), false, "unknown")
		eq(P.canBuyFinish({}, 1e9, 1e9, {}), false, "garbage id")
	end,
}
