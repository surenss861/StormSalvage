-- @file Storm Pursuit rules unit tests
-- @domain qa
-- @status stable
-- @see [[Pursuit.luau]]
local Pursuit = require("../src/shared/Pursuit")

local function eq(a: any, b: any, what: string)
	if a ~= b then
		error(("%s: expected %s, got %s"):format(what, tostring(b), tostring(a)), 2)
	end
end
local function near(a: number, b: number, what: string)
	if math.abs(a - b) > 1e-6 then
		error(("%s: expected %s, got %s"):format(what, tostring(b), tostring(a)), 2)
	end
end

return {
	["pursuit: twister steps toward the target at its speed"] = function()
		local p, left = Pursuit.step({ X = 0, Z = 0 }, { X = 30, Z = 40 }, 24, 0.5)
		near(p.X, 7.2, "x")
		near(p.Z, 9.6, "z")
		near(left, 38, "remaining")
	end,
	["pursuit: never overshoots"] = function()
		local p, left = Pursuit.step({ X = 0, Z = 0 }, { X = 1, Z = 0 }, 24, 1)
		eq(p.X, 1, "x")
		eq(left, 0, "remaining")
	end,
	["pursuit: sprinting outruns it, running doesn't"] = function()
		-- 20 s chase from 34 studs behind: run 20 vs twister 24, sprint 28 vs 24.
		local gapRun = 34 + (20 - 24) * 20
		local gapSprint = 34 + (28 - 24) * 20
		eq(gapRun < 7, true, "a runner is caught")
		eq(gapSprint > 34, true, "a sprinter pulls away")
	end,
	["pursuit: catch radius is inclusive"] = function()
		eq(Pursuit.caught({ X = 0, Z = 0 }, { X = 7, Z = 0 }, 7), true, "edge")
		eq(Pursuit.caught({ X = 0, Z = 0 }, { X = 7.01, Z = 0 }, 7), false, "outside")
	end,
	["pursuit: strikes lead the runner, not a standing player"] = function()
		local a = Pursuit.leadPoint({ X = 10, Z = 10 }, { X = 0, Z = 0 }, 1.1)
		eq(a.X, 10, "still x")
		local b = Pursuit.leadPoint({ X = 10, Z = 10 }, { X = 28, Z = 0 }, 1.1)
		near(b.X, 40.8, "lead x")
	end,
	["pursuit: spawns behind the carrier, toward the cache"] = function()
		local s = Pursuit.spawnPoint({ X = 0, Z = 0 }, { X = 0, Z = 10 }, 34)
		near(s.Z, 34, "behind")
		local same = Pursuit.spawnPoint({ X = 5, Z = 5 }, { X = 5, Z = 5 }, 34)
		near(same.Z, 39, "degenerate case picks a direction")
	end,
	["pursuit: records count, best time, streaks and hardest site"] = function()
		local r = Pursuit.newRecords()
		local a = Pursuit.record(r, 31.27, 2, true)
		eq(a.Best, true, "first is best")
		eq(r.BestExtract, 31.3, "rounded")
		eq(a.Streak, 1, "streak 1")
		eq(a.NewHardest, true, "first hardest")
		local b = Pursuit.record(r, 40, 1, true)
		eq(b.Best, false, "slower")
		eq(b.Streak, 2, "streak 2")
		eq(b.NewHardest, false, "easier site")
		local c = Pursuit.record(r, 22.04, 3, false)
		eq(c.Best, true, "faster")
		eq(c.Streak, 0, "caught this time: streak resets")
		eq(r.BestStreak, 2, "best streak kept")
		eq(r.Hardest, 3, "hardest")
		eq(r.Extractions, 3, "count")
		Pursuit.breakStreak(r)
		eq(r.Streak, 0, "broken")
	end,
	["pursuit: old records are reconciled"] = function()
		local r = Pursuit.reconcile({ Extractions = 4, BestExtract = 12.5 })
		eq(r.Extractions, 4, "kept")
		eq(r.BestExtract, 12.5, "kept best")
		eq(r.Streak, 0, "filled")
		eq(r.RushFinds, 0, "filled")
		eq(Pursuit.reconcile(nil).Hardest, 0, "nil profile field")
		eq(Pursuit.reconcile({ Streak = 0 / 0 }).Streak, 0, "NaN repaired")
	end,
	["events: never the same kind or site twice in a row"] = function()
		local kinds = { "Pursuit", "Extraction", "Rush" }
		local sites = { "A", "B", "C" }
		local lastK, lastS = nil, nil
		local seed = 7
		local function random(n: number): number
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed % n + 1
		end
		for _ = 1, 200 do
			local k, s = Pursuit.pickNext(lastK, lastS, kinds, sites, random)
			if lastK then
				eq(k ~= lastK, true, "kind repeated")
				eq(s ~= lastS, true, "site repeated")
			end
			lastK, lastS = k, s
		end
		local onlyK = Pursuit.pickNext("X", "Y", { "X" }, { "Y" }, random)
		eq(onlyK, "X", "single choice still works")
	end,
	["events: surges land on the line home"] = function()
		local p = Pursuit.surgePoint({ X = 0, Z = 0 }, { X = 0, Z = -100 }, 30)
		near(p.Z, -30, "ahead")
		local capped = Pursuit.surgePoint({ X = 0, Z = 0 }, { X = 0, Z = -10 }, 30)
		near(capped.Z, -10, "never past home")
	end,
	["pursuit: twister speed builds and caps"] = function()
		eq(Pursuit.speedAt(0, 25, 0.4, 31), 25, "start")
		near(Pursuit.speedAt(7.5, 25, 0.4, 31), 28, "passes a base sprint at 7.5 s with ramp 0.4")
		eq(Pursuit.speedAt(60, 25, 0.4, 31), 31, "capped")
		eq(Pursuit.speedAt(-3, 25, 0.4, 31), 25, "never below start")
	end,
}
