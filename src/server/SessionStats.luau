-- @file First-session analytics
-- @domain qa
-- @status stable
-- First-session progression measurements, from the moment a player joins: time to first
-- pickup, sale, upgrade and survived storm; every salvage trip (coins, items by rarity, how
-- long the walk back to the Scrap Buyer took); deaths before the first upgrade; and whether
-- they went out again after selling. In memory only: one summary line is printed when a
-- player leaves, and the Studio debug command "session" returns the live report.
--
-- A "trip" starts with the first pickup after a sale (or after joining) and ends at the
-- next sale. Return time is from the trip's last pickup to the sale.

local AnalyticsService = game:GetService("AnalyticsService")
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

-- Roblox analytics (Creator Hub dashboards). Only the existing journey milestones, no personal
-- data beyond what Roblox attaches to every event. Failures never affect gameplay.
local STEPS = { Joined = 1, FirstPickup = 2, FirstSale = 3, FirstUpgrade = 4, FirstStormSurvived = 5 }
local function funnel(player: Player, step: string)
	pcall(AnalyticsService.LogOnboardingFunnelStepEvent, AnalyticsService, player, STEPS[step], step)
end
local function event(player: Player, name: string, value: number?)
	pcall(AnalyticsService.LogCustomEvent, AnalyticsService, player, name, value or 1)
end
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
	funnel(player, "Joined")
end

function SessionStats.collected(player: Player, lootId: string)
	local report = reports[player]
	local def = Config.Loot[lootId]
	if not report or not def then
		return
	end
	local t = since(report)
	if not report.FirstPickup then
		funnel(player, "FirstPickup")
	end
	report.FirstPickup = report.FirstPickup or t
	if lootId == "StormCore" then
		event(player, "StormCoreCollected")
	end
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
	event(player, "BagDropped")
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
	if not report.FirstSale then
		funnel(player, "FirstSale")
	end
	event(player, "SaleCoins", coins)
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
	if not report.FirstUpgrade then
		funnel(player, "FirstUpgrade")
	end
	event(player, "Upgrade_" .. upgradeId, level)
	report.FirstUpgrade = report.FirstUpgrade or since(report)
	table.insert(report.Upgrades, ("%s %d @%ss"):format(upgradeId, level, tostring(since(report))))
end

function SessionStats.died(player: Player)
	local report = reports[player]
	if not report then
		return
	end
	report.Deaths += 1
	event(player, "Death")
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
		if not report.FirstStormSurvived then
			funnel(player, "FirstStormSurvived")
		end
		event(player, "StormSurvived")
		report.FirstStormSurvived = report.FirstStormSurvived or since(report)
	end
end

-- A completed Robux purchase (after the reward is saved), for the Creator Hub dashboards.
function SessionStats.purchased(player: Player, key: string)
	event(player, "Purchase_" .. key, 1)
end

-- Client diagnostics (ViewHealth): a fixed set of kinds, at most one per kind per player per
-- minute. Recorded for QA only; nothing in the game acts on it.
local DIAG_KINDS = { NoCamera = true, CameraType = true, Subject = true, Distance = true }
local lastDiag: { [Player]: { [string]: number } } = {}
function SessionStats.clientDiag(player: Player, kind: unknown, value: unknown)
	if type(kind) ~= "string" or not DIAG_KINDS[kind] then
		return
	end
	local number = if type(value) == "number" and value == value
		then math.clamp(math.floor(value), -1, 100000)
		else -1
	local seen = lastDiag[player] or {}
	lastDiag[player] = seen
	if seen[kind] and os.clock() - seen[kind] < 60 then
		return
	end
	seen[kind] = os.clock()
	warn(("[ClientDiag] %s view lost: %s (%d)"):format(player.Name, kind, number))
	event(player, "ViewLost_" .. kind, 1)
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
		lastDiag[player] = nil
	end)
	local Remotes = require(game:GetService("ReplicatedStorage").Shared.Remotes)
	Remotes.get("ClientDiag").OnServerEvent:Connect(SessionStats.clientDiag)
end

return SessionStats
