-- @file Salvage Detector scans (server side)
-- @domain salvage-economy
-- @status stable
-- @see [[Detector.luau]]
-- @see [[V3-SUPPLY-DEPOT]]
-- Runs the Salvage Detector for the players who own it. The scan happens here, on the server,
-- with the pure rules in shared/Detector: ordinary salvage only, never Epic finds, Storm Cores
-- or dropped bags, within range, nearest few. Each owner gets a DetectorPing only when that set
-- changes (at most once per ScanSeconds), so a player standing still costs no traffic. The
-- client draws what it is sent and nothing else; the detector never collects or extends reach.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Detector = require(ReplicatedStorage.Shared.Detector)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local LootService = require(script.Parent.LootService)
local PlayerService = require(script.Parent.PlayerService)

local DetectorService = {}

local DEF = Config.Tools.Detector
local pingRemote = Remotes.get("DetectorPing")
local lastSent: { [Player]: { Detector.Blip } } = {}
local ids: { [Instance]: string } = setmetatable({}, { __mode = "k" }) :: any
local nextId = 0

local function idOf(item: Instance): string
	local id = ids[item]
	if not id then
		nextId += 1
		id = tostring(nextId)
		ids[item] = id
	end
	return id
end

local function candidates(): { Detector.Candidate }
	local list = {}
	local folder = LootService.folder()
	if not folder then
		return list
	end
	for _, item in folder:GetChildren() do
		local lootId = item:GetAttribute("LootId")
		local def = type(lootId) == "string" and Config.Loot[lootId]
		if def and item:IsA("BasePart") then
			local p = item.Position
			table.insert(list, {
				Id = idOf(item),
				X = p.X,
				Z = p.Z,
				Rarity = def.Rarity,
				Dropped = item:GetAttribute("OwnerId") ~= nil,
			})
		end
	end
	return list
end

local function scan()
	local list: { Detector.Candidate }? = nil
	for _, player in Players:GetPlayers() do
		if PlayerService.ownsTool(player, "Detector") then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local blips: { Detector.Blip } = {}
			if root and humanoid and humanoid.Health > 0 then
				list = list or candidates()
				blips = Detector.pick(
					root.Position.X,
					root.Position.Z,
					list :: { Detector.Candidate },
					DEF.Range,
					DEF.Rarities,
					DEF.MaxBlips
				)
			end
			if not Detector.sameSet(lastSent[player], blips) then
				lastSent[player] = blips
				local payload = {}
				for _, b in blips do
					table.insert(payload, {
						X = math.floor(b.X * 10 + 0.5) / 10,
						Z = math.floor(b.Z * 10 + 0.5) / 10,
					})
				end
				pingRemote:FireClient(player, payload)
			end
		end
	end
end

function DetectorService.init()
	Players.PlayerRemoving:Connect(function(player)
		lastSent[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(DEF.ScanSeconds)
			local ok, err = pcall(scan)
			if not ok then
				warn("[DetectorService] scan failed:", err)
			end
		end
	end)
end

return DetectorService
