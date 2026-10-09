-- Client-side environmental reactions to the storm cycle (V3 vertical slice). Purely cosmetic
-- and driven by the replicated storm state, so every client sees the same weather:
--
--   V3Flag       flags point downwind and flutter; harder in warnings, hardest in gusts.
--   V3Bulb       festoon bulbs: steady in calm, flicker during lightning storms.
--   V3Lamp       work lamps, plus the Scrapyard floodlights: flicker during storm warnings.
--   V3PuddleSpot puddles appear after a flood and dry up during the next calm.
--
-- Cheap by design: flags are a handful of parts, bulb flicker touches a few bulbs at ~10 Hz,
-- and nothing runs on the server.

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local EnvironmentFX = {}

local getState: () -> any
local gustPhase: (now: number) -> (string?, number)
local isReduced: () -> boolean

local BULB_ON = Color3.fromRGB(255, 214, 140)
local BULB_OFF = Color3.fromRGB(90, 70, 50)

type Flag = { Part: BasePart, Hinge: Vector3, Seed: number }
local flags: { Flag } = {}
local bulbs: { BasePart } = {}
local lamps: { BasePart } = {}
local puddleSpots: { BasePart } = {}
local puddles: { BasePart } = {}
local effects: Folder

local function track(tag: string, list: { any }, wrap: ((Instance) -> any)?)
	local function add(inst: Instance)
		if inst:IsA("BasePart") then
			table.insert(list, if wrap then wrap(inst) else inst)
		end
	end
	for _, inst in CollectionService:GetTagged(tag) do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
end

local function setLit(part: BasePart, on: boolean)
	if part:GetAttribute("Lit") == on then
		return
	end
	part:SetAttribute("Lit", on)
	part.Color = if on then (part:GetAttribute("OnColor") or BULB_ON) else BULB_OFF
	local light = part:FindFirstChildWhichIsA("Light")
	if light then
		light.Enabled = on
	end
end

---------------------------------------------------------------------------- Puddles

local function spawnPuddles()
	for _, spot in puddleSpots do
		for i = 1, 2 do
			local size = math.random(60, 120) / 10
			local p = Instance.new("Part")
			p.Name = "Puddle"
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Shape = Enum.PartType.Cylinder
			p.Size = Vector3.new(0.05, size, size * 0.8)
			p.CFrame = CFrame.new(
				spot.Position + Vector3.new(math.random(-40, 40) / 10 * i, 0, math.random(-40, 40) / 10)
			) * CFrame.Angles(0, math.rad(math.random(0, 180)), math.rad(90))
			p.Material = Enum.Material.Glass
			p.Color = Color3.fromRGB(90, 110, 120)
			p.Reflectance = 0.25
			p.Transparency = 0.35
			p.Parent = effects
			table.insert(puddles, p)
		end
	end
end

local function dryPuddles(seconds: number)
	for _, p in puddles do
		local tween =
			TweenService:Create(p, TweenInfo.new(seconds, Enum.EasingStyle.Sine), { Transparency = 1 })
		tween:Play()
		tween.Completed:Once(function()
			p:Destroy()
		end)
	end
	table.clear(puddles)
end

---------------------------------------------------------------------------- Per frame

local lastPhase = ""
local lastStorm: string? = nil
local flickerAt = 0

function EnvironmentFX.step(now: number)
	local state = getState()
	local phase, storm = state.Phase, state.Storm

	-- Phase changes: puddles after a flood, dry out in the next calm.
	if phase ~= lastPhase then
		if phase == "Aftermath" and lastStorm == "Flood" then
			spawnPuddles()
		elseif phase == "Calm" and #puddles > 0 then
			dryPuddles(40)
		end
		if phase ~= "Warning" and phase ~= "Storm" then
			for _, b in bulbs do
				setLit(b, true)
			end
			for _, l in lamps do
				setLit(l, true)
			end
		end
		lastPhase = phase
	end
	if phase == "Storm" or phase == "Warning" then
		lastStorm = storm
	end

	-- Flags: point downwind, flutter harder as the weather gets worse.
	local camera = workspace.CurrentCamera
	local camPos = camera and camera.CFrame.Position or Vector3.zero
	local dir = (state.WindDir and phase ~= "Calm" and phase ~= "Aftermath") and state.WindDir
		or Vector3.new(0.8, 0, 0.6).Unit
	local gust = gustPhase(now)
	local amp = if gust == "gust"
		then 32
		elseif storm == "Wind" and phase == "Storm" then 20
		elseif phase == "Warning" or phase == "Storm" then 14
		else 7
	local speed = if gust == "gust" then 14 elseif phase == "Storm" then 9 else 4
	if isReduced() then
		amp *= 0.4
	end
	for _, f in flags do
		if (f.Hinge - camPos).Magnitude < 260 then
			local flutter = math.rad(amp) * math.sin(now * speed + f.Seed)
			local wave = math.rad(amp * 0.35) * math.sin(now * speed * 1.7 + f.Seed * 2)
			f.Part.CFrame = CFrame.lookAt(f.Hinge, f.Hinge - dir)
				* CFrame.Angles(wave, flutter, 0)
				* CFrame.new(0, 0, 2.2)
		end
	end

	-- Lights: warnings make work lamps stutter; lightning storms make festoon bulbs flicker.
	if now >= flickerAt then
		flickerAt = now + 0.1
		if phase == "Warning" and not isReduced() then
			for _, l in lamps do
				setLit(l, math.random() > 0.25)
			end
		end
		if phase == "Storm" and storm == "Lightning" and not isReduced() and #bulbs > 0 then
			for _ = 1, 6 do
				local b = bulbs[math.random(1, #bulbs)]
				setLit(b, math.random() > 0.45)
			end
		elseif phase == "Storm" then
			for _, l in lamps do
				setLit(l, true)
			end
		end
	end
end

function EnvironmentFX.init(
	state: () -> any,
	gusts: (now: number) -> (string?, number),
	reduced: () -> boolean
)
	getState, gustPhase, isReduced = state, gusts, reduced
	effects = Instance.new("Folder")
	effects.Name = "EnvironmentFX"
	effects.Parent = workspace
	track("V3Flag", flags, function(inst)
		local part = inst :: BasePart
		local hinge = part:GetAttribute("Hinge")
		return {
			Part = part,
			Hinge = if typeof(hinge) == "Vector3" then hinge else part.Position,
			Seed = part.Position.X * 0.3,
		}
	end)
	track("V3Bulb", bulbs)
	track("V3Lamp", lamps)
	track("V3PuddleSpot", puddleSpots)
	-- The Scrapyard's floodlights flicker with the work lamps.
	task.spawn(function()
		local map = workspace:WaitForChild("Map", 60)
		local yard = map and map:WaitForChild("Scrapyard", 30)
		if not yard then
			return
		end
		for _, d in yard:GetDescendants() do
			if
				d:IsA("BasePart")
				and d.Material == Enum.Material.Neon
				and d.Parent
				and d.Parent.Name == "Floodlight"
			then
				d:SetAttribute("OnColor", d.Color)
				table.insert(lamps, d)
			end
		end
	end)
end

return EnvironmentFX
