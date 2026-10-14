--!strict
-- @file The premium catalogue: game passes and developer products (all off until activation)
-- @domain salvage-economy
-- @status wip
-- @tested-by [[catalog.spec.luau]]
-- @see [[V4-CATALOG]]
-- Pure data (no Roblox types) so the unit tests can check the catalogue's rules: everything off
-- in the repo, fixed pack amounts, packs no more than ~30% of a band's gear, supporter finishes
-- paid-only. Config re-exports it (Config.PurchasesEnabled / GamePasses / DevProducts).

local Catalog = {}

Catalog.PurchasesEnabled = false
Catalog.GamePasses = {
	HeavyDuty = {
		Id = 0,
		DisplayName = "Heavy-Duty Pack",
		-- +2 (owner decision 2026-10-13): +4 gave +54% income in a matched 15-min test.
		Description = "+2 bag slots on top of your Backpack upgrades. Permanent.",
		BonusCapacity = 2,
		RobuxPrice = 149,
	},
	-- V4 M8 supporter finishes (Progression.PremiumFinishes): cosmetic nameplates, nothing else.
	NeonStorm = {
		Id = 0,
		DisplayName = "Neon Storm Nameplate",
		Description = "A supporter nameplate finish. Cosmetic only; marked SUPPORTER on your card.",
		Finish = "NeonStorm",
		RobuxPrice = 99,
	},
	GildedWreck = {
		Id = 0,
		DisplayName = "Gilded Wreck Nameplate",
		Description = "A supporter nameplate finish. Cosmetic only; marked SUPPORTER on your card.",
		Finish = "GildedWreck",
		RobuxPrice = 99,
	},
}
Catalog.DevProducts = {
	CoinsSmall = { Id = 0, DisplayName = "Pocket Change", Coins = 300, RobuxPrice = 29, Order = 1 },
	CoinsMedium = { Id = 0, DisplayName = "Scrap Bundle", Coins = 1200, RobuxPrice = 99, Order = 2 },
	CoinsLarge = { Id = 0, DisplayName = "Salvage Haul", Coins = 3000, RobuxPrice = 199, Order = 3 },
	-- V4 M8 high-scale packs: still FIXED amounts (receipt safety: a product grants the same
	-- coins whoever buys it, so retries and restores are exact), shown from the band where they
	-- matter (MinBand). Each is at most ~30% of that band's whole gear track (catalog test).
	CoinsIndustrial = {
		Id = 0,
		DisplayName = "Industrial Crate",
		Coins = 1000000,
		RobuxPrice = 299,
		Order = 4,
		MinBand = 2,
	},
	CoinsHunter = {
		Id = 0,
		DisplayName = "Hunter Cache",
		Coins = 80000000,
		RobuxPrice = 499,
		Order = 5,
		MinBand = 3,
	},
	CoinsVault = {
		Id = 0,
		DisplayName = "Vault Haul",
		Coins = 50000000000,
		RobuxPrice = 799,
		Order = 6,
		MinBand = 4,
	},
	CoinsLegend = {
		Id = 0,
		DisplayName = "Legend Hoard",
		Coins = 3000000000000,
		RobuxPrice = 999,
		Order = 7,
		MinBand = 5,
	},
}

return Catalog
