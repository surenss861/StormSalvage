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

export type Records = { Extractions: number, BestExtract: number }

-- Applies a successful extraction taking `seconds`. Returns whether it was a personal best.
function Pursuit.record(records: Records, seconds: number): boolean
	assert(seconds == seconds and seconds >= 0 and seconds < math.huge, "invalid time")
	records.Extractions += 1
	if records.BestExtract <= 0 or seconds < records.BestExtract then
		records.BestExtract = math.floor(seconds * 10 + 0.5) / 10
		return true
	end
	return false
end

return Pursuit
