-- Reward feedback for the salvage loop: pickups, rare finds, a full bag, Storm Cores, and the
-- sale receipt. Everything shown here comes from the server (Pickup and SaleReceipt events
-- and the player state); nothing is computed or granted on the client.
--
--   Every pickup: "Mini Safe · 90 value" rising from where the item was. That's what it will
--     sell for, not money yet, so it isn't gold and has no "+".
--   Rare / Epic / Legendary: also a find card (left slot), its own chime, and sparkles.
--   Bag full: a card telling you to go sell (waits behind a find card instead of hiding it).
--   Storm Cores: a light column and label over every core in town.
--   Sale: an itemized receipt card; the total counts up to the server's exact payout.
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
		Role = "Title",
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

local function bagFullCard()
	Notifications.card({
		Priority = 1,
		Accent = UI.Color.Danger,
		Height = 62,
		Seconds = 3,
		Build = function(card)
			line(card, 8, 22, { Role = "Title", Text = "BAG FULL", TextColor3 = UI.Color.Danger })
			line(card, 33, 18, {
				Role = "Body",
				TextSize = 14,
				Text = "Sell at the Scrap Buyer on the hill",
				TextColor3 = UI.Color.TextDim,
			})
		end,
	})
end

-- Called with the player's state right after a pickup (carried count is already updated).
function SalvageFeedback.onPickup(info: { Id: string, Position: Vector3 }, carried: number, capacity: number)
	local def = Config.Loot[info.Id]
	if not def then
		return
	end
	local rank = RANK[def.Rarity] or 0
	local color = Config.RarityColors[def.Rarity]
	worldPop(info.Position, ("%s · %d value"):format(def.Name, def.Value), color, rank >= 2)
	Audio.play("Pickup", 1, 1 + rank * 0.05)
	if rank >= 2 then
		Audio.play(FIND_SOUND[def.Rarity])
		sparkleBurst(info.Position + Vector3.new(0, 1.5, 0), color, 8 + rank * 8)
		local isCore = info.Id == "StormCore"
		Notifications.card({
			Priority = rank,
			Accent = color,
			Height = 100,
			Seconds = 2.2 + rank * 0.5,
			Build = function(card)
				line(card, 8, 18, { Role = "Label", Text = TAG[def.Rarity], TextColor3 = color })
				line(card, 28, 30, { Role = "Display", TextSize = 26, Text = def.Name })
				line(card, 60, 16, {
					Role = "Label",
					TextSize = 14,
					Text = ("Salvage value %d"):format(def.Value),
					TextColor3 = color,
				})
				line(card, 78, 16, {
					Role = "Body",
					TextSize = 13,
					Text = if isCore
						then ("Bag %d/%d  ·  get it to the Scrap Buyer alive!"):format(carried, capacity)
						else ("Bag %d/%d"):format(carried, capacity),
					TextColor3 = UI.Color.TextDim,
				})
			end,
		})
	end
	if carried >= capacity then
		bagFullCard() -- waits behind a find card, if one just showed
	end
end

---------------------------------------------------------------------------- Sale receipt

local lastSale = 0

function SalvageFeedback.onSale(receipt: any)
	if receipt.Sale <= lastSale then
		return -- already shown: one receipt per completed sale
	end
	lastSale = receipt.Sale
	local shown = math.min(#receipt.Lines, 4)
	local extra = #receipt.Lines - shown
	local rows = shown + (if extra > 0 then 1 else 0) + #receipt.Multipliers
	local height = 34 + rows * 19 + 62 -- header, rows, divider + total + balance
	local accent = if receipt.HadCore then Config.RarityColors.Legendary else UI.Color.Safe

	Notifications.card({
		Priority = 5,
		Accent = accent,
		Height = height,
		Seconds = if receipt.HadCore then 5.5 else 3.8,
		Build = function(card)
			line(card, 8, 22, {
				Role = "Title",
				Text = if receipt.HadCore then "STORM CORE DELIVERED!" else "SOLD!",
				TextColor3 = accent,
			})
			local y = 34
			local function row(left: string, right: string, color: Color3?)
				line(card, y, 17, {
					Role = "Body",
					TextSize = 14,
					Size = UDim2.new(0.72, 0, 0, 17),
					Text = left,
					TextColor3 = color or UI.Color.TextDim,
				})
				line(card, y, 17, {
					Role = "Label",
					TextSize = 14,
					Position = UDim2.new(0.72, 0, 0, y),
					Size = UDim2.new(0.28, 0, 0, 17),
					TextXAlignment = Enum.TextXAlignment.Right,
					Text = right,
					TextColor3 = color or UI.Color.TextDim,
				})
				y += 19
			end
			for i = 1, shown do
				local entry = receipt.Lines[i]
				local def = Config.Loot[entry.Id]
				local name = if entry.Count > 1 then ("%dx %s"):format(entry.Count, def.Name) else def.Name
				row(name, tostring(entry.Value * entry.Count), Config.RarityColors[def.Rarity])
			end
			if extra > 0 then
				local rest = 0
				for i = shown + 1, #receipt.Lines do
					rest += receipt.Lines[i].Value * receipt.Lines[i].Count
				end
				row(("+ %d more"):format(extra), tostring(rest))
			end
			for _, bonus in receipt.Multipliers do
				row(bonus.Name, ("x%s"):format(tostring(bonus.Factor)), UI.Color.Coin)
			end
			UI.new("Frame", {
				Parent = card,
				Position = UDim2.fromOffset(0, y + 3),
				Size = UDim2.new(1, 0, 0, 2),
				BackgroundColor3 = UI.Color.Slate,
				BorderSizePixel = 0,
			})
			line(card, y + 9, 30, { Role = "Title", Size = UDim2.new(0.45, 0, 0, 30), Text = "TOTAL" })
			local total = line(card, y + 9, 30, {
				Role = "Display",
				Position = UDim2.new(0.35, 0, 0, y + 9),
				Size = UDim2.new(0.65, 0, 0, 30),
				TextXAlignment = Enum.TextXAlignment.Right,
				Text = "+0",
				TextColor3 = UI.Color.Coin,
			})
			line(card, y + 41, 16, {
				Role = "Body",
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Right,
				Text = ("Balance %d coins"):format(receipt.Balance),
				TextColor3 = UI.Color.TextDim,
			})
			-- Count up to the exact server total (visual only; the coins were already paid).
			UI.countUp(total, 0, receipt.Total, if UI.reduced() then 0.01 else UI.Time.Count, "+%d")
		end,
	})

	Audio.play("Sell")
	if receipt.HadCore then
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
		Role = "Title",
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
