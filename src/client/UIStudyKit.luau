-- Shared plumbing for the three UI art-direction studies (UIStudies.luau): instance builders,
-- shapes that Roblox UI doesn't have natively, and sample data for screens that need a sale
-- or a pickup that hasn't happened yet. Studio-only; nothing here ships in the final UI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Kit = {}

function Kit.new(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = props.Parent
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

-- A plain filled frame.
function Kit.box(parent: Instance, props: { [string]: any }): Frame
	props.Parent = parent
	if props.BorderSizePixel == nil then
		props.BorderSizePixel = 0
	end
	return Kit.new("Frame", props)
end

function Kit.label(parent: Instance, props: { [string]: any }): TextLabel
	props.Parent = parent
	props.BackgroundTransparency = 1
	if props.TextColor3 == nil then
		props.TextColor3 = Color3.new(1, 1, 1)
	end
	return Kit.new("TextLabel", props)
end

function Kit.button(parent: Instance, props: { [string]: any }): TextButton
	props.Parent = parent
	props.AutoButtonColor = false
	if props.BorderSizePixel == nil then
		props.BorderSizePixel = 0
	end
	return Kit.new("TextButton", props)
end

function Kit.corner(parent: Instance, radius: number): UICorner
	return Kit.new("UICorner", { Parent = parent, CornerRadius = UDim.new(0, radius) })
end

function Kit.round(parent: Instance): UICorner
	return Kit.new("UICorner", { Parent = parent, CornerRadius = UDim.new(1, 0) })
end

function Kit.stroke(parent: Instance, color: Color3, thickness: number, transparency: number?): UIStroke
	return Kit.new("UIStroke", {
		Parent = parent,
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Kit.textStroke(parent: Instance, color: Color3, thickness: number): UIStroke
	return Kit.new("UIStroke", {
		Parent = parent,
		Color = color,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

function Kit.pad(parent: Instance, t: number, r: number?, b: number?, l: number?): UIPadding
	return Kit.new("UIPadding", {
		Parent = parent,
		PaddingTop = UDim.new(0, t),
		PaddingRight = UDim.new(0, r or t),
		PaddingBottom = UDim.new(0, b or t),
		PaddingLeft = UDim.new(0, l or r or t),
	})
end

function Kit.list(parent: Instance, gap: number, horizontal: boolean?, align: any?): UIListLayout
	return Kit.new("UIListLayout", {
		Parent = parent,
		Padding = UDim.new(0, gap),
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
end

function Kit.gradient(parent: Instance, a: Color3, b: Color3, rotation: number?): UIGradient
	return Kit.new("UIGradient", {
		Parent = parent,
		Color = ColorSequence.new(a, b),
		Rotation = rotation or 90,
	})
end

-- A line between two points in a parent's offset space (rotated thin frame).
function Kit.line(
	parent: Instance,
	a: Vector2,
	b: Vector2,
	thickness: number,
	color: Color3,
	z: number?
): Frame
	local d = b - a
	return Kit.box(parent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2),
		Size = UDim2.fromOffset(d.Magnitude, thickness),
		Rotation = math.deg(math.atan2(d.Y, d.X)),
		BackgroundColor3 = color,
		ZIndex = z or 1,
	})
end

-- Four L-shaped corner brackets just inside a frame (Storm Chaser's targeting frame).
function Kit.brackets(parent: Instance, color: Color3, length: number, thickness: number, z: number?)
	for _, c in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		local holder = Kit.box(parent, {
			BackgroundTransparency = 1,
			AnchorPoint = c,
			Position = UDim2.fromScale(c.X, c.Y),
			Size = UDim2.fromOffset(length, length),
			ZIndex = z or 2,
		})
		Kit.box(holder, {
			AnchorPoint = Vector2.new(c.X, c.Y),
			Position = UDim2.fromScale(c.X, c.Y),
			Size = UDim2.new(1, 0, 0, thickness),
			BackgroundColor3 = color,
			ZIndex = z or 2,
		})
		Kit.box(holder, {
			AnchorPoint = Vector2.new(c.X, c.Y),
			Position = UDim2.fromScale(c.X, c.Y),
			Size = UDim2.new(0, thickness, 1, 0),
			BackgroundColor3 = color,
			ZIndex = z or 2,
		})
	end
end

-- A diamond (rotated square) centred at `pos`.
function Kit.diamond(parent: Instance, pos: UDim2, size: number, color: Color3, z: number?): Frame
	return Kit.box(parent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos,
		Size = UDim2.fromOffset(size * 0.72, size * 0.72),
		Rotation = 45,
		BackgroundColor3 = color,
		ZIndex = z or 1,
	})
end

-- A sawtooth edge along the bottom of a frame (torn paper, ticket stubs).
function Kit.zigzag(parent: Instance, width: number, tooth: number, color: Color3, z: number?)
	local holder = Kit.box(parent, {
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, tooth / 2),
		ZIndex = z or 1,
	})
	for i = 0, math.ceil(width / tooth) do
		Kit.box(holder, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(i * tooth + tooth / 2, 0),
			Size = UDim2.fromOffset(tooth * 0.71, tooth * 0.71),
			Rotation = 45,
			BackgroundColor3 = color,
			ZIndex = z or 1,
		})
	end
end

-- Sun rays: thin wedges radiating from the centre of a square holder.
function Kit.rays(
	parent: Instance,
	size: number,
	count: number,
	color: Color3,
	transparency: number,
	z: number?
): Frame
	local holder = Kit.box(parent, {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		ZIndex = z or 1,
	})
	for i = 1, count do
		Kit.box(holder, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, size * 0.09, 1, 0),
			Rotation = i * 180 / count,
			BackgroundColor3 = color,
			BackgroundTransparency = transparency,
			ZIndex = z or 1,
		})
	end
	return holder
end

function Kit.tween(
	inst: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
)
	local t = TweenService:Create(
		inst,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

function Kit.comma(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

function Kit.clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

Kit.Tiers = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

function Kit.tierIndex(rarity: string): number
	return table.find(Kit.Tiers, rarity) or 1
end

-- Upgrade levels, values and next cost for the Gear Shop, from the live player state.
export type Gear = {
	Id: string,
	Name: string,
	Level: number,
	MaxLevel: number,
	Now: number,
	Next: number?,
	Cost: number?,
	Unit: string,
}
function Kit.gear(state: any): { Gear }
	local out = {}
	for _, id in Config.UpgradeOrder do
		local def = Config.Upgrades[id]
		local level = state and state.Upgrades and state.Upgrades[id] or 0
		local unit = if id == "Backpack" then "slots" elseif id == "Boots" then "speed" else "% less damage"
		local function fmt(v: number?): number?
			if v == nil then
				return nil
			end
			return if id == "Armor" then math.floor(v * 100 + 0.5) else v
		end
		table.insert(out, {
			Id = id,
			Name = def.DisplayName,
			Level = level,
			MaxLevel = #def.Costs,
			Now = fmt(def.Values[level + 1]) :: number,
			Next = fmt(def.Values[level + 2]),
			Cost = def.Costs[level + 1],
			Unit = unit,
		})
	end
	return out
end

-- "3 → 5 slots", "16 → 18 speed", "0% → 15% less damage" (or just the current value when maxed).
function Kit.gearText(g: Gear): string
	local function v(n: number): string
		return if g.Id == "Armor" then n .. "%" else tostring(n)
	end
	local unit = if g.Id == "Armor" then "less damage" else g.Unit
	if g.Next then
		return ("%s → %s %s"):format(v(g.Now), v(g.Next), unit)
	end
	return ("%s %s"):format(v(g.Now), unit)
end

-- A representative sale for the receipt screen when no real sale has happened this session.
Kit.SampleReceipt = {
	Lines = {
		{ Id = "Safe", Value = 90, Count = 1 },
		{ Id = "Register", Value = 45, Count = 1 },
		{ Id = "Tv", Value = 15, Count = 2 },
		{ Id = "Can", Value = 2, Count = 3 },
	},
	Base = 171,
	Multipliers = { { Name = "Storm bonus", Factor = 1.25 } },
	Total = 213,
	Balance = 1453,
	HadCore = false,
}

return Kit
