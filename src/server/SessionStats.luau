-- First-session progression measurements, from the moment a player joins: time to first
-- pickup, sale, upgrade and survived storm; every salvage trip (coins, items by rarity, how
-- long the walk back to the Scrap Buyer took); deaths before the first upgrade; and whether
-- they went out again after selling. In memory only: one summary line is printed when a
-- player leaves, and the Studio debug command "session" returns the live report.
--
-- A "trip" starts with the first pickup after a sale (or after joining) and ends at the
-- next sale. Return time is from the trip's last pickup to the sale.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local SessionStats = {}

export type Trip = {
	StartedAt: number, -- seconds since join
	SoldAt: number?,
	Items: number,
	Coins: number,
	ReturnSeconds: number?,
	Rarities: { [string]: number },
	HadCore: boolean,
}

export type Report = {
	JoinedAt: number, -- os.clock()
	FirstPickup: number?,
	FirstSale: number?,
	FirstUpgrade: number?,
	FirstStormSurvived: number?,
	Deaths: number,
	DeathsBeforeFirstUpgrade: number,
	Pickups: { [string]: number }, -- by rarity
	Upgrades: { string },
	Trips: { Trip },
	WentOutAgain: boolean, -- picked something up after their first sale
	StormsSeen: number,
}

local reports: { [Player]: Report } = {}
local lastPickupAt: { [Player]: number } = {}

local function since(report: Report): number
	return math.floor((os.clock() - report.JoinedAt) * 10 + 0.5) / 10
end

local function currentTrip(report: Report): Trip?
	local trip = report.Trips[#report.Trips]
	if trip and not trip.SoldAt then
		return trip
	end
	return nil
end

function SessionStats.joined(player: Player)
	reports[player] = {
		JoinedAt = os.clock(),
		Deaths = 0,
		DeathsBeforeFirstUpgrade = 0,
		Pickups = {},
		Upgrades = {},
		Trips = {},
		WentOutAgain = false,
		StormsSeen = 0,
	}
end

function SessionStats.collected(player: Player, lootId: string)
	local report = reports[player]
	local def = Config.Loot[lootId]
	if not report or not def then
		return
	end
	local t = since(report)
	report.FirstPickup = report.FirstPickup or t
	report.Pickups[def.Rarity] = (report.Pickups[def.Rarity] or 0) + 1
	if report.FirstSale then
		report.WentOutAgain = true
	end
	local trip = currentTrip(report)
	if not trip then
		trip = { StartedAt = t, Items = 0, Coins = 0, Rarities = {}, HadCore = false }
		table.insert(report.Trips, trip)
	end
	local active = trip :: Trip
	active.Items += 1
	active.Rarities[def.Rarity] = (active.Rarities[def.Rarity] or 0) + 1
	active.HadCore = active.HadCore or lootId == "StormCore"
	lastPickupAt[player] = os.clock()
end

-- Dropping the bag on death ends the trip without a sale.
function SessionStats.lostBag(player: Player)
	local report = reports[player]
	local trip = report and currentTrip(report)
	if trip then
		trip.SoldAt = since(report :: Report)
		trip.Coins = 0
		trip.ReturnSeconds = nil
	end
end

function SessionStats.sold(player: Player, coins: number)
	local report = reports[player]
	if not report then
		return
	end
	local t = since(report)
	report.FirstSale = report.FirstSale or t
	local trip = currentTrip(report)
	if trip then
		trip.SoldAt = t
		trip.Coins = coins
		local last = lastPickupAt[player]
		trip.ReturnSeconds = last and math.floor((os.clock() - last) * 10 + 0.5) / 10 or nil
	end
end

function SessionStats.upgraded(player: Player, upgradeId: string, level: number)
	local report = reports[player]
	if not report then
		return
	end
	report.FirstUpgrade = report.FirstUpgrade or since(report)
	table.insert(report.Upgrades, ("%s %d @%ss"):format(upgradeId, level, tostring(since(report))))
end

function SessionStats.died(player: Player)
	local report = reports[player]
	if not report then
		return
	end
	report.Deaths += 1
	if not report.FirstUpgrade then
		report.DeathsBeforeFirstUpgrade += 1
	end
end

function SessionStats.stormStarted()
	for _, report in reports do
		report.StormsSeen += 1
	end
end

function SessionStats.survivedStorm(player: Player)
	local report = reports[player]
	if report then
		report.FirstStormSurvived = report.FirstStormSurvived or since(report)
	end
end

function SessionStats.report(player: Player): Report?
	return reports[player]
end

function SessionStats.all(): { [string]: Report }
	local out = {}
	for player, report in reports do
		out[player.Name] = report
	end
	return out
end

function SessionStats.init()
	Players.PlayerRemoving:Connect(function(player)
		local report = reports[player]
		if report then
			print(
				("[SessionStats] %s after %ds: %s"):format(
					player.Name,
					math.floor(os.clock() - report.JoinedAt),
					HttpService:JSONEncode(report)
				)
			)
		end
		reports[player] = nil
		lastPickupAt[player] = nil
	end)
end

return SessionStats
