-- Lightweight per-storm measurements for balancing: damage by storm, deaths, time exposed
-- vs sheltered, survival, salvage and Storm Cores collected, coins sold, and whether a
-- player stuck around for the next storm. One summary line is printed per storm; recent
-- storms are kept in memory for the Studio debug "stats" command. Nothing is saved.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local StormStats = {}

export type PlayerStats = {
	Damage: number,
	Deaths: number,
	ExposedSeconds: number,
	ShelteredSeconds: number,
	TownSeconds: number,
	Survived: boolean,
	Salvage: number,
	Cores: number,
	SoldCoins: number,
	PlayedNextStorm: boolean?, -- filled in when the following storm ends
}

export type StormRecord = {
	Storm: string,
	Index: number,
	Players: { [string]: PlayerStats },
}

local HISTORY = 20
local history: { StormRecord } = {}
local current: StormRecord? = nil
local stormIndex = 0

local function entry(player: Player): PlayerStats?
	if not current then
		return nil
	end
	local stats = current.Players[player.Name]
	if not stats then
		stats = {
			Damage = 0,
			Deaths = 0,
			ExposedSeconds = 0,
			ShelteredSeconds = 0,
			TownSeconds = 0,
			Survived = false,
			Salvage = 0,
			Cores = 0,
			SoldCoins = 0,
		}
		current.Players[player.Name] = stats
	end
	return stats
end

function StormStats.beginStorm(storm: string)
	stormIndex += 1
	current = { Storm = storm, Index = stormIndex, Players = {} }
	for _, player in Players:GetPlayers() do
		entry(player)
	end
end

function StormStats.damage(player: Player, amount: number)
	local stats = entry(player)
	if stats and amount > 0 then
		stats.Damage += amount
	end
end

function StormStats.died(player: Player)
	local stats = entry(player)
	if stats then
		stats.Deaths += 1
	end
end

-- Called once per second for each living player while a storm runs.
function StormStats.sample(player: Player, inTown: boolean, sheltered: boolean)
	local stats = entry(player)
	if not stats or not inTown then
		return
	end
	stats.TownSeconds += 1
	if sheltered then
		stats.ShelteredSeconds += 1
	else
		stats.ExposedSeconds += 1
	end
end

function StormStats.collected(player: Player, lootId: string)
	local stats = entry(player)
	if stats then
		stats.Salvage += 1
		if lootId == "StormCore" then
			stats.Cores += 1
		end
	end
end

function StormStats.sold(player: Player, coins: number)
	local stats = entry(player)
	if stats then
		stats.SoldCoins += coins
	end
end

function StormStats.survived(player: Player)
	local stats = entry(player)
	if stats then
		stats.Survived = true
	end
end

-- Prints the storm's summary. A record covers one storm plus the aftermath and calm after
-- it (salvage and sales keep counting) until the next storm begins, so a run's haul is
-- credited to the storm it was gathered around.
function StormStats.endStorm()
	local record = current
	if not record then
		return
	end
	local previous = history[#history]
	if previous then
		for name, stats in previous.Players do
			local now = record.Players[name]
			stats.PlayedNextStorm = now ~= nil and now.TownSeconds >= 5
		end
	end
	table.insert(history, record)
	while #history > HISTORY do
		table.remove(history, 1)
	end
	local players, deaths, damage, survivors = 0, 0, 0, 0
	for _, stats in record.Players do
		players += 1
		deaths += stats.Deaths
		damage += stats.Damage
		survivors += if stats.Survived then 1 else 0
	end
	print(
		("[StormStats] #%d %s: %d players, %d survived in town, %d deaths, %.0f damage | %s"):format(
			record.Index,
			record.Storm,
			players,
			survivors,
			deaths,
			damage,
			HttpService:JSONEncode(record.Players)
		)
	)
end

function StormStats.history(): { StormRecord }
	return history
end

return StormStats
