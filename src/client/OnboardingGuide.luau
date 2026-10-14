-- @file First-session guide: the objective line and a pointer to where to go
-- @domain ui
-- @status wip
-- @see [[Onboarding.luau]]
-- Shows the Onboarding step as the objective note and points at its target in the world: a
-- marker with the distance over the target, and a chevron at your feet facing it. The pointer
-- hides within a few studs of the target and never appears once the lessons are done.
-- Targets: Loot (nearest salvage you can take), Sell (the Scrap Buyer), Plateau (the Scrapyard
-- gate), Event (the live event's site), Shop (the Gear Shop counter).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BigMoney = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BigMoney"))
local Config = require(ReplicatedStorage.Shared:WaitForChild("Config"))
local Onboarding = require(ReplicatedStorage.Shared:WaitForChild("Onboarding"))
local UI = require(script.Parent:WaitForChild("UI"))

local OnboardingGuide = {}

local PLATEAU = Vector3.new(0, 31, -228)
local AMBER = Color3.fromRGB(255, 176, 46)

local folder: Folder
local marker: Part
local markerLabel: TextLabel
local chevron: { BasePart } = {}
local current: Onboarding.Step? = nil
local eventTarget: () -> Vector3? = function()
	return nil
end

local function part(name: string): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = AMBER
	p.Parent = folder
	return p
end

local function cheapest(s: any): number?
	local best: number? = nil
	for id, def in Config.Upgrades do
		local cost = def.Costs[(s.Upgrades[id] or 0) + 1]
		if cost and not def.License and (best == nil or cost < best) then
			best = cost
		end
	end
	return best
end

-- The Onboarding step for this player state and what's happening now.
function OnboardingGuide.compute(s: any, phase: string, eventLive: boolean): Onboarding.Step?
	if type(s) ~= "table" then
		return nil
	end
	local levels, core = 0, false
	for _, level in s.Upgrades or {} do
		levels += level
	end
	for _, id in s.Carried or {} do
		if Config.CoreIds[id] then
			core = true
		end
	end
	local cost = cheapest(s)
	local records = s.Records or {}
	return Onboarding.step({
		ItemsSold = s.Stats and s.Stats.ItemsSold or 0,
		Carried = #(s.Carried or {}),
		Capacity = s.Capacity or 1,
		-- Profiles from before StormsSeen existed start it at 0: their survived storms count too.
		StormsSeen = if s.Stats then math.max(s.Stats.StormsSeen or 0, s.Stats.StormsSurvived or 0) else 0,
		Extractions = records.Extractions or 0,
		RushFinds = records.RushFinds or 0,
		Upgrades = levels,
		HasPro = s.Licenses ~= nil and s.Licenses.Pro == true,
	}, {
		Phase = phase,
		EventLive = eventLive,
		CarryingCore = core,
		CanAffordUpgrade = cost ~= nil and BigMoney.gte(s.Coins, BigMoney.of(cost)),
	})
end

function OnboardingGuide.set(step: Onboarding.Step?)
	current = step
end

function OnboardingGuide.setEventTarget(fn: () -> Vector3?)
	eventTarget = fn
end

local function nearestLoot(from: Vector3): Vector3?
	local loot = workspace:FindFirstChild("Loot")
	if not loot then
		return nil
	end
	local best, bestD = nil, math.huge
	for _, item in loot:GetChildren() do
		local owner = item:GetAttribute("OwnerId")
		local mine = owner == Players.LocalPlayer.UserId
		local takeable = not item:GetAttribute("License") and (owner == nil or mine)
		-- From the Scrapyard, point down the ramp into town: the yards beside the plateau are
		-- below its cliffs (reachable only by the shortcuts), so "nearest" there misleads.
		local onPlateau = from.Y > 25 and from.Z < -205
		local inTown = item:IsA("BasePart") and (item :: BasePart).Position.Z > -205
		if onPlateau and not inTown then
			takeable = false
		end
		if item:IsA("BasePart") and takeable then
			-- Your own find (the welcome Jukebox) wins over closer junk.
			local d = (item.Position - from).Magnitude * (if mine then 0.25 else 1)
			if d < bestD then
				best, bestD = item.Position, d
			end
		end
	end
	return best
end

local function promptPart(name: string): Vector3?
	for _, d in workspace:GetDescendants() do
		if d:IsA("ProximityPrompt") and d.Name == name and d.Parent and d.Parent:IsA("BasePart") then
			return (d.Parent :: BasePart).Position
		end
	end
	return nil
end

local cachedSell: Vector3? = nil
local cachedShop: Vector3? = nil

local function targetOf(id: string?, from: Vector3): Vector3?
	if id == "Loot" then
		return nearestLoot(from)
	elseif id == "Sell" then
		cachedSell = cachedSell or promptPart("SellPrompt")
		return cachedSell
	elseif id == "Shop" then
		cachedShop = cachedShop or promptPart("UpgradePrompt")
		return cachedShop
	elseif id == "Plateau" then
		return PLATEAU
	elseif id == "Event" then
		return eventTarget()
	end
	return nil
end

local function step()
	local root = Players.LocalPlayer.Character
		and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local s = current
	local at = if s and root then targetOf(s.Target, root.Position) else nil
	local d = if at and root then ((at - root.Position) * Vector3.new(1, 0, 1)).Magnitude else 0
	local show = at ~= nil and root ~= nil and d > 8 and not UI.modalOpen()
	marker.Transparency = if show then 0.35 else 1
	markerLabel.Visible = show
	for _, c in chevron do
		c.Transparency = if show then 0.25 else 1
	end
	if not show or not at or not root then
		return
	end
	marker.Position = at + Vector3.new(0, 7 + (if UI.reduced() then 0 else math.sin(os.clock() * 3) * 0.6), 0)
	markerLabel.Text = ("%dm"):format(math.floor(d))
	local dir = ((at - root.Position) * Vector3.new(1, 0, 1)).Unit
	local base = root.Position - Vector3.new(0, 2.8, 0) + dir * 4
	local cf = CFrame.lookAt(base, base + dir)
	chevron[1].CFrame = cf * CFrame.Angles(0, math.rad(40), 0) * CFrame.new(0, 0, 1.2)
	chevron[2].CFrame = cf * CFrame.Angles(0, math.rad(-40), 0) * CFrame.new(0, 0, 1.2)
end

function OnboardingGuide.init()
	folder = Instance.new("Folder")
	folder.Name = "GuideFx"
	folder.Parent = workspace
	marker = part("GuideMarker")
	marker.Shape = Enum.PartType.Ball
	marker.Size = Vector3.new(1.6, 1.6, 1.6)
	marker.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(80, 26)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = marker
	markerLabel = UI.text({
		Parent = gui,
		FontFace = UI.Heading,
		TextSize = 18,
		Size = UDim2.fromScale(1, 1),
		TextColor3 = AMBER,
		Outline = true,
		Text = "",
		Visible = false,
	})
	for i = 1, 2 do
		local c = part("GuideChevron" .. i)
		c.Size = Vector3.new(0.7, 0.15, 2.4)
		c.Transparency = 1
		table.insert(chevron, c)
	end
	RunService.RenderStepped:Connect(step)
end

return OnboardingGuide
