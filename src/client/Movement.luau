-- @file V4 movement: run and sprint
-- @domain world
-- @status wip
-- @see [[V4-GAMEPLAY]]
-- V4 movement prototype. The character runs at RunSpeed (Boots, base 20) and sprints at
-- SprintSpeed (base 28); both are set by the server as character attributes from the Boots level.
--   Keyboard: hold Shift to sprint.
--   Touch and gamepad: sprint starts by itself after a moment of steady movement (no extra
--   button to hold on a phone); gamepad can also click the left stick.
-- The speed eases up over a short ramp instead of snapping, and drops back to running when you
-- stop. While sprinting the camera widens slightly (off in Reduced Effects). Roblox's own
-- character controller, camera and animations stay in charge; this only sets WalkSpeed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UI = require(script.Parent:WaitForChild("UI"))

local Movement = {}

local M = Config.Movement
local BASE_FOV = 70
local shiftHeld = false
local stickSprint = false
local movingSince: number? = nil
local sprinting = false

function Movement.isSprinting(): boolean
	return sprinting
end

local function step(dt: number)
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local camera = workspace.CurrentCamera
	if not humanoid or humanoid.Health <= 0 then
		sprinting = false
		return
	end
	local run = tonumber(character:GetAttribute("RunSpeed"))
	local sprint = tonumber(character:GetAttribute("SprintSpeed"))
	if not run or not sprint then
		return -- the server hasn't set the speeds yet (or an older server): leave WalkSpeed alone
	end
	-- Studio QA only: a scripted runner can't hold Shift, so QA_Sprint forces it. Scripted
	-- MoveTo leaves MoveDirection at zero, so QA also counts actual ground speed as moving.
	local qa = RunService:IsStudio() and ReplicatedStorage:GetAttribute("QA_Sprint") == true
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local ground = if root then (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude else 0
	local moving = humanoid.MoveDirection.Magnitude > 0.5 or (qa and ground > 2)
	local now = os.clock()
	if moving then
		movingSince = movingSince or now
	else
		movingSince = nil
		stickSprint = false
	end
	local touchy = UserInputService.TouchEnabled or UserInputService.GamepadEnabled
	local auto = touchy and movingSince ~= nil and now - (movingSince :: number) >= M.AutoSprintAfter
	sprinting = moving and (shiftHeld or stickSprint or auto or qa)
	local target = if sprinting then sprint else run
	local current = humanoid.WalkSpeed
	if not moving then
		humanoid.WalkSpeed = run
	elseif current < target then
		local rate = (sprint - run) / M.SprintRampSeconds
		humanoid.WalkSpeed = math.min(target, current + rate * dt)
	elseif current > target then
		humanoid.WalkSpeed = target
	end
	if camera then
		local fov = if sprinting and not UI.reduced() then M.SprintFov else BASE_FOV
		local alpha = math.clamp(dt * 8, 0, 1)
		camera.FieldOfView += (fov - camera.FieldOfView) * alpha
	end
end

function Movement.init()
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			shiftHeld = true
		elseif input.KeyCode == Enum.KeyCode.ButtonL3 then
			stickSprint = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			shiftHeld = false
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return Movement
