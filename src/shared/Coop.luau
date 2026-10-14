--!strict
-- @file Fair shares for cooperative events (Armored Wreck, Storm Titan)
-- @domain progression
-- @status wip
-- @tested-by [[coop.spec.luau]]
-- @see [[WreckService.luau]]
-- @see [[TitanService.luau]]
-- Pure maths for the server's reward split. Contributions are measured work (cut progress,
-- siphon), never presence.
--   shares       split N whole rewards by contribution (largest remainder), everyone above the
--                minimum fraction gets at least one when there are enough, nobody below it gets any
--   weightedPick one winner, chance proportional to contribution (the announced jackpot draw)
--   consolation  coins for a partial Titan siphon when the Titan ends

local Coop = {}

export type Contributions = { [string]: number }

-- Total of positive contributions.
local function total(c: Contributions): number
	local t = 0
	for _, v in c do
		if v > 0 then
			t += v
		end
	end
	return t
end

-- Contributors at or above `minFraction` of the total, in a stable order (largest first, then id).
function Coop.eligible(c: Contributions, minFraction: number): { string }
	local t = total(c)
	local out = {}
	if t <= 0 then
		return out
	end
	for id, v in c do
		if v > 0 and v / t >= minFraction then
			table.insert(out, id)
		end
	end
	table.sort(out, function(a, b)
		if c[a] ~= c[b] then
			return c[a] > c[b]
		end
		return a < b
	end)
	return out
end

-- Split `count` whole rewards among eligible contributors. Each eligible contributor gets one
-- first (while there are rewards to give, biggest contributors first), then the rest go by
-- largest remainder of their proportional share. Always sums to `count` if anyone is eligible.
function Coop.shares(c: Contributions, count: number, minFraction: number): { [string]: number }
	local ids = Coop.eligible(c, minFraction)
	local out: { [string]: number } = {}
	if #ids == 0 or count <= 0 then
		return out
	end
	local t = 0
	for _, id in ids do
		t += c[id]
	end
	local left = count
	for _, id in ids do
		if left <= 0 then
			break
		end
		out[id] = 1
		left -= 1
	end
	if left <= 0 then
		return out
	end
	-- The remaining rewards by proportional share of the whole count, minus the one already given.
	local wants = {}
	local given = 0
	for _, id in ids do
		local exact = math.max(0, count * c[id] / t - (out[id] or 0))
		local whole = math.floor(exact)
		whole = math.min(whole, left - given)
		out[id] = (out[id] or 0) + whole
		given += whole
		table.insert(wants, { Id = id, Rest = exact - math.floor(exact) })
	end
	table.sort(wants, function(a, b)
		if a.Rest ~= b.Rest then
			return a.Rest > b.Rest
		end
		return c[a.Id] > c[b.Id] or (c[a.Id] == c[b.Id] and a.Id < b.Id)
	end)
	local k = 1
	while given < left and #wants > 0 do
		local id = wants[(k - 1) % #wants + 1].Id
		out[id] += 1
		given += 1
		k += 1
	end
	return out
end

-- One eligible winner, chance proportional to contribution. `roll` in [0, 1).
function Coop.weightedPick(c: Contributions, roll: number, minFraction: number): string?
	local ids = Coop.eligible(c, minFraction)
	local t = 0
	for _, id in ids do
		t += c[id]
	end
	if t <= 0 then
		return nil
	end
	local acc = 0
	for _, id in ids do
		acc += c[id] / t
		if roll < acc then
			return id
		end
	end
	return ids[#ids]
end

-- Coins for a Titan siphon left at `progress` (0..1) when it ends: nothing below `floor`, then
-- linear up to `value` at a full meter (which would have been a core instead).
function Coop.consolation(progress: number, floor: number, value: number): number
	if type(progress) ~= "number" or progress ~= progress or progress < floor then
		return 0
	end
	return math.floor(math.min(progress, 1) * value)
end

return Coop
