-- Procedurally builds the Storm Salvage town at server start.
-- Layout (north = -Z): raised Scrapyard hub in the north, town below it.
--   Gas Station (NW)   Supermarket (NE)
--   Houses (SW)   Town Square (centre)   Warehouse (SE)
--               Motel (far south)

local CollectionService = game:GetService("CollectionService")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local MapBuilder = {}

local TOWN_HALF = 210 -- town ground is 420x420 centred on origin
local PLATEAU_HEIGHT = 30
local PLATEAU_CENTER = Vector3.new(0, 0, -275)
local PLATEAU_SIZE = Vector3.new(170, PLATEAU_HEIGHT, 110)

local map: Model
local roofs: Folder

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local parent = props.Parent
	props.Parent = nil
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent or map
	return p
end

local function sign(parent: Instance, text: string, color: Color3, offsetY: number, maxDistance: number?)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 50)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = maxDistance or 250
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Parent = gui
	gui.Parent = parent
	return gui
end

-- Wall along X or Z with an optional door gap in the middle.
local function wall(parent: Instance, center: Vector3, length: number, height: number, alongX: boolean, door: boolean, color: Color3, material: Enum.Material)
	local thickness = 1
	local function seg(offset: number, len: number, y: number, h: number)
		local pos = alongX and center + Vector3.new(offset, y, 0) or center + Vector3.new(0, y, offset)
		local size = alongX and Vector3.new(len, h, thickness) or Vector3.new(thickness, h, len)
		part({ Parent = parent, Size = size, Position = pos, Color = color, Material = material })
	end
	if not door then
		seg(0, length, height / 2, height)
		return
	end
	local doorWidth, doorHeight = 8, 9
	local side = (length - doorWidth) / 2
	seg(-(doorWidth / 2 + side / 2), side, height / 2, height)
	seg(doorWidth / 2 + side / 2, side, height / 2, height)
	seg(0, doorWidth, doorHeight + (height - doorHeight) / 2, height - doorHeight)
end

-- Builds a hollow building. Returns interior loot points.
local function building(name: string, center: Vector3, size: Vector3, color: Color3, material: Enum.Material, doorFace: string, roofColor: Color3?, ladder: boolean?): { Vector3 }
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = map

	local w, h, d = size.X, size.Y, size.Z
	part({ Parent = model, Name = "Floor", Size = Vector3.new(w, 1, d), Position = center + Vector3.new(0, 0.5, 0), Color = Color3.fromRGB(120, 105, 90), Material = Enum.Material.WoodPlanks })
	local roof = part({ Parent = roofs, Name = name .. "Roof", Size = Vector3.new(w + 2, 1, d + 2), Position = center + Vector3.new(0, h + 0.5, 0), Color = roofColor or Color3.fromRGB(90, 60, 50), Material = Enum.Material.Slate })
	CollectionService:AddTag(roof, "Shelter")

	wall(model, center + Vector3.new(0, 0, -d / 2), w, h, true, doorFace == "N", color, material)
	wall(model, center + Vector3.new(0, 0, d / 2), w, h, true, doorFace == "S", color, material)
	wall(model, center + Vector3.new(w / 2, 0, 0), d, h, false, doorFace == "E", color, material)
	wall(model, center + Vector3.new(-w / 2, 0, 0), d, h, false, doorFace == "W", color, material)

	-- Windows on the side walls (cosmetic)
	for _, sx in { -1, 1 } do
		part({ Parent = model, Size = Vector3.new(0.3, 3, math.min(8, d / 3)), Position = center + Vector3.new(sx * (w / 2 + 0.5), h * 0.6, 0), Color = Color3.fromRGB(150, 200, 230), Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false })
	end

	if ladder then
		-- Truss on the back wall so players can climb to the roof during floods.
		local backZ = doorFace == "S" and -d / 2 - 2.5 or d / 2 + 2.5
		local truss = Instance.new("TrussPart")
		truss.Anchored = true
		truss.Size = Vector3.new(2, h + 4, 2) -- trusses snap to even sizes; all heights here are even
		truss.Position = center + Vector3.new(w / 2 - 4, (h + 4) / 2, backZ)
		truss.Color = Color3.fromRGB(230, 180, 40)
		truss.Parent = model
	end

	sign(roof, name, Color3.fromRGB(255, 255, 255), 6)

	local points = {}
	local margin = 4
	for x = -w / 2 + margin, w / 2 - margin, 7 do
		for z = -d / 2 + margin, d / 2 - margin, 7 do
			table.insert(points, center + Vector3.new(x, 2.5, z))
		end
	end
	return points
end

local function tree(pos: Vector3)
	part({ Size = Vector3.new(10, 1.6, 1.6), Position = pos + Vector3.new(0, 5, 0), Shape = Enum.PartType.Cylinder, Orientation = Vector3.new(0, 0, 90), Color = Color3.fromRGB(100, 70, 45), Material = Enum.Material.Wood })
	part({ Size = Vector3.new(9, 9, 9), Position = pos + Vector3.new(0, 12, 0), Shape = Enum.PartType.Ball, Color = Color3.fromRGB(60, 140, 60), Material = Enum.Material.Grass, CanCollide = false })
end

local function streetLight(pos: Vector3)
	part({ Size = Vector3.new(0.6, 14, 0.6), Position = pos + Vector3.new(0, 7, 0), Color = Color3.fromRGB(60, 60, 65), Material = Enum.Material.Metal })
	local lamp = part({ Size = Vector3.new(2, 0.8, 2), Position = pos + Vector3.new(0, 14.2, 0), Color = Color3.fromRGB(255, 240, 200), Material = Enum.Material.Neon })
	local light = Instance.new("PointLight")
	light.Range = 24
	light.Brightness = 1.5
	light.Color = Color3.fromRGB(255, 230, 180)
	light.Parent = lamp
end

local function car(pos: Vector3, color: Color3, rotY: number)
	local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(rotY), 0)
	part({ Size = Vector3.new(6, 2.2, 11), CFrame = cf * CFrame.new(0, 1.8, 0), Color = color, Material = Enum.Material.SmoothPlastic })
	part({ Size = Vector3.new(5.6, 2, 5.5), CFrame = cf * CFrame.new(0, 3.9, -0.5), Color = Color3.fromRGB(40, 50, 60), Material = Enum.Material.Glass, Transparency = 0.2 })
	for _, o in { Vector3.new(-3, 0.9, 3.5), Vector3.new(3, 0.9, 3.5), Vector3.new(-3, 0.9, -3.5), Vector3.new(3, 0.9, -3.5) } do
		part({ Size = Vector3.new(1, 1.8, 1.8), CFrame = cf * CFrame.new(o), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(25, 25, 25) })
	end
end

function MapBuilder.build()
	local existing = workspace:FindFirstChild("Map")
	if existing then
		existing:Destroy()
	end
	map = Instance.new("Model")
	map.Name = "Map"
	map.Parent = workspace
	roofs = Instance.new("Folder")
	roofs.Name = "Roofs"
	roofs.Parent = map

	-- Ground, roads, boundary
	part({ Name = "Ground", Size = Vector3.new(TOWN_HALF * 2, 4, TOWN_HALF * 2), Position = Vector3.new(0, -2, 0), Color = Color3.fromRGB(90, 150, 75), Material = Enum.Material.Grass })
	local asphalt = Color3.fromRGB(55, 55, 60)
	part({ Name = "MainRoad", Size = Vector3.new(24, 0.2, TOWN_HALF * 2), Position = Vector3.new(0, 0.1, 0), Color = asphalt, Material = Enum.Material.Asphalt })
	part({ Name = "CrossRoad", Size = Vector3.new(TOWN_HALF * 2, 0.2, 24), Position = Vector3.new(0, 0.1, 10), Color = asphalt, Material = Enum.Material.Asphalt })
	for z = -TOWN_HALF + 10, TOWN_HALF - 10, 20 do
		part({ Size = Vector3.new(0.6, 0.05, 8), Position = Vector3.new(0, 0.22, z), Color = Color3.fromRGB(240, 220, 90), Material = Enum.Material.SmoothPlastic, CanCollide = false })
	end
	for _, info in { { Vector3.new(0, 30, -TOWN_HALF - 130), Vector3.new(TOWN_HALF * 2, 60, 1) }, { Vector3.new(0, 30, TOWN_HALF), Vector3.new(TOWN_HALF * 2, 60, 1) }, { Vector3.new(TOWN_HALF, 30, -65), Vector3.new(1, 60, TOWN_HALF * 2 + 130) }, { Vector3.new(-TOWN_HALF, 30, -65), Vector3.new(1, 60, TOWN_HALF * 2 + 130) } } do
		part({ Name = "Boundary", Position = info[1], Size = info[2], Transparency = 1, CanQuery = false })
	end

	-- Scrapyard plateau (safe hub) + ramp
	local plateauTop = PLATEAU_HEIGHT
	part({ Name = "Plateau", Size = PLATEAU_SIZE, Position = PLATEAU_CENTER + Vector3.new(0, PLATEAU_HEIGHT / 2, 0), Color = Color3.fromRGB(110, 100, 90), Material = Enum.Material.Rock })
	part({ Name = "NorthGround", Size = Vector3.new(TOWN_HALF * 2, 4, 135), Position = Vector3.new(0, -2, -TOWN_HALF - 67.5), Color = Color3.fromRGB(110, 100, 90), Material = Enum.Material.Rock })
	local rampLength = 80
	local rampStartZ = PLATEAU_CENTER.Z + PLATEAU_SIZE.Z / 2 -- plateau front edge
	local ramp = Instance.new("WedgePart")
	ramp.Name = "Ramp"
	ramp.Anchored = true
	ramp.Size = Vector3.new(24, PLATEAU_HEIGHT, rampLength)
	-- A wedge's tall end is at +Z; rotating 180 puts it against the plateau (-Z).
	ramp.CFrame = CFrame.new(0, PLATEAU_HEIGHT / 2, rampStartZ + rampLength / 2) * CFrame.Angles(0, math.rad(180), 0)
	ramp.Color = asphalt
	ramp.Material = Enum.Material.Asphalt
	ramp.Parent = map
	-- Fill under the ramp's sides so nobody gets stuck
	for _, sx in { -1, 1 } do
		part({ Size = Vector3.new(1, 4, rampLength), Position = Vector3.new(sx * 12.5, 0, rampStartZ + rampLength / 2), Transparency = 1 })
	end
	-- Side stairs, a second route up
	for i = 0, PLATEAU_HEIGHT - 1 do
		part({ Name = "Stair", Size = Vector3.new(12, i + 1, 2), Position = Vector3.new(-70, (i + 1) / 2, rampStartZ + 1 + 2 * (PLATEAU_HEIGHT - 1 - i)), Color = Color3.fromRGB(130, 120, 110), Material = Enum.Material.Concrete })
	end

	-- Scrapyard contents
	local yard = Instance.new("Model")
	yard.Name = "Scrapyard"
	yard.Parent = map
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	-- Rotated so players spawn facing south, toward the town and the sell/shop counters.
	spawn.CFrame = CFrame.new(PLATEAU_CENTER + Vector3.new(0, plateauTop + 0.5, -25)) * CFrame.Angles(0, math.pi, 0)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(240, 170, 40)
	spawn.Material = Enum.Material.DiamondPlate
	spawn.Parent = yard

	local sellPart = part({ Parent = yard, Name = "SellCounter", Size = Vector3.new(14, 4, 5), Position = PLATEAU_CENTER + Vector3.new(-25, plateauTop + 2, 15), Color = Color3.fromRGB(60, 170, 80), Material = Enum.Material.DiamondPlate })
	local sellPrompt = Instance.new("ProximityPrompt")
	sellPrompt.Name = "SellPrompt"
	sellPrompt.ActionText = "Sell Salvage"
	sellPrompt.ObjectText = "Scrap Buyer"
	sellPrompt.MaxActivationDistance = 14
	sellPrompt.RequiresLineOfSight = false
	sellPrompt.Parent = sellPart
	sign(sellPart, "SELL HERE", Color3.fromRGB(120, 255, 140), 6, 2000)

	local shopPart = part({ Parent = yard, Name = "UpgradeShop", Size = Vector3.new(14, 4, 5), Position = PLATEAU_CENTER + Vector3.new(25, plateauTop + 2, 15), Color = Color3.fromRGB(60, 120, 200), Material = Enum.Material.DiamondPlate })
	local shopPrompt = Instance.new("ProximityPrompt")
	shopPrompt.Name = "UpgradePrompt"
	shopPrompt.ActionText = "Upgrades"
	shopPrompt.ObjectText = "Gear Shop"
	shopPrompt.MaxActivationDistance = 14
	shopPrompt.RequiresLineOfSight = false
	shopPrompt.Parent = shopPart
	sign(shopPart, "UPGRADES", Color3.fromRGB(140, 200, 255), 6)

	-- Scrap piles + fence for flavour
	local rng = Random.new(7)
	for _ = 1, 30 do
		local px = rng:NextNumber(-80, 80)
		local pz = PLATEAU_CENTER.Z + rng:NextNumber(-50, -30)
		local s = rng:NextNumber(2, 6)
		part({ Parent = yard, Size = Vector3.new(s, s * 0.7, s * 1.2), Position = Vector3.new(px, plateauTop + s * 0.35, pz), Orientation = Vector3.new(rng:NextNumber(-20, 20), rng:NextNumber(0, 360), rng:NextNumber(-20, 20)), Color = Color3.fromHSV(rng:NextNumber(0, 0.12), 0.4, rng:NextNumber(0.3, 0.6)), Material = Enum.Material.CorrodedMetal })
	end
	for x = -80, 80, 8 do
		if math.abs(x) > 14 and math.abs(x + 70) > 10 then
			part({ Parent = yard, Size = Vector3.new(8, 4, 0.4), Position = Vector3.new(x, plateauTop + 2, rampStartZ - 1), Color = Color3.fromRGB(150, 150, 150), Material = Enum.Material.DiamondPlate, Transparency = 0.2 })
		end
	end
	car(PLATEAU_CENTER + Vector3.new(55, plateauTop, 25), Color3.fromRGB(160, 60, 40), 20)

	-- Town buildings
	local zones = {}
	local wallWood = Enum.Material.WoodPlanks
	local brick = Enum.Material.Brick
	local concrete = Enum.Material.Concrete

	local housePoints = {}
	local houseColors = { Color3.fromRGB(230, 200, 150), Color3.fromRGB(170, 200, 220), Color3.fromRGB(220, 160, 160), Color3.fromRGB(200, 220, 170) }
	local housePositions = { Vector3.new(-150, 0, 55), Vector3.new(-95, 0, 55), Vector3.new(-150, 0, 120), Vector3.new(-95, 0, 120) }
	for i, pos in housePositions do
		local pts = building("House " .. i, pos, Vector3.new(30, 12, 28), houseColors[i], wallWood, "N", nil, false)
		for _, p in pts do
			table.insert(housePoints, p)
		end
	end
	zones.Houses = { Points = housePoints, Label = "Houses" }

	zones.Warehouse = { Points = building("Warehouse", Vector3.new(125, 0, 90), Vector3.new(70, 22, 60), Color3.fromRGB(150, 120, 90), concrete, "N", Color3.fromRGB(80, 80, 85), true), Label = "Warehouse" }
	zones.GasStation = { Points = building("Gas Station", Vector3.new(-120, 0, -80), Vector3.new(40, 14, 30), Color3.fromRGB(230, 230, 230), concrete, "S", Color3.fromRGB(200, 40, 40), true), Label = "Gas Station" }
	zones.Supermarket = { Points = building("Supermarket", Vector3.new(120, 0, -80), Vector3.new(70, 18, 50), Color3.fromRGB(200, 180, 140), brick, "S", Color3.fromRGB(60, 120, 60), true), Label = "Supermarket" }
	zones.Motel = { Points = building("Motel", Vector3.new(0, 0, 165), Vector3.new(110, 14, 30), Color3.fromRGB(210, 150, 110), brick, "N", Color3.fromRGB(70, 90, 130), true), Label = "Motel" }

	-- Gas station canopy + pumps + cars
	local canopy = part({ Name = "Canopy", Size = Vector3.new(36, 1, 20), Position = Vector3.new(-120, 12, -45), Color = Color3.fromRGB(200, 40, 40), Material = Enum.Material.Metal })
	canopy.Parent = roofs
	CollectionService:AddTag(canopy, "Shelter")
	for _, x in { -135, -105 } do
		part({ Size = Vector3.new(1, 12, 1), Position = Vector3.new(x, 6, -45), Color = Color3.fromRGB(220, 220, 220), Material = Enum.Material.Metal })
		part({ Size = Vector3.new(2, 4, 1.5), Position = Vector3.new(x + 7, 2, -45), Color = Color3.fromRGB(240, 200, 40), Material = Enum.Material.SmoothPlastic })
	end
	car(Vector3.new(-150, 0, -15), Color3.fromRGB(40, 90, 160), 90)
	car(Vector3.new(-170, 0, -120), Color3.fromRGB(220, 200, 60), 10)
	car(Vector3.new(70, 0, -30), Color3.fromRGB(200, 60, 60), 75)
	car(Vector3.new(160, 0, 140), Color3.fromRGB(80, 80, 80), 0)

	-- Supermarket shelves (against side walls, outside the loot grid)
	for _, sx in { -1, 1 } do
		part({ Size = Vector3.new(2, 6, 40), Position = Vector3.new(120 + sx * 32.5, 4, -80), Color = Color3.fromRGB(220, 220, 220), Material = Enum.Material.Metal })
	end

	-- Town square: open plaza with a fountain (no shelter = risky)
	part({ Name = "Plaza", Size = Vector3.new(60, 0.4, 60), Position = Vector3.new(-50, 0.2, -55), Color = Color3.fromRGB(190, 180, 165), Material = Enum.Material.Cobblestone })
	part({ Name = "Fountain", Size = Vector3.new(3, 14, 14), Position = Vector3.new(-50, 1.5, -55), Shape = Enum.PartType.Cylinder, Orientation = Vector3.new(0, 0, 90), Color = Color3.fromRGB(160, 160, 170), Material = Enum.Material.Marble })
	local fountainWater = part({ Size = Vector3.new(1, 12, 12), Position = Vector3.new(-50, 3.2, -55), Shape = Enum.PartType.Cylinder, Orientation = Vector3.new(0, 0, 90), Color = Color3.fromRGB(80, 160, 230), Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false })
	sign(fountainWater, "Town Square", Color3.fromRGB(255, 255, 255), 8)
	local squarePoints = {}
	for x = -75, -25, 10 do
		for z = -80, -30, 10 do
			if (Vector3.new(x, 0, z) - Vector3.new(-50, 0, -55)).Magnitude > 12 then
				table.insert(squarePoints, Vector3.new(x, 2.5, z))
			end
		end
	end
	zones.TownSquare = { Points = squarePoints, Label = "Town Square" }

	-- Dressing
	for _, pos in { Vector3.new(-30, 0, 60), Vector3.new(30, 0, 60), Vector3.new(-30, 0, 130), Vector3.new(40, 0, 120), Vector3.new(-185, 0, -150), Vector3.new(185, 0, -150), Vector3.new(-185, 0, 185), Vector3.new(185, 0, 185), Vector3.new(-90, 0, -150), Vector3.new(80, 0, -160), Vector3.new(-20, 0, -110), Vector3.new(30, 0, -120) } do
		tree(pos)
	end
	for z = -135, 90, 45 do
		streetLight(Vector3.new(14, 0, z))
		streetLight(Vector3.new(-14, 0, z + 22))
	end

	return {
		Zones = zones,
		Roofs = roofs,
		SellPrompt = sellPrompt,
		SpawnPosition = spawn.Position,
		TownMin = Vector3.new(-TOWN_HALF + 5, 0, -TOWN_HALF + 5),
		TownMax = Vector3.new(TOWN_HALF - 5, 0, TOWN_HALF - 5),
		FloodMaxY = 12,
		SafeZoneZ = Config.SafeZoneMaxZ, -- plateau front edge is at rampStartZ (-220)
	}
end

return MapBuilder
