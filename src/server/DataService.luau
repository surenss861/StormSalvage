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

local DataService = {}

local LOCK_EXPIRY = Config.AutosaveSeconds * 3
local SESSION_ID = game.JobId ~= "" and game.JobId or HttpService:GenerateGUID(false)

local store: DataStore? = nil
-- One line at startup so a staging or live server's log shows which data it's using.
print(
	("[Environment] %s (%s), place %d, store %s"):format(
		tostring(Config.Environment),
		tostring(Config.EnvironmentReason),
		game.PlaceId,
		Config.DataStoreName or "NONE (nothing will save)"
	)
)
if Config.DataStoreName then
	pcall(function()
		store = DataStoreService:GetDataStore(Config.DataStoreName :: string)
	end)
else
	warn("[DataService] unknown environment (place " .. game.PlaceId .. "): progress will not be saved")
end

export type Data = {
	Version: number,
	Coins: number,
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
	Lock: { Session: string, Time: number }?,
}

function DataService.default(): Data
	return {
		Version = 1,
		Coins = Config.StartingCoins,
		Upgrades = { Backpack = 0, Boots = 0, Armor = 0 },
		Stats = { TotalEarned = 0, ItemsSold = 0, StormsSurvived = 0 },
		ProcessedReceipts = {},
		BoostUntil = 0,
		Rep = { XP = 0 },
		Contracts = { Active = {}, Done = 0 },
		Cosmetics = { Owned = { Cardboard = true }, Plate = "Cardboard" },
		Tools = { Owned = {} },
		Records = { Extractions = 0, BestExtract = 0 },
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
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(key(player.UserId), function(old)
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

return DataService
