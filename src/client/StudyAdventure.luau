-- UI study 1: Salvage Adventure. A sunny treasure hunt: cream "sticker" plates with thick
-- navy outlines and drop shadows, a weather dial with a ribbon banner, a quest scroll, a
-- Trading Post with tilted item cards, a coin-burst sale card and gem-shaped rarity.
-- Loud, friendly and readable at a glance; the closest of the three to the Roblox mainstream.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UI = require(script.Parent:WaitForChild("UI"))

local Study = {}

local CREAM = Color3.fromRGB(252, 243, 224)
local CREAM_DARK = Color3.fromRGB(232, 214, 180)
local INK = Color3.fromRGB(30, 44, 74)
local ORANGE = Color3.fromRGB(255, 140, 38)
local ORANGE_DARK = Color3.fromRGB(214, 96, 20)
local GREEN = Color3.fromRGB(88, 190, 84)
local SKY = Color3.fromRGB(96, 182, 240)
local GOLD = Color3.fromRGB(255, 204, 52)
local CORAL = Color3.fromRGB(240, 92, 80)

local DISPLAY = Enum.Font.LuckiestGuy
local NUM = Enum.Font.FredokaOne
local BODY = Enum.Font.Nunito

local TIER_WORD = {
	Common = "COMMON",
	Uncommon = "UNCOMMON!",
	Rare = "RARE!",
	Epic = "EPIC!!",
	Legendary = "LEGENDARY!!!",
}

function Study.build(root: Frame, Kit: any, _opts: any)
	local view = {}

	-- A sticker plate: fill, thick ink outline, a solid ink shadow below.
	local function sticker(parent: Instance, props: { [string]: any }, radius: number, fill: Color3?): Frame
		local holder = Kit.box(parent, {
			BackgroundTransparency = 1,
			AnchorPoint = props.AnchorPoint,
			Position = props.Position,
			Size = props.Size,
			Rotation = props.Rotation or 0,
			ZIndex = props.ZIndex or 1,
			Name = props.Name or "Sticker",
		})
		local shadow = Kit.box(holder, {
			Position = UDim2.fromOffset(0, 5),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = INK,
			ZIndex = (props.ZIndex or 1),
		})
		Kit.corner(shadow, radius)
		local face = Kit.box(holder, {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = fill or CREAM,
			ZIndex = (props.ZIndex or 1) + 1,
			Name = "Face",
		})
		Kit.corner(face, radius)
		Kit.stroke(face, INK, 3)
		return face
	end

	local function outlined(label: TextLabel, thickness: number?)
		Kit.textStroke(label, INK, thickness or 2.5)
		return label
	end

	local function coin(parent: Instance, pos: UDim2, size: number, z: number)
		local c = Kit.box(parent, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = pos,
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = GOLD,
			ZIndex = z,
		})
		Kit.round(c)
		Kit.stroke(c, INK, math.max(2, size / 20))
		local inner = Kit.box(c, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.66, 0.66),
			BackgroundColor3 = Color3.fromRGB(255, 226, 120),
			ZIndex = z + 1,
		})
		Kit.round(inner)
		Kit.stroke(inner, ORANGE_DARK, math.max(1, size / 32), 0.3)
		Kit.label(c, {
			Size = UDim2.fromScale(1, 1),
			Font = DISPLAY,
			TextScaled = true,
			Text = "S",
			TextColor3 = ORANGE_DARK,
			ZIndex = z + 2,
		}).Size =
			UDim2.fromScale(1, 0.9)
		return c
	end

	local function gem(parent: Instance, pos: UDim2, size: number, color: Color3, z: number): Frame
		local outer = Kit.diamond(parent, pos, size, color, z)
		Kit.corner(outer, math.max(2, size / 10))
		Kit.stroke(outer, INK, math.max(2, size / 16))
		local shine = Kit.box(outer, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.38, 0.38),
			Size = UDim2.fromScale(0.34, 0.34),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.35,
			ZIndex = z + 1,
		})
		Kit.corner(shine, 2)
		return outer
	end

	------------------------------------------------------------------ HUD

	-- Coins: a big coin overlapping a cream pill.
	local coinPill = sticker(root, {
		Position = UDim2.fromOffset(46, 18),
		Size = UDim2.fromOffset(176, 54),
	}, 27)
	coin(root, UDim2.fromOffset(46, 45), 66, 5)
	local coinsText = outlined(Kit.label(coinPill, {
		Position = UDim2.fromOffset(38, 0),
		Size = UDim2.new(1, -52, 1, 0),
		Font = NUM,
		TextSize = 32,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "0",
		ZIndex = 4,
	}))

	-- Bag: satchel icon, count, and one pip per slot coloured by what's in it.
	local bagPlate = sticker(root, {
		Position = UDim2.fromOffset(18, 88),
		Size = UDim2.fromOffset(250, 74),
	}, 20)
	local satchel = Kit.box(bagPlate, {
		Position = UDim2.fromOffset(12, 14),
		Size = UDim2.fromOffset(46, 44),
		BackgroundColor3 = Color3.fromRGB(176, 112, 62),
		ZIndex = 4,
	})
	Kit.corner(satchel, 10)
	Kit.stroke(satchel, INK, 3)
	local flap = Kit.box(satchel, {
		Size = UDim2.new(1, 0, 0.45, 0),
		BackgroundColor3 = Color3.fromRGB(140, 84, 44),
		ZIndex = 5,
	})
	Kit.corner(flap, 8)
	local buckle = Kit.box(satchel, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = GOLD,
		ZIndex = 6,
	})
	Kit.stroke(buckle, INK, 2)
	local bagText = outlined(Kit.label(bagPlate, {
		Position = UDim2.fromOffset(68, 6),
		Size = UDim2.fromOffset(100, 30),
		Font = NUM,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "0 / 0",
		ZIndex = 4,
	}))
	local bagWorth = Kit.label(bagPlate, {
		Position = UDim2.fromOffset(150, 8),
		Size = UDim2.fromOffset(88, 26),
		Font = BODY,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = INK,
		Text = "",
		ZIndex = 4,
	})
	local pips = Kit.box(bagPlate, {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(68, 40),
		Size = UDim2.fromOffset(170, 24),
		ZIndex = 4,
	})
	local pipKey = ""

	-- Weather dial + ribbon banner, top centre.
	local top = Kit.box(root, {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(340, 170),
	})
	local ribbonTails = {}
	for i, side in { -1, 1 } do
		local tail = Kit.box(top, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, side * 150, 0, 84),
			Size = UDim2.fromOffset(60, 40),
			BackgroundColor3 = ORANGE_DARK,
			ZIndex = 1,
		})
		Kit.corner(tail, 6)
		Kit.stroke(tail, INK, 3)
		ribbonTails[i] = tail
	end
	local ribbon = sticker(top, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 66),
		Size = UDim2.fromOffset(300, 54),
		ZIndex = 2,
	}, 12, ORANGE)
	local ribbonText = outlined(Kit.label(ribbon, {
		Position = UDim2.fromOffset(0, 14),
		Size = UDim2.new(1, 0, 1, -14),
		Font = DISPLAY,
		TextSize = 24,
		Text = "",
		ZIndex = 5,
	}))
	local dialHolder = Kit.box(top, {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(78, 78),
		ZIndex = 6,
	})
	local dialShadow = Kit.box(dialHolder, {
		Position = UDim2.fromOffset(0, 5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = INK,
		ZIndex = 6,
	})
	Kit.round(dialShadow)
	local dial = Kit.box(dialHolder, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = SKY, ZIndex = 7 })
	Kit.round(dial)
	Kit.stroke(dial, INK, 4)
	local glyph = Kit.box(dial, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 8 })
	local glyphKey = ""

	local function drawGlyph(kind: string)
		glyph:ClearAllChildren()
		if kind == "Calm" then
			local rays = Kit.rays(glyph, 60, 6, GOLD, 0, 8)
			rays.Name = "Spin"
			local sun = Kit.box(glyph, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(34, 34),
				BackgroundColor3 = GOLD,
				ZIndex = 9,
			})
			Kit.round(sun)
			Kit.stroke(sun, INK, 3)
		elseif kind == "Warning" then
			outlined(
				Kit.label(glyph, {
					Size = UDim2.fromScale(1, 1),
					Font = DISPLAY,
					TextSize = 54,
					Text = "!",
					ZIndex = 9,
				}),
				3
			)
		elseif kind == "Lightning" then
			local pts = { Vector2.new(46, 12), Vector2.new(30, 40), Vector2.new(46, 40), Vector2.new(30, 68) }
			for i = 1, 3 do
				Kit.line(glyph, pts[i], pts[i + 1], 9, GOLD, 9)
			end
		elseif kind == "Flood" then
			for i = 0, 2 do
				local wave = Kit.box(glyph, {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(39, 26 + i * 13),
					Size = UDim2.fromOffset(46 - i * 4, 8),
					BackgroundColor3 = Color3.new(1, 1, 1),
					ZIndex = 9,
				})
				Kit.round(wave)
			end
		else -- Wind
			for i, w in { 44, 32, 40 } do
				local streak = Kit.box(glyph, {
					Position = UDim2.fromOffset(14 + (i % 2) * 8, 18 + (i - 1) * 15),
					Size = UDim2.fromOffset(w, 8),
					BackgroundColor3 = Color3.new(1, 1, 1),
					ZIndex = 9,
				})
				Kit.round(streak)
			end
		end
	end

	-- Storm advice: a speech bubble under the banner during warnings and storms.
	local bubble = sticker(top, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 132),
		Size = UDim2.fromOffset(340, 44),
		ZIndex = 2,
	}, 14)
	local bubbleText = Kit.label(bubble, {
		Size = UDim2.fromScale(1, 1),
		Font = BODY,
		TextSize = 16,
		TextWrapped = true,
		TextColor3 = INK,
		Text = "",
		ZIndex = 5,
	})
	Kit.pad(bubbleText, 0, 12)
	local bubbleHolder = bubble.Parent :: Frame

	-- Quest scroll, bottom centre.
	local quest = sticker(root, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -22),
		Size = UDim2.fromOffset(440, 50),
	}, 25)
	local questMark = Kit.box(quest, {
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.fromOffset(38, 38),
		BackgroundColor3 = ORANGE,
		ZIndex = 4,
	})
	Kit.round(questMark)
	Kit.stroke(questMark, INK, 3)
	outlined(
		Kit.label(
			questMark,
			{ Size = UDim2.fromScale(1, 1), Font = DISPLAY, TextSize = 26, Text = "!", ZIndex = 5 }
		)
	)
	local questText = Kit.label(quest, {
		Position = UDim2.fromOffset(54, 0),
		Size = UDim2.new(1, -66, 1, 0),
		Font = NUM,
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = INK,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		ZIndex = 4,
	})

	-- Shop and settings: big round buttons on the right edge, clear of the jump button.
	local shopHolder = Kit.box(root, {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -18, 0.5, 10),
		Size = UDim2.fromOffset(92, 92),
	})
	local shopShadow = Kit.box(shopHolder, {
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = INK,
	})
	Kit.round(shopShadow)
	local shopBtn = Kit.button(shopHolder, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = ORANGE,
		Text = "",
		ZIndex = 2,
	})
	Kit.round(shopBtn)
	Kit.stroke(shopBtn, INK, 4)
	UI.bagIcon(shopBtn, 34, Color3.new(1, 1, 1)).Position = UDim2.new(0.5, -17, 0, 12)
	outlined(Kit.label(shopBtn, {
		Position = UDim2.new(0, 0, 1, -34),
		Size = UDim2.new(1, 0, 0, 24),
		Font = DISPLAY,
		TextSize = 22,
		Text = "SHOP",
		ZIndex = 4,
	}))
	local gearBtn = Kit.button(root, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -36, 0.5, -76),
		Size = UDim2.fromOffset(56, 56),
		BackgroundColor3 = CREAM,
		Text = "",
	})
	Kit.round(gearBtn)
	Kit.stroke(gearBtn, INK, 3)
	local sliders = UI.slidersIcon(gearBtn, 26)
	sliders.Position = UDim2.new(0.5, -13, 0.5, -13)
	for _, d in sliders:GetDescendants() do
		if d:IsA("Frame") and d.BackgroundTransparency < 1 then
			d.BackgroundColor3 = INK
		elseif d:IsA("UIStroke") then
			d.Color = INK
		end
	end

	-- Boost tag, under the bag.
	local boost = sticker(root, {
		Position = UDim2.fromOffset(18, 176),
		Size = UDim2.fromOffset(150, 36),
	}, 18, GREEN)
	local boostText = outlined(Kit.label(boost, {
		Size = UDim2.fromScale(1, 1),
		Font = DISPLAY,
		TextSize = 18,
		Text = "",
		ZIndex = 4,
	}))
	local boostHolder = boost.Parent :: Frame

	local overlay = Kit.box(root, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50 })

	function view.hud(s: any, storm: any, now: number, objective: string, hint: string?)
		coinsText.Text = Kit.comma(s.Coins)
		bagText.Text = ("%d / %d"):format(#s.Carried, s.Capacity)
		bagWorth.Text = if s.CarriedValue and s.CarriedValue > 0
			then ("worth %d"):format(s.CarriedValue)
			else ""
		local key = table.concat(s.Carried, ",") .. "/" .. s.Capacity
		if key ~= pipKey then
			pipKey = key
			pips:ClearAllChildren()
			local size = math.clamp(math.floor(170 / s.Capacity) - 4, 7, 18)
			Kit.list(pips, 4, true)
			for i = 1, s.Capacity do
				local id = s.Carried[i]
				local def = id and Config.Loot[id]
				local pip = Kit.box(pips, {
					LayoutOrder = i,
					Size = UDim2.fromOffset(size, size),
					BackgroundColor3 = if def then Config.RarityColors[def.Rarity] else CREAM_DARK,
					ZIndex = 5,
				})
				Kit.round(pip)
				Kit.stroke(pip, INK, if def then 2 else 1.5, if def then 0 else 0.6)
			end
		end

		local remaining = (storm.EndsAt or 0) - now
		local phase = storm.Phase
		local kind = if phase == "Storm"
			then (storm.Storm or "Wind")
			elseif phase == "Warning" then "Warning"
			else "Calm"
		if kind ~= glyphKey then
			glyphKey = kind
			drawGlyph(kind)
		end
		local spin = glyph:FindFirstChild("Spin") :: Frame?
		if spin then
			spin.Rotation = (now * 20) % 360
		end
		local stormName = storm.Storm
				and Config.Storms[storm.Storm]
				and Config.Storms[storm.Storm].DisplayName
			or "STORM"
		if phase == "Storm" then
			dial.BackgroundColor3 = Color3.fromRGB(70, 74, 110)
			ribbon.BackgroundColor3 = CORAL
			ribbonText.Text = ("%s  %s"):format(stormName, Kit.clock(remaining))
		elseif phase == "Warning" then
			dial.BackgroundColor3 = ORANGE
			ribbon.BackgroundColor3 = CORAL
			ribbonText.Text = ("%s IN %s"):format(stormName, Kit.clock(remaining))
		else
			dial.BackgroundColor3 = SKY
			ribbon.BackgroundColor3 = GREEN
			ribbonText.Text = ("ALL CLEAR  %s"):format(Kit.clock(remaining))
		end
		for _, tail in ribbonTails do
			tail.BackgroundColor3 = if phase == "Calm"
				then Color3.fromRGB(56, 140, 60)
				else Color3.fromRGB(190, 60, 52)
		end
		local urgent = phase ~= "Calm" and remaining < 10
		local pulse = if urgent then 1 + math.abs(math.sin(now * 5)) * 0.06 else 1
		dialHolder.Size = UDim2.fromOffset(78 * pulse, 78 * pulse)
		bubbleHolder.Visible = hint ~= nil
		bubbleText.Text = hint or ""
		questText.Text = objective
		local boostLeft = (s.BoostRemaining or 0)
		boostHolder.Visible = boostLeft > 0
		boostText.Text = "2X SALVAGE!"
	end

	------------------------------------------------------------------ Overlays

	function view.clearOverlay()
		overlay:ClearAllChildren()
	end

	function view.shop(s: any)
		local layer = Kit.box(
			overlay,
			{ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, Name = "Shop" }
		)
		Kit.box(layer, {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = INK,
			BackgroundTransparency = 0.45,
			ZIndex = 50,
		})
		local board = sticker(layer, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.53),
			Size = UDim2.fromOffset(780, 420),
			ZIndex = 51,
		}, 26)
		-- Header ribbon over the top edge.
		local head = sticker(layer, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.53, -210),
			Size = UDim2.fromOffset(330, 58),
			ZIndex = 60,
		}, 14, ORANGE)
		outlined(
			Kit.label(head, {
				Size = UDim2.fromScale(1, 1),
				Font = DISPLAY,
				TextSize = 36,
				Text = "TRADING POST",
				ZIndex = 63,
			}),
			3
		)
		-- Wallet + close.
		local wallet = sticker(board, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -66, 0, 18),
			Size = UDim2.fromOffset(140, 40),
			ZIndex = 54,
		}, 20, CREAM_DARK)
		coin(wallet, UDim2.fromOffset(20, 20), 30, 58)
		Kit.label(wallet, {
			Position = UDim2.fromOffset(36, 0),
			Size = UDim2.new(1, -46, 1, 0),
			Font = NUM,
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = INK,
			Text = Kit.comma(s and s.Coins or 0),
			ZIndex = 58,
		})
		local close = Kit.button(board, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -8, 0, 8),
			Size = UDim2.fromOffset(52, 52),
			BackgroundColor3 = CORAL,
			Text = "",
			ZIndex = 60,
		})
		Kit.round(close)
		Kit.stroke(close, INK, 3)
		outlined(
			Kit.label(
				close,
				{ Size = UDim2.fromScale(1, 1), Font = DISPLAY, TextSize = 28, Text = "X", ZIndex = 61 }
			)
		)

		local row = Kit.box(board, {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -26),
			Size = UDim2.fromOffset(732, 320),
			ZIndex = 54,
		})
		local tint = {
			Backpack = Color3.fromRGB(255, 196, 120),
			Boots = Color3.fromRGB(150, 214, 255),
			Armor = Color3.fromRGB(170, 226, 150),
		}
		local tilt = { -2.5, 1.5, -1 }
		for i, g in Kit.gear(s) do
			local card = sticker(row, {
				Position = UDim2.fromOffset((i - 1) * 252 + 6, 8),
				Size = UDim2.fromOffset(226, 300),
				Rotation = tilt[i],
				ZIndex = 55,
			}, 20, Color3.new(1, 1, 1))
			local band = Kit.box(card, {
				Size = UDim2.new(1, 0, 0, 112),
				BackgroundColor3 = tint[g.Id],
				ZIndex = 57,
			})
			Kit.corner(band, 18)
			Kit.box(card, {
				Position = UDim2.fromOffset(0, 92),
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundColor3 = tint[g.Id],
				ZIndex = 56,
			})
			local disc = Kit.box(band, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.55),
				Size = UDim2.fromOffset(82, 82),
				BackgroundColor3 = Color3.new(1, 1, 1),
				ZIndex = 58,
			})
			Kit.round(disc)
			Kit.stroke(disc, INK, 3)
			local icon = UI.upgradeIcon(g.Id, disc, 50)
			icon.Position = UDim2.new(0.5, -25, 0.5, -25)
			for _, d in icon:GetDescendants() do
				if d:IsA("GuiObject") then
					d.ZIndex = 60
				end
			end
			if icon:IsA("GuiObject") then
				icon.ZIndex = 59
			end
			Kit.label(card, {
				Position = UDim2.fromOffset(0, 120),
				Size = UDim2.new(1, 0, 0, 30),
				Font = DISPLAY,
				TextSize = 24,
				TextColor3 = INK,
				Text = g.Name:upper(),
				ZIndex = 58,
			})
			-- Level stars as gold pips.
			local stars = Kit.box(card, {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, 154),
				Size = UDim2.new(1, 0, 0, 20),
				ZIndex = 58,
			})
			Kit.list(stars, 6, true, Enum.HorizontalAlignment.Center)
			for l = 1, g.MaxLevel do
				local star = Kit.box(stars, {
					LayoutOrder = l,
					Size = UDim2.fromOffset(16, 16),
					Rotation = 45,
					BackgroundColor3 = if l <= g.Level then GOLD else CREAM_DARK,
					ZIndex = 59,
				})
				Kit.corner(star, 3)
				Kit.stroke(star, INK, 2, if l <= g.Level then 0 else 0.5)
			end
			Kit.label(card, {
				Position = UDim2.fromOffset(10, 182),
				Size = UDim2.new(1, -20, 0, 44),
				Font = NUM,
				TextSize = 20,
				TextWrapped = true,
				TextColor3 = INK,
				Text = Kit.gearText(g),
				ZIndex = 58,
			})
			local coins = s and s.Coins or 0
			local afford = g.Cost ~= nil and coins >= g.Cost
			local buy = sticker(card, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -18),
				Size = UDim2.fromOffset(186, 52),
				ZIndex = 58,
			}, 26, if g.Cost == nil then GOLD elseif afford then GREEN else CREAM_DARK)
			if g.Cost == nil then
				outlined(Kit.label(buy, {
					Size = UDim2.fromScale(1, 1),
					Font = DISPLAY,
					TextSize = 24,
					Text = "MAXED!",
					ZIndex = 62,
				}))
			elseif afford then
				coin(buy, UDim2.fromOffset(34, 26), 32, 61)
				outlined(Kit.label(buy, {
					Position = UDim2.fromOffset(52, 0),
					Size = UDim2.new(1, -64, 1, 0),
					Font = NUM,
					TextSize = 28,
					Text = Kit.comma(g.Cost),
					ZIndex = 62,
				}))
			else
				Kit.label(buy, {
					Size = UDim2.fromScale(1, 1),
					Font = NUM,
					TextSize = 18,
					TextColor3 = INK,
					Text = ("Need %s more"):format(Kit.comma(g.Cost - coins)),
					ZIndex = 62,
				})
			end
		end
		local scale = Kit.new("UIScale", { Parent = board.Parent, Scale = 0.85 })
		Kit.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
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
		local shown = math.min(#r.Lines, 4)
		local rows = shown + #r.Multipliers + (if #r.Lines > shown then 1 else 0)
		local height = 96 + rows * 30 + 128
		local card = sticker(layer, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(380, height),
			ZIndex = 52,
		}, 24)
		local head = sticker(layer, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, -height / 2),
			Size = UDim2.fromOffset(250, 52),
			Rotation = -2,
			ZIndex = 60,
		}, 14, if r.HadCore then GOLD else GREEN)
		outlined(
			Kit.label(head, {
				Size = UDim2.fromScale(1, 1),
				Font = DISPLAY,
				TextSize = 32,
				Text = "LOOT SOLD!",
				ZIndex = 63,
			}),
			3
		)
		local list = Kit.box(card, {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(26, 46),
			Size = UDim2.new(1, -52, 0, rows * 30),
			ZIndex = 54,
		})
		Kit.list(list, 0)
		local function line(order: number, left: string, right: string, color: Color3?, gemColor: Color3?)
			local f = Kit.box(list, {
				BackgroundTransparency = 1,
				LayoutOrder = order,
				Size = UDim2.new(1, 0, 0, 30),
				ZIndex = 54,
			})
			if gemColor then
				gem(f, UDim2.fromOffset(9, 15), 18, gemColor, 55)
			end
			Kit.label(f, {
				Position = UDim2.fromOffset(28, 0),
				Size = UDim2.new(1, -100, 1, 0),
				Font = BODY,
				TextSize = 18,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = color or INK,
				Text = left,
				ZIndex = 56,
			})
			Kit.label(f, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0, 90, 1, 0),
				Font = NUM,
				TextSize = 20,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = color or INK,
				Text = right,
				ZIndex = 56,
			})
		end
		for i = 1, shown do
			local entry = r.Lines[i]
			local def = Config.Loot[entry.Id]
			line(
				i,
				if entry.Count > 1 then ("%s  x%d"):format(def.Name, entry.Count) else def.Name,
				tostring(entry.Value * entry.Count),
				nil,
				Config.RarityColors[def.Rarity]
			)
		end
		if #r.Lines > shown then
			local rest = 0
			for i = shown + 1, #r.Lines do
				rest += r.Lines[i].Value * r.Lines[i].Count
			end
			line(shown + 1, ("+ %d more"):format(#r.Lines - shown), tostring(rest))
		end
		for i, bonus in r.Multipliers do
			line(100 + i, bonus.Name, ("x%s"):format(tostring(bonus.Factor)), ORANGE_DARK)
		end
		-- Dotted rule.
		local rule = Kit.box(card, {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(26, 52 + rows * 30),
			Size = UDim2.new(1, -52, 0, 4),
			ZIndex = 54,
		})
		Kit.list(rule, 6, true)
		for i = 1, 30 do
			local dot = Kit.box(
				rule,
				{ LayoutOrder = i, Size = UDim2.fromOffset(4, 4), BackgroundColor3 = CREAM_DARK, ZIndex = 54 }
			)
			Kit.round(dot)
		end
		-- Total with a coin burst.
		local totalZone = Kit.box(card, {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 62 + rows * 30),
			Size = UDim2.new(1, 0, 0, 84),
			ZIndex = 54,
		})
		local burst = Kit.rays(totalZone, 150, 8, GOLD, 0.45, 54)
		burst.Name = "Burst"
		coin(totalZone, UDim2.new(0.5, -66, 0.5, 0), 52, 56)
		local total = Kit.label(totalZone, {
			Position = UDim2.new(0.5, -32, 0, 0),
			Size = UDim2.new(0.5, 30, 1, 0),
			Font = NUM,
			TextSize = 50,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = GREEN,
			Text = "+" .. Kit.comma(r.Total),
			ZIndex = 58,
		})
		Kit.textStroke(total, INK, 3)
		Kit.label(card, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -14),
			Size = UDim2.new(1, 0, 0, 22),
			Font = BODY,
			TextSize = 17,
			TextColor3 = INK,
			Text = ("Coins now: %s"):format(Kit.comma(r.Balance)),
			ZIndex = 56,
		})
		task.spawn(function()
			local t0 = os.clock()
			while burst.Parent do
				burst.Rotation = (os.clock() - t0) * 30
				task.wait()
			end
		end)
		local scale = Kit.new("UIScale", { Parent = card.Parent, Scale = 0.6 })
		Kit.tween(scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
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
		local legendary = def.Rarity == "Legendary"
		local layer = Kit.box(
			overlay,
			{ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, Name = "Rarity" }
		)
		local card = sticker(layer, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 22, 0.45, 0),
			Size = UDim2.fromOffset(360, 116),
			ZIndex = 52,
		}, 22, Color3.new(1, 1, 1))
		Kit.stroke(card, INK, 3)
		local band = Kit.box(card, {
			Size = UDim2.new(0, 112, 1, 0),
			BackgroundColor3 = color,
			ClipsDescendants = true,
			ZIndex = 53,
		})
		Kit.corner(band, 20)
		Kit.box(card, {
			Position = UDim2.fromOffset(92, 0),
			Size = UDim2.new(0, 20, 1, 0),
			BackgroundColor3 = color,
			ZIndex = 53,
		})
		if legendary or def.Rarity == "Epic" then
			local rays = Kit.rays(band, 120, 6, Color3.new(1, 1, 1), 0.55, 54)
			task.spawn(function()
				while rays.Parent do
					rays.Rotation = (os.clock() * 40) % 360
					task.wait()
				end
			end)
		end
		gem(band, UDim2.fromScale(0.5, 0.5), 74, color, 56)
		local word = Kit.label(card, {
			Position = UDim2.fromOffset(126, 12),
			Size = UDim2.new(1, -140, 0, 36),
			Font = DISPLAY,
			TextSize = if legendary then 30 else 32,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = color,
			Text = TIER_WORD[def.Rarity],
			ZIndex = 56,
		})
		Kit.textStroke(word, INK, 3)
		Kit.label(card, {
			Position = UDim2.fromOffset(126, 50),
			Size = UDim2.new(1, -140, 0, 28),
			Font = NUM,
			TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = INK,
			Text = def.Name,
			ZIndex = 56,
		})
		Kit.label(card, {
			Position = UDim2.fromOffset(126, 80),
			Size = UDim2.new(1, -140, 0, 22),
			Font = BODY,
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = INK,
			Text = ("Worth %d coins"):format(def.Value),
			ZIndex = 56,
		})
		local holder = card.Parent :: Frame
		holder.Position = UDim2.new(0, -400, 0.45, 0)
		Kit.tween(holder, 0.45, { Position = UDim2.new(0, 22, 0.45, 0) }, Enum.EasingStyle.Back)

		if not transient then
			-- The full tier ladder for comparison.
			local ladder = sticker(layer, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -92),
				Size = UDim2.fromOffset(600, 92),
				ZIndex = 52,
			}, 20)
			for i, tier in Kit.Tiers do
				local x = (i - 0.5) / #Kit.Tiers
				gem(ladder, UDim2.new(x, 0, 0, 34), 38, Config.RarityColors[tier], 55)
				Kit.label(ladder, {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(x, 0, 0, 60),
					Size = UDim2.fromOffset(118, 22),
					Font = DISPLAY,
					TextSize = 17,
					TextColor3 = INK,
					Text = tier:upper(),
					ZIndex = 56,
				})
			end
		else
			task.delay(3.2, function()
				if layer.Parent then
					Kit.tween(holder, 0.3, { Position = UDim2.new(0, -400, 0.45, 0) })
					task.wait(0.32)
					layer:Destroy()
				end
			end)
		end
	end

	return view
end

return Study
