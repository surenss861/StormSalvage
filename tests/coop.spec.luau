-- @file Cooperative reward shares: fair, whole, no freeloaders
-- @domain qa
-- @status stable
-- @see [[Coop.luau]]
local Coop = require("../src/shared/Coop")

local function eq(a: any, b: any, what: string)
	if a ~= b then
		error(("%s: expected %s, got %s"):format(what, tostring(b), tostring(a)), 2)
	end
end

local function sum(t: { [string]: number }): number
	local n = 0
	for _, v in t do
		n += v
	end
	return n
end

return {
	["coop: three equal cutters each get a share, all rewards handed out"] = function()
		local s = Coop.shares({ a = 1, b = 1, c = 1 }, 5, 0.1)
		eq(sum(s), 5, "all five")
		for _, id in { "a", "b", "c" } do
			assert((s[id] or 0) >= 1, id .. " gets at least one")
		end
	end,
	["coop: a bigger contribution gets more, never less"] = function()
		local s = Coop.shares({ big = 0.7, small = 0.3 }, 4, 0.1)
		eq(sum(s), 4, "all four")
		assert(s.big >= s.small, "big >= small")
		eq(s.small, 1, "small still gets one")
	end,
	["coop: a freeloader below the minimum gets nothing"] = function()
		local s = Coop.shares({ worker = 1.95, touch = 0.05 }, 3, 0.1)
		eq(s.touch, nil, "a 2.5% touch is not a share")
		eq(s.worker, 3, "the worker gets all three")
		eq(sum(Coop.shares({ idle = 0 }, 3, 0.1)), 0, "no work, no rewards")
		eq(sum(Coop.shares({}, 3, 0.1)), 0, "nobody")
	end,
	["coop: more contributors than rewards: the biggest get one each"] = function()
		local s = Coop.shares({ a = 4, b = 3, c = 2, d = 1 }, 2, 0.05)
		eq(sum(s), 2, "two")
		eq(s.a, 1, "a")
		eq(s.b, 1, "b")
		eq(s.d, nil, "d")
	end,
	["coop: shares are deterministic and sum exactly over many splits"] = function()
		local seed = 12345
		local function rand(): number
			seed = (seed * 1103515245 + 12345) % 2147483648
			return math.floor(seed / 65536) % 1000 / 1000
		end
		for _ = 1, 500 do
			local c = {}
			local n = 1 + math.floor(rand() * 6)
			for i = 1, n do
				c["p" .. i] = rand()
			end
			local count = math.floor(rand() * 8)
			local s1 = Coop.shares(c, count, 0.05)
			local s2 = Coop.shares(c, count, 0.05)
			local eligible = #Coop.eligible(c, 0.05)
			eq(sum(s1), if eligible > 0 then count else 0, "sums to the count")
			for id, v in s1 do
				eq(s2[id], v, "same split twice")
				assert(v >= 0, "no negatives")
			end
		end
	end,
	["coop: the jackpot draw follows contribution and skips freeloaders"] = function()
		local c = { a = 3, b = 1, lurker = 0.01 }
		local wins = { a = 0, b = 0, lurker = 0 }
		for i = 0, 999 do
			local w = Coop.weightedPick(c, i / 1000, 0.1) :: string
			wins[w] += 1
		end
		eq(wins.lurker, 0, "never the lurker")
		eq(wins.a, 750, "a 75%")
		eq(wins.b, 250, "b 25%")
		eq(Coop.weightedPick({}, 0.5, 0.1), nil, "nobody to win")
	end,
	["coop: titan consolation is zero below the floor and below a core above it"] = function()
		eq(Coop.consolation(0.1, 0.25, 8000000), 0, "too little")
		eq(Coop.consolation(0.5, 0.25, 8000000), 4000000, "half")
		eq(Coop.consolation(0 / 0, 0.25, 8000000), 0, "nan")
		assert(Coop.consolation(0.99, 0.25, 8000000) < 8000000, "never a full core's worth")
	end,
}
