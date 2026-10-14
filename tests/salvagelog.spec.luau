-- @file Salvage Log and golden prize unit tests
-- @domain qa
-- @status stable
-- @see [[SalvageLog.luau]]
-- @see [[Pursuit.luau]]
local SalvageLog = require("../src/shared/SalvageLog")
local Pursuit = require("../src/shared/Pursuit")

local function eq(a: any, b: any, what: string)
	if a ~= b then
		error(("%s: expected %s, got %s"):format(what, tostring(b), tostring(a)), 2)
	end
end

local KNOWN = {
	Can = { Rarity = "Common", Value = 2 },
	Pipe = { Rarity = "Common", Value = 5 },
	Safe = { Rarity = "Epic", Value = 90 },
	StormCore = { Rarity = "Legendary", Value = 175 },
	GoldenCore = { Rarity = "Legendary", Value = 600 },
}

return {
	["salvage log: first find is a discovery, repeats are not"] = function()
		local c = SalvageLog.reconcile(nil)
		local first, n = SalvageLog.record(c, "Safe", KNOWN)
		eq(first, true, "first")
		eq(n, 1, "count 1")
		for i = 2, 5 do
			first, n = SalvageLog.record(c, "Safe", KNOWN)
			eq(first, false, "repeat " .. i)
			eq(n, i, "count " .. i)
		end
		eq(SalvageLog.progress(c, KNOWN), 1, "one kind found")
	end,
	["salvage log: unknown ids change nothing"] = function()
		local c = SalvageLog.reconcile({})
		local first, n = SalvageLog.record(c, "Banana", KNOWN)
		eq(first, false, "not a discovery")
		eq(n, 0, "no count")
		eq(c.Found.Banana, nil, "not found")
		eq(c.Counts.Banana, nil, "not counted")
	end,
	["salvage log: old saves keep finds and gain counts"] = function()
		local c = SalvageLog.reconcile({ Found = { Can = true, Safe = true } })
		eq(c.Counts.Can, 1, "backfilled can")
		eq(c.Counts.Safe, 1, "backfilled safe")
		eq(c.Found.Can, true, "kept found")
		local first = SalvageLog.record(c, "Can", KNOWN)
		eq(first, false, "an old find is not a new discovery")
		eq(c.Counts.Can, 2, "counted on")
	end,
	["salvage log: bad counts are repaired, good ones kept"] = function()
		local c = SalvageLog.reconcile({
			Found = { Pipe = true },
			Counts = { Can = -3, Pipe = 0 / 0, Safe = "x", StormCore = 7.9 },
		})
		eq(c.Counts.Can, nil, "negative dropped")
		eq(c.Counts.Pipe, 1, "NaN dropped, then backfilled from Found")
		eq(c.Counts.Safe, nil, "non-number dropped")
		eq(c.Counts.StormCore, 7, "floored")
	end,
	["salvage log: progress counts known kinds only"] = function()
		local c = SalvageLog.reconcile({ Found = { Can = true, GoldenCore = true, Retired = true } })
		local count, total = SalvageLog.progress(c, KNOWN)
		eq(count, 2, "found")
		eq(total, 5, "total")
	end,
	["salvage log: order is rarity, then value"] = function()
		local ids = SalvageLog.order(KNOWN)
		eq(table.concat(ids, ","), "Can,Pipe,Safe,StormCore,GoldenCore", "order")
	end,
	["golden prize: chance boundary"] = function()
		eq(
			Pursuit.pickPrize(0.15, function()
				return 0.1499
			end),
			"GoldenCore",
			"below"
		)
		eq(
			Pursuit.pickPrize(0.15, function()
				return 0.15
			end),
			"StormCore",
			"at"
		)
		eq(
			Pursuit.pickPrize(0, function()
				return 0
			end),
			"StormCore",
			"never at 0"
		)
	end,
	["golden prize: about 15% over many rolls"] = function()
		-- A seeded LCG (Lune has no Random), so the test is deterministic.
		local seed = 20261014
		local function roll(): number
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed / 2147483648
		end
		local golden, n = 0, 20000
		for _ = 1, n do
			if Pursuit.pickPrize(0.15, roll) == "GoldenCore" then
				golden += 1
			end
		end
		local rate = golden / n
		-- 20,000 rolls: 3 standard deviations is about 0.0076.
		assert(math.abs(rate - 0.15) < 0.0076, ("rate %.4f"):format(rate))
	end,
}
