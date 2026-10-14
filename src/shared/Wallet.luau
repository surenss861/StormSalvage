--!strict
-- @file A profile's money: cash and lifetime earnings, exact, with a rollback-safe legacy mirror
-- @domain salvage-economy
-- @status wip
-- @tested-by [[wallet.spec.luau]]
-- @see [[BigMoney.luau]]
-- @see [[V4-BIG-NUMBERS]]
-- Every coin a profile gains or spends goes through here (sales, bonuses, contracts, upgrades,
-- tools, licences, finishes, Robux packs), so there is one place that can change money.
--
-- Storage (schema 2): data.Wallet = { Schema = 2, Cash = "<digits>", Lifetime = "<digits>",
--   Mirror = { Coins = n, TotalEarned = n } }. Cash and Lifetime are exact BigMoney strings.
--
-- Rollback safety: older builds (RC10 and earlier) only know the numbers data.Coins and
-- data.Stats.TotalEarned. Those stay in the profile as a MIRROR: the exact balance while it is at
-- most LEGACY_CAP (1 Qa, RC10's own cap, so RC10 accepts it as valid), else LEGACY_CAP. The value
-- written is remembered in Wallet.Mirror. If an older build runs the profile meanwhile (a rollback,
-- or a player hopping to an old server during a deploy) and earns or spends, the mirror moves away
-- from what was written; on the next load here, that difference is applied to the exact balance.
-- So no build ever sees a string where it expects a number, and no progress is lost either way,
-- except coins an older build couldn't represent (earnings past its 1 Qa cap while rolled back).
--
-- Migration (schema 1 -> 2) converts the legacy numbers exactly (BigMoney.fromLegacyNumber).
-- A corrupt legacy value (NaN, infinite, negative) is never silently zeroed: the original is kept
-- in Wallet.Repaired and the load reports it, and the balance starts from 0.
-- Pure: no Roblox APIs, so `lune` tests it.

-- Roblox resolves the sibling ModuleScript; Lune (unit tests) resolves the file path.
local BigMoney = if script then require(script.Parent.BigMoney) else (require :: any)("./BigMoney")

local Wallet = {}

type Big = string -- a canonical BigMoney amount

Wallet.SCHEMA = 2
Wallet.LEGACY_CAP = 1e15

export type Report = { Migrated: boolean, Repaired: { string }, AppliedCash: string?, AppliedLifetime: string? }

local function mirrorOf(v: Big): number
	if #v <= 16 and BigMoney.cmp(v, "1000000000000000") <= 0 then
		return tonumber(v) :: number
	end
	return Wallet.LEGACY_CAP
end

local function writeMirror(data: any)
	local w = data.Wallet
	local coins, earned = mirrorOf(w.Cash), mirrorOf(w.Lifetime)
	data.Coins = coins
	if type(data.Stats) ~= "table" then
		data.Stats = {}
	end
	data.Stats.TotalEarned = earned
	w.Mirror = { Coins = coins, TotalEarned = earned }
end

-- What an older build did to a mirror since we wrote it: the signed change, or nil if it's
-- unusable (missing, corrupt) or unchanged.
local function legacyDelta(now: unknown, wrote: unknown): (string?, boolean)
	if type(now) ~= "number" or type(wrote) ~= "number" or now ~= now or wrote ~= wrote then
		return nil, false
	end
	if now == wrote then
		return nil, false
	end
	local a, b = BigMoney.fromLegacyNumber(now), BigMoney.fromLegacyNumber(wrote)
	if not a or not b then
		return nil, false
	end
	if BigMoney.gte(a, b) then
		return BigMoney.sub(a, b), true -- gained
	end
	return BigMoney.sub(b, a), false -- spent
end

-- Prepares a loaded profile: migrates schema 1, folds in changes an older build made, writes the
-- mirror. Call once per load, before anything reads money. Returns what happened.
function Wallet.load(data: any): Report
	local report: Report = { Migrated = false, Repaired = {} }
	if type(data.Stats) ~= "table" then
		data.Stats = {}
	end
	local w = data.Wallet
	if type(w) ~= "table" or not BigMoney.is(w.Cash) or not BigMoney.is(w.Lifetime) then
		-- Schema 1 (or a damaged wallet): convert the legacy numbers exactly.
		local cash = BigMoney.fromLegacyNumber(data.Coins)
		local life = BigMoney.fromLegacyNumber(data.Stats.TotalEarned)
		local repaired = {}
		if not cash then
			table.insert(repaired, "Coins=" .. tostring(data.Coins))
			table.insert(report.Repaired, "Coins")
		end
		if not life then
			table.insert(repaired, "TotalEarned=" .. tostring(data.Stats.TotalEarned))
			table.insert(report.Repaired, "TotalEarned")
		end
		data.Wallet = {
			Schema = Wallet.SCHEMA,
			Cash = cash or "0",
			Lifetime = life or "0",
			Repaired = if #repaired > 0 then repaired else nil,
		}
		report.Migrated = true
	else
		-- Schema 2: apply anything an older build did to the mirror meanwhile.
		local mirror = if type(w.Mirror) == "table" then w.Mirror else {}
		local d, gained = legacyDelta(data.Coins, mirror.Coins)
		if d then
			if gained then
				w.Cash = BigMoney.cap(BigMoney.add(w.Cash, d))
			else
				w.Cash = BigMoney.sub(w.Cash, d) or "0"
			end
			report.AppliedCash = (if gained then "+" else "-") .. d
		end
		local e, egained = legacyDelta(data.Stats.TotalEarned, mirror.TotalEarned)
		if e and egained then
			w.Lifetime = BigMoney.cap(BigMoney.add(w.Lifetime, e))
			report.AppliedLifetime = "+" .. e
		end
	end
	writeMirror(data)
	return report
end

function Wallet.cash(data: any): Big
	return data.Wallet.Cash
end

function Wallet.lifetime(data: any): Big
	return data.Wallet.Lifetime
end

function Wallet.canAfford(data: any, cost: unknown): boolean
	local c = BigMoney.parse(cost)
	return c ~= nil and BigMoney.gte(data.Wallet.Cash, c)
end

-- How much more is needed for `cost` ("0" if affordable).
function Wallet.shortBy(data: any, cost: unknown): Big
	local c = BigMoney.of(cost)
	return BigMoney.sub(c, data.Wallet.Cash) or "0"
end

-- Earned coins: added to cash and lifetime earnings (capped at BigMoney.MAX). Returns what was
-- actually added ("0" for an invalid amount).
function Wallet.earn(data: any, amount: unknown): Big
	local a = BigMoney.parse(amount)
	if not a or a == "0" then
		return "0"
	end
	local w = data.Wallet
	local before = w.Cash
	w.Cash = BigMoney.cap(BigMoney.add(before, a))
	local added = BigMoney.sub(w.Cash, before) :: Big
	w.Lifetime = BigMoney.cap(BigMoney.add(w.Lifetime, added))
	writeMirror(data)
	return added
end

-- Coins that aren't earnings (a purchased coin pack): cash only.
function Wallet.deposit(data: any, amount: unknown): Big
	local a = BigMoney.parse(amount)
	if not a or a == "0" then
		return "0"
	end
	local w = data.Wallet
	local before = w.Cash
	w.Cash = BigMoney.cap(BigMoney.add(before, a))
	writeMirror(data)
	return BigMoney.sub(w.Cash, before) :: Big
end

-- Spends `cost` if affordable. Invalid costs are refused.
function Wallet.spend(data: any, cost: unknown): boolean
	local c = BigMoney.parse(cost)
	if not c then
		return false
	end
	local after = BigMoney.sub(data.Wallet.Cash, c)
	if not after then
		return false
	end
	data.Wallet.Cash = after
	writeMirror(data)
	return true
end

-- Studio QA only: set cash exactly.
function Wallet.setCashForTest(data: any, amount: unknown)
	data.Wallet.Cash = BigMoney.cap(BigMoney.of(amount))
	writeMirror(data)
end

return Wallet
