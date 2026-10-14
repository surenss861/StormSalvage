-- @file The Armored Wreck, drawn: a beacon over the truck, lock markers, the cutting banner
-- @domain world
-- @status wip
-- @see [[WreckService.luau]]
-- The server owns the wreck (WreckState: where, each lock's progress, when it ends). This draws:
--   * an amber beacon over the truck, so it's findable from across town;
--   * a marker on each uncut lock (the progress bars themselves are server billboards);
--   * an objective-strip entry, only for Heavy licence holders (band 4+): locks cut as a bar,
--     time left, cutting or paused. Everyone else gets the one announcement.
-- Sparks fly from a lock while the local player is cutting it (fewer in Reduced Effects).

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
local sparks: ParticleEmitter? = nil
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
	if sparks then
		(sparks.Parent :: Instance):Destroy()
		sparks = nil
	end
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

local function setSparks(at: Vector3?)
	if not at then
		if sparks then
			(sparks.Parent :: Instance):Destroy()
			sparks = nil
		end
		return
	end
	if not sparks then
		local holder = Instance.new("Part")
		holder.Name = "CutSparks"
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.new(0.5, 0.5, 0.5)
		holder.Parent = folder
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(Color3.fromRGB(255, 230, 150), Color3.fromRGB(255, 120, 40))
		e.LightEmission = 1
		e.Size = NumberSequence.new(0.18, 0)
		e.Speed = NumberRange.new(8, 14)
		e.SpreadAngle = Vector2.new(60, 60)
		e.Lifetime = NumberRange.new(0.25, 0.5)
		e.Acceleration = Vector3.new(0, -30, 0)
		e.Parent = holder
		sparks = e
		Audio.play("Gust", 0.25, 2.2)
	end
	local e = sparks :: ParticleEmitter
	e.Rate = if UI.reduced() then 12 else 60;
	(e.Parent :: BasePart).Position = at
end

local function step()
	if not state then
		return
	end
	if beacon and not UI.reduced() then
		beacon.Transparency = 0.45 + 0.15 * math.sin(os.clock() * 4)
	end
	local cutting = Players.LocalPlayer:GetAttribute("WreckCutting")
	local cutAt = lockPosition(cutting)
	local me = Players.LocalPlayer.Character
		and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	setSparks(
		if cutAt and me and (me.Position - cutAt).Magnitude <= Bands.Wreck.CutReach + 1 then cutAt else nil
	)
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
		e.Sub = if inReach
			then "Cutting… dodge the security charges, then get back to the lock!"
			else "Cut paused: get back to the lock to keep cutting."
	else
		e.Sub = ("At %s. Cut the locks: rear doors, side hatch (climb up), roof hatch."):format(state.Site)
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
