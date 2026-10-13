-- @file Client memory soak
-- @domain qa
-- @status stable
-- @see [[V3-SOAK-AND-DEATH-QA]]
-- Client memory soak (QA only, not part of the game). Run with the MCP execute_luau tool in the
-- Client data model during a Studio Play session, after the server side has created the
-- runtime-only RemoteFunction ReplicatedStorage.QA_Server (see docs/production/V3-SOAK.md).
--
-- One cycle = spawn 3 loot near the player (every third includes a Storm Core, every other an
-- Epic) -> collect each through its real ProximityPrompt -> sell at the real SellPrompt ->
-- buy an upgrade (BuyUpgrade remote) -> open/close the Gear Shop 3x and Settings 2x (Studio
-- QA probe) -> die and respawn -> advance the storm one phase.
-- Installs ReplicatedStorage.QA_Soak (BindableFunction): Invoke(cycles) runs that many cycles
-- and returns one metrics line; Invoke(0) only measures.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stats = game:GetService("Stats")

local lp = Players.LocalPlayer
local server = ReplicatedStorage:WaitForChild("QA_Server") :: RemoteFunction
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local probe = lp:WaitForChild("PlayerScripts"):FindFirstChild("QA_ClientProbe", true) :: BindableFunction

local function hold(prompt: ProximityPrompt)
	prompt:InputHoldBegin()
	task.wait(prompt.HoldDuration + 0.1)
	prompt:InputHoldEnd()
end

local function root(): BasePart
	local c = lp.Character or lp.CharacterAdded:Wait()
	return c:WaitForChild("HumanoidRootPart") :: BasePart
end

local function sellPrompt(): ProximityPrompt?
	for _, d in workspace:GetDescendants() do
		if d:IsA("ProximityPrompt") and d.Name == "SellPrompt" then
			return d
		end
	end
	return nil
end

local UPGRADES = { "Boots", "Armor", "Backpack" }
local cycleCount = 0

local function cycle()
	cycleCount += 1
	server:InvokeServer("home")
	task.wait(0.3)
	local ids = {
		"Can",
		if cycleCount % 2 == 0 then "Safe" else "Register",
		if cycleCount % 3 == 0 then "StormCore" else "Tv",
	}
	local names = server:InvokeServer("spawnloot", table.unpack(ids))
	for _, name in names do
		local item = workspace.Loot:FindFirstChild(name)
		local prompt = item and item:FindFirstChildOfClass("ProximityPrompt")
		if item and prompt then
			root().CFrame = CFrame.new(item.Position + Vector3.new(0, 2, 2.5))
			task.wait(0.25)
			hold(prompt)
			task.wait(0.15)
		end
	end
	local sp = sellPrompt()
	if sp then
		local at = (sp.Parent :: BasePart).Position
		root().CFrame = CFrame.lookAt(at + Vector3.new(0, 1, 4), at + Vector3.new(0, 1, 0))
		task.wait(0.4)
		hold(sp)
		task.wait(0.4)
	end
	server:InvokeServer("coins", 5000)
	remotes.BuyUpgrade:FireServer(UPGRADES[cycleCount % 3 + 1])
	for _ = 1, 3 do
		probe:Invoke("shop")
		task.wait(0.15)
		probe:Invoke("shop")
		task.wait(0.1)
	end
	for _ = 1, 2 do
		probe:Invoke("settings")
		task.wait(0.15)
		probe:Invoke("settings")
		task.wait(0.1)
	end
	server:InvokeServer("kill")
	server:InvokeServer("skip")
	task.wait(0.3)
end

local function measure(): string
	local gui = #lp.PlayerGui:GetDescendants()
	local ws = #workspace:GetDescendants()
	local fx = workspace:FindFirstChild("SalvageEffects")
	local s = server:InvokeServer("server")
	return ("cycles=%d clientMem=%.0fMB luaHeap=%.1fMB gui=%.1fMB instMem=%.1fMB playerGui=%d workspace=%d salvageFx=%d terrainAtt=%d | server inst=%d mem=%.0fMB loot=%d"):format(
		cycleCount,
		Stats:GetTotalMemoryUsageMb(),
		Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.LuaHeap),
		Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Gui),
		Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Instances),
		gui,
		ws,
		if fx then #fx:GetChildren() else -1,
		#workspace.Terrain:GetChildren(),
		s.instances,
		s.mem,
		s.loot
	)
end

local old = ReplicatedStorage:FindFirstChild("QA_Soak")
if old then
	old:Destroy()
end
local fn = Instance.new("BindableFunction")
fn.Name = "QA_Soak"
fn.OnInvoke = function(cycles: number)
	for _ = 1, cycles do
		cycle()
	end
	task.wait(2) -- let cards, pops and debris expire before measuring
	return measure()
end
fn.Parent = ReplicatedStorage
return "QA_Soak installed"
