-- Reward feedback for the salvage loop: pickups, rare finds, a full bag, Storm Cores, and the
-- sale receipt. Everything shown here comes from the server (Pickup and SaleReceipt events
-- and the player state); nothing is computed or granted on the client.
--
--   Every pickup: "Mini Safe · 90" rising from where the item was. That's what it will sell
--     for, not money yet, so it isn't gold and has no "+". Uncommon adds a few sparks.
--   Rare / Epic / Legendary: also a graded find tag, its own chime, and sparkles.
--   Bag full: a card telling you to go sell (waits behind a find card instead of hiding it).
--   Storm Cores: a light column and label over every core in town.
--   Sale: the Scrap Buyer's clipboard tally; the total counts up to the server's exact payout.
-- Cards go through Notifications, which decides what shows when.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Audio = require(script.Parent:WaitForChild("Audio"))
local Notifications = require(script.Parent:WaitForChild("Notifications"))
local UI = require(script.Parent:WaitForChild("UI"))

local SalvageFeedback = {}

local effects: Folder
local RANK = { Common = 0, Uncommon = 1, Rare = 2, Epic = 3, Legendary = 4 }
local TAG = { Rare = "RARE FIND", Epic = "EPIC FIND!", Legendary = "LEGENDARY!" }
local FIND_SOUND = { Rare = "FindRare", Epic = "FindEpic", Legendary = "FindCore" }

local function line(parent: Instance, y: number, height: number, props: { [string]: any }): TextLabel
	props.Parent = parent
	props.Position = props.Position or UDim2.fromOffset(0, y)
	props.Size = props.Size or UDim2.new(1, 0, 0, height)
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextTruncate = Enum.TextTruncate.AtEnd
	return UI.text(props)
end

---------------------------------------------------------------------------- Pickups

-- "Name · 90 value" rising out of the spot the item was taken from.
local function worldPop(position: Vector3, text: string, color: Color3, big: boolean)
	local anchor = UI.new("Part", {
		Parent = effects,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.one,
		Position = position + Vector3.new(0, 2, 0),
	})
	local gui = UI.new("BillboardGui", {
		Parent = anchor,
		Size = UDim2.fromOffset(if big then 240 else 190, if big then 30 else 24),
		LightInfluence = 0,
		MaxDistance = 120,
	})
	local label = UI.text({
		Parent = gui,
		Font = UI.Font.Mono,
		TextSize = if big then 22 else 17,
		Outline = true,
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextColor3 = color,
	})
	UI.tween(
		gui,
		1.1,
		{ StudsOffset = Vector3.new(0, if UI.reduced() then 1 else 3, 0) },
		Enum.EasingStyle.Quad
	)
	task.delay(0.7, function()
		UI.tween(label, 0.4, { TextTransparency = 1 }, Enum.EasingStyle.Linear)
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			UI.tween(stroke, 0.4, { Transparency = 1 }, Enum.EasingStyle.Linear)
		end
	end)
	Debris:AddItem(anchor, 1.2)
end

local function sparkleBurst(position: Vector3, color: Color3, amount: number)
	local attachment = UI.new("Attachment", { Parent = workspace.Terrain, WorldPosition = position })
	local emitter = UI.new("ParticleEmitter", {
		Parent = attachment,
		Enabled = false,
		Rate = 0,
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(8, 16),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -12, 0),
		Size = NumberSequence.new(0.35, 0),
		Color = ColorSequence.new(color),
		LightEmission = 1,
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
	})
	emitter:Emit(if UI.reduced() then math.ceil(amount / 3) else amount)
	Debris:AddItem(attachment, 1.2)
end

local M = UI.Mat

local function bagFullCard()
	Notifications.card({
		Priority = 1,
		Accent = UI.Color.Danger,
		Height = 70,
		Seconds = 3,
		Surface = "Note",
		Build = function(card)
			line(
				card,
				14,
				22,
				{ Font = UI.Font.Mono, TextSize = 19, Text = "BAG FULL!", TextColor3 = M.RedPen }
			)
			line(card, 38, 18, {
				Font = UI.Font.Label,
				TextSize = 14,
				Text = "Sell at the Scrap Buyer on the hill",
				TextColor3 = M.Marker,
			})
		end,
	})
end

-- A rubber stamp that thumps onto a card (appears in place with Reduced Effects).
local function stamp(
	parent: Instance,
	text: string,
	color: Color3,
	pos: UDim2,
	size: Vector2,
	rotation: number
)
	local frame = UI.new("Frame", {
		Name = "Stamp",
		Parent = parent,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos,
		Size = UDim2.fromOffset(size.X, size.Y),
		Rotation = rotation,
		BackgroundTransparency = 1,
		ZIndex = 9,
	}, { UI.corner(5), UI.stroke(color, 3) })
	UI.text({
		Parent = frame,
		Font = UI.Font.Mono,
		TextSize = math.floor(size.Y * 0.6),
		Size = UDim2.fromScale(1, 1),
		TextColor3 = color,
		Text = text,
		ZIndex = 9,
	})
	local scale = UI.new("UIScale", { Parent = frame })
	if not UI.reduced() then
		scale.Scale = 1.9
		frame.Visible = false
		task.delay(0.25, function()
			frame.Visible = true
			UI.tween(scale, 0.14, { Scale = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end)
	end
	return frame
end

-- Called with the player's state right after a pickup (carried count is already updated).
-- Common: a light value pop. Uncommon: green pop and a few sparks. Rare and up: a manila tag
-- graded with tape in the rarity colour; Epic adds a stamp, Storm Cores a gold star and the
-- delivery reminder. Tags sit at the side of the screen so they never cover storm hazards.
function SalvageFeedback.onPickup(info: { Id: string, Position: Vector3 }, carried: number, capacity: number)
	local def = Config.Loot[info.Id]
	if not def then
		return
	end
	local rank = RANK[def.Rarity] or 0
	local color = Config.RarityColors[def.Rarity]
	worldPop(info.Position, ("%s · %d"):format(def.Name, def.Value), color, rank >= 1)
	Audio.play("Pickup", 1, 1 + rank * 0.05)
	if rank == 1 then
		sparkleBurst(info.Position + Vector3.new(0, 1.5, 0), color, 6)
	end
	if rank >= 2 then
		Audio.play(FIND_SOUND[def.Rarity])
		sparkleBurst(info.Position + Vector3.new(0, 1.5, 0), color, 8 + rank * 8)
		local isCore = info.Id == "StormCore"
		Notifications.card({
			Priority = rank,
			Accent = color,
			Height = if isCore then 132 else 112,
			Width = 270,
			Seconds = 2.2 + rank * 0.5,
			Surface = "Tag",
			Build = function(card)
				local grade = line(card, 8, 26, {
					Font = UI.Font.Mono,
					TextSize = 16,
					Position = UDim2.fromOffset(24, 8),
					Size = UDim2.new(1, -34, 0, 26),
					Rotation = -1,
					Text = if isCore then "STORM CORE!" else TAG[def.Rarity],
					TextColor3 = if rank >= 4 then M.Marker else Color3.new(1, 1, 1),
					ZIndex = 7,
				})
				grade.TextXAlignment = Enum.TextXAlignment.Center
				line(card, 42, 30, {
					Font = UI.Font.Title,
					TextSize = 25,
					Text = def.Name,
					TextColor3 = M.Marker,
					ZIndex = 7,
				})
				line(card, 74, 18, {
					Font = UI.Font.Mono,
					TextSize = 16,
					Text = ("WORTH %d"):format(def.Value),
					TextColor3 = color:Lerp(M.Marker, 0.45),
					ZIndex = 7,
				})
				line(card, 94, 16, {
					Font = UI.Font.Label,
					TextSize = 13,
					Text = ("Bag %d/%d"):format(carried, capacity),
					TextColor3 = M.Pencil,
					ZIndex = 7,
				})
				if isCore then
					line(card, 110, 16, {
						Font = UI.Font.Label,
						TextSize = 13,
						Text = "Get it to the Scrap Buyer alive!",
						TextColor3 = M.RedPen,
						ZIndex = 7,
					})
				end
				if rank == 3 then
					stamp(
						card,
						"EPIC",
						color:Lerp(M.Marker, 0.2),
						UDim2.new(1, -44, 0, 84),
						Vector2.new(78, 32),
						-12
					)
				elseif rank >= 4 then
					local star = UI.new("Frame", {
						Parent = card,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.new(1, -30, 0, 80),
						Size = UDim2.fromOffset(46, 46),
						Rotation = 18,
						BackgroundColor3 = color,
						BorderSizePixel = 0,
						ZIndex = 8,
					}, { UI.corner(8), UI.stroke(M.Marker, 2) })
					UI.text({
						Parent = star,
						Font = UI.Font.Mono,
						TextSize = 24,
						Size = UDim2.fromScale(1, 1),
						TextColor3 = M.Marker,
						Text = "★",
						ZIndex = 9,
					})
				end
			end,
		})
	end
	if carried >= capacity then
		bagFullCard() -- waits behind a find card, if one just showed
	end
end

---------------------------------------------------------------------------- Sale receipt

local lastSale = 0

-- The Scrap Buyer's tally on a clipboard: itemised lines, bonuses, the payout (the biggest thing
-- on the card), the new balance and a PAID stamp. Every number is the server's.
function SalvageFeedback.onSale(receipt: any)
	if receipt.Sale <= lastSale then
		return -- already shown: one receipt per completed sale
	end
	lastSale = receipt.Sale
	local shown = math.min(#receipt.Lines, 4)
	local extra = #receipt.Lines - shown
	local rows = shown + (if extra > 0 then 1 else 0) + #receipt.Multipliers
	local height = 156 + rows * 22
	local core = receipt.HadCore

	Notifications.card({
		Priority = 5,
		Accent = if core then Config.RarityColors.Legendary else UI.Color.Safe,
		Height = height,
		Width = 290,
		Seconds = if core then 5.5 else 3.8,
		Surface = "Clipboard",
		Build = function(card)
			line(card, 0, 18, {
				Font = UI.Font.Title,
				TextSize = 17,
				Text = if core then "STORM CORE DELIVERED" else "SCRAP BUYER",
				TextColor3 = if core then M.RedPen else M.Marker,
				ZIndex = 7,
			})
			line(card, 2, 14, {
				Font = UI.Font.Label,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Right,
				Text = ("SALE #%03d"):format(receipt.Sale),
				TextColor3 = M.Pencil,
				ZIndex = 7,
			})
			local y = 26
			local function row(left: string, right: string, color: Color3?, chip: Color3?)
				if chip then
					UI.new("Frame", {
						Parent = card,
						Position = UDim2.fromOffset(0, y + 5),
						Size = UDim2.fromOffset(10, 12),
						Rotation = -6,
						BackgroundColor3 = chip,
						BorderSizePixel = 0,
						ZIndex = 7,
					})
				end
				line(card, y, 22, {
					Font = UI.Font.Label,
					TextSize = 14,
					Position = UDim2.fromOffset(16, y),
					Size = UDim2.new(0.74, -16, 0, 22),
					Text = left,
					TextColor3 = color or M.Marker,
					ZIndex = 7,
				})
				line(card, y, 22, {
					Font = UI.Font.Mono,
					TextSize = 15,
					Position = UDim2.new(0.74, 0, 0, y),
					Size = UDim2.new(0.26, 0, 0, 22),
					TextXAlignment = Enum.TextXAlignment.Right,
					Text = right,
					TextColor3 = color or M.Marker,
					ZIndex = 7,
				})
				y += 22
			end
			for i = 1, shown do
				local entry = receipt.Lines[i]
				local def = Config.Loot[entry.Id]
				local name = if entry.Count > 1 then ("%s ×%d"):format(def.Name, entry.Count) else def.Name
				row(name, tostring(entry.Value * entry.Count), nil, Config.RarityColors[def.Rarity])
			end
			if extra > 0 then
				local rest = 0
				for i = shown + 1, #receipt.Lines do
					rest += receipt.Lines[i].Value * receipt.Lines[i].Count
				end
				row(("+ %d more"):format(extra), tostring(rest))
			end
			for _, bonus in receipt.Multipliers do
				row(bonus.Name, ("×%s"):format(tostring(bonus.Factor)), M.RedPen)
			end
			-- The payout: biggest number on the card, circled in red pen.
			local ring = UI.new("Frame", {
				Parent = card,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.42, 0, 0, y + 8),
				Size = UDim2.fromOffset(150, 52),
				Rotation = -3,
				BackgroundTransparency = 1,
				ZIndex = 7,
			}, { UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), UI.stroke(M.RedPen, 2.5) })
			local total = UI.text({
				Parent = ring,
				Font = UI.Font.Mono,
				TextSize = 34,
				Size = UDim2.fromScale(1, 1),
				TextColor3 = M.Marker,
				Text = "+0",
				ZIndex = 8,
			})
			stamp(card, "PAID", M.RedPen, UDim2.new(1, -24, 0, y + 44), Vector2.new(62, 26), -14)
			line(card, y + 66, 16, {
				Font = UI.Font.Label,
				TextSize = 13,
				Text = ("Coins now: %s"):format(UI.comma(receipt.Balance)),
				TextColor3 = M.Pencil,
				ZIndex = 7,
			})
			-- Count up to the exact server total (visual only; the coins were already paid).
			UI.countUp(total, 0, receipt.Total, if UI.reduced() then 0.01 else UI.Time.Count, "+%d")
		end,
	})

	Audio.play("Sell")
	if core then
		Audio.play("CoreDelivered")
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			sparkleBurst(root.Position + Vector3.new(0, 2, 0), Config.RarityColors.Legendary, 24)
		end
	elseif receipt.Total >= 150 then
		task.delay(0.12, Audio.play, "SellBig")
	end
end

---------------------------------------------------------------------------- Beacons

-- A light column you can find from across town. Thin columns vanish at a distance, so each
-- one widens with camera distance (updated a few times a second in step()).
type Beacon = { Part: BasePart, Base: Vector3 }
local beacons: { Beacon } = {}

local function beacon(position: Vector3, height: number, color: Color3, name: string): Beacon
	local part = UI.new("Part", {
		Parent = effects,
		Name = name,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = Enum.Material.Neon,
		Color = color,
		Transparency = 0.5,
		Size = Vector3.new(0.8, height, 0.8),
		Position = position + Vector3.new(0, height / 2 + 2, 0),
	})
	local b = { Part = part, Base = position }
	table.insert(beacons, b)
	return b
end

local function removeBeacon(b: Beacon)
	local i = table.find(beacons, b)
	if i then
		table.remove(beacons, i)
	end
	b.Part:Destroy()
end

-- Billboards are parented to a part (in Studio captures, billboards kept in a loose folder
-- didn't render). `offset` is from that part's centre.
local function worldLabel(
	part: BasePart,
	name: string,
	text: string,
	color: Color3,
	maxDistance: number,
	offset: Vector3
): TextLabel
	local gui = UI.new("BillboardGui", {
		Parent = part,
		Name = name,
		Size = UDim2.fromOffset(200, 26),
		StudsOffsetWorldSpace = offset,
		LightInfluence = 0,
		MaxDistance = maxDistance,
	})
	return UI.text({
		Parent = gui,
		Font = UI.Font.Mono,
		TextSize = 18,
		Outline = true,
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextColor3 = color,
	})
end

---------------------------------------------------------------------------- Storm Cores

local cores: { [Instance]: Beacon } = {}

local function addCoreBeacon(item: Instance)
	if not item:IsA("BasePart") or item:GetAttribute("LootId") ~= "StormCore" or cores[item] then
		return
	end
	local color = Config.Loot.StormCore.Color
	cores[item] = beacon(item.Position, 120, color, "CoreBeacon")
	worldLabel(
		item,
		"CoreLabel",
		("STORM CORE · %d"):format(Config.Loot.StormCore.Value),
		color,
		500,
		Vector3.new(0, 4.5, 0)
	)
end

function SalvageFeedback.coreCount(): number
	local n = 0
	for _ in cores do
		n += 1
	end
	return n
end

---------------------------------------------------------------------------- Dropped bag

-- Your own dropped salvage gets one light column and one countdown per drop (not one per
-- item), so you can find it from the Scrapyard and know how long it's yours alone.
type Drop = { Items: { [Instance]: boolean }, Beacon: Beacon, Label: TextLabel, Until: number }
local drops: { [number]: Drop } = {}

local function addBagMarker(item: Instance)
	if not item:IsA("BasePart") or item:GetAttribute("OwnerId") ~= Players.LocalPlayer.UserId then
		return
	end
	local untilTime = item:GetAttribute("OwnerUntil") or 0
	local key = math.floor(untilTime * 10 + 0.5) -- every item from one drop shares this
	local drop = drops[key]
	if drop then
		drop.Items[item] = true
		return
	end
	local height = 80
	local b = beacon(item.Position, height, Color3.fromRGB(255, 150, 80), "BagBeacon")
	drops[key] = {
		Items = { [item] = true },
		Beacon = b,
		-- On the beacon, not an item: items vanish one by one as they're picked up.
		Label = worldLabel(
			b.Part,
			"BagLabel",
			"YOUR BAG",
			Color3.fromRGB(255, 190, 120),
			600,
			Vector3.new(0, -height / 2 + 3, 0)
		),
		Until = untilTime,
	}
end

local function removeBagItem(item: Instance)
	for key, drop in drops do
		if drop.Items[item] then
			drop.Items[item] = nil
			if next(drop.Items) == nil then
				removeBeacon(drop.Beacon)
				drops[key] = nil
			end
			return
		end
	end
end

---------------------------------------------------------------------------- Per frame

local beaconCheckAt = 0

function SalvageFeedback.step(now: number)
	for _, drop in drops do
		local left = drop.Until - now
		if left > 0 then
			drop.Label.Text = ("YOUR BAG · %ds"):format(math.ceil(left))
			drop.Label.TextColor3 = Color3.fromRGB(255, 190, 120)
		else
			drop.Label.Text = "YOUR BAG · anyone can take it!"
			drop.Label.TextColor3 = UI.Color.Danger
		end
	end
	if os.clock() >= beaconCheckAt then
		beaconCheckAt = os.clock() + 0.15
		local camera = workspace.CurrentCamera
		if camera then
			local camPos = camera.CFrame.Position
			for _, b in beacons do
				-- About 1 stud wide close up, up to 5 studs at 500 studs away.
				local width = math.clamp((b.Base - camPos).Magnitude / 100, 0.8, 5)
				if math.abs(b.Part.Size.X - width) > 0.2 then
					b.Part.Size = Vector3.new(width, b.Part.Size.Y, width)
				end
			end
		end
	end
end

---------------------------------------------------------------------------- Init

function SalvageFeedback.init()
	effects = UI.new("Folder", { Name = "SalvageEffects", Parent = workspace })
	task.spawn(function()
		local lootFolder = workspace:WaitForChild("Loot")
		local function added(item: Instance)
			addCoreBeacon(item)
			addBagMarker(item)
		end
		lootFolder.ChildAdded:Connect(added)
		lootFolder.ChildRemoved:Connect(function(item)
			local b = cores[item]
			if b then
				removeBeacon(b)
				cores[item] = nil
			end
			removeBagItem(item)
		end)
		for _, item in lootFolder:GetChildren() do
			added(item)
		end
	end)
end

return SalvageFeedback
