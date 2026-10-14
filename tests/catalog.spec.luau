-- @file The premium catalogue stays off, fixed, fair, and separate from earned prestige
-- @domain qa
-- @status stable
-- @see [[V4-CATALOG]]
local Config = require("../src/shared/Catalog")
local Bands = require("../src/shared/Bands")
local Progression = require("../src/shared/Progression")
local Titles = require("../src/shared/Titles")

local function eq(a: any, b: any, what: string)
	if a ~= b then
		error(("%s: expected %s, got %s"):format(what, tostring(b), tostring(a)), 2)
	end
end

local function gearTotal(costs: { number }): number
	local t = 0
	for _, c in costs do
		t += c
	end
	return t
end

return {
	["catalog: purchases are switched off and nothing is on sale in the repo"] = function()
		eq(Config.PurchasesEnabled, false, "master switch off")
		for key, def in Config.DevProducts do
			eq(def.Id, 0, "product " .. key .. " has no live id")
		end
		for key, def in Config.GamePasses do
			eq(def.Id, 0, "pass " .. key .. " has no live id")
		end
	end,
	["catalog: every coin pack is a fixed whole amount"] = function()
		for key, def in Config.DevProducts do
			assert(type(def.Coins) == "number" and def.Coins > 0 and def.Coins % 1 == 0, key .. " fixed")
			assert(def.Coins < 2 ^ 53, key .. " exact as a number")
		end
	end,
	["catalog: a band's pack never buys more than ~30% of that band's gear"] = function()
		local tracks = {
			[2] = gearTotal(Bands.Press.Costs),
			[3] = gearTotal(Bands.Harness.Costs),
			[4] = gearTotal(Bands.Cutter.Costs),
			[5] = gearTotal(Bands.Rig.Costs),
		}
		for key, def in Config.DevProducts do
			local band = def.MinBand
			if band and tracks[band] then
				assert(
					def.Coins <= tracks[band] * 0.31,
					("%s is %.0f%% of band %d gear"):format(key, def.Coins / tracks[band] * 100, band)
				)
			end
		end
	end,
	["catalog: supporter finishes are paid-only, never earned or sold for coins"] = function()
		for _, f in Progression.PremiumFinishes do
			eq(f.Paid, true, f.Id .. " marked paid")
			eq(f.Cost, 0, f.Id .. " adds no net worth")
			local pass = Config.GamePasses[f.Pass]
			assert(pass and pass.Finish == f.Id, f.Id .. " has its pass")
			local ok, why = Progression.canBuyFinish(f.Id, "999999999999999", 999999, {})
			eq(ok, false, f.Id .. " can't be bought with coins")
			eq(why, "unknown", "refused as not for sale")
			for _, earned in Progression.Finishes do
				assert(earned.Id ~= f.Id, "not also an earned finish")
			end
		end
	end,
	["catalog: no title can be bought"] = function()
		-- Every title is earned from records, licences, finds or lifetime earnings (never cash):
		-- a view with unlimited cash and nothing else earns nothing.
		local got = Titles.earned({ Records = {}, Found = {}, TotalEarned = 0, Licenses = {} })
		eq(#got, 0, "no titles from nothing")
	end,
}
