-- @file Salvage Detector dial on the HUD
-- @domain salvage-economy
-- @status stable
-- @see [[DetectorService.luau]]
-- @see [[Tools.luau]]
-- The Salvage Detector's dial: a small round gauge (Workshop instrument) in the lower right,
-- shown only to players who own the detector. Up on the dial is where the camera faces; the
-- centre is you; blips are the nearest ordinary salvage the server sent (DetectorPing), placed
-- by direction and distance and turned with the camera every frame. The readout under it says
-- how far the nearest one is. It draws only what the server sent: the server decides what the
-- detector may reveal (shared/Detector).
-- Reduced Effects: no sweeping needle and no blip pulse.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage.Shared:WaitForChild("Remotes"))
local UI = require(script.Parent:WaitForChild("UI"))

local DetectorHud = {}
local M = UI.Mat

local RANGE = Config.Tools.Detector.Range
local FACE = Color3.fromRGB(38, 50, 44)
local GLOW = Color3.fromRGB(150, 230, 160)

local holder: Frame
local dial: Frame
local needle: Frame
local readout: TextLabel
local blipFrames: { Frame } = {}
local targets: { { X: number, Z: number } } = {}
local owned = false

local function makeBlip(): Frame
	local blip = UI.new("Frame", {
		Name = "Blip",
		Parent = dial,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = M.Orange,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 7,
	}, { UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), UI.stroke(Color3.new(0, 0, 0), 1.5) })
	table.insert(blipFrames, blip)
	return blip
end

local function step()
	if not owned then
		return
	end
	local player = Players.LocalPlayer
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local camera = workspace.CurrentCamera
	if not root or not camera then
		holder.Visible = false
		return
	end
	holder.Visible = true
	-- Camera heading on the ground plane: dial "up" is where you look.
	local look = camera.CFrame.LookVector
	local heading = math.atan2(-look.X, -look.Z)
	local cosH, sinH = math.cos(heading), math.sin(heading)
	local nearest: number? = nil
	for i, t in targets do
		local blip = blipFrames[i] or makeBlip()
		local dx, dz = t.X - root.Position.X, t.Z - root.Position.Z
		local d = math.sqrt(dx * dx + dz * dz)
		if d > RANGE + 6 then
			blip.Visible = false
		else
			-- Rotate the world offset into camera space (x right, y forward).
			local right = dx * cosH - dz * sinH
			local forward = -(dx * sinH + dz * cosH)
			local r = math.min(d / RANGE, 1) * 0.42
			local len = math.max(d, 0.001)
			blip.Position = UDim2.fromScale(0.5 + right / len * r, 0.5 - forward / len * r)
			blip.Visible = true
			nearest = if nearest then math.min(nearest, d) else d
		end
	end
	for i = #targets + 1, #blipFrames do
		blipFrames[i].Visible = false
	end
	readout.Text = if nearest then ("SALVAGE %dm"):format(math.floor(nearest + 0.5)) else "NOTHING NEAR"
	readout.TextColor3 = if nearest then GLOW else Color3.fromRGB(170, 170, 160)
	if not UI.reduced() then
		needle.Rotation = (os.clock() * 120) % 360
		needle.Visible = true
	else
		needle.Visible = false
	end
end

function DetectorHud.setState(s: any)
	local tools = s and s.Tools
	local now = tools ~= nil and type(tools.Owned) == "table" and tools.Owned.Detector == true
	if now ~= owned then
		owned = now
		holder.Visible = now
	end
end

local function layout(compact: boolean)
	-- Desktop: lower right corner. Phone: bottom centre-right, clear of the thumbstick (left 40%)
	-- and the jump button (lower right).
	if compact then
		holder.AnchorPoint = Vector2.new(0.5, 1)
		holder.Position = UDim2.new(0.62, 0, 1, -8)
		holder.Size = UDim2.fromOffset(96, 118)
	else
		holder.AnchorPoint = Vector2.new(1, 1)
		holder.Position = UDim2.new(1, -20, 1, -20)
		holder.Size = UDim2.fromOffset(128, 152)
	end
end

function DetectorHud.init(root: Frame, onLayout: ((boolean) -> ()) -> ())
	holder = UI.new("Frame", {
		Name = "Detector",
		Parent = root,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 5,
	})
	dial = UI.new("Frame", {
		Name = "Dial",
		Parent = holder,
		Size = UDim2.new(1, 0, 1, -24),
		BackgroundColor3 = FACE,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, {
		UI.new("UIAspectRatioConstraint", { AspectRatio = 1 }),
		UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		UI.stroke(Color3.fromRGB(176, 140, 72), 5),
	})
	-- Range rings and the "you" dot.
	for _, f in { 0.84, 0.42 } do
		UI.new("Frame", {
			Parent = dial,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(f, f),
			BackgroundTransparency = 1,
			ZIndex = 6,
		}, {
			UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			UI.stroke(Color3.fromRGB(70, 96, 82), 1.5),
		})
	end
	UI.new("Frame", {
		Parent = dial,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = GLOW,
		BorderSizePixel = 0,
		ZIndex = 8,
	}, { UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	-- Facing tick at the top.
	UI.new("Frame", {
		Parent = dial,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.04),
		Size = UDim2.fromOffset(3, 9),
		BackgroundColor3 = GLOW,
		BorderSizePixel = 0,
		ZIndex = 6,
	})
	-- Sweep: a thin line from the centre, rotating (not in Reduced Effects).
	needle = UI.new("Frame", {
		Name = "Sweep",
		Parent = dial,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.84, 0.84),
		BackgroundTransparency = 1,
		ZIndex = 6,
	})
	UI.new("Frame", {
		Parent = needle,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 2, 0.5, 0),
		BackgroundColor3 = GLOW,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		ZIndex = 6,
	})
	readout = UI.text({
		Name = "Readout",
		Parent = holder,
		Font = UI.Font.Mono,
		TextSize = 13,
		Outline = true,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 20, 0, 20),
		TextColor3 = GLOW,
		Text = "",
		ZIndex = 6,
	})
	onLayout(layout)

	Remotes.get("DetectorPing").OnClientEvent:Connect(function(list)
		targets = {}
		if type(list) ~= "table" then
			return
		end
		for _, t in list do
			if type(t) == "table" and type(t.X) == "number" and type(t.Z) == "number" then
				table.insert(targets, { X = t.X, Z = t.Z })
			end
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return DetectorHud
