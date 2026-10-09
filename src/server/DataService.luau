-- Player persistence with a simple session lock (prevents two servers writing the
-- same profile at once, which is how item/coin duplication usually happens).
-- Swap for ProfileStore later if you need more features; the API surface is small.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local DataService = {}

local LOCK_EXPIRY = Config.AutosaveSeconds * 3
local SESSION_ID = game.JobId ~= "" and game.JobId or HttpService:GenerateGUID(false)

local store: DataStore? = nil
pcall(function()
	store = DataStoreService:GetDataStore(Config.DataStoreName)
end)

export type Data = {
	Version: number,
	Coins: number,
	Upgrades: { [string]: number },
	Stats: { TotalEarned: number, ItemsSold: number, StormsSurvived: number },
	ProcessedReceipts: { string },
	BoostUntil: number,
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

local function key(userId: number): string
	return "player_" .. userId
end

-- Returns (data, canSave). canSave=false means DataStores are unavailable, so the
-- player gets a temporary profile that is never written back.
function DataService.load(player: Player): (Data?, boolean)
	if not store then
		return DataService.default(), false
	end
	for attempt = 1, 6 do
		local locked = false
		local result: Data? = nil
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(key(player.UserId), function(old)
				local data = reconcile(old or DataService.default())
				local now = os.time()
				if data.Lock and data.Lock.Session ~= SESSION_ID and now - data.Lock.Time < LOCK_EXPIRY then
					locked = true
					return nil -- abort write; another server owns this profile
				end
				data.Lock = { Session = SESSION_ID, Time = now }
				result = data
				return data
			end)
		end)
		if ok and result then
			return result, true
		end
		if not ok then
			warn("[DataService] load failed for", player.Name, err)
			-- Studio without API access enabled: play with a temporary profile.
			if tostring(err):find("StudioAccessToApisNotAllowed") or tostring(err):find("403") then
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

-- Returns (saved, lostLock). lostLock means another server now owns the profile, so this
-- session must never write it again.
function DataService.save(player: Player, data: Data, release: boolean): (boolean, boolean)
	if not store then
		return false, false
	end
	local lostLock = false
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key(player.UserId), function(old)
			if old and old.Lock and old.Lock.Session ~= SESSION_ID then
				lostLock = true
				return nil -- we lost the lock; never overwrite another server's data
			end
			lostLock = false
			local copy = table.clone(data)
			copy.Lock = if release then nil else { Session = SESSION_ID, Time = os.time() }
			return copy
		end)
	end)
	if not ok then
		warn("[DataService] save failed for", player.Name, err)
	elseif lostLock then
		warn("[DataService] save skipped, another server owns the profile:", player.Name)
		return false, true
	end
	return ok, false
end

return DataService
