-- @file Keeps the camera inside buildings
-- @domain world
-- @status stable
-- Keeps the native camera inside buildings. Roblox's camera only stops at visible, colliding
-- parts; our building walls and roofs are invisible gameplay parts (MapBuilder.building) under
-- non-colliding Blender shells, so in a tight aisle against a wall (the supermarket's freezer
-- row, motel rooms) the camera slid out through the wall and showed the player its outside.
--
-- After the native camera has updated each frame, one raycast from the focus to the camera
-- against just those walls and roofs pulls the camera in front of the first one it crosses.
-- The camera controller, zoom and controls are untouched.

local RunService = game:GetService("RunService")

local CameraOcclusion = {}

local BUILDINGS = {
	"Supermarket",
	"Gas Station",
	"Warehouse",
	"Motel",
	"House 1",
	"House 2",
	"House 3",
	"House 4",
}
local MARGIN = 0.6 -- studs kept between the camera and the wall

function CameraOcclusion.init()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.IgnoreWater = true

	local function collect()
		local map = workspace:FindFirstChild("Map")
		if not map then
			return false
		end
		local list = {}
		for _, name in BUILDINGS do
			local building = map:FindFirstChild(name)
			if building then
				for _, part in building:GetChildren() do
					-- The invisible walls (Floor and the climbing truss excluded).
					if part:IsA("Part") and part.Transparency >= 0.99 and part.CanCollide then
						table.insert(list, part)
					end
				end
			end
		end
		local roofs = map:FindFirstChild("Roofs")
		if roofs then
			for _, part in roofs:GetDescendants() do
				if part:IsA("BasePart") then
					table.insert(list, part)
				end
			end
		end
		params.FilterDescendantsInstances = list
		return #list > 0
	end

	task.spawn(function()
		while not collect() do
			task.wait(2)
		end
		RunService:BindToRenderStep(
			"StormSalvageCameraWalls",
			Enum.RenderPriority.Camera.Value + 1,
			function()
				local camera = workspace.CurrentCamera
				if not camera or camera.CameraType ~= Enum.CameraType.Custom then
					return
				end
				local focus = camera.Focus.Position
				local offset = camera.CFrame.Position - focus
				local distance = offset.Magnitude
				if distance < 1 then
					return
				end
				local hit = workspace:Raycast(focus, offset, params)
				if hit then
					local keep = math.max(0.5, hit.Distance - MARGIN)
					camera.CFrame = camera.CFrame + offset.Unit * (keep - distance)
				end
			end
		)
	end)
end

return CameraOcclusion
