-- World look profiles: lighting, color grade, atmosphere, palette and material treatment for
-- calm weather and storms. MapBuilder applies the active profile's calm look at startup and
-- StormService tweens between cycle phases with `targetsFor()`.
--
-- "V2" is the shipped look, "V3" the approved direction. "A", "B" and "C" are the art-direction studies
-- (docs/art/V3-ART-DIRECTION.md); in Studio they can be switched live with
-- StormSalvageDebug:Invoke("look", "A") for side-by-side screenshots.

local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Palette"))

local LookService = {}

export type Phase = {
	Lighting: { [string]: any },
	Grade: { [string]: any },
	Atmosphere: { [string]: any },
	Clouds: { [string]: any },
}

export type Profile = {
	Name: string,
	Calm: Phase,
	Storm: Phase, -- default storm look (warning and storm)
	Storms: { [string]: Phase }?, -- per-storm looks (Wind, Flood, Lightning); fall back to Storm
	Aftermath: Phase?, -- the 15 s after a storm; falls back to Calm
	Bloom: { [string]: any },
	SunRays: { [string]: any },
	-- Swatch recolors, multiplied into Palette swatches: saturation and value scales.
	PaletteSaturation: number,
	PaletteValue: number,
	-- Base material -> MaterialVariant name (variants live in MaterialService).
	Materials: { [string]: string },
	Water: { [string]: any },
}

local profiles: { [string]: Profile } = {
	-- The shipped V2 look, kept exactly so studies can be compared against it.
	V2 = {
		Name = "V2 (shipped)",
		Calm = {
			Lighting = {
				ClockTime = 15.5,
				Brightness = 2.4,
				Ambient = Color3.fromRGB(70, 70, 80),
				OutdoorAmbient = Color3.fromRGB(135, 130, 125),
				ColorShift_Top = Color3.fromRGB(255, 240, 215),
				ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
				EnvironmentDiffuseScale = 0.5,
				EnvironmentSpecularScale = 0.5,
				ExposureCompensation = 0,
				ShadowSoftness = 0.2,
			},
			Grade = {
				Saturation = 0.12,
				Contrast = 0.06,
				Brightness = 0,
				TintColor = Color3.fromRGB(255, 248, 238),
			},
			Atmosphere = {
				Density = 0.28,
				Offset = 0,
				Haze = 0.5,
				Glare = 0,
				Color = Color3.fromRGB(199, 199, 199),
				Decay = Color3.fromRGB(106, 112, 125),
			},
			Clouds = { Cover = 0.5, Density = 0.4 },
		},
		Storm = {
			Lighting = {
				ClockTime = 16.8,
				Brightness = 1.1,
				OutdoorAmbient = Color3.fromRGB(95, 100, 115),
				ExposureCompensation = -0.3,
			},
			Grade = { Saturation = -0.3, Contrast = 0.15, TintColor = Color3.fromRGB(205, 215, 235) },
			Atmosphere = { Density = 0.5, Haze = 2.5, Color = Color3.fromRGB(110, 110, 120) },
			Clouds = { Cover = 0.95, Density = 0.9 },
		},
		Bloom = { Intensity = 0.35, Size = 22, Threshold = 1.4 },
		SunRays = { Intensity = 0.05, Spread = 0.6 },
		PaletteSaturation = 1,
		PaletteValue = 1,
		Materials = {},
		Water = { WaterColor = Color3.fromRGB(92, 84, 58), WaterTransparency = 0.35, WaterReflectance = 0.25 },
	},

	-- A: Storm-Scarred Arcade. Golden-hour warmth, saturated paint over weathered, patched
	-- materials; storms turn teal-violet and electric. Stylized texture, not realism.
	A = {
		Name = "A: Storm-Scarred Arcade",
		Calm = {
			Lighting = {
				ClockTime = 17.05, -- low golden sun with long shadows (past ~17.3 the moon shows)
				Brightness = 3.1,
				Ambient = Color3.fromRGB(78, 70, 88),
				OutdoorAmbient = Color3.fromRGB(150, 132, 128),
				ColorShift_Top = Color3.fromRGB(255, 200, 140),
				ColorShift_Bottom = Color3.fromRGB(70, 80, 130), -- cool bounce fill under eaves
				EnvironmentDiffuseScale = 0.75,
				EnvironmentSpecularScale = 0.8,
				ExposureCompensation = 0.05,
				ShadowSoftness = 0.12,
			},
			Grade = {
				Saturation = 0.24,
				Contrast = 0.16,
				Brightness = 0.01,
				TintColor = Color3.fromRGB(255, 236, 212),
			},
			Atmosphere = {
				Density = 0.38,
				Offset = 0.2,
				Haze = 1.6,
				Glare = 0.45,
				Color = Color3.fromRGB(255, 222, 186),
				Decay = Color3.fromRGB(150, 112, 140),
			},
			Clouds = { Cover = 0.55, Density = 0.45 },
		},
		Storm = {
			Lighting = {
				ClockTime = 17,
				Brightness = 1.25,
				OutdoorAmbient = Color3.fromRGB(88, 104, 128),
				ExposureCompensation = -0.2,
			},
			Grade = { Saturation = -0.15, Contrast = 0.22, TintColor = Color3.fromRGB(190, 220, 235) },
			Atmosphere = { Density = 0.48, Haze = 2.2, Color = Color3.fromRGB(78, 104, 122) },
			Clouds = { Cover = 0.95, Density = 0.85 },
		},
		Bloom = { Intensity = 0.5, Size = 24, Threshold = 1.2 },
		SunRays = { Intensity = 0.09, Spread = 0.5 },
		PaletteSaturation = 1.1,
		PaletteValue = 1,
		Materials = {
			Metal = "V3A_PaintedMetal3",
			CorrodedMetal = "V3A_RustedSheet1",
			Concrete = "V3A_PatchedConcrete",
			Asphalt = "V3A_PatchedAsphalt",
			WoodPlanks = "V3A_WeatheredPlanks2",
			Brick = "V3A_StylizedBrick3",
		},
		Water = { WaterColor = Color3.fromRGB(70, 92, 84), WaterTransparency = 0.3, WaterReflectance = 0.3 },
	},

	-- V3: the approved direction (Milestone A review). Study A's golden light and hand-painted
	-- materials, Study B's distance haze for depth, and a distinct sky per storm plus a warm
	-- aftermath. Storm phases override only what changes; the rest tweens from calm.
	V3 = {
		Name = "V3: Storm-Scarred Arcade",
		Calm = {
			Lighting = {
				ClockTime = 17.05,
				Brightness = 3.1,
				Ambient = Color3.fromRGB(78, 70, 88),
				OutdoorAmbient = Color3.fromRGB(150, 132, 128),
				ColorShift_Top = Color3.fromRGB(255, 200, 140),
				ColorShift_Bottom = Color3.fromRGB(70, 80, 130),
				EnvironmentDiffuseScale = 0.75,
				EnvironmentSpecularScale = 0.8,
				ExposureCompensation = 0.05,
				ShadowSoftness = 0.12,
			},
			Grade = {
				Saturation = 0.24,
				Contrast = 0.16,
				Brightness = 0.01,
				TintColor = Color3.fromRGB(255, 236, 212),
			},
			Atmosphere = {
				-- Study B's depth: denser, offset haze so the town edge and backdrop fade out.
				Density = 0.42,
				Offset = 0.28,
				Haze = 2,
				Glare = 0.45,
				Color = Color3.fromRGB(255, 220, 188),
				Decay = Color3.fromRGB(140, 120, 150),
			},
			Clouds = { Cover = 0.55, Density = 0.45 },
		},
		Storm = {
			Lighting = {
				ClockTime = 17,
				Brightness = 1.25,
				OutdoorAmbient = Color3.fromRGB(88, 104, 128),
				ExposureCompensation = -0.2,
			},
			Grade = { Saturation = -0.15, Contrast = 0.22, TintColor = Color3.fromRGB(190, 220, 235) },
			Atmosphere = { Density = 0.48, Haze = 2.2, Color = Color3.fromRGB(78, 104, 122) },
			Clouds = { Cover = 0.95, Density = 0.85 },
		},
		Storms = {
			-- Wind: flat, bright overcast with dusty ochre haze. Hard to see far, not dark.
			Wind = {
				Lighting = {
					ClockTime = 16.2,
					Brightness = 2,
					OutdoorAmbient = Color3.fromRGB(150, 138, 118),
					ColorShift_Top = Color3.fromRGB(255, 226, 170),
					ExposureCompensation = 0,
				},
				Grade = { Saturation = -0.12, Contrast = 0.12, TintColor = Color3.fromRGB(255, 236, 200) },
				Atmosphere = {
					Density = 0.52,
					Offset = 0.1,
					Haze = 2.6,
					Glare = 0.1,
					Color = Color3.fromRGB(196, 168, 120),
					Decay = Color3.fromRGB(150, 120, 90),
				},
				Clouds = { Cover = 0.85, Density = 0.6 },
			},
			-- Flood: dark teal-grey, heavy and wet.
			Flood = {
				Lighting = {
					ClockTime = 16.9,
					Brightness = 1,
					OutdoorAmbient = Color3.fromRGB(72, 96, 104),
					ColorShift_Top = Color3.fromRGB(170, 200, 210),
					ExposureCompensation = -0.25,
				},
				Grade = { Saturation = -0.25, Contrast = 0.2, TintColor = Color3.fromRGB(180, 215, 220) },
				Atmosphere = {
					Density = 0.56,
					Offset = 0.05,
					Haze = 2.8,
					Glare = 0,
					Color = Color3.fromRGB(70, 98, 104),
					Decay = Color3.fromRGB(50, 70, 80),
				},
				Clouds = { Cover = 1, Density = 0.95 },
			},
			-- Lightning: very dark violet; strikes are the main light.
			Lightning = {
				Lighting = {
					ClockTime = 17.15,
					Brightness = 0.7,
					OutdoorAmbient = Color3.fromRGB(86, 76, 120),
					ColorShift_Top = Color3.fromRGB(190, 170, 255),
					ExposureCompensation = -0.3,
				},
				Grade = { Saturation = -0.05, Contrast = 0.28, TintColor = Color3.fromRGB(205, 190, 255) },
				Atmosphere = {
					Density = 0.5,
					Offset = 0.1,
					Haze = 2.4,
					Glare = 0,
					Color = Color3.fromRGB(70, 56, 104),
					Decay = Color3.fromRGB(50, 40, 80),
				},
				Clouds = { Cover = 1, Density = 1 },
			},
		},
		-- Aftermath: the sun comes back lower and warmer than calm. Relief, go grab the loot.
		Aftermath = {
			Lighting = {
				ClockTime = 17.2,
				Brightness = 3.3,
				OutdoorAmbient = Color3.fromRGB(165, 132, 118),
				ColorShift_Top = Color3.fromRGB(255, 186, 120),
				ExposureCompensation = 0.1,
			},
			Grade = { Saturation = 0.3, Contrast = 0.16, TintColor = Color3.fromRGB(255, 228, 196) },
			Atmosphere = {
				Density = 0.36,
				Offset = 0.3,
				Haze = 1.4,
				Glare = 0.8,
				Color = Color3.fromRGB(255, 206, 160),
				Decay = Color3.fromRGB(170, 120, 140),
			},
			Clouds = { Cover = 0.6, Density = 0.4 },
		},
		Bloom = { Intensity = 0.5, Size = 24, Threshold = 1.2 },
		SunRays = { Intensity = 0.09, Spread = 0.5 },
		PaletteSaturation = 1.1,
		PaletteValue = 1,
		Materials = {
			Metal = "V3A_PaintedMetal3",
			CorrodedMetal = "V3A_RustedSheet1",
			Concrete = "V3A_PatchedConcrete",
			Asphalt = "V3A_PatchedAsphalt",
			WoodPlanks = "V3A_WeatheredPlanks2",
			Brick = "V3A_StylizedBrick3",
		},
		Water = { WaterColor = Color3.fromRGB(70, 92, 84), WaterTransparency = 0.3, WaterReflectance = 0.3 },
	},

	-- B: Cinematic Storm Town. Grounded colors, realistic material response, depth haze; the
	-- storm is heavy and grey-blue. Most atmospheric, least toy-like.
	B = {
		Name = "B: Cinematic Storm Town",
		Calm = {
			Lighting = {
				ClockTime = 14.6,
				Brightness = 2.6,
				Ambient = Color3.fromRGB(60, 64, 72),
				OutdoorAmbient = Color3.fromRGB(118, 122, 128),
				ColorShift_Top = Color3.fromRGB(255, 244, 228),
				ColorShift_Bottom = Color3.fromRGB(40, 48, 60),
				EnvironmentDiffuseScale = 1,
				EnvironmentSpecularScale = 1,
				ExposureCompensation = 0,
				ShadowSoftness = 0.2,
			},
			Grade = {
				Saturation = -0.06,
				Contrast = 0.1,
				Brightness = 0,
				TintColor = Color3.fromRGB(246, 248, 255),
			},
			Atmosphere = {
				Density = 0.44,
				Offset = 0.1,
				Haze = 2.3,
				Glare = 0.2,
				Color = Color3.fromRGB(200, 210, 222),
				Decay = Color3.fromRGB(96, 110, 128),
			},
			Clouds = { Cover = 0.65, Density = 0.55 },
		},
		Storm = {
			Lighting = {
				ClockTime = 16.6,
				Brightness = 0.95,
				OutdoorAmbient = Color3.fromRGB(84, 90, 100),
				ExposureCompensation = -0.25,
			},
			Grade = { Saturation = -0.4, Contrast = 0.18, TintColor = Color3.fromRGB(200, 210, 222) },
			Atmosphere = { Density = 0.55, Haze = 2.8, Color = Color3.fromRGB(104, 112, 122) },
			Clouds = { Cover = 1, Density = 0.95 },
		},
		Bloom = { Intensity = 0.25, Size = 20, Threshold = 1.6 },
		SunRays = { Intensity = 0.04, Spread = 0.7 },
		PaletteSaturation = 0.72,
		PaletteValue = 0.92,
		Materials = {
			Metal = "V3B_Metal",
			CorrodedMetal = "V3B_Rust3",
			Concrete = "V3B_Concrete1",
			Asphalt = "V3B_Asphalt1",
			WoodPlanks = "V3B_Planks3",
			Brick = "V3B_Brick3",
		},
		Water = { WaterColor = Color3.fromRGB(78, 76, 62), WaterTransparency = 0.4, WaterReflectance = 0.35 },
	},

	-- C: Salvage Adventure. Midday, bright and clean, punchy toy colors and hand-painted
	-- materials; the storm is a vivid purple spectacle rather than a grey one.
	C = {
		Name = "C: Salvage Adventure",
		Calm = {
			Lighting = {
				ClockTime = 13.2,
				Brightness = 3.1,
				Ambient = Color3.fromRGB(96, 96, 110),
				OutdoorAmbient = Color3.fromRGB(165, 160, 158),
				ColorShift_Top = Color3.fromRGB(255, 248, 232),
				ColorShift_Bottom = Color3.fromRGB(110, 120, 170),
				EnvironmentDiffuseScale = 0.9,
				EnvironmentSpecularScale = 0.4,
				ExposureCompensation = 0.1,
				ShadowSoftness = 0.35,
			},
			Grade = {
				Saturation = 0.32,
				Contrast = 0.08,
				Brightness = 0.02,
				TintColor = Color3.fromRGB(255, 252, 245),
			},
			Atmosphere = {
				Density = 0.24,
				Offset = 0,
				Haze = 0.3,
				Glare = 0.1,
				Color = Color3.fromRGB(205, 228, 255),
				Decay = Color3.fromRGB(120, 150, 210),
			},
			Clouds = { Cover = 0.45, Density = 0.35 },
		},
		Storm = {
			Lighting = {
				ClockTime = 16.5,
				Brightness = 1.6,
				OutdoorAmbient = Color3.fromRGB(112, 96, 140),
				ExposureCompensation = -0.1,
			},
			Grade = { Saturation = 0.05, Contrast = 0.2, TintColor = Color3.fromRGB(215, 200, 255) },
			Atmosphere = { Density = 0.45, Haze = 1.8, Color = Color3.fromRGB(110, 86, 150) },
			Clouds = { Cover = 0.9, Density = 0.8 },
		},
		Bloom = { Intensity = 0.45, Size = 26, Threshold = 1.3 },
		SunRays = { Intensity = 0.06, Spread = 0.55 },
		PaletteSaturation = 1.22,
		PaletteValue = 1.05,
		Materials = {
			-- No metal variant: all four generated "toy metal" options painted literal toys on it.
			Concrete = "V3C_PaintedConcrete1",
			Asphalt = "V3C_CartoonAsphalt2",
			WoodPlanks = "V3C_PaintedPlanks1",
			Brick = "V3C_CartoonBrick1",
		},
		Water = {
			WaterColor = Color3.fromRGB(60, 120, 150),
			WaterTransparency = 0.25,
			WaterReflectance = 0.3,
		},
	},
}

local active = "V2"

local function set(target: Instance, props: { [string]: any })
	for k, v in props do
		(target :: any)[k] = v
	end
end

local function ensure(className: string, name: string, parent: Instance): any
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = parent
	return inst
end

-- Original swatch for each palette color, so recolors can be undone and re-applied.
local swatchByColor: { [string]: string } = {}
for name, color in Palette.Swatches do
	swatchByColor[tostring(color)] = name
end

local function profileColor(profile: Profile, swatch: string): Color3
	local h, s, v = Palette.Swatches[swatch]:ToHSV()
	return Color3.fromHSV(
		h,
		math.clamp(s * profile.PaletteSaturation, 0, 1),
		math.clamp(v * profile.PaletteValue, 0, 1)
	)
end

-- Recolors map parts that carry a palette swatch (MapBuilder parts and styled imports).
local function recolor(profile: Profile)
	local map = workspace:FindFirstChild("Map")
	if not map then
		return
	end
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			local swatch = d:GetAttribute("Swatch") or swatchByColor[tostring(d.Color)]
			if swatch and Palette.Swatches[swatch] then
				d:SetAttribute("Swatch", swatch)
				d.Color = profileColor(profile, swatch)
			end
		end
	end
end

-- The study MaterialVariants are saved in the repo (assets/roblox/materials/V3Studies.rbxm,
-- synced to ServerStorage.Assets); variants only render from MaterialService, so copy them
-- there if the place doesn't already have them.
local function ensureVariants()
	if MaterialService:FindFirstChild("V3Studies") then
		return
	end
	local assets = game:GetService("ServerStorage"):FindFirstChild("Assets")
	local materials = assets and assets:FindFirstChild("materials")
	local source = materials and materials:FindFirstChild("V3Studies")
	if source then
		source:Clone().Parent = MaterialService
	end
end

local function applyMaterials(profile: Profile)
	if next(profile.Materials) then
		ensureVariants()
	end
	for _, material in Enum.Material:GetEnumItems() do
		local variant = profile.Materials[material.Name]
		local ok = pcall(function()
			MaterialService:SetBaseMaterialOverride(material, variant or "")
		end)
		if not ok and variant then
			warn(("[Look] couldn't override %s with %s"):format(material.Name, variant))
		end
	end
end

-- Applies a profile's calm look. `recolorMap` is false at startup (the map is colored as it's
-- built from the palette, which is already the V2 look).
function LookService.apply(name: string, recolorMap: boolean?)
	local profile = profiles[name]
	assert(profile, "unknown look " .. tostring(name))
	active = name
	set(Lighting, profile.Calm.Lighting)
	set(ensure("ColorCorrectionEffect", "Grade", Lighting), profile.Calm.Grade)
	set(ensure("BloomEffect", "Bloom", Lighting), profile.Bloom)
	set(ensure("SunRaysEffect", "SunRays", Lighting), profile.SunRays)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
		or ensure("Atmosphere", "Atmosphere", Lighting)
	set(atmosphere, profile.Calm.Atmosphere)
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
		or ensure("Clouds", "Clouds", workspace.Terrain)
	set(clouds, profile.Calm.Clouds)
	set(workspace.Terrain, profile.Water)
	applyMaterials(profile)
	if recolorMap ~= false then
		recolor(profile)
	end
	workspace:SetAttribute("Look", name)
end

-- The look for a storm-cycle phase: "Calm", "Warning", "Storm" or "Aftermath". During the
-- warning and the storm, `storm` picks that storm's look (falling back to the profile's shared
-- storm look, tinted by `stormColor`).
function LookService.targetsFor(phase: string, storm: string?, stormColor: Color3?): Phase
	local profile = profiles[active]
	if phase == "Aftermath" then
		return profile.Aftermath or profile.Calm
	elseif phase ~= "Warning" and phase ~= "Storm" then
		return profile.Calm
	end
	local own = storm and profile.Storms and profile.Storms[storm]
	if own then
		return own
	end
	local shared = table.clone(profile.Storm)
	if stormColor then
		local atmosphere = table.clone(shared.Atmosphere)
		atmosphere.Color = stormColor:Lerp(atmosphere.Color, 0.6)
		shared.Atmosphere = atmosphere
	end
	return shared
end

function LookService.active(): string
	return active
end

function LookService.names(): { string }
	return { "V2", "V3", "A", "B", "C" }
end

return LookService
