-- @file Storm Pursuit QA runner (client side, not part of the game)
-- @domain qa
-- @status wip
-- @see [[PursuitService.luau]]
-- A scripted player for the Storm Pursuit event. Put into StarterPlayerScripts for a Studio Play
-- session (as QA_PursuitRunner). It plays the event the way a determined player would: path to
-- the cache (or the dropped core), press the real prompt, then path to the Scrapyard plateau
-- while the twister chases. Sprinting follows the Studio-only QA_Sprint attribute.
-- Call it with ReplicatedStorage.QA_RunEvent:Invoke(timeout) (a client-only BindableFunction):
-- returns a timeline and a summary line. Engineering evidence only: a bot
-- can't tell us whether the chase is fun.

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local me = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local EXTRACT = Vector3.new(0, 34, -240)

local state: any = nil
local onState: ((any) -> ())? = nil
local strikes = 0
remotes:WaitForChild("PursuitState").OnClientEvent:Connect(function(m)
	state = m
	if onState then
		onState(m)
	end
end)
remotes:WaitForChild("PursuitStrike").OnClientEvent:Connect(function()
	strikes += 1
end)

local function hum(): (Humanoid?, BasePart?)
	local c = me.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	if h and h.Health > 0 then
		return h, c:FindFirstChild("HumanoidRootPart") :: BasePart?
	end
	return nil, nil
end

local function walk(goal: Vector3, near: number, abort: (() -> boolean)?): boolean
	local h, r = hum()
	if not h or not r then
		return false
	end
	local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
	pcall(function()
		path:ComputeAsync((r :: BasePart).Position, goal)
	end)
	if path.Status ~= Enum.PathStatus.Success then
		return false
	end
	for _, wp in path:GetWaypoints() do
		h, r = hum()
		if not h or not r then
			return false
		end
		if wp.Action == Enum.PathWaypointAction.Jump then
			h.Jump = true
		end
		h:MoveTo(wp.Position)
		local t = os.clock()
		while
			(((r :: BasePart).Position - wp.Position) * Vector3.new(1, 0, 1)).Magnitude > 3
			and os.clock() - t < 3
		do
			task.wait(0.05)
			if abort and abort() then
				return true
			end
			h, r = hum()
			if not h or not r then
				return false
			end
		end
		if ((r :: BasePart).Position - goal).Magnitude <= near then
			return true
		end
	end
	return true
end

local function grab(item: BasePart)
	local cam = workspace.CurrentCamera
	cam.CFrame = CFrame.lookAt(item.Position + Vector3.new(8, 6, 0), item.Position)
	task.wait(0.2)
	local prompt = item:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt:InputHoldBegin()
		task.wait(prompt.HoldDuration + 0.25)
		prompt:InputHoldEnd()
		task.wait(0.3)
	end
end

local function cacheItem(): BasePart?
	local loot = workspace:FindFirstChild("Loot")
	for _, item in (loot and loot:GetChildren() or {}) do
		if item:GetAttribute("PursuitCache") and item:IsA("BasePart") then
			return item
		end
	end
	return nil
end

local function runEvent(timeout: number): string
	local log = {}
	local t0 = os.clock()
	local minGap, catches, raceSeconds = math.huge, 0, nil
	local function note(text: string)
		table.insert(log, ("%5.1fs %s"):format(os.clock() - t0, text))
	end
	strikes = 0
	onState = function(m)
		note(
			("state %s %s %s"):format(tostring(m.Phase), tostring(m.Result or ""), tostring(m.Seconds or ""))
		)
		if m.Phase == "Loose" then
			catches += 1
		elseif m.Phase == "Chase" and not raceSeconds then
			raceSeconds = os.clock() - t0
		end
	end
	local lastBranch = ""
	local function branch(name: string)
		if name ~= lastBranch then
			lastBranch = name
			note("branch " .. name)
		end
	end
	while os.clock() - t0 < timeout do
		local s = state or { Phase = "?" }
		local item0 = cacheItem()
		branch(("phase=%s item=%s"):format(tostring(s.Phase), tostring(item0 ~= nil)))
		if s.Phase == "Done" and not item0 and os.clock() - t0 > 2 then
			break
		end
		if item0 and s.Phase ~= "Chase" then
			s = { Phase = s.Phase }
			local item = cacheItem()
			if item then
				local okWalk = walk(item.Position, 7, function()
					return item.Parent == nil
				end)
				branch("walked to item: " .. tostring(okWalk))
				if item.Parent then
					grab(item)
				end
			else
				task.wait(0.3)
			end
		elseif s.Phase == "Chase" and s.CarrierId == me.UserId then
			walk(EXTRACT, 4, function()
				local twister = workspace:FindFirstChild("PursuitTwister") :: BasePart?
				local _, r = hum()
				if twister and r then
					local gap = ((r.Position - twister.Position) * Vector3.new(1, 0, 1)).Magnitude
					minGap = math.min(minGap, gap)
				end
				return not state or state.Phase ~= "Chase"
			end)
			task.wait(0.2)
		else
			task.wait(0.3)
		end
	end
	onState = nil
	local h = hum()
	note(
		("END result=%s race=%.1fs catches=%d minGap=%.1f strikes=%d hp=%s"):format(
			tostring(state and state.Result),
			raceSeconds or -1,
			catches,
			minGap,
			strikes,
			if h then tostring(math.floor(h.Health)) else "dead"
		)
	)
	return table.concat(log, "\n")
end

local fn = Instance.new("BindableFunction")
fn.Name = "QA_RunEvent"
fn.OnInvoke = runEvent
fn.Parent = ReplicatedStorage
