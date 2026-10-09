# Storm Salvage: Art Direction

## The one-line pitch

A sun-baked, slightly cartoonish small town that keeps getting hammered by storms, next to a busy, oily salvage yard. Calm weather feels warm and inviting; storms drain the color out and make everything rattle.

## Style rules

1. **Chunky, not detailed.** Thick trim, fat window frames, oversized roofs and doors, 10–20% exaggerated proportions. Every mesh is bevelled so edges catch light. No thin greebles that vanish on a phone screen.
2. **Silhouette first.** Each building must be identifiable from its outline at 100 studs: gas-station canopy, supermarket sign tower, motel walkway and pole sign, warehouse sawtooth roof, houses with chimneys and porches.
3. **Weathered, lived-in.** Patched roofs, leaning fences, missing shingles, rust streaks, boarded windows, vines. Storms have clearly happened here before.
4. **Color from material and palette, not textures.** Meshes are split by material and colored from `src/shared/Palette.luau`. No image textures in V2, which keeps memory low on mobile and lets lighting do the work.
5. **Warm town, cold storm.** Walls use saturated warm swatches (Terracotta, Mustard, Coral, Cobalt, Teal) with Cream trim. The Scrapyard uses SafetyYellow, Rust, Gunmetal. Storm lighting desaturates and cools everything.
6. **Readability beats decoration.** Loot, shelters, ladders and hazards must stand out from the dressing. Ladders are always SafetyYellow; shelter roofs overhang visibly; loot carries rarity color.

## Palette

The source of truth is `src/shared/Palette.luau`. Groups:

| Group | Swatches |
| --- | --- |
| Walls | Terracotta, Mustard, Coral, Cobalt, Teal, Mint, Plaster |
| Trim | Cream, White |
| Roofs | RoofRed, RoofBrown, RoofSlate |
| Nature and ground | Grass, GrassDark, Leaf, Bark, Sand, Stone, Asphalt, Concrete |
| Industrial | SafetyYellow, Rust, RustDark, Gunmetal, Steel, HazardBlack, ContainerBlue, ContainerGreen |
| Accents | Glass, WindowWarm, NeonPink, NeonGreen, StormCyan, Rubber |

## Scale

- 1 Blender unit = 1 stud. Import with the 3D Importer's **Scale Unit: Studs**.
- Default avatar is about 5 studs tall; doors are 4.5 × 8, ceilings 11–13, steps 1 stud high.
- Loot items are exaggerated 1.3–1.5× real size so they read from 30 studs away.
- Axes after import (verified in Studio): Blender −Y (front) → Roblox −Z (the model's LookVector), Blender Z → Roblox Y, Blender +X → Roblox −X. Model pivots land at the asset's base center.

## Asset specifications

| Rule | Value |
| --- | --- |
| Triangles | ≤ 2,000 for props, ≤ 6,000 per building piece, ≤ 20,000 hard limit per mesh (Roblox) |
| Origin | Bottom center of the object, so it sits on the ground at y = 0 |
| Object names | `Piece__Material__Swatch`, for example `Wall__Brick__Terracotta`. `Material` is a key in `Palette.Materials`, `Swatch` a key in `Palette.Swatches` |
| Collisions | Visual meshes use `Box` or `Hull` collision fidelity. Gameplay-critical collision (walls, floors, roofs in the Roofs folder) stays as simple invisible parts placed by code |
| Export | FBX, Apply Scalings: FBX Unit Scale, Path Mode: Copy, no leaf bones, no baked animation |
| Source | Every export has a generator script in `tools/asset_pipeline/` and a `.blend` in `assets/blender/` |

## Pipeline

1. `tools/asset_pipeline/build_*.py` generates a `.blend` and exports `.fbx` files with Blender in background mode.
2. The FBX batch is imported through Studio's 3D Importer (Scale Unit: Studs) into `ServerStorage.ImportedAssets`.
3. The importer uploads each mesh to the owner's Roblox account. The resulting mesh IDs are recorded in `assets/ASSET-MANIFEST.md`.
4. `AssetStyler` applies material and color from object names, so recoloring never requires a re-import.
5. The styled models are saved to `assets/roblox/*.rbxm`, which Rojo syncs into `ServerStorage.Assets`, and placed by the map code.
