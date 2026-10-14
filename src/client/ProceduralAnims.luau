-- @file Functional animation fallbacks: posed joints while the real animations await upload
-- @domain world
-- @status wip
-- @see [[CharacterAnims.luau]]
-- @see [[ANIMATIONS]]
-- The three V4 animations (Dodge, CoreCarry, Celebrate) need the owner's upload (no asset id is
-- ever invented). Until then, this poses characters directly so each moment still reads:
--   carry      arms up and forward around the core, a slight lean back (anyone whose root has
--              the server's CoreGlow: everyone sees every carrier)
--   dodge      a quick forward lunge (yours, and others' through DodgeFx)
--   celebrate  arms thrown up for a moment (your extraction)
-- It offsets each joint's C0 from its original and eases in and out, so it layers with the
-- default walk and stops entirely for a pose whose real animation exists (uploaded, or the
-- Studio preview for your own character). R15 and R6 rigs. Reduced Effects keeps the poses
-- (they're information) but drops the bob.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UI = require(script.Parent:WaitForChild("UI"))

local ProceduralAnims = {}

type Rig = { Joints: { [string]: Motor6D }, Base: { [string]: CFrame } }
local rigs: { [Model]: Rig } = {}
local pulses: { [Model]: { [string]: number } } = {} -- name -> os.clock() it started
local weights: { [Model]: { [string]: number } } = {}
local hasReal: (name: string, player: Player) -> boolean = function(_name: string, _player: Player): boolean
	return false
end

local DURATION = { Dodge = 0.4, Celebrate = 1.4 }

-- Joint names for both rigs: R15 first.
local JOINTS = {
	RightShoulder = { "RightUpperArm.RightShoulder", "Torso.Right Shoulder" },
	LeftShoulder = { "LeftUpperArm.LeftShoulder", "Torso.Left Shoulder" },
	Waist = { "UpperTorso.Waist", "HumanoidRootPart.RootJoint" },
}

local function rigOf(character: Model): Rig?
	local rig = rigs[character]
	if rig then
		return rig
	end
	local joints, base = {}, {}
	for key, paths in JOINTS do
		for _, path in paths do
			local partName, jointName = string.match(path, "^(.-)%.(.+)$")
			local part = character:FindFirstChild(partName :: string)
			local joint = part and part:FindFirstChild(jointName :: string)
			if joint and joint:IsA("Motor6D") then
				joints[key] = joint
				base[key] = joint.C0
				break
			end
		end
	end
	if not joints.RightShoulder or not joints.LeftShoulder then
		return nil
	end
	rig = { Joints = joints, Base = base }
	rigs[character] = rig
	character.Destroying:Connect(function()
		rigs[character] = nil
		pulses[character] = nil
		weights[character] = nil
	end)
	return rig
end

-- `isReal(name, player)` says whether a real animation plays for that player (then no pose).
function ProceduralAnims.setRealCheck(isReal: (string, Player) -> boolean)
	hasReal = isReal
end

-- A one-shot pose ("Dodge" or "Celebrate") on `player`'s character.
function ProceduralAnims.pulse(player: Player, name: string)
	local character = player.Character
	if not character or hasReal(name, player) then
		return
	end
	pulses[character] = pulses[character] or {}
	pulses[character][name] = os.clock()
end

local function ease(x: number): number
	return x * x * (3 - 2 * x)
end

local function step(dt: number)
	local now = os.clock()
	local reduced = UI.reduced()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local rig = character and rigOf(character)
		if not character or not root or not rig then
			continue
		end
		local w = weights[character] or { Carry = 0, Dodge = 0, Celebrate = 0 }
		weights[character] = w
		local carrying = root:FindFirstChild("CoreGlow") ~= nil and not hasReal("CoreCarry", player)
		w.Carry += ((if carrying then 1 else 0) - w.Carry) * math.min(1, dt * 8)
		local p = pulses[character] or {}
		for name, len in DURATION do
			local started = p[name]
			local t = if started then (now - started) / len else 1
			-- Up fast, hold, down: a pulse shape over the pose's length.
			w[name] = if t < 1
				then (if t < 0.2 then ease(t / 0.2) elseif t > 0.7 then ease((1 - t) / 0.3) else 1)
				else 0
		end
		local bob = if reduced then 0 else math.sin(now * 8) * 0.05
		local j, b = rig.Joints, rig.Base
		-- Shoulders: carry hugs forward (about 75 degrees), celebrate throws up (about 160).
		local rightArm = -1.3 * w.Carry - 2.8 * w.Celebrate
		local leftArm = -1.3 * w.Carry - 2.8 * w.Celebrate
		j.RightShoulder.C0 = b.RightShoulder * CFrame.Angles(rightArm + bob * w.Carry, 0, 0.25 * w.Carry)
		j.LeftShoulder.C0 = b.LeftShoulder * CFrame.Angles(leftArm + bob * w.Carry, 0, -0.25 * w.Carry)
		if j.Waist then
			-- Dodge lunges forward; carrying leans back a little against the weight.
			j.Waist.C0 = b.Waist * CFrame.Angles(-0.5 * w.Dodge + 0.12 * w.Carry, 0, 0)
		end
	end
end

function ProceduralAnims.init()
	RunService.RenderStepped:Connect(step)
	-- Uploaded ids replicate as real animations for everyone; without one, everyone gets the pose.
	ProceduralAnims.setRealCheck(function(name: string, _player: Player): boolean
		local id = (Config.Animations :: any)[name]
		return type(id) == "number" and id > 0
	end)
end

return ProceduralAnims
