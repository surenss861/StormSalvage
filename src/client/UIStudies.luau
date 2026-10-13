-- UI art-direction studies (Studio only). Three complete, independent interface concepts for
-- the same game state, so they can be compared in real gameplay before one is chosen:
--   Adventure  Salvage Adventure (StudyAdventure.luau)
--   Chaser     Storm Chaser      (StudyChaser.luau)
--   Workshop   Scrapyard Workshop (StudyWorkshop.luau)
--
-- Driven by ReplicatedStorage attributes (set them from the server or the command bar):
--   UIStudy        "Adventure" | "Chaser" | "Workshop" | nil (nil = the normal game HUD)
--   UIStudyScreen  "hud" | "shop" | "receipt" | "rarity"
--   UIStudyRarity  a Config.Loot id for the rarity screen (default "Safe")
--   UIStudyDevice  "desktop" | "phone"  phone lays the study out at 844x390 (an iPhone in
--                  landscape, in points) and magnifies it, so the phone layout can be judged
--                  on a monitor. It is a layout preview, not a device test.
-- The HUD is live (coins, bag, storm, objective). The receipt uses the last real sale, or a
-- sample sale if none happened yet. None of this is reachable outside Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Kit = require(script.Parent:WaitForChild("UIStudyKit"))

local UIStudies = {}

local STUDIES = {
	Adventure = "StudyAdventure",
	Chaser = "StudyChaser",
	Workshop = "StudyWorkshop",
}
local PHONE = Vector2.new(844, 390)

local playerGui: PlayerGui
local hudGui: ScreenGui
local gui: ScreenGui?
local view: any = nil
local content: Frame? = nil
local contentScale: UIScale? = nil
local device = "desktop"

local player: any = nil
local storm: any = { Phase = "Calm", EndsAt = 0 }
local lastReceipt: any = nil

local function objective(): (string, string?)
	if not player then
		return "Find salvage in town", nil
	end
	local carried = #player.Carried
	local text
	if carried == 0 then
		text = "Find salvage in town"
	elseif carried >= player.Capacity then
		text = "Bag full! Sell at the Scrap Buyer on the hill"
	else
		text = "Grab more, or sell at the Scrap Buyer on the hill"
	end
	local hint = nil
	if (storm.Phase == "Warning" or storm.Phase == "Storm") and storm.Storm then
		hint = Config.Storms[storm.Storm].Hint
	end
	return text, hint
end

-- Same rule as the game HUD: phones in landscape land on 0.7, laptops on 1-1.15.
local function fit()
	if not (gui and content and contentScale) then
		return
	end
	local frame = content.Parent :: Frame
	local logicalHeight
	if device == "phone" then
		logicalHeight = PHONE.Y
	else
		local camera = workspace.CurrentCamera
		logicalHeight = if camera then camera.ViewportSize.Y else 600
	end
	local scale = math.clamp(logicalHeight / 600, 0.7, 1.15)
	contentScale.Scale = scale
	content.Size = UDim2.fromScale(1 / scale, 1 / scale)
	frame:SetAttribute("Scale", scale)
end

local function showScreen()
	if not view then
		return
	end
	view.clearOverlay()
	local screen = ReplicatedStorage:GetAttribute("UIStudyScreen") or "hud"
	if screen == "shop" then
		view.shop(player)
	elseif screen == "receipt" then
		view.receipt(lastReceipt or Kit.SampleReceipt)
	elseif screen == "rarity" then
		local id = ReplicatedStorage:GetAttribute("UIStudyRarity") or "Safe"
		if Config.Loot[id] then
			view.rarity(id)
		end
	end
end

local function rebuild()
	if gui then
		gui:Destroy()
		gui = nil
	end
	view, content, contentScale = nil, nil, nil
	local name = ReplicatedStorage:GetAttribute("UIStudy")
	local moduleName = STUDIES[name or ""]
	hudGui.Enabled = moduleName == nil
	if not moduleName then
		return
	end
	device = ReplicatedStorage:GetAttribute("UIStudyDevice") or "desktop"

	local screenGui = Kit.new("ScreenGui", {
		Name = "UIStudy",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 5,
	})
	local frame: Frame
	if device == "phone" then
		-- The phone screen, magnified to fill most of the monitor, with a bezel around it.
		local holder = Kit.box(screenGui, {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(PHONE.X, PHONE.Y),
		})
		local camera = workspace.CurrentCamera
		local vp = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		Kit.new(
			"UIScale",
			{ Parent = holder, Scale = math.min(vp.X * 0.92 / PHONE.X, vp.Y * 0.86 / PHONE.Y) }
		)
		local bezel = Kit.box(holder, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 24, 1, 24),
			BackgroundTransparency = 1,
		})
		Kit.corner(bezel, 44)
		Kit.stroke(bezel, Color3.fromRGB(14, 14, 16), 12)
		Kit.label(holder, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, 16),
			Size = UDim2.fromOffset(600, 20),
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "PHONE LAYOUT PREVIEW  ·  844 × 390 pt  ·  UI scale 0.70",
		})
		frame = Kit.box(holder, {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ClipsDescendants = true,
		})
	else
		frame = Kit.box(screenGui, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	end
	local inner = Kit.box(frame, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	contentScale = Kit.new("UIScale", { Parent = inner })
	content = inner
	gui = screenGui
	fit()

	local module = require(script.Parent:WaitForChild(moduleName)) :: any
	view = module.build(inner, Kit, { Phone = device == "phone" })
	screenGui.Parent = playerGui
	showScreen()
end

function UIStudies.init(pg: PlayerGui, normalHud: ScreenGui)
	if not RunService:IsStudio() then
		return
	end
	playerGui = pg
	hudGui = normalHud
	ReplicatedStorage:GetAttributeChangedSignal("UIStudy"):Connect(rebuild)
	ReplicatedStorage:GetAttributeChangedSignal("UIStudyDevice"):Connect(rebuild)
	ReplicatedStorage:GetAttributeChangedSignal("UIStudyScreen"):Connect(showScreen)
	ReplicatedStorage:GetAttributeChangedSignal("UIStudyRarity"):Connect(showScreen)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	if ReplicatedStorage:GetAttribute("UIStudy") then
		rebuild()
	end
end

function UIStudies.setPlayer(s: any)
	player = s
	local screen = ReplicatedStorage:GetAttribute("UIStudyScreen")
	if view and screen == "shop" then
		showScreen()
	end
end

function UIStudies.setStorm(s: any)
	storm = s
end

function UIStudies.onSale(receipt: any)
	lastReceipt = receipt
	if view then
		view.receipt(receipt, ReplicatedStorage:GetAttribute("UIStudyScreen") ~= "receipt")
	end
end

function UIStudies.onPickup(info: any)
	if view and info and info.Id and Config.Loot[info.Id] then
		view.rarity(info.Id, true)
	end
end

function UIStudies.step(now: number)
	if view and player then
		local text, hint = objective()
		view.hud(player, storm, now, text, hint)
	end
end

return UIStudies
