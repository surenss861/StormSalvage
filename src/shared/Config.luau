--!strict
-- Central tuning for Storm Salvage. Everything balance-related lives here.

local Config = {}

Config.DataStoreName = "StormSalvage_v1"
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
	FloodDamagePerSecond = 5, -- ~20s in the water from full health
	FloodRiseFraction = 0.4, -- water reaches full height after this share of the storm
	LightningDamage = 35,
	LightningRadius = 9,
	LightningWarnSeconds = 1.6,
	LightningInterval = { 0.8, 1.4 },
	LightningTargetChance = 0.5, -- chance a strike aims near an exposed player
	DebrisDamage = 14,
	DebrisInterval = 0.3,
	WindPush = 110, -- client-side push acceleration (studs/s²); 55 barely moved players in testing
}

-- Death drops: only the owner can pick their bag back up for this long, then anyone can.
Config.BagOwnerOnlySeconds = 20
Config.BagLifetimeSeconds = 60

Config.Storms = {
	Wind = {
		DisplayName = "WINDSTORM",
		Color = Color3.fromRGB(170, 200, 220),
		Hint = "Debris is flying! Stay behind walls.",
	},
	Flood = {
		DisplayName = "FLASH FLOOD",
		Color = Color3.fromRGB(60, 140, 220),
		Hint = "Water is rising! Get to high ground.",
	},
	Lightning = {
		DisplayName = "LIGHTNING STORM",
		Color = Color3.fromRGB(250, 230, 90),
		Hint = "Watch for glowing circles on the ground!",
	},
}

-- Loot definitions.
export type LootDef = {
	Name: string,
	Value: number,
	Size: Vector3,
	Color: Color3,
	Material: Enum.Material,
	Rarity: string,
}

Config.Loot = {
	Can = { Name = "Scrap Can", Value = 2, Size = Vector3.new(0.8, 1.2, 0.8), Color = Color3.fromRGB(180, 180, 180), Material = Enum.Material.Metal, Rarity = "Common" },
	Pipe = { Name = "Copper Pipe", Value = 5, Size = Vector3.new(0.5, 0.5, 3), Color = Color3.fromRGB(200, 120, 70), Material = Enum.Material.Metal, Rarity = "Common" },
	Toaster = { Name = "Toaster", Value = 8, Size = Vector3.new(1.4, 1, 1), Color = Color3.fromRGB(220, 220, 230), Material = Enum.Material.SmoothPlastic, Rarity = "Common" },
	Tv = { Name = "Old TV", Value = 15, Size = Vector3.new(2, 1.6, 1.4), Color = Color3.fromRGB(60, 60, 60), Material = Enum.Material.SmoothPlastic, Rarity = "Uncommon" },
	Tire = { Name = "Tire", Value = 10, Size = Vector3.new(2.2, 2.2, 0.8), Color = Color3.fromRGB(30, 30, 30), Material = Enum.Material.Rubber, Rarity = "Common" },
	Battery = { Name = "Car Battery", Value = 22, Size = Vector3.new(1.2, 1, 1.6), Color = Color3.fromRGB(40, 90, 50), Material = Enum.Material.Plastic, Rarity = "Uncommon" },
	Engine = { Name = "Engine Block", Value = 60, Size = Vector3.new(2.5, 2, 2.5), Color = Color3.fromRGB(90, 90, 100), Material = Enum.Material.DiamondPlate, Rarity = "Rare" },
	Register = { Name = "Cash Register", Value = 45, Size = Vector3.new(1.6, 1.2, 1.6), Color = Color3.fromRGB(230, 200, 80), Material = Enum.Material.Metal, Rarity = "Rare" },
	Safe = { Name = "Mini Safe", Value = 90, Size = Vector3.new(1.8, 1.8, 1.8), Color = Color3.fromRGB(50, 55, 70), Material = Enum.Material.DiamondPlate, Rarity = "Epic" },
	Jukebox = { Name = "Retro Jukebox", Value = 140, Size = Vector3.new(2, 3, 1.5), Color = Color3.fromRGB(200, 60, 120), Material = Enum.Material.Neon, Rarity = "Epic" },
	StormCore = { Name = "Storm Core", Value = 250, Size = Vector3.new(1.5, 1.5, 1.5), Color = Color3.fromRGB(120, 220, 255), Material = Enum.Material.Neon, Rarity = "Legendary" },
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
	Houses = { { Id = "Can", Weight = 40 }, { Id = "Toaster", Weight = 30 }, { Id = "Tv", Weight = 20 }, { Id = "Jukebox", Weight = 3 } },
	Warehouse = { { Id = "Pipe", Weight = 35 }, { Id = "Tire", Weight = 30 }, { Id = "Engine", Weight = 12 }, { Id = "Safe", Weight = 4 } },
	GasStation = { { Id = "Can", Weight = 25 }, { Id = "Battery", Weight = 35 }, { Id = "Tire", Weight = 25 }, { Id = "Engine", Weight = 10 } },
	Supermarket = { { Id = "Can", Weight = 30 }, { Id = "Register", Weight = 25 }, { Id = "Tv", Weight = 20 }, { Id = "Safe", Weight = 6 } },
	Motel = { { Id = "Toaster", Weight = 30 }, { Id = "Tv", Weight = 30 }, { Id = "Jukebox", Weight = 10 }, { Id = "Safe", Weight = 8 } },
	TownSquare = { { Id = "Can", Weight = 50 }, { Id = "Pipe", Weight = 30 }, { Id = "Battery", Weight = 15 } },
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

-- Monetization. Set IDs after creating products on the Creator Dashboard; 0 disables.
Config.GamePasses = {
	BigBag = { Id = 0, DisplayName = "Big Bag", Description = "+5 carry capacity forever.", BonusCapacity = 5 },
	VIP = { Id = 0, DisplayName = "VIP", Description = "+20% sell value forever.", SellMultiplier = 1.2 },
}

Config.DevProducts = {
	SalvageBoost = { Id = 0, DisplayName = "2x Salvage (15 min)", BoostSeconds = 15 * 60 },
	CoinPackSmall = { Id = 0, DisplayName = "500 Coins", Coins = 500 },
}

return Config
