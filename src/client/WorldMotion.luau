-- @file Small environmental motion: spinning machinery and blinking lamps (client only)
-- @domain world
-- @status wip
-- @see [[DistrictRailYard.luau]]
-- @see [[DistrictFloodWorks.luau]]
-- Map parts tagged by the server animate here, so the server does no per-frame work:
--   "Spin"   rotates about its own axis (SpinAxis "X" or "Y", SpinSpeed in turns per second);
--   "Blink"  a Neon lamp that pulses on a one-second beat (BlinkPhase 0/1 alternate).
--   "Beacon" a tall marker beam (cache, dropped core, Storm Heart, wreck): it fades out as the
--            camera gets within a few studs, so standing at the prize never fills the screen.
-- Only parts within MOTION_RANGE of the camera move. Reduced Effects stops spinning (lamps
-- still blink, slower and softer).

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local UI = require(script.Parent:WaitForChild("UI"))

local WorldMotion = {}

local MOTION_RANGE = 260

type Spinner = { Part: BasePart, Base: CFrame, Speed: number, Axis: string }
local spinners: { [BasePart]: Spinner } = {}
local blinkers: { [BasePart]: { Color: Color3, Phase: number } } = {}
local beacons: { [BasePart]: number } = {} -- base transparency
local BEACON_CLEAR, BEACON_FULL = 8, 34 -- studs from the beam's axis: invisible .. normal

local function addSpin(p: Instance)
	if p:IsA("BasePart") then
		spinners[p] = {
			Part = p,
			Base = p.CFrame,
			Speed = (p:GetAttribute("SpinSpeed") :: number?) or 1,
			Axis = (p:GetAttribute("SpinAxis") :: string?) or "Y",
		}
	end
end

local function addBlink(p: Instance)
	if p:IsA("BasePart") then
		blinkers[p] = { Color = p.Color, Phase = (p:GetAttribute("BlinkPhase") :: number?) or 0 }
	end
end

-- Exposed so HUD modules can tag the beams they make (CollectionService tags replicate only from
-- the server; these beams are client-made).
function WorldMotion.beacon(p: BasePart)
	beacons[p] = p.Transparency
	p.Destroying:Connect(function()
		beacons[p] = nil
	end)
end

function WorldMotion.init()
	for _, p in CollectionService:GetTagged("Spin") do
		addSpin(p)
	end
	for _, p in CollectionService:GetTagged("Blink") do
		addBlink(p)
	end
	CollectionService:GetInstanceAddedSignal("Spin"):Connect(addSpin)
	CollectionService:GetInstanceAddedSignal("Blink"):Connect(addBlink)
	CollectionService:GetInstanceRemovedSignal("Spin"):Connect(function(p)
		spinners[p :: BasePart] = nil
	end)
	CollectionService:GetInstanceRemovedSignal("Blink"):Connect(function(p)
		blinkers[p :: BasePart] = nil
	end)
	local lastBlink = -1
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local eye = camera.CFrame.Position
		local now = os.clock()
		local reduced = UI.reduced()
		if not reduced then
			for p, s in spinners do
				if p.Parent and (p.Position - eye).Magnitude < MOTION_RANGE then
					local a = now * s.Speed * math.pi * 2
					p.CFrame = s.Base
						* (if s.Axis == "X" then CFrame.Angles(a, 0, 0) else CFrame.Angles(0, a, 0))
				end
			end
		end
		for p, base in beacons do
			local d = ((p.Position - eye) * Vector3.new(1, 0, 1)).Magnitude
			local k = math.clamp((d - BEACON_CLEAR) / (BEACON_FULL - BEACON_CLEAR), 0, 1)
			p.Transparency = 1 - (1 - base) * k
		end
		local beat = math.floor(now * (if reduced then 0.5 else 1))
		if beat ~= lastBlink then
			lastBlink = beat
			for p, b in blinkers do
				if p.Parent and (p.Position - eye).Magnitude < MOTION_RANGE then
					local on = (beat + b.Phase) % 2 == 0
					p.Color = if on
						then b.Color
						else b.Color:Lerp(Color3.new(0.1, 0.1, 0.1), if reduced then 0.5 else 0.8)
				end
			end
		end
	end)
end

return WorldMotion
