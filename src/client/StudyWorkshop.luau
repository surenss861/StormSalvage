-- UI study 3: Scrapyard Workshop. Everything is a physical object from the salvage yard: a
-- cardboard cash tag, a wooden crate for the bag, a tin sign hung on strings for the storm,
-- sticky notes for objectives, a pegboard with hanging tool tags for the shop, a clipboard
-- tally sheet for sales, and rarity as coloured tape. Warm, handmade and tactile; it belongs
-- to this game's world rather than to a generic game-UI vocabulary.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UI = require(script.Parent:WaitForChild("UI"))

local Study = {}

local KRAFT = Color3.fromRGB(204, 166, 116)
local KRAFT_EDGE = Color3.fromRGB(150, 112, 70)
local MANILA = Color3.fromRGB(240, 218, 166)
local TAPE = Color3.fromRGB(238, 228, 190)
local MARKER = Color3.fromRGB(34, 30, 28)
local PENCIL = Color3.fromRGB(96, 92, 88)
local RED_PEN = Color3.fromRGB(206, 40, 36)
local TIN = Color3.fromRGB(178, 184, 188)
local TIN_DARK = Color3.fromRGB(110, 116, 122)
local WOOD = Color3.fromRGB(164, 112, 64)
local WOOD_DARK = Color3.fromRGB(116, 76, 40)
local PEG = Color3.fromRGB(150, 106, 62)
local NOTE = Color3.fromRGB(255, 228, 112)
local NOTE_PINK = Color3.fromRGB(255, 176, 170)
local PAPER = Color3.fromRGB(250, 248, 238)
local RULE = Color3.fromRGB(170, 200, 230)
local ORANGE = Color3.fromRGB(255, 132, 40)

local HAND = Enum.Font.PermanentMarker
local NOTEHAND = Enum.Font.PatrickHand
local TILE = Enum.Font.GothamBlack

local GRADE = {
	Common = "COMMON",
	Uncommon = "UNCOMMON",
	Rare = "RARE FIND",
	Epic = "EPIC FIND!",
	Legendary = "LEGENDARY!!",
}

function Study.build(root: Frame, Kit: any, _opts: any)
	local view = {}

	local function tape(
		parent: Instance,
		pos: UDim2,
		size: Vector2,
		rotation: number,
		color: Color3?,
		z: number?
	): Frame
		local t = Kit.box(parent, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = pos,
			Size = UDim2.fromOffset(size.X, size.Y),
			Rotation = rotation,
			BackgroundColor3 = color or TAPE,
			BackgroundTransparency = if color then 0.05 else 0.12,
			ZIndex = z or 5,
		})
		return t
	end

	local function hand(parent: Instance, props: { [string]: any }): TextLabel
		props.Font = props.Font or HAND
		props.TextColor3 = props.TextColor3 or MARKER
		return Kit.label(parent, props)
	end

	local function rivet(parent: Instance, pos: UDim2, z: number?)
		local r = Kit.box(parent, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = pos,
			Size = UDim2.fromOffset(8, 8),
			BackgroundColor3 = TIN_DARK,
			ZIndex = z or 3,
		})
		Kit.round(r)
		return r
	end

	------------------------------------------------------------------ HUD

	-- Cash tag.
	local cash = Kit.box(root, {
		Position = UDim2.fromOffset(20, 16),
		Size = UDim2.fromOffset(200, 72),
		Rotation = -2,
		BackgroundColor3 = KRAFT,
	})
	Kit.corner(cash, 4)
	Kit.stroke(cash, KRAFT_EDGE, 2)
	tape(cash, UDim2.fromOffset(8, 6), Vector2.new(54, 18), -38)
	hand(cash, {
		Position = UDim2.fromOffset(18, 6),
		Size = UDim2.fromOffset(100, 18),
		Font = NOTEHAND,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = PENCIL,
		Text = "cash",
		ZIndex = 2,
	})
	local cashText = hand(cash, {
		Position = UDim2.fromOffset(18, 22),
		Size = UDim2.new(1, -30, 0, 44),
		TextSize = 38,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "0",
		ZIndex = 2,
	})

	-- Crate.
	local crate = Kit.box(root, {
		Position = UDim2.fromOffset(18, 102),
		Size = UDim2.fromOffset(250, 84),
		BackgroundColor3 = WOOD,
	})
	Kit.stroke(crate, WOOD_DARK, 3)
	for _, y in { 0.33, 0.66 } do
		Kit.box(crate, {
			Position = UDim2.fromScale(0, y),
			Size = UDim2.new(1, 0, 0, 2),
			BackgroundColor3 = WOOD_DARK,
			ZIndex = 1,
		})
	end
	for _, x in { 0, 1 } do
		Kit.box(crate, {
			AnchorPoint = Vector2.new(x, 0),
			Position = UDim2.fromScale(x, 0),
			Size = UDim2.new(0, 10, 1, 0),
			BackgroundColor3 = WOOD_DARK,
			ZIndex = 2,
		})
	end
	local crateLabel = tape(crate, UDim2.new(1, -46, 0, 2), Vector2.new(84, 28), 3, nil, 6)
	local crateCount = hand(crateLabel, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 20,
		Text = "",
		ZIndex = 7,
	})
	local slots = Kit.box(crate, {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 30),
		Size = UDim2.new(1, -36, 0, 44),
		ZIndex = 3,
	})
	local slotKey = ""
	local crateWorth = hand(crate, {
		Position = UDim2.fromOffset(16, 4),
		Size = UDim2.fromOffset(140, 22),
		Font = NOTEHAND,
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 240, 210),
		Text = "",
		ZIndex = 3,
	})

	-- Tin storm sign hung on two strings.
	local signHolder = Kit.box(root, {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -10),
		Size = UDim2.fromOffset(300, 140),
	})
	local swing = Kit.box(signHolder, {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(1, 1),
	})
	Kit.line(swing, Vector2.new(70, 0), Vector2.new(60, 36), 2, MARKER)
	Kit.line(swing, Vector2.new(230, 0), Vector2.new(240, 36), 2, MARKER)
	local sign = Kit.box(swing, {
		Position = UDim2.fromOffset(10, 34),
		Size = UDim2.fromOffset(280, 98),
		BackgroundColor3 = TIN,
		ZIndex = 2,
	})
	Kit.corner(sign, 6)
	Kit.stroke(sign, TIN_DARK, 3)
	Kit.gradient(sign, Color3.fromRGB(214, 220, 224), Color3.fromRGB(160, 166, 172), 100)
	for _, p in
		{
			UDim2.fromOffset(12, 12),
			UDim2.new(1, -12, 0, 12),
			UDim2.new(0, 12, 1, -12),
			UDim2.new(1, -12, 1, -12),
		}
	do
		rivet(sign, p, 3)
	end
	local signTitle = hand(sign, {
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 30),
		TextSize = 26,
		Text = "",
		ZIndex = 3,
	})
	local tiles = Kit.box(sign, {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 40),
		Size = UDim2.fromOffset(170, 48),
		ZIndex = 3,
	})
	Kit.list(tiles, 4, true, Enum.HorizontalAlignment.Center)
	local tileLabels = {}
	for i = 1, 4 do
		local t = Kit.box(tiles, {
			LayoutOrder = if i <= 2 then i else i + 1,
			Size = UDim2.fromOffset(36, 48),
			BackgroundColor3 = Color3.fromRGB(36, 36, 38),
			ZIndex = 4,
		})
		Kit.corner(t, 4)
		Kit.box(t, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Color3.fromRGB(14, 14, 16),
			BackgroundTransparency = 0.3,
			ZIndex = 6,
		})
		tileLabels[i] = Kit.label(t, {
			Size = UDim2.fromScale(1, 1),
			Font = TILE,
			TextSize = 32,
			TextColor3 = Color3.fromRGB(246, 242, 230),
			Text = "0",
			ZIndex = 5,
		})
	end
	hand(tiles, { LayoutOrder = 3, Size = UDim2.fromOffset(12, 48), TextSize = 30, Text = ":", ZIndex = 4 })

	-- Sticky notes, left side (clear of the phone thumbstick).
	local notes = Kit.box(root, {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 204),
		Size = UDim2.fromOffset(250, 230),
	})
	local todo = Kit.box(notes, {
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(230, 100),
		Rotation = 2,
		BackgroundColor3 = NOTE,
	})
	Kit.gradient(todo, NOTE, Color3.fromRGB(246, 212, 86), 90)
	tape(todo, UDim2.new(0.5, 0, 0, 0), Vector2.new(70, 20), -4)
	hand(todo, {
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.fromOffset(200, 22),
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "TO DO:",
		ZIndex = 2,
	})
	local box = Kit.box(todo, {
		Position = UDim2.fromOffset(16, 44),
		Size = UDim2.fromOffset(16, 16),
		BackgroundTransparency = 1,
		ZIndex = 2,
	})
	Kit.stroke(box, MARKER, 2)
	local todoText = hand(todo, {
		Position = UDim2.fromOffset(40, 36),
		Size = UDim2.new(1, -50, 0, 56),
		Font = NOTEHAND,
		TextSize = 22,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
		ZIndex = 2,
	})
	local warnNote = Kit.box(notes, {
		Position = UDim2.fromOffset(14, 112),
		Size = UDim2.fromOffset(230, 96),
		Rotation = -3,
		BackgroundColor3 = NOTE_PINK,
	})
	tape(warnNote, UDim2.new(0.5, 0, 0, 0), Vector2.new(70, 20), 5)
	local warnText = hand(warnNote, {
		Position = UDim2.fromOffset(12, 14),
		Size = UDim2.new(1, -24, 1, -20),
		Font = NOTEHAND,
		TextSize = 21,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = RED_PEN,
		Text = "",
		ZIndex = 2,
	})

	-- Workbench tag + settings plate, right edge.
	local benchHolder = Kit.box(root, {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.56, 0),
		Size = UDim2.fromOffset(140, 96),
	})
	Kit.line(benchHolder, Vector2.new(70, 0), Vector2.new(40, 26), 2, MARKER)
	local bench = Kit.box(benchHolder, {
		Position = UDim2.fromOffset(6, 22),
		Size = UDim2.fromOffset(128, 70),
		Rotation = 4,
		BackgroundColor3 = MANILA,
	})
	Kit.corner(bench, 8)
	Kit.stroke(bench, KRAFT_EDGE, 2)
	local hole = Kit.box(bench, {
		Position = UDim2.fromOffset(24, 8),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Color3.fromRGB(250, 244, 230),
		ZIndex = 2,
	})
	Kit.round(hole)
	Kit.stroke(hole, KRAFT_EDGE, 3)
	hand(bench, {
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = 20,
		Text = "UPGRADES",
		ZIndex = 2,
	})
	local tin = Kit.box(root, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -34, 0.56, -88),
		Size = UDim2.fromOffset(60, 60),
		BackgroundColor3 = TIN,
	})
	Kit.corner(tin, 6)
	Kit.stroke(tin, TIN_DARK, 3)
	for _, p in
		{ UDim2.fromOffset(8, 8), UDim2.new(1, -8, 0, 8), UDim2.new(0, 8, 1, -8), UDim2.new(1, -8, 1, -8) }
	do
		rivet(tin, p, 2)
	end
	local sliders = UI.slidersIcon(tin, 26)
	sliders.Position = UDim2.new(0.5, -13, 0.5, -13)
	for _, d in sliders:GetDescendants() do
		if d:IsA("Frame") and d.BackgroundTransparency < 1 then
			d.BackgroundColor3 = MARKER
		elseif d:IsA("UIStroke") then
			d.Color = MARKER
		end
	end

	-- Boost: an orange price-gun sticker on the cash tag.
	local boost = Kit.box(root, {
		Position = UDim2.fromOffset(196, 14),
		Size = UDim2.fromOffset(64, 64),
		Rotation = 12,
		BackgroundColor3 = ORANGE,
	})
	Kit.round(boost)
	hand(boost, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 18,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "2X!",
		ZIndex = 2,
	})

	local overlay = Kit.box(root, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50 })

	function view.hud(s: any, storm: any, now: number, objective: string, hint: string?)
		cashText.Text = Kit.comma(s.Coins)
		crateCount.Text = ("%d / %d"):format(#s.Carried, s.Capacity)
		crateWorth.Text = if s.CarriedValue and s.CarriedValue > 0
			then ("worth %d"):format(s.CarriedValue)
			else "empty"
		local key = table.concat(s.Carried, ",") .. "/" .. s.Capacity
		if key ~= slotKey then
			slotKey = key
			slots:ClearAllChildren()
			Kit.list(slots, 4, true)
			local w = math.clamp(math.floor((214 - (s.Capacity - 1) * 4) / s.Capacity), 8, 40)
			for i = 1, s.Capacity do
				local id = s.Carried[i]
				local def = id and Config.Loot[id]
				local slot = Kit.box(slots, {
					LayoutOrder = i,
					Size = UDim2.fromOffset(w, 40),
					Rotation = if def then (i % 3 - 1) * 4 else 0,
					BackgroundColor3 = if def then Config.RarityColors[def.Rarity] else WOOD_DARK,
					BackgroundTransparency = if def then 0 else 0.55,
					ZIndex = 4,
				})
				if def then
					Kit.stroke(slot, MARKER, 1, 0.5)
				end
			end
		end

		local remaining = math.max(0, math.ceil((storm.EndsAt or 0) - now))
		local phase = storm.Phase
		local name = storm.Storm and Config.Storms[storm.Storm] and Config.Storms[storm.Storm].DisplayName
			or "STORM"
		if phase == "Storm" then
			signTitle.Text = name .. "!"
			signTitle.TextColor3 = RED_PEN
			sign.BackgroundColor3 = Color3.fromRGB(230, 200, 120)
		elseif phase == "Warning" then
			signTitle.Text = name .. " IN"
			signTitle.TextColor3 = RED_PEN
			sign.BackgroundColor3 = TIN
		else
			signTitle.Text = "ALL CLEAR FOR"
			signTitle.TextColor3 = MARKER
			sign.BackgroundColor3 = TIN
		end
		local m, sec = remaining // 60, remaining % 60
		local digits = ("%02d%02d"):format(math.min(m, 99), sec)
		for i = 1, 4 do
			tileLabels[i].Text = digits:sub(i, i)
		end
		local amp = if phase == "Storm" then 5 elseif phase == "Warning" then 2.5 else 0.8
		swing.Rotation = math.sin(now * (if phase == "Storm" then 3 else 1.4)) * amp
		todoText.Text = objective
		warnNote.Visible = hint ~= nil
		warnText.Text = hint and ("!! " .. hint) or ""
		boost.Visible = (s.BoostRemaining or 0) > 0
	end

	------------------------------------------------------------------ Overlays

	function view.clearOverlay()
		overlay:ClearAllChildren()
	end

	function view.shop(s: any)
		local layer = Kit.box(overlay, {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(20, 14, 8),
			BackgroundTransparency = 0.4,
			ZIndex = 50,
			Name = "Shop",
		})
		local board = Kit.box(layer, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.52),
			Size = UDim2.fromOffset(800, 440),
			BackgroundColor3 = PEG,
			ClipsDescendants = true,
			ZIndex = 51,
		})
		Kit.stroke(board, WOOD_DARK, 6)
		for x = 1, 24 do
			for y = 1, 13 do
				local h = Kit.box(board, {
					Position = UDim2.fromOffset(x * 32 - 6, y * 32 - 6),
					Size = UDim2.fromOffset(6, 6),
					BackgroundColor3 = Color3.fromRGB(92, 62, 34),
					ZIndex = 51,
				})
				Kit.round(h)
			end
		end
		local header = tape(layer, UDim2.new(0.5, 0, 0.52, -214), Vector2.new(440, 54), -1.5, nil, 60)
		hand(
			header,
			{ Size = UDim2.fromScale(1, 1), TextSize = 32, Text = "WORKBENCH UPGRADES", ZIndex = 61 }
		)
		local cashNote = Kit.box(board, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -86, 0, 26),
			Size = UDim2.fromOffset(150, 52),
			Rotation = 3,
			BackgroundColor3 = KRAFT,
			ZIndex = 56,
		})
		Kit.stroke(cashNote, KRAFT_EDGE, 2)
		hand(cashNote, {
			Size = UDim2.fromScale(1, 1),
			TextSize = 26,
			Text = Kit.comma(s and s.Coins or 0) .. " cash",
			ZIndex = 57,
		})
		local close = Kit.box(board, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -20, 0, 22),
			Size = UDim2.fromOffset(54, 54),
			BackgroundColor3 = TIN,
			ZIndex = 56,
		})
		Kit.corner(close, 6)
		Kit.stroke(close, TIN_DARK, 3)
		hand(close, { Size = UDim2.fromScale(1, 1), TextSize = 30, Text = "X", ZIndex = 57 })

		local coins = s and s.Coins or 0
		local tilt = { -3, 2, -1.5 }
		for i, g in Kit.gear(s) do
			local cx = 150 + (i - 1) * 240
			-- Peg and string.
			local peg = Kit.box(board, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(cx, 96),
				Size = UDim2.fromOffset(14, 14),
				BackgroundColor3 = TIN_DARK,
				ZIndex = 58,
			})
			Kit.round(peg)
			local card = Kit.box(board, {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromOffset(cx, 112),
				Size = UDim2.fromOffset(206, 300),
				Rotation = tilt[i],
				BackgroundColor3 = MANILA,
				ZIndex = 54,
			})
			Kit.corner(card, 10)
			Kit.stroke(card, KRAFT_EDGE, 2)
			Kit.line(board, Vector2.new(cx, 96), Vector2.new(cx - tilt[i] * 1.5, 128), 2, MARKER, 57)
			local ring = Kit.box(card, {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 8),
				Size = UDim2.fromOffset(20, 20),
				BackgroundColor3 = PEG,
				ZIndex = 55,
			})
			Kit.round(ring)
			Kit.stroke(ring, KRAFT_EDGE, 4)
			local icon = UI.upgradeIcon(g.Id, card, 64)
			icon.Position = UDim2.new(0.5, -32, 0, 38)
			for _, d in icon:GetDescendants() do
				if d:IsA("GuiObject") then
					d.ZIndex = 56
				end
			end
			hand(card, {
				Position = UDim2.fromOffset(8, 108),
				Size = UDim2.new(1, -16, 0, 30),
				TextSize = 24,
				Text = g.Name,
				ZIndex = 55,
			})
			-- Level as punched holes.
			local holes = Kit.box(card, {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, 144),
				Size = UDim2.new(1, 0, 0, 16),
				ZIndex = 55,
			})
			Kit.list(holes, 8, true, Enum.HorizontalAlignment.Center)
			for l = 1, g.MaxLevel do
				local h = Kit.box(holes, {
					LayoutOrder = l,
					Size = UDim2.fromOffset(14, 14),
					BackgroundColor3 = if l <= g.Level then MARKER else MANILA,
					ZIndex = 56,
				})
				Kit.round(h)
				Kit.stroke(h, MARKER, 2)
			end
			hand(card, {
				Position = UDim2.fromOffset(8, 168),
				Size = UDim2.new(1, -16, 0, 26),
				Font = NOTEHAND,
				TextSize = 23,
				Text = Kit.gearText(g),
				ZIndex = 55,
			})
			local afford = g.Cost ~= nil and coins >= g.Cost
			if g.Cost == nil then
				local done = tape(
					card,
					UDim2.new(0.5, 0, 1, -50),
					Vector2.new(170, 40),
					-4,
					Color3.fromRGB(110, 200, 110),
					57
				)
				hand(done, { Size = UDim2.fromScale(1, 1), TextSize = 22, Text = "MAXED OUT", ZIndex = 58 })
			else
				-- Price sticker.
				local sticker = Kit.box(card, {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0, 56, 1, -50),
					Size = UDim2.fromOffset(78, 78),
					Rotation = -10,
					BackgroundColor3 = if afford then ORANGE else Color3.fromRGB(190, 180, 160),
					ZIndex = 57,
				})
				Kit.round(sticker)
				hand(sticker, {
					Size = UDim2.fromScale(1, 1),
					TextSize = 24,
					TextColor3 = Color3.new(1, 1, 1),
					Text = Kit.comma(g.Cost),
					ZIndex = 58,
				})
				if afford then
					-- Rubber stamp BUY.
					local stamp = Kit.box(card, {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.new(0, 148, 1, -50),
						Size = UDim2.fromOffset(92, 52),
						Rotation = -6,
						BackgroundTransparency = 1,
						ZIndex = 57,
					})
					Kit.corner(stamp, 6)
					Kit.stroke(stamp, RED_PEN, 4)
					hand(stamp, {
						Size = UDim2.fromScale(1, 1),
						TextSize = 30,
						TextColor3 = RED_PEN,
						Text = "BUY",
						ZIndex = 58,
					})
				else
					hand(card, {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.new(0, 148, 1, -50),
						Size = UDim2.fromOffset(100, 50),
						Font = NOTEHAND,
						TextSize = 20,
						TextWrapped = true,
						TextColor3 = PENCIL,
						Text = ("need %s more"):format(Kit.comma(g.Cost - coins)),
						ZIndex = 57,
					})
				end
			end
		end
		board.Rotation = -1.5
		Kit.tween(board, 0.35, { Rotation = 0 }, Enum.EasingStyle.Back)
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
		local height = 120 + rows * 32 + 130
		local clip = Kit.box(layer, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 10),
			Size = UDim2.fromOffset(380, height),
			Rotation = 1.5,
			BackgroundColor3 = WOOD,
			ZIndex = 51,
		})
		Kit.corner(clip, 12)
		Kit.stroke(clip, WOOD_DARK, 3)
		local paper = Kit.box(clip, {
			Position = UDim2.fromOffset(16, 34),
			Size = UDim2.new(1, -32, 1, -50),
			BackgroundColor3 = PAPER,
			ClipsDescendants = true,
			ZIndex = 52,
		})
		for y = 66, height - 90, 32 do
			Kit.box(paper, {
				Position = UDim2.fromOffset(0, y),
				Size = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = RULE,
				ZIndex = 52,
			})
		end
		Kit.box(paper, {
			Position = UDim2.fromOffset(40, 0),
			Size = UDim2.new(0, 1, 1, 0),
			BackgroundColor3 = Color3.fromRGB(240, 140, 140),
			ZIndex = 52,
		})
		local metal = Kit.box(clip, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 12),
			Size = UDim2.fromOffset(140, 40),
			BackgroundColor3 = TIN,
			ZIndex = 55,
		})
		Kit.corner(metal, 8)
		Kit.stroke(metal, TIN_DARK, 3)
		Kit.gradient(metal, Color3.fromRGB(226, 230, 234), Color3.fromRGB(150, 156, 162), 90)
		hand(paper, {
			Position = UDim2.fromOffset(50, 28),
			Size = UDim2.new(1, -60, 0, 34),
			TextSize = 28,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "SCRAP TALLY",
			ZIndex = 53,
		})
		local y = 66
		local function row(left: string, right: string, color: Color3?, tapeColor: Color3?)
			if tapeColor then
				local t = Kit.box(paper, {
					Position = UDim2.fromOffset(12, y + 9),
					Size = UDim2.fromOffset(20, 14),
					Rotation = -8,
					BackgroundColor3 = tapeColor,
					ZIndex = 53,
				})
				t.BackgroundTransparency = 0.05
			end
			hand(paper, {
				Position = UDim2.fromOffset(50, y),
				Size = UDim2.new(1, -140, 0, 32),
				Font = NOTEHAND,
				TextSize = 24,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = color or MARKER,
				Text = left,
				ZIndex = 53,
			})
			hand(paper, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -16, 0, y),
				Size = UDim2.fromOffset(80, 32),
				Font = NOTEHAND,
				TextSize = 26,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = color or MARKER,
				Text = right,
				ZIndex = 53,
			})
			y += 32
		end
		for i = 1, shown do
			local entry = r.Lines[i]
			local d = Config.Loot[entry.Id]
			local tally = if entry.Count > 1 then "  " .. string.rep("|", entry.Count) else ""
			row(d.Name .. tally, tostring(entry.Value * entry.Count), nil, Config.RarityColors[d.Rarity])
		end
		for _, bonus in r.Multipliers do
			row(bonus.Name:lower(), "x" .. tostring(bonus.Factor), RED_PEN)
		end
		local totalY = y + 10
		local circle = Kit.box(paper, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 20, 0, totalY + 30),
			Size = UDim2.fromOffset(170, 66),
			Rotation = -4,
			BackgroundTransparency = 1,
			ZIndex = 53,
		})
		Kit.round(circle)
		Kit.stroke(circle, RED_PEN, 3)
		hand(paper, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 20, 0, totalY + 30),
			Size = UDim2.fromOffset(170, 60),
			TextSize = 44,
			TextColor3 = RED_PEN,
			Text = "+" .. Kit.comma(r.Total),
			ZIndex = 54,
		})
		hand(paper, {
			Position = UDim2.fromOffset(50, totalY + 70),
			Size = UDim2.new(1, -60, 0, 24),
			Font = NOTEHAND,
			TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = PENCIL,
			Text = ("cash now: %s"):format(Kit.comma(r.Balance)),
			ZIndex = 53,
		})
		clip.Position = UDim2.new(0.5, 0, 1.6, 0)
		Kit.tween(clip, 0.45, { Position = UDim2.new(0.5, 0, 0.5, 10) }, Enum.EasingStyle.Back)
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
		local color = Config.RarityColors[def.Rarity]
		local layer = Kit.box(
			overlay,
			{ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, Name = "Rarity" }
		)
		-- A tag dropping on its string from the top of the screen.
		local hang = Kit.box(layer, {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, -230, 0, -20),
			Size = UDim2.fromOffset(330, 320),
			ZIndex = 51,
		})
		Kit.line(hang, Vector2.new(165, 0), Vector2.new(165, 150), 2, MARKER, 51)
		local tag = Kit.box(hang, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(165, 140),
			Size = UDim2.fromOffset(300, 140),
			BackgroundColor3 = MANILA,
			ZIndex = 52,
		})
		Kit.corner(tag, 10)
		Kit.stroke(tag, KRAFT_EDGE, 2)
		local ring = Kit.box(tag, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 6),
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = Color3.fromRGB(250, 246, 236),
			ZIndex = 53,
		})
		Kit.round(ring)
		Kit.stroke(ring, KRAFT_EDGE, 3)
		local grade = tape(tag, UDim2.new(0.5, 0, 0, 44), Vector2.new(260, 38), -3, color, 54)
		hand(grade, {
			Size = UDim2.fromScale(1, 1),
			TextSize = 26,
			TextColor3 = if def.Rarity == "Common" or def.Rarity == "Legendary"
				then MARKER
				else Color3.new(1, 1, 1),
			Text = GRADE[def.Rarity],
			ZIndex = 55,
		})
		hand(tag, {
			Position = UDim2.fromOffset(10, 70),
			Size = UDim2.new(1, -20, 0, 34),
			TextSize = 28,
			Text = def.Name,
			ZIndex = 53,
		})
		hand(tag, {
			Position = UDim2.fromOffset(10, 104),
			Size = UDim2.new(1, -20, 0, 26),
			Font = NOTEHAND,
			TextSize = 22,
			TextColor3 = PENCIL,
			Text = ("worth %d"):format(def.Value),
			ZIndex = 53,
		})
		if def.Rarity == "Legendary" then
			local star = Kit.box(tag, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, -10, 0, 10),
				Size = UDim2.fromOffset(44, 44),
				Rotation = 20,
				BackgroundColor3 = Color3.fromRGB(255, 204, 40),
				ZIndex = 56,
			})
			Kit.corner(star, 6)
			Kit.stroke(star, MARKER, 2)
			hand(star, { Size = UDim2.fromScale(1, 1), TextSize = 22, Text = "★", ZIndex = 57 })
		end
		-- Drop and swing.
		hang.Position = UDim2.new(0.5, -230, 0, -360)
		Kit.tween(hang, 0.5, { Position = UDim2.new(0.5, -230, 0, -20) }, Enum.EasingStyle.Bounce)
		task.spawn(function()
			local t0 = os.clock()
			while hang.Parent do
				local t = os.clock() - t0
				hang.Rotation = math.sin(t * 4) * 6 * math.exp(-t * 1.2)
				task.wait()
			end
		end)

		if not transient then
			local strip = Kit.box(layer, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -40),
				Size = UDim2.fromOffset(640, 84),
				Rotation = 0.6,
				BackgroundColor3 = KRAFT,
				ZIndex = 51,
			})
			Kit.stroke(strip, KRAFT_EDGE, 2)
			for i, tier in Kit.Tiers do
				local x = (i - 0.5) / 5
				tape(
					strip,
					UDim2.new(x, 0, 0, 28),
					Vector2.new(104, 28),
					(i % 2 - 0.5) * 6,
					Config.RarityColors[tier],
					52
				)
				hand(strip, {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(x, 0, 0, 48),
					Size = UDim2.fromOffset(120, 26),
					Font = NOTEHAND,
					TextSize = 21,
					Text = tier,
					ZIndex = 53,
				})
			end
		else
			task.delay(3.2, function()
				if layer.Parent then
					layer:Destroy()
				end
			end)
		end
	end

	return view
end

return Study
