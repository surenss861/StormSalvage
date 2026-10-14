-- @file Pending cooperative rewards: paid once, bounded, exact, never someone else's
-- @domain qa
-- @status stable
-- @see [[PendingRewards.luau]]
local P = require("../src/shared/PendingRewards")

local function eq(a: any, b: any, what: string)
	if a ~= b then
		error(("%s: expected %s, got %s"):format(what, tostring(b), tostring(a)), 2)
	end
end

local NOW = 2000000000

local function entry(id: string, at: number?): any
	return { Id = id, Items = { "BullionBar" }, Source = "Wreck", At = at or NOW }
end

return {
	["pending: adding the same share twice keeps one"] = function()
		local r = P.add(nil, entry("w1:a"), NOW)
		r = P.add(r, entry("w1:a"), NOW + 5)
		eq(#r.Entries, 1, "one entry")
	end,
	["pending: expired entries are dropped and the list is capped"] = function()
		local r = P.add(nil, entry("old", NOW - P.TTL - 1), NOW)
		eq(#P.live(r, NOW), 0, "an expired share is not live")
		r = P.add(nil, entry("old", NOW - P.TTL - 1), NOW - P.TTL - 1)
		r = P.add(r, entry("new"), NOW)
		eq(#r.Entries, 1, "the expired one went")
		eq(r.Entries[1].Id, "new", "the new one stayed")
		for i = 1, P.MAX + 5 do
			r = P.add(r, entry("e" .. i, NOW + i), NOW + i)
		end
		eq(#r.Entries, P.MAX, "capped")
		eq(r.Entries[#r.Entries].Id, "e" .. (P.MAX + 5), "newest kept")
	end,
	["pending: removing claimed ids leaves the rest"] = function()
		local r = P.add(P.add(nil, entry("a"), NOW), entry("b"), NOW)
		r = P.remove(r, { a = true })
		eq(#r.Entries, 1, "one left")
		eq(r.Entries[1].Id, "b", "b")
	end,
	["pending: the payout is the exact sale value at the owner's press"] = function()
		local values = { BullionBar = 1200000, CrownJewels = 8000000 }
		eq(P.value({ "BullionBar", "BullionBar" }, values, 1), "2400000", "base")
		eq(P.value({ "BullionBar", "CrownJewels" }, values, 8), "73600000", "x8 press")
		eq(P.value({ "Nonsense" }, values, 8), "0", "unknown items pay nothing")
	end,
	["pending: claimed ids are remembered longer than any entry lives"] = function()
		assert(P.CLAIM_MEMORY > P.TTL, "memory outlives entries, so a late duplicate can't pay twice")
		local c = P.remember(nil, "a", NOW)
		eq(P.claimed(c, "a"), true, "remembered")
		c = P.remember(c, "b", NOW + P.CLAIM_MEMORY + 1)
		eq(P.claimed(c, "a"), false, "forgotten after the memory window")
		eq(P.claimed(c, "b"), true, "b")
	end,
}
