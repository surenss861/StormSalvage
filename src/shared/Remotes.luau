--!strict
-- Shared remote registry. The server creates the instances; clients wait for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"PlayerState", -- server -> client: full player state table
	"StormState", -- server -> client: phase, storm type, ends-at timestamp
	"Notify", -- server -> client: toast text, color
	"BuyUpgrade", -- client -> server: upgradeId
	"LightningWarning", -- server -> client: position, radius, delay
}

local folder: Folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in EVENTS do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local Remotes = {}

function Remotes.get(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
