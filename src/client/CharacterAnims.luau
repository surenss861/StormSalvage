-- @file V4 character animations: dodge, core carry, extraction celebration
-- @domain world
-- @status wip
-- @see [[Dodge.luau]]
-- @see [[ANIMATIONS]]
-- Plays the three V4 animations on the local character (animations played on your own
-- character replicate to everyone). Sources, in order:
--   1. Config.Animations[name]: the uploaded asset id. Empty until the owner uploads them; no
--      id is ever made up (docs/art/v4/ANIMATIONS.md has the upload steps).
--   2. Studio only: the authored KeyframeSequence (ReplicatedStorage.StudioAnimations), through a
--      temporary preview id, so the animations can be checked before they're uploaded.
--   3. Otherwise nothing plays, and each moment keeps its fallback: the dodge has its dust and
--      whoosh, the carrier glows, and the extraction has its receipt card and burst.

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local CharacterAnims = {}

local ids: { [string]: string | false } = {} -- resolved content id per name (false = none)
local tracks: { [string]: AnimationTrack } = {}
local trackOwner: Humanoid? = nil
local carrying = false

-- The content id for `name`, or nil if there is no animation to play.
function CharacterAnims.source(name: string): (string?, string)
	local cached = ids[name]
	if cached ~= nil then
		return if cached then cached else nil, if cached then "cached" else "fallback"
	end
	local uploaded = (Config.Animations :: any)[name]
	if type(uploaded) == "number" and uploaded > 0 then
		ids[name] = "rbxassetid://" .. uploaded
		return ids[name] :: string, "uploaded"
	end
	if RunService:IsStudio() then
		local folder = ReplicatedStorage:FindFirstChild("StudioAnimations")
		local kfs = folder and folder:FindFirstChild(name)
		if kfs and kfs:IsA("KeyframeSequence") then
			local ok, id = pcall(function()
				return KeyframeSequenceProvider:RegisterKeyframeSequence(kfs)
			end)
			if ok then
				ids[name] = id
				return id, "studio-preview"
			end
		end
	end
	ids[name] = false
	return nil, "fallback"
end

local function track(name: string): AnimationTrack?
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not humanoid or not animator or humanoid.Health <= 0 then
		return nil
	end
	if trackOwner ~= humanoid then
		tracks = {}
		trackOwner = humanoid
	end
	if tracks[name] then
		return tracks[name]
	end
	local id = CharacterAnims.source(name)
	if not id then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, t = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok then
		return nil
	end
	tracks[name] = t
	return t
end

-- One-shot animations. Returns whether an animation played (false = the fallback stands alone).
function CharacterAnims.play(name: string, fade: number?): boolean
	local t = track(name)
	if not t then
		return false
	end
	t:Play(fade or 0.05)
	return true
end

-- The core-carry loop, on while the local player carries any Storm Core.
function CharacterAnims.setCarrying(on: boolean)
	carrying = on
	local t = track("CoreCarry")
	if not t then
		return
	end
	if on and not t.IsPlaying then
		t:Play(0.2)
	elseif not on and t.IsPlaying then
		t:Stop(0.2)
	end
end

function CharacterAnims.init()
	-- A respawn gets fresh tracks; keep the carry loop in step with the bag (emptied on death).
	Players.LocalPlayer.CharacterAdded:Connect(function()
		tracks = {}
		trackOwner = nil
		if carrying then
			task.defer(CharacterAnims.setCarrying, carrying)
		end
	end)
end

return CharacterAnims
