-- Multiplayer QA harness (client side). Not part of the game: an MCP session puts it into
-- each test client's PlayerScripts during a StudioTestService run, so several clients can
-- act in the same frame. The server starts an action by setting workspace attributes:
--   QA_Action  = "grab" | "sell"
--   QA_Target  = loot item name (grab only)
--   QA_FireAt  = server timestamp to act at (changing it starts the action)
-- Each client reports back with ReplicatedStorage attribute QA_<PlayerName> (client-local).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local name = Players.LocalPlayer.Name
ReplicatedStorage:SetAttribute("QA_Ready", true)

local function findSellPrompt(): ProximityPrompt?
	for _, d in workspace:GetDescendants() do
		if d:IsA("ProximityPrompt") and d.Name == "SellPrompt" then
			return d
		end
	end
	return nil
end

local function run()
	local action = workspace:GetAttribute("QA_Action")
	local fireAt = workspace:GetAttribute("QA_FireAt")
	if not action or not fireAt then
		return
	end
	local prompt: ProximityPrompt?
	if action == "grab" then
		local item = workspace.Loot:FindFirstChild(workspace:GetAttribute("QA_Target") or "")
		prompt = item and item:FindFirstChildOfClass("ProximityPrompt")
	elseif action == "sell" then
		prompt = findSellPrompt()
	end
	if not prompt then
		ReplicatedStorage:SetAttribute("QA_" .. name, action .. ": no prompt")
		return
	end
	while workspace:GetServerTimeNow() < fireAt do
		task.wait()
	end
	local started = workspace:GetServerTimeNow()
	prompt:InputHoldBegin()
	task.wait(prompt.HoldDuration + 0.05)
	prompt:InputHoldEnd()
	ReplicatedStorage:SetAttribute("QA_" .. name, ("%s: began %.3f"):format(action, started))
end

workspace:GetAttributeChangedSignal("QA_FireAt"):Connect(run)
