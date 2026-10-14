--!strict
-- @file Contract, rank and finish rules
-- @domain progression
-- @status stable
-- @see [[V3-PROGRESSION]]
-- @tested-by [[progression.spec.luau]]
-- Salvage Contracts and Salvager Reputation: the rules, as pure functions so the server, the
-- client UI and the unit tests (tests/progression.spec.luau) share one definition.
--
--   Contracts   three active jobs at a time, each a real server-verified action (collect, sell,
--               earn from sales, survive a storm in town, deliver a Storm Core, salvage in a named
--               district). Finishing one pays coins + XP and deals a new job straight away.
--   Reputation  Salvager XP, never spent, from jobs (most), salvage sold and storms survived.
--               Ranks are titles: they unlock nameplate finishes, never stats or multipliers.
--   Finishes    nameplate styles bought with coins once your rank allows: the long-term coin
--               sink after equipment is maxed. Purely cosmetic.
-- No Roblox APIs here.

-- Roblox resolves the sibling ModuleScript; Lune (unit tests) resolves the file path.
local BigMoney = if script then require(script.Parent.BigMoney) else (require :: any)("./BigMoney")

local Progression = {}

---------------------------------------------------------------------------- Ranks

export type Rank = { Index: number, Title: string, XP: number }

Progression.Ranks = {
	{ Index = 1, Title = "Scrap Rookie", XP = 0 },
	{ Index = 2, Title = "Scavenger", XP = 150 },
	{ Index = 3, Title = "Salvager", XP = 400 },
	{ Index = 4, Title = "Storm Runner", XP = 900 },
	{ Index = 5, Title = "Wreck Diver", XP = 2000 },
	{ Index = 6, Title = "Yard Boss", XP = 4500 },
	{ Index = 7, Title = "Storm Legend", XP = 9000 },
} :: { Rank }

function Progression.rankFor(xp: number): Rank
	local best = Progression.Ranks[1]
	for _, r in Progression.Ranks do
		if xp >= r.XP then
			best = r
		end
	end
	return best
end

-- The next rank, or nil at the top.
function Progression.nextRank(xp: number): Rank?
	return Progression.Ranks[Progression.rankFor(xp).Index + 1]
end

-- XP for things other than jobs.
Progression.XP_PER_ITEM_SOLD = 1
Progression.XP_PER_STORM_SURVIVED = 10

---------------------------------------------------------------------------- Contracts

export type Contract = {
	Id: string,
	Kind: string,
	Target: number,
	Progress: number,
	Coins: number,
	XP: number,
	Zone: string?,
}

-- Base target and reward at rank 1; both grow 35% per rank so jobs keep pace with better gear.
-- Coin rewards tuned from a 10-min bot run (V3-PROGRESSION.md): jobs ~25% of income, not more.
Progression.Kinds = {
	Collect = { Target = 8, Coins = 25, XP = 25 },
	Zone = { Target = 4, Coins = 35, XP = 35 },
	Sell = { Target = 8, Coins = 25, XP = 25 },
	Earn = { Target = 150, Coins = 30, XP = 30 },
	Survive = { Target = 1, Coins = 60, XP = 50, Fixed = true },
	Core = { Target = 1, Coins = 80, XP = 60, Fixed = true },
} :: { [string]: any }
Progression.KindOrder = { "Collect", "Zone", "Sell", "Earn", "Survive", "Core" }

-- District names as the server's loot zones call them, and how players see them.
Progression.Zones = {
	Houses = "the Houses",
	Supermarket = "the Supermarket",
	GasStation = "Fuel & Go",
	Warehouse = "the Warehouse",
	Motel = "the Motel",
	TownSquare = "Town Square",
	RailYard = "the Rail Yard",
	FloodWorks = "Flood Control",
	Ballpark = "the Ballpark",
	Trailers = "Pine Rest",
} :: { [string]: string }
Progression.ZoneOrder = {
	"Houses",
	"Supermarket",
	"GasStation",
	"Warehouse",
	"Motel",
	"TownSquare",
	"RailYard",
	"FloodWorks",
	"Ballpark",
	"Trailers",
}

Progression.ACTIVE = 3
Progression.SWAP_COOLDOWN = 120 -- seconds between free job swaps (session-only)

local function scaled(base: number, rank: number, round: number): number
	local v = base * (1 + 0.35 * (rank - 1))
	return math.max(round, math.floor(v / round + 0.5) * round)
end

-- A new job of `kind` for a player at `rank`. `pick` returns 1..n (the server passes a Random);
-- it chooses the district for Zone jobs.
function Progression.make(kind: string, rank: number, serial: number, pick: (n: number) -> number): Contract
	local k = Progression.Kinds[kind]
	assert(k, "unknown contract kind " .. tostring(kind))
	local target = if k.Fixed then k.Target else scaled(k.Target, rank, if kind == "Earn" then 50 else 1)
	return {
		Id = "c" .. serial,
		Kind = kind,
		Target = target,
		Progress = 0,
		Coins = scaled(k.Coins, rank, 5),
		XP = scaled(k.XP, rank, 5),
		Zone = if kind == "Zone" then Progression.ZoneOrder[pick(#Progression.ZoneOrder)] else nil,
	}
end

-- Picks a kind not already active, so the three jobs are always different.
function Progression.pickKind(active: { Contract }, pick: (n: number) -> number): string
	local free = {}
	for _, kind in Progression.KindOrder do
		local used = false
		for _, c in active do
			if c.Kind == kind then
				used = true
			end
		end
		if not used then
			table.insert(free, kind)
		end
	end
	if #free == 0 then
		free = Progression.KindOrder
	end
	return free[pick(#free)]
end

-- Player-facing description: "Sell 8 salvage", "Salvage 4 items at the Motel".
function Progression.describe(c: Contract): string
	local n = c.Target
	if c.Kind == "Collect" then
		return ("Collect %d salvage"):format(n)
	elseif c.Kind == "Zone" then
		return ("Salvage %d items at %s"):format(n, Progression.Zones[c.Zone or ""] or "a district")
	elseif c.Kind == "Sell" then
		return ("Sell %d salvage"):format(n)
	elseif c.Kind == "Earn" then
		return ("Earn %d coins from sales"):format(n)
	elseif c.Kind == "Survive" then
		return "Survive a storm in town"
	elseif c.Kind == "Core" then
		return "Deliver a Storm Core"
	end
	return c.Kind
end

-- Game events the server reports. Returns how much each event advances a job (0 if unrelated).
export type Event = {
	Type: "Collected" | "Sold" | "Survived",
	Items: number?, -- Collected: 1; Sold: items in the sale
	Zone: string?, -- Collected: district of the item, nil for Storm Cores and dropped bags
	Coins: number?, -- Sold: payout
	Cores: number?, -- Sold: Storm Cores in the sale
}
function Progression.advance(c: Contract, e: Event): number
	if e.Type == "Collected" then
		if c.Kind == "Collect" then
			return e.Items or 0
		elseif c.Kind == "Zone" and e.Zone ~= nil and e.Zone == c.Zone then
			return e.Items or 0
		end
	elseif e.Type == "Sold" then
		if c.Kind == "Sell" then
			return e.Items or 0
		elseif c.Kind == "Earn" then
			return e.Coins or 0
		elseif c.Kind == "Core" then
			return e.Cores or 0
		end
	elseif e.Type == "Survived" and c.Kind == "Survive" then
		return 1
	end
	return 0
end

---------------------------------------------------------------------------- Nameplate finishes

export type Finish = {
	Id: string,
	Name: string,
	Cost: number,
	Rank: number,
	Plate: { number }, -- RGB
	Edge: { number },
	Text: { number },
}

Progression.Finishes = {
	{
		Id = "Cardboard",
		Name = "Cardboard",
		Cost = 0,
		Rank = 1,
		Plate = { 206, 168, 118 },
		Edge = { 146, 108, 66 },
		Text = { 34, 30, 28 },
	},
	{
		Id = "Tin",
		Name = "Galvanised Tin",
		Cost = 500,
		Rank = 2,
		Plate = { 190, 196, 200 },
		Edge = { 104, 110, 116 },
		Text = { 34, 30, 28 },
	},
	{
		Id = "Brass",
		Name = "Brass Plate",
		Cost = 1500,
		Rank = 3,
		Plate = { 214, 172, 74 },
		Edge = { 140, 100, 30 },
		Text = { 50, 32, 10 },
	},
	{
		Id = "Hazard",
		Name = "Hazard Stripe",
		Cost = 3000,
		Rank = 4,
		Plate = { 250, 200, 40 },
		Edge = { 30, 30, 30 },
		Text = { 20, 20, 20 },
	},
	{
		Id = "Copper",
		Name = "Copper Patina",
		Cost = 5000,
		Rank = 5,
		Plate = { 96, 170, 150 },
		Edge = { 170, 100, 60 },
		Text = { 245, 240, 230 },
	},
	{
		Id = "Chrome",
		Name = "Chrome",
		Cost = 8000,
		Rank = 6,
		Plate = { 228, 234, 240 },
		Edge = { 120, 130, 145 },
		Text = { 30, 40, 60 },
	},
	{
		Id = "StormGlass",
		Name = "Storm Glass",
		Cost = 12000,
		Rank = 7,
		Plate = { 40, 70, 120 },
		Edge = { 120, 220, 255 },
		Text = { 220, 245, 255 },
	},
} :: { Finish }

function Progression.finish(id: unknown): Finish?
	for _, f in Progression.Finishes do
		if f.Id == id then
			return f
		end
	end
	return nil
end

-- Can a player with `coins`, `xp` and `owned` buy finish `id`? Reason: "unknown", "owned",
-- "rank", "short".
function Progression.canBuyFinish(
	id: unknown,
	coins: number | string,
	xp: number,
	owned: { [string]: boolean }
): (boolean, string?)
	local f = Progression.finish(id)
	if not f then
		return false, "unknown"
	end
	if owned[f.Id] then
		return false, "owned"
	end
	if Progression.rankFor(xp).Index < f.Rank then
		return false, "rank"
	end
	local have = BigMoney.parse(coins)
	if not have or BigMoney.lt(have, BigMoney.of(f.Cost)) then
		return false, "short"
	end
	return true, nil
end

return Progression
