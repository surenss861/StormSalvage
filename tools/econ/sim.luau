-- @file V4 economy simulation: progression curves and milestone times
-- @domain salvage-economy
-- @status wip
-- @see [[V4-ECONOMY]]
-- @see [[Bands.luau]]
-- `lune run tools/econ/sim` prints milestone times for the candidate progression curves.
--
-- The model is a simple, deterministic engaged player, calibrated to Studio and playtest data:
--   * Salvage trips: carry `capacity` items of the band's average value; a trip takes
--     0.75 min plus 0.2 min per item (walk, search, grab, walk back, sell). Measured V3 baseline:
--     about 84 coins/min with a small bag and no events (V3-MONETIZATION).
--   * Events: one per 2.45-min storm cycle; the player extracts half of them (Studio runner and
--     M1 notes); a win pays the band's extraction bonus plus the prize's sale value.
--   * Storm Cores: 0.6 grabbed per cycle at band 1 values.
--   * Spending: greedy. The licence first when its requirements are met and it's affordable,
--     else the cheapest gear step that raises income. Cosmetics are not bought (a pure-income
--     player is the fastest case; real players are slower).
-- Bands 1-2 use the real tables (src/shared/Bands.luau); bands 3-5 are design extrapolations
-- with the same structure. These are estimates to check against real play, not promises.

local Bands = require("../../src/shared/Bands")

local CYCLE_MIN = 2.45
local EXTRACT_RATE = 0.5
local MILESTONES = { 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9, 1e10, 1e12 }

type Band = {
	Name: string,
	LicenseCost: number, -- coins to enter this band (band 1: 0)
	RequireMinutes: number, -- earliest minute the licence's accomplishment can be met
	AvgItem: number, -- average sale value of an item picked in this band
	EventBonus: number, -- extraction bonus per successful event
	PrizeValue: number, -- average prize sale value (cores) per successful event
	Gear: { { Cost: number, Factor: number } }, -- this band's sale-multiplier track (cumulative factor)
}

type Curve = { Name: string, Note: string, Bands: { Band } }

-- Band 1 is today's game in every curve: real values (Config.Loot, Config.Upgrades.Backpack).
local BACKPACK = { Costs = { 50, 150, 400, 1000, 2500 }, Values = { 3, 5, 7, 10, 14, 20 } }
local BAND1: Band = {
	Name = "1 Scrap Rookie",
	LicenseCost = 0,
	RequireMinutes = 0,
	AvgItem = 14, -- weighted town pool average (Can 2 ... Jukebox 140)
	EventBonus = 150,
	PrizeValue = 0.85 * 175 + 0.15 * 600, -- Storm Core or Golden (15%)
	Gear = {},
}

local function geometric(
	first: number,
	ratio: number,
	factors: { number }
): { { Cost: number, Factor: number } }
	local out = {}
	local cost = first
	for _, f in factors do
		table.insert(out, { Cost = math.floor(cost), Factor = f })
		cost *= ratio
	end
	return out
end

-- Bands 3-5 from band 2's shape: each next band's items are worth `jump` times more, its gear
-- costs scale the same way, and its licence costs `licenseMinutes` of the previous band's peak
-- income. Requirements arrive at `reqMinutes`.
local NAMES = { "3 Storm Hunter", "4 Salvage Magnate", "5 Storm Legend" }
local function extrapolate(
	last: Band,
	from: number,
	jump: number,
	licenseMinutes: number,
	reqMinutes: { number }
): { Band }
	local out = {}
	local prev = last
	for i = from, 3 do
		local names = NAMES
		local gear = {}
		for _, g in prev.Gear do
			table.insert(gear, { Cost = g.Cost * jump, Factor = g.Factor })
		end
		local peak = prev.AvgItem * 20 * prev.Gear[#prev.Gear].Factor / (0.75 + 0.2 * 20)
		local b: Band = {
			Name = names[i],
			LicenseCost = math.floor(peak * licenseMinutes),
			RequireMinutes = reqMinutes[i],
			AvgItem = prev.AvgItem * jump,
			EventBonus = prev.EventBonus * jump,
			PrizeValue = prev.PrizeValue * jump,
			Gear = gear,
		}
		table.insert(out, b)
		prev = b
	end
	return out
end

-- `built`: the bands implemented in Bands.luau (from band 2); the rest are extrapolated.
local function curveFrom(
	name: string,
	note: string,
	built: Band | { Band },
	jump: number,
	licenseMinutes: number,
	req: { number }
): Curve
	local list: { Band } = if (built :: any).Name then { built :: Band } else built :: { Band }
	local bands = { BAND1 }
	for _, b in list do
		table.insert(bands, b)
	end
	for _, b in extrapolate(list[#list], #list, jump, licenseMinutes, req) do
		table.insert(bands, b)
	end
	return { Name = name, Note = note, Bands = bands }
end

-- A: the original V4-ECONOMY draft (first million at about 10 h).
local A = curveFrom("A original", "licence 75K at 100K lifetime; band 2 items ~10x band 1", {
	Name = "2 Professional",
	LicenseCost = 75000,
	RequireMinutes = 60,
	AvgItem = 140,
	EventBonus = 1500,
	PrizeValue = 1500,
	Gear = geometric(20000, 2.2, { 1.25, 1.5, 2, 2.5, 3, 4, 5, 6 }),
}, 12, 60, { 600, 1500, 3000 })

-- B: a faster first million (licence 25K, band 2 items ~40x band 1).
local B = curveFrom("B faster", "licence 25K; band 2 items ~40x band 1", {
	Name = "2 Professional",
	LicenseCost = 25000,
	RequireMinutes = 30,
	AvgItem = 560,
	EventBonus = 3000,
	PrizeValue = 279,
	Gear = geometric(25000, 2.3, { 1.25, 1.5, 2, 2.5, 3, 4, 5, 6 }),
}, 15, 90, { 600, 1800, 4200 })

-- C: the shipped bands 1-2 (src/shared/Bands.luau): an early fortune.
local C = curveFrom(
	"C early fortune (built)",
	"Bands.luau: bands 2-4 built (Pro, Storm Hunter, Heavy Salvage); 5 extrapolated",
	{ Bands.simBand2(), Bands.simBand3(), Bands.simBand4() },
	15,
	120,
	{ 600, 1800, 4200 }
)

local function income(band: Band, capacity: number, factor: number): number
	local trip = 0.75 + 0.2 * capacity
	local salvage = capacity * band.AvgItem * factor / trip
	local cores = 0.6 * 175 * factor / CYCLE_MIN
	local events = EXTRACT_RATE * (band.EventBonus + band.PrizeValue * factor) / CYCLE_MIN
	return salvage + cores + events
end

type Result = { Milestones: { [number]: number }, BandEntry: { number }, End: number }

local function run(curve: Curve, horizonMin: number): Result
	local t, coins, lifetime = 0, 0, 0
	local bandIndex, capLevel = 1, 0
	local gearLevel = 0
	local carried = 1 -- sale factor carried over from earlier bands' gear (stays owned)
	local res: Result = { Milestones = {}, BandEntry = { 0 }, End = 0 }
	local nextMilestone = 1
	local function factor(): number
		local b = curve.Bands[bandIndex]
		local g = b.Gear[gearLevel]
		return carried * (if g then g.Factor else 1)
	end
	local function earn(minutes: number)
		local rate = income(curve.Bands[bandIndex], BACKPACK.Values[capLevel + 1], factor())
		-- step in small slices so milestones land at the right minute
		local step = math.max(0.05, minutes / 200)
		local left = minutes
		while left > 0 do
			local dt = math.min(step, left)
			coins += rate * dt
			lifetime += rate * dt
			t += dt
			left -= dt
			while MILESTONES[nextMilestone] and lifetime >= MILESTONES[nextMilestone] do
				res.Milestones[MILESTONES[nextMilestone]] = t
				nextMilestone += 1
			end
		end
	end
	while t < horizonMin do
		local band = curve.Bands[bandIndex]
		local nextBand = curve.Bands[bandIndex + 1]
		-- Options: licence, next backpack, next band gear.
		local options = {}
		if nextBand then
			table.insert(
				options,
				{ Kind = "License", Cost = nextBand.LicenseCost, Wait = nextBand.RequireMinutes }
			)
		end
		if BACKPACK.Costs[capLevel + 1] then
			table.insert(options, { Kind = "Backpack", Cost = BACKPACK.Costs[capLevel + 1], Wait = 0 })
		end
		if band.Gear[gearLevel + 1] then
			table.insert(options, { Kind = "Gear", Cost = band.Gear[gearLevel + 1].Cost, Wait = 0 })
		end
		-- The licence wins once it's affordable and allowed; otherwise the cheapest step. A
		-- player saves for the licence only once their band gear is done.
		table.sort(options, function(a, b)
			return a.Cost < b.Cost
		end)
		local pick = options[1]
		for _, o in options do
			if o.Kind == "License" and (#options == 1 or (coins >= o.Cost and t >= o.Wait)) then
				pick = o
			end
		end
		if not pick then
			earn(horizonMin - t)
			break
		end
		local rate = income(band, BACKPACK.Values[capLevel + 1], factor())
		local need = math.max(0, pick.Cost - coins)
		local wait = math.max(need / rate, (pick.Wait or 0) - t, 0)
		if t + wait > horizonMin then
			earn(horizonMin - t)
			break
		end
		earn(wait)
		coins -= pick.Cost
		if pick.Kind == "License" then
			carried = factor()
			bandIndex += 1
			gearLevel = 0
			res.BandEntry[bandIndex] = t
		elseif pick.Kind == "Backpack" then
			capLevel += 1
		else
			gearLevel += 1
		end
	end
	res.End = t
	return res
end

local function fmtTime(m: number?): string
	if not m then
		return "-"
	end
	if m < 60 then
		return ("%dm"):format(math.floor(m + 0.5))
	end
	return ("%.1fh"):format(m / 60)
end

local function labelOf(n: number): string
	local names = {
		[1e3] = "1K",
		[1e4] = "10K",
		[1e5] = "100K",
		[1e6] = "1M",
		[1e7] = "10M",
		[1e8] = "100M",
		[1e9] = "1B",
		[1e10] = "10B",
		[1e12] = "1T",
	}
	return names[n]
end

local HORIZON = 200 * 60
print("Lifetime-earned milestones (engaged play, greedy income spending; estimates)")
local header = { ("%-26s"):format("curve") }
for _, m in MILESTONES do
	table.insert(header, ("%6s"):format(labelOf(m)))
end
table.insert(header, "   band entries (2 3 4 5)")
print(table.concat(header, " "))
for _, curve in { A, B, C } do
	local r = run(curve, HORIZON)
	local row = { ("%-26s"):format(curve.Name) }
	for _, m in MILESTONES do
		table.insert(row, ("%6s"):format(fmtTime(r.Milestones[m])))
	end
	local entries = {}
	for i = 2, 5 do
		table.insert(entries, fmtTime(r.BandEntry[i]))
	end
	table.insert(row, "   " .. table.concat(entries, " "))
	print(table.concat(row, " "))
end
print("")
for _, curve in { A, B, C } do
	print(("%s: %s"):format(curve.Name, curve.Note))
end

-- Band 2 detail for the built curve: income at entry and with all band-2 gear.
local b2 = C.Bands[2]
print("")
print(
	("Built band 2: income at entry (bag 20, no press) %.0f/min; with full press %.0f/min"):format(
		income(b2, 20, 1),
		income(b2, 20, b2.Gear[#b2.Gear].Factor)
	)
)
print(
	("Built band 1: income bag 3 %.0f/min, bag 20 %.0f/min"):format(income(BAND1, 3, 1), income(BAND1, 20, 1))
)

return { run = run, curves = { A = A, B = B, C = C } }
