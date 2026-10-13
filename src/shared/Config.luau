--!strict
-- @file Game configuration, flags and IDs
-- @domain data
-- @status stable
-- @see [[V3-RELEASE-CHECKLIST]]
-- Central tuning for Storm Salvage. Everything balance-related lives here.

local Config = {}

-- Data environments, explicit and fail-safe (src/shared/Environment.luau, unit-tested):
--   Production  the live place. Real player data, unless LiveTestMode is on (below).
--   Staging     listed private test places use "_STAGING" DataStores (none: no staging experience).
--   Studio      every Studio session (any place) uses "_STUDIO" DataStores.
--   Unknown     any other place gets no DataStores at all: temporary profiles, nothing saved,
--               purchases refused (MonetizationService requires a saving session).
-- Live place confirmed by the owner 2026-10-13: place 99653875913460, experience 10769947641.
Config.ProductionPlaceIds = { 99653875913460 }
Config.StagingPlaceIds = {} :: { number }
-- Pre-launch testing happens in the private live experience. While this is true the live place
-- saves to "StormSalvage_v1_LIVETEST", so real saves are never opened. MUST be false for the
-- public release: a `release-*` tag fails CI while it's true (tools/ci/release-gate.sh).
Config.LiveTestMode = true
do
	local Environment = require(script.Parent:WaitForChild("Environment"))
	local env = Environment.resolve(
		game:GetService("RunService"):IsStudio(),
		game.PlaceId,
		Config.ProductionPlaceIds,
		Config.StagingPlaceIds,
		Config.LiveTestMode
	)
	Config.Environment = env.Name
	Config.DataStoreName = env.DataStoreName
	Config.EnvironmentReason = env.Reason
	Config.IsLiveTest = env.LiveTest
end
Config.AutosaveSeconds = 120
Config.StartingCoins = 0

-- Storm cycle (seconds)
Config.Cycle = {
	Calm = 75,
	Warning = 12,
	Storm = 45,
	Aftermath = 15,
}

-- Storm danger tuning. Damage values are before armor.
Config.StormTuning = {
	SurvivorBonus = 25,
	SurvivorMinTownFraction = 0.5, -- must spend this share of the storm in town to earn the bonus
	-- Flash flood: water rises in 4-stud steps to the map's flood height. The first rise waits a
	-- few seconds so players caught low when the storm starts still get a head start.
	FloodDamagePerSecond = 5, -- ~20s in the water from full health
	FloodFirstRiseSeconds = 4,
	FloodStepSeconds = 6, -- 4 -> 8 -> 12 studs at 4s, 10s, 16s
	-- Lightning: one telegraphed disc at a time per area, so a strike is always dodgeable.
	LightningDamage = 35,
	LightningRadius = 9,
	LightningWarnSeconds = 2.0,
	LightningInterval = { 1.1, 1.7 },
	LightningTargetChance = 0.5, -- chance a strike aims near an exposed player
	LightningMinSpacing = 22, -- pending strike discs never overlap (2 x radius + a step)
	-- Windstorm: steady wind with telegraphed gusts. Gusts carry most of the push and debris;
	-- the lulls between them are the windows to cross open ground.
	DebrisDamage = 14,
	DebrisInterval = 1.0, -- between gusts
	GustDebrisInterval = 0.22, -- during a gust
	DebrisSpread = 6, -- aimed debris lands within this many studs of the player's path
	WindPush = 30, -- steady client-side push (studs/s²)
	GustPush = 150, -- push during a gust; 55 barely moved players, 110 was the old constant
	GustWarnSeconds = 2.0,
	GustSeconds = 3.5,
	GustLull = { 4, 6 }, -- calm seconds between a gust ending and the next warning
}

-- Death drops: only the owner can pick their bag back up for this long, then anyone can.
-- Respawning (5s) and walking back at base speed takes 22-37s depending on the district
-- (measured 2026-10-09), so 40s gives the owner a real chance; others get the last 35s.
Config.BagOwnerOnlySeconds = 40
Config.BagLifetimeSeconds = 75

Config.Storms = {
	Wind = {
		DisplayName = "WINDSTORM",
		Color = Color3.fromRGB(170, 200, 220),
		Hint = "Get behind walls or indoors. Cross open ground between gusts.",
	},
	Flood = {
		DisplayName = "FLASH FLOOD",
		Color = Color3.fromRGB(60, 140, 220),
		Hint = "Roofs won't save you! Climb a yellow ladder or head uphill.",
	},
	Lightning = {
		DisplayName = "LIGHTNING STORM",
		Color = Color3.fromRGB(250, 230, 90),
		Hint = "Get under a roof. Out in the open, dodge the red circles!",
	},
}

-- Loot definitions.
export type LootDef = {
	Name: string,
	Value: number,
	Size: Vector3, -- part size; for cylinders the X axis is the length
	Color: Color3,
	Material: Enum.Material,
	Rarity: string,
	Shape: Enum.PartType?,
	Upright: boolean?, -- stand a cylinder on its end
}

Config.Loot = {
	Can = {
		Name = "Scrap Can",
		Value = 2,
		Size = Vector3.new(1.2, 0.8, 0.8),
		Color = Color3.fromRGB(180, 180, 180),
		Material = Enum.Material.Metal,
		Rarity = "Common",
		Shape = Enum.PartType.Cylinder,
		Upright = true,
	},
	Pipe = {
		Name = "Copper Pipe",
		Value = 5,
		Size = Vector3.new(3, 0.5, 0.5),
		Color = Color3.fromRGB(200, 120, 70),
		Material = Enum.Material.Metal,
		Rarity = "Common",
		Shape = Enum.PartType.Cylinder,
	},
	Toaster = {
		Name = "Toaster",
		Value = 8,
		Size = Vector3.new(1.4, 1, 1),
		Color = Color3.fromRGB(220, 220, 230),
		Material = Enum.Material.SmoothPlastic,
		Rarity = "Common",
	},
	Tv = {
		Name = "Old TV",
		Value = 15,
		Size = Vector3.new(2, 1.6, 1.4),
		Color = Color3.fromRGB(60, 60, 60),
		Material = Enum.Material.SmoothPlastic,
		Rarity = "Uncommon",
	},
	Tire = {
		Name = "Tire",
		Value = 10,
		Size = Vector3.new(0.8, 2.2, 2.2),
		Color = Color3.fromRGB(30, 30, 30),
		Material = Enum.Material.Rubber,
		Rarity = "Common",
		Shape = Enum.PartType.Cylinder,
	},
	Battery = {
		Name = "Car Battery",
		Value = 22,
		Size = Vector3.new(1.2, 1, 1.6),
		Color = Color3.fromRGB(40, 90, 50),
		Material = Enum.Material.Plastic,
		Rarity = "Uncommon",
	},
	Engine = {
		Name = "Engine Block",
		Value = 60,
		Size = Vector3.new(2.5, 2, 2.5),
		Color = Color3.fromRGB(90, 90, 100),
		Material = Enum.Material.DiamondPlate,
		Rarity = "Rare",
	},
	Register = {
		Name = "Cash Register",
		Value = 45,
		Size = Vector3.new(1.6, 1.2, 1.6),
		Color = Color3.fromRGB(230, 200, 80),
		Material = Enum.Material.Metal,
		Rarity = "Rare",
	},
	Safe = {
		Name = "Mini Safe",
		Value = 90,
		Size = Vector3.new(1.8, 1.8, 1.8),
		Color = Color3.fromRGB(50, 55, 70),
		Material = Enum.Material.DiamondPlate,
		Rarity = "Epic",
	},
	Jukebox = {
		Name = "Retro Jukebox",
		Value = 140,
		Size = Vector3.new(2, 3, 1.5),
		Color = Color3.fromRGB(200, 60, 120),
		Material = Enum.Material.Neon,
		Rarity = "Epic",
	},
	StormCore = {
		Name = "Storm Core",
		-- Was 250. In a 10-minute solo run, 4 cores (1008) outearned every other trip combined
		-- (300), making ordinary salvage pointless. 175 stays above the best Epic (140).
		Value = 175,
		Size = Vector3.new(1.6, 1.6, 1.6),
		Color = Color3.fromRGB(120, 220, 255),
		Material = Enum.Material.Neon,
		Rarity = "Legendary",
		Shape = Enum.PartType.Ball,
	},
} :: { [string]: LootDef }

Config.RarityColors = {
	Common = Color3.fromRGB(200, 200, 200),
	Uncommon = Color3.fromRGB(90, 220, 110),
	Rare = Color3.fromRGB(80, 160, 255),
	Epic = Color3.fromRGB(190, 90, 255),
	Legendary = Color3.fromRGB(255, 190, 40),
}

-- Zone loot pools: Weight = relative spawn chance within the zone.
Config.ZonePools = {
	Houses = {
		{ Id = "Can", Weight = 40 },
		{ Id = "Toaster", Weight = 30 },
		{ Id = "Tv", Weight = 20 },
		{ Id = "Jukebox", Weight = 3 },
	},
	Warehouse = {
		{ Id = "Pipe", Weight = 35 },
		{ Id = "Tire", Weight = 30 },
		{ Id = "Engine", Weight = 12 },
		{ Id = "Safe", Weight = 4 },
	},
	GasStation = {
		{ Id = "Can", Weight = 25 },
		{ Id = "Battery", Weight = 35 },
		{ Id = "Tire", Weight = 25 },
		{ Id = "Engine", Weight = 10 },
	},
	Supermarket = {
		{ Id = "Can", Weight = 30 },
		{ Id = "Register", Weight = 25 },
		{ Id = "Tv", Weight = 20 },
		{ Id = "Safe", Weight = 6 },
	},
	Motel = {
		{ Id = "Toaster", Weight = 30 },
		{ Id = "Tv", Weight = 30 },
		{ Id = "Jukebox", Weight = 10 },
		{ Id = "Safe", Weight = 8 },
	},
	TownSquare = {
		{ Id = "Can", Weight = 50 },
		{ Id = "Pipe", Weight = 30 },
		{ Id = "Battery", Weight = 15 },
	},
}

-- North of this Z (and above y=20) is the Scrapyard plateau: storms can't hurt you there.
Config.SafeZoneMaxZ = -222

Config.MaxLootPerZone = 10
Config.LootRespawnSeconds = 8
Config.StormCoresPerStorm = 3 -- Legendary loot that only spawns mid-storm

-- Upgrades: cost per level (index = level being bought).
Config.Upgrades = {
	Backpack = {
		DisplayName = "Backpack",
		Description = "Carry more salvage per trip.",
		Costs = { 50, 150, 400, 1000, 2500 },
		Values = { 3, 5, 7, 10, 14, 20 }, -- capacity at level 0..5
	},
	Boots = {
		DisplayName = "Running Boots",
		Description = "Move faster through the town.",
		Costs = { 75, 250, 700, 1800 },
		Values = { 16, 18, 20, 22, 24 }, -- walkspeed at level 0..4
	},
	Armor = {
		DisplayName = "Storm Armor",
		Description = "Take less damage from storms.",
		Costs = { 100, 350, 900, 2200 },
		Values = { 0, 0.15, 0.3, 0.45, 0.6 }, -- damage reduction at level 0..4
	},
}
Config.UpgradeOrder = { "Backpack", "Boots", "Armor" }

-- Tools: permanent coin unlocks in the Gear Shop's Tools tab (V3-SUPPLY-DEPOT.md). Owned once,
-- saved in the profile's Tools.Owned.
Config.Tools = {
	Detector = {
		DisplayName = "Salvage Detector",
		Description = "Pings the nearest ordinary salvage within range, even behind walls. Epic finds and Storm Cores stay hidden.",
		Cost = 2500,
		Range = 55, -- studs, horizontal
		MaxBlips = 3,
		ScanSeconds = 1, -- server scan interval per owner; a ping is sent only when the set changes
		Rarities = { Common = true, Uncommon = true, Rare = true },
	},
}
Config.ToolOrder = { "Detector" }

-- Sound effects. All from Roblox's licensed libraries (ProSoundEffects / APM Music uploads,
-- published by those accounts on the Creator Store), which any experience may use. Set an id
-- to "" to mute that cue.
--   Group: "Effects" (UI, pickups, sales, warnings) or "Weather" (rain, flood, wind, thunder);
--          the Settings volumes act on these groups.
--   MinInterval: a repeat inside this many seconds is dropped, so fast collecting or many
--          strikes don't pile up. Pool: copies that can overlap. Pitch: default playback speed.
--   Loop: ambience that crossfades in and out.
export type SoundDef = {
	Id: string,
	Volume: number,
	Group: string,
	MinInterval: number?,
	Pool: number?,
	Pitch: number?,
	Loop: boolean?,
}
Config.Sounds = {
	-- Salvage
	Pickup = {
		Id = "rbxassetid://9113244443",
		Volume = 0.55,
		Group = "Effects",
		MinInterval = 0.06,
		Pool = 3,
	}, -- Bag Drop Bag Bumping Wall 2
	FindRare = { Id = "rbxassetid://9116394545", Volume = 0.45, Group = "Effects", MinInterval = 0.25 }, -- Magic Glows Soft Clusters Of Chiming Hits 1
	FindEpic = { Id = "rbxassetid://9116395089", Volume = 0.55, Group = "Effects", MinInterval = 0.25 }, -- Magic Glows Soft Clusters Of Chiming Hits 4
	FindCore = { Id = "rbxassetid://9119447936", Volume = 0.5, Group = "Effects", MinInterval = 0.5 }, -- Sparkle Bell Tree Wind Chimes 1
	-- Selling and upgrades
	Sell = { Id = "rbxassetid://9113849492", Volume = 0.75, Group = "Effects", MinInterval = 0.2 }, -- Coins Or Keys Jingle 6
	SellBig = { Id = "rbxassetid://9113849583", Volume = 0.6, Group = "Effects", MinInterval = 0.3 }, -- Coin Throws 2
	CoreDelivered = { Id = "rbxassetid://9043511769", Volume = 0.4, Group = "Effects", MinInterval = 1 }, -- Rising Together (sting a) (APM)
	Upgrade = { Id = "rbxassetid://9045119921", Volume = 0.45, Group = "Effects", MinInterval = 0.3 }, -- Mascot Party - Mnemonic1 (APM)
	Click = { Id = "rbxassetid://9119727934", Volume = 0.3, Group = "Effects", MinInterval = 0.05, Pool = 2 }, -- Switch In-Line Plastic Switch Clicks 14
	-- Storm warnings: the shared siren plus one identity cue per storm
	Siren = { Id = "rbxassetid://9113073742", Volume = 0.3, Group = "Effects", MinInterval = 2 }, -- Air Raid Siren Old Fashioned 1
	WarnWind = { Id = "rbxassetid://9114373454", Volume = 0.7, Group = "Effects", MinInterval = 1 }, -- Fast Pass By Airy Whooshes Windy 1
	WarnFlood = { Id = "rbxassetid://9120607126", Volume = 0.7, Group = "Effects", MinInterval = 1 }, -- Water Surge 4
	WarnLightning = {
		Id = "rbxassetid://9113169432",
		Volume = 0.6,
		Group = "Effects",
		MinInterval = 1,
		Pitch = 0.7,
	}, -- Artillery Distant 2, slowed into a low rumble
	-- Weather
	Gust = { Id = "rbxassetid://9120704324", Volume = 0.5, Group = "Weather", MinInterval = 1 }, -- Whoosh Combo Of Impacts Bys 6
	Thunder = {
		Id = "rbxassetid://9113169432",
		Volume = 0.9,
		Group = "Weather",
		MinInterval = 0.15,
		Pool = 3,
	}, -- Artillery Distant 2 ("possible use: thunder")
	Rain = { Id = "rbxassetid://9112793871", Volume = 0.45, Group = "Weather", Loop = true }, -- Heavy Rain 2
	Flood = { Id = "rbxassetid://9114492638", Volume = 0.35, Group = "Weather", Loop = true }, -- Flood Massive Flowing Water 1
	Wind = { Id = "rbxassetid://9125742262", Volume = 0.5, Group = "Weather", Loop = true }, -- Constant Airy Whooshing Windy
} :: { [string]: SoundDef }

-- Monetization. Set IDs after creating products on the Creator Dashboard; 0 disables.
-- Robux shop (owner's launch catalog, 2026-10-13; packs resized to 300/1,200/3,000 so no single
-- pack buys more than ~30% of all equipment). Optional purchases that speed progress up;
-- nothing here is pay-to-win in a storm, random, or a second currency.
--   Id 0 = not created on the Creator Hub yet (shown as "not on sale yet", can't be bought).
--   RobuxPrice is the planned price, shown only until the real price is read from Roblox
--   (MarketplaceService:GetProductInfo); the Creator Hub price is the one players pay.
--   PurchasesEnabled is the master switch for Buy buttons. Receipts for configured products are
--   always honoured, so a purchase made before a switch-off is still delivered.
Config.PurchasesEnabled = false
Config.GamePasses = {
	HeavyDuty = {
		Id = 0,
		DisplayName = "Heavy-Duty Pack",
		-- +2 (owner decision 2026-10-13): +4 gave +54% income in a matched 15-min test.
		Description = "+2 bag slots on top of your Backpack upgrades. Permanent.",
		BonusCapacity = 2,
		RobuxPrice = 149,
	},
}
Config.DevProducts = {
	CoinsSmall = { Id = 0, DisplayName = "Pocket Change", Coins = 300, RobuxPrice = 29, Order = 1 },
	CoinsMedium = { Id = 0, DisplayName = "Scrap Bundle", Coins = 1200, RobuxPrice = 99, Order = 2 },
	CoinsLarge = { Id = 0, DisplayName = "Salvage Haul", Coins = 3000, RobuxPrice = 199, Order = 3 },
}

return Config
