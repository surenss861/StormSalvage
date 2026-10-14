-- @file Wallet: migration, earning, spending and rollback safety
-- @domain qa
-- @status stable
-- @see [[Wallet.luau]]
local W = require("../src/shared/Wallet")
local B = require("../src/shared/BigMoney")

local function eq(a: any, b: any, what: string)
	if a ~= b then
		error(("%s: expected %s, got %s"):format(what, tostring(b), tostring(a)), 2)
	end
end

local function profile(coins: any, earned: any): any
	return { Coins = coins, Stats = { TotalEarned = earned, ItemsSold = 3 } }
end

-- RC10's DataService reconcile, as shipped: an invalid number becomes Money.clamp(x).
local function rc10Reconcile(d: any)
	local function valid(n: any)
		return type(n) == "number" and n == n and n >= 0 and n <= 1e15 and n % 1 == 0
	end
	local function clamp(n: any)
		if type(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge then
			return 0
		end
		return math.clamp(math.floor(n), 0, 1e15)
	end
	if not valid(d.Coins) then
		d.Coins = clamp(d.Coins)
	end
	if not valid(d.Stats.TotalEarned) then
		d.Stats.TotalEarned = clamp(d.Stats.TotalEarned)
	end
end

return {
	["wallet: schema 1 balances migrate exactly"] = function()
		local d = profile(38900, 45075)
		local r = W.load(d)
		eq(r.Migrated, true, "migrated")
		eq(W.cash(d), "38900", "cash")
		eq(W.lifetime(d), "45075", "lifetime")
		eq(d.Wallet.Schema, 2, "schema")
		eq(d.Coins, 38900, "mirror coins")
		eq(d.Stats.TotalEarned, 45075, "mirror earned")
		eq(d.Stats.ItemsSold, 3, "other stats untouched")
		eq(W.load(d).Migrated, false, "loading again is a no-op")
		eq(W.cash(d), "38900", "still exact")
	end,
	["wallet: the owner-scale profile and the old cap migrate exactly"] = function()
		local d = profile(3313, 3313)
		W.load(d)
		eq(W.cash(d), "3313", "LIVETEST profile size")
		d = profile(1e15, 1e15)
		W.load(d)
		eq(W.cash(d), "1000000000000000", "1 Qa (the RC10 cap)")
	end,
	["wallet: corrupt legacy values are kept and reported, never silently zeroed"] = function()
		local d = profile(0 / 0, -5)
		local r = W.load(d)
		eq(#r.Repaired, 2, "both reported")
		eq(W.cash(d), "0", "starts from 0")
		assert(d.Wallet.Repaired and #d.Wallet.Repaired == 2, "originals kept in the profile")
		assert(d.Wallet.Repaired[1]:find("nan") or d.Wallet.Repaired[1]:find("NaN"), d.Wallet.Repaired[1])
	end,
	["wallet: earn adds to cash and lifetime, exactly, past any old limit"] = function()
		local d = profile(0, 0)
		W.load(d)
		eq(W.earn(d, "1250000000000000000"), "1250000000000000000", "1.25 Qi")
		eq(W.cash(d), "1250000000000000000", "cash")
		eq(W.lifetime(d), "1250000000000000000", "lifetime")
		eq(d.Coins, 1e15, "mirror holds at the legacy cap")
		eq(W.earn(d, "1"), "1", "one more")
		eq(W.cash(d), "1250000000000000001", "exact to the unit")
		eq(W.earn(d, -5), "0", "negative refused")
		eq(W.earn(d, 0 / 0), "0", "NaN refused")
		eq(W.earn(d, "1.5"), "0", "fraction string refused")
	end,
	["wallet: earn stops at MAX and reports only what fit"] = function()
		local d = profile(0, 0)
		W.load(d)
		W.setCashForTest(d, B.sub(B.MAX, "10"))
		eq(W.earn(d, "25"), "10", "only the room left")
		eq(W.cash(d), B.MAX, "at MAX")
	end,
	["wallet: spend is exact and refuses overdrafts and bad costs"] = function()
		local d = profile(0, 0)
		W.load(d)
		W.earn(d, "1000000000000000000000") -- 1 Sx
		eq(W.spend(d, "500000000000000000000"), true, "spend 500 Qi")
		eq(W.cash(d), "500000000000000000000", "exactly 500 Qi left")
		eq(W.spend(d, "500000000000000000001"), false, "one over")
		eq(W.cash(d), "500000000000000000000", "unchanged")
		eq(W.spend(d, -1), false, "negative")
		eq(W.spend(d, "abc"), false, "garbage")
		eq(W.lifetime(d), "1000000000000000000000", "spending never lowers lifetime earnings")
	end,
	["wallet: deposits (coin packs) are cash, not earnings"] = function()
		local d = profile(100, 100)
		W.load(d)
		W.deposit(d, 300)
		eq(W.cash(d), "400", "cash")
		eq(W.lifetime(d), "100", "lifetime unchanged")
	end,
	["rollback: an older build's spending and earning are folded back in"] = function()
		local d = profile(10000, 20000)
		W.load(d)
		-- An RC10 server runs the profile: it spends 2,500 and earns 700 on the numbers.
		rc10Reconcile(d)
		d.Coins = d.Coins - 2500 + 700
		d.Stats.TotalEarned += 700
		local r = W.load(d)
		eq(W.cash(d), "8200", "10,000 - 2,500 + 700")
		eq(W.lifetime(d), "20700", "20,000 + 700")
		eq(r.AppliedCash, "-1800", "reported")
		eq(d.Coins, 8200, "mirror rewritten")
	end,
	["rollback: a balance past 1 Qa survives an older build intact"] = function()
		local d = profile(0, 0)
		W.load(d)
		W.earn(d, "5000000000000000000") -- 5 Qi
		-- RC10 sees 1 Qa (its own cap, valid to it) and spends 1,000 there.
		rc10Reconcile(d)
		eq(d.Coins, 1e15, "RC10 accepts the mirror unchanged")
		d.Coins -= 1000
		W.load(d)
		eq(W.cash(d), "4999999999999999000", "5 Qi - 1,000, exact")
	end,
	["rollback: an untouched profile comes back exactly"] = function()
		local d = profile(0, 0)
		W.load(d)
		W.earn(d, "123456789012345678901234567890")
		rc10Reconcile(d) -- an older build loads and saves without changing money
		W.load(d)
		eq(W.cash(d), "123456789012345678901234567890", "exact after a round trip")
	end,
	["wallet: a damaged wallet falls back to the legacy numbers, not zero"] = function()
		local d = profile(4200, 4200)
		d.Wallet = { Schema = 2, Cash = "12x", Lifetime = "5" }
		W.load(d)
		eq(W.cash(d), "4200", "rebuilt from the mirror")
	end,
	["wallet: many rapid grants add up exactly"] = function()
		local d = profile(0, 0)
		W.load(d)
		for _ = 1, 10000 do
			W.earn(d, "123456789123456789") -- far past 2^53 each time
		end
		eq(W.cash(d), "1234567891234567890000", "10,000 x 123456789123456789")
	end,
}
