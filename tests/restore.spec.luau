-- @file Restoring an older profile version: purchases kept exactly once, locks, migration
-- @domain qa
-- @status stable
-- @see [[RestorePlan.luau]]
local R = require("../src/shared/RestorePlan")
local W = require("../src/shared/Wallet")

local function eq(a: any, b: any, what: string)
	if a ~= b then
		error(("%s: expected %s, got %s"):format(what, tostring(b), tostring(a)), 2)
	end
end

local EXPIRY = 360
local NOW = 1000000

-- A coin pack of 1,000 (fixed per product), the way MonetizationService applies it.
local function pack(id: string): ((any) -> ())?
	if id:sub(1, 4) == "pack" then
		return function(d)
			W.deposit(d, 1000)
		end
	end
	return nil
end

local function profile(cash: string, receipts: { string }, lockTime: number?): any
	local d =
		{ Coins = 0, Stats = { TotalEarned = 0 }, ProcessedReceipts = receipts, Upgrades = { Press = 1 } }
	W.load(d)
	W.setCashForTest(d, cash)
	if lockTime then
		d.Lock = { Session = "server/x", Time = lockTime }
	end
	return d
end

return {
	["restore: purchases confirmed after the old version are re-applied once"] = function()
		local old = profile("5000", { "pack-1" })
		local current = profile("90000", { "pack-1", "pack-2", "pack-3" })
		local r = R.plan(current, old, NOW, EXPIRY, pack, "v-old")
		eq(r.Ok, true, "ok")
		eq(#r.Reapplied, 2, "two re-applied")
		eq(W.cash(r.Profile), "7000", "old 5,000 + two packs")
		eq(#r.Profile.ProcessedReceipts, 3, "all three recorded, none twice")
		eq(r.Profile.Lock, nil, "lock cleared")
		eq(r.Profile.Restored.From, "v-old", "labelled")
		-- Restoring the result again from itself changes nothing (no double grants).
		local again = R.plan(r.Profile, r.Profile, NOW, EXPIRY, pack, "again")
		eq(#again.Reapplied, 0, "idempotent")
		eq(W.cash(again.Profile), "7000", "same cash")
	end,
	["restore: refused while the profile is in use"] = function()
		local r = R.plan(profile("1", {}, NOW - 10), profile("1", {}), NOW, EXPIRY, pack, "x")
		eq(r.Ok, false, "live lock")
		local ok = R.plan(profile("1", {}, NOW - EXPIRY - 1), profile("1", {}), NOW, EXPIRY, pack, "x")
		eq(ok.Ok, true, "expired lock is fine")
	end,
	["restore: an unknown purchase stops it"] = function()
		local r = R.plan(profile("1", { "mystery-9" }), profile("1", {}), NOW, EXPIRY, pack, "x")
		eq(r.Ok, false, "refused")
		assert(r.Reason and r.Reason:find("mystery%-9"), tostring(r.Reason))
	end,
	["restore: a pre-migration (schema 1) version migrates exactly"] = function()
		local old = { Coins = 38900, Stats = { TotalEarned = 45075 }, ProcessedReceipts = {} }
		local current = profile("5000000000000000000", { "pack-7" })
		local r = R.plan(current, old, NOW, EXPIRY, pack, "pre-migration")
		eq(r.Ok, true, "ok")
		eq(W.cash(r.Profile), "39900", "38,900 + the pack bought since")
		eq(W.lifetime(r.Profile), "45075", "lifetime exact (packs aren't earnings)")
		eq(r.Profile.Wallet.Schema, 2, "schema 2")
	end,
	["restore: the old version is not modified"] = function()
		local old = profile("5000", {})
		local current = profile("1", { "pack-1" })
		R.plan(current, old, NOW, EXPIRY, pack, "x")
		eq(W.cash(old), "5000", "old untouched")
		eq(#old.ProcessedReceipts, 0, "old receipts untouched")
	end,
}
