-- Client-side storm presentation: what each storm looks and feels like, and the readouts that
-- let a player plan around it. Gameplay (damage, strike positions, gust and flood timing) is
-- decided by the server and arrives in the storm state; this only draws it.
--
--   Wind: gust timer, push (steady vs gust), streaks, trees and bushes leaning.
--   Flood: water level and next rise, "climb here" markers on every ladder and the ramp.
--   Lightning: full-size strike zone from the first frame, a beam to spot it from afar,
--              impact flash, scorch and sparks.
-- A personal alert (Notifications.danger) appears only when *you* are in danger.

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Shelter = require(ReplicatedStorage.Shared:WaitForChild("Shelter"))
local Audio = require(script.Parent:WaitForChild("Audio"))
local Notifications = require(script.Parent:WaitForChild("Notifications"))
local UI = require(script.Parent:WaitForChild("UI"))

local T = Config.StormTuning
local player = Players.LocalPlayer

local StormEffects = {}

local state: any = { Phase = "Calm", EndsAt = 0 }
local reduced = false

local effects: Folder
local flash: ColorCorrectionEffect
local rain: ParticleEmitter
local rainAnchor: Part
local windStreaks: ParticleEmitter
local windAnchor: Part

local function new(className: string, props: { [string]: any }): any
	local inst = Instance.new(className)
	local parent = props.Parent
	props.Parent = nil
	for k, v in props do
		(inst :: any)[k] = v
	end
	inst.Parent = parent
	return inst
end

local function inSafeZone(position: Vector3): boolean
	return position.Z < Config.SafeZoneMaxZ and position.Y > 20
end

local function rootPart(): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

---------------------------------------------------------------------------- Wind

-- "lull" | "warn" | "gust" and the seconds until it changes, or nil outside a windstorm.
function StormEffects.gustPhase(now: number): (string?, number)
	if state.Phase ~= "Storm" or state.Storm ~= "Wind" or (state.GustAt or 0) == 0 then
		return nil, 0
	end
	if now >= state.GustAt and now < state.GustEnd then
		return "gust", state.GustEnd - now
	elseif now >= state.GustAt - T.GustWarnSeconds and now < state.GustAt then
		return "warn", state.GustAt - now
	end
	return "lull", math.max(0, state.GustAt - T.GustWarnSeconds - now)
end

local windForce: VectorForce? = nil
local function getWindForce(): VectorForce?
	local root = rootPart()
	if not root then
		return nil
	end
	if windForce and windForce.Parent == root then
		return windForce
	end
	local attachment = root:FindFirstChild("RootAttachment") or new("Attachment", { Parent = root })
	windForce = new("VectorForce", {
		Parent = root,
		Attachment0 = attachment,
		RelativeTo = Enum.ActuatorRelativeTo.World,
		ApplyAtCenterOfMass = true,
		Enabled = false,
	})
	return windForce
end

-- Trees and bushes lean downwind, harder in a gust. Pivots are at each model's base.
local swayers: { { Model: Model, Base: CFrame, Height: number, Seed: number } } = {}
local swaying = false

local function collectSwayers()
	local map = workspace:WaitForChild("Map", 30)
	if not map then
		return
	end
	for _, d in map:GetDescendants() do
		if d:IsA("Model") and (d.Name == "TreeBlocky" or d.Name == "BushRound") then
			table.insert(swayers, {
				Model = d,
				Base = d:GetPivot(),
				Height = d:GetExtentsSize().Y,
				Seed = d:GetPivot().Position.X * 0.37 + d:GetPivot().Position.Z * 0.11,
			})
		end
	end
end

local function sway(now: number, strength: number, cameraPosition: Vector3)
	local dir = state.WindDir or Vector3.new(1, 0, 0)
	local axis = Vector3.new(0, 1, 0):Cross(dir) -- leaning around this axis tips the top downwind
	for _, s in swayers do
		if (s.Base.Position - cameraPosition).Magnitude < 160 then
			local stiffness = s.Height > 8 and 1 or 0.6
			local wobble = 0.75 + 0.25 * math.sin(now * 2.3 + s.Seed)
			local angle = math.rad(strength * stiffness * wobble)
			s.Model:PivotTo(CFrame.fromAxisAngle(axis, angle) * s.Base.Rotation + s.Base.Position)
		end
	end
	swaying = true
end

local function resetSway()
	if swaying then
		for _, s in swayers do
			s.Model:PivotTo(s.Base)
		end
		swaying = false
	end
end

---------------------------------------------------------------------------- Flood

-- Climb markers are guidance, not decoration: small, shown only during a flood warning or
-- flood while you're below the flood line, and only for routes near you (no labels floating
-- over the skyline from across town).
type Marker = { Gui: BillboardGui, Position: Vector3, Range: number }
local markers: { Marker } = {}

local function marker(adornee: BasePart, offset: Vector3, text: string, range: number)
	-- Parented to the ladder itself and drawn in the world (not AlwaysOnTop): in Studio
	-- captures, billboards in a loose folder or drawn on top didn't show up at all.
	local gui = new("BillboardGui", {
		Name = "HighGroundMarker",
		Parent = adornee,
		Adornee = adornee,
		AlwaysOnTop = false,
		Size = UDim2.fromOffset(if #text > 8 then 128 else 84, 24),
		StudsOffsetWorldSpace = offset,
		MaxDistance = range + 20,
		LightInfluence = 0,
		Enabled = false,
	})
	local frame = new("Frame", {
		Parent = gui,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(240, 190, 50),
		BackgroundTransparency = 0.05,
	})
	new("UICorner", { Parent = frame, CornerRadius = UDim.new(0, UI.Radius.Chip) })
	new("UIStroke", { Parent = frame, Thickness = 2, Color = UI.Color.Outline })
	new("TextLabel", {
		Parent = frame,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = text,
		Font = UI.Font.Title,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(35, 28, 8),
	})
	table.insert(markers, { Gui = gui, Position = adornee.Position + offset, Range = range })
end

local function collectMarkers()
	local map = workspace:WaitForChild("Map", 30)
	if not map then
		return
	end
	for _, d in map:GetDescendants() do
		if d:IsA("TrussPart") then
			marker(d, Vector3.new(0, d.Size.Y / 2 + 2, 0), "▲ CLIMB", 110)
		end
	end
	local ramp = map:FindFirstChild("Ramp")
	if ramp and ramp:IsA("BasePart") then
		marker(ramp, Vector3.new(0, ramp.Size.Y / 2 + 4, 0), "▲ HIGH GROUND", 170)
	end
end

local markersShown = false
local markerCheckAt = 0

-- `near` is where the player is, or nil to hide every marker.
local function showMarkers(near: Vector3?)
	if not near then
		if markersShown then
			markersShown = false
			for _, m in markers do
				m.Gui.Enabled = false
			end
		end
		return
	end
	if os.clock() < markerCheckAt then
		return
	end
	markerCheckAt = os.clock() + 0.25
	markersShown = true
	for _, m in markers do
		m.Gui.Enabled = (m.Position - near).Magnitude <= m.Range
	end
end

---------------------------------------------------------------------------- Lightning

-- Strikes announced to this client that haven't landed yet (for the personal alert).
local strikes: { { Position: Vector3, Radius: number, LandsAt: number } } = {}

local function lightningFlash(position: Vector3)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local distance = (camera.CFrame.Position - position).Magnitude
	if distance <= 220 and not reduced then
		flash.Brightness = 0.35 * (1 - distance / 220)
		TweenService:Create(
			flash,
			TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Brightness = 0 }
		):Play()
	end
	-- Thunder comes from the strike itself, a beat after the flash; the pitch varies a little
	-- so a run of strikes doesn't sound like one sample on repeat.
	task.delay(distance / 400, Audio.playAt, "Thunder", position, 1, 0.9 + math.random() * 0.2)
end

local function impact(position: Vector3, radius: number)
	local scorch = new("Part", {
		Parent = effects,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, radius * 1.2, radius * 1.2),
		CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(25, 22, 20),
		Transparency = 0.25,
	})
	TweenService:Create(scorch, TweenInfo.new(4, Enum.EasingStyle.Linear), { Transparency = 1 }):Play()
	Debris:AddItem(scorch, 4.1)
	local sparkAnchor =
		new("Attachment", { Parent = workspace.Terrain, WorldPosition = position + Vector3.new(0, 1, 0) })
	local sparks = new("ParticleEmitter", {
		Parent = sparkAnchor,
		Enabled = false,
		Rate = 0,
		Lifetime = NumberRange.new(0.3, 0.7),
		Speed = NumberRange.new(20, 40),
		SpreadAngle = Vector2.new(80, 80),
		Acceleration = Vector3.new(0, -60, 0),
		Size = NumberSequence.new(0.25, 0),
		Color = ColorSequence.new(Color3.fromRGB(255, 240, 180)),
		LightEmission = 1,
	})
	sparks:Emit(if reduced then 8 else 24)
	Debris:AddItem(sparkAnchor, 1)
end

local function onLightningWarning(position: Vector3, radius: number, delay: number)
	local landsAt = os.clock() + delay
	table.insert(strikes, { Position = position, Radius = radius, LandsAt = landsAt })
	local flat = CFrame.new(position + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.rad(90))
	-- The whole danger zone shows at once; the bright core grows to fill it as the strike nears.
	local zone = new("Part", {
		Parent = effects,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.15, radius * 2, radius * 2),
		CFrame = flat,
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 70, 50),
		Transparency = 0.7,
	})
	local core = new("Part", {
		Parent = effects,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 1, 1),
		CFrame = flat * CFrame.new(0.05, 0, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 230, 80),
		Transparency = 0.35,
	})
	-- A faint column marks the spot from across town.
	local beam = new("Part", {
		Parent = effects,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Size = Vector3.new(0.5, 70, 0.5),
		CFrame = CFrame.new(position + Vector3.new(0, 35, 0)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 220, 120),
		Transparency = 0.75,
	})
	TweenService:Create(core, TweenInfo.new(delay, Enum.EasingStyle.Linear), {
		Size = Vector3.new(0.2, radius * 2, radius * 2),
		Color = Color3.fromRGB(255, 60, 40),
	}):Play()
	TweenService:Create(beam, TweenInfo.new(delay, Enum.EasingStyle.Linear), { Transparency = 0.45 }):Play()
	Debris:AddItem(zone, delay + 0.05)
	Debris:AddItem(core, delay + 0.05)
	Debris:AddItem(beam, delay + 0.05)
	task.delay(delay, function()
		for i, s in strikes do
			if s.LandsAt == landsAt and s.Position == position then
				table.remove(strikes, i)
				break
			end
		end
		lightningFlash(position)
		impact(position, radius)
	end)
end

---------------------------------------------------------------------------- Per frame

local shelterCheckAt = 0
local sheltered = false
local lastGust: string? = nil
local lastFloodLevel = 0
local function setAlert(text: string, color: Color3?)
	Notifications.danger(text, color)
end

-- The storm strip's status line: what the storm is doing right now. The strip shows the
-- time left separately.
function StormEffects.statusLine(now: number): (string?, Color3?)
	if state.Phase ~= "Storm" then
		return nil, nil
	end
	if state.Storm == "Wind" then
		local phase, secs = StormEffects.gustPhase(now)
		if phase == "gust" then
			return ("GUST! Hold cover for %ds"):format(math.ceil(secs)), UI.Color.Danger
		elseif phase == "warn" then
			return ("Gust in %.1fs - get behind a wall!"):format(secs), UI.Color.Warn
		elseif phase == "lull" then
			return ("Lull: move now! Next gust in %ds"):format(math.ceil(secs + T.GustWarnSeconds)),
				UI.Color.Safe
		end
	elseif state.Storm == "Flood" then
		local level, max = state.FloodLevel or 0, state.FloodMax or 0
		if (state.FloodNextAt or 0) > now then
			return ("Water %d/%d - rising in %ds"):format(level, max, math.ceil(state.FloodNextAt - now)),
				UI.Color.Water
		end
		return "Water at its peak - stay high", UI.Color.Water
	elseif state.Storm == "Lightning" then
		return "Step out of red circles!", Color3.fromRGB(255, 225, 120)
	end
	return nil, nil
end

function StormEffects.step(now: number)
	local camera = workspace.CurrentCamera
	local stormActive = state.Phase == "Storm"
	local storm = state.Storm
	local gust = StormEffects.gustPhase(now)

	rain.Enabled = stormActive and (storm == "Flood" or storm == "Lightning")
	windStreaks.Enabled = stormActive and storm == "Wind"
	local streakRate = if gust == "gust" then 340 elseif gust == "warn" then 200 else 80
	windStreaks.Rate = if reduced then streakRate * 0.5 else streakRate
	Audio.setAmbience("Wind", stormActive and storm == "Wind", if gust == "gust" then 1 else 0.55)

	if camera then
		local camPos = camera.CFrame.Position
		rainAnchor.CFrame = CFrame.new(camPos + Vector3.new(0, 40, 0))
		if windStreaks.Enabled then
			local dir = state.WindDir
			windAnchor.CFrame =
				CFrame.lookAt(camPos - dir * 60 + Vector3.new(0, 4, 0), camPos + Vector3.new(0, 4, 0))
		end
		if stormActive and storm == "Wind" and not reduced then
			sway(now, if gust == "gust" then 7 else 2.5, camPos)
		else
			resetSway()
		end
	end

	-- Gust impact and each rise of the water get their own sound.
	if gust == "gust" and lastGust ~= "gust" then
		Audio.play("Gust")
	end
	lastGust = gust
	local level = state.FloodLevel or 0
	if stormActive and storm == "Flood" and level > lastFloodLevel then
		Audio.play("WarnFlood", 0.6, 1.1)
	end
	lastFloodLevel = if stormActive then level else 0

	local root = rootPart()
	local force = getWindForce()
	if not root then
		showMarkers(nil)
		setAlert("")
		return
	end
	if os.clock() > shelterCheckAt then
		shelterCheckAt = os.clock() + 0.25
		sheltered = Shelter.isSheltered(root.Position) or inSafeZone(root.Position)
	end
	local exposed = not sheltered
	local pos = root.Position

	if force then
		local windy = stormActive and storm == "Wind" and exposed
		force.Enabled = windy
		if windy then
			local push = if gust == "gust" then T.GustPush else T.WindPush
			force.Force = state.WindDir * root.AssemblyMass * push
		end
	end

	-- Flood guidance only for players who need it: below the flood line during the warning
	-- or the flood, and only the routes near them.
	local floodDanger = storm == "Flood" and (state.Phase == "Warning" or stormActive) and not inSafeZone(pos)
	local feet = pos.Y - 3
	local floodMax = if (state.FloodMax or 0) > 0 then state.FloodMax else 12
	local belowLine = floodDanger and feet < floodMax
	showMarkers(if belowLine then pos else nil)

	-- Personal danger, most urgent first. The strip already shows timers, so these stay
	-- short and steady.
	for _, s in strikes do
		if ((pos - s.Position) * Vector3.new(1, 0, 1)).Magnitude <= s.Radius + 1 and exposed then
			setAlert("MOVE! Lightning is about to strike here", UI.Color.Danger)
			return
		end
	end
	if storm == "Wind" and stormActive and exposed and (gust == "warn" or gust == "gust") then
		setAlert(
			if gust == "warn" then "You're in the open - gust coming!" else "Get behind a wall!",
			UI.Color.Warn
		)
		return
	end
	if belowLine then
		if level > 0 and feet < level then
			setAlert("You're in the flood! Climb a ▲ ladder or head uphill", UI.Color.Water)
		else
			setAlert(
				"Below the flood line - get to a ▲ ladder or high ground",
				Color3.fromRGB(150, 200, 255)
			)
		end
		return
	end
	setAlert("")
end

function StormEffects.setState(s)
	state = s
end

function StormEffects.setReduced(on: boolean)
	reduced = on
	if on then
		resetSway()
	end
end

function StormEffects.isReduced(): boolean
	return reduced
end

function StormEffects.init(lightningRemote: RemoteEvent)
	effects = new("Folder", { Name = "ClientEffects", Parent = workspace })
	-- Client-only grade for lightning flashes, separate from the server's storm grade.
	flash = new("ColorCorrectionEffect", { Name = "LightningFlash", Parent = Lighting })

	rainAnchor = new("Part", {
		Parent = effects,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		Transparency = 1,
		Size = Vector3.new(90, 1, 90),
	})
	rain = new("ParticleEmitter", {
		Parent = rainAnchor,
		Enabled = false,
		Rate = 600,
		Lifetime = NumberRange.new(0.8, 1.2),
		Speed = NumberRange.new(70, 90),
		EmissionDirection = Enum.NormalId.Bottom,
		Size = NumberSequence.new(0.18),
		Squash = NumberSequence.new(2.5), -- stretch into streaks
		Color = ColorSequence.new(Color3.fromRGB(190, 210, 235)),
		Transparency = NumberSequence.new(0.2),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		LightEmission = 0.3,
	})

	-- Wind streaks blow past the camera from upwind during windstorms.
	windAnchor = new("Part", {
		Parent = effects,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		Transparency = 1,
		Size = Vector3.new(120, 40, 1),
	})
	windStreaks = new("ParticleEmitter", {
		Parent = windAnchor,
		Enabled = false,
		Rate = 160,
		Lifetime = NumberRange.new(1, 1.4),
		Speed = NumberRange.new(90, 120),
		EmissionDirection = Enum.NormalId.Front,
		Size = NumberSequence.new(0.14),
		Squash = NumberSequence.new(3),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.5),
			NumberSequenceKeypoint.new(0.8, 0.5),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Color = ColorSequence.new(Color3.fromRGB(225, 220, 205)),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		LightEmission = 0.1,
	})

	lightningRemote.OnClientEvent:Connect(onLightningWarning)
	task.spawn(collectSwayers)
	task.spawn(collectMarkers)
end

return StormEffects
