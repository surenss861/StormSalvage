-- Multiplayer QA (client side, not part of the game): records the storm timeline this
-- client receives, so several clients can be compared. Put into PlayerScripts during a
-- StudioTestService run; read back with ReplicatedStorage:GetAttribute("QA_StormLog").
--   S|phase|storm|gustAt|gustEnd|floodLevel|floodNextAt   (storm state updates)
--   L|x|z|radius|serverTimeReceived                       (lightning warnings)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local log = {}

local function push(line: string)
	table.insert(log, line)
	ReplicatedStorage:SetAttribute("QA_StormLog", HttpService:JSONEncode(log))
end

remotes.StormState.OnClientEvent:Connect(function(s)
	push(
		("S|%s|%s|%.2f|%.2f|%d|%.2f"):format(
			s.Phase,
			tostring(s.Storm),
			s.GustAt or 0,
			s.GustEnd or 0,
			s.FloodLevel or 0,
			s.FloodNextAt or 0
		)
	)
end)

remotes.LightningWarning.OnClientEvent:Connect(function(pos: Vector3, radius: number)
	push(("L|%.1f|%.1f|%d|%.2f"):format(pos.X, pos.Z, radius, workspace:GetServerTimeNow()))
end)
