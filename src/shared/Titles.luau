--!strict
-- @file Earned titles: what each one takes, and which a profile has earned (pure, unit-tested)
-- @domain progression
-- @status wip
-- @tested-by [[titles.spec.luau]]
-- @see [[V4-STATUS]]
-- Titles are earned, never bought: the server checks a profile's own records (extractions, the
-- Salvage Log, lifetime earnings, licences) and grants them. Players only choose which earned
-- title shows under their name. Skill and spectacle count as much as wealth: most titles come
-- from how you extract and what you find, only a few from coins.
-- Pure: no Roblox APIs, so `lune` tests it.

-- Roblox resolves the sibling ModuleScript; Lune (unit tests) resolves the file path.
local BigMoney = if script then require(script.Parent.BigMoney) else (require :: any)("./BigMoney")

local Titles = {}

export type View = {
	Records: { [string]: number }, -- Pursuit records (+ GoldenExtractions)
	Found: { [string]: boolean }, -- Salvage Log kinds found
	TotalEarned: number | string, -- lifetime earnings (BigMoney string, or a legacy number)
	Licenses: { [string]: boolean },
}

export type Def = {
	Id: string,
	Name: string,
	Category: "Pursuit" | "Discovery" | "Career" | "Wealth",
	How: string,
	earned: (View) -> boolean,
}

local function rec(v: View, key: string): number
	local n = v.Records[key]
	return if type(n) == "number" and n == n then n else 0
end

local BAND1_KINDS = {
	"Can",
	"Pipe",
	"Toaster",
	"Tv",
	"Tire",
	"Battery",
	"Engine",
	"Register",
	"Safe",
	"Jukebox",
	"StormCore",
	"GoldenCore",
}
Titles.Band1Kinds = BAND1_KINDS

Titles.List = {
	{
		Id = "Stormbreaker",
		Name = "Stormbreaker",
		Category = "Pursuit",
		How = "Extract an event core to the Scrapyard",
		earned = function(v)
			return rec(v, "Extractions") >= 1
		end,
	},
	{
		Id = "QuickHands",
		Name = "Quick Hands",
		Category = "Pursuit",
		How = "Extract a core in under 20 seconds",
		earned = function(v)
			local best = rec(v, "BestExtract")
			return best > 0 and best < 20
		end,
	},
	{
		Id = "Untouchable",
		Name = "Untouchable",
		Category = "Pursuit",
		How = "Extract 3 cores in a row without being caught",
		earned = function(v)
			return rec(v, "BestStreak") >= 3
		end,
	},
	{
		Id = "Daredevil",
		Name = "Daredevil",
		Category = "Pursuit",
		How = "Extract a core from the hardest site in town",
		earned = function(v)
			return rec(v, "Hardest") >= 3
		end,
	},
	{
		Id = "JackpotHunter",
		Name = "Jackpot Hunter",
		Category = "Pursuit",
		How = "Extract a Golden Storm Core",
		earned = function(v)
			return rec(v, "GoldenExtractions") >= 1
		end,
	},
	{
		Id = "Collector",
		Name = "Collector",
		Category = "Discovery",
		How = "Log every kind of town salvage, Golden Storm Core included",
		earned = function(v)
			for _, id in BAND1_KINDS do
				if not v.Found[id] then
					return false
				end
			end
			return true
		end,
	},
	{
		Id = "TurbineHunter",
		Name = "Turbine Hunter",
		Category = "Discovery",
		How = "Find a Turbine Rotor, the rarest industrial salvage",
		earned = function(v)
			return v.Found.TurbineRotor == true
		end,
	},
	{
		Id = "Professional",
		Name = "Professional",
		Category = "Career",
		How = "Earn the Pro Salvage License",
		earned = function(v)
			return v.Licenses.Pro == true
		end,
	},
	{
		Id = "StormHunter",
		Name = "Storm Hunter",
		Category = "Career",
		How = "Earn the Storm Hunter License",
		earned = function(v)
			return v.Licenses.Hunter == true
		end,
	},
	{
		Id = "EyeDiver",
		Name = "Eye Diver",
		Category = "Pursuit",
		How = "Deliver a Storm Heart from the Storm's Eye",
		earned = function(v)
			return rec(v, "EyeHearts") >= 1
		end,
	},
	{
		Id = "ArtifactCollector",
		Name = "Artifact Collector",
		Category = "Discovery",
		How = "Log a Gale Shard, a Tide Relic and a Fulgurite",
		earned = function(v)
			return v.Found.GaleShard == true and v.Found.TideRelic == true and v.Found.Fulgurite == true
		end,
	},
} :: { Def }

-- Wealth titles: lifetime-earnings milestones, so spending never takes one away. One per named
-- tier up to quintillions for now; more come with the bands that reach them.
local function earnedAtLeast(v: View, digits: string): boolean
	local have = BigMoney.parse(v.TotalEarned)
	return have ~= nil and BigMoney.gte(have, digits)
end
for _, w in
	{
		{ Id = "FirstFortune", Name = "First Fortune", Zeros = 6, Words = "1,000,000" },
		{ Id = "Billionaire", Name = "Billionaire", Zeros = 9, Words = "1 billion" },
		{ Id = "Trillionaire", Name = "Trillionaire", Zeros = 12, Words = "1 trillion" },
		{ Id = "Quadrillionaire", Name = "Quadrillionaire", Zeros = 15, Words = "1 quadrillion" },
		{ Id = "Quintillionaire", Name = "Quintillionaire", Zeros = 18, Words = "1 quintillion" },
	}
do
	local threshold = "1" .. string.rep("0", w.Zeros)
	table.insert(Titles.List, {
		Id = w.Id,
		Name = w.Name,
		Category = "Wealth",
		How = ("Earn %s coins in total"):format(w.Words),
		earned = function(v)
			return earnedAtLeast(v, threshold)
		end,
	})
end

Titles.ById = {} :: { [string]: Def }
for _, t in Titles.List do
	Titles.ById[t.Id] = t
end

-- Every title the view qualifies for, in list order.
function Titles.earned(v: View): { string }
	local out = {}
	for _, t in Titles.List do
		if t.earned(v) then
			table.insert(out, t.Id)
		end
	end
	return out
end

-- Titles qualified for but not yet owned (what to grant now).
function Titles.newlyEarned(v: View, owned: { [string]: boolean }): { string }
	local out = {}
	for _, id in Titles.earned(v) do
		if not owned[id] then
			table.insert(out, id)
		end
	end
	return out
end

-- Can a player show title `id`? Only an owned, real title (or nil to show their rank instead).
function Titles.canShow(id: unknown, owned: { [string]: boolean }): boolean
	if id == nil then
		return true
	end
	return type(id) == "string" and Titles.ById[id] ~= nil and owned[id] == true
end

-- Repairs a saved Titles table in place: { Owned = { [id] = true }, Shown = id? }. Unknown or
-- malformed entries are dropped; a shown title must be owned.
function Titles.reconcile(t: any): { Owned: { [string]: boolean }, Shown: string? }
	local out = if type(t) == "table" then t else {}
	if type(out.Owned) ~= "table" then
		out.Owned = {}
	end
	for id, v in out.Owned do
		if v ~= true or not Titles.ById[id] then
			out.Owned[id] = nil
		end
	end
	if not Titles.canShow(out.Shown, out.Owned) then
		out.Shown = nil
	end
	return out
end

return Titles
