-- @file Black-screen diagnostic
-- @domain qa
-- @status stable
-- @see [[V3-SOAK-AND-DEATH-QA]]
-- Watches for the game view losing the player (V3 QA: one unreproduced black screen after a
-- death in Studio, docs/art/V3-UI-WORKSHOP.md). Once a second, while the character has been
-- alive for a few seconds, it checks that the camera follows the character's Humanoid with the
-- normal camera type and stays near it. If that's untrue for 3 checks in a row it reports once
-- per character (ClientDiag -> server analytics and log), with what it saw.
--
-- It observes only: it never moves or resets the camera, so it can't mask the cause.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local ViewHealth = {}

local SETTLE = 3 -- seconds after spawn before checking
local STRIKES = 3 -- consecutive bad checks before reporting
local FAR = 80 -- studs between camera and character that count as "lost"

local function check(character: Model): string?
	local camera = workspace.CurrentCamera
	if not camera then
		return "NoCamera"
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or humanoid.Health <= 0 then
		return nil -- dying or loading: nothing to judge
	end
	if camera.CameraType ~= Enum.CameraType.Custom then
		return "CameraType"
	end
	if camera.CameraSubject ~= humanoid then
		return "Subject"
	end
	local distance = (camera.CFrame.Position - root.Position).Magnitude
	if distance ~= distance or distance > FAR then
		return "Distance"
	end
	return nil
end

function ViewHealth.init()
	local remote = Remotes.get("ClientDiag")
	local player = Players.LocalPlayer
	local function watch(character: Model)
		local spawnedAt = os.clock()
		local strikes = 0
		local reported = false
		task.spawn(function()
			while character.Parent and player.Character == character do
				task.wait(1)
				if os.clock() - spawnedAt >= SETTLE and not reported then
					local problem = check(character)
					strikes = if problem then strikes + 1 else 0
					if problem and strikes >= STRIKES then
						reported = true
						local camera = workspace.CurrentCamera
						local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
						local distance = if camera and root
							then math.floor((camera.CFrame.Position - root.Position).Magnitude)
							else -1
						warn("[ViewHealth] view lost:", problem, "distance", distance)
						remote:FireServer(problem, distance)
					end
				end
			end
		end)
	end
	player.CharacterAdded:Connect(watch)
	if player.Character then
		watch(player.Character)
	end
end

return ViewHealth
