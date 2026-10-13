-- @file Starlite Motel district (V3 C5)
-- @domain world
-- @status stable
-- @see [[V3-C5-MOTEL]]
-- V3 Milestone C5: the Starlite Motel (far south). Turns the V2 single dormitory hall into six
-- rooms and an office along a front corridor, each room with its own storm story, and finishes the
-- walkway outside. See docs/art/V3-C5-MOTEL.md.
--
-- Gameplay stays where MapBuilder put it: the invisible 110 x 30 x 14 walls and roof (shelter),
-- the walkway awning (shelter), the central door, the back truss (roof escape) and the 15 x 3
-- loot grid (z 155 / 162 / 169). Partition walls stand between loot columns and stop 8 studs
-- short of the front wall, so every room opens onto the corridor; furniture sits in the back
-- 7 studs where there is no loot. Everything comes from ServerStorage.Assets.v3motel; without it
-- the V2 motel stays as is.

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local Palette = require(game:GetService("ReplicatedStorage").Shared.Palette)

local DistrictMotel = {}

local S = Palette.Swatches
local FLOOR = 1
local BACK = 179.5 -- inner face of the back wall
local PARTITIONS = { -39.5, -25.5, -11.5, 9.5, 23.5, 37.5 }

type Room = { number: string, x0: number, x1: number, kind: string, blanket: Color3? }
local ROOMS: { Room } = {
	{ number = "101", x0 = -54.5, x1 = -39.5, kind = "intact", blanket = S.Coral },
	{ number = "102", x0 = -39.5, x1 = -25.5, kind = "leak" },
	{ number = "103", x0 = -25.5, x1 = -11.5, kind = "hurry", blanket = S.Cobalt },
	{ number = "104", x0 = 9.5, x1 = 23.5, kind = "flooded", blanket = S.Sand },
	{ number = "105", x0 = 23.5, x1 = 37.5, kind = "intact", blanket = S.Teal },
	{ number = "106", x0 = 37.5, x1 = 54.5, kind = "storage" },
}

-- Only big surfaces cast shadows inside.
local SHADOW_KEEP: { [string]: { [string]: boolean } } = {
	RoomPartition = { Smooth__Plaster = true },
	MotelBed = { Planks__Bark = true },
	BedStripped = { Planks__Bark = true },
	FrontDesk = { Planks__Teal = true },
}

type Context = {
	Map: Model,
	Part: (props: { [string]: any }) -> Part,
	Prop: (props: { [string]: any }) -> Part,
	SurfaceSign: (
		target: BasePart,
		face: Enum.NormalId,
		text: string,
		color: Color3,
		font: Enum.Font?
	) -> any,
}

local function source(set: string, name: string): Model?
	local assets = ServerStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild(set)
	local model = folder and folder:FindFirstChild(name)
	return if model and model:IsA("Model") then model else nil
end

local function place(set: string, name: string, cf: CFrame, parent: Instance): Model?
	local src = source(set, name)
	if not src then
		return nil
	end
	local model = src:Clone()
	model:PivotTo(cf)
	model.Parent = parent
	return model
end

local function meshWith(model: Model?, key: string): BasePart?
	if not model then
		return nil
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and string.find(d.Name, key, 1, true) then
			return d
		end
	end
	return nil
end

local function tagLamps(model: Model?)
	if not model then
		return
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
			d:SetAttribute("OnColor", d.Color)
			CollectionService:AddTag(d, "V3Lamp")
		end
	end
end

local function recolor(model: Model?, swatch: string, color: Color3?)
	if not model or not color then
		return
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and string.match(d.Name, "__" .. swatch .. "$") then
			d.Color = color
		end
	end
end

-- Facing the corridor / the front (-Z) from a point on the back band.
local function front(x: number, z: number, y: number?): CFrame
	local p = Vector3.new(x, y or FLOOR, z)
	return CFrame.lookAt(p, p + Vector3.new(0, 0, -1))
end

local function flat(
	ctx: Context,
	parent: Instance,
	size: Vector3,
	pos: Vector3,
	color: Color3,
	material: Enum.Material?
)
	return ctx.Prop({
		Parent = parent,
		Size = size,
		Position = pos,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		CanCollide = false,
		CastShadow = false,
	})
end

local function furnish(room: Room, ctx: Context, folder: Instance)
	local cx = (room.x0 + room.x1) / 2
	local kind = room.kind
	if kind == "leak" then
		place("v3motel", "BedStripped", front(cx + 1.5, BACK - 0.2), folder)
		-- Ceiling stain and a dangling tile over the bed, a bucket on the floor.
		flat(ctx, folder, Vector3.new(4.5, 0.06, 4.5), Vector3.new(cx + 0.5, 13.9, 175), S.Bark)
		flat(
			ctx,
			folder,
			Vector3.new(2.4, 0.15, 2.4),
			Vector3.new(cx - 1.5, 12.8, 174.5),
			Color3.fromRGB(176, 160, 132)
		).CFrame *= CFrame.Angles(
			math.rad(35),
			0,
			math.rad(10)
		)
		ctx.Prop({
			Parent = folder,
			Name = "Bucket",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.1, 1.3, 1.3),
			CFrame = CFrame.new(cx - 2.6, FLOOR + 0.55, 174) * CFrame.Angles(0, 0, math.rad(90)),
			Color = S.Cobalt,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
	elseif kind == "hurry" then
		local bed = place("v3motel", "MotelBed", front(cx + 1.5, BACK - 0.2), folder)
		recolor(bed, "Coral", room.blanket)
		tagLamps(place("v3motel", "Nightstand", front(cx + 5.5, BACK - 1.2), folder))
		place("v3motel", "OpenSuitcase", front(cx - 3.6, 174.6) * CFrame.Angles(0, math.rad(20), 0), folder)
		place("v3motel", "LuggagePile", front(cx - 4.8, BACK - 1.5), folder)
	elseif kind == "flooded" then
		local bed = place("v3motel", "MotelBed", front(cx + 1.5, BACK - 0.2), folder)
		recolor(bed, "Coral", room.blanket)
		recolor(bed, "White", Color3.fromRGB(190, 176, 150))
		place(
			"v3motel",
			"Armchair",
			front(cx - 3.8, 174.8, FLOOR + 1.2) * CFrame.Angles(math.rad(-90), math.rad(25), 0),
			folder
		)
		-- Water line on the three walls of the room and mud on the floor.
		local line = Color3.fromRGB(96, 82, 64)
		for _, x in { room.x0 + 0.47, room.x1 - 0.47 } do
			flat(ctx, folder, Vector3.new(0.05, 0.3, 21.4), Vector3.new(x, 3.4, BACK - 10.7), line)
		end
		flat(ctx, folder, Vector3.new(room.x1 - room.x0, 0.3, 0.05), Vector3.new(cx, 3.4, BACK - 0.03), line)
		for _, info in { { -2, 166, 5 }, { 3, 158, 4 }, { -4, 174, 3 } } do
			flat(
				ctx,
				folder,
				Vector3.new(info[3], 0.05, info[3] * 0.7),
				Vector3.new(cx + info[1], FLOOR + 0.03, info[2]),
				line,
				Enum.Material.Mud
			)
		end
	elseif kind == "storage" then
		place("v3motel", "BedStripped", front(cx + 2.5, BACK - 0.2), folder)
		place(
			"v3motel",
			"LuggagePile",
			front(cx - 3.5, BACK - 1.5) * CFrame.Angles(0, math.rad(-15), 0),
			folder
		)
		place(
			"v3motel",
			"LuggagePile",
			front(cx - 6.4, BACK - 1.6) * CFrame.Angles(0, math.rad(10), 0),
			folder
		)
	else -- intact
		local bed = place("v3motel", "MotelBed", front(cx + 1.5, BACK - 0.2), folder)
		recolor(bed, "Coral", room.blanket)
		tagLamps(place("v3motel", "Nightstand", front(cx + 5.5, BACK - 1.2), folder))
		place("v3motel", "DresserTV", front(cx - 4.0, BACK - 1.0), folder)
		place("v3motel", "Armchair", front(cx - 4.4, 174.2) * CFrame.Angles(0, math.rad(-30), 0), folder)
	end
end

function DistrictMotel.build(ctx: Context)
	if not source("v3motel", "RoomPartition") then
		return -- assets not imported yet: the V2 motel stays
	end
	local t0 = os.clock()
	local map = ctx.Map
	local folder = Instance.new("Folder")
	folder.Name = "V3Motel"
	folder.Parent = map

	-- The V2 dormitory furniture goes; the rooms get their own.
	for _, d in map:GetChildren() do
		if d:IsA("Model") and (d.Name == "Bed" or d.Name == "MotelDresser" or d.Name == "BathroomSink") then
			local p = d:GetPivot().Position
			if math.abs(p.X) < 56 and p.Z > 150 and p.Z < 181 then
				d:Destroy()
			end
		end
	end

	-- Carpet instead of the wood planks (same part, collision unchanged).
	local motel = map:FindFirstChild("Motel")
	local floor = motel and motel:FindFirstChild("Floor")
	if floor and floor:IsA("BasePart") then
		floor.Material = Enum.Material.Fabric
		floor.Color = Color3.fromRGB(122, 84, 78)
	end

	-- Partitions: one solid invisible wall each, meshes don't collide.
	for _, x in PARTITIONS do
		local wall = place("v3motel", "RoomPartition", front(x, BACK), folder)
		if wall then
			for _, d in wall:GetDescendants() do
				if d:IsA("BasePart") then
					d.CanCollide = false
				end
			end
		end
		ctx.Part({
			Parent = folder,
			Name = "PartitionCollider",
			Size = Vector3.new(0.9, 13, 21.5),
			Position = Vector3.new(x, FLOOR + 6.5, BACK - 10.75),
			Transparency = 1,
			CastShadow = false,
		})
	end

	-- Rooms: number boards over the openings, a light each, the room's story.
	for _, room in ROOMS do
		local cx = (room.x0 + room.x1) / 2
		local sign = place("v3market", "AisleSign", front(cx, 158.6, 11.2), folder)
		local board = meshWith(sign, "Signboard")
		if board then
			ctx.SurfaceSign(
				board,
				Enum.NormalId.Front,
				"ROOM " .. room.number,
				S.Cream,
				Enum.Font.LuckiestGuy
			)
		end
		local fixture = place("v3market", "CeilingLight", CFrame.new(cx, 13.2, 170), folder)
		if fixture then
			local tube = meshWith(fixture, "Neon")
			if tube then
				tube.Color = Color3.fromRGB(196, 184, 160)
			end
			tagLamps(fixture)
		end
		furnish(room, ctx, folder)
	end

	-- Office: front desk at the back of the lobby, facing the door.
	local desk = place("v3motel", "FrontDesk", front(-1, 174.6), folder)
	local box = meshWith(desk, "Signboard")
	if box then
		ctx.SurfaceSign(box, Enum.NormalId.Front, "NO VACANCY", S.NeonPink, Enum.Font.LuckiestGuy)
	end
	local lobbyLight = place("v3market", "CeilingLight", CFrame.new(-1, 13.2, 165), folder)
	if lobbyLight then
		tagLamps(lobbyLight)
		local tube = meshWith(lobbyLight, "Neon")
		if tube then
			tube.Color = Color3.fromRGB(196, 184, 160)
			local light = Instance.new("PointLight")
			light.Range = 26
			light.Brightness = 0.6
			light.Color = Color3.fromRGB(255, 220, 170)
			light.Shadows = false
			light.Parent = tube
		end
	end

	-- Walkway: a wall light by every room door, storm shutters on three windows.
	for _, x in { -48, -36, -24, -12, 12, 24, 36, 48 } do
		tagLamps(place("v3motel", "WallSconce", front(x + 0.3, 149.2, 7.6), folder))
	end
	for _, info in { { -32.8, "CLOSED" }, { 15.2, "BACK SOON" }, { 39.2, "CLOSED" } } do
		local shutter = place("v3motel", "StormShutter", front(info[1], 148.95, 3.1), folder)
		local mark = meshWith(shutter, "Signboard")
		if mark then
			mark.Color = S.Sand
			ctx.SurfaceSign(mark, Enum.NormalId.Front, info[2], S.Coral, Enum.Font.PermanentMarker)
		end
	end

	-- Parking: two guests' cars nose-in to the walkway.
	for _, info in { { Vector3.new(-45, 0, 133), S.Mustard }, { Vector3.new(38, 0, 134), S.Mint } } do
		local car = place("v3houses", "Sedan", CFrame.lookAt(info[1], info[1] + Vector3.new(0, 0, 1)), folder)
		if car then
			for _, d in car:GetDescendants() do
				if d:IsA("BasePart") then
					if string.match(d.Name, "__Coral$") and d.Material ~= Enum.Material.Neon then
						d.Color = info[2]
					elseif string.match(d.Name, "__Bark$") or string.match(d.Name, "__Leaf$") then
						d:Destroy()
					end
				end
			end
		end
	end

	-- Shadow pass inside the building.
	for _, model in folder:GetChildren() do
		if model:IsA("Model") then
			local p = model:GetPivot().Position
			if math.abs(p.X) < 55 and p.Z > 150 and p.Z < 180 then
				local keep = SHADOW_KEEP[model.Name] or {}
				for _, d in model:GetDescendants() do
					if d:IsA("BasePart") then
						local suffix = string.match(d.Name, "__(%w+__%w+)$")
						d.CastShadow = suffix ~= nil and keep[suffix] == true
					end
				end
			end
		end
	end

	map:SetAttribute("C5MotelBuildMs", math.floor((os.clock() - t0) * 1000))
end

return DistrictMotel
