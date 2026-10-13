-- Overhead nameplates for other players: display name, Salvager rank title, and the nameplate
-- finish they've equipped (bought with coins at the Jobs board). Drawn from the attributes the
-- server sets on each Player (RankTitle, Plate), so nothing here is trusted for gameplay. Replaces
-- Roblox's default overhead name, which the server hides.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlateStyle = require(script.Parent:WaitForChild("PlateStyle"))
local UI = require(script.Parent:WaitForChild("UI"))

local Nameplates = {}

local function attach(player: Player, character: Model)
	local head = character:WaitForChild("Head", 10) :: BasePart?
	if not head then
		return
	end
	local old = head:FindFirstChild("Nameplate")
	if old then
		old:Destroy()
	end
	local gui = UI.new("BillboardGui", {
		Name = "Nameplate",
		Parent = head,
		Adornee = head,
		Size = UDim2.fromOffset(170, 40),
		StudsOffset = Vector3.new(0, 2.6, 0),
		MaxDistance = 70,
		LightInfluence = 0,
	})
	local plate = UI.new("Frame", {
		Parent = gui,
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
	}, { UI.corner(6) })
	local stroke = UI.stroke(Color3.new(), 3)
	stroke.Parent = plate
	local name = UI.text({
		Parent = plate,
		Font = UI.Font.Mono,
		TextSize = 15,
		Position = UDim2.fromOffset(0, 3),
		Size = UDim2.new(1, 0, 0, 18),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = player.DisplayName,
	})
	local title = UI.text({
		Parent = plate,
		Font = UI.Font.Label,
		TextSize = 11,
		Position = UDim2.fromOffset(0, 21),
		Size = UDim2.new(1, 0, 0, 14),
		Text = "",
	})
	name.ZIndex = 3
	title.ZIndex = 3
	local function refresh()
		local textColor = PlateStyle.apply(plate, player:GetAttribute("Plate"), 2)
		name.TextColor3 = textColor
		title.TextColor3 = textColor
		title.Text = tostring(player:GetAttribute("RankTitle") or "")
	end
	refresh()
	local c1 = player:GetAttributeChangedSignal("Plate"):Connect(refresh)
	local c2 = player:GetAttributeChangedSignal("RankTitle"):Connect(refresh)
	gui.Destroying:Connect(function()
		c1:Disconnect()
		c2:Disconnect()
	end)
end

local function watch(player: Player)
	-- You don't see your own name over your head (the preview is in the Jobs board). Studio QA can
	-- show it with the ReplicatedStorage attribute QA_OwnPlate, for screenshots.
	local qaOwn = RunService:IsStudio() and ReplicatedStorage:GetAttribute("QA_OwnPlate") == true
	if player == Players.LocalPlayer and not qaOwn then
		return
	end
	player.CharacterAdded:Connect(function(character)
		attach(player, character)
	end)
	if player.Character then
		task.spawn(attach, player, player.Character)
	end
end

function Nameplates.init()
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return Nameplates
