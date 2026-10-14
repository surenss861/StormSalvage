--!strict
-- @file Storm Pursuit rules: twister movement, catches, strikes, records
-- @domain world
-- @status wip
-- @see [[PursuitService.luau]]
-- @see [[V4-GAMEPLAY]]
-- @tested-by [[pursuit.spec.luau]]
-- Pure rules for the Storm Pursuit event, shared by the server (authoritative) and the unit tests.
-- Positions are flat (X, Z): the twister moves over the ground plane and passes through buildings,
-- so open roads are the fast escape and corners cost the runner, not the twister.

local Pursuit = {}

export type Vec2 = { X: number, Z: number }

-- Moves `from` toward `to` by at most speed * dt. Returns the new position and remaining distance.
function Pursuit.step(from: Vec2, to: Vec2, speed: number, dt: number): (Vec2, number)
	local dx, dz = to.X - from.X, to.Z - from.Z
	local d = math.sqrt(dx * dx + dz * dz)
	local move = speed * dt
	if d <= move or d == 0 then
		return { X = to.X, Z = to.Z }, 0
	end
	return { X = from.X + dx / d * move, Z = from.Z + dz / d * move }, d - move
end

-- Twister speed `seconds` into a chase: ramps from `start` by `ramp` per second up to `max`.
function Pursuit.speedAt(seconds: number, start: number, ramp: number, max: number): number
	return math.min(max, start + math.max(0, seconds) * ramp)
end

function Pursuit.distance(a: Vec2, b: Vec2): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

function Pursuit.caught(twister: Vec2, carrier: Vec2, radius: number): boolean
	return Pursuit.distance(twister, carrier) <= radius
end

-- Where a strike aims: ahead of the carrier along their current velocity, so standing still is
-- safe from the lead but running in a straight line isn't. Always telegraphed first.
function Pursuit.leadPoint(carrier: Vec2, velocity: Vec2, lead: number): Vec2
	return { X = carrier.X + velocity.X * lead, Z = carrier.Z + velocity.Z * lead }
end

-- The twister spawns `behind` studs from the carrier, on the side of the cache (it came out of the
-- storm there), so the first seconds are a head start, not a trap.
function Pursuit.spawnPoint(carrier: Vec2, cache: Vec2, behind: number): Vec2
	local dx, dz = cache.X - carrier.X, cache.Z - carrier.Z
	local d = math.sqrt(dx * dx + dz * dz)
	if d < 0.001 then
		dx, dz, d = 0, 1, 1
	end
	return { X = carrier.X + dx / d * behind, Z = carrier.Z + dz / d * behind }
end

export type Records = {
	Extractions: number,
	BestExtract: number,
	Streak: number, -- extractions in a row without being caught
	BestStreak: number,
	Hardest: number, -- highest site difficulty extracted from
	RushFinds: number,
}

function Pursuit.newRecords(): Records
	return { Extractions = 0, BestExtract = 0, Streak = 0, BestStreak = 0, Hardest = 0, RushFinds = 0 }
end

-- Fills fields missing from older profiles (the first V4 build saved only two of them).
function Pursuit.reconcile(records: any): Records
	local out = if type(records) == "table" then records else {}
	for k, v in Pursuit.newRecords() do
		if type(out[k]) ~= "number" or out[k] ~= out[k] then
			out[k] = v
		end
	end
	return out :: Records
end

export type RecordResult = { Best: boolean, Streak: number, NewHardest: boolean }

-- Applies a successful extraction taking `seconds` from a site of `difficulty`. `clean` means the
-- carrier was never caught during this event (streaks count clean extractions in a row).
function Pursuit.record(records: Records, seconds: number, difficulty: number?, clean: boolean?): RecordResult
	assert(seconds == seconds and seconds >= 0 and seconds < math.huge, "invalid time")
	records.Extractions += 1
	local best = false
	if records.BestExtract <= 0 or seconds < records.BestExtract then
		records.BestExtract = math.floor(seconds * 10 + 0.5) / 10
		best = true
	end
	if clean == false then
		records.Streak = 0
	else
		records.Streak += 1
		records.BestStreak = math.max(records.BestStreak, records.Streak)
	end
	local d = difficulty or 0
	local newHardest = d > records.Hardest
	if newHardest then
		records.Hardest = d
	end
	return { Best = best, Streak = records.Streak, NewHardest = newHardest }
end

-- A failed event (out of time, or the core lost) breaks the streak.
function Pursuit.breakStreak(records: Records)
	records.Streak = 0
end

-- Next event: never the same kind or the same site twice in a row. `random(n)` returns 1..n.
function Pursuit.pickNext(
	lastKind: string?,
	lastSite: string?,
	kinds: { string },
	siteIds: { string },
	random: (number) -> number
): (string, string)
	local k = {}
	for _, kind in kinds do
		if kind ~= lastKind then
			table.insert(k, kind)
		end
	end
	local s = {}
	for _, id in siteIds do
		if id ~= lastSite then
			table.insert(s, id)
		end
	end
	if #k == 0 then
		k = kinds
	end
	if #s == 0 then
		s = siteIds
	end
	return k[random(#k)], s[random(#s)]
end

-- A surge point `ahead` studs from the carrier along the straight line to `goal`.
function Pursuit.surgePoint(carrier: Vec2, goal: Vec2, ahead: number): Vec2
	local dx, dz = goal.X - carrier.X, goal.Z - carrier.Z
	local d = math.sqrt(dx * dx + dz * dz)
	if d < 0.001 then
		return { X = carrier.X, Z = carrier.Z }
	end
	local t = math.min(ahead, d)
	return { X = carrier.X + dx / d * t, Z = carrier.Z + dz / d * t }
end

-- The cache's prize, decided once when the event spawns: a Golden Storm Core with probability
-- `goldenChance`, otherwise an ordinary Storm Core. `roll()` returns a number in [0, 1).
function Pursuit.pickPrize(goldenChance: number, roll: () -> number): string
	return if roll() < goldenChance then "GoldenCore" else "StormCore"
end

return Pursuit
