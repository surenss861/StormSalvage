-- UI study 2: Storm Chaser. A storm-tracking broadcast: dark navy glass at the screen edges,
-- cyan telemetry, corner brackets instead of rounded plates, a live radar scope for the storm,
-- a news-style chyron for objectives and warnings, an equipment loadout with spec bars, a
-- tabular haul report, and rarity graded as storm categories (CAT 1-5). The centre of the
-- screen stays clear; the drama comes from the storm, the UI reports on it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UI = require(script.Parent:WaitForChild("UI"))

local Study = {}

local NAVY = Color3.fromRGB(8, 16, 30)
local GLASS = 0.22
local CYAN = Color3.fromRGB(70, 225, 255)
local CYAN_DIM = Color3.fromRGB(116, 186, 212)
local WHITE = Color3.fromRGB(236, 246, 255)
local RED = Color3.fromRGB(255, 62, 72)
local AMBER = Color3.fromRGB(255, 184, 0)
local GRID = Color3.fromRGB(40, 90, 120)

local WIDE = Enum.Font.Michroma
local BODY = Enum.Font.TitilliumWeb
local MONO = Enum.Font.RobotoMono

local WARNING_SECONDS = 15 -- for the inbound blip; the warning phase is about this long

function Study.build(root: Frame, Kit: any, _opts: any)
	local view = {}

	local function glass(parent: Instance, props: { [string]: any }, bracket: Color3?): Frame
		props.BackgroundColor3 = props.BackgroundColor3 or NAVY
		if props.BackgroundTransparency == nil then
			props.BackgroundTransparency = GLASS
		end
		local f = Kit.box(parent, props)
		Kit.stroke(f, CYAN_DIM, 1, 0.55)
		Kit.brackets(f, bracket or CYAN, 14, 2, (props.ZIndex or 1) + 1)
		return f
	end

	local function text(parent: Instance, props: { [string]: any }): TextLabel
		props.TextColor3 = props.TextColor3 or WHITE
		props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
		return Kit.label(parent, props)
	end

	local function catColor(rarity: string): Color3
		return Config.RarityColors[rarity]
	end

	------------------------------------------------------------------ HUD

	-- Telemetry, top left.
	local tele = glass(root, { Position = UDim2.fromOffset(16, 14), Size = UDim2.fromOffset(300, 124) })
	text(tele, {
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.fromOffset(120, 14),
		Font = WIDE,
		TextSize = 12,
		TextColor3 = CYAN_DIM,
		Text = "FUNDS",
	})
	local fundsDot = Kit.diamond(tele, UDim2.fromOffset(24, 42), 14, AMBER, 2)
	fundsDot.Name = "Dot"
	local funds = text(tele, {
		Position = UDim2.fromOffset(38, 24),
		Size = UDim2.fromOffset(240, 36),
		Font = MONO,
		TextSize = 32,
		Text = "0",
	})
	text(tele, {
		Position = UDim2.fromOffset(16, 66),
		Size = UDim2.fromOffset(120, 14),
		Font = WIDE,
		TextSize = 12,
		TextColor3 = CYAN_DIM,
		Text = "PAYLOAD",
	})
	local payloadCount = text(tele, {
		Position = UDim2.fromOffset(110, 62),
		Size = UDim2.fromOffset(70, 20),
		Font = MONO,
		TextSize = 18,
		Text = "",
	})
	local payloadValue = text(tele, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 62),
		Size = UDim2.fromOffset(120, 20),
		Font = MONO,
		TextSize = 15,
		TextColor3 = CYAN,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
	})
	local segs = Kit.box(tele, {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 90),
		Size = UDim2.new(1, -32, 0, 18),
	})
	local segKey = ""

	local boost = glass(root, {
		Position = UDim2.fromOffset(16, 146),
		Size = UDim2.fromOffset(190, 30),
		BackgroundColor3 = Color3.fromRGB(60, 44, 0),
	}, AMBER)
	text(boost, {
		Size = UDim2.fromScale(1, 1),
		Font = WIDE,
		TextSize = 12,
		TextColor3 = AMBER,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "2X YIELD ACTIVE",
	})

	-- Radar, top right.
	local R = 76
	local radarBox = glass(root, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 14),
		Size = UDim2.fromOffset(2 * R + 48, 2 * R + 72),
	})
	local scope = Kit.box(radarBox, {
		Position = UDim2.fromOffset(24, 12),
		Size = UDim2.fromOffset(2 * R, 2 * R),
		BackgroundColor3 = Color3.fromRGB(4, 22, 34),
		BackgroundTransparency = 0.1,
		ClipsDescendants = true,
	})
	Kit.round(scope)
	for _, f in { 1, 0.66, 0.33 } do
		local ring = Kit.box(scope, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(f, f),
			BackgroundTransparency = 1,
		})
		Kit.round(ring)
		Kit.stroke(ring, GRID, 1)
	end
	Kit.box(scope, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = GRID,
	})
	Kit.box(scope, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = GRID,
	})
	local sweep = Kit.box(scope, {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(2 * R, 2 * R),
	})
	for i = 0, 5 do
		Kit.box(sweep, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(R, 2),
			Rotation = -i * 5,
			BackgroundColor3 = CYAN,
			BackgroundTransparency = 0.1 + i * 0.16,
		})
	end
	local blip = Kit.box(scope, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = RED,
		Visible = false,
	})
	Kit.round(blip)
	local you = Kit.box(scope, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(6, 6),
		BackgroundColor3 = WHITE,
	})
	Kit.round(you)
	local radarTitle = text(radarBox, {
		Position = UDim2.fromOffset(14, 2 * R + 20),
		Size = UDim2.new(1, -28, 0, 16),
		Font = WIDE,
		TextSize = 12,
		TextColor3 = CYAN_DIM,
		Text = "",
	})
	local radarTime = text(radarBox, {
		Position = UDim2.fromOffset(14, 2 * R + 38),
		Size = UDim2.new(1, -28, 0, 30),
		Font = MONO,
		TextSize = 28,
		Text = "",
	})

	-- Chyron, bottom.
	local chyron = Kit.box(root, {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.new(0.62, 0, 0, 46),
	})
	local tag = Kit.box(chyron, { Size = UDim2.new(0, 170, 1, 0), BackgroundColor3 = CYAN })
	local tagText = text(tag, {
		Size = UDim2.fromScale(1, 1),
		Font = WIDE,
		TextSize = 13,
		TextColor3 = NAVY,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "FIELD OPS",
	})
	local band = Kit.box(chyron, {
		Position = UDim2.fromOffset(170, 0),
		Size = UDim2.new(1, -170, 1, 0),
		BackgroundColor3 = NAVY,
		BackgroundTransparency = 0.12,
		ClipsDescendants = true,
	})
	Kit.box(band, { Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = CYAN })
	local ticker = text(band, {
		Position = UDim2.fromOffset(16, 2),
		Size = UDim2.new(0, 0, 1, -2),
		AutomaticSize = Enum.AutomaticSize.X,
		Font = BODY,
		TextSize = 20,
		Text = "",
	})
	local tickerKey = ""
	local tickerStart = 0

	-- Buttons, right edge.
	local loadout = glass(root, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.56, 0),
		Size = UDim2.fromOffset(132, 64),
	})
	local loadoutIcon = UI.bagIcon(loadout, 26, CYAN)
	loadoutIcon.Position = UDim2.fromOffset(14, 19)
	text(loadout, {
		Position = UDim2.fromOffset(48, 0),
		Size = UDim2.new(1, -54, 1, 0),
		Font = WIDE,
		TextSize = 12,
		Text = "LOADOUT",
	})
	local sys = glass(root, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -158, 0.56, 0),
		Size = UDim2.fromOffset(64, 64),
	})
	local sysIcon = UI.slidersIcon(sys, 26)
	sysIcon.Position = UDim2.new(0.5, -13, 0.5, -13)

	local overlay = Kit.box(root, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50 })

	function view.hud(s: any, storm: any, now: number, objective: string, hint: string?)
		funds.Text = Kit.comma(s.Coins)
		payloadCount.Text = ("%d/%d"):format(#s.Carried, s.Capacity)
		payloadValue.Text = if s.CarriedValue and s.CarriedValue > 0
			then ("EST %d"):format(s.CarriedValue)
			else "EMPTY"
		local key = table.concat(s.Carried, ",") .. "/" .. s.Capacity
		if key ~= segKey then
			segKey = key
			segs:ClearAllChildren()
			Kit.list(segs, 3, true)
			local w = math.floor((268 - (s.Capacity - 1) * 3) / s.Capacity)
			for i = 1, s.Capacity do
				local id = s.Carried[i]
				local def = id and Config.Loot[id]
				Kit.box(segs, {
					LayoutOrder = i,
					Size = UDim2.fromOffset(w, 18),
					BackgroundColor3 = if def then catColor(def.Rarity) else GRID,
					BackgroundTransparency = if def then 0 else 0.5,
				})
			end
		end

		local remaining = (storm.EndsAt or 0) - now
		local phase = storm.Phase
		local short = if storm.Storm then string.upper(storm.Storm) else "STORM"
		sweep.Rotation = (now * 120) % 360
		if phase == "Storm" then
			blip.Visible = true
			local pulse = 34 + math.sin(now * 6) * 6
			blip.Size = UDim2.fromOffset(pulse, pulse)
			blip.Position = UDim2.fromScale(0.5, 0.5)
			blip.BackgroundColor3 = RED
			blip.BackgroundTransparency = 0.25
			radarTitle.Text = "IN CELL: " .. short
			radarTitle.TextColor3 = RED
			radarTime.Text = Kit.clock(remaining)
			radarTime.TextColor3 = RED
			tag.BackgroundColor3 = RED
			tagText.Text = "SEVERE"
			tagText.TextColor3 = WHITE
		elseif phase == "Warning" then
			blip.Visible = true
			local d = math.clamp(remaining / WARNING_SECONDS, 0.12, 0.95) * R
			blip.Size = UDim2.fromOffset(16, 16)
			blip.Position = UDim2.new(0.5, d * 0.7, 0.5, -d * 0.7)
			blip.BackgroundColor3 = AMBER
			blip.BackgroundTransparency = 0
			radarTitle.Text = "INBOUND: " .. short
			radarTitle.TextColor3 = AMBER
			radarTime.Text = Kit.clock(remaining)
			radarTime.TextColor3 = AMBER
			tag.BackgroundColor3 = AMBER
			tagText.Text = "STORM WARNING"
			tagText.TextColor3 = NAVY
		else
			blip.Visible = false
			radarTitle.Text = "CLEAR · NEXT CELL"
			radarTitle.TextColor3 = CYAN_DIM
			radarTime.Text = Kit.clock(remaining)
			radarTime.TextColor3 = WHITE
			tag.BackgroundColor3 = CYAN
			tagText.Text = "FIELD OPS"
			tagText.TextColor3 = NAVY
		end
		local line = objective:upper()
		if hint then
			line = hint:upper() .. "   ///   " .. line
		end
		if line ~= tickerKey then
			tickerKey = line
			tickerStart = now
			ticker.Text = line .. "   ///   " .. line
		end
		-- Scroll only when the line doesn't fit.
		-- Absolute sizes include the UI scale; the scope's known size converts back.
		local k = math.max(0.01, scope.AbsoluteSize.X / (2 * R))
		local width = band.AbsoluteSize.X / k
		local half = ticker.AbsoluteSize.X / k / 2
		if half > width - 32 then
			local x = ((now - tickerStart) * 70) % (half + 0.0001)
			ticker.Position = UDim2.fromOffset(16 - x, 2)
		else
			ticker.Text = line
			ticker.Position = UDim2.fromOffset(16, 2)
		end
		boost.Visible = (s.BoostRemaining or 0) > 0
	end

	------------------------------------------------------------------ Overlays

	function view.clearOverlay()
		overlay:ClearAllChildren()
	end

	function view.shop(s: any)
		local layer = Kit.box(overlay, {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = NAVY,
			BackgroundTransparency = 0.35,
			ZIndex = 50,
			Name = "Shop",
		})
		local panel = glass(layer, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(840, 430),
			BackgroundTransparency = 0.08,
			ZIndex = 51,
		})
		text(panel, {
			Position = UDim2.fromOffset(28, 18),
			Size = UDim2.fromOffset(500, 30),
			Font = WIDE,
			TextSize = 24,
			Text = "EQUIPMENT LOADOUT",
			ZIndex = 53,
		})
		text(panel, {
			Position = UDim2.fromOffset(28, 50),
			Size = UDim2.fromOffset(500, 18),
			Font = MONO,
			TextSize = 13,
			TextColor3 = CYAN_DIM,
			Text = "FIELD KIT // SELECT A MODULE TO UPGRADE",
			ZIndex = 53,
		})
		text(panel, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -90, 0, 18),
			Size = UDim2.fromOffset(220, 16),
			Font = WIDE,
			TextSize = 12,
			TextColor3 = CYAN_DIM,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = "FUNDS",
			ZIndex = 53,
		})
		text(panel, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -90, 0, 34),
			Size = UDim2.fromOffset(220, 30),
			Font = MONO,
			TextSize = 28,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = Kit.comma(s and s.Coins or 0),
			ZIndex = 53,
		})
		local close = glass(panel, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -18, 0, 18),
			Size = UDim2.fromOffset(56, 48),
			ZIndex = 53,
		})
		text(close, {
			Size = UDim2.fromScale(1, 1),
			Font = WIDE,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = "X",
			ZIndex = 55,
		})
		Kit.box(panel, {
			Position = UDim2.fromOffset(28, 80),
			Size = UDim2.new(1, -56, 0, 1),
			BackgroundColor3 = CYAN_DIM,
			BackgroundTransparency = 0.4,
			ZIndex = 52,
		})

		local gear = Kit.gear(s)
		local coins = s and s.Coins or 0
		local selected = 1
		for i, g in gear do
			if g.Cost then
				selected = i
				break
			end
		end
		for i, g in gear do
			local on = i == selected
			local row = Kit.box(panel, {
				Position = UDim2.fromOffset(28, 96 + (i - 1) * 104),
				Size = UDim2.fromOffset(330, 92),
				BackgroundColor3 = if on then Color3.fromRGB(20, 52, 72) else NAVY,
				BackgroundTransparency = if on then 0 else 0.4,
				ZIndex = 52,
			})
			if on then
				Kit.box(row, { Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = CYAN, ZIndex = 53 })
			end
			local iconBox = Kit.box(row, {
				Position = UDim2.fromOffset(16, 16),
				Size = UDim2.fromOffset(60, 60),
				BackgroundTransparency = 1,
				ZIndex = 53,
			})
			Kit.brackets(iconBox, if on then CYAN else CYAN_DIM, 12, 2, 54)
			local icon = UI.upgradeIcon(g.Id, iconBox, 40)
			icon.Position = UDim2.fromOffset(10, 10)
			for _, d in icon:GetDescendants() do
				if d:IsA("GuiObject") then
					d.ZIndex = 55
				end
			end
			text(row, {
				Position = UDim2.fromOffset(92, 16),
				Size = UDim2.fromOffset(230, 20),
				Font = WIDE,
				TextSize = 14,
				Text = g.Name:upper(),
				ZIndex = 53,
			})
			text(row, {
				Position = UDim2.fromOffset(92, 42),
				Size = UDim2.fromOffset(120, 20),
				Font = MONO,
				TextSize = 15,
				TextColor3 = CYAN_DIM,
				Text = ("MK %d/%d"):format(g.Level, g.MaxLevel),
				ZIndex = 53,
			})
			text(row, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -14, 0, 42),
				Size = UDim2.fromOffset(120, 20),
				Font = MONO,
				TextSize = 17,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = if g.Cost == nil then CYAN_DIM elseif coins >= g.Cost then CYAN else RED,
				Text = if g.Cost then Kit.comma(g.Cost) else "MAX",
				ZIndex = 53,
			})
		end

		-- Detail of the selected module.
		local g = gear[selected]
		local def = Config.Upgrades[g.Id]
		local detail = Kit.box(panel, {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(392, 96),
			Size = UDim2.fromOffset(420, 300),
			ZIndex = 52,
		})
		text(detail, {
			Size = UDim2.fromOffset(420, 34),
			Font = WIDE,
			TextSize = 26,
			Text = g.Name:upper(),
			ZIndex = 53,
		})
		text(detail, {
			Position = UDim2.fromOffset(0, 38),
			Size = UDim2.fromOffset(420, 22),
			Font = BODY,
			TextSize = 18,
			TextColor3 = CYAN_DIM,
			Text = def.Description,
			ZIndex = 53,
		})
		local statName = if g.Id == "Backpack"
			then "CAPACITY"
			elseif g.Id == "Boots" then "SPEED"
			else "DAMAGE REDUCTION"
		text(detail, {
			Position = UDim2.fromOffset(0, 84),
			Size = UDim2.fromOffset(240, 16),
			Font = WIDE,
			TextSize = 12,
			TextColor3 = CYAN_DIM,
			Text = statName,
			ZIndex = 53,
		})
		text(detail, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 78),
			Size = UDim2.fromOffset(240, 24),
			Font = MONO,
			TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = Kit.gearText(g):upper(),
			ZIndex = 53,
		})
		local bars = Kit.box(detail, {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 110),
			Size = UDim2.fromOffset(420, 26),
			ZIndex = 53,
		})
		Kit.list(bars, 4, true)
		local levels = #def.Values
		local w = math.floor((420 - (levels - 1) * 4) / levels)
		for l = 1, levels do
			local lit = l <= g.Level + 1
			local nextOne = l == g.Level + 2
			Kit.box(bars, {
				LayoutOrder = l,
				Size = UDim2.fromOffset(w, 26),
				BackgroundColor3 = if lit then CYAN elseif nextOne then AMBER else GRID,
				BackgroundTransparency = if lit or nextOne then 0 else 0.4,
				ZIndex = 54,
			})
		end
		for i, item in { { CYAN, "INSTALLED" }, { AMBER, "NEXT MK" }, { GRID, "LOCKED" } } do
			local x = (i - 1) * 130
			Kit.box(detail, {
				Position = UDim2.fromOffset(x, 145),
				Size = UDim2.fromOffset(10, 10),
				BackgroundColor3 = item[1],
				ZIndex = 53,
			})
			text(detail, {
				Position = UDim2.fromOffset(x + 16, 142),
				Size = UDim2.fromOffset(110, 16),
				Font = MONO,
				TextSize = 13,
				TextColor3 = CYAN_DIM,
				Text = item[2],
				ZIndex = 53,
			})
		end
		Kit.box(detail, {
			Position = UDim2.fromOffset(0, 196),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = CYAN_DIM,
			BackgroundTransparency = 0.4,
			ZIndex = 53,
		})
		text(detail, {
			Position = UDim2.fromOffset(0, 214),
			Size = UDim2.fromOffset(120, 16),
			Font = WIDE,
			TextSize = 12,
			TextColor3 = CYAN_DIM,
			Text = "COST",
			ZIndex = 53,
		})
		text(detail, {
			Position = UDim2.fromOffset(0, 232),
			Size = UDim2.fromOffset(180, 40),
			Font = MONO,
			TextSize = 36,
			Text = if g.Cost then Kit.comma(g.Cost) else "—",
			ZIndex = 53,
		})
		local afford = g.Cost ~= nil and coins >= g.Cost
		local install = Kit.box(detail, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 218),
			Size = UDim2.fromOffset(220, 62),
			BackgroundColor3 = if afford then CYAN else NAVY,
			BackgroundTransparency = if afford then 0 else 0.3,
			ZIndex = 53,
		})
		if not afford then
			Kit.stroke(install, RED, 1)
		end
		text(install, {
			Size = UDim2.fromScale(1, 1),
			Font = WIDE,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = if afford then NAVY else RED,
			Text = if g.Cost == nil
				then "FULLY UPGRADED"
				elseif afford then "INSTALL"
				else ("SHORT %s"):format(Kit.comma(g.Cost - coins)),
			ZIndex = 54,
		})
		panel.Position = UDim2.new(0.5, 0, 0.5, 24)
		panel.BackgroundTransparency = 1
		Kit.tween(panel, 0.25, { Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 0.08 })
	end

	function view.receipt(r: any, transient: boolean?)
		local old = overlay:FindFirstChild("Receipt")
		if old then
			old:Destroy()
		end
		local layer = Kit.box(
			overlay,
			{ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, Name = "Receipt" }
		)
		local shown = math.min(#r.Lines, 5)
		local rows = shown + #r.Multipliers
		local height = 214 + rows * 26
		local panel = glass(layer, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 20),
			Size = UDim2.fromOffset(430, height),
			BackgroundTransparency = 0.08,
			ZIndex = 51,
		})
		text(panel, {
			Position = UDim2.fromOffset(22, 16),
			Size = UDim2.fromOffset(260, 26),
			Font = WIDE,
			TextSize = 20,
			Text = "HAUL REPORT",
			ZIndex = 53,
		})
		text(panel, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -22, 0, 20),
			Size = UDim2.fromOffset(140, 18),
			Font = MONO,
			TextSize = 14,
			TextColor3 = CYAN_DIM,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = ("#%04d"):format(os.time() % 10000),
			ZIndex = 53,
		})
		text(panel, {
			Position = UDim2.fromOffset(22, 44),
			Size = UDim2.fromOffset(300, 16),
			Font = WIDE,
			TextSize = 10,
			TextColor3 = CYAN,
			Text = "● TRANSFER COMPLETE",
			ZIndex = 53,
		})
		local cols = { { "QTY", 22, 40 }, { "ITEM", 66, 200 }, { "CAT", 270, 50 }, { "VALUE", 330, 78 } }
		for _, c in cols do
			text(panel, {
				Position = UDim2.fromOffset(c[2], 74),
				Size = UDim2.fromOffset(c[3], 16),
				Font = WIDE,
				TextSize = 10,
				TextColor3 = CYAN_DIM,
				TextXAlignment = if c[1] == "VALUE"
					then Enum.TextXAlignment.Right
					else Enum.TextXAlignment.Left,
				Text = c[1],
				ZIndex = 53,
			})
		end
		Kit.box(panel, {
			Position = UDim2.fromOffset(22, 94),
			Size = UDim2.new(1, -44, 0, 1),
			BackgroundColor3 = CYAN_DIM,
			BackgroundTransparency = 0.4,
			ZIndex = 52,
		})
		local y = 100
		local function row(cells: { string }, color: Color3?, catCol: Color3?)
			for i, c in cols do
				text(panel, {
					Position = UDim2.fromOffset(c[2], y),
					Size = UDim2.fromOffset(c[3], 24),
					Font = MONO,
					TextSize = 16,
					TextColor3 = if i == 3 and catCol then catCol else color or WHITE,
					TextXAlignment = if i == 4 then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Text = cells[i] or "",
					ZIndex = 53,
				})
			end
			y += 26
		end
		local shares: { [string]: number } = {}
		local base = 0
		for _, entry in r.Lines do
			local d = Config.Loot[entry.Id]
			shares[d.Rarity] = (shares[d.Rarity] or 0) + entry.Value * entry.Count
			base += entry.Value * entry.Count
		end
		for i = 1, shown do
			local entry = r.Lines[i]
			local d = Config.Loot[entry.Id]
			row({
				tostring(entry.Count),
				d.Name:upper(),
				tostring(Kit.tierIndex(d.Rarity)),
				tostring(entry.Value * entry.Count),
			}, nil, catColor(d.Rarity))
		end
		for _, bonus in r.Multipliers do
			row({ "×", bonus.Name:upper(), "", "x" .. tostring(bonus.Factor) }, AMBER)
		end
		-- Value composition by category.
		local bar = Kit.box(panel, {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(22, y + 10),
			Size = UDim2.new(1, -44, 0, 10),
			ZIndex = 53,
		})
		Kit.list(bar, 2, true)
		for i, tier in Kit.Tiers do
			local v = shares[tier]
			if v and base > 0 then
				Kit.box(bar, {
					LayoutOrder = i,
					Size = UDim2.new(v / base, -2, 1, 0),
					BackgroundColor3 = catColor(tier),
					ZIndex = 54,
				})
			end
		end
		text(panel, {
			Position = UDim2.fromOffset(22, y + 30),
			Size = UDim2.fromOffset(200, 16),
			Font = WIDE,
			TextSize = 12,
			TextColor3 = CYAN_DIM,
			Text = "NET CREDIT",
			ZIndex = 53,
		})
		text(panel, {
			Position = UDim2.fromOffset(22, y + 46),
			Size = UDim2.fromOffset(240, 48),
			Font = MONO,
			TextSize = 44,
			TextColor3 = CYAN,
			Text = "+" .. Kit.comma(r.Total),
			ZIndex = 53,
		})
		text(panel, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -22, 0, y + 30),
			Size = UDim2.fromOffset(160, 16),
			Font = WIDE,
			TextSize = 12,
			TextColor3 = CYAN_DIM,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = "BALANCE",
			ZIndex = 53,
		})
		text(panel, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -22, 0, y + 52),
			Size = UDim2.fromOffset(160, 30),
			Font = MONO,
			TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = Kit.comma(r.Balance),
			ZIndex = 53,
		})
		panel.Position = UDim2.new(0.5, 0, 0.5, 60)
		Kit.tween(panel, 0.3, { Position = UDim2.new(0.5, 0, 0.5, 20) })
		if transient then
			task.delay(5, function()
				if layer.Parent then
					layer:Destroy()
				end
			end)
		end
	end

	function view.rarity(id: string, transient: boolean?)
		local old = overlay:FindFirstChild("Rarity")
		if old then
			old:Destroy()
		end
		local def = Config.Loot[id]
		local color = catColor(def.Rarity)
		local cat = Kit.tierIndex(def.Rarity)
		local layer = Kit.box(
			overlay,
			{ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, Name = "Rarity" }
		)
		local lock = Kit.box(layer, {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, -170, 0.36, 0),
			Size = UDim2.fromOffset(120, 120),
			ZIndex = 51,
		})
		local inner = Kit.box(lock, {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = NAVY,
			BackgroundTransparency = 0.15,
			ZIndex = 51,
		})
		Kit.brackets(inner, color, 26, 4, 53)
		text(inner, {
			Position = UDim2.fromOffset(0, 18),
			Size = UDim2.new(1, 0, 0, 16),
			Font = WIDE,
			TextSize = 12,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = "CAT",
			ZIndex = 53,
		})
		text(inner, {
			Position = UDim2.fromOffset(0, 32),
			Size = UDim2.new(1, 0, 0, 70),
			Font = WIDE,
			TextSize = 64,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = tostring(cat),
			ZIndex = 53,
		})
		local info = Kit.box(layer, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0.5, -96, 0.36, 0),
			Size = UDim2.fromOffset(340, 120),
			BackgroundColor3 = NAVY,
			BackgroundTransparency = 0.15,
			ZIndex = 51,
		})
		Kit.box(info, { Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = color, ZIndex = 52 })
		text(info, {
			Position = UDim2.fromOffset(18, 14),
			Size = UDim2.fromOffset(300, 16),
			Font = WIDE,
			TextSize = 12,
			TextColor3 = color,
			Text = "SIGNAL ACQUIRED · " .. def.Rarity:upper(),
			ZIndex = 53,
		})
		text(info, {
			Position = UDim2.fromOffset(18, 34),
			Size = UDim2.fromOffset(300, 32),
			Font = WIDE,
			TextSize = 24,
			Text = def.Name:upper(),
			ZIndex = 53,
		})
		text(info, {
			Position = UDim2.fromOffset(18, 68),
			Size = UDim2.fromOffset(140, 20),
			Font = MONO,
			TextSize = 18,
			TextColor3 = CYAN,
			Text = ("%d CR"):format(def.Value),
			ZIndex = 53,
		})
		local meter = Kit.box(info, {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(18, 96),
			Size = UDim2.fromOffset(300, 10),
			ZIndex = 53,
		})
		Kit.list(meter, 4, true)
		for i = 1, 5 do
			Kit.box(meter, {
				LayoutOrder = i,
				Size = UDim2.fromOffset(56, 10),
				BackgroundColor3 = if i <= cat then color else GRID,
				BackgroundTransparency = if i <= cat then 0 else 0.4,
				ZIndex = 54,
			})
		end
		-- Lock-on: brackets close in from wide.
		local scale = Kit.new("UIScale", { Parent = lock, Scale = 1.8 })
		Kit.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Quint)
		info.Position = UDim2.new(0.5, -96, 0.36, 0) + UDim2.fromOffset(40, 0)
		Kit.tween(info, 0.3, { Position = UDim2.new(0.5, -96, 0.36, 0) })

		if not transient then
			local scaleBar = Kit.box(layer, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -84),
				Size = UDim2.fromOffset(640, 70),
				BackgroundColor3 = NAVY,
				BackgroundTransparency = 0.15,
				ZIndex = 51,
			})
			Kit.brackets(scaleBar, CYAN_DIM, 12, 2, 53)
			for i, tier in Kit.Tiers do
				local x = (i - 1) / 5
				Kit.box(scaleBar, {
					Position = UDim2.new(x, 10, 0, 12),
					Size = UDim2.new(0.2, -16, 0, 8),
					BackgroundColor3 = catColor(tier),
					ZIndex = 52,
				})
				text(scaleBar, {
					Position = UDim2.new(x, 10, 0, 26),
					Size = UDim2.new(0.2, -16, 0, 16),
					Font = WIDE,
					TextSize = 12,
					TextColor3 = catColor(tier),
					Text = "CAT " .. i,
					ZIndex = 52,
				})
				text(scaleBar, {
					Position = UDim2.new(x, 10, 0, 44),
					Size = UDim2.new(0.2, -16, 0, 16),
					Font = BODY,
					TextSize = 15,
					TextColor3 = CYAN_DIM,
					Text = tier,
					ZIndex = 52,
				})
			end
		else
			task.delay(3, function()
				if layer.Parent then
					layer:Destroy()
				end
			end)
		end
	end

	return view
end

return Study
