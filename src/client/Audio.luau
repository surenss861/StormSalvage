-- Client audio: every cue in Config.Sounds routed through two SoundGroups (Effects and Weather)
-- whose volumes follow the Settings panel (master x group). Handles repeat throttling, small
-- pools for cues that may overlap, positional one-shots, and crossfaded ambience loops.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Audio = {}

local volumes = { Master = 1, Effects = 1, Weather = 1 }
local groups: { [string]: SoundGroup } = {}
local pools: { [string]: { Sound } } = {}
local nextIndex: { [string]: number } = {}
local lastPlayed: { [string]: number } = {}

local function applyVolumes()
	for name, group in groups do
		group.Volume = volumes.Master * (volumes :: any)[name]
	end
end

function Audio.init()
	for _, name in { "Effects", "Weather" } do
		local group = Instance.new("SoundGroup")
		group.Name = "StormSalvage" .. name
		group.Parent = SoundService
		groups[name] = group
	end
	applyVolumes()
	for name, def in Config.Sounds do
		if def.Id == "" then
			continue
		end
		local pool = {}
		for i = 1, def.Pool or 1 do
			local sound = Instance.new("Sound")
			sound.Name = if i == 1 then name else name .. i
			sound.SoundId = def.Id
			sound.Volume = def.Volume
			sound.PlaybackSpeed = def.Pitch or 1
			sound.Looped = def.Loop == true
			sound.SoundGroup = groups[def.Group] or groups.Effects
			sound.Parent = groups[def.Group] or groups.Effects
			table.insert(pool, sound)
		end
		pools[name] = pool
		nextIndex[name] = 1
	end
end

-- True if `name` may play now (not repeated inside its MinInterval).
local function allowed(name: string): boolean
	local def = Config.Sounds[name]
	local now = os.clock()
	if def and def.MinInterval and now - (lastPlayed[name] or -1e9) < def.MinInterval then
		return false
	end
	lastPlayed[name] = now
	return true
end

-- Plays a one-shot cue. `volumeScale` and `pitch` adjust this play only.
function Audio.play(name: string, volumeScale: number?, pitch: number?): Sound?
	local pool = pools[name]
	if not pool or not allowed(name) then
		return nil
	end
	local def = Config.Sounds[name]
	local i = nextIndex[name]
	nextIndex[name] = i % #pool + 1
	local sound = pool[i]
	sound.Volume = def.Volume * (volumeScale or 1)
	sound.PlaybackSpeed = (def.Pitch or 1) * (pitch or 1)
	sound.TimePosition = 0
	sound:Play()
	return sound
end

-- Plays a cue from a point in the world, so it gets quieter and pans with distance.
function Audio.playAt(name: string, position: Vector3, volumeScale: number?, pitch: number?)
	local pool = pools[name]
	if not pool or not allowed(name) then
		return
	end
	local def = Config.Sounds[name]
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	local sound = pool[1]:Clone()
	sound.Volume = def.Volume * (volumeScale or 1)
	sound.PlaybackSpeed = (def.Pitch or 1) * (pitch or 1)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 40
	sound.RollOffMaxDistance = 700
	sound.Parent = attachment
	sound:Play()
	Debris:AddItem(attachment, math.max(sound.TimeLength, 2) / sound.PlaybackSpeed + 0.5)
end

-- Fades a playing cue out over `seconds`.
function Audio.fadeOut(name: string, seconds: number)
	local pool: { Sound } = pools[name] or {}
	for _, sound in pool do
		if sound.IsPlaying then
			local tween = TweenService:Create(sound, TweenInfo.new(seconds), { Volume = 0 })
			tween:Play()
			tween.Completed:Once(function()
				if sound.Volume == 0 then
					sound:Stop()
				end
			end)
		end
	end
end

-- Crossfades a looping ambience in or out without restarting it every frame.
function Audio.setAmbience(name: string, on: boolean, volumeScale: number?)
	local pool = pools[name]
	if not pool then
		return
	end
	local sound = pool[1]
	local target = if on then Config.Sounds[name].Volume * (volumeScale or 1) else 0
	if sound:GetAttribute("Target") == target then
		return
	end
	sound:SetAttribute("Target", target)
	if on and not sound.IsPlaying then
		sound.Volume = 0
		sound:Play()
	end
	local tween = TweenService:Create(sound, TweenInfo.new(if on then 1 else 2.5), { Volume = target })
	tween:Play()
	if not on then
		tween.Completed:Once(function()
			if sound:GetAttribute("Target") == 0 then
				sound:Stop()
			end
		end)
	end
end

-- Volumes from the Settings panel, 0..1. `kind` is "Master", "Effects" or "Weather".
function Audio.setVolume(kind: string, value: number)
	if (volumes :: any)[kind] ~= nil then
		(volumes :: any)[kind] = math.clamp(value, 0, 1)
		applyVolumes()
	end
end

function Audio.getVolume(kind: string): number
	return (volumes :: any)[kind] or 1
end

-- For QA: every cue, whether its asset loaded, and its length.
function Audio.status(): { { Name: string, Loaded: boolean, Length: number } }
	local out = {}
	for name, pool in pools do
		table.insert(out, { Name = name, Loaded = pool[1].IsLoaded, Length = pool[1].TimeLength })
	end
	table.sort(out, function(a, b)
		return a.Name < b.Name
	end)
	return out
end

return Audio
