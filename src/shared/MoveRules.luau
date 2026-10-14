-- @file Dodge and movement plausibility rules (pure, unit-tested)
-- @domain world
-- @status wip
-- @see [[DodgeService.luau]]
-- @see [[Dodge.luau]]
-- The server's rules for the dodge and for trusting a character's position. Movement is
-- client-owned on Roblox, so the server can't stop a client moving; what it controls is what a
-- move counts for. It only honours a dodge that respects the cooldown, and it judges hits on a
-- position it finds plausible: a jump further than running plus one honoured dodge could cover
-- is ignored, and the hit lands where the character last plausibly was.
-- Pure: no Roblox services, so `lune` can test it.

local MoveRules = {}

-- A dodge request at `now` after one honoured at `last` (nil = never). `tolerance` absorbs
-- network jitter between the client's clock and the server's arrival times.
function MoveRules.dodgeAllowed(now: number, last: number?, cooldown: number, tolerance: number): boolean
	return last == nil or now - last >= cooldown - tolerance
end

-- How far a character may plausibly move horizontally in `elapsed` seconds: `maxSpeed` (studs/s,
-- generous enough for sprinting downwind in a gust), plus `dodgeDistance` if an honoured dodge
-- falls in the window, plus a fixed `slack` for replication bursts.
function MoveRules.budget(elapsed: number, maxSpeed: number, dodgeDistance: number, slack: number): number
	return math.max(0, elapsed) * maxSpeed + dodgeDistance + slack
end

function MoveRules.plausible(
	distance: number,
	elapsed: number,
	maxSpeed: number,
	dodgeDistance: number,
	slack: number
): boolean
	return distance <= MoveRules.budget(elapsed, maxSpeed, dodgeDistance, slack)
end

return MoveRules
