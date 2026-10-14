-- @file Dodge and movement plausibility unit tests
-- @domain qa
-- @status stable
-- @see [[MoveRules.luau]]
local MoveRules = require("../src/shared/MoveRules")

local function eq(a: any, b: any, what: string)
	if a ~= b then
		error(("%s: expected %s, got %s"):format(what, tostring(b), tostring(a)), 2)
	end
end

-- The shipped numbers (Config.Dodge): cooldown 2.5, tolerance 0.2, burst 58 x 0.22, slack 6.
local COOLDOWN, TOLERANCE, SLACK = 2.5, 0.2, 6
local DODGE = 58 * 0.22
local MAX = 34 * 1.75 -- top Boots sprint, generous for gusts

return {
	["dodge: first one is allowed"] = function()
		eq(MoveRules.dodgeAllowed(10, nil, COOLDOWN, TOLERANCE), true, "first")
	end,
	["dodge: cooldown is enforced with a small jitter allowance"] = function()
		eq(MoveRules.dodgeAllowed(11.0, 10, COOLDOWN, TOLERANCE), false, "1.0 s later")
		eq(MoveRules.dodgeAllowed(12.2, 10, COOLDOWN, TOLERANCE), false, "2.2 s later")
		eq(MoveRules.dodgeAllowed(12.3, 10, COOLDOWN, TOLERANCE), true, "2.3 s later (jitter)")
		eq(MoveRules.dodgeAllowed(12.5, 10, COOLDOWN, TOLERANCE), true, "2.5 s later")
	end,
	["dodge: spamming can't beat the cooldown on average"] = function()
		-- A client firing every 0.1 s for 20 s gets at most one honoured dodge per 2.3 s.
		local last: number? = nil
		local honoured = 0
		for i = 0, 200 do
			local now = i * 0.1
			if MoveRules.dodgeAllowed(now, last, COOLDOWN, TOLERANCE) then
				honoured += 1
				last = now
			end
		end
		assert(honoured <= math.floor(20 / (COOLDOWN - TOLERANCE)) + 1, "honoured " .. honoured)
	end,
	["movement: sprinting and an honoured dodge are plausible"] = function()
		eq(MoveRules.plausible(34 * 0.5, 0.5, MAX, 0, SLACK), true, "half a second of top sprint")
		eq(MoveRules.plausible(34 * 0.5 + DODGE, 0.5, MAX, DODGE, SLACK), true, "sprint plus dodge")
	end,
	["movement: a teleport is not"] = function()
		eq(MoveRules.plausible(60, 0.5, MAX, 0, SLACK), false, "60 studs in 0.5 s")
		eq(MoveRules.plausible(60, 0.5, MAX, DODGE, SLACK), false, "even with a dodge")
	end,
	["movement: an unhonoured dodge doesn't get the dodge allowance"] = function()
		-- Standing still, then a dodge's worth plus a sprint step: fine only if the dodge counted.
		local d = 34 * 0.5 * 1.75 + DODGE + SLACK - 0.5
		eq(MoveRules.plausible(d, 0.5, MAX, DODGE, SLACK), true, "honoured")
		eq(MoveRules.plausible(d, 0.5, MAX, 0, SLACK), false, "refused")
	end,
	["movement: budget never negative"] = function()
		eq(MoveRules.budget(-1, MAX, 0, 0), 0, "negative elapsed")
	end,
}
