-- District titles: when you walk into a district, a short title and its best finds appear
-- under the storm strip for a few seconds. These replace the big floating district names
-- that used to hang over the town; the buildings carry their own physical signs.
--
-- The server publishes each district's footprint as an invisible part in Map.Districts
-- (attribute Zone = the loot pool name, Label = the display name).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Notifications = require(script.Parent:WaitForChild("Notifications"))

local Districts = {}

type District = { Label: string, Sub: string, CFrame: CFrame, Half: Vector3 }
local districts: { District } = {}
local current: string? = nil
local RANK = { Common = 0, Uncommon = 1, Rare = 2, Epic = 3, Legendary = 4 }

-- "Best finds: Engine Block, Mini Safe" from the district's loot pool.
local function bestFinds(zone: string?): string
	local pool = zone and Config.ZonePools[zone]
	if not pool then
		return ""
	end
	local items = {}
	for _, entry in pool do
		table.insert(items, Config.Loot[entry.Id])
	end
	table.sort(items, function(a, b)
		return (RANK[a.Rarity] or 0) * 1000 + a.Value > (RANK[b.Rarity] or 0) * 1000 + b.Value
	end)
	return ("Best finds: %s, %s"):format(items[1].Name, items[2].Name)
end

local function inside(d: District, position: Vector3): boolean
	local p = d.CFrame:PointToObjectSpace(position)
	return math.abs(p.X) <= d.Half.X and math.abs(p.Z) <= d.Half.Z and math.abs(p.Y) <= d.Half.Y
end

function Districts.init()
	task.spawn(function()
		local map = workspace:WaitForChild("Map", 60)
		local folder = map and map:WaitForChild("Districts", 60)
		if not folder then
			return
		end
		for _, part in folder:GetChildren() do
			if part:IsA("BasePart") then
				local zone = part:GetAttribute("Zone")
				table.insert(districts, {
					Label = string.upper(part:GetAttribute("Label") or part.Name),
					Sub = part:GetAttribute("Sub") or bestFinds(zone),
					CFrame = part.CFrame,
					Half = part.Size / 2,
				})
			end
		end
		while true do
			task.wait(0.5)
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local here: District? = nil
				for _, d in districts do
					if inside(d, root.Position) then
						here = d
						break
					end
				end
				local label = if here then here.Label else nil
				if label ~= current then
					current = label
					if here then
						Notifications.location(here.Label, here.Sub)
					end
				end
			end
		end
	end)
end

return Districts
