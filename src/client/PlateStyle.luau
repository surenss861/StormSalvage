-- @file Nameplate finish materials
-- @domain progression
-- @status stable
-- @see [[V3-PROGRESSION]]
-- How each nameplate finish looks: a material, not just a colour. Used by the overhead
-- nameplates (Nameplates.luau) and the locker previews (Jobs.luau), so what you buy is exactly
-- what other players see.
--   Cardboard   kraft with a masking-tape corner
--   Tin         galvanised grey with four rivets
--   Brass       polished gold sheen
--   Hazard      yellow with black chevron stripes
--   Copper      copper going green at the edges (patina)
--   Chrome      mirror sheen with a bright highlight band
--   StormGlass  dark glass, cyan glow edge, a lightning bolt

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Progression = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Progression"))
local UI = require(script.Parent:WaitForChild("UI"))

local PlateStyle = {}

local function rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function gradient(parent: Instance, keys: { { number } }, rotation: number)
	local points = {}
	for _, k in keys do
		table.insert(points, ColorSequenceKeypoint.new(k[1], Color3.fromRGB(k[2], k[3], k[4])))
	end
	UI.new("UIGradient", { Parent = parent, Color = ColorSequence.new(points), Rotation = rotation })
end

-- Dresses `plate` (a Frame) in finish `id`. Detail goes in a holder that clips to the plate and
-- sits under the text (`z` is the plate's ZIndex). Returns the finish's text colour.
function PlateStyle.apply(plate: Frame, id: unknown, z: number): Color3
	local f = Progression.finish(id) or Progression.Finishes[1]
	for _, c in plate:GetChildren() do
		if c.Name == "Finish" or c:IsA("UIGradient") then
			c:Destroy()
		end
	end
	plate.BackgroundColor3 = rgb(f.Plate)
	plate.ClipsDescendants = true
	local stroke = plate:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = rgb(f.Edge)
		stroke.Thickness = if f.Id == "StormGlass" then 4 else 3
	end
	local detail = UI.new("Frame", {
		Name = "Finish",
		Parent = plate,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = z,
	})
	local function bit(props: { [string]: any }): Frame
		props.Parent = detail
		props.BorderSizePixel = 0
		props.ZIndex = z
		return UI.new("Frame", props)
	end
	if f.Id == "Cardboard" then
		bit({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(6, 4),
			Size = UDim2.fromOffset(30, 10),
			Rotation = -35,
			BackgroundColor3 = UI.Mat.Tape,
			BackgroundTransparency = 0.15,
		})
	elseif f.Id == "Tin" then
		for _, at in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
			bit({
				AnchorPoint = at,
				Position = UDim2.new(at.X, if at.X == 0 then 4 else -4, at.Y, if at.Y == 0 then 4 else -4),
				Size = UDim2.fromOffset(5, 5),
				BackgroundColor3 = rgb(f.Edge),
			})
		end
		gradient(plate, { { 0, 214, 220, 224 }, { 1, 168, 174, 178 } }, 100)
	elseif f.Id == "Brass" then
		gradient(
			plate,
			{ { 0, 170, 120, 40 }, { 0.45, 250, 214, 120 }, { 0.55, 255, 236, 170 }, { 1, 176, 128, 46 } },
			20
		)
	elseif f.Id == "Hazard" then
		for i = -2, 12 do
			bit({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0, i * 18, 0.5, 0),
				Size = UDim2.new(0, 7, 2, 0),
				Rotation = 35,
				BackgroundColor3 = Color3.fromRGB(28, 28, 28),
				BackgroundTransparency = 0.15,
			})
		end
		-- A solid band behind the text keeps the name readable over the stripes.
		bit({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -16, 1, -10),
			BackgroundColor3 = rgb(f.Plate),
		})
	elseif f.Id == "Copper" then
		gradient(
			plate,
			{ { 0, 90, 168, 150 }, { 0.3, 190, 110, 64 }, { 0.7, 214, 130, 80 }, { 1, 90, 168, 150 } },
			0
		)
	elseif f.Id == "Chrome" then
		gradient(plate, {
			{ 0, 150, 160, 175 },
			{ 0.42, 245, 248, 252 },
			{ 0.5, 255, 255, 255 },
			{ 0.58, 220, 228, 236 },
			{ 1, 130, 140, 156 },
		}, 70)
	elseif f.Id == "StormGlass" then
		gradient(plate, { { 0, 20, 40, 80 }, { 0.5, 46, 84, 140 }, { 1, 20, 40, 80 } }, 90)
		for i, pt in { { 0.86, 0.15, 0.78, 0.55 }, { 0.78, 0.55, 0.9, 0.55 }, { 0.9, 0.55, 0.82, 0.92 } } do
			local a, b = Vector2.new(pt[1], pt[2]), Vector2.new(pt[3], pt[4])
			local mid = (a + b) / 2
			bit({
				Name = "Bolt" .. i,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(mid.X, mid.Y),
				Size = UDim2.new(0, 3, (b - a).Magnitude, 0),
				Rotation = math.deg(math.atan2(b.X - a.X, -(b.Y - a.Y))),
				BackgroundColor3 = Color3.fromRGB(150, 235, 255),
			})
		end
	end
	return rgb(f.Text)
end

return PlateStyle
