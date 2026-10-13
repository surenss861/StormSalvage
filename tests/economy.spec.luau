local Economy = require("../src/shared/Economy")

local function eq(a: any, b: any, what: string)
	if a ~= b then
		error(("%s: expected %s, got %s"):format(what, tostring(b), tostring(a)), 2)
	end
end
local function throws(fn: () -> (), what: string)
	if pcall(fn) then
		error(what .. ": expected an error", 2)
	end
end

local BACKPACK = { 50, 150, 400, 1000, 2500 }

return {
	["sell: no multipliers"] = function()
		local base, total = Economy.sellTotal({ 20, 35, 140 }, {})
		eq(base, 195, "base")
		eq(total, 195, "total")
	end,
	["sell: VIP and 2x stack and round down"] = function()
		local base, total = Economy.sellTotal({ 33 }, { 1.2, 2 })
		eq(base, 33, "base")
		eq(total, 79, "total") -- 33 * 2.4 = 79.2
	end,
	["sell: empty bag pays nothing"] = function()
		local base, total = Economy.sellTotal({}, { 2 })
		eq(base, 0, "base")
		eq(total, 0, "total")
	end,
	["sell: rejects negative, NaN and infinite input"] = function()
		throws(function()
			Economy.sellTotal({ -5 }, {})
		end, "negative value")
		throws(function()
			Economy.sellTotal({ 0 / 0 }, {})
		end, "NaN value")
		throws(function()
			Economy.sellTotal({ 10 }, { math.huge })
		end, "infinite multiplier")
		throws(function()
			Economy.sellTotal({ 10 }, { 0 })
		end, "zero multiplier")
	end,
	["upgrade: affordable"] = function()
		local c = Economy.checkUpgrade(BACKPACK, 3, 1000)
		eq(c.Ok, true, "ok")
		eq(c.Cost, 1000, "cost")
	end,
	["upgrade: one coin short"] = function()
		local c = Economy.checkUpgrade(BACKPACK, 3, 999)
		eq(c.Ok, false, "ok")
		eq(c.Reason, "short", "reason")
		eq(c.Short, 1, "short")
	end,
	["upgrade: maxed"] = function()
		local c = Economy.checkUpgrade(BACKPACK, 5, 1e9)
		eq(c.Ok, false, "ok")
		eq(c.Reason, "maxed", "reason")
	end,
	["upgrade: malformed level or coins"] = function()
		for _, bad in { -1, 1.5, 0 / 0, "2", {} } do
			eq(Economy.checkUpgrade(BACKPACK, bad, 1e9).Reason, "invalid", "level " .. tostring(bad))
		end
		eq(Economy.checkUpgrade(BACKPACK, 0, 0 / 0).Reason, "invalid", "NaN coins")
	end,
}
