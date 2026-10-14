-- @file Player persistence with session-owned save locks
-- @domain data
-- @status stable
-- @see [[V3-PRODUCTION-AUDIT]]
-- @see [[Environment.luau]]
-- Player persistence with a simple session lock (prevents two servers writing the
-- same profile at once, which is how item/coin duplication usually happens).
-- Swap for ProfileStore later if you need more features; the API surface is small.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local SalvageLog = require(game:GetService("ReplicatedStorage").Shared.SalvageLog)
local Wallet = require(game:GetService("ReplicatedStorage").Shared.Wallet)
local Titles = require(game:GetService("ReplicatedStorage").Shared.Titles)

local DataService = {}

local LOCK_EXPIRY = Config.AutosaveSeconds * 3
local SESSION_ID = game.JobId ~= "" and game.JobId or HttpService:GenerateGUID(false)

local store: DataStore? = nil
-- V4 money migration: the untouched pre-migration (schema 1) profile is copied here once, the
-- first time this build migrates it, so it can be restored exactly (DataStore versions are kept
-- only about hourly, so "the version just before the migration" may not exist).
local backups: DataStore? = nil
-- One line at startup so a staging or live server's log shows which data it's using.
print(
	-- PlaceVersion tells which published build this server runs (servers keep their version until
	-- they shut down: a rehearsal checks this line, never assumes).
	("[Environment] %s (%s), place %d version %d, store %s"):format(
		tostring(Config.Environment),
		tostring(Config.EnvironmentReason),
		game.PlaceId,
		game.PlaceVersion,
		Config.DataStoreName or "NONE (nothing will save)"
	)
)
if Config.DataStoreName then
	pcall(function()
		store = DataStoreService:GetDataStore(Config.DataStoreName :: string)
		backups = DataStoreService:GetDataStore((Config.DataStoreName :: string) .. "_Backups")
	end)
else
	warn("[DataService] unknown environment (place " .. game.PlaceId .. "): progress will not be saved")
end

export type Data = {
	Version: number,
	Coins: number, -- legacy mirror only: the exact balance is Wallet.Cash (Wallet.luau)
	Upgrades: { [string]: number },
	Stats: { TotalEarned: number, ItemsSold: number, StormsSurvived: number },
	ProcessedReceipts: { string },
	BoostUntil: number,
	-- Added in V3 (Contracts + Reputation). Older profiles get these from reconcile; older
	-- code that loads a profile with them keeps them untouched (it saves whole tables).
	Rep: { XP: number },
	Contracts: { Active: { any }, Done: number, Pinned: string? },
	Cosmetics: { Owned: { [string]: boolean }, Plate: string },
	-- Added for the Supply Depot (Tools tab). Same reconcile/rollback rules as above.
	Tools: { Owned: { [string]: boolean } },
	-- V4 Storm Pursuit records.
	Records: { Extractions: number, BestExtract: number },
	-- V4 Salvage Log: kinds of salvage found at least once.
	Collection: { Found: { [string]: boolean }, Counts: { [string]: number } },
	-- V4 M3 (economy and status): licences held (the band follows from them) and earned titles.
	Licenses: { [string]: boolean },
	Titles: { Owned: { [string]: boolean }, Shown: string? },
	-- V4 big numbers (schema 2): exact cash and lifetime earnings, plus the legacy mirror record.
	Wallet: any,
	Lock: { Session: string, Time: number }?,
}

function DataService.default(): Data
	return {
		Version = 1,
		Coins = Config.StartingCoins,
		Upgrades = { Backpack = 0, Boots = 0, Armor = 0, Press = 0, Harness = 0 },
		Stats = { TotalEarned = 0, ItemsSold = 0, StormsSurvived = 0 },
		ProcessedReceipts = {},
		BoostUntil = 0,
		Rep = { XP = 0 },
		Contracts = { Active = {}, Done = 0 },
		Cosmetics = { Owned = { Cardboard = true }, Plate = "Cardboard" },
		Tools = { Owned = {} },
		Records = { Extractions = 0, BestExtract = 0 },
		Collection = { Found = {}, Counts = {} },
		Licenses = {},
		Titles = { Owned = {} },
	}
end

-- Fill in any fields added after a profile was first saved.
local function reconcile(data: any): Data
	local template = DataService.default()
	for k, v in template do
		if data[k] == nil then
			data[k] = v
		elseif type(v) == "table" and type(data[k]) == "table" and k ~= "ProcessedReceipts" then
			for k2, v2 in v do
				if data[k][k2] == nil then
					data[k][k2] = v2
				end
			end
		end
	end
	-- Salvage Log counts arrived in V4: kinds already found count as found once. Additive only.
	data.Collection = SalvageLog.reconcile(data.Collection)
	-- V4 M3: titles must be real and owned.
	data.Titles = Titles.reconcile(data.Titles)
	-- V4 big numbers: money lives in data.Wallet as exact strings (schema 2). Converts a schema-1
	-- profile exactly, folds in anything an older build did to the numeric mirror, and keeps
	-- Coins / Stats.TotalEarned as that mirror for older builds (Wallet.luau). Idempotent, so it
	-- is safe inside UpdateAsync transforms that may retry.
	local report = Wallet.load(data)
	if #report.Repaired > 0 then
		warn(
			"[DataService] corrupt legacy money kept in Wallet.Repaired:",
			table.concat(report.Repaired, ", ")
		)
	end
	if report.AppliedCash or report.AppliedLifetime then
		print(
			"[DataService] applied an older build's money changes:",
			report.AppliedCash or "",
			report.AppliedLifetime or ""
		)
	end
	if type(data.Licenses) ~= "table" then
		data.Licenses = {}
	end
	return data
end

-- Ownership for every write after load: the stored profile must carry *this* server's lock.
-- A missing lock counts as lost, not free: it means the profile was released (by this server
-- on leave, or by another server that took over and has since finished). Writing then would
-- overwrite newer progress and newer purchase grants with this server's stale copy.
--
-- The lock token is per *session*, not per server: "<server JobId>/<guid made at load>". If a
-- player leaves and rejoins the same server, the new session has a new token, so a write
-- still in flight from the old session (e.g. an autosave delayed by throttling) can't pass as
-- the new owner. Every write captures its session's token when it starts.
local tokens: { [Player]: string } = {}

local function ownedBy(old: any, token: string?): boolean
	return token ~= nil and old ~= nil and old.Lock ~= nil and old.Lock.Session == token
end

-- A lock left by an earlier session on this same server (its release failed): that session is
-- gone and its writes carry its own token, so it is safe to take over without waiting.
local function fromThisServer(lock: any): boolean
	return type(lock.Session) == "string" and lock.Session:sub(1, #SESSION_ID + 1) == SESSION_ID .. "/"
end

local function key(userId: number): string
	return "player_" .. userId
end

-- Returns (data, canSave). canSave=false means DataStores are unavailable, so the
-- player gets a temporary profile that is never written back.
function DataService.load(player: Player): (Data?, boolean)
	if not store then
		return DataService.default(), false
	end
	local token = SESSION_ID .. "/" .. HttpService:GenerateGUID(false)
	for attempt = 1, 6 do
		local locked = false
		local result: Data? = nil
		local preMigration: string? = nil
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(key(player.UserId), function(old)
				-- A schema-1 profile about to be migrated: keep an exact copy (as JSON, taken before
				-- reconcile touches it) for the backup written after this transaction.
				preMigration = nil
				if type(old) == "table" and old.Wallet == nil then
					-- Never let the backup break a load (a value JSON can't hold just skips it).
					local okJ, json = pcall(HttpService.JSONEncode, HttpService, old)
					preMigration = if okJ then json else nil
				end
				local data = reconcile(old or DataService.default())
				local now = os.time()
				local lock = data.Lock
				if lock and not fromThisServer(lock) and now - lock.Time < LOCK_EXPIRY then
					locked = true
					return nil -- abort write; another server owns this profile
				end
				data.Lock = { Session = token, Time = now }
				result = data
				return data
			end)
		end)
		if ok and result then
			tokens[player] = token
			if preMigration and backups then
				-- Once only: never overwrite an existing backup. A failed backup write doesn't block
				-- play (the profile is already safely migrated); it's logged for the operator.
				local okB, errB = pcall(function()
					(backups :: DataStore):UpdateAsync(
						"premigration_" .. key(player.UserId),
						function(existing)
							if existing ~= nil then
								return nil
							end
							return { Profile = HttpService:JSONDecode(preMigration :: string), At = os.time() }
						end
					)
				end)
				if not okB then
					warn("[DataService] pre-migration backup failed for", player.Name, errB)
				end
			end
			return result, true
		end
		if not ok then
			warn("[DataService] load failed for", player.Name, err)
			-- Studio without working API access (not enabled, or solo Play returning 401 "User is
			-- not authenticated"): play with a temporary profile instead of being kicked.
			if
				RunService:IsStudio()
				or tostring(err):find("StudioAccessToApisNotAllowed")
				or tostring(err):find("403")
			then
				return DataService.default(), false
			end
		elseif locked then
			warn("[DataService] profile locked by another server, retrying", player.Name)
		end
		if not player.Parent then
			return nil, false
		end
		task.wait(attempt * 2)
	end
	return nil, false
end

-- Studio QA fault injection (MonetizationService tests): the next N calls of an operation fail
-- as if the DataStore errored. Never set outside Studio.
local faults: { [string]: number } = {}
function DataService.failNextForTest(operation: string, count: number)
	if RunService:IsStudio() then
		faults[operation] = count
	end
end
local function injectedFailure(operation: string): boolean
	local n = faults[operation]
	if n and n > 0 then
		faults[operation] = n - 1
		return true
	end
	return false
end

-- Applies a developer-product grant to the *stored* profile and records its PurchaseId in the
-- same write, so the grant and its receipt are durable together before the live session ever
-- sees the reward. Returns (ok, alreadyGranted, lostLock).
--   ok=false            nothing was written; safe to retry the receipt later
--   alreadyGranted=true the stored profile already has this PurchaseId (no second grant)
function DataService.grantReceipt(
	player: Player,
	purchaseId: string,
	apply: (data: Data) -> ()
): (boolean, boolean, boolean)
	if not store then
		return false, false, false
	end
	if injectedFailure("grant") then
		return false, false, false
	end
	local token = tokens[player]
	local already, lostLock = false, false
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key(player.UserId), function(old)
			if not ownedBy(old, token) then
				lostLock = true
				return nil
			end
			local data = reconcile(old)
			if table.find(data.ProcessedReceipts, purchaseId) then
				already = true
				return nil -- nothing to write
			end
			apply(data)
			table.insert(data.ProcessedReceipts, purchaseId)
			data.Lock = { Session = token, Time = os.time() }
			return data
		end)
	end)
	if not ok then
		warn("[DataService] receipt grant failed for", player.Name, err)
		return false, false, false
	end
	return not lostLock, already, lostLock
end

-- Purchase audit log, one record per PurchaseId, written after the reward is saved in the
-- profile. Write-only: correctness comes from the profile, which keeps every PurchaseId it has
-- granted (never pruned) in the same UpdateAsync as the reward. Never read it to decide a grant.
local history: DataStore? = nil
if Config.DataStoreName then
	pcall(function()
		history = DataStoreService:GetDataStore((Config.DataStoreName :: string) .. "_Purchases")
	end)
end

function DataService.recordPurchase(purchaseId: string, userId: number, productId: number): boolean
	if not history then
		return false
	end
	if injectedFailure("historyWrite") then
		return false
	end
	local ok, err = pcall(function()
		(history :: DataStore):UpdateAsync("purchase_" .. purchaseId, function(old)
			return old or { UserId = userId, ProductId = productId, Time = os.time() }
		end)
	end)
	if not ok then
		warn("[DataService] purchase history write failed", purchaseId, err)
	end
	return ok
end

-- Returns (saved, lostLock). lostLock means another server now owns the profile, so this
-- session must never write it again.
function DataService.save(player: Player, data: Data, release: boolean): (boolean, boolean)
	if not store then
		return false, false
	end
	if injectedFailure("save") then
		return false, false
	end
	local token = tokens[player]
	local lostLock = false
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key(player.UserId), function(old)
			if not ownedBy(old, token) then
				lostLock = true
				return nil -- not ours any more (taken over or released): never overwrite it
			end
			lostLock = false
			local copy = table.clone(data)
			copy.Lock = if release then nil else { Session = token :: string, Time = os.time() }
			return copy
		end)
	end)
	if release then
		-- Leaving: this session never writes again, whether or not the release landed.
		tokens[player] = nil
	end
	if not ok then
		warn("[DataService] save failed for", player.Name, err)
	elseif lostLock then
		warn("[DataService] save skipped, another server owns the profile:", player.Name)
		return false, true
	end
	return ok, false
end

-- Studio QA only (rehearsal harness): point this copy of DataService at a disposable rehearsal
-- store, so lock, shutdown and receipt tests never touch a real profile. A clone of this module
-- required separately acts as a separate server (its own session id and lock tokens).
function DataService.useStoreForTest(name: string)
	assert(RunService:IsStudio(), "Studio only")
	assert(name:match("^StormSalvage_v1_STUDIO_REHEARSAL") ~= nil, "rehearsal stores only")
	store = DataStoreService:GetDataStore(name)
	history = DataStoreService:GetDataStore(name .. "_Purchases")
	backups = DataStoreService:GetDataStore(name .. "_Backups")
end

function DataService.storeNameForTest(): string?
	return if store then (store :: DataStore).Name else nil
end

function DataService.lockExpiry(): number
	return LOCK_EXPIRY
end

return DataService
