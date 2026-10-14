-- @file The Armored Wreck, drawn: a beacon over the truck, lock markers, the cutting banner
-- @domain world
-- @status wip
-- @see [[WreckService.luau]]
-- The server owns the wreck (WreckState: where, each lock's progress, when it ends). This draws:
--   * an amber beacon over the truck, so it's findable from across town;
--   * a marker on each uncut lock (the progress bars themselves are server billboards);
--   * an objective-strip entry, only for Heavy licence holders (band 4+): locks cut as a bar,
--     time left, cutting or paused. Everyone else gets the one announcement.
-- Sparks fly from every lock being cut, for everyone (fewer in Reduced Effects).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Bands = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Bands"))
local Remotes = require(ReplicatedStorage.Shared:WaitForChild("Remotes"))
local Audio = require(script.Parent:WaitForChild("Audio"))
local UI = require(script.Parent:WaitForChild("UI"))
local WorldMotion = require(script.Parent:WaitForChild("WorldMotion"))
local EventStrip = require(script.Parent:WaitForChild("EventStrip"))

local WreckHud = {}

local AMBER = Color3.fromRGB(255, 190, 80)
local GREEN = Color3.fromRGB(110, 230, 130)

local folder: Folder
local beacon: BasePart? = nil
local markers: { BasePart } = {}
local state: any = nil

local function clearWorld()
	if beacon then
		beacon:Destroy()
		beacon = nil
	end
	for _, m in markers do
		m:Destroy()
	end
	markers = {}
end

local function isHeavy(): boolean
	local band = Players.LocalPlayer:GetAttribute("Band")
	return type(band) == "number" and band >= 4
end

local function marker(at: Vector3, cut: boolean): BasePart
	local p = Instance.new("Part")
	p.Name = "LockMarker"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.ForceField
	p.Color = if cut then GREEN else AMBER
	p.Transparency = if cut then 0.8 else 0.4
	p.Size = Vector3.new(3, 3, 3)
	p.Position = at
	p.Parent = folder
	return p
end

local function onState(m: any)
	if type(m) ~= "table" or not m.Active then
		state = nil
		clearWorld()
		EventStrip.clear("wreck")
		return
	end
	local fresh = not state or state.Id ~= m.Id
	state = m
	if fresh then
		clearWorld()
		local b = Instance.new("Part")
		b.Name = "WreckBeacon"
		b.Anchored = true
		b.CanCollide = false
		b.CanQuery = false
		b.CanTouch = false
		b.CastShadow = false
		b.Material = Enum.Material.Neon
		b.Color = AMBER
		b.Transparency = 0.5
		b.Size = Vector3.new(1.2, 120, 1.2)
		b.Position = m.Position + Vector3.new(0, 66, 0)
		b.Parent = folder

		WorldMotion.beacon(b)
		beacon = b
		Audio.play("WarnWind", 0.5, 1.3)
	end
	for _, mk in markers do
		mk:Destroy()
	end
	markers = {}
	for _, lock in m.Locks do
		if not m.Opened then
			table.insert(markers, marker(lock.Position, lock.Cut))
		end
	end
	if m.Opened and beacon then
		beacon.Color = GREEN
	end
end

local function lockPosition(name: string?): Vector3?
	if not state or not name then
		return nil
	end
	local i = tonumber(string.sub(name, -1))
	local lock = i and state.Locks[i]
	return lock and lock.Position
end

-- Sparks on every lock someone is cutting (the server marks them "Sparking"), so a crew's work
-- is visible to everyone. The emitters are client-side children of the server's lock parts.
local function sparkLocks()
	local wreck = workspace:FindFirstChild("ArmoredWreck")
	if not wreck then
		return
	end
	for i = 1, Bands.Wreck.Locks do
		local lock = wreck:FindFirstChild("Lock" .. i)
		if lock and lock:IsA("BasePart") then
			local e = lock:FindFirstChild("CutSparks") :: ParticleEmitter?
			if not e then
				local n = Instance.new("ParticleEmitter")
				n.Name = "CutSparks"
				n.Color = ColorSequence.new(Color3.fromRGB(255, 230, 150), Color3.fromRGB(255, 120, 40))
				n.LightEmission = 1
				n.Size = NumberSequence.new(0.18, 0)
				n.Speed = NumberRange.new(8, 14)
				n.SpreadAngle = Vector2.new(60, 60)
				n.Lifetime = NumberRange.new(0.25, 0.5)
				n.Acceleration = Vector3.new(0, -30, 0)
				n.Parent = lock
				e = n
			end
			local on = lock:GetAttribute("Sparking") == true
			local em = e :: ParticleEmitter
			if on and not em.Enabled then
				Audio.playAt("Gust", lock.Position, 0.25, 2.2)
			end
			em.Enabled = on
			em.Rate = if UI.reduced() then 12 else 60
		end
	end
end

local function step()
	if not state then
		return
	end
	local cutting = Players.LocalPlayer:GetAttribute("WreckCutting")
	sparkLocks()
	if not isHeavy() then
		EventStrip.clear("wreck")
		return
	end
	local cut, total = 0, #state.Locks
	local progress = 0
	for _, lock in state.Locks do
		if lock.Cut then
			cut += 1
		end
		progress += (lock.Progress or 0) / total
	end
	local e = {
		Priority = if cutting then 80 else 60,
		Title = if state.Opened
			then "Armored Wreck · vault open"
			else ("Armored Wreck · %d/%d locks"):format(cut, total),
		Sub = "",
		Accent = AMBER,
		EndsAt = state.EndsAt,
		Progress = if state.Opened then nil else progress,
		Pill = ("WRECK %d/%d"):format(cut, total),
	}
	if state.Opened then
		e.Sub = "Grab the bullion before it's hauled away!"
		e.Priority = 74
	elseif cutting then
		local at = lockPosition(cutting)
		local root = Players.LocalPlayer.Character
			and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local inReach = at ~= nil
			and root ~= nil
			and (root.Position - at).Magnitude <= Bands.Wreck.CutReach + 1
		local crew = if (state.Crew or 0) > 1
			then (" · Crew of %d, +%d%% speed"):format(
				state.Crew,
				math.floor(((state.Bonus or 1) - 1) * 100 + 0.5)
			)
			else ""
		e.Sub = if inReach
			then "Cutting… dodge the security charges!" .. crew
			else "Cut paused: get back to the lock to keep cutting."
	else
		e.Sub = if (state.Crew or 0) > 0
			then ("%d cutting at %s. Take another lock: more locks at once, faster for all."):format(
				state.Crew,
				state.Site
			)
			else ("At %s. Cut the locks: rear doors, side hatch (climb up), roof hatch."):format(
				state.Site
			)
	end
	EventStrip.set("wreck", e)
end

function WreckHud.init(_topStack: Frame)
	folder = Instance.new("Folder")
	folder.Name = "WreckFx"
	folder.Parent = workspace
	Remotes.get("WreckState").OnClientEvent:Connect(onState)
	RunService.RenderStepped:Connect(step)
end

return WreckHud
