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
Config.BagOwnerOnlySeconds = 20
Config.BagLifetimeSeconds = 60

Config.Storms = {
	Wind = {
		DisplayName = "WINDSTORM",
		Color = Color3.fromRGB(170, 200, 220),
		Hint = "Cross open ground between gusts. Hide during them.",
	},
	Flood = {
		DisplayName = "FLASH FLOOD",
		Color = Color3.fromRGB(60, 140, 220),
		Hint = "Water is rising! Climb a yellow ladder or head uphill.",
	},
	Lightning = {
		DisplayName = "LIGHTNING STORM",
		Color = Color3.fromRGB(250, 230, 90),
		Hint = "Step out of red circles before they strike!",
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
		Value = 250,
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

-- Sound effects. All from Roblox's licensed libraries (ProSoundEffects / APM Music uploads),
-- which any experience may use. Set an id to "" to mute that cue.
Config.Sounds = {
	Pickup = { Id = "rbxassetid://9113244443", Volume = 0.6 }, -- Bag Drop Bag Bumping Wall 2
	Sell = { Id = "rbxassetid://9113849492", Volume = 0.8 }, -- Coins Or Keys Jingle 6
	Upgrade = { Id = "rbxassetid://9045119921", Volume = 0.5 }, -- Mascot Party - Mnemonic1 (APM)
	Siren = { Id = "rbxassetid://9113073742", Volume = 0.35 }, -- Air Raid Siren Old Fashioned 1
	Thunder = { Id = "rbxassetid://9113169432", Volume = 0.9 }, -- Artillery Distant 2 ("possible use: thunder")
	Rain = { Id = "rbxassetid://9112793871", Volume = 0.45 }, -- Heavy Rain 2 (loop)
	Flood = { Id = "rbxassetid://9114492638", Volume = 0.35 }, -- Flood Massive Flowing Water 1 (loop)
	Wind = { Id = "rbxassetid://9125742262", Volume = 0.5 }, -- Constant Airy Whooshing Windy (loop)
}

-- Monetization. Set IDs after creating products on the Creator Dashboard; 0 disables.
Config.GamePasses = {
	BigBag = {
		Id = 0,
		DisplayName = "Big Bag",
		Description = "+5 carry capacity forever.",
		BonusCapacity = 5,
	},
	VIP = { Id = 0, DisplayName = "VIP", Description = "+20% sell value forever.", SellMultiplier = 1.2 },
}

Config.DevProducts = {
	SalvageBoost = { Id = 0, DisplayName = "2x Salvage (15 min)", BoostSeconds = 15 * 60 },
	CoinPackSmall = { Id = 0, DisplayName = "500 Coins", Coins = 500 },
}

return Config
