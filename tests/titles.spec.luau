-- @file Earned titles and progression bands unit tests
-- @domain qa
-- @status stable
-- @see [[Titles.luau]]
-- @see [[Bands.luau]]
local Titles = require("../src/shared/Titles")
local Bands = require("../src/shared/Bands")

local function eq(a: any, b: any, what: string)
	if a ~= b then
		error(("%s: expected %s, got %s"):format(what, tostring(b), tostring(a)), 2)
	end
end

local function view(records: any?, found: any?, earned: number?, licenses: any?): any
	return {
		Records = records or {},
		Found = found or {},
		TotalEarned = earned or 0,
		Licenses = licenses or {},
	}
end

local function has(list: { string }, id: string): boolean
	return table.find(list, id) ~= nil
end

return {
	["titles: a new player has none"] = function()
		eq(#Titles.earned(view()), 0, "none")
	end,
	["titles: pursuit titles follow the records"] = function()
		local got = Titles.earned(
			view({ Extractions = 1, BestExtract = 19.9, BestStreak = 3, Hardest = 3, GoldenExtractions = 1 })
		)
		for _, id in { "Stormbreaker", "QuickHands", "Untouchable", "Daredevil", "JackpotHunter" } do
			assert(has(got, id), id)
		end
		got = Titles.earned(view({ Extractions = 1, BestExtract = 20, BestStreak = 2, Hardest = 2 }))
		eq(has(got, "QuickHands"), false, "20.0 s is not under 20")
		eq(has(got, "Untouchable"), false, "streak 2")
		eq(has(got, "Daredevil"), false, "difficulty 2")
		eq(has(got, "JackpotHunter"), false, "no golden")
		got = Titles.earned(view({ Extractions = 0, BestExtract = 0 }))
		eq(has(got, "QuickHands"), false, "never extracted (0 means none)")
	end,
	["titles: discovery and wealth"] = function()
		local found = {}
		for _, id in Titles.Band1Kinds do
			found[id] = true
		end
		eq(has(Titles.earned(view(nil, found)), "Collector"), true, "all 12")
		found.GoldenCore = nil
		eq(has(Titles.earned(view(nil, found)), "Collector"), false, "golden missing")
		eq(has(Titles.earned(view(nil, { TurbineRotor = true })), "TurbineHunter"), true, "turbine")
		eq(has(Titles.earned(view(nil, nil, 999999)), "FirstFortune"), false, "999,999")
		eq(has(Titles.earned(view(nil, nil, 1000000)), "FirstFortune"), true, "1M")
		eq(has(Titles.earned(view(nil, nil, 0, { Pro = true })), "Professional"), true, "licence")
	end,
	["titles: bad records never grant"] = function()
		local got = Titles.earned(view({ Extractions = 0 / 0, BestExtract = -5, BestStreak = "9" }))
		eq(#got, 0, "nothing from garbage")
	end,
	["titles: newly earned skips owned ones"] = function()
		local got = Titles.newlyEarned(view({ Extractions = 2, BestExtract = 30 }), { Stormbreaker = true })
		eq(#got, 0, "already owned")
	end,
	["titles: only owned real titles can be shown"] = function()
		local owned = { Stormbreaker = true }
		eq(Titles.canShow("Stormbreaker", owned), true, "owned")
		eq(Titles.canShow("Daredevil", owned), false, "not owned")
		eq(Titles.canShow("Admin", { Admin = true }), false, "not a title")
		eq(Titles.canShow(nil, owned), true, "rank instead")
		eq(Titles.canShow(5, owned), false, "number")
	end,
	["titles: reconcile drops unknown and unowned"] = function()
		local t = Titles.reconcile({
			Owned = { Stormbreaker = true, Admin = true, Daredevil = "yes" },
			Shown = "Daredevil",
		})
		eq(t.Owned.Stormbreaker, true, "kept")
		eq(t.Owned.Admin, nil, "unknown dropped")
		eq(t.Owned.Daredevil, nil, "malformed dropped")
		eq(t.Shown, nil, "unowned shown cleared")
		eq(Titles.reconcile(nil).Shown, nil, "nil save")
	end,
	["bands: band follows licences"] = function()
		eq(Bands.bandOf(nil), 1, "none")
		eq(Bands.bandOf({}), 1, "empty")
		eq(Bands.bandOf({ Pro = true }), 2, "pro")
		eq(Bands.bandOf({ Fake = true }), 1, "unknown licence")
	end,
	["bands: licence needs every requirement and the coins"] = function()
		local ok = Bands.checkLicense("Pro", { Rank = 3, Extractions = 3, Coins = 5000, Owned = false })
		eq(ok.Ok, true, "all met")
		local r = Bands.checkLicense("Pro", { Rank = 2, Extractions = 3, Coins = 1e9, Owned = false })
		eq(r.Reason, "requirements", "rank short, coins don't help")
		eq(#r.Missing, 1, "one missing")
		r = Bands.checkLicense("Pro", { Rank = 3, Extractions = 2, Coins = 1e9, Owned = false })
		eq(r.Reason, "requirements", "extractions short")
		r = Bands.checkLicense("Pro", { Rank = 3, Extractions = 3, Coins = 4999, Owned = false })
		eq(r.Reason, "short", "coins short")
		r = Bands.checkLicense("Pro", { Rank = 9, Extractions = 9, Coins = 1e9, Owned = true })
		eq(r.Reason, "owned", "owned")
		eq(
			Bands.checkLicense("Mega", { Rank = 9, Extractions = 9, Coins = 1e9, Owned = false }).Reason,
			"invalid",
			"unknown"
		)
		eq(
			Bands.checkLicense(nil, { Rank = 9, Extractions = 9, Coins = 1e9, Owned = false }).Reason,
			"invalid",
			"nil"
		)
		r = Bands.checkLicense("Pro", { Rank = 3, Extractions = 0 / 0, Coins = 1e9, Owned = false } :: any)
		eq(r.Reason, "requirements", "NaN extractions")
	end,
	["bands: press needs the licence and climbs in order"] = function()
		eq(Bands.checkPress(0, false, 1e9).Reason, "license", "unlicensed")
		local c = Bands.checkPress(0, true, 20000)
		eq(c.Ok, true, "first level")
		eq(c.Cost, 20000, "cost")
		eq(Bands.checkPress(0, true, 19999).Reason, "short", "short")
		eq(Bands.checkPress(6, true, 1e12).Reason, "maxed", "maxed")
		eq(Bands.checkPress(-1, true, 1e9).Reason, "invalid", "negative")
		eq(Bands.checkPress(1.5, true, 1e9).Reason, "invalid", "fraction")
		eq(#Bands.Press.Values, #Bands.Press.Costs + 1, "a factor per level")
		for i = 2, #Bands.Press.Values do
			assert(Bands.Press.Values[i] > Bands.Press.Values[i - 1], "factors rise")
		end
	end,
	["bands: event bonus by band and kind"] = function()
		eq(Bands.eventBonus(1, "Pursuit", false), 150, "band 1 pursuit (unchanged)")
		eq(Bands.eventBonus(1, "Extraction", false), 120, "band 1 extraction (unchanged)")
		eq(Bands.eventBonus(1, "Pursuit", true), 150, "band 1 golden (unchanged)")
		eq(Bands.eventBonus(2, "Pursuit", false), 6000, "band 2")
		eq(Bands.eventBonus(2, "Pursuit", true), 18000, "band 2 golden")
		eq(Bands.eventBonus(99, "Pursuit", false), 6000, "clamped to the top band")
	end,
	["bands: industrial salvage outvalues town salvage, rarer is worth more"] = function()
		for i = 2, #Bands.Industrial do
			assert(Bands.Industrial[i].Value > Bands.Industrial[i - 1].Value, "rising value")
			assert(Bands.Industrial[i].Weight < Bands.Industrial[i - 1].Weight, "rarer")
		end
		assert(Bands.Industrial[1].Value > 140, "cheapest beats the best town Epic (140)")
	end,
}
