--!strict
-- @file V4 progression bands 1-2: licence, industrial salvage, Salvage Press, event bonuses
-- @domain salvage-economy
-- @status wip
-- @tested-by [[bands.spec.luau]]
-- @see [[V4-ECONOMY]]
-- The economy ladder's first two bands, as data (pure: the server, the client, the unit tests and
-- the economy simulation (tools/econ/sim.luau) all read this one table).
--   Band 1 "Scrap Rookie": today's town salvage, gear and events. Nothing changes.
--   Band 2 "Professional": entered with the Pro Salvage License, which costs coins AND proves
--     you can play: a Salvager rank and three successful extractions. It opens a new class of
--     salvage (industrial machinery in the Warehouse, Fuel & Go and Supermarket yards: real new
--     things to chase, worth 30-600x a tin can), the Salvage Press (a sale multiplier track),
--     and band-sized extraction bonuses. Bigger numbers come from bigger accomplishments, not
--     from multiplying every price.
-- Paying Robux never buys a licence or skips a requirement (and purchases stay off).

local Bands = {}

export type Requirement = { Kind: "Rank" | "Extractions", Value: number, Text: string }
export type License = {
	Id: string,
	DisplayName: string,
	Band: number,
	Cost: number,
	Requirements: { Requirement },
	Description: string,
}

Bands.Names = { "Town", "Pro" }

Bands.Licenses = {
	Pro = {
		Id = "Pro",
		DisplayName = "Pro Salvage License",
		Band = 2,
		Cost = 5000,
		Requirements = {
			{ Kind = "Rank", Value = 3, Text = "Reach the Salvager rank" },
			{ Kind = "Extractions", Value = 3, Text = "Extract 3 event cores to the Scrapyard" },
		},
		Description = "Licensed to haul industrial salvage: machinery worth hundreds to thousands of coins, "
			.. "found in the Warehouse, Fuel & Go and Supermarket yards. Unlocks the Salvage Press and "
			.. "Pro-sized event bonuses.",
	},
} :: { [string]: License }
Bands.LicenseOrder = { "Pro" }

-- Industrial salvage (band 2). Spawns alongside ordinary loot (its own cap, so unlicensed players'
-- ordinary salvage isn't diluted); unlicensed players see it but can't take it.
export type Industrial = { Id: string, Name: string, Value: number, Rarity: string, Weight: number }
Bands.Industrial = {
	{ Id = "CopperSpool", Name = "Copper Wire Spool", Value = 400, Rarity = "Uncommon", Weight = 40 },
	{ Id = "HydraulicPump", Name = "Hydraulic Pump", Value = 1200, Rarity = "Rare", Weight = 32 },
	{ Id = "DieselGenerator", Name = "Diesel Generator", Value = 3000, Rarity = "Epic", Weight = 20 },
	{ Id = "TurbineRotor", Name = "Turbine Rotor", Value = 9000, Rarity = "Legendary", Weight = 8 },
} :: { Industrial }
Bands.IndustrialZones = { Warehouse = true, GasStation = true, Supermarket = true }
Bands.IndustrialPerZone = 3
Bands.IndustrialLicense = "Pro"

-- The Salvage Press: band 2 gear, a sale multiplier on everything you sell (cumulative factor
-- at each level). Needs the Pro licence.
Bands.Press = {
	DisplayName = "Salvage Press",
	Description = "Compacts salvage before you sell it: every sale pays more.",
	License = "Pro",
	Costs = { 20000, 60000, 150000, 400000, 1000000, 2500000 },
	Values = { 1, 1.5, 2, 3, 4, 6, 8 }, -- factor at level 0..6
}

-- Extraction bonus per band (coins), by event kind. A Golden Storm Core extraction pays
-- GoldenFactor times the bonus from band 2 on (band 1 keeps today's 150 / 120 for both).
Bands.EventBonus = {
	{ Pursuit = 150, Extraction = 120, GoldenFactor = 1 },
	{ Pursuit = 6000, Extraction = 5000, GoldenFactor = 3 },
}

-- The band a profile is in: 1 plus every licence held, in order.
function Bands.bandOf(licenses: { [string]: boolean }?): number
	local band = 1
	for _, id in Bands.LicenseOrder do
		if licenses and licenses[id] then
			band = math.max(band, Bands.Licenses[id].Band)
		end
	end
	return band
end

-- The extraction bonus for a player in `band` for an event of `kind`.
function Bands.eventBonus(band: number, kind: string, golden: boolean): number
	local row = Bands.EventBonus[math.clamp(band, 1, #Bands.EventBonus)]
	local base = if kind == "Extraction" then row.Extraction else row.Pursuit
	return base * (if golden then row.GoldenFactor else 1)
end

export type Progress = { Rank: number, Extractions: number, Coins: number, Owned: boolean }
export type LicenseCheck = {
	Ok: boolean,
	Reason: ("owned" | "requirements" | "short" | "invalid")?,
	Missing: { string },
}

-- Can a player buy licence `id`? Every requirement must be met AND the coins available.
function Bands.checkLicense(id: unknown, p: Progress): LicenseCheck
	local def = if type(id) == "string" then Bands.Licenses[id] else nil
	if not def then
		return { Ok = false, Reason = "invalid", Missing = {} }
	end
	if p.Owned then
		return { Ok = false, Reason = "owned", Missing = {} }
	end
	local missing = {}
	for _, r in def.Requirements do
		local have = if r.Kind == "Rank" then p.Rank else p.Extractions
		if type(have) ~= "number" or have ~= have or have < r.Value then
			table.insert(missing, r.Text)
		end
	end
	if #missing > 0 then
		return { Ok = false, Reason = "requirements", Missing = missing }
	end
	if type(p.Coins) ~= "number" or p.Coins ~= p.Coins or p.Coins < def.Cost then
		return { Ok = false, Reason = "short", Missing = {} }
	end
	return { Ok = true, Missing = {} }
end

-- The Press level a player can buy next, or why not.
export type PressCheck = { Ok: boolean, Reason: ("license" | "maxed" | "short" | "invalid")?, Cost: number? }
function Bands.checkPress(level: unknown, licensed: boolean, coins: unknown): PressCheck
	if
		type(level) ~= "number"
		or level % 1 ~= 0
		or level < 0
		or type(coins) ~= "number"
		or coins ~= coins
	then
		return { Ok = false, Reason = "invalid" }
	end
	if not licensed then
		return { Ok = false, Reason = "license" }
	end
	local cost = Bands.Press.Costs[level + 1]
	if not cost then
		return { Ok = false, Reason = "maxed" }
	end
	if coins < cost then
		return { Ok = false, Reason = "short", Cost = cost }
	end
	return { Ok = true, Cost = cost }
end

-- Average value of what a licensed band-2 player carries (half industrial, half town salvage,
-- by spawn weight). Used by the economy simulation.
function Bands.avgIndustrial(): number
	local total, weight = 0, 0
	for _, item in Bands.Industrial do
		total += item.Value * item.Weight
		weight += item.Weight
	end
	return total / weight
end

-- Band 2 in the simulation's shape (tools/econ/sim.luau).
function Bands.simBand2(): any
	local gear = {}
	for i, cost in Bands.Press.Costs do
		table.insert(gear, { Cost = cost, Factor = Bands.Press.Values[i + 1] })
	end
	return {
		Name = "2 Professional",
		LicenseCost = Bands.Licenses.Pro.Cost,
		RequireMinutes = 25, -- Salvager rank ~12 min; 3 extractions at ~1 per 5 min
		AvgItem = 0.5 * 14 + 0.5 * Bands.avgIndustrial(),
		EventBonus = Bands.EventBonus[2].Pursuit,
		PrizeValue = 0.85 * 175 + 0.15 * 600,
		Gear = gear,
	}
end

return Bands
