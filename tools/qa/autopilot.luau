-- QA autopilot (client side, not part of the game). Plays the core loop the way an efficient
-- but storm-naive new player might: walk to the nearest salvage, grab it, go sell when the
-- bag is full, and buy the cheapest affordable upgrade. It ignores storms on purpose.
-- Walking uses PathfindingService at the character's real WalkSpeed; prompts are pressed with
-- InputHoldBegin/End, so the server's distance checks and hold times all apply.
--
-- Put into PlayerScripts during a Play session. Progress is reported on
-- ReplicatedStorage attribute QA_Autopilot; the server's SessionStats has the real numbers.

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
-- Player state only arrives when it changes, so start from a fresh profile's values.
local state: any = { Carried = {}, Capacity = 3, Coins = 0, Upgrades = {} }
remotes.PlayerState.OnClientEvent:Connect(function(s)
	state = s
end)

local skip: { [Instance]: boolean } = {}
local status = "starting"
local function report(text: string)
	status = text
	ReplicatedStorage:SetAttribute("QA_Autopilot", text)
end

local function character()
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if hum and root and hum.Health > 0 then
		return hum, root :: BasePart
	end
	return nil, nil
end

-- Walks a computed path to `goal`. Returns true when within `near` studs.
local function walkTo(goal: Vector3, near: number): boolean
	local hum, root = character()
	if not hum or not root then
		return false
	end
	local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
	local ok = pcall(function()
		path:ComputeAsync(root.Position, goal)
	end)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		return false
	end
	for _, wp in path:GetWaypoints() do
		hum, root = character()
		if not hum or not root then
			return false
		end
		if wp.Action == Enum.PathWaypointAction.Jump then
			hum.Jump = true
		end
		hum:MoveTo(wp.Position)
		local t0 = os.clock()
		while (root.Position * Vector3.new(1, 0, 1) - wp.Position * Vector3.new(1, 0, 1)).Magnitude > 3 do
			if os.clock() - t0 > 4 or hum.Health <= 0 then
				return false
			end
			task.wait(0.05)
		end
		if (root.Position - goal).Magnitude <= near then
			return true
		end
	end
	local _, r = character()
	return r ~= nil and (r.Position - goal).Magnitude <= near + 2
end

local function press(prompt: ProximityPrompt)
	prompt:InputHoldBegin()
	task.wait(prompt.HoldDuration + 0.1)
	prompt:InputHoldEnd()
	task.wait(0.3)
end

-- A walkable spot on the ground near `position` (prompts often sit on counters or in the air).
local function groundNear(position: Vector3, offset: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { player.Character, workspace.Loot }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local from = position + offset + Vector3.new(0, 2, 0) -- below any roof over the counter
	local hit = workspace:Raycast(from, Vector3.new(0, -60, 0), params)
	return if hit then hit.Position + Vector3.new(0, 3, 0) else position + offset
end

local function sellPrompt(): ProximityPrompt?
	for _, d in workspace:GetDescendants() do
		if d:IsA("ProximityPrompt") and d.Name == "SellPrompt" then
			return d
		end
	end
	return nil
end

local function nearestLoot(root: BasePart): BasePart?
	local best, bestD = nil, math.huge
	for _, item in workspace.Loot:GetChildren() do
		local prompt = item:FindFirstChildOfClass("ProximityPrompt")
		if item:IsA("BasePart") and prompt and not skip[item] and not prompt.ObjectText:find("'s ") then
			local d = (item.Position - root.Position).Magnitude
			if d < bestD then
				best, bestD = item, d
			end
		end
	end
	return best
end

local function buyUpgrades()
	if not state then
		return
	end
	local cheapest, cost = nil, math.huge
	for _, id in Config.UpgradeOrder do
		local level = state.Upgrades[id] or 0
		local c = Config.Upgrades[id].Costs[level + 1]
		if c and c < cost then
			cheapest, cost = id, c
		end
	end
	if cheapest and state.Coins >= cost then
		remotes.BuyUpgrade:FireServer(cheapest)
		task.wait(0.5)
	end
end

while true do
	-- In Studio Play sessions driven over MCP, the camera was found switched to Scriptable
	-- (not by game code), which hides proximity prompts; keep the default camera.
	local cam = workspace.CurrentCamera
	if cam.CameraType ~= Enum.CameraType.Custom then
		cam.CameraType = Enum.CameraType.Custom
	end
	local hum, root = character()
	if not hum or not root or not state then
		report("waiting for character")
		task.wait(1)
		continue
	end
	buyUpgrades()
	if #state.Carried >= state.Capacity then
		report(("selling %d/%d"):format(#state.Carried, state.Capacity))
		local prompt = sellPrompt()
		local counter = prompt and prompt.Parent :: BasePart?
		if prompt and counter then
			-- Try each side of the counter; some sides are inside the shack.
			for _, side in
				{ Vector3.new(6, 0, 0), Vector3.new(0, 0, 6), Vector3.new(-6, 0, 0), Vector3.new(0, 0, -6) }
			do
				if walkTo(groundNear(counter.Position, side), 4) then
					break
				end
			end
			local _, r = character()
			if r and (r.Position - counter.Position).Magnitude <= prompt.MaxActivationDistance then
				press(prompt)
			end
		end
		task.wait(0.2)
		continue
	end
	local item = nearestLoot(root)
	if not item then
		report("no loot found")
		task.wait(1)
		continue
	end
	report(("going for %s"):format(item.Name))
	local prompt = item:FindFirstChildOfClass("ProximityPrompt")
	if prompt and walkTo(item.Position, prompt.MaxActivationDistance - 2) and item.Parent then
		press(prompt)
	end
	if item.Parent then
		skip[item] = true -- unreachable or taken; don't keep trying it
	end
	task.wait(0.1)
end
