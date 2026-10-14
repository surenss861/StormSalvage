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
		eq(has(Titles.earned(view(nil, nil, "1000000")), "FirstFortune"), true, "1M as a string")
		local q = Titles.earned(view(nil, nil, "1000000000000000000"))
		for _, id in { "FirstFortune", "Billionaire", "Trillionaire", "Quadrillionaire", "Quintillionaire" } do
			assert(has(q, id), id .. " at 1 Qi")
		end
		eq(
			has(Titles.earned(view(nil, nil, "999999999999999999")), "Quintillionaire"),
			false,
			"one under 1 Qi"
		)
		eq(has(Titles.earned(view(nil, nil, "1e18")), "Billionaire"), false, "garbage earns nothing")
		eq(has(Titles.earned(view(nil, nil, 0, { Pro = true })), "Professional"), true, "licence")
	end,
	["titles: band 3 titles"] = function()
		local got = Titles.earned(
			view(
				{ EyeHearts = 1 },
				{ GaleShard = true, TideRelic = true, Fulgurite = true },
				0,
				{ Hunter = true }
			)
		)
		for _, id in { "StormHunter", "EyeDiver", "ArtifactCollector" } do
			assert(has(got, id), id)
		end
		eq(
			has(Titles.earned(view(nil, { GaleShard = true, TideRelic = true })), "ArtifactCollector"),
			false,
			"two of three"
		)
	end,
	["bands: storm hunter licence needs rank, extractions and the industrial log"] = function()
		local base =
			{ Rank = 4, Extractions = 10, Coins = "4000000", Owned = false, Found = { Industrial = 4 } }
		eq(Bands.checkLicense("Hunter", base).Ok, true, "all met")
		local p = table.clone(base)
		p.Found = { Industrial = 3 }
		local r = Bands.checkLicense("Hunter", p)
		eq(r.Reason, "requirements", "three industrial kinds")
		eq(#r.Missing, 1, "only that one")
		p = table.clone(base)
		p.Found = nil
		eq(Bands.checkLicense("Hunter", p).Reason, "requirements", "no log at all")
		p = table.clone(base)
		p.Coins = "3999999"
		eq(Bands.checkLicense("Hunter", p).Reason, "short", "one coin short")
		local have, need = Bands.progressOf(Bands.Licenses.Hunter.Requirements[3], base)
		eq(have, 4, "progress have")
		eq(need, 4, "progress need")
	end,
	["bands: artifacts are a storm each, worth more than any industrial salvage"] = function()
		local storms = {}
		for _, a in Bands.Artifacts do
			assert(a.Value > Bands.Industrial[#Bands.Industrial].Value, a.Id .. " beats a Turbine Rotor")
			assert(not storms[a.Storm], "one per storm")
			storms[a.Storm] = true
		end
		eq(storms.Wind and storms.Flood and storms.Lightning, true, "all three storms")
		assert(
			Bands.StormHeart.Value > Bands.Artifacts[#Bands.Artifacts].Value * 10,
			"the Heart is the jackpot"
		)
		local found = Bands.foundByClass({ CopperSpool = true, Can = true, GaleShard = true }, {
			CopperSpool = { Class = "Industrial" },
			Can = {},
			GaleShard = { Class = "Artifact" },
		})
		eq(found.Industrial, 1, "industrial count")
		eq(found.Artifact, 1, "artifact count")
	end,
	["bands: harness protection rises and stays below total immunity"] = function()
		for i = 2, #Bands.Harness.Values do
			assert(Bands.Harness.Values[i] > Bands.Harness.Values[i - 1], "rises")
		end
		assert(Bands.Harness.Values[#Bands.Harness.Values] < 1, "never immune")
		eq(#Bands.Harness.Values, #Bands.Harness.Costs + 1, "a value per level")
	end,
	["titles: band 4 titles"] = function()
		local got = Titles.earned(view({ VaultsOpened = 1 }, { CrownJewels = true }, 0, { Heavy = true }))
		for _, id in { "HeavyHauler", "Safecracker", "CrownThief" } do
			assert(has(got, id), id)
		end
		eq(has(Titles.earned(view({ WreckLocks = 3 })), "Safecracker"), false, "locks alone aren't a vault")
	end,
	["bands: heavy licence needs the artifacts and a Storm Heart"] = function()
		local base = {
			Rank = 5,
			Extractions = 25,
			Coins = "1000000000",
			Owned = false,
			Found = { Artifact = 3 },
			Records = { EyeHearts = 1 },
		}
		eq(Bands.checkLicense("Heavy", base).Ok, true, "all met")
		local p = table.clone(base)
		p.Records = { EyeHearts = 0 }
		local r = Bands.checkLicense("Heavy", p)
		eq(r.Reason, "requirements", "no Heart")
		eq(r.Missing[1], "Deliver a Storm Heart", "named")
		p = table.clone(base)
		p.Coins = "999999999"
		eq(Bands.checkLicense("Heavy", p).Reason, "short", "one coin short of a billion")
		eq(Bands.bandOf({ Pro = true, Hunter = true, Heavy = true }), 4, "band 4")
	end,
	["bands: the vault outvalues the band below; bars grow with the crew and stop at the cap"] = function()
		assert(
			Bands.Vault.Strongbox.Value > Bands.Artifacts[#Bands.Artifacts].Value,
			"strongbox beats an artifact"
		)
		assert(Bands.Vault.BullionBar.Value > Bands.StormHeart.Value, "a bar beats the Heart")
		assert(Bands.Vault.CrownJewels.Value > Bands.Vault.BullionBar.Value * 5, "the jewels are the jackpot")
		eq(Bands.barsFor(1), Bands.Wreck.BarsBase + 1, "solo")
		eq(Bands.barsFor(0), Bands.Wreck.BarsBase, "nobody counted")
		eq(Bands.barsFor(50), Bands.Wreck.BarsMax, "capped")
		assert(Bands.Wreck.JewelChance > 0 and Bands.Wreck.JewelChance < 1, "real odds")
		assert(Bands.Wreck.ChargeRadius < Bands.Wreck.CutReach * 2, "a charge can be stepped out of")
		for i = 2, #Bands.Cutter.Values do
			assert(Bands.Cutter.Values[i] > Bands.Cutter.Values[i - 1], "cutter speeds rise")
		end
		eq(#Bands.Cutter.Values, #Bands.Cutter.Costs + 1, "a value per level")
	end,
	["titles: band 5 titles"] = function()
		local got = Titles.earned(view({ TitanCores = 1 }, { SingularityCore = true }, 0, { Legend = true }))
		for _, id in { "StormLegend", "TitanTamer", "Singularity" } do
			assert(has(got, id), id)
		end
	end,
	["bands: legend licence needs the vaults"] = function()
		local base = {
			Rank = 7,
			Extractions = 50,
			Coins = "20000000000",
			Owned = false,
			Found = { Vault = 2 },
			Records = { VaultsOpened = 3 },
		}
		eq(Bands.checkLicense("Legend", base).Ok, true, "all met")
		local p = table.clone(base)
		p.Records = { VaultsOpened = 2 }
		eq(Bands.checkLicense("Legend", p).Reason, "requirements", "two vaults")
		eq(Bands.bandOf({ Pro = true, Hunter = true, Heavy = true, Legend = true }), 5, "band 5")
	end,
	["bands: mythic odds are published, sum to one and are the real draw"] = function()
		local total = 0
		for _, m in Bands.Mythic do
			total += m.Odds
			assert(m.Value > Bands.Vault.CrownJewels.Value, m.Id .. " beats the Crown Jewels")
		end
		assert(math.abs(total - 1) < 1e-9, "odds sum to 1")
		-- The draw follows the odds exactly at the boundaries.
		eq(Bands.drawMythic(0).Id, "TitanCore", "lowest roll")
		eq(Bands.drawMythic(0.5999).Id, "TitanCore", "just under 60%")
		eq(Bands.drawMythic(0.6).Id, "PrismCore", "60%")
		eq(Bands.drawMythic(0.8999).Id, "PrismCore", "just under 90%")
		eq(Bands.drawMythic(0.9).Id, "SingularityCore", "top 10%")
		eq(Bands.drawMythic(0.99999).Id, "SingularityCore", "top roll")
		-- And over many even rolls the shares match.
		local n, counts = 10000, {}
		for i = 0, n - 1 do
			local id = Bands.drawMythic(i / n).Id
			counts[id] = (counts[id] or 0) + 1
		end
		eq(counts.TitanCore, 6000, "60%")
		eq(counts.PrismCore, 3000, "30%")
		eq(counts.SingularityCore, 1000, "10%")
		assert(Bands.Titan.InnerRadius < Bands.Titan.OuterRadius, "a ring to hold")
		eq(#Bands.Rig.Values, #Bands.Rig.Costs + 1, "a value per level")
		eq(#Bands.EventBonus, 5, "a bonus row per band")
	end,
	["bands: the titan's charge node is catchable and worth chasing"] = function()
		local T = Bands.Titan
		local nodeStudsPerSecond = T.NodeSpeed * T.NodeRadius
		assert(nodeStudsPerSecond < 20, "slower than a run (20)")
		assert(nodeStudsPerSecond > 4, "fast enough that you have to move")
		assert(T.NodeRadius - T.NodeHit > T.InnerRadius, "the node sits clear of the deadly core")
		assert(T.NodeRadius + T.NodeHit <= T.OuterRadius + 0.01, "and inside the ring")
		assert(T.RingRate < 0.5, "standing anywhere in the ring is much slower than the node")
		assert(T.InhaleWarn >= 1, "the inhale is telegraphed")
	end,
	["bands: wreck crews split up: more locks at once is faster for everyone"] = function()
		eq(Bands.crewBonus(0), 1, "nobody")
		eq(Bands.crewBonus(1), 1, "one lock: no bonus")
		assert(Bands.crewBonus(3) > Bands.crewBonus(2), "three locks beat two")
		-- Three players on three locks finish sooner than three on one lock (no stacking bonus).
		local W = Bands.Wreck
		local spread = W.CutSeconds / Bands.crewBonus(3) -- each lock, one cutter, bonus
		local stacked = W.CutSeconds / 3 * W.Locks -- one lock at a time, three cutters
		assert(spread < stacked, ("spread %.1fs vs stacked %.1fs"):format(spread, stacked))
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
		eq(
			Bands.eventBonus(99, "Pursuit", false),
			Bands.EventBonus[#Bands.EventBonus].Pursuit,
			"clamped to the top band"
		)
	end,
	["bands: industrial salvage outvalues town salvage, rarer is worth more"] = function()
		for i = 2, #Bands.Industrial do
			assert(Bands.Industrial[i].Value > Bands.Industrial[i - 1].Value, "rising value")
			assert(Bands.Industrial[i].Weight < Bands.Industrial[i - 1].Weight, "rarer")
		end
		assert(Bands.Industrial[1].Value > 140, "cheapest beats the best town Epic (140)")
	end,
}
