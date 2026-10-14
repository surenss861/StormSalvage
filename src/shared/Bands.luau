--!strict
-- @file V4 progression bands: licences, salvage classes, band gear, event bonuses
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
--   Band 3 "Storm Hunter" (M4): storm artifacts that exist only mid-storm, out in the open, one
--     kind per storm type; the Storm Harness (stay out in the weather longer); and the Storm's
--     Eye, a drifting pocket of calm that carries a Storm Heart through the storm.
--   Band 4 "Heavy Salvage" (M4): the Armored Wreck. After a storm an armored bank truck lies
--     wrecked at an event site. Heavy licence holders cut its locks with a Thermal Cutter (stand
--     at a lock and keep cutting; progress stays if you step away) while its security charges
--     fire telegraphed shocks at the cutters. Each lock drops a strongbox; when every lock is cut
--     the vault spills bullion for everyone. A new skill (working a spot under fire, together),
--     not a bigger price on the old loop.
--   Band 5 "Storm Legend" (M4): the Storm Titan. During a storm a colossal twister roams town.
--     Legend licence holders siphon it with a Containment Rig by holding the ring around it:
--     close enough to draw its energy, not so close it swallows you, while it drags you in and
--     hurls debris. A full siphon forms a Mythic Core at your feet, its kind drawn at published
--     odds. The skill is riding a moving ring under pull.
-- Paying Robux never buys a licence or skips a requirement (and purchases stay off).

-- Roblox resolves the sibling ModuleScript; Lune (unit tests) resolves the file path.
local BigMoney = if script then require(script.Parent.BigMoney) else (require :: any)("./BigMoney")

local Bands = {}

-- A licence requirement. Rank: Salvager rank index. Extractions: event cores extracted.
-- Found: kinds of a salvage class in the Salvage Log. Record: a Records counter.
export type Requirement = {
	Kind: "Rank" | "Extractions" | "Found" | "Record",
	Value: number,
	Text: string,
	Class: string?,
	Field: string?,
}
export type License = {
	Id: string,
	DisplayName: string,
	Band: number,
	Cost: number,
	Requirements: { Requirement },
	Description: string,
	Tag: string, -- short label on the licence card
	Earned: string, -- the line shown when it's bought
}

Bands.Names = { "Town", "Pro", "Storm Hunter", "Heavy Salvage", "Storm Legend" }

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
		Tag = "PRO",
		Earned = "Industrial salvage is yours to haul.",
		Description = "Licensed to haul industrial salvage: machinery worth hundreds to thousands of coins, "
			.. "found in the Warehouse, Fuel & Go, Supermarket, Rail Yard and Flood Control. Unlocks the Press and "
			.. "Pro-sized event bonuses.",
	},
	Hunter = {
		Id = "Hunter",
		DisplayName = "Storm Hunter License",
		Band = 3,
		Cost = 4000000,
		Requirements = {
			{ Kind = "Rank", Value = 4, Text = "Reach the Storm Runner rank" },
			{ Kind = "Extractions", Value = 10, Text = "Extract 10 event cores" },
			{
				Kind = "Found",
				Class = "Industrial",
				Value = 4,
				Text = "Log all 4 kinds of industrial salvage",
			},
		},
		Tag = "HUNTER",
		Earned = "Storm artifacts and the Storm Heart are yours to hunt.",
		Description = "Licensed to hunt the storm itself: artifacts that form only mid-storm, out in the "
			.. "open, and the Storm Heart the Eye carries. Unlocks the Storm Harness and Hunter-sized "
			.. "event bonuses.",
	},
	Heavy = {
		Id = "Heavy",
		DisplayName = "Heavy Salvage License",
		Band = 4,
		Cost = 1000000000,
		Requirements = {
			{ Kind = "Rank", Value = 5, Text = "Reach the Wreck Diver rank" },
			{ Kind = "Extractions", Value = 25, Text = "Extract 25 event cores" },
			{ Kind = "Found", Class = "Artifact", Value = 3, Text = "Log all 3 storm artifacts" },
			{ Kind = "Record", Field = "EyeHearts", Value = 1, Text = "Deliver a Storm Heart" },
		},
		Tag = "HEAVY",
		Earned = "The Armored Wreck is yours to cut open.",
		Description = "Licensed for heavy salvage: after a storm, cut open the Armored Wreck's locks "
			.. "with a Thermal Cutter while its security charges fire, for strongboxes and vault "
			.. "bullion. Unlocks Thermal Cutter upgrades and Heavy-sized event bonuses.",
	},
	Legend = {
		Id = "Legend",
		DisplayName = "Storm Legend License",
		Band = 5,
		Cost = 20000000000,
		Requirements = {
			{ Kind = "Rank", Value = 7, Text = "Reach the Storm Legend rank" },
			{ Kind = "Extractions", Value = 50, Text = "Extract 50 event cores" },
			{ Kind = "Record", Field = "VaultsOpened", Value = 3, Text = "Help open 3 Armored Wreck vaults" },
			{ Kind = "Found", Class = "Vault", Value = 2, Text = "Log a Strongbox and a Bullion Bar" },
		},
		Tag = "LEGEND",
		Earned = "The Storm Titan is yours to siphon.",
		Description = "Licensed to take on the Storm Titan: siphon the colossal twister with a "
			.. "Containment Rig for Mythic Cores, drawn at published odds. Unlocks Containment Rig "
			.. "upgrades and Legend-sized event bonuses.",
	},
} :: { [string]: License }
Bands.LicenseOrder = { "Pro", "Hunter", "Heavy", "Legend" }

-- Storm artifacts (band 3): each storm type forms its own kind, out in the open, only while the
-- storm rages (they melt away in the aftermath). Values before the Salvage Press.
export type Artifact = { Id: string, Name: string, Value: number, Rarity: string, Storm: string? }
Bands.Artifacts = {
	{ Id = "GaleShard", Name = "Gale Shard", Value = 18000, Rarity = "Rare", Storm = "Wind" },
	{ Id = "TideRelic", Name = "Tide Relic", Value = 26000, Rarity = "Epic", Storm = "Flood" },
	{ Id = "Fulgurite", Name = "Fulgurite", Value = 36000, Rarity = "Epic", Storm = "Lightning" },
} :: { Artifact }
Bands.ArtifactsPerStorm = 5
Bands.ArtifactLicense = "Hunter"
-- The Storm's Eye prize (band 3 signature event).
Bands.StormHeart = { Id = "StormHeart", Name = "Storm Heart", Value = 600000, Rarity = "Legendary" }

-- The Storm's Eye: while a storm rages, a calm pocket drifts across town carrying a Storm Heart.
-- Inside it there's no wind, debris or lightning (a flood's water stays: the Eye can't hold back
-- the sea). The Heart forms at the Eye's centre and stays where it formed, so the Eye drifts
-- away and leaves it in the open storm: grab it while you're still sheltered, or go in after it.
Bands.Eye = {
	Radius = 22,
	Speed = 5, -- studs/s
	FormSeconds = 4,
	Legs = 4, -- straight drifts between exposed points
	MinBand = 3, -- appears when someone in the server holds the Storm Hunter licence
}

-- The Armored Wreck (band 4 signature event). Runs in the calm after a storm, alongside the
-- ordinary event, when someone in the server holds the Heavy licence. Locks take CutSeconds of
-- cutting at Thermal Cutter level 0 (several cutters on one lock add up); a security charge
-- (telegraphed shock) fires at a cutter every ChargeEvery seconds. Stepping out of reach to dodge
-- pauses your cut (it resumes when you're back); a hit stops it until you press the lock again.
Bands.Wreck = {
	License = "Heavy",
	MinBand = 4,
	StartAfterCalm = 10, -- seconds into the Calm phase
	Seconds = 55, -- cut short so it always ends before the storm warning
	Locks = 3,
	CutSeconds = 7,
	CutReach = 6, -- studs from a lock (the side hatch needs a climb: from the ground it is ~7)
	Leash = 16, -- step further than this from your lock and you've stopped cutting it
	ChargeEvery = 3.2,
	ChargeWarn = 1.5,
	ChargeRadius = 7,
	ChargeDamage = 30,
	BarsBase = 2, -- the vault spills BarsBase + one per cutter (capped)
	BarsMax = 6,
	JewelChance = 0.25, -- real odds, announced when it spills
	ItemSeconds = 40, -- vault salvage left on the ground this long
}
-- Vault salvage (band 4). Heavy licence holders only.
export type VaultItem = { Id: string, Name: string, Value: number, Rarity: string }
Bands.Vault = {
	Strongbox = { Id = "Strongbox", Name = "Strongbox", Value = 250000, Rarity = "Rare" },
	BullionBar = { Id = "BullionBar", Name = "Bullion Bar", Value = 1200000, Rarity = "Epic" }, -- several per vault: no server-wide call-out each
	CrownJewels = { Id = "CrownJewels", Name = "Crown Jewels", Value = 8000000, Rarity = "Legendary" },
} :: { [string]: VaultItem }
Bands.VaultOrder = { "Strongbox", "BullionBar", "CrownJewels" }

-- The Thermal Cutter: band 4 gear. Cutting speed (factor at each level).
Bands.Cutter = {
	DisplayName = "Thermal Cutter",
	Description = "Cuts the Armored Wreck's locks faster: more of the vault before the charges get you.",
	License = "Heavy",
	Costs = { 3000000000, 8000000000, 20000000000, 50000000000, 120000000000 },
	Values = { 1, 1.3, 1.6, 2, 2.5, 3 }, -- cutting speed at level 0..5
}

-- The Storm Titan (band 5 signature event). Runs during a storm when someone in the server holds
-- the Legend licence. Siphon ring: between InnerRadius and OuterRadius from its centre. Inside
-- the inner radius it hurts and drains your siphon; the pull (client-side push, like the wind)
-- grows toward the centre. Debris strikes (telegraphed) fall on siphoners.
Bands.Titan = {
	License = "Legend",
	MinBand = 5,
	StartAfter = 6, -- seconds into the storm
	Speed = 7, -- studs/s
	Legs = 5,
	InnerRadius = 16,
	OuterRadius = 40,
	SiphonSeconds = 12, -- in the ring at Containment Rig level 0
	CoreDamagePerSecond = 18, -- inside the inner radius
	DrainPerSecond = 0.15, -- siphon lost per second inside the inner radius
	Pull = 80, -- studs/s² at the inner edge, a quarter at the outer (steady wind 30, gust 150; 120 sucked players straight in)
	StrikeEvery = 3,
	StrikeWarn = 1.4,
	StrikeRadius = 8,
	StrikeDamage = 20,
	CoreSeconds = 50, -- a Mythic Core waits this long on the ground
}
-- Mythic Cores: the Titan's prize. Odds are published (licence card, Salvage Log, the formation
-- notice) and are the real draw weights.
export type Mythic = { Id: string, Name: string, Value: number, Odds: number }
Bands.Mythic = {
	{ Id = "TitanCore", Name = "Titan Core", Value = 40000000, Odds = 0.6 },
	{ Id = "PrismCore", Name = "Prism Core", Value = 100000000, Odds = 0.3 },
	{ Id = "SingularityCore", Name = "Singularity Core", Value = 400000000, Odds = 0.1 },
} :: { Mythic }

-- Draw a Mythic Core with `roll` in [0, 1).
function Bands.drawMythic(roll: number): Mythic
	local acc = 0
	for _, m in Bands.Mythic do
		acc += m.Odds
		if roll < acc then
			return m
		end
	end
	return Bands.Mythic[#Bands.Mythic]
end

-- The Containment Rig: band 5 gear. Siphon speed, and resistance to the Titan's pull.
Bands.Rig = {
	DisplayName = "Containment Rig",
	Description = "Siphons the Storm Titan faster and braces you against its pull.",
	License = "Legend",
	Costs = { 100000000000, 300000000000, 900000000000, 2700000000000, 8000000000000 },
	Values = { 1, 1.3, 1.6, 2, 2.5, 3 }, -- siphon speed at level 0..5 (pull resistance: 1 - 1/speed)
}

-- Bars the vault spills for `cutters` players.
function Bands.barsFor(cutters: number): number
	return math.clamp(Bands.Wreck.BarsBase + math.max(0, cutters), Bands.Wreck.BarsBase, Bands.Wreck.BarsMax)
end

-- Industrial salvage (band 2). Spawns alongside ordinary loot (its own cap, so unlicensed players'
-- ordinary salvage isn't diluted); unlicensed players see it but can't take it.
export type Industrial = { Id: string, Name: string, Value: number, Rarity: string, Weight: number }
Bands.Industrial = {
	{ Id = "CopperSpool", Name = "Copper Wire Spool", Value = 400, Rarity = "Uncommon", Weight = 40 },
	{ Id = "HydraulicPump", Name = "Hydraulic Pump", Value = 1200, Rarity = "Rare", Weight = 32 },
	{ Id = "DieselGenerator", Name = "Diesel Generator", Value = 3000, Rarity = "Epic", Weight = 20 },
	{ Id = "TurbineRotor", Name = "Turbine Rotor", Value = 9000, Rarity = "Legendary", Weight = 8 },
} :: { Industrial }
Bands.IndustrialZones =
	{ Warehouse = true, GasStation = true, Supermarket = true, RailYard = true, FloodWorks = true }
Bands.IndustrialPerZone = 3
Bands.IndustrialLicense = "Pro"

-- The Storm Harness: band 3 gear. Protection from storm damage and wind push (fraction at each
-- level), so a hunter can stay out in the weather where the artifacts are.
Bands.Harness = {
	DisplayName = "Storm Harness",
	Description = "Braces you against the storm: less storm damage, less wind push. Hunt longer in the open.",
	License = "Hunter",
	Costs = { 6000000, 15000000, 35000000, 80000000, 180000000 },
	Values = { 0, 0.15, 0.3, 0.45, 0.6, 0.75 }, -- protection at level 0..5
}

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
	{ Pursuit = 90000, Extraction = 75000, GoldenFactor = 3 },
	{ Pursuit = 1500000, Extraction = 1200000, GoldenFactor = 3 },
	{ Pursuit = 25000000, Extraction = 20000000, GoldenFactor = 3 },
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

export type Progress = {
	Rank: number,
	Extractions: number,
	Coins: number | string,
	Owned: boolean,
	Found: { [string]: number }?, -- kinds logged per salvage class
	Records: { [string]: number }?,
}

-- How far a player is along one requirement (have, needed).
function Bands.progressOf(r: Requirement, p: Progress): (number, number)
	local have: any
	if r.Kind == "Rank" then
		have = p.Rank
	elseif r.Kind == "Extractions" then
		have = p.Extractions
	elseif r.Kind == "Found" then
		have = p.Found and p.Found[r.Class :: string]
	else
		have = p.Records and p.Records[r.Field :: string]
	end
	if type(have) ~= "number" or have ~= have then
		have = 0
	end
	return have, r.Value
end
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
		local have, need = Bands.progressOf(r, p)
		if have < need then
			table.insert(missing, r.Text)
		end
	end
	if #missing > 0 then
		return { Ok = false, Reason = "requirements", Missing = missing }
	end
	local coins = BigMoney.parse(p.Coins)
	if not coins or BigMoney.lt(coins, BigMoney.of(def.Cost)) then
		return { Ok = false, Reason = "short", Missing = {} }
	end
	return { Ok = true, Missing = {} }
end

-- The Press level a player can buy next, or why not.
export type PressCheck = { Ok: boolean, Reason: ("license" | "maxed" | "short" | "invalid")?, Cost: number? }
function Bands.checkPress(level: unknown, licensed: boolean, coins: unknown): PressCheck
	local have = BigMoney.parse(coins)
	if type(level) ~= "number" or level % 1 ~= 0 or level < 0 or not have then
		return { Ok = false, Reason = "invalid" }
	end
	if not licensed then
		return { Ok = false, Reason = "license" }
	end
	local cost = Bands.Press.Costs[level + 1]
	if not cost then
		return { Ok = false, Reason = "maxed" }
	end
	if BigMoney.lt(have, BigMoney.of(cost)) then
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

-- Kinds of each salvage class found, from a Salvage Log and the loot table ({id -> def}).
function Bands.foundByClass(found: { [string]: boolean }?, loot: { [string]: any }): { [string]: number }
	local out = {}
	for id, def in loot do
		if found and found[id] and type(def) == "table" and def.Class then
			out[def.Class] = (out[def.Class] or 0) + 1
		end
	end
	return out
end

-- Band 3 in the simulation's shape: a hunter's sales are about 2 artifacts per storm cycle (more
-- with the Harness: it is modelled as an income factor, 1 + protection) plus the Eye's Heart on
-- half the storms, all through a maxed Salvage Press (x8) carried over from band 2.
function Bands.simBand3(): any
	local avgArtifact = 0
	for _, a in Bands.Artifacts do
		avgArtifact += a.Value / #Bands.Artifacts
	end
	local gear = {}
	for i, cost in Bands.Harness.Costs do
		table.insert(gear, { Cost = cost, Factor = 1 + Bands.Harness.Values[i + 1] })
	end
	return {
		Name = "3 Storm Hunter",
		LicenseCost = Bands.Licenses.Hunter.Cost,
		RequireMinutes = 150, -- Storm Runner rank, 10 extractions, all industrial logged
		AvgItem = 0.5 * Bands.avgIndustrial() + 0.5 * avgArtifact,
		EventBonus = Bands.EventBonus[3].Pursuit,
		PrizeValue = 0.5 * Bands.StormHeart.Value, -- the Heart on about half the storms
		Gear = gear,
	}
end

-- Band 4 in the simulation's shape: per cycle a solo Heavy salvager cuts the wreck (3 strongboxes,
-- 3 bars, the jewels a quarter of the time) on about 40% of cycles (charges, a late start, a
-- missed site), plus band 3 storm hunting; the Thermal Cutter is an income factor on the wreck
-- share, all through the maxed Press (x8).
function Bands.simBand4(): any
	local W = Bands.Wreck
	local wreck = W.Locks * Bands.Vault.Strongbox.Value
		+ Bands.barsFor(1) * Bands.Vault.BullionBar.Value
		+ W.JewelChance * Bands.Vault.CrownJewels.Value
	local gear = {}
	for i, cost in Bands.Cutter.Costs do
		-- faster cutting finishes the wreck more often: income grows with the root of the speed
		table.insert(gear, { Cost = cost, Factor = math.sqrt(Bands.Cutter.Values[i + 1]) })
	end
	return {
		Name = "4 Heavy Salvage",
		LicenseCost = Bands.Licenses.Heavy.Cost,
		RequireMinutes = 720, -- Wreck Diver rank, 25 extractions, the artifacts, a Heart
		AvgItem = 0.5 * Bands.avgIndustrial() + 0.5 * Bands.Artifacts[2].Value,
		EventBonus = Bands.EventBonus[4].Pursuit,
		PrizeValue = 0.4 * wreck + 0.5 * Bands.StormHeart.Value,
		Gear = gear,
	}
end

-- Band 5 in the simulation's shape: a Legend siphons about one Mythic Core per storm (the ring
-- is hard to hold: modelled as 0.8 of a core at the average draw), plus band 4's wreck on 40% of
-- cycles; the Rig is an income factor (root of its speed) on top of the carried gear.
function Bands.simBand5(): any
	local avgMythic = 0
	for _, m in Bands.Mythic do
		avgMythic += m.Value * m.Odds
	end
	local W = Bands.Wreck
	local wreck = W.Locks * Bands.Vault.Strongbox.Value
		+ Bands.barsFor(1) * Bands.Vault.BullionBar.Value
		+ W.JewelChance * Bands.Vault.CrownJewels.Value
	local gear = {}
	for i, cost in Bands.Rig.Costs do
		table.insert(gear, { Cost = cost, Factor = math.sqrt(Bands.Rig.Values[i + 1]) })
	end
	return {
		Name = "5 Storm Legend",
		LicenseCost = Bands.Licenses.Legend.Cost,
		RequireMinutes = 2400, -- Storm Legend rank, 50 extractions, 3 vaults
		AvgItem = 0.5 * Bands.avgIndustrial() + 0.5 * Bands.Artifacts[2].Value,
		EventBonus = Bands.EventBonus[5].Pursuit,
		PrizeValue = 0.8 * avgMythic + 0.4 * wreck,
		Gear = gear,
	}
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
