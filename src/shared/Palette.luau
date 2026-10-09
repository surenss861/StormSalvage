--!strict
-- Storm Salvage art palette. One source of truth for world colors: MapBuilder uses these,
-- and imported Blender meshes are colored from their object names (see AssetStyler).
-- Swatch names are referenced from Blender object names: "Piece__Material__Swatch".

local Palette = {}

Palette.Swatches = {
	-- Town walls: saturated, sun-faded
	Terracotta = Color3.fromRGB(214, 106, 64),
	Mustard = Color3.fromRGB(232, 178, 62),
	Coral = Color3.fromRGB(222, 96, 104),
	Cobalt = Color3.fromRGB(62, 112, 196),
	Teal = Color3.fromRGB(52, 156, 150),
	Mint = Color3.fromRGB(150, 210, 170),
	Cream = Color3.fromRGB(242, 230, 205), -- trim, window frames
	Plaster = Color3.fromRGB(226, 208, 176),
	-- Roofs
	RoofRed = Color3.fromRGB(168, 62, 48),
	RoofBrown = Color3.fromRGB(122, 74, 52),
	RoofSlate = Color3.fromRGB(70, 82, 104),
	-- Ground and nature
	Grass = Color3.fromRGB(104, 168, 76),
	GrassDark = Color3.fromRGB(70, 128, 58),
	Leaf = Color3.fromRGB(84, 150, 70),
	Bark = Color3.fromRGB(110, 76, 52),
	Sand = Color3.fromRGB(226, 204, 158),
	Stone = Color3.fromRGB(150, 146, 140),
	Asphalt = Color3.fromRGB(56, 56, 64),
	Concrete = Color3.fromRGB(176, 172, 164),
	-- Industrial (Scrapyard)
	SafetyYellow = Color3.fromRGB(246, 190, 40),
	Rust = Color3.fromRGB(150, 78, 46),
	RustDark = Color3.fromRGB(96, 56, 40),
	Gunmetal = Color3.fromRGB(70, 74, 82),
	Steel = Color3.fromRGB(150, 156, 164),
	HazardBlack = Color3.fromRGB(34, 34, 38),
	ContainerBlue = Color3.fromRGB(40, 96, 150),
	ContainerGreen = Color3.fromRGB(58, 122, 82),
	-- Accents
	Glass = Color3.fromRGB(150, 200, 230),
	WindowWarm = Color3.fromRGB(255, 214, 140), -- lit windows
	NeonPink = Color3.fromRGB(255, 110, 160),
	NeonGreen = Color3.fromRGB(120, 255, 140),
	StormCyan = Color3.fromRGB(120, 220, 255),
	Rubber = Color3.fromRGB(32, 32, 34),
	White = Color3.fromRGB(240, 240, 240),
} :: { [string]: Color3 }

-- Roblox materials allowed in Blender object names.
Palette.Materials = {
	Plastic = Enum.Material.Plastic,
	Smooth = Enum.Material.SmoothPlastic,
	Wood = Enum.Material.Wood,
	Planks = Enum.Material.WoodPlanks,
	Brick = Enum.Material.Brick,
	Concrete = Enum.Material.Concrete,
	Metal = Enum.Material.Metal,
	Rusty = Enum.Material.CorrodedMetal,
	Plate = Enum.Material.DiamondPlate,
	Slate = Enum.Material.Slate,
	Glass = Enum.Material.Glass,
	Neon = Enum.Material.Neon,
	Fabric = Enum.Material.Fabric,
	Rubber = Enum.Material.Rubber,
	Grass = Enum.Material.Grass,
	Rock = Enum.Material.Rock,
	Cobble = Enum.Material.Cobblestone,
} :: { [string]: Enum.Material }

-- Parses "Piece__Material__Swatch" (Blender may append ".001"); returns nil if not styled.
function Palette.parseName(name: string): (Enum.Material?, Color3?)
	local _, material, swatch = string.match(name, "^(.-)__(%w+)__(%w+)")
	if not material then
		return nil, nil
	end
	return Palette.Materials[material], Palette.Swatches[swatch :: string]
end

return Palette
