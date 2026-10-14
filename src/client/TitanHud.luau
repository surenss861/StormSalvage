-- @file The Storm Titan, drawn: the colossal funnel, its siphon ring, the pull, the siphon meter
-- @domain world
-- @status wip
-- @see [[TitanService.luau]]
-- The server owns the Titan (TitanState: centre and radii) and every siphon (the TitanSiphon
-- attribute on the local player). This draws and applies the client half:
--   * the funnel: stacked, widening rings of storm cloud that spin (still and fewer in Reduced
--     Effects), with a debris band near the ground, eased toward each server update;
--   * the siphon ring on the ground (magenta), and the inner "too close" ring (red);
--   * the pull: a VectorForce toward the centre while you're near it, strongest at the inner
--     edge (the Containment Rig resists it: the server sets TitanResist), like the wind push;
--   * for Storm Legends, a banner with your siphon meter and where you stand.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Bands = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Bands"))
local Remotes = require(ReplicatedStorage.Shared:WaitForChild("Remotes"))
local Audio = require(script.Parent:WaitForChild("Audio"))
local UI = require(script.Parent:WaitForChild("UI"))

local TitanHud = {}

local T = Bands.Titan
local MAGENTA = Color3.fromRGB(255, 90, 200)
local DANGER = Color3.fromRGB(255, 80, 70)
local CLOUD = Color3.fromRGB(70, 64, 82)
local HEIGHT = 110
local RINGS = 9

local folder: Folder
local funnel: Model? = nil
local rings: { BasePart } = {}
local siphonRing: BasePart? = nil
local innerRing: BasePart? = nil
local target: Vector3? = nil
local shown: Vector3? = nil
local spin = 0
local force: VectorForce? = nil
local banner: Frame
local title: TextLabel
local sub: TextLabel
local meterFill: Frame

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
	siphonRing, innerRing = nil, nil
	target, shown = nil, nil
	if force then
		force.Enabled = false
	end
	banner.Visible = false
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
	local count = if UI.reduced() then 5 else RINGS
	for i = 1, count do
		local f = (i - 1) / (count - 1)
		local p = anchoredPart("Cloud")
		p.Shape = Enum.PartType.Cylinder
		p.Material = Enum.Material.SmoothPlastic
		p.Color = CLOUD:Lerp(Color3.fromRGB(150, 140, 160), f * 0.6)
		p.Transparency = 0.15 + f * 0.25
		local r = 5 + f * f * 34
		p.Size = Vector3.new(HEIGHT / count + 2, r * 2, r * 2)
		p:SetAttribute("Y", 4 + f * HEIGHT)
		p.Parent = model
		table.insert(rings, p)
	end
	local debris = anchoredPart("DebrisBand")
	debris.Shape = Enum.PartType.Cylinder
	debris.Material = Enum.Material.Slate
	debris.Color = Color3.fromRGB(90, 76, 62)
	debris.Transparency = 0.35
	debris.Size = Vector3.new(6, 26, 26)
	debris:SetAttribute("Y", 5)
	debris.Parent = model
	table.insert(rings, debris)
	siphonRing = groundRing("SiphonRing", T.OuterRadius, MAGENTA, 0.55)
	innerRing = groundRing("InnerRing", T.InnerRadius, DANGER, 0.45);
	(siphonRing :: Part).Parent = model;
	(innerRing :: Part).Parent = model
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
	if not funnel and target then
		build(target)
		Audio.play("WarnWind", 0.9, 0.5)
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
	if not UI.reduced() then
		spin += dt * 1.6
	end
	for i, p in rings do
		local y = p:GetAttribute("Y") :: number
		local wobble = if UI.reduced() then 0 else math.sin(os.clock() * 0.9 + i) * (y / HEIGHT) * 4
		p.CFrame = CFrame.new(c.X + wobble, c.Y + y, c.Z)
			* CFrame.Angles(0, spin * (1 + i * 0.07), 0)
			* CFrame.Angles(0, 0, math.pi / 2)
	end
	local flat = CFrame.new(c.X, c.Y + 0.3, c.Z) * CFrame.Angles(0, 0, math.pi / 2)
	if siphonRing then
		siphonRing.CFrame = flat
	end
	if innerRing then
		innerRing.CFrame = flat * CFrame.new(0.05, 0, 0)
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
		banner.Visible = false
		return
	end
	local s = Players.LocalPlayer:GetAttribute("TitanSiphon")
	local siphon = if type(s) == "number" then s else 0
	meterFill.Size = UDim2.fromScale(siphon, 1)
	if d < T.InnerRadius then
		title.Text = "TOO CLOSE · THE TITAN IS TEARING YOU APART"
		title.TextColor3 = DANGER
		sub.Text = "Get back out to the magenta ring!"
	elseif d <= T.OuterRadius then
		title.Text = ("SIPHONING THE STORM TITAN · %d%%"):format(math.floor(siphon * 100))
		title.TextColor3 = MAGENTA
		sub.Text = "Hold the ring. Fight the pull, dodge the debris."
	else
		title.Text = ("THE STORM TITAN · %dm"):format(math.floor(d))
		title.TextColor3 = MAGENTA
		sub.Text = "Get inside its magenta ring to siphon it for a Mythic Core."
	end
	banner.Visible = not UI.modalOpen()
end

function TitanHud.init(topStack: Frame)
	folder = Instance.new("Folder")
	folder.Name = "TitanFx"
	folder.Parent = workspace
	banner = UI.plate({
		Name = "TitanBanner",
		Parent = topStack,
		LayoutOrder = 7,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		Visible = false,
	})
	UI.padding(5, 14).Parent = banner
	UI.new("UIListLayout", {
		Parent = banner,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 3),
	})
	title = UI.text({
		Parent = banner,
		LayoutOrder = 1,
		Font = UI.Font.Mono,
		TextSize = 18,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		TextColor3 = MAGENTA,
		Text = "",
	})
	local meter = UI.new("Frame", {
		Parent = banner,
		LayoutOrder = 2,
		Size = UDim2.fromOffset(220, 8),
		BackgroundColor3 = Color3.fromRGB(40, 36, 48),
		BorderSizePixel = 0,
	}, { UI.corner(4) })
	meterFill = UI.new("Frame", {
		Parent = meter,
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = MAGENTA,
		BorderSizePixel = 0,
	}, { UI.corner(4) })
	sub = UI.text({
		Parent = banner,
		LayoutOrder = 3,
		Font = UI.Font.Body,
		TextSize = 14,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		Text = "",
	})
	Remotes.get("TitanState").OnClientEvent:Connect(onState)
	RunService.RenderStepped:Connect(step)
end

return TitanHud
