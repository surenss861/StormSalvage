-- @file V4 evasive action: the dodge
-- @domain world
-- @status wip
-- @see [[Movement.luau]]
-- @see [[V4-GAMEPLAY]]
-- One evasive move, chosen over a slide: a dodge reads clearly with effects alone (a slide needs a
-- crouch animation to read, and animations need uploaded assets), and it works the same in wind,
-- floods and on every surface.
--   Q (keyboard), B (gamepad) or the DODGE button (touch): a short burst in the direction you're
--   moving (or facing, if still), about 13 studs: enough to clear a debris circle or the twister's
--   catch ring when timed well. Ground only (not climbing, swimming, seated or mid-air), with a
--   cooldown, so it's a decision, not extra speed.
-- It changes nothing on the server: no reward, no immunity. Movement is client-owned on Roblox
-- anyway; the dodge stays inside what an ordinary sprinting character can reach in a second.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Audio = require(script.Parent:WaitForChild("Audio"))
local UI = require(script.Parent:WaitForChild("UI"))

local Dodge = {}

local D = Config.Dodge
local readyAt = 0
local burstUntil = 0
local direction = Vector3.zero

local GROUND_STATES = {
	[Enum.HumanoidStateType.Running] = true,
	[Enum.HumanoidStateType.RunningNoPhysics] = true,
	[Enum.HumanoidStateType.Landed] = true,
}

function Dodge.ready(): boolean
	return os.clock() >= readyAt
end

function Dodge.cooldownLeft(): number
	return math.max(0, readyAt - os.clock())
end

local function dust(at: Vector3)
	if UI.reduced() then
		return
	end
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.Position = at
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(150, 136, 116))
	e.Size = NumberSequence.new(1.5, 4)
	e.Transparency = NumberSequence.new(0.4, 1)
	e.Lifetime = NumberRange.new(0.35, 0.6)
	e.Speed = NumberRange.new(6, 12)
	e.SpreadAngle = Vector2.new(70, 20)
	e.Rate = 0
	e.Parent = p
	p.Parent = workspace
	e:Emit(10)
	task.delay(1, function()
		p:Destroy()
	end)
end

-- Attempts a dodge now. Returns whether it happened.
function Dodge.trigger(): boolean
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or humanoid.Health <= 0 or os.clock() < readyAt then
		return false
	end
	if not GROUND_STATES[humanoid:GetState()] then
		return false
	end
	local move = humanoid.MoveDirection * Vector3.new(1, 0, 1)
	if move.Magnitude < 0.1 then
		move = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	end
	if move.Magnitude < 0.1 then
		return false
	end
	direction = move.Unit
	readyAt = os.clock() + D.Cooldown
	burstUntil = os.clock() + D.Seconds
	dust(root.Position - Vector3.new(0, 2.5, 0))
	Audio.play("WarnWind", 0.35, 1.6)
	return true
end

local function step()
	if os.clock() >= burstUntil then
		return
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		burstUntil = 0
		return
	end
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(direction.X * D.Speed, v.Y, direction.Z * D.Speed)
end

function Dodge.init()
	ContextActionService:BindAction("StormSalvageDodge", function(_, state)
		if state == Enum.UserInputState.Begin then
			Dodge.trigger()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
	ContextActionService:SetTitle("StormSalvageDodge", "DODGE")
	-- Touch: above-left of the jump button, inside the right thumb's reach.
	ContextActionService:SetPosition("StormSalvageDodge", UDim2.new(1, -170, 1, -150))
	RunService.Heartbeat:Connect(step)
	if RunService:IsStudio() then
		-- QA only: a scripted run can't press Q, so ReplicatedStorage.QA_Dodge:Fire() triggers it.
		local qa = Instance.new("BindableEvent")
		qa.Name = "QA_Dodge"
		qa.Event:Connect(Dodge.trigger)
		qa.Parent = ReplicatedStorage
	end
end

return Dodge
