-- @file Rollback reconciliation: RC8, RC9 and RC10 money semantics against Wallet, fuzzed
-- @domain qa
-- @status stable
-- @see [[Wallet.luau]]
-- @see [[V4-BIG-NUMBERS]]
-- Emulates exactly how each older build touches money (from their source at the tagged commits):
--   RC8 (2996d74) and RC9 (8ccc3ff): load fills missing fields only; earn: Coins += a and
--     Stats.TotalEarned += a; spend: if Coins >= cost then Coins -= cost. No cap, no validation.
--   RC10 (53fe778): load clamps an invalid Coins/TotalEarned (Money.valid/clamp, cap 1e15);
--     earn: Money.grant (floor, cap 1e15) and lifetime += the amount actually added; spend:
--     Money.spend (refuses invalid or unaffordable costs).
-- Then runs random chains of new-build sessions and older-build sessions (rollbacks and
-- roll-forwards, mixed-version hops) and checks after every new-build load:
--   * cash equals an independent exact oracle: the start, plus every spend and every earning
--     as each build itself credited it (RC10 credits only up to its 1 Qa cap: the documented
--     loss), never more, never less;
--   * lifetime never falls and matches its own oracle;
--   * the mirror equals min(cash, 1 Qa) and Wallet.Mirror records exactly what was written.
local W = require("../src/shared/Wallet")
local B = require("../src/shared/BigMoney")

local CAP = 1e15
local CAPS = "1000000000000000"

local function eq(a: any, b: any, what: string)
	if a ~= b then
		error(("%s: expected %s, got %s"):format(what, tostring(b), tostring(a)), 2)
	end
end

---------------------------------------------------------------- older builds

local Legacy = {}

function Legacy.load(build: string, d: any)
	if build == "RC10" then
		local function valid(n: any)
			return type(n) == "number" and n == n and n >= 0 and n <= CAP and n % 1 == 0
		end
		local function clamp(n: any)
			if type(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge then
				return 0
			end
			return math.clamp(math.floor(n), 0, CAP)
		end
		if not valid(d.Coins) then
			d.Coins = clamp(d.Coins)
		end
		if not valid(d.Stats.TotalEarned) then
			d.Stats.TotalEarned = clamp(d.Stats.TotalEarned)
		end
	end
	-- RC8/RC9: template fill only (money fields already present).
end

-- Returns what the build actually credited to cash, and to lifetime earnings.
function Legacy.earn(build: string, d: any, a: number): (number, number)
	if build == "RC10" then
		local b = d.Coins
		local after = math.min(CAP, b + math.floor(a))
		local added = after - b
		d.Coins = after
		local lb = d.Stats.TotalEarned
		d.Stats.TotalEarned = math.min(CAP, lb + added)
		return added, d.Stats.TotalEarned - lb
	end
	d.Coins += a
	d.Stats.TotalEarned += a
	return a, a
end

function Legacy.spend(build: string, d: any, cost: number): boolean
	if d.Coins < cost then
		return false
	end
	d.Coins -= cost
	return true
end

---------------------------------------------------------------- fuzz harness

local seed = 4242
local function rand(n: number): number
	seed = (seed * 1103515245 + 12345) % 2147483648
	-- High bits: an LCG's low bits cycle with a tiny period (bit 0 just alternates).
	return math.floor(seed / 65536) % n
end

-- Signed exact change as a BigMoney pair.
local function applySigned(v: string, delta: number): string
	if delta >= 0 then
		return B.add(v, B.of(delta))
	end
	return B.sub(v, B.of(-delta)) :: string
end

local function checkInvariants(d: any, label: string)
	local cash = W.cash(d)
	local expectMirror = if B.cmp(cash, CAPS) <= 0 then tonumber(cash) else CAP
	eq(d.Coins, expectMirror, label .. ": mirror coins")
	eq(d.Wallet.Mirror.Coins, d.Coins, label .. ": recorded mirror coins")
	eq(d.Wallet.Mirror.TotalEarned, d.Stats.TotalEarned, label .. ": recorded mirror lifetime")
	assert(B.is(cash) and B.is(W.lifetime(d)), label .. ": canonical strings")
end

local STARTS = {
	"0",
	"1",
	"999",
	"38900",
	"999999999999000",
	"999999999999999",
	"1000000000000000",
	"1000000000000001",
	"5000000000000002000",
	"123456789012345678901234567890",
}

local function scenario(n: number)
	local d = { Coins = 0, Stats = { TotalEarned = 0 } }
	W.load(d)
	local start = STARTS[1 + rand(#STARTS)]
	W.setCashForTest(d, start)
	local oracle = start
	local life = W.lifetime(d)
	checkInvariants(d, "scenario " .. n .. " start")
	for cycle = 1, 8 do
		local label = ("scenario %d cycle %d"):format(n, cycle)
		if rand(2) == 0 then
			-- A new-build session: exact earns/spends, some at or past the legacy cap.
			for _ = 1, 1 + rand(4) do
				local amount = if rand(4) == 0
					then "1000000000000" .. tostring(rand(1000))
					else tostring(1 + rand(200000))
				if rand(2) == 0 then
					local added = W.earn(d, amount)
					oracle = B.add(oracle, added)
					life = B.add(life, added)
				elseif W.spend(d, amount) then
					oracle = B.sub(oracle, amount) :: string
				end
			end
		else
			-- An older build runs the saved profile (rollback or a hop to an old server).
			local build = ({ "RC8", "RC9", "RC10" })[1 + rand(3)]
			Legacy.load(build, d)
			for _ = 1, 1 + rand(4) do
				local amount = if rand(3) == 0 then 1e14 + rand(1e6) else 1 + rand(200000)
				if rand(2) == 0 then
					local credited, lifeCredited = Legacy.earn(build, d, amount)
					oracle = applySigned(oracle, credited)
					life = B.add(life, B.of(lifeCredited))
				elseif Legacy.spend(build, d, amount) then
					oracle = applySigned(oracle, -amount)
				end
			end
		end
		-- The new build loads whatever was saved.
		W.load(d)
		eq(W.cash(d), oracle, label .. ": cash vs oracle")
		eq(W.lifetime(d), B.cap(life), label .. ": lifetime vs oracle")
		checkInvariants(d, label)
	end
	return d, life
end

return {
	["rollback: 600 random chains of RC8/RC9/RC10/new sessions stay exact"] = function()
		for n = 1, 600 do
			scenario(n)
		end
	end,
	["rollback: RC10 earning across its cap loses exactly the overflow, nothing else"] = function()
		local d = { Coins = 0, Stats = { TotalEarned = 0 } }
		W.load(d)
		W.setCashForTest(d, "999999999999990") -- 10 under 1 Qa
		Legacy.load("RC10", d)
		eq((Legacy.earn("RC10", d, 100)), 10, "RC10 credits only 10")
		W.load(d)
		eq(W.cash(d), CAPS, "exactly 1 Qa (90 lost: the documented RC10 loss)")
	end,
	["rollback: RC9 earning above the mirror cap is applied in full"] = function()
		local d = { Coins = 0, Stats = { TotalEarned = 0 } }
		W.load(d)
		W.earn(d, "7000000000000000000") -- 7 Qi: mirror shows 1 Qa
		Legacy.load("RC9", d)
		Legacy.earn("RC9", d, 150)
		Legacy.spend("RC9", d, 40)
		W.load(d)
		eq(W.cash(d), "7000000000000000110", "7 Qi + 150 - 40")
	end,
	["rollback: RC8 spending more than it can see is refused by RC8, so nothing goes negative"] = function()
		local d = { Coins = 0, Stats = { TotalEarned = 0 } }
		W.load(d)
		W.earn(d, "3000000000000000000") -- 3 Qi; RC8 sees 1 Qa
		Legacy.load("RC8", d)
		eq(Legacy.spend("RC8", d, 2e15), false, "RC8 can't spend past what it sees")
		eq(Legacy.spend("RC8", d, CAP), true, "but can spend all of it")
		W.load(d)
		eq(W.cash(d), "2999000000000000000", "3 Qi - 1 Qa")
	end,
	["rollback: repeated old-new-old-new with no money change never drifts"] = function()
		local d = { Coins = 0, Stats = { TotalEarned = 0 } }
		W.load(d)
		W.earn(d, "123456789012345678901234567890")
		for i = 1, 50 do
			Legacy.load(({ "RC8", "RC9", "RC10" })[1 + i % 3], d)
			W.load(d)
		end
		eq(W.cash(d), "123456789012345678901234567890", "exact after 50 round trips")
		checkInvariants(d, "after 50")
	end,
	["rollback: an older build that saves twice before the new build returns is one delta"] = function()
		local d = { Coins = 0, Stats = { TotalEarned = 0 } }
		W.load(d)
		W.setCashForTest(d, "50000")
		-- Two RC10 sessions in a row (two rollback days) with no new-build load between.
		Legacy.load("RC10", d)
		Legacy.spend("RC10", d, 1000)
		Legacy.load("RC10", d)
		Legacy.earn("RC10", d, 300)
		W.load(d)
		eq(W.cash(d), "49300", "50,000 - 1,000 + 300")
	end,
}
