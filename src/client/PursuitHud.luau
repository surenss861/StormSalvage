-- @file Post-storm events presentation: banner, markers, the twister, strikes, audio
-- @domain world
-- @status wip
-- @see [[PursuitService.luau]]
-- @see [[EventService.luau]]
-- @see [[V4-GAMEPLAY]]
-- Draws the post-storm events from the server's PursuitState and PursuitStrike. Nothing here
-- decides anything.
--   Banner: one plate under the storm sign, only while an event runs (no permanent panel). The
--   wording follows the kind: RARE CACHE (Pursuit), UNSTABLE CORE (Extraction), SALVAGE RUSH.
--   Markers: a tall beam and a distance tag on the cache, the dropped core or the rush site; for
--   the carrier, a tag on the Scrapyard gate (the extraction).
--   The twister: a client-side funnel eased toward the server's position every frame. It reads
--   its state from the server part: Forming (grows out of the ground), Chasing, WindUp (the base
--   glows red just before a debris strike), Stunned (shrinks and pales after a catch),
--   Searching (no route to you: it wanders in place). It leans toward where it's going, has
--   orbiting debris, a red catch ring at its exact radius and a roar that grows as it closes.
--   Strikes: Debris (twister) is a brown dust ring with chunks raining in; Surge (unstable
--   core) is a cyan electric ring that pulses. Neither reuses the storm's lightning.
-- Reduced Effects: no spin, wobble or orbiting debris, and less dust.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage.Shared:WaitForChild("Remotes"))
local Audio = require(script.Parent:WaitForChild("Audio"))
local Notifications = require(script.Parent:WaitForChild("Notifications"))
local SalvageFeedback = require(script.Parent:WaitForChild("SalvageFeedback"))
local UI = require(script.Parent:WaitForChild("UI"))

local PursuitHud = {}

local EXTRACT_AT = Vector3.new(0, 34, -222) -- the Scrapyard gate on the plateau edge
local DANGER = Color3.fromRGB(255, 96, 70)
local GOLD = Color3.fromRGB(255, 206, 70)
local SURGE = Color3.fromRGB(90, 220, 255)
local FUNNEL_DARK = Color3.fromRGB(46, 42, 44)
local FUNNEL_LIGHT = Color3.fromRGB(104, 96, 92)

local state: any = nil
local banner: Frame
local title: TextLabel
local sub: TextLabel
local markerFolder: Folder
local fxFolder: Folder
local tagPart: Part?
local tagText: TextLabel?
local funnel: Model?
local roar: Sound?
local lastKey = ""

local function clock(secondsLeft: number): string
	local s = math.max(0, math.ceil(secondsLeft))
	return ("%d:%02d"):format(s // 60, s % 60)
end

local function clearMarkers()
	markerFolder:ClearAllChildren()
	tagPart, tagText = nil, nil
end

-- A tall beam (optional) and a distance tag at `position`.
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
		Size = UDim2.fromOffset(190, 44),
		LightInfluence = 0,
	})
	local plate = UI.new("Frame", {
		Parent = gui,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(28, 24, 20),
		BackgroundTransparency = 0.15,
	}, { UI.corner(6), UI.stroke(color, 2.5) })
	local text = UI.text({
		Parent = plate,
		Font = UI.Font.Mono,
		TextSize = 15,
		Size = UDim2.fromScale(1, 1),
		TextColor3 = color,
		Text = label,
	})
	text:SetAttribute("Label", label)
	tagText = text
	tagPart = p
end

---------------------------------------------------------------------------- The twister

local function part(model: Model, name: string, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = model
	return p
end

local function buildFunnel(): Model
	local model = Instance.new("Model")
	model.Name = "TwisterFx"
	-- A tapered funnel: thin and dark at the ground, wide and paler up top.
	local rings = 9
	for i = 1, rings do
		local t = (i - 1) / (rings - 1)
		local r = 2.2 + t * t * 15
		local ring = part(model, "Ring" .. i, {
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.SmoothPlastic,
			Color = FUNNEL_DARK:Lerp(FUNNEL_LIGHT, t),
			Transparency = 0.08 + t * 0.32,
			Size = Vector3.new(3.2, r * 2, r * 2),
		})
		ring:SetAttribute("Height", 1.6 + t * 34)
		ring:SetAttribute("Index", i)
	end
	-- The base glows red during a wind-up and on a catch.
	local base = part(model, "Base", {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Neon,
		Color = DANGER,
		Transparency = 1,
		Size = Vector3.new(1.2, 7, 7),
	})
	base:SetAttribute("Height", 1)
	-- Orbiting debris: planks and panels whirling round the funnel.
	for i = 1, 8 do
		local chunk = part(model, "Chunk", {
			Material = Enum.Material.WoodPlanks,
			Color = Color3.fromRGB(110, 84, 60):Lerp(Color3.fromRGB(150, 150, 150), (i % 3) / 2),
			Size = Vector3.new(0.6 + (i % 3) * 0.5, 0.3, 1.6 + (i % 2) * 1.2),
		})
		chunk:SetAttribute("Orbit", i)
	end
	-- The catch zone, drawn on the ground at its exact radius.
	part(model, "Zone", {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 70, 50),
		Transparency = 0.55,
		Size = Vector3.new(0.2, Config.Pursuit.CatchRadius * 2, Config.Pursuit.CatchRadius * 2),
	})
	local dust = part(model, "Dust", { Transparency = 1, Size = Vector3.new(10, 1, 10) })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(120, 112, 100))
	emitter.Size = NumberSequence.new(4, 10)
	emitter.Transparency = NumberSequence.new(0.35, 1)
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(10, 18)
	emitter.SpreadAngle = Vector2.new(180, 20)
	emitter.Rate = if UI.reduced() then 6 else 24
	emitter.Parent = dust
	model.Parent = fxFolder
	local sound = Instance.new("Sound")
	sound.SoundId = Config.Sounds.Wind.Id
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
local lean = Vector3.zero
local scale = 0
local formStart = 0
local lastState: string? = nil
local lastCaughtAt = 0

local function stepFunnel(dt: number)
	local server = workspace:FindFirstChild("PursuitTwister") :: BasePart?
	if not server then
		if funnel then
			funnel:Destroy()
			funnel, roar = nil, nil
		end
		lastState = nil
		return
	end
	if not funnel then
		funnel = buildFunnel()
		shown = server.Position
		scale = 0
		formStart = os.clock()
	end
	local st = server:GetAttribute("State") :: string?
	if st ~= lastState then
		if st == "WindUp" then
			Audio.playAt("WarnWind", server.Position, 0.9)
		elseif st == "Forming" then
			Audio.playAt("Gust", server.Position, 1)
		end
		lastState = st
	end
	local caughtAt = tonumber(server:GetAttribute("CaughtAt")) or 0
	if caughtAt > lastCaughtAt then
		lastCaughtAt = caughtAt
		Audio.playAt("Gust", server.Position, 1.2)
	end
	local reduced = UI.reduced()
	local previous = shown
	shown = shown:Lerp(server.Position, math.clamp(dt * 12, 0, 1))
	local velocity = (shown - previous) / math.max(dt, 1e-3)
	lean = lean:Lerp(velocity * Vector3.new(1, 0, 1) * 0.02, math.clamp(dt * 4, 0, 1))
	local form =
		math.clamp((os.clock() - formStart) / (tonumber(server:GetAttribute("FormSeconds")) or 0.8), 0, 1)
	local target = if st == "Stunned" then 0.6 elseif st == "Forming" then form else 1
	scale += (target - scale) * math.clamp(dt * 6, 0, 1)
	local spinRate = if st == "Stunned" then 1.2 elseif st == "WindUp" then 7 else 4
	local spin = if reduced then 0 else os.clock() * spinRate
	local pale = if st == "Stunned" then 0.35 else 0
	for _, p in (funnel :: Model):GetChildren() do
		if not p:IsA("BasePart") then
			continue
		end
		local h = p:GetAttribute("Height") :: number?
		local i = p:GetAttribute("Index") :: number?
		local orbit = p:GetAttribute("Orbit") :: number?
		if p.Name == "Zone" then
			p.CFrame = CFrame.new(shown + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
			p.Transparency = if st == "Stunned" or st == "Forming" then 0.8 else 0.55
		elseif p.Name == "Dust" then
			p.CFrame = CFrame.new(shown + Vector3.new(0, 0.5, 0))
		elseif p.Name == "Base" then
			p.CFrame = CFrame.new(shown + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90))
			local glow = st == "WindUp" or workspace:GetServerTimeNow() - caughtAt < 0.6
			p.Transparency = if glow then 0.25 + 0.2 * math.sin(os.clock() * 30) else 1
		elseif orbit then
			if reduced then
				p.Transparency = 1
			else
				p.Transparency = 0
				local a = os.clock() * (2.4 + orbit * 0.15) + orbit
				local height = (4 + (orbit * 3.7) % 26) * scale
				local radius = (3 + height * 0.42)
				local at = shown
					+ lean * height
					+ Vector3.new(math.cos(a) * radius, height, math.sin(a) * radius)
				p.CFrame = CFrame.new(at) * CFrame.Angles(a, a * 1.3, 0)
			end
		elseif h and i then
			local wobble = if reduced then 0 else math.sin(os.clock() * 2 + i) * (0.4 + i * 0.25)
			local height = h * scale
			p.CFrame = CFrame.new(shown + lean * height + Vector3.new(wobble, height, wobble * 0.6))
				* CFrame.Angles(0, spin * (1 + i * 0.1), math.rad(90))
			local t = (i - 1) / 8
			p.Color = FUNNEL_DARK:Lerp(FUNNEL_LIGHT, math.min(1, t + pale))
			p.Transparency = math.min(0.9, 0.08 + t * 0.32 + pale)
		end
	end
	local root = Players.LocalPlayer.Character
		and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if roar and root then
		local d = ((root :: BasePart).Position - shown).Magnitude
		roar.Volume = math.clamp(1 - d / 140, 0, 1) * (if st == "Stunned" then 0.4 else 0.95)
	end
end

---------------------------------------------------------------------------- Strikes

local function onStrike(style: string, position: Vector3, radius: number, warn: number)
	local color = if style == "Surge" then SURGE else Color3.fromRGB(196, 120, 60)
	local flat = CFrame.new(position + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local zone = part(fxFolder :: any, "StrikeZone", {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Neon,
		Color = color,
		Transparency = 0.65,
		Size = Vector3.new(0.15, radius * 2, radius * 2),
		CFrame = flat,
	})
	local core = part(fxFolder :: any, "StrikeCore", {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Neon,
		Color = color,
		Transparency = 0.3,
		Size = Vector3.new(0.2, 1, 1),
		CFrame = flat * CFrame.new(0.05, 0, 0),
	})
	TweenService:Create(core, TweenInfo.new(warn, Enum.EasingStyle.Linear), {
		Size = Vector3.new(0.2, radius * 2, radius * 2),
	}):Play()
	Debris:AddItem(zone, warn + 0.05)
	Debris:AddItem(core, warn + 0.05)
	Audio.playAt(if style == "Surge" then "WarnLightning" else "WarnWind", position, 0.6)
	task.delay(warn, function()
		Audio.playAt(
			"Gust",
			position,
			if style == "Surge" then 0.8 else 1,
			if style == "Surge" then 1.4 else 0.7
		)
		if UI.reduced() then
			return
		end
		if style == "Surge" then
			-- An electric pulse: a bright ring that expands and fades.
			local ring = part(fxFolder :: any, "Pulse", {
				Shape = Enum.PartType.Cylinder,
				Material = Enum.Material.Neon,
				Color = SURGE,
				Transparency = 0.1,
				Size = Vector3.new(0.3, radius, radius),
				CFrame = flat,
			})
			TweenService:Create(ring, TweenInfo.new(0.35), {
				Size = Vector3.new(0.3, radius * 2.4, radius * 2.4),
				Transparency = 1,
			}):Play()
			Debris:AddItem(ring, 0.4)
		else
			-- Debris: a few chunks slam down and a dust puff kicks up.
			for k = 1, 5 do
				local a = k / 5 * math.pi * 2
				local at = position + Vector3.new(math.cos(a) * radius * 0.5, 0.6, math.sin(a) * radius * 0.5)
				local chunk = part(fxFolder :: any, "Chunk", {
					Material = Enum.Material.WoodPlanks,
					Color = Color3.fromRGB(110, 84, 60),
					Size = Vector3.new(0.8, 0.4, 2.2),
					CFrame = CFrame.new(at + Vector3.new(0, 14, 0)) * CFrame.Angles(a, a, 0),
				})
				TweenService
					:Create(chunk, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						CFrame = CFrame.new(at) * CFrame.Angles(a, a, 0.4),
					})
					:Play()
				Debris:AddItem(chunk, 1.6)
			end
			local puff = part(fxFolder :: any, "Puff", { Transparency = 1, Size = Vector3.new(1, 1, 1) })
			puff.Position = position + Vector3.new(0, 1, 0)
			local e = Instance.new("ParticleEmitter")
			e.Texture = "rbxasset://textures/particles/smoke_main.dds"
			e.Color = ColorSequence.new(Color3.fromRGB(140, 120, 96))
			e.Size = NumberSequence.new(3, 8)
			e.Transparency = NumberSequence.new(0.3, 1)
			e.Lifetime = NumberRange.new(0.6, 1)
			e.Speed = NumberRange.new(12, 20)
			e.SpreadAngle = Vector2.new(180, 30)
			e.Rate = 0
			e.Parent = puff
			e:Emit(18)
			Debris:AddItem(puff, 1.5)
		end
	end)
end

---------------------------------------------------------------------------- Banner

local function kindTitle(kind: string?, golden: boolean?): string
	if golden then
		return "GOLDEN CACHE"
	elseif kind == "Extraction" then
		return "UNSTABLE CORE"
	elseif kind == "Rush" then
		return "SALVAGE RUSH"
	end
	return "RARE CACHE"
end

local function step(dt: number)
	stepFunnel(dt)
	if not state or state.Phase == "Done" then
		banner.Visible = false
		return
	end
	-- A modal (shop, Jobs, a player card) sits where the banner does: hide it meanwhile.
	banner.Visible = not UI.modalOpen()
	local left = (state.EndsAt or 0) - workspace:GetServerTimeNow()
	local me = Players.LocalPlayer
	local root = me.Character and me.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local carrier = state.Phase == "Chase" and state.CarrierId == me.UserId
	local site = string.upper(state.Site or state.District or "")
	sub.TextColor3 = UI.Color.Text
	if state.Phase == "Rush" then
		title.Text = ("SALVAGE RUSH · %s · %s"):format(site, clock(left))
		title.TextColor3 = GOLD
		sub.Text = ("%d valuable finds left. Grab what you can!"):format(state.Left or 0)
	elseif state.Phase == "Race" then
		title.Text = ("%s · %s · %s"):format(kindTitle(state.Kind, state.Golden), site, clock(left))
		title.TextColor3 = GOLD
		sub.Text = if state.Kind == "Extraction"
			then "Grab it and get it home before it blows"
			else "Grab it first. A twister will chase you home"
	elseif state.Phase == "Loose" then
		title.Text = ("CORE DROPPED! · %s"):format(clock(left))
		title.TextColor3 = GOLD
		sub.Text = "Grab it before time runs out"
	elseif carrier then
		title.Text = ("GET IT TO THE SCRAPYARD · %s"):format(clock(left))
		title.TextColor3 = DANGER
		if state.Kind == "Extraction" then
			sub.Text = "Surges erupt on the straight road. Pick your route!"
		else
			local server = workspace:FindFirstChild("PursuitTwister") :: BasePart?
			if server and root then
				local d = ((root.Position - server.Position) * Vector3.new(1, 0, 1)).Magnitude
				local searching = server:GetAttribute("State") == "Searching"
				sub.Text = if searching
					then "TWISTER LOST YOUR TRAIL · keep going"
					elseif d < 12 then ("TWISTER %dm · DODGE! (Q / B)"):format(math.floor(d + 0.5))
					else ("TWISTER %dm BEHIND · %s"):format(
						math.floor(d + 0.5),
						if d < 25 then "SPRINT!" else "keep moving"
					)
				if d < 25 and not searching then
					sub.TextColor3 = DANGER
				end
			else
				sub.Text = "Reach the plateau!"
			end
		end
	else
		title.Text = ("%s HAS THE CORE · %s"):format(
			string.upper(state.CarrierName or "SOMEONE"),
			clock(left)
		)
		title.TextColor3 = GOLD
		sub.Text = if state.Kind == "Extraction"
			then "If they fall, it drops"
			else "If the twister catches them, it drops"
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
	local key = tostring(msg.Id) .. ":" .. tostring(msg.Phase)
	local fresh = key ~= lastKey
	lastKey = key
	state = msg
	local me = Players.LocalPlayer
	local site = msg.Site or msg.District or "town"
	if msg.Phase == "Race" or (msg.Phase == "Rush" and fresh and (msg.Left or 0) == #Config.Rush.Items) then
		if fresh then
			Audio.play("Siren", 1)
			local line = if msg.Kind == "Rush"
				then ("SALVAGE RUSH at %s! Valuable finds for %ds."):format(site, Config.Rush.Seconds)
				elseif
					msg.Kind == "Extraction"
				then ("UNSTABLE CORE at %s! Get it home before it blows."):format(site)
				elseif
					msg.Golden
				then ("GOLDEN CACHE at %s! A Golden Storm Core (600). First to grab it gets chased home."):format(
					site
				)
				else ("RARE CACHE at %s! First to grab it gets chased home."):format(site)
			Notifications.feed(line, GOLD, 5)
		end
		if msg.Target then
			mark(
				msg.Target,
				kindTitle(msg.Kind, msg.Golden),
				true,
				if msg.Kind == "Extraction" then SURGE else GOLD
			)
		end
	elseif msg.Phase == "Loose" then
		Audio.play("WarnWind", 0.8)
		if msg.Target then
			mark(msg.Target, "DROPPED CORE", true, GOLD)
		end
	elseif msg.Phase == "Chase" then
		if msg.CarrierId == me.UserId then
			Audio.play("FindCore", 1)
			mark(EXTRACT_AT, "EXTRACT", false, Color3.fromRGB(140, 230, 150))
		else
			clearMarkers()
		end
	elseif msg.Phase == "Done" then
		clearMarkers()
		if msg.Result == "Extracted" then
			Audio.play("CoreDelivered", 1)
			if msg.CarrierId == me.UserId then
				SalvageFeedback.extracted(msg)
			else
				Notifications.feed(
					("%s extracted %s in %.1fs!"):format(
						msg.CarrierName or "Someone",
						if msg.Golden then "a GOLDEN core" else "it",
						msg.Seconds or 0
					),
					GOLD,
					5
				)
			end
		elseif msg.Result == "RushOver" then
			Notifications.feed(
				("Rush over. Top salvager: %s with %d."):format(msg.TopName or "?", msg.TopCount or 0),
				GOLD,
				4
			)
		elseif msg.Result == "Expired" then
			Notifications.feed("The core destabilised. Out of time.", DANGER, 4)
		elseif msg.Result == "Unclaimed" then
			Notifications.feed("Nobody claimed it this time.", UI.Color.TextDim, 3)
		end
	end
end

function PursuitHud.init(topStack: Frame)
	markerFolder = Instance.new("Folder")
	markerFolder.Name = "PursuitMarkers"
	markerFolder.Parent = workspace
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "PursuitFx"
	fxFolder.Parent = workspace
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
	Remotes.get("PursuitStrike").OnClientEvent:Connect(onStrike)
	RunService.RenderStepped:Connect(step)
end

return PursuitHud
