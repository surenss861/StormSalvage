-- @file Onboarding QA bot: a fresh profile played to the first licence by client inputs only
-- @domain qa
-- @status wip
-- @see [[V4-ONBOARDING]]
-- Client side, not part of the game (tools/ is outside the Rojo tree). Run in a Studio Play
-- session's Client context on a brand-new profile (ServerStorage attribute QA_ProfileStore).
-- It does only what a player's client can do: walk (PathfindingService at the character's own
-- WalkSpeed, with short direct legs when no path is found), hold real ProximityPrompts
-- (InputHoldBegin/End, so the server's distance and hold checks apply), and fire the same
-- remotes the Gear Shop buttons fire. Nothing is granted. It shelters on the Scrapyard during
-- storms, carries event cores home first, sells when the bag is full and buys cheap gear.
-- It never buys a licence: that last step is done by hand through the real Tools tab.
-- Runs as a LocalScript (the Studio command bar parents it to PlayerGui). Progress is published
-- as JSON on the LocalPlayer attribute QA_Bot; set the attribute QA_BotStop to stop it.

local Players = game:GetService("Players")
local PFS = game:GetService("PathfindingService")
local RS = game:GetService("ReplicatedStorage")

local me = Players.LocalPlayer
local R = RS:WaitForChild("Remotes")
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))

local S = {
	Phase = "Calm",
	Log = {},
	State = nil :: any,
	Sells = 0,
	Grabs = 0,
	Fails = 0,
	CarryCore = false,
	CarryingEvent = false,
}
local function running(): boolean
	return me:GetAttribute("QA_BotStop") ~= true
end

local function log(t: string)
	table.insert(S.Log, os.date("%X") .. " " .. t)
	if #S.Log > 30 then
		table.remove(S.Log, 1)
	end
end

R.PlayerState.OnClientEvent:Connect(function(s)
	S.State = s
end)
R.StormState.OnClientEvent:Connect(function(s)
	S.Phase = if type(s) == "table" then (s.Phase or S.Phase) else tostring(s)
end)
R.PursuitState.OnClientEvent:Connect(function(p)
	if type(p) == "table" and p.Result then
		log(("event %s %s carrier %s"):format(tostring(p.Kind), tostring(p.Result), tostring(p.CarrierName)))
	end
end)

local sellPrompt = workspace:FindFirstChild("SellPrompt", true) :: ProximityPrompt
local HOME = Vector3.new(0, 34, -240)

local function body(): (BasePart?, Humanoid?)
	local c = me.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	if h and h.Health > 0 then
		return c:FindFirstChild("HumanoidRootPart") :: BasePart?, h
	end
	return nil, nil
end

local function stepTo(h: Humanoid, r: BasePart, p: Vector3, seconds: number, valid: (() -> boolean)?)
	h:MoveTo(p)
	local t0 = os.clock()
	while ((r.Position - p) * Vector3.new(1, 0, 1)).Magnitude > 3 and os.clock() - t0 < seconds do
		if valid and not valid() then
			return
		end
		task.wait(0.1)
	end
end

-- An event cache (Pursuit / Extraction) is up: its race is 25 s, so every other errand yields.
local chasingEvent = false
local function eventLive(): boolean
	for _, item in workspace.Loot:GetChildren() do
		if item:GetAttribute("PursuitCache") then
			local p = item:FindFirstChildOfClass("ProximityPrompt")
			if p and p.Enabled then
				return true
			end
		end
	end
	return false
end

-- Walk to `goal` (within `near`). Pathfinding first; with no path, a short direct leg, then
-- try again (long trips across town often have no single computable path).
local function goTo(goal: Vector3, near: number, valid: (() -> boolean)?): boolean
	for _ = 1, 12 do
		local r, h = body()
		if not r or not h or not running() or (valid and not valid()) then
			return false
		end
		if not chasingEvent and eventLive() then
			return false
		end
		if (r.Position - goal).Magnitude < near then
			return true
		end
		local path =
			PFS:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 8 })
		local ok = pcall(function()
			path:ComputeAsync(r.Position, goal)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			for _, w in path:GetWaypoints() do
				r, h = body()
				if not r or not h or not running() or (valid and not valid()) then
					return false
				end
				if not chasingEvent and eventLive() then
					return false
				end
				if w.Action == Enum.PathWaypointAction.Jump then
					h.Jump = true
				end
				stepTo(h, r, w.Position, 4, valid)
				if (r.Position - goal).Magnitude < near then
					return true
				end
			end
		else
			local flat = (goal - r.Position) * Vector3.new(1, 0, 1)
			local leg = r.Position + flat.Unit * math.min(flat.Magnitude, 60)
			h.Jump = true
			stepTo(h, r, leg, 5, valid)
		end
	end
	local r = body()
	return r ~= nil and (r.Position - goal).Magnitude < near + 2
end

local function hold(prompt: ProximityPrompt)
	local item = prompt.Parent :: any
	local at = if item:IsA("Model") then item:GetPivot().Position else item.Position
	workspace.CurrentCamera.CFrame = CFrame.lookAt(at + Vector3.new(8, 6, 0), at)
	task.wait(0.2)
	prompt:InputHoldBegin()
	task.wait(prompt.HoldDuration + 0.25)
	prompt:InputHoldEnd()
	task.wait(0.4)
end

local function posOf(inst: Instance): Vector3?
	if inst:IsA("BasePart") then
		return inst.Position
	elseif inst:IsA("Model") then
		return inst:GetPivot().Position
	end
	return nil
end

local bad: { [Instance]: number } = {}

-- Nearest takeable salvage in town (beyond the plateau cliffs is unreachable); event cores
-- (and the storm's own cores) first, wherever they are.
local function pick(): (ProximityPrompt?, boolean)
	local r = body()
	if not r then
		return nil, false
	end
	local lic = S.State and S.State.Licenses or {}
	local best, bestD, bestCore = nil, math.huge, false
	for _, p in workspace.Loot:GetDescendants() do
		if p:IsA("ProximityPrompt") and p.Enabled and (bad[p] or 0) < 2 then
			local item = p.Parent :: Instance
			local L = item:GetAttribute("License")
			local owner = item:GetAttribute("OwnerId")
			local pos = posOf(item)
			local core = item:GetAttribute("PursuitCache") ~= nil or p.ObjectText:find("Core") ~= nil
			if pos and (core or pos.Z > -205) and (not L or lic[L]) and (not owner or owner == me.UserId) then
				-- Event caches (they count toward the licence) outrank storm cores and Rush finds.
				local event = item:GetAttribute("PursuitCache") ~= nil
				local rush = item:GetAttribute("RushItem") ~= nil
				local d = (pos - r.Position).Magnitude
					- (if event then 3000 elseif core then 1000 elseif rush then 300 else 0)
				if d < bestD then
					best, bestD, bestCore = p, d, core
				end
			end
		end
	end
	return best, bestCore
end

local function carried(): (number, number)
	local s = S.State
	if not s then
		return 0, 3
	end
	return #s.Carried, s.Capacity or 3
end

local function sell()
	if goTo((sellPrompt.Parent :: BasePart).Position, 9) then
		hold(sellPrompt)
		S.Sells += 1
	end
end

-- Cheap gear only (the Gear Shop's own remote), so coins build toward the licence.
local function shop()
	local s = S.State
	if not s then
		return
	end
	local coins = tonumber(s.Coins) or 0
	for _, id in { "Backpack", "Boots", "Armor" } do
		local def = Config.Upgrades[id]
		local level = (s.Upgrades or {})[id] or 0
		local cost = def and def.Costs[level + 1]
		if cost and coins >= cost and cost <= math.max(coins * 0.3, 160) then
			R.BuyUpgrade:FireServer(id)
			log(("bought %s L%d for %d"):format(id, level + 1, cost))
			task.wait(1)
			return
		end
	end
end

local function tick()
	local r = body()
	if not r then
		S.CarryCore = false
		task.wait(1)
		return
	end
	local n, cap = carried()
	if S.CarryCore then
		chasingEvent = S.CarryingEvent == true
		if goTo(HOME, 8) then
			log("core home")
		end
		S.CarryCore = false
		task.wait(1.5)
		return
	end
	local p, core = pick()
	if (S.Phase == "Warning" or S.Phase == "Storm") and not core then
		if n > 0 then
			sell()
			shop()
		end
		goTo((sellPrompt.Parent :: BasePart).Position + Vector3.new(10, 0, -10), 8)
		task.wait(1)
		return
	end
	if not p or (n >= cap and not core) then
		if n > 0 then
			sell()
			shop()
		else
			task.wait(1)
		end
		return
	end
	local prompt = p :: ProximityPrompt
	local valid = function()
		return prompt.Parent ~= nil and prompt.Enabled
	end
	local at = posOf(prompt.Parent :: Instance) :: Vector3
	local event = (prompt.Parent :: Instance):GetAttribute("PursuitCache") ~= nil
	chasingEvent = event
	if event then
		log(
			("event cache %s at %d studs"):format(
				prompt.ObjectText,
				math.floor((at - (body() :: BasePart).Position).Magnitude)
			)
		)
	end
	if goTo(at, math.min(prompt.MaxActivationDistance - 2, 7), valid) and valid() then
		hold(prompt)
		if not prompt:IsDescendantOf(workspace) or not prompt.Enabled then
			S.Grabs += 1
			if core then
				S.CarryCore = true
				S.CarryingEvent = event
				log("carrying " .. prompt.ObjectText .. (if event then " (event)" else ""))
			end
			return
		end
	end
	if event then
		log(
			("event cache missed: still there %s, enabled %s"):format(
				tostring(prompt.Parent ~= nil),
				tostring(prompt.Enabled)
			)
		)
	end
	if prompt.Parent then
		bad[prompt] = (bad[prompt] or 0) + 1
		S.Fails += 1
	end
end

task.spawn(function()
	local HttpService = game:GetService("HttpService")
	while running() do
		local st = S.State or {}
		me:SetAttribute(
			"QA_Bot",
			HttpService:JSONEncode({
				Phase = S.Phase,
				Grabs = S.Grabs,
				Sells = S.Sells,
				Fails = S.Fails,
				Coins = st.Coins,
				Lifetime = st.Lifetime,
				XP = st.Rep and st.Rep.XP,
				Records = st.Records,
				Licenses = st.Licenses,
				Log = S.Log,
			})
		)
		task.wait(1)
	end
end)

task.spawn(function()
	while running() do
		local ok, err = pcall(tick)
		if not ok then
			log("err " .. tostring(err))
			task.wait(1)
		end
		task.wait(0.1)
	end
	log("stopped")
end)
