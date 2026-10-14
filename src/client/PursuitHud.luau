-- @file Storm Pursuit presentation: banner, world markers, the twister, audio
-- @domain world
-- @status wip
-- @see [[PursuitService.luau]]
-- @see [[V4-GAMEPLAY]]
-- Draws the Storm Pursuit event from the server's PursuitState. Nothing here decides anything.
--   Banner: one plate under the storm sign, only while an event runs (no permanent panel):
--     race      RARE CACHE · WAREHOUSE 7 · 0:24      "Grab the Storm Core first!"
--     carrier   EXTRACT TO THE SCRAPYARD · 0:38      "TWISTER 24m BEHIND - SPRINT!"
--     others    <name> HAS THE CORE · 0:38           "Help them, or be ready if it drops"
--     loose     CORE DROPPED! · 0:20                  "Grab it before the twister does"
--   Markers: a tall beam and a distance tag on the cache / dropped core; for the carrier, a
--   tag on the Scrapyard gate (the extraction).
--   The twister: a client-side funnel that eases toward the server's position every frame (so
--   it moves smoothly), spins, kicks up dust and roars when close. Reduced Effects: no spin
--   and less dust.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage.Shared:WaitForChild("Remotes"))
local Audio = require(script.Parent:WaitForChild("Audio"))
local Notifications = require(script.Parent:WaitForChild("Notifications"))
local UI = require(script.Parent:WaitForChild("UI"))

local PursuitHud = {}

local EXTRACT_AT = Vector3.new(0, 34, -222) -- the Scrapyard gate on the plateau edge
local DANGER = Color3.fromRGB(255, 96, 70)
local GOLD = Color3.fromRGB(255, 206, 70)

local state: any = nil
local banner: Frame
local title: TextLabel
local sub: TextLabel
local markerFolder: Folder
local tagPart: Part?
local tagText: TextLabel?
local funnel: Model?
local roar: Sound?
local lastPhase: string? = nil

local function clock(secondsLeft: number): string
	local s = math.max(0, math.ceil(secondsLeft))
	return ("%d:%02d"):format(s // 60, s % 60)
end

local function clearMarkers()
	markerFolder:ClearAllChildren()
	tagPart, tagText = nil, nil
end

-- A tall beam (for the cache) and/or a distance tag at `position`.
local function mark(position: Vector3, label: string, withBeam: boolean, color: Color3)
	clearMarkers()
	if withBeam then
		UI.new("Part", {
			Name = "Beam",
			Parent = markerFolder,
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Material = Enum.Material.Neon,
			Color = color,
			Transparency = 0.45,
			Size = Vector3.new(1.2, 160, 1.2),
			Position = position + Vector3.new(0, 80, 0),
		})
	end
	local p = UI.new("Part", {
		Name = "Tag",
		Parent = markerFolder,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.new(1, 1, 1),
		Position = position + Vector3.new(0, 8, 0),
	})
	local gui = UI.new("BillboardGui", {
		Parent = p,
		AlwaysOnTop = true,
		Size = UDim2.fromOffset(170, 44),
		LightInfluence = 0,
	})
	local plate = UI.new("Frame", {
		Parent = gui,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(28, 24, 20),
		BackgroundTransparency = 0.15,
	}, { UI.corner(6), UI.stroke(color, 2.5) })
	local label2 = UI.text({
		Parent = plate,
		Font = UI.Font.Mono,
		TextSize = 15,
		Size = UDim2.fromScale(1, 1),
		TextColor3 = color,
		Text = label,
	})
	label2:SetAttribute("Label", label)
	tagText = label2
	tagPart = p
end

local function buildFunnel(): Model
	local model = Instance.new("Model")
	model.Name = "TwisterFx"
	local rings = 7
	for i = 1, rings do
		local t = (i - 1) / (rings - 1)
		local ring = Instance.new("Part")
		ring.Name = "Ring" .. i
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.CastShadow = false
		ring.Shape = Enum.PartType.Cylinder
		ring.Material = Enum.Material.SmoothPlastic
		-- Dark storm grey-brown, mostly opaque: it has to read against a bright sky and a
		-- grey road from across the street.
		ring.Color = Color3.fromRGB(46, 42, 44):Lerp(Color3.fromRGB(104, 96, 92), t)
		ring.Transparency = 0.1 + t * 0.3
		local r = 3 + t * 14
		ring.Size = Vector3.new(2.6, r * 2, r * 2)
		ring:SetAttribute("Height", 1.5 + t * 32)
		ring:SetAttribute("Index", i)
		ring.Parent = model
	end
	-- The catch zone, drawn on the ground at its exact radius: step inside and you're caught.
	local zone = Instance.new("Part")
	zone.Name = "Zone"
	zone.Anchored = true
	zone.CanCollide = false
	zone.CanQuery = false
	zone.CanTouch = false
	zone.CastShadow = false
	zone.Shape = Enum.PartType.Cylinder
	zone.Material = Enum.Material.Neon
	zone.Color = Color3.fromRGB(255, 70, 50)
	zone.Transparency = 0.55
	zone.Size = Vector3.new(0.2, Config.Pursuit.CatchRadius * 2, Config.Pursuit.CatchRadius * 2)
	zone.Parent = model
	local dust = Instance.new("Part")
	dust.Name = "Dust"
	dust.Anchored = true
	dust.CanCollide = false
	dust.CanQuery = false
	dust.CanTouch = false
	dust.Transparency = 1
	dust.Size = Vector3.new(10, 1, 10)
	dust.Parent = model
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(120, 112, 100))
	emitter.Size = NumberSequence.new(4, 9)
	emitter.Transparency = NumberSequence.new(0.4, 1)
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(10, 18)
	emitter.SpreadAngle = Vector2.new(180, 20)
	emitter.Rate = if UI.reduced() then 6 else 22
	emitter.Parent = dust
	model.Parent = workspace
	local def = Config.Sounds.Wind
	local sound = Instance.new("Sound")
	sound.SoundId = def.Id
	sound.Looped = true
	sound.Volume = 0
	sound.RollOffMaxDistance = 140
	sound.RollOffMinDistance = 12
	sound.Parent = dust
	sound:Play()
	roar = sound
	return model
end

local shown = Vector3.zero

local function stepFunnel(dt: number)
	local server = workspace:FindFirstChild("PursuitTwister") :: BasePart?
	if not server then
		if funnel then
			funnel:Destroy()
			funnel, roar = nil, nil
		end
		return
	end
	if not funnel then
		funnel = buildFunnel()
		shown = server.Position
	end
	-- Ease toward the server position: smooth at any network rate, never more than a few
	-- studs behind (the server step is 0.1 s at 24 studs/s).
	shown = shown:Lerp(server.Position, math.clamp(dt * 12, 0, 1))
	local spin = if UI.reduced() then 0 else os.clock() * 4
	for _, part in (funnel :: Model):GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "Dust" and part.Name ~= "Zone" then
			local h = part:GetAttribute("Height") :: number
			local i = part:GetAttribute("Index") :: number
			local wobble = if UI.reduced() then 0 else math.sin(os.clock() * 2 + i) * (0.4 + i * 0.25)
			part.CFrame = CFrame.new(shown + Vector3.new(wobble, h, wobble * 0.6))
				* CFrame.Angles(0, spin * (1 + i * 0.1), math.rad(90))
		elseif part.Name == "Dust" then
			part.CFrame = CFrame.new(shown + Vector3.new(0, 0.5, 0))
		elseif part.Name == "Zone" then
			part.CFrame = CFrame.new(shown + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
		end
	end
	local root = Players.LocalPlayer.Character
		and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if roar and root then
		local d = ((root :: BasePart).Position - shown).Magnitude
		roar.Volume = math.clamp(1 - d / 140, 0, 1) * 0.9
	end
end

local function step(dt: number)
	stepFunnel(dt)
	if not state or state.Phase == "Done" then
		banner.Visible = false
		return
	end
	banner.Visible = true
	local left = (state.EndsAt or 0) - workspace:GetServerTimeNow()
	local me = Players.LocalPlayer
	local root = me.Character and me.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local carrier = state.Phase == "Chase" and state.CarrierId == me.UserId
	if state.Phase == "Race" then
		title.Text = ("RARE CACHE · %s · %s"):format(string.upper(state.District or ""), clock(left))
		title.TextColor3 = GOLD
		sub.Text = "A Storm Core dropped. Grab it first!"
		sub.TextColor3 = UI.Color.Text
	elseif state.Phase == "Loose" then
		title.Text = ("CORE DROPPED! · %s"):format(clock(left))
		title.TextColor3 = GOLD
		sub.Text = "Grab it before the twister does"
		sub.TextColor3 = UI.Color.Text
	elseif carrier then
		title.Text = ("EXTRACT TO THE SCRAPYARD · %s"):format(clock(left))
		title.TextColor3 = DANGER
		local server = workspace:FindFirstChild("PursuitTwister") :: BasePart?
		if server and root then
			local d = ((root.Position - server.Position) * Vector3.new(1, 0, 1)).Magnitude
			sub.Text = ("TWISTER %dm BEHIND · %s"):format(
				math.floor(d + 0.5),
				if d < 25 then "SPRINT!" else "keep moving"
			)
			sub.TextColor3 = if d < 25 then DANGER else UI.Color.Text
		else
			sub.Text = "Reach the plateau!"
		end
	else
		title.Text = ("%s HAS THE CORE · %s"):format(
			string.upper(state.CarrierName or "SOMEONE"),
			clock(left)
		)
		title.TextColor3 = GOLD
		sub.Text = "If the twister catches them, it drops"
		sub.TextColor3 = UI.Color.Text
	end
	if tagPart and tagText and root then
		local d = (tagPart.Position - root.Position).Magnitude
		tagText.Text = ("%s  %dm"):format(tagText:GetAttribute("Label") :: string, math.floor(d + 0.5))
	end
end

local function onState(msg: any)
	if type(msg) ~= "table" then
		return
	end
	local previous = lastPhase
	state = msg
	lastPhase = msg.Phase
	local me = Players.LocalPlayer
	if msg.Phase == "Race" then
		if previous ~= "Race" then
			Audio.play("Siren", 1)
			Notifications.feed(
				("RARE CACHE in %s! First to grab it gets chased home."):format(msg.District or "town"),
				GOLD,
				5
			)
		end
		if msg.Target then
			mark(msg.Target, "RARE CACHE", true, GOLD)
		end
	elseif msg.Phase == "Loose" then
		Audio.play("WarnWind", 0.8)
		if msg.Target then
			mark(msg.Target, "DROPPED CORE", true, GOLD)
		end
	elseif msg.Phase == "Chase" then
		if msg.CarrierId == me.UserId then
			Audio.play("FindCore", 1)
			Audio.play("WarnWind", 1)
			mark(EXTRACT_AT, "EXTRACT", false, Color3.fromRGB(140, 230, 150))
		else
			clearMarkers()
		end
	elseif msg.Phase == "Done" then
		clearMarkers()
		if msg.Result == "Extracted" then
			Audio.play("CoreDelivered", 1)
			local mine = msg.CarrierName == me.DisplayName
			Notifications.feed(
				if mine
					then ("EXTRACTED in %.1fs! +%d bonus%s · sell the core on the hill"):format(
						msg.Seconds or 0,
						Config.Pursuit.ExtractCoins,
						if msg.Best then " · NEW PERSONAL BEST" else ""
					)
					else ("%s extracted the rare cache in %.1fs!"):format(
						msg.CarrierName or "Someone",
						msg.Seconds or 0
					),
				GOLD,
				6
			)
		elseif msg.Result == "Expired" then
			Notifications.feed("The core destabilised. Out of time.", DANGER, 4)
		elseif msg.Result == "Unclaimed" then
			Notifications.feed("Nobody claimed the rare cache.", UI.Color.TextDim, 3)
		end
	end
end

function PursuitHud.init(topStack: Frame)
	markerFolder = Instance.new("Folder")
	markerFolder.Name = "PursuitMarkers"
	markerFolder.Parent = workspace
	banner = UI.plate({
		Name = "PursuitBanner",
		Parent = topStack,
		LayoutOrder = 4,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		Visible = false,
	})
	UI.padding(5, 14).Parent = banner
	UI.new("UIListLayout", {
		Parent = banner,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	title = UI.text({
		Parent = banner,
		LayoutOrder = 1,
		Font = UI.Font.Mono,
		TextSize = 18,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		TextColor3 = GOLD,
		Text = "",
	})
	sub = UI.text({
		Parent = banner,
		LayoutOrder = 2,
		Font = UI.Font.Body,
		TextSize = 14,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		Text = "",
	})
	Remotes.get("PursuitState").OnClientEvent:Connect(onState)
	RunService.RenderStepped:Connect(step)
end

return PursuitHud
