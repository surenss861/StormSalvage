-- Device performance log for staging and Studio playtests (never runs in production). Every
-- frame's duration goes into a buffer; once a minute it prints one line to the client log, which
-- a tester can read on a phone in the Developer Console (F9):
--   [Perf] 60s fps1s p10 31 median 44 | frame p95 38.2ms p99 61.0ms | worst 210ms | mem 812MB | q 3
-- The numbers follow docs/production/V3-PERFORMANCE-BUDGETS.md A/B: 1-second FPS windows and
-- frame-time percentiles of real client frames. Memory is the client total (Stats); draw calls
-- and triangles aren't exposed to scripts, so read those from the performance overlay.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local PerfProbe = {}

local WINDOW = 60 -- seconds per report

local function percentile(sorted: { number }, p: number): number
	if #sorted == 0 then
		return 0
	end
	local i = math.clamp(math.ceil(#sorted * p), 1, #sorted)
	return sorted[i]
end

function PerfProbe.init()
	if Config.Environment ~= "Staging" and Config.Environment ~= "Studio" then
		return
	end
	local frames: { number } = {}
	local secondFrames = 0
	local secondStart = os.clock()
	local fpsWindows: { number } = {}
	local windowStart = os.clock()
	RunService.RenderStepped:Connect(function(dt)
		table.insert(frames, dt * 1000)
		secondFrames += 1
		local now = os.clock()
		if now - secondStart >= 1 then
			table.insert(fpsWindows, secondFrames / (now - secondStart))
			secondFrames = 0
			secondStart = now
		end
		if now - windowStart >= WINDOW then
			local sortedFrames = table.clone(frames)
			table.sort(sortedFrames)
			local sortedFps = table.clone(fpsWindows)
			table.sort(sortedFps)
			local quality = "?"
			pcall(function()
				quality = tostring(UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value)
			end)
			print(
				("[Perf] %ds fps1s p10 %d median %d | frame p95 %.1fms p99 %.1fms | worst %dms | mem %dMB | q %s"):format(
					math.floor(now - windowStart),
					math.floor(percentile(sortedFps, 0.1)),
					math.floor(percentile(sortedFps, 0.5)),
					percentile(sortedFrames, 0.95),
					percentile(sortedFrames, 0.99),
					math.floor(sortedFrames[#sortedFrames] or 0),
					math.floor(Stats:GetTotalMemoryUsageMb()),
					quality
				)
			)
			table.clear(frames)
			table.clear(fpsWindows)
			windowStart = now
		end
	end)
end

return PerfProbe
