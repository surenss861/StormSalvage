-- @file Salvage Log rules (pure, unit-tested)
-- @domain progression
-- @status wip
-- @see [[ContractService.luau]]
-- @see [[Jobs.luau]]
-- The Salvage Log: which kinds of salvage a player has found, and how many of each, for life.
-- Profile shape: Collection = { Found = { [lootId] = true }, Counts = { [lootId] = n } }.
-- Only fresh finds count; the caller skips recoveries of dropped bags (the item was already
-- counted when it was first picked up). Pure: no Roblox services, so `lune` can test it.

local SalvageLog = {}

export type Collection = { Found: { [string]: boolean }, Counts: { [string]: number } }

-- Repairs a saved collection in place (older saves have Found only) and returns it.
function SalvageLog.reconcile(collection: any): Collection
	local c = if type(collection) == "table" then collection else {}
	if type(c.Found) ~= "table" then
		c.Found = {}
	end
	if type(c.Counts) ~= "table" then
		c.Counts = {}
	end
	for id, n in c.Counts do
		if type(n) ~= "number" or n ~= n or n < 0 then
			c.Counts[id] = nil
		else
			c.Counts[id] = math.floor(n)
		end
	end
	-- A kind found before counts existed has been found at least once.
	for id, found in c.Found do
		if found and (c.Counts[id] or 0) < 1 then
			c.Counts[id] = 1
		end
	end
	return c
end

-- Records one fresh find of `lootId`. Returns whether it is the first ever (a discovery) and the
-- new lifetime count. Unknown ids (not in `known`) change nothing.
function SalvageLog.record(
	collection: Collection,
	lootId: string,
	known: { [string]: any }
): (boolean, number)
	if not known[lootId] then
		return false, 0
	end
	local first = not collection.Found[lootId]
	collection.Found[lootId] = true
	local n = (collection.Counts[lootId] or 0) + 1
	collection.Counts[lootId] = n
	return first, n
end

-- Kinds discovered out of all kinds in `known`.
function SalvageLog.progress(collection: Collection, known: { [string]: any }): (number, number)
	local count, total = 0, 0
	for id in known do
		total += 1
		if collection.Found[id] then
			count += 1
		end
	end
	return count, total
end

local RARITY_ORDER = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6 }

-- The order the Log shows entries in: by rarity, then by value, then by id (stable).
-- `known` maps id -> a def with Rarity and Value.
function SalvageLog.order(known: { [string]: any }): { string }
	local ids = {}
	for id in known do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		local ra, rb = RARITY_ORDER[known[a].Rarity] or 0, RARITY_ORDER[known[b].Rarity] or 0
		if ra ~= rb then
			return ra < rb
		end
		if known[a].Value ~= known[b].Value then
			return known[a].Value < known[b].Value
		end
		return a < b
	end)
	return ids
end

return SalvageLog
