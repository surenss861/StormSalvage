-- @file Restoring a saved profile to an older DataStore version, safely
-- @domain data
-- @status wip
-- @see [[RestorePlan.luau]]
-- @see [[V4-BIG-NUMBERS]]
-- An operator tool (Studio command bar in Edit, or a Studio QA run), never called by gameplay.
-- It reads the version to restore and the current profile, works out which purchases were
-- confirmed after that version (from the profile's own PurchaseId list) and what each granted
-- (from the purchase audit log + the fixed product table), and writes the restored profile in
-- ONE UpdateAsync: the plan is re-made inside the transform against whatever is stored at that
-- instant, so a purchase landing meanwhile is never lost or doubled.
--   ProfileRestore.versions(storeName, key, n)  -> the newest n versions (id, time)
--   ProfileRestore.run(storeName, key, source)  -> { Ok, Reason?, Reapplied, Cash, Lifetime }
--     source: a version id, or "premigration" (the exact pre-migration copy DataService keeps)
-- Refuses the production store: only "*_LIVETEST", "*_STUDIO" and "*_STUDIO_REHEARSAL" stores.
-- Requires no gameplay service, so it can be required from the Edit command bar.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RestorePlan = require(ReplicatedStorage.Shared.RestorePlan)
local Wallet = require(ReplicatedStorage.Shared.Wallet)

local ProfileRestore = {}

local LOCK_EXPIRY = Config.AutosaveSeconds * 3

local function allowed(storeName: string): boolean
	return storeName:match("_LIVETEST$") ~= nil
		or storeName:match("_STUDIO$") ~= nil
		or storeName:match("_STUDIO_REHEARSAL") ~= nil
end

-- Coins granted by a developer product: the real catalogue, and the Studio stand-in ids that
-- MonetizationService uses in QA (-1 = the 1,000-coin test pack, -100 - Order = catalogue packs).
local function coinsFor(productId: number): number?
	for _, def in Config.DevProducts do
		if def.Id ~= 0 and def.Id == productId then
			return def.Coins
		end
		if productId == -100 - def.Order then
			return def.Coins
		end
	end
	if productId == -1 then
		return 1000
	end
	return nil
end

function ProfileRestore.versions(
	storeName: string,
	key: string,
	n: number
): { { Version: string, Time: number } }
	assert(allowed(storeName), "refusing store " .. storeName)
	local store = DataStoreService:GetDataStore(storeName)
	local pages = store:ListVersionsAsync(key, Enum.SortDirection.Descending, nil, nil, n)
	local out = {}
	for _, info in pages:GetCurrentPage() do
		table.insert(out, { Version = info.Version, Time = info.CreatedTime })
	end
	return out
end

-- `source`: a DataStore version id of the key, or "premigration" for the exact copy DataService
-- saved before this build first migrated the profile (<store>_Backups, "premigration_<key>").
function ProfileRestore.run(storeName: string, key: string, source: string): { [string]: any }
	assert(allowed(storeName), "refusing store " .. storeName)
	assert(type(source) == "string" and source ~= "", 'need a version id or "premigration"')
	local store = DataStoreService:GetDataStore(storeName)
	local history = DataStoreService:GetDataStore(storeName .. "_Purchases")
	local old
	if source == "premigration" then
		local backup = DataStoreService:GetDataStore(storeName .. "_Backups"):GetAsync("premigration_" .. key)
		old = type(backup) == "table" and backup.Profile or nil
	else
		old = store:GetVersionAsync(key, source)
	end
	if type(old) ~= "table" then
		return { Ok = false, Reason = "source not found: " .. source }
	end
	-- What every purchase in the current profile granted, fetched now: a transform can't yield.
	local current = store:GetAsync(key)
	local grants: { [string]: number } = {}
	for _, id in
		(if type(current) == "table" and type(current.ProcessedReceipts) == "table"
			then current.ProcessedReceipts
			else {}) :: { string }
	do
		local record = history:GetAsync("purchase_" .. id)
		local coins = type(record) == "table" and coinsFor(record.ProductId)
		if coins then
			grants[id] = coins
		end
	end
	local result: RestorePlan.Result = { Ok = false, Reason = "not written", Reapplied = {} }
	store:UpdateAsync(key, function(now)
		result = RestorePlan.plan(now, old, os.time(), LOCK_EXPIRY, function(id)
			local coins = grants[id]
			if not coins then
				return nil -- unknown here (or bought after the pre-fetch): refuse, retry later
			end
			return function(d)
				Wallet.deposit(d, coins)
			end
		end, source)
		if not result.Ok then
			return nil
		end
		return result.Profile
	end)
	if not result.Ok then
		return { Ok = false, Reason = result.Reason }
	end
	local p = result.Profile :: any
	return {
		Ok = true,
		Reapplied = result.Reapplied,
		Cash = Wallet.cash(p),
		Lifetime = Wallet.lifetime(p),
		Receipts = #p.ProcessedReceipts,
	}
end

return ProfileRestore
