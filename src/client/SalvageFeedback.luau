-- Reward feedback for the salvage loop: pickups, rare finds, a full bag, Storm Cores, and the
-- sale receipt. Everything shown here comes from the server (Pickup and SaleReceipt events
-- and the player state); nothing is computed or granted on the client.
--
--   Common / Uncommon: a "+value Name" pop where the item was. Quick, no text in the HUD.
--   Rare / Epic / Legendary: the pop plus a find card (left side), brighter sound, sparkles.
--   Bag full: a card telling you to go sell.
--   Storm Cores: a light column and label over every core in town, so they're an event.
--   Sale: an itemized receipt card; tap to dismiss.
-- Cards share one slot on the left, middle of the screen, so they never stack.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local SalvageFeedback = {}

export type Hooks = {
	PlaySound: (name: string, volumeScale: number?, pitch: number?) -> (),
	HudRoot: Frame,
	Font: Enum.Font,
	IsReduced: () -> boolean,
}

local hooks: Hooks
local effects: Folder
local RANK = { Common = 0, Uncommon = 1, Rare = 2, Epic = 3, Legendary = 4 }
local TAG = { Rare = "RARE FIND", Epic = "EPIC FIND!", Legendary = "LEGENDARY!" }
local PANEL = Color3.fromRGB(25, 28, 36)
local GOLD = Color3.fromRGB(255, 215, 80)

local function new(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = props.Parent
	props.Parent = nil
	for k, v in props do
		(inst :: any)[k] = v
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	inst.Parent = parent
	return inst
end

local function text(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = 1
	props.Font = props.Font or hooks.Font
	props.TextScaled = true
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	local l = new("TextLabel", props)
	new("UIStroke", { Parent = l, Thickness = 1.5, Color = Color3.new(0, 0, 0) })
	return l
end

---------------------------------------------------------------------------- Card slot

local slot: TextButton
local slotScale: UIScale
local cardToken = 0

-- Shows `build`'s content in the card slot for `seconds`, replacing whatever was there.
local function showCard(accent: Color3, height: number, seconds: number, build: (GuiObject) -> ())
	cardToken += 1
	local token = cardToken
	for _, c in slot:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	slot.Size = UDim2.fromOffset(250, height)
	local stroke = slot:FindFirstChildOfClass("UIStroke") :: UIStroke
	stroke.Color = accent
	new("Frame", {
		Parent = slot,
		Name = "Accent",
		Size = UDim2.new(0, 6, 1, 0),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 3) }) })
	build(slot)
	slot.Visible = true
	slotScale.Scale = 0.85
	TweenService:Create(slotScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(seconds, function()
		if token == cardToken then
			slot.Visible = false
		end
	end)
end

---------------------------------------------------------------------------- Pickups

-- "+value Name" that rises out of the spot the item was taken from.
local function worldPop(position: Vector3, label: string, color: Color3, big: boolean)
	local anchor = new("Part", {
		Parent = effects,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.one,
		Position = position + Vector3.new(0, 2, 0),
	})
	local gui = new("BillboardGui", {
		Parent = anchor,
		Size = UDim2.fromOffset(big and 220 or 160, big and 44 or 30),
		LightInfluence = 0,
		MaxDistance = 120,
	})
	local l = text({ Parent = gui, Size = UDim2.fromScale(1, 1), Text = label, TextColor3 = color })
	TweenService
		:Create(gui, TweenInfo.new(1.1, Enum.EasingStyle.Quad), { StudsOffset = Vector3.new(0, 3, 0) })
		:Play()
	TweenService
		:Create(l, TweenInfo.new(0.4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.7), {
			TextTransparency = 1,
		})
		:Play()
	Debris:AddItem(anchor, 1.2)
end

local function sparkleBurst(position: Vector3, color: Color3, amount: number)
	local attachment = new("Attachment", { Parent = workspace.Terrain, WorldPosition = position })
	local emitter = new("ParticleEmitter", {
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
	emitter:Emit(if hooks.IsReduced() then math.ceil(amount / 3) else amount)
	Debris:AddItem(attachment, 1.2)
end

local function bagFullCard()
	showCard(Color3.fromRGB(240, 90, 70), 64, 3, function(card)
		text({
			Parent = card,
			Position = UDim2.fromOffset(16, 6),
			Size = UDim2.new(1, -24, 0, 28),
			Text = "BAG FULL",
			TextColor3 = Color3.fromRGB(255, 120, 100),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		text({
			Parent = card,
			Position = UDim2.fromOffset(16, 36),
			Size = UDim2.new(1, -24, 0, 20),
			Text = "Sell at the Scrap Buyer on the hill",
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end)
end

-- Called with the player's state right after a pickup (carried count is already updated).
function SalvageFeedback.onPickup(info: { Id: string, Position: Vector3 }, carried: number, capacity: number)
	local def = Config.Loot[info.Id]
	if not def then
		return
	end
	local rank = RANK[def.Rarity] or 0
	local color = Config.RarityColors[def.Rarity]
	worldPop(info.Position, ("+%d %s"):format(def.Value, def.Name), color, rank >= 2)
	hooks.PlaySound("Pickup", 1, 1 + rank * 0.07)
	if rank >= 2 then
		hooks.PlaySound("Sell", 0.4 + rank * 0.12, 0.9 + rank * 0.1)
		sparkleBurst(info.Position + Vector3.new(0, 1.5, 0), color, 8 + rank * 8)
		local tag = TAG[def.Rarity]
		showCard(color, 92, 2 + rank * 0.5, function(card)
			text({
				Parent = card,
				Position = UDim2.fromOffset(16, 6),
				Size = UDim2.new(1, -24, 0, 22),
				Text = tag,
				TextColor3 = color,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			text({
				Parent = card,
				Position = UDim2.fromOffset(16, 30),
				Size = UDim2.new(0.7, -16, 0, 30),
				Text = def.Name,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			text({
				Parent = card,
				Position = UDim2.new(0.7, 0, 0, 30),
				Size = UDim2.new(0.3, -10, 0, 30),
				Text = ("+%d"):format(def.Value),
				TextColor3 = GOLD,
				TextXAlignment = Enum.TextXAlignment.Right,
			})
			text({
				Parent = card,
				Position = UDim2.fromOffset(16, 64),
				Size = UDim2.new(1, -24, 0, 18),
				Text = if info.Id == "StormCore"
					then ("Bag %d/%d  -  get it to the Scrap Buyer alive!"):format(carried, capacity)
					else ("Bag %d/%d"):format(carried, capacity),
				Font = Enum.Font.GothamMedium,
				TextColor3 = Color3.fromRGB(200, 200, 210),
				TextXAlignment = Enum.TextXAlignment.Left,
			})
		end)
		if carried >= capacity then
			-- Rare card first; the bag-full reminder follows once it has been read.
			task.delay(2 + rank * 0.5, bagFullCard)
		end
	elseif carried >= capacity then
		bagFullCard()
	end
end

---------------------------------------------------------------------------- Sale receipt

local lastSale = 0

function SalvageFeedback.onSale(receipt: any)
	if receipt.Sale <= lastSale then
		return -- already shown
	end
	lastSale = receipt.Sale
	local shown = math.min(#receipt.Lines, 4)
	local extra = #receipt.Lines - shown
	local rows = shown + (if extra > 0 then 1 else 0) + #receipt.Multipliers
	local height = 70 + rows * 22 + 44
	local accent = if receipt.HadCore then Config.RarityColors.Legendary else Color3.fromRGB(90, 220, 110)
	showCard(accent, height, if receipt.HadCore then 5 else 3.2, function(card)
		text({
			Parent = card,
			Position = UDim2.fromOffset(16, 6),
			Size = UDim2.new(1, -24, 0, 24),
			Text = if receipt.HadCore then "STORM CORE DELIVERED!" else "SOLD!",
			TextColor3 = accent,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local y = 36
		local function row(left: string, right: string, color: Color3?)
			text({
				Parent = card,
				Position = UDim2.fromOffset(16, y),
				Size = UDim2.new(0.7, -16, 0, 20),
				Text = left,
				Font = Enum.Font.GothamMedium,
				TextColor3 = color or Color3.fromRGB(220, 220, 228),
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			text({
				Parent = card,
				Position = UDim2.new(0.7, 0, 0, y),
				Size = UDim2.new(0.3, -10, 0, 20),
				Text = right,
				Font = Enum.Font.GothamMedium,
				TextColor3 = color or Color3.fromRGB(220, 220, 228),
				TextXAlignment = Enum.TextXAlignment.Right,
			})
			y += 22
		end
		for i = 1, shown do
			local line = receipt.Lines[i]
			local def = Config.Loot[line.Id]
			local name = if line.Count > 1 then ("%dx %s"):format(line.Count, def.Name) else def.Name
			row(name, tostring(line.Value * line.Count), Config.RarityColors[def.Rarity])
		end
		if extra > 0 then
			local rest = 0
			for i = shown + 1, #receipt.Lines do
				rest += receipt.Lines[i].Value * receipt.Lines[i].Count
			end
			row(("+ %d more"):format(extra), tostring(rest))
		end
		for _, bonus in receipt.Multipliers do
			row(bonus.Name, ("x%s"):format(tostring(bonus.Factor)), Color3.fromRGB(255, 220, 120))
		end
		new("Frame", {
			Parent = card,
			Position = UDim2.fromOffset(16, y + 2),
			Size = UDim2.new(1, -26, 0, 2),
			BackgroundColor3 = Color3.fromRGB(70, 75, 90),
			BorderSizePixel = 0,
		})
		text({
			Parent = card,
			Position = UDim2.fromOffset(16, y + 8),
			Size = UDim2.new(0.5, -16, 0, 30),
			Text = "TOTAL",
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local total = text({
			Parent = card,
			Position = UDim2.new(0.5, 0, 0, y + 8),
			Size = UDim2.new(0.5, -10, 0, 30),
			Text = "+0",
			TextColor3 = GOLD,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		-- Count up quickly to the exact server total.
		task.spawn(function()
			local t0 = os.clock()
			local duration = 0.45
			while os.clock() - t0 < duration and total.Parent do
				local f = (os.clock() - t0) / duration
				total.Text = ("+%d"):format(math.floor(receipt.Total * f))
				task.wait()
			end
			total.Text = ("+%d"):format(receipt.Total)
		end)
	end)
	hooks.PlaySound("Sell", if receipt.HadCore then 1.2 else 1, if receipt.HadCore then 1.15 else 1)
end

---------------------------------------------------------------------------- Storm Cores

local cores: { [Instance]: Instance } = {}

local function addCoreBeacon(item: Instance)
	if not item:IsA("BasePart") or item:GetAttribute("LootId") ~= "StormCore" or cores[item] then
		return
	end
	local color = Config.Loot.StormCore.Color
	local beam = new("Part", {
		Parent = effects,
		Name = "CoreBeacon",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = Enum.Material.Neon,
		Color = color,
		Transparency = 0.55,
		Size = Vector3.new(0.8, 120, 0.8),
		Position = item.Position + Vector3.new(0, 62, 0),
	})
	local gui = new("BillboardGui", {
		Parent = item,
		Name = "CoreLabel",
		Size = UDim2.fromOffset(150, 34),
		StudsOffsetWorldSpace = Vector3.new(0, 5, 0),
		LightInfluence = 0,
		MaxDistance = 500,
	})
	text({
		Parent = gui,
		Size = UDim2.fromScale(1, 1),
		Text = ("STORM CORE  %d"):format(Config.Loot.StormCore.Value),
		TextColor3 = color,
	})
	cores[item] = beam
end

---------------------------------------------------------------------------- Dropped bag

-- Your own dropped salvage gets a light column and a countdown, so you can find it from the
-- Scrapyard and know how long it's yours alone.
local bagMarkers: { [Instance]: { Beam: BasePart, Label: TextLabel, Until: number } } = {}

local function addBagMarker(item: Instance)
	if not item:IsA("BasePart") or item:GetAttribute("OwnerId") ~= Players.LocalPlayer.UserId then
		return
	end
	local beam = new("Part", {
		Parent = effects,
		Name = "BagBeacon",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 150, 80),
		Transparency = 0.6,
		Size = Vector3.new(0.6, 80, 0.6),
		Position = item.Position + Vector3.new(0, 42, 0),
	})
	local gui = new("BillboardGui", {
		Parent = item,
		Name = "BagLabel",
		Size = UDim2.fromOffset(170, 30),
		StudsOffsetWorldSpace = Vector3.new(0, 4, 0),
		LightInfluence = 0,
		MaxDistance = 600,
	})
	local label = text({ Parent = gui, Size = UDim2.fromScale(1, 1), Text = "YOUR BAG" })
	bagMarkers[item] = { Beam = beam, Label = label, Until = item:GetAttribute("OwnerUntil") or 0 }
end

function SalvageFeedback.step(now: number)
	for _, marker in bagMarkers do
		local left = marker.Until - now
		if left > 0 then
			marker.Label.Text = ("YOUR BAG  %ds"):format(math.ceil(left))
			marker.Label.TextColor3 = Color3.fromRGB(255, 190, 120)
		else
			marker.Label.Text = "YOUR BAG  (anyone can take it!)"
			marker.Label.TextColor3 = Color3.fromRGB(255, 110, 90)
		end
	end
end

function SalvageFeedback.coreCount(): number
	local n = 0
	for _ in cores do
		n += 1
	end
	return n
end

---------------------------------------------------------------------------- Init

function SalvageFeedback.init(h: Hooks)
	hooks = h
	effects = new("Folder", { Name = "SalvageEffects", Parent = workspace })

	slot = new("TextButton", {
		Name = "RewardCard",
		Parent = h.HudRoot,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.42, 0), -- above the touch thumbstick
		Size = UDim2.fromOffset(250, 92),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.12,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		ZIndex = 4,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0, 12) }),
		new("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1) }),
	})
	slotScale = new("UIScale", { Parent = slot })
	-- Tap to dismiss.
	slot.Activated:Connect(function()
		cardToken += 1
		slot.Visible = false
	end)

	task.spawn(function()
		local lootFolder = workspace:WaitForChild("Loot")
		local function added(item: Instance)
			addCoreBeacon(item)
			addBagMarker(item)
		end
		lootFolder.ChildAdded:Connect(added)
		lootFolder.ChildRemoved:Connect(function(item)
			local beam = cores[item]
			if beam then
				beam:Destroy()
				cores[item] = nil
			end
			local marker = bagMarkers[item]
			if marker then
				marker.Beam:Destroy()
				bagMarkers[item] = nil
			end
		end)
		for _, item in lootFolder:GetChildren() do
			added(item)
		end
	end)
end

return SalvageFeedback
