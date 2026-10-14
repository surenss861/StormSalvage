--!strict
-- @file Restoring an older saved profile without duplicating or losing purchases (pure, tested)
-- @domain data
-- @status wip
-- @tested-by [[restore.spec.luau]]
-- @see [[V4-BIG-NUMBERS]]
-- Keeping an old DataStore version is not the same as restoring it. A restore here means: take
-- the profile as it was at an older version, and make it safe to load and play:
--   * Purchases are never lost or doubled. Every PurchaseId the CURRENT profile has granted but
--     the old one hasn't is re-applied (its product's fixed grant) and recorded, so the restored
--     profile owns exactly the purchases that were confirmed. PurchaseIds are never removed.
--     A PurchaseId whose product can't be identified stops the restore (fix it by hand).
--   * Money is exact: the old version is migrated to the current wallet schema (Wallet.load),
--     then purchase grants go through Wallet like any other.
--   * The session lock is cleared, and a restore is refused while the current profile holds a
--     live lock (the player must be offline, or the lock expired).
--   * Gameplay progress made after the old version (sales, upgrades, records) is gone: that is
--     what restoring means. Use it for corruption or a bad migration, never casually.
-- Pure: no Roblox APIs, so `lune` tests it. The caller does the DataStore reads and the write.

local Wallet = if script then require(script.Parent.Wallet) else (require :: any)("./Wallet")

local RestorePlan = {}

export type Result = {
	Ok: boolean,
	Reason: string?,
	Profile: any?,
	Reapplied: { string },
}

local function deepCopy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = deepCopy(x)
	end
	return out
end

-- `current`: the profile as stored now. `old`: the profile at the version to restore.
-- `now`, `lockExpiry`: seconds (os.time) and the lock lifetime. `applyFor(purchaseId)` returns
-- the grant function for that purchase's product (from the purchase audit log and the product
-- table), or nil if unknown. `label` is recorded in the restored profile.
function RestorePlan.plan(
	current: any,
	old: any,
	now: number,
	lockExpiry: number,
	applyFor: (string) -> ((any) -> ())?,
	label: string
): Result
	if type(old) ~= "table" then
		return { Ok = false, Reason = "no old version", Reapplied = {} }
	end
	local lock = type(current) == "table" and current.Lock
	if type(lock) == "table" and type(lock.Time) == "number" and now - lock.Time < lockExpiry then
		return { Ok = false, Reason = "profile is in use (live lock)", Reapplied = {} }
	end
	local restored = deepCopy(old)
	if type(restored.Stats) ~= "table" then
		restored.Stats = {}
	end
	Wallet.load(restored)
	if type(restored.ProcessedReceipts) ~= "table" then
		restored.ProcessedReceipts = {}
	end
	local have: { [string]: boolean } = {}
	for _, id in restored.ProcessedReceipts do
		have[id] = true
	end
	local reapplied = {}
	for _, id in
		(if type(current) == "table" and type(current.ProcessedReceipts) == "table"
			then current.ProcessedReceipts
			else {}) :: { string }
	do
		if not have[id] then
			local apply = applyFor(id)
			if not apply then
				return { Ok = false, Reason = "unknown product for purchase " .. tostring(id), Reapplied = {} }
			end
			apply(restored)
			table.insert(restored.ProcessedReceipts, id)
			have[id] = true
			table.insert(reapplied, id)
		end
	end
	restored.Lock = nil
	restored.Restored = { From = label, At = now, Reapplied = #reapplied }
	return { Ok = true, Profile = restored, Reapplied = reapplied }
end

return RestorePlan
