-- Server performance log for staging, Studio and live-test mode (never in the public release). Once a minute it prints
-- one line to the server log, readable in the Developer Console (F9 -> Server) during the
-- 4/8/12-player staging runs (docs/production/V3-PRELAUNCH-TEST-PLAN.md):
--   [ServerPerf] 60s players 8 | heartbeat 1s p1 57.9 p10 59.8 median 60.0 | worst step 41ms | mem 912MB | loot 61
-- Heartbeat is updates per second in 1-second windows (V3-PERFORMANCE-BUDGETS.md E); it is
-- scheduling rate, not CPU time. CPU per frame comes from the MicroProfiler.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local Config = require(ReplicatedStorage.Shared.Config)

local ServerPerf = {}

local WINDOW = 60

function ServerPerf.init()
	if Config.Environment ~= "Staging" and Config.Environment ~= "Studio" and not Config.IsLiveTest then
		return
	end
	local windows: { number } = {}
	local count, secondStart, windowStart, worst = 0, os.clock(), os.clock(), 0
	RunService.Heartbeat:Connect(function(dt)
		count += 1
		worst = math.max(worst, dt)
		local now = os.clock()
		if now - secondStart >= 1 then
			table.insert(windows, count / (now - secondStart))
			count = 0
			secondStart = now
		end
		if now - windowStart >= WINDOW and #windows > 0 then
			local sorted = table.clone(windows)
			table.sort(sorted)
			local function at(p: number): number
				return sorted[math.clamp(math.ceil(#sorted * p), 1, #sorted)]
			end
			local loot = workspace:FindFirstChild("Loot")
			print(
				("[ServerPerf] %ds players %d | heartbeat 1s p1 %.1f p10 %.1f median %.1f | worst step %dms | mem %dMB | loot %d"):format(
					math.floor(now - windowStart),
					#Players:GetPlayers(),
					at(0.01),
					at(0.1),
					at(0.5),
					math.floor(worst * 1000),
					math.floor(Stats:GetTotalMemoryUsageMb()),
					if loot then #loot:GetChildren() else -1
				)
			)
			table.clear(windows)
			worst = 0
			windowStart = now
		end
	end)
end

return ServerPerf
