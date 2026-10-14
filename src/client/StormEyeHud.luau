-- @file The Storm's Eye, drawn: the calm pocket, its wall, the Storm Heart beacon, the banner
-- @domain world
-- @status wip
-- @see [[StormEyeService.luau]]
-- The server owns the Eye (StormEye remote: centre, radius, the Heart's spot). This draws it:
--   * the eye wall: a ring of tall ForceField panels slowly turning (fewer, still, in Reduced
--     Effects), lavender against the storm, so the calm reads from across town;
--   * a soft lit disc on the ground marking where it's safe, and a beam of clear light;
--   * the Storm Heart: a tall violet beacon with its distance, until someone takes it;
--   * an objective-strip entry (EventStrip): where the Eye is and who can take the Heart.
-- The centre is eased toward each server update so the drift is smooth between updates.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Audio = require(script.Parent:WaitForChild("Audio"))
local UI = require(script.Parent:WaitForChild("UI"))
local WorldMotion = require(script.Parent:WaitForChild("WorldMotion"))
local EventStrip = require(script.Parent:WaitForChild("EventStrip"))

local StormEyeHud = {}

local VIOLET = Color3.fromRGB(200, 150, 255)
local WALL = Color3.fromRGB(190, 170, 255)
local HEIGHT = 70

local folder: Folder
local wall: Model? = nil
local panels: { BasePart } = {}
local disc: BasePart? = nil
local heartBeacon: BasePart? = nil
local heartLabel: TextLabel? = nil
local target: Vector3? = nil
local shown: Vector3? = nil
local radius = 22
local heart: Vector3? = nil
local spin = 0
local hadHeart = false

local function clear()
	if wall then
		wall:Destroy()
		wall = nil
	end
	panels = {}
	disc = nil
	if heartBeacon then
		heartBeacon:Destroy()
		heartBeacon = nil
		heartLabel = nil
	end
	EventStrip.clear("eye")
	target, shown, heart = nil, nil, nil
	hadHeart = false
end

local function build(center: Vector3)
	local model = Instance.new("Model")
	model.Name = "StormEye"
	local count = if UI.reduced() then 10 else 20
	for i = 1, count do
		local p = Instance.new("Part")
		p.Name = "Wall"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.ForceField
		p.Color = WALL
		p.Transparency = 0.25
		p.Size = Vector3.new(2 * math.pi * radius / count + 1, HEIGHT, 1)
		p:SetAttribute("Angle", (i - 1) / count * math.pi * 2)
		p.Parent = model
		table.insert(panels, p)
	end
	local d = Instance.new("Part")
	d.Name = "Calm"
	d.Shape = Enum.PartType.Cylinder
	d.Anchored = true
	d.CanCollide = false
	d.CanQuery = false
	d.CanTouch = false
	d.CastShadow = false
	d.Material = Enum.Material.Neon
	d.Color = Color3.fromRGB(230, 220, 255)
	d.Transparency = 0.85
	d.Size = Vector3.new(0.2, radius * 2, radius * 2)
	d.Parent = model
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(235, 230, 255)
	light.Range = radius
	light.Brightness = 1.5
	light.Parent = d
	disc = d
	model.Parent = folder
	wall = model
	shown = center
end

local function makeHeartBeacon(at: Vector3)
	local b = Instance.new("Part")
	b.Name = "HeartBeacon"
	b.Anchored = true
	b.CanCollide = false
	b.CanQuery = false
	b.CanTouch = false
	b.CastShadow = false
	b.Material = Enum.Material.Neon
	b.Color = VIOLET
	b.Transparency = 0.45
	b.Size = Vector3.new(1.2, 140, 1.2)
	b.Position = at + Vector3.new(0, 70, 0)
	b.Parent = folder

	WorldMotion.beacon(b)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 40)
	gui.StudsOffset = Vector3.new(0, -60, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 600
	gui.LightInfluence = 0
	local label = UI.text({
		Parent = gui,
		Font = UI.Font.Mono,
		TextSize = 16,
		Size = UDim2.fromScale(1, 1),
		TextColor3 = VIOLET,
		Outline = true,
		Text = "STORM HEART",
	})
	gui.Parent = b
	heartBeacon = b
	heartLabel = label
end

local function onState(m: any)
	if type(m) ~= "table" or not m.Active then
		clear()
		return
	end
	radius = m.Radius or radius
	target = m.Center
	if not wall and target then
		build(target)
		Audio.play("WarnWind", 0.6, 0.6)
	end
	if m.Heart and not heartBeacon then
		makeHeartBeacon(m.Heart)
		Audio.play("CoreDelivered", 0.5)
	elseif not m.Heart and heartBeacon then
		heartBeacon:Destroy()
		heartBeacon = nil
		heartLabel = nil
	end
	hadHeart = hadHeart or m.Heart ~= nil
	heart = m.Heart
end

local function isHunter(): boolean
	local band = Players.LocalPlayer:GetAttribute("Band")
	return type(band) == "number" and band >= 3
end

local function step(dt: number)
	if not wall or not target then
		return
	end
	shown = (shown :: Vector3):Lerp(target :: Vector3, math.min(1, dt * 4))
	local c = shown :: Vector3
	if not UI.reduced() then
		spin += dt * 0.25
	end
	for _, p in panels do
		local a = (p:GetAttribute("Angle") :: number) + spin
		local pos = c + Vector3.new(math.cos(a) * radius, HEIGHT / 2 - 4, math.sin(a) * radius)
		p.CFrame = CFrame.lookAt(pos, Vector3.new(c.X, pos.Y, c.Z))
	end
	if disc then
		disc.CFrame = CFrame.new(c.X, c.Y + 0.2, c.Z) * CFrame.Angles(0, 0, math.pi / 2)
	end
	local root = Players.LocalPlayer.Character
		and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local inside = root ~= nil and ((root.Position - c) * Vector3.new(1, 0, 1)).Magnitude <= radius
	local e = {
		Priority = if inside then 66 else 64,
		Title = if inside then "Inside the Storm's Eye · calm" else "The Storm's Eye",
		Sub = "",
		Accent = VIOLET,
		Pill = "STORM'S EYE",
	}
	if heart and root then
		local d = math.floor(((root.Position - heart) * Vector3.new(1, 0, 1)).Magnitude)
		if heartLabel then
			heartLabel.Text = ("STORM HEART · %dm"):format(d)
		end
		if isHunter() then
			e.Priority = if inside then 86 else 70
			e.Sub = ("The Storm Heart is %dm away. Grab it before the calm drifts off it!"):format(d)
			e.Pill = ("HEART %dm"):format(d)
		else
			e.Sub = "Shelter here. The Storm Heart is for Storm Hunters."
		end
	elseif hadHeart then
		e.Sub = "Someone took the Storm Heart. The calm still shelters you."
	else
		e.Sub = "No wind, debris or lightning inside (floods still rise). A Storm Heart is forming..."
	end
	EventStrip.set("eye", e)
end

function StormEyeHud.init(_topStack: Frame)
	folder = Instance.new("Folder")
	folder.Name = "StormEyeFx"
	folder.Parent = workspace
	Remotes.get("StormEye").OnClientEvent:Connect(onState)
	RunService.RenderStepped:Connect(step)
end

return StormEyeHud
