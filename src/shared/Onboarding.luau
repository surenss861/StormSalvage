--!strict
-- @file First-session guidance: the next thing a new player should learn, from their own progress
-- @domain progression
-- @status wip
-- @tested-by [[onboarding.spec.luau]]
-- @see [[Onboarding.client]]
-- No separate tutorial: guidance follows play. Each step is derived from the player's saved
-- progress (so it survives a rejoin) plus what's happening right now, and gives way the moment
-- something more urgent happens (a storm, an event, carrying a core). The seven lessons:
--   1 Collect   grab glowing salvage                      (nothing sold yet, bag empty)
--   2 Sell      sell your bag at the Scrap Buyer          (carrying, nothing sold yet)
--   3 Storm     a storm is coming: get under a roof / up the hill (no storm seen yet)
--   4 Event     an event is on: race for it                (no extraction yet, an event is live)
--   5 Escape    carrying a core: get it to the Scrapyard   (any time a core is in the bag)
--   6 Spend     you can afford gear: the Gear Shop          (no upgrade bought yet)
--   7 Licence   work toward the next licence                (until the Pro licence)
-- After that: nil (the objective note shows the pinned job).

local Onboarding = {}

export type Live = {
	Phase: string, -- storm phase: "Calm" | "Warning" | "Storm" | "Aftermath"
	EventLive: boolean, -- a cache event or rush is running
	CarryingCore: boolean,
	CanAffordUpgrade: boolean,
}

export type Progress = {
	ItemsSold: number,
	Carried: number,
	Capacity: number,
	StormsSeen: number, -- storms lived through anywhere (sheltering counts)
	Extractions: number,
	RushFinds: number,
	Upgrades: number, -- levels bought, all gear
	HasPro: boolean,
}

export type Step = { Id: string, Index: number, Text: string, Target: string? }

-- Targets the client knows how to find: "Loot" (nearest takeable salvage), "Sell" (the Scrap
-- Buyer), "Plateau" (the safe Scrapyard), "Event" (the live event's site), "Shop" (the Gear Shop).
function Onboarding.step(p: Progress, live: Live): Step?
	-- Urgent lessons first: they interrupt whatever else is being taught.
	if live.CarryingCore and p.Extractions < 1 then
		return {
			Id = "Escape",
			Index = 5,
			Text = "You have a core! Get it to the Scrapyard on the hill.",
			Target = "Plateau",
		}
	end
	if (live.Phase == "Warning" or live.Phase == "Storm") and p.StormsSeen < 1 then
		return {
			Id = "Storm",
			Index = 3,
			Text = if live.Phase == "Warning"
				then "A storm is coming! Head for a roof or the Scrapyard."
				else "Stay sheltered: under a roof, or up on the Scrapyard.",
			Target = "Plateau",
		}
	end
	if live.EventLive and p.Extractions < 1 and p.RushFinds < 1 and p.ItemsSold > 0 then
		return {
			Id = "Event",
			Index = 4,
			Text = "An event is on! Race to the beam for a big prize.",
			Target = "Event",
		}
	end
	-- The loop.
	if p.ItemsSold < 1 then
		if p.Carried < 1 then
			return { Id = "Collect", Index = 1, Text = "Grab glowing salvage in town.", Target = "Loot" }
		end
		return {
			Id = "Sell",
			Index = 2,
			Text = if p.Carried >= p.Capacity
				then "Bag full! Sell it at the Scrap Buyer on the hill."
				else "Grab more, or sell at the Scrap Buyer on the hill.",
			Target = if p.Carried >= p.Capacity then "Sell" else "Loot",
		}
	end
	if p.Upgrades < 1 then
		if live.CanAffordUpgrade then
			return {
				Id = "Spend",
				Index = 6,
				Text = "You can afford gear! Visit the Gear Shop.",
				Target = "Shop",
			}
		end
		return {
			Id = "Spend",
			Index = 6,
			Text = "Salvage and sell to afford your first gear.",
			Target = "Loot",
		}
	end
	if not p.HasPro then
		return {
			Id = "Licence",
			Index = 7,
			Text = "Work toward the Pro licence (Gear Shop · Supply Counter).",
			Target = nil,
		}
	end
	return nil
end

return Onboarding
