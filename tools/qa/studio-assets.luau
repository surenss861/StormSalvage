-- @file Studio QA: build the JSON-authored assets (part models, animations) into the open place
-- @domain qa
-- @status stable
-- Rojo builds these from assets/roblox/**/*.model.json; Studio windows synced with
-- tools/studio-sync.luau (scripts only) need them built by hand. Run from the Edit command bar
-- while `python3 -m http.server 34872` serves the repo:
--   loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:34872/tools/qa/studio-assets.luau"))()
local Http = game:GetService("HttpService")
local BASE = "http://127.0.0.1:34872/assets/roblox/"
local function cf(t)
	local c = t.CFrame or t.OptionalCFrame
	local o, p = c.orientation, c.position
	return CFrame.new(
		p[1],
		p[2],
		p[3],
		o[1][1],
		o[1][2],
		o[1][3],
		o[2][1],
		o[2][2],
		o[2][3],
		o[3][1],
		o[3][2],
		o[3][3]
	)
end
local function build(node, parent)
	local inst = Instance.new(node.className)
	inst.Name = node.name or inst.Name
	local pr = node.properties or {}
	if node.className == "Part" then
		inst.Size = Vector3.new(table.unpack(pr.Size))
		inst.CFrame = cf(pr.CFrame)
		inst.Color = Color3.new(table.unpack(pr.Color))
		inst.Material = Enum.Material[pr.Material]
		inst.Shape = Enum.PartType[pr.Shape]
		inst.Transparency = pr.Transparency
		inst.Anchored, inst.CanCollide, inst.CanQuery, inst.CanTouch =
			true, pr.CanCollide == true, pr.CanQuery == true, pr.CanTouch == true
		inst.CastShadow = pr.CastShadow
		inst.TopSurface, inst.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	elseif node.className == "Model" then
		inst.WorldPivot = CFrame.new()
	elseif node.className == "Pose" then
		inst.CFrame = cf(pr.CFrame)
		inst.Weight = pr.Weight
		inst.EasingStyle = Enum.PoseEasingStyle[pr.EasingStyle]
		inst.EasingDirection = Enum.PoseEasingDirection[pr.EasingDirection]
	elseif node.className == "Keyframe" then
		inst.Time = pr.Time
	elseif node.className == "KeyframeSequence" then
		inst.Loop = pr.Loop
		inst.Priority = Enum.AnimationPriority[pr.Priority]
	end
	for _, c in node.children or {} do
		build(c, inst)
	end
	inst.Parent = parent
	return inst
end
local assets = game.ServerStorage.Assets
local SETS = {
	salvage = {
		"GoldenCore",
		"CopperSpool",
		"HydraulicPump",
		"DieselGenerator",
		"TurbineRotor",
		"GaleShard",
		"TideRelic",
		"Fulgurite",
		"StormHeart",
		"Strongbox",
		"BullionBar",
		"CrownJewels",
		"TitanCore",
		"PrismCore",
		"SingularityCore",
	},
	events = { "ArmoredWreck" },
	animations = { "Dodge", "CoreCarry", "Celebrate" },
}
local built = 0
for set, names in SETS do
	local folder = assets:FindFirstChild(set)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = set
		folder.Parent = assets
	end
	for _, n in names do
		local old = folder:FindFirstChild(n)
		if old then
			old:Destroy()
		end
		local data = Http:JSONDecode(Http:GetAsync(BASE .. set .. "/" .. n .. ".model.json"))
		data.name = n
		build(data, folder)
		built += 1
	end
end
print(("[studio-assets] built %d assets"):format(built))
return built
