-- @file First-session guidance follows play and gives way to urgent moments
-- @domain qa
-- @status stable
-- @see [[Onboarding.luau]]
local O = require("../src/shared/Onboarding")

local function eq(a: any, b: any, what: string)
	if a ~= b then
		error(("%s: expected %s, got %s"):format(what, tostring(b), tostring(a)), 2)
	end
end

local function fresh(): any
	return {
		ItemsSold = 0,
		Carried = 0,
		Capacity = 3,
		StormsSurvived = 0,
		Extractions = 0,
		RushFinds = 0,
		Upgrades = 0,
		HasPro = false,
	}
end
local function calm(): any
	return { Phase = "Calm", EventLive = false, CarryingCore = false, CanAffordUpgrade = false }
end

return {
	["onboarding: the loop in order"] = function()
		local p, l = fresh(), calm()
		eq((O.step(p, l) :: any).Id, "Collect", "start")
		p.Carried = 1
		eq((O.step(p, l) :: any).Id, "Sell", "carrying")
		eq((O.step(p, l) :: any).Target, "Loot", "room left: keep grabbing")
		p.Carried = 3
		eq((O.step(p, l) :: any).Target, "Sell", "full: go sell")
		p.Carried, p.ItemsSold = 0, 3
		eq((O.step(p, l) :: any).Id, "Spend", "after the first sale")
		l.CanAffordUpgrade = true
		eq((O.step(p, l) :: any).Target, "Shop", "affordable: the shop")
		p.Upgrades = 1
		eq((O.step(p, l) :: any).Id, "Licence", "after the first upgrade")
		p.HasPro = true
		eq(O.step(p, l), nil, "done")
	end,
	["onboarding: a storm interrupts until one has been survived"] = function()
		local p, l = fresh(), calm()
		l.Phase = "Warning"
		eq((O.step(p, l) :: any).Id, "Storm", "warning")
		l.Phase = "Storm"
		eq((O.step(p, l) :: any).Id, "Storm", "storm")
		p.StormsSurvived = 1
		eq((O.step(p, l) :: any).Id, "Collect", "a veteran isn't nagged")
	end,
	["onboarding: carrying a core outranks everything, until the first extraction"] = function()
		local p, l = fresh(), calm()
		l.Phase, l.CarryingCore = "Storm", true
		eq((O.step(p, l) :: any).Id, "Escape", "core beats storm")
		p.Extractions = 1
		eq((O.step(p, l) :: any).Id, "Storm", "learned")
	end,
	["onboarding: events are introduced after the first sale"] = function()
		local p, l = fresh(), calm()
		l.EventLive = true
		eq((O.step(p, l) :: any).Id, "Collect", "not before the loop is learned")
		p.ItemsSold = 1
		eq((O.step(p, l) :: any).Id, "Event", "then the event")
		p.RushFinds = 1
		eq((O.step(p, l) :: any).Id, "Spend", "joined one: move on")
	end,
	["onboarding: every step has text and a known target"] = function()
		local targets = { Loot = true, Sell = true, Plateau = true, Event = true, Shop = true }
		for _, phase in { "Calm", "Warning", "Storm" } do
			for sold = 0, 1 do
				for carried = 0, 3 do
					local p = fresh()
					p.ItemsSold, p.Carried = sold, carried
					local s = O.step(p, {
						Phase = phase,
						EventLive = true,
						CarryingCore = carried == 2,
						CanAffordUpgrade = true,
					})
					if s then
						assert(#s.Text > 0, "text")
						assert(s.Target == nil or targets[s.Target], "target " .. tostring(s.Target))
					end
				end
			end
		end
	end,
}
