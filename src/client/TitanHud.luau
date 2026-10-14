-- @file The Storm Titan, drawn: the colossal funnel, the charge node, the inhale, the pull, the HUD
-- @domain world
-- @status wip
-- @see [[TitanService.luau]]
-- The server owns the Titan (TitanState: centre, radii, the charge node's angle and direction,
-- when it next inhales) and every siphon (TitanSiphon / TitanInNode attributes on the local
-- player). This draws and applies the client half:
--   * the funnel: a tall stack of widening storm-cloud discs that spin at different rates and
--     sway, a magenta energy core up the middle, debris orbiting the lower funnel, lightning
--     arcs jumping from it to the ground, a dust skirt at its base;
--   * the siphon ring (magenta) and the inner "too close" ring (red) on the ground;
--   * the charge node: a stream of energy from the funnel to one spot on the ring, with a lit
--     disc where it lands. It sweeps round the ring (extrapolated between server updates);
--   * the inhale: a red warning glow, then the pull spikes (InhalePull) for a moment;
--   * the pull: a VectorForce toward the centre near it, strongest at the inner edge (the
--     Containment Rig resists it: TitanResist), like the storm's wind push;
--   * an objective-strip entry: the siphon as its bar, and where the node is.
-- Reduced Effects: fewer discs, no spin, sway, orbiting debris, arcs or dust.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Bands = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Bands"))
local Remotes = require(ReplicatedStorage.Shared:WaitForChild("Remotes"))
local Audio = require(script.Parent:WaitForChild("Audio"))
local UI = require(script.Parent:WaitForChild("UI"))
local EventStrip = require(script.Parent:WaitForChild("EventStrip"))

local TitanHud = {}

local T = Bands.Titan
local MAGENTA = Color3.fromRGB(255, 90, 200)
local DANGER = Color3.fromRGB(255, 80, 70)
local CLOUD = Color3.fromRGB(58, 54, 70)
local CLOUD_TOP = Color3.fromRGB(150, 142, 166)
local HEIGHT = 130
local RINGS = 14

local folder: Folder
local funnel: Model? = nil
local rings: { BasePart } = {}
local siphonRing: BasePart? = nil
local innerRing: BasePart? = nil
local target: Vector3? = nil
local shown: Vector3? = nil
local spin = 0
local force: VectorForce? = nil
local core: BasePart? = nil
local debris: { BasePart } = {}
local stream: BasePart? = nil
local nodeDisc: BasePart? = nil
local dust: ParticleEmitter? = nil
local node = { Angle = 0, Dir = 1, SentAt = 0 }
local inhaleAt = math.huge
local warned = 0
local nextArc = 0

local function anchoredPart(name: string): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

local function clear()
	if funnel then
		funnel:Destroy()
		funnel = nil
	end
	rings = {}
	debris = {}
	core, stream, nodeDisc, dust = nil, nil, nil, nil
	inhaleAt = math.huge
	siphonRing, innerRing = nil, nil
	target, shown = nil, nil
	if force then
		force.Enabled = false
	end
	EventStrip.clear("titan")
end

local function groundRing(name: string, radius: number, color: Color3, transparency: number): Part
	local p = anchoredPart(name)
	p.Shape = Enum.PartType.Cylinder
	p.Material = Enum.Material.ForceField
	p.Color = color
	p.Transparency = transparency
	p.Size = Vector3.new(0.3, radius * 2, radius * 2)
	return p
end

local function build(center: Vector3)
	local model = Instance.new("Model")
	model.Name = "StormTitan"
	local reduced = UI.reduced()
	local count = if reduced then 6 else RINGS
	for i = 1, count do
		local f = (i - 1) / (count - 1)
		local p = anchoredPart("Cloud")
		p.Shape = Enum.PartType.Cylinder
		p.Material = Enum.Material.SmoothPlastic
		p.Color = CLOUD:Lerp(CLOUD_TOP, f * 0.75):Lerp(Color3.fromRGB(90, 60, 110), (i % 3) * 0.08)
		p.Transparency = 0.18 + f * 0.32
		local r = 4 + (f ^ 1.6) * 44
		p.Size = Vector3.new((HEIGHT / count) * 1.8, r * 2, r * 2) -- thick: neighbours overlap, no steps
		p:SetAttribute("Y", 3 + f * HEIGHT)
		p:SetAttribute("Rate", 1.2 + (1 - f) * 1.6) -- the bottom turns fastest
		p.Parent = model
		table.insert(rings, p)
	end
	local c = anchoredPart("EnergyCore")
	c.Material = Enum.Material.Neon
	c.Color = MAGENTA
	c.Transparency = 0.45
	c.Shape = Enum.PartType.Cylinder
	c.Size = Vector3.new(HEIGHT * 0.45, 2.2, 2.2)
	c.Parent = model
	core = c
	if not reduced then
		local rng = Random.new(7)
		for i = 1, 12 do
			local chunk = anchoredPart("Debris")
			chunk.Material = if i % 2 == 0 then Enum.Material.WoodPlanks else Enum.Material.CorrodedMetal
			chunk.Color = if i % 2 == 0 then Color3.fromRGB(110, 84, 60) else Color3.fromRGB(96, 98, 104)
			chunk.Size = Vector3.new(rng:NextNumber(1, 3), rng:NextNumber(0.4, 1.2), rng:NextNumber(1.5, 4))
			chunk:SetAttribute("R", rng:NextNumber(12, 24))
			chunk:SetAttribute("H", rng:NextNumber(3, 34))
			chunk:SetAttribute("A", rng:NextNumber() * math.pi * 2)
			chunk:SetAttribute("W", rng:NextNumber(1.2, 2.4))
			chunk.Parent = model
			table.insert(debris, chunk)
		end
	end
	local base = anchoredPart("DustBase")
	base.Transparency = 1
	base.Size = Vector3.new(1, 1, 1)
	base.Parent = model
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(120, 108, 96))
	e.Size = NumberSequence.new(8, 16)
	e.Transparency = NumberSequence.new(0.5, 1)
	e.Lifetime = NumberRange.new(1.5, 2.5)
	e.Speed = NumberRange.new(10, 18)
	e.SpreadAngle = Vector2.new(180, 8)
	e.Rate = if reduced then 0 else 18
	e.Parent = base
	dust = e
	siphonRing = groundRing("SiphonRing", T.OuterRadius, MAGENTA, 0.55)
	innerRing = groundRing("InnerRing", T.InnerRadius, DANGER, 0.45);
	(siphonRing :: Part).Parent = model;
	(innerRing :: Part).Parent = model
	local s = anchoredPart("ChargeStream")
	s.Material = Enum.Material.Neon
	s.Color = MAGENTA
	s.Transparency = 0.3
	s.Parent = model
	stream = s
	local disc = anchoredPart("ChargeNode")
	disc.Shape = Enum.PartType.Cylinder
	disc.Material = Enum.Material.Neon
	disc.Color = MAGENTA
	disc.Transparency = 0.45
	disc.Size = Vector3.new(0.4, T.NodeHit * 2, T.NodeHit * 2)
	local light = Instance.new("PointLight")
	light.Color = MAGENTA
	light.Range = 18
	light.Brightness = 3
	light.Parent = disc
	disc.Parent = model
	nodeDisc = disc
	model.Parent = folder
	funnel = model
	shown = center
end

local function onState(m: any)
	if type(m) ~= "table" or not m.Active then
		clear()
		return
	end
	target = m.Center
	node.Angle = m.NodeAngle or node.Angle
	node.Dir = m.NodeDir or node.Dir
	node.SentAt = m.SentAt or workspace:GetServerTimeNow()
	inhaleAt = m.InhaleAt or math.huge
	if not funnel and target then
		build(target)
		Audio.play("WarnWind", 0.9, 0.5)
	end
end

-- A lightning arc from the funnel down to the ground nearby (lasts a moment).
local function arc(c: Vector3)
	local from = c + Vector3.new(math.random(-10, 10), math.random(40, 80), math.random(-10, 10))
	local a = math.random() * math.pi * 2
	local to = c + Vector3.new(math.cos(a), 0, math.sin(a)) * math.random(20, 50)
	local points = { from }
	for k = 1, 3 do
		local p = from:Lerp(to, k / 4)
			+ Vector3.new(math.random(-6, 6), math.random(-4, 4), math.random(-6, 6))
		table.insert(points, p)
	end
	table.insert(points, to)
	for k = 1, #points - 1 do
		local p0, p1 = points[k], points[k + 1]
		local seg = anchoredPart("Arc")
		seg.Material = Enum.Material.Neon
		seg.Color = Color3.fromRGB(240, 210, 255)
		seg.Size = Vector3.new(0.35, 0.35, (p1 - p0).Magnitude)
		seg.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
		seg.Parent = folder
		game:GetService("Debris"):AddItem(seg, 0.14)
	end
end

local function isLegend(): boolean
	local band = Players.LocalPlayer:GetAttribute("Band")
	return type(band) == "number" and band >= T.MinBand
end

local function step(dt: number)
	if not funnel or not target then
		return
	end
	shown = (shown :: Vector3):Lerp(target :: Vector3, math.min(1, dt * 4))
	local c = shown :: Vector3
	local reduced = UI.reduced()
	local now = workspace:GetServerTimeNow()
	local warning = now >= inhaleAt - T.InhaleWarn and now < inhaleAt
	local inhaling = now >= inhaleAt and now < inhaleAt + T.InhaleSeconds
	if not reduced then
		spin += dt
	end
	for i, p in rings do
		local y = p:GetAttribute("Y") :: number
		local wobble = if reduced then 0 else math.sin(os.clock() * 0.8 + i * 0.6) * (y / HEIGHT) * 7
		local squeeze = if inhaling then 0.88 else 1
		p.CFrame = CFrame.new(c.X + wobble, c.Y + y, c.Z + wobble * 0.4)
			* CFrame.Angles(0, spin * (p:GetAttribute("Rate") :: number), 0)
			* CFrame.Angles(0, 0, math.pi / 2)
		if inhaling or warning then
			p.Color = p.Color:Lerp(Color3.fromRGB(150, 40, 60), dt * 3)
		else
			p.Color = p.Color:Lerp(CLOUD:Lerp(CLOUD_TOP, y / HEIGHT * 0.75), dt * 1.5)
		end
		local base = p:GetAttribute("BaseSize") :: Vector3?
		if not base then
			p:SetAttribute("BaseSize", p.Size)
			base = p.Size
		end
		local b = base :: Vector3
		p.Size = Vector3.new(b.X, b.Y * squeeze, b.Z * squeeze)
	end
	if core then
		core.CFrame = CFrame.new(c + Vector3.new(0, HEIGHT * 0.24, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		core.Transparency = if warning or inhaling then 0.2 else 0.6 + 0.1 * math.sin(os.clock() * 6)
		core.Color = if warning or inhaling then DANGER else MAGENTA
	end
	for _, chunk in debris do
		local a = (chunk:GetAttribute("A") :: number) + os.clock() * (chunk:GetAttribute("W") :: number)
		local r = chunk:GetAttribute("R") :: number
		chunk.CFrame = CFrame.new(
			c + Vector3.new(math.cos(a) * r, chunk:GetAttribute("H") :: number, math.sin(a) * r)
		) * CFrame.Angles(a * 2, a, a * 0.5)
	end
	if dust then
		(dust.Parent :: BasePart).Position = c + Vector3.new(0, 1, 0)
	end
	if not reduced and os.clock() >= nextArc then
		nextArc = os.clock() + 1.2 + math.random() * 1.8
		arc(c)
	end
	if warning and warned ~= inhaleAt then
		warned = inhaleAt
		Audio.play("WarnWind", 1, 0.7)
	end
	local flat = CFrame.new(c.X, c.Y + 0.3, c.Z) * CFrame.Angles(0, 0, math.pi / 2)
	if siphonRing then
		siphonRing.CFrame = flat
	end
	if innerRing then
		innerRing.CFrame = flat * CFrame.new(0.05, 0, 0)
		innerRing.Transparency = if warning or inhaling then 0.2 + 0.2 * math.sin(os.clock() * 14) else 0.45
	end
	-- The charge node, extrapolated along the ring.
	local angle = node.Angle + node.Dir * T.NodeSpeed * (now - node.SentAt)
	local nodePos = c + Vector3.new(math.cos(angle), 0, math.sin(angle)) * T.NodeRadius
	if nodeDisc then
		nodeDisc.CFrame = CFrame.new(nodePos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		nodeDisc.Transparency = 0.35 + 0.15 * math.sin(os.clock() * 8)
	end
	if stream then
		local top = c + Vector3.new(0, 34, 0)
		local len = (nodePos - top).Magnitude
		stream.Size = Vector3.new(1.4, 1.4, len)
		stream.CFrame = CFrame.lookAt((top + nodePos) / 2, nodePos)
		stream.Transparency = 0.25 + 0.15 * math.sin(os.clock() * 10)
	end

	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local offset = (c - root.Position) * Vector3.new(1, 0, 1)
	local d = offset.Magnitude
	-- The pull: everyone near it feels it; the Rig resists (1 - 1/speed).
	if not force or force.Parent ~= root then
		local attachment = root:FindFirstChild("TitanPullAttachment") or Instance.new("Attachment")
		attachment.Name = "TitanPullAttachment"
		attachment.Parent = root
		local f = Instance.new("VectorForce")
		f.Name = "TitanPull"
		f.Attachment0 = attachment :: Attachment
		f.RelativeTo = Enum.ActuatorRelativeTo.World
		f.ApplyAtCenterOfMass = true
		f.Parent = root
		force = f
	end
	local f = force :: VectorForce
	local reach = T.OuterRadius * 1.3
	if d < reach and d > 1 then
		local k = 1 - math.clamp((d - T.InnerRadius) / (reach - T.InnerRadius), 0, 1) * 0.75
		local resist = character and character:GetAttribute("TitanResist")
		local keep = 1 - (if type(resist) == "number" then math.clamp(resist, 0, 0.9) else 0)
		f.Force = offset.Unit * root.AssemblyMass * T.Pull * k * keep
		f.Enabled = true
	else
		f.Enabled = false
	end

	if not isLegend() then
		EventStrip.set("titan", {
			Priority = 56,
			Title = "The Storm Titan",
			Sub = "A colossal twister roams town. Keep clear of its ring.",
			Accent = MAGENTA,
			Pill = ("TITAN %dm"):format(math.floor(d)),
		})
		return
	end
	local s = Players.LocalPlayer:GetAttribute("TitanSiphon")
	local siphon = if type(s) == "number" then s else 0
	local inNode = Players.LocalPlayer:GetAttribute("TitanInNode") == true
	local toNode = math.floor(((nodePos - root.Position) * Vector3.new(1, 0, 1)).Magnitude)
	local e = { Priority = 72, Title = "", Sub = "", Accent = MAGENTA, Progress = siphon, Pill = "" }
	if (warning or inhaling) and d <= T.OuterRadius * 1.3 then
		e.Priority, e.Accent = 97, DANGER
		e.Title = if inhaling then "The Titan is inhaling!" else "The Titan is about to inhale"
		e.Sub = "Sprint or dodge OUT, away from the core!"
		e.Pill = "INHALE"
	elseif d < T.InnerRadius then
		e.Priority, e.Accent = 95, DANGER
		e.Title = "Too close · the Titan is tearing you apart"
		e.Sub = "Get back out to the magenta ring!"
		e.Pill = "TOO CLOSE"
	elseif d <= T.OuterRadius then
		e.Priority = 88
		e.Title = ("Siphoning the Titan · %d%%"):format(math.floor(siphon * 100))
		e.Sub = if inNode
			then "In the charge node: full power. Stay with it as it moves!"
			else ("Chase the charge node: %dm round the ring"):format(toNode)
		e.Pill = ("SIPHON %d%%"):format(math.floor(siphon * 100))
	else
		e.Title = ("The Storm Titan · %dm"):format(math.floor(d))
		e.Sub = "Reach its magenta ring and chase the charge node for a Mythic Core."
		e.Pill = ("TITAN %dm"):format(math.floor(d))
	end
	EventStrip.set("titan", e)
end

function TitanHud.init(_topStack: Frame)
	folder = Instance.new("Folder")
	folder.Name = "TitanFx"
	folder.Parent = workspace
	Remotes.get("TitanState").OnClientEvent:Connect(onState)
	RunService.RenderStepped:Connect(step)
end

return TitanHud
