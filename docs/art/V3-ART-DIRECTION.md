# Storm Salvage V3 art direction (proposal for review)

**Status:** Milestone A, the art-direction studies. Nothing here has been propagated across the
map. This document stops at the review gate: pick a direction, then the Scrapyard + Town Square
vertical slice gets built in it.

Branch `v3-art-direction`. The V2 rules in [`ART-DIRECTION.md`](ART-DIRECTION.md) still describe
the shipped game; this document replaces them once a direction is approved.

## 1. Audit: what limits the current world

Captured in Studio at 1920×1080 from four fixed cameras: Scrapyard overview, Scrapyard eye level,
the departure road, and Town Square calm and in a storm warning. V2 shots are
`v3/studies/V2-*.jpg`.

| Area | What the screenshots show | Root cause |
| --- | --- | --- |
| Scrapyard at eye level (`V2-yard.jpg`) | Two small shacks and a gate on a big empty dirt plane; the crane and car piles are off to the sides | Layout, not materials. The hub has no foreground, no mid-ground clutter and no sense of a working yard |
| Departure road (`V2-road.jpg`) | Buildings scattered across a huge flat lawn; the world ends at a hard edge | Terrain and composition: no elevation, no tree lines, no backdrop, no density |
| Town Square (`V2-square.jpg`) | Readable and pleasant, but every surface is flat colour; the square is a pad on grass | Materials and edges: no curbs, planting beds, pavement variation or storm history |
| Storm (`V2-storm.jpg`) | Grey sky and lower contrast; recognisably "bad weather" but generic | The storm look is a lighting tween only; nothing in the world reacts |
| Buildings | Clean, chunky, all similar depth | "Chunky, not detailed" and "no image textures" kept everything single-colour and shallow |

**The main finding:** materials and lighting (what these studies change) fix maybe a third of the
problem. The rest is **composition**: the flat lawn, the empty yard, the hard world edge and the
lack of layering. No lighting profile fixes that, which is why the vertical slice has to include
geometry and layout work, not just a re-skin.

## 2. The three studies

Each study is a switchable look profile in `src/server/LookService.luau`. It sets calm and storm
lighting, colour grade, atmosphere, clouds, water, palette saturation and MaterialVariant
overrides. All use the same map, so the comparison is only about style. Switch live in Studio
with `ServerStorage.StormSalvageDebug:Invoke("look", "A")`.

Material boards (4 generated options per material, picked best of 4): `v3/materials-board-*.jpg`.

| | A: Storm-Scarred Arcade | B: Cinematic Storm Town | C: Salvage Adventure |
| --- | --- | --- | --- |
| Screenshots | `A-overview`, `A-yard`, `A-road`, `A-square`, `A-storm` | `B-overview`, `B-yard`, `B-road`, `B-square`, `B-storm` | `C-overview`, `C-yard`, `C-square`, `C-storm` |
| Calm light | Low golden sun (17:03), warm haze, pink-gold cloud edges, cool bounce under eaves | Afternoon (14:36), neutral, deep blue-grey distance haze | Midday (13:12), bright and clean, crisp sky |
| Palette | Saturated paint ×1.1 | Desaturated ×0.72 | Punchy ×1.22 |
| Materials | Hand-painted: riveted metal panels, corrugated rust, cracked concrete, patched asphalt, weathered planks, chunky brick | Realistic PBR-style: scratched steel, flaking rust, poured concrete, clapboard, old brick | Clean cartoon: tile grid concrete, simple planks, cartoon brick. Metal left default (all four generated "toy metal" options painted literal toys on it) |
| Storm | Teal-grey, contrast up; currently too close to V2 | Heavy grey, dark and moody | Lavender-purple; clearly different from calm |
| Feel | Lived-in, warm, a little scruffy. Reads as a scrapyard town | Atmospheric and serious; loses the playful Roblox tone, and the chunky shapes look plain under realistic materials | Bright and toy-like; clean but generic, and the grid tiles look like a template |

### Scoring

1 to 5; mobile cost is relative to V2.

| Criterion | A | B | C |
| --- | --- | --- | --- |
| Brand distinctiveness (recognisable as Storm Salvage) | **5** | 3 | 2 |
| Player readability (loot, ladders, hazards still pop) | 4 | 3 | **5** |
| Fit with the chunky shapes and existing assets | **5** | 2 | 4 |
| Storm contrast potential | 4 | **5** | 4 |
| Production cost | 4 | 2 (realism invites detail everywhere) | **5** |
| Mobile cost | 4 | 3 | **5** |
| **Total** | **26** | 18 | 25 |

C scores close on numbers because it's cheap and readable, but it's the least distinctive, and
"recognisable without the name" is the bar you set.

## 3. Recommendation: A, Storm-Scarred Arcade, with B's depth haze

- **A's materials and warm golden light** carry the identity: painted metal with rivets, patched
  surfaces, warm late sun. It suits the existing chunky assets, which look plain under B's realism.
- **Borrow B's distance haze** (higher atmosphere density and haze far away) so the town gets
  depth and the world edge fades instead of cutting off. Low cost.
- **Borrow C's storm idea:** give each storm a clearly different sky. A's current storm is too
  close to V2. Proposed storm scripts are in §5.

This matches your "Scrapyard Arcade with a hint of Storm Chaser" instinct. The difference: the
Storm Chaser part goes into the weather look and the HUD, not the town's materials.

## 4. Visual identity

**One line:** a sun-baked, toy-bright salvage town that has been patched back together after a
hundred storms, next to a busy, oily scrapyard.

- **Shape language:** keep the chunky silhouettes and exaggerated proportions. Add depth with
  layering (inset windows, overhanging trim, awnings, porches, roof edges), not with small detail.
- **Storm history:** visible repairs on everything. Mismatched replacement panels, boarded windows,
  tarps on roofs, sandbag walls, bent signs, tied-down shutters, scorch marks near lightning
  rods. Restrained: one or two story details per building, not everywhere.
- **Material hierarchy:** hand-painted texture on large, close surfaces (walls, ground, metal
  panels). Plain colour on small props and distant geometry. Neon only for signs and Storm Cores.

## 5. Lighting and colour scripts

| Phase | Light | Grade and atmosphere | Mood |
| --- | --- | --- | --- |
| Calm | Low golden sun, long shadows, cool bounce | Warm tint, saturation +0.24, distance haze toward pink-gold | Inviting, a little nostalgic |
| Warning (12 s) | Sun dims over 6 s; sky darkens from the storm's side | Contrast up, warm tint drains away | Unease: "get ready" |
| Wind | Flat, bright overcast; fast cloud movement | Dusty ochre haze, low saturation | Gritty, hard to see far |
| Flood | Dark blue-grey; wet reflective ground | Teal tint, heavy haze, rain | Heavy, claustrophobic |
| Lightning | Very dark violet; flashes are the main light | High contrast, purple atmosphere | Electric, dramatic |
| Aftermath (15 s) | Sun returns warmer than calm, low and gold | Saturation slightly above calm, light haze | Relief, "go grab the loot" |

Storm atmosphere colours are already tinted per storm (`Config.Storms[...].Color`); the slice
will give each storm its own full profile instead of one shared storm look.

## 6. Architecture, terrain and foliage

- **Buildings:** layered facades with inset windows, sills, trim and awnings; roofs with visible
  edges, gutters and patched sections. Storefronts get physical signs, shutters and a lit window.
- **Streets:** raised curbs, sidewalk edges, drains, crosswalks, cracked and patched asphalt,
  painted lines worn in places, puddle decals after floods.
- **Terrain:** gentle elevation (the town sits in a shallow bowl below the Scrapyard), dirt
  verges, worn paths, drainage ditches that make the flood read. **No flat lawn edge:** the
  boundary becomes hills, a tree line and distant silhouettes (water tower, power pylons,
  farmland) as cheap low-detail backdrop.
- **Foliage:** chunky trees in 3 sizes and 2 species, clustered, not evenly spaced; bushes along
  fences and buildings.

## 7. Interiors

Each enterable building gets one readable layout: entry, a main room with landmark furniture, and
loot spots in clear sightlines. Interiors stay lit (window light plus one warm light, no
shadows). Finish the motel room dividers and the gas station shop interior during the district pass.

## 8. Landmarks and navigation

- From the Scrapyard gate: the clock tower is the town's anchor, the warehouse sawtooth roof is
  left, the motel pole sign is far right. Keep these silhouettes visible above everything else.
- The departure road frames the clock tower. Nothing tall in that sightline.
- Each district gets one colour accent and one landmark object (gas canopy, supermarket sign
  tower, motel pole sign, warehouse crane).

## 9. Animation

Client-side, cheap, phase-driven. Crane slowly swings, floodlights flicker during warnings, loose
signs and tarps flap in gusts (already have tree sway), puddles appear after floods, lightning
leaves scorch decals for the storm. Nothing animated by server physics.

## 10. Mobile and performance

Budgets in [`../production/V3-PERFORMANCE-BUDGETS.md`](../production/V3-PERFORMANCE-BUDGETS.md).
Rules for the slice:

- MaterialVariants are shared across the whole map (6 per study); no per-part unique textures.
- Hand-painted textures ≤1024 px; the generated variants are Roblox-hosted.
- Backdrop scenery is low-poly, non-colliding and not shadow-casting.
- New lights are non-shadow-casting unless a scene needs one specifically.
- Every slice change is measured against the V2 baseline below.

### V2 baseline (Studio, solo, calm, 2026-10-09)

| Metric | Value | Notes |
| --- | --- | --- |
| BaseParts in workspace | 1,759 | 1,425 MeshParts using 417 unique meshes |
| Shadow-casting parts | 1,268 | Biggest easy win if mobile needs it |
| Lights | 26 | |
| Particle emitters (idle) | 1 | Storms add rain/wind/sparks client-side |
| Semi-transparent parts | 62 | |
| Server work per frame (`Stats.HeartbeatTime`) | 0.09 ms median, 0.11 ms max | Real work, solo calm. The 16.6 ms heartbeat interval is just 60 Hz scheduling |
| Server heartbeat interval | median 16.6 ms, p99 17.6 ms | |
| Draw calls, triangles, client memory, FPS | **NOT TESTED** | Need the standalone client or a real device |

## 11. Relationship with the UI

The UI art pass (Milestone D) uses the same identity: painted-metal panels with a few rivets,
SafetyYellow and hazard stripes used sparingly, the warm palette for rewards and the storm colours
for weather. The Gear Shop becomes a mechanic's workbench with item previews. The HUD weather strip
takes the storm-instrument styling. Safe areas, notification priorities and Reduced Effects stay
as they are.

## 12. Plan after approval (Milestone B, vertical slice)

1. Give each storm its own look profile (§5) on the chosen direction.
2. **Scrapyard:** densify the hub. Sell and shop shacks become proper workshop and weigh-station
   buildings; foreground clutter and a crane work area. Blender: new SellShack/GearShack/weigh
   station, workshop props.
3. **Departure road and Town Square:** curbs, sidewalks, terrain shaping, planting, square
   storefronts, storm-repair details.
4. **World edge:** terrain hills, tree line and backdrop silhouettes around the whole map.
5. Re-run the gameplay regressions: shelter, ladders, loot grid, pathfinding, multiplayer.
   Then capture the same 4 camera views and compare with V2.

**Your part:** the new Blender models still need importing through Studio's 3D Importer, the
same way as the earlier batches.
