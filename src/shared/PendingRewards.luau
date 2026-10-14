--!strict
-- @file Earned rewards that wait for a player who wasn't there to collect them
-- @domain progression
-- @status wip
-- @tested-by [[pendingrewards.spec.luau]]
-- @see [[RewardClaims.luau]]
-- @see [[V4-COOP]]
-- A cooperative share the server decided (Armored Wreck work) is never lost to a disconnect and
-- never handed to someone else: if its owner isn't there to pick it up, it's written as a pending
-- reward under their own user id and paid on their next join. Pure rules:
--   * one entry per share, with a unique Id (the event and the share), so it is paid exactly once
--     (the profile records claimed ids in the same write as the payment);
--   * bounded: at most MAX entries per player, each expires after TTL seconds;
--   * the payout is the items' sale value at the owner's own Salvage Press, exact (BigMoney).

local BigMoney = if script then require(script.Parent.BigMoney) else (require :: any)("./BigMoney")

local PendingRewards = {}

PendingRewards.TTL = 72 * 3600 -- a weekend away still collects
PendingRewards.MAX = 20
PendingRewards.CLAIM_MEMORY = 8 * 24 * 3600 -- claimed ids kept longer than any entry can live

export type Entry = { Id: string, Items: { string }, Source: string, At: number }
export type Record = { Entries: { Entry } }

-- `record` with `entry` added (if new), expired entries dropped, capped (oldest dropped first).
function PendingRewards.add(record: any, entry: Entry, now: number): Record
	local out: Record = { Entries = {} }
	local seen = false
	for _, e in (if type(record) == "table" and type(record.Entries) == "table" then record.Entries else {}) do
		if
			type(e) == "table"
			and type(e.Id) == "string"
			and type(e.At) == "number"
			and now - e.At < PendingRewards.TTL
		then
			table.insert(out.Entries, e)
			if e.Id == entry.Id then
				seen = true
			end
		end
	end
	if not seen then
		table.insert(out.Entries, entry)
	end
	table.sort(out.Entries, function(a, b)
		return a.At < b.At
	end)
	while #out.Entries > PendingRewards.MAX do
		table.remove(out.Entries, 1)
	end
	return out
end

-- The live entries in `record` (not expired, well formed).
function PendingRewards.live(record: any, now: number): { Entry }
	local out = {}
	for _, e in (if type(record) == "table" and type(record.Entries) == "table" then record.Entries else {}) do
		if
			type(e) == "table"
			and type(e.Id) == "string"
			and type(e.Items) == "table"
			and type(e.At) == "number"
		then
			if now - e.At < PendingRewards.TTL then
				table.insert(out, e)
			end
		end
	end
	return out
end

-- `record` without the entries whose ids are in `ids`.
function PendingRewards.remove(record: any, ids: { [string]: boolean }): Record
	local out: Record = { Entries = {} }
	for _, e in (if type(record) == "table" and type(record.Entries) == "table" then record.Entries else {}) do
		if type(e) == "table" and not ids[e.Id] then
			table.insert(out.Entries, e)
		end
	end
	return out
end

-- Exact coins for `items` (loot ids) at sale `factor`, from `values` (id -> base value).
function PendingRewards.value(items: { string }, values: { [string]: number }, factor: number): string
	local total = "0"
	for _, id in items do
		local v = values[id]
		if type(v) == "number" and v > 0 then
			total = BigMoney.add(total, BigMoney.of(v)) :: string
		end
	end
	return BigMoney.mulFactors(total, { factor }) :: string
end

-- Claimed-id memory in a profile: has `id` been paid? (`claimed` is { [id] = unix time }.)
function PendingRewards.claimed(claimed: any, id: string): boolean
	return type(claimed) == "table" and claimed[id] ~= nil
end

-- `claimed` with `id` recorded at `now` and ids older than CLAIM_MEMORY dropped.
function PendingRewards.remember(claimed: any, id: string, now: number): { [string]: number }
	local out = {}
	for k, t in (if type(claimed) == "table" then claimed else {}) do
		if type(k) == "string" and type(t) == "number" and now - t < PendingRewards.CLAIM_MEMORY then
			out[k] = t
		end
	end
	out[id] = now
	return out
end

return PendingRewards
