-- @file Salvage Detector rules unit tests
-- @domain qa
-- @status stable
-- @see [[Detector.luau]]
local Detector = require("../src/shared/Detector")

local function eq(a: any, b: any, what: string)
	if a ~= b then
		error(("%s: expected %s, got %s"):format(what, tostring(b), tostring(a)), 2)
	end
end

local ORDINARY = { Common = true, Uncommon = true, Rare = true }

local function c(id, x, z, rarity, dropped)
	return { Id = id, X = x, Z = z, Rarity = rarity, Dropped = dropped or false }
end

return {
	["detector: nearest first, capped"] = function()
		local got = Detector.pick(0, 0, {
			c("a", 30, 0, "Common"),
			c("b", 10, 0, "Common"),
			c("c", 0, 20, "Rare"),
			c("d", 5, 5, "Uncommon"),
		}, 55, ORDINARY, 3)
		eq(#got, 3, "count")
		eq(got[1].Id, "d", "first")
		eq(got[2].Id, "b", "second")
		eq(got[3].Id, "c", "third")
	end,
	["detector: never reveals Epic or Storm Cores"] = function()
		local got = Detector.pick(0, 0, {
			c("epic", 1, 0, "Epic"),
			c("core", 2, 0, "Legendary"),
			c("far", 40, 0, "Common"),
		}, 55, ORDINARY, 3)
		eq(#got, 1, "count")
		eq(got[1].Id, "far", "only the ordinary one")
	end,
	["detector: never reveals dropped bags"] = function()
		local got = Detector.pick(0, 0, { c("bag", 3, 0, "Common", true) }, 55, ORDINARY, 3)
		eq(#got, 0, "count")
	end,
	["detector: range is horizontal and inclusive"] = function()
		local got =
			Detector.pick(0, 0, { c("edge", 33, 44, "Common"), c("out", 34, 44, "Common") }, 55, ORDINARY, 3)
		eq(#got, 1, "count")
		eq(got[1].Id, "edge", "55 studs exactly is in")
	end,
	["detector: nothing nearby is an empty list"] = function()
		eq(#Detector.pick(0, 0, {}, 55, ORDINARY, 3), 0, "empty")
	end,
	["detector: sameSet compares ids in order"] = function()
		local a = { { Id = "1", X = 0, Z = 0, Distance = 1 } }
		eq(Detector.sameSet(nil, a), false, "nil vs set")
		eq(Detector.sameSet(a, { { Id = "1", X = 9, Z = 9, Distance = 9 } }), true, "same id")
		eq(Detector.sameSet(a, {}), false, "different size")
		eq(Detector.sameSet({}, {}), true, "both empty")
	end,
}
