--!strict
-- @file Salvage Detector rules: what a scan may reveal
-- @domain salvage-economy
-- @status stable
-- @see [[V3-SUPPLY-DEPOT]]
-- @tested-by [[detector.spec.luau]]
-- Pure rules for the Salvage Detector (a coin tool from the Gear Shop's Tools tab), shared by the
-- server and the unit tests. The server scans; the client only ever receives what `pick`
-- returns, so these rules are the whole of what the detector can reveal:
--   * ordinary salvage only (Config.Tools.Detector.Rarities): never Epic finds, never Storm Cores,
--     so the high-value finds still need exploring;
--   * never a dropped bag (another player's, or your own: you know where you died);
--   * horizontal range only, at most `max` results, nearest first.
-- It shows where to look; it never collects and never changes pickup range.

local Detector = {}

export type Candidate = {
	Id: string, -- loot instance key (stable while the item exists)
	X: number,
	Z: number,
	Rarity: string,
	Dropped: boolean,
}

export type Blip = { Id: string, X: number, Z: number, Distance: number }

function Detector.pick(
	originX: number,
	originZ: number,
	candidates: { Candidate },
	range: number,
	rarities: { [string]: boolean },
	max: number
): { Blip }
	local found: { Blip } = {}
	for _, c in candidates do
		if not c.Dropped and rarities[c.Rarity] then
			local dx, dz = c.X - originX, c.Z - originZ
			local d = math.sqrt(dx * dx + dz * dz)
			if d <= range then
				table.insert(found, { Id = c.Id, X = c.X, Z = c.Z, Distance = d })
			end
		end
	end
	table.sort(found, function(a, b)
		if a.Distance == b.Distance then
			return a.Id < b.Id
		end
		return a.Distance < b.Distance
	end)
	while #found > max do
		table.remove(found)
	end
	return found
end

-- Same set of blips (by id) as last time? The server only sends a ping when this changes.
function Detector.sameSet(a: { Blip }?, b: { Blip }): boolean
	if a == nil or #a ~= #b then
		return false
	end
	for i, blip in b do
		if a[i].Id ~= blip.Id then
			return false
		end
	end
	return true
end

return Detector
