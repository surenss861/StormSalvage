---
related-code:
  - "[[DistrictHouses.luau]]"
domain: world
type: spec
status: stable
tags: [storm-salvage, world]
---
# Storm Salvage V3: Milestone C1, Houses district (ready for creative review)

Branch `v3-art-direction`. Milestone B (`b2cc012`) is the quality reference. `main` is untouched.
**C2 Supermarket has not started; stopping here for C1 review.**

All measurements are from Roblox Studio. Phone and standalone-client gates stay **NOT TESTED**.

## Audit (before, avatar height)

| Weakness | Evidence (`docs/art/v3/c1/`) |
| --- | --- |
| Four houses from two flat shells, only the paint differs | `before-street.jpg`, `before-between-houses.jpg` |
| Back gardens are open lawn with no lot boundaries; nothing says people live here | `before-overview.jpg` |
| Flood-escape climbs are bare yellow truss parts | `before-overview.jpg` |
| No landmark; the lane just stops at a road-closed barrier | `before-overview.jpg` |

The layout itself works: the lane between the rows, front paths, and four reachable trusses.
So C1 keeps the layout and upgrades the architecture and the yards. Nothing was recomposed.

## What changed

| Change | Detail | Evidence |
| --- | --- | --- |
| V3 house shells (`HouseV3A`, `HouseV3B`) | Lap siding, a stone skirt with crawlspace vents, gutters and downpipes, porch balusters and chairs, an open front door, house numbers. Storm story per variant: A has a blue tarp weighted with sandbags, torn shingles and window boxes; B has a bent satellite dish, a hanging gutter, torn shingles and sandbags at the door. Same 30 × 28 footprint, door, ridge and porch widths as V2, so collision, shelter and loot are unchanged. Per-house wall and roof colours kept | `after-street.jpg`, `after-between-houses.jpg`, `after-garden.jpg` |
| Roof ladders | A galvanised ladder mesh over each flood-escape truss. The truss still does the climbing and is now invisible | `after-garden.jpg` |
| Gardens | Board fence along the back gardens of the south row and between the two lots, a garden shed, a clothesline | `after-garden.jpg`, `after-overview.jpg` |
| Driveway | Shared concrete driveway between the street-side houses, the family car under a fallen branch | `after-between-houses.jpg` |
| Landmark | An uprooted oak across the west end of the lane, root plate standing up behind the road-closed barrier, with a sawn round left by the road crew. It closes the lane's sightline | `after-lane-oak.jpg` |
| Weather | Two puddle spots in the lane after floods (EnvironmentFX) | — |

Code: `src/server/DistrictHouses.luau` (new), called from `MapBuilder` after the V3 slice.
Without `ServerStorage.Assets.v3houses` the V2 district builds unchanged (checked in Play: no
warnings). A flipped trampoline was modelled and cut because it didn't read as a trampoline.

## Imported assets

Eight models, `assets/roblox/v3houses/`, mesh IDs in `assets/ASSET-MANIFEST.md`. Houses, ladder, oak
and clothesline are visual-only; the fence, shed and sedan use box collision; the oak has one
invisible trunk collider.

| Asset | Triangles | Note |
| --- | --- | --- |
| HouseV3A / HouseV3B | 5,892 / 5,920 | Building module (2,000–6,000). Lighter than V2 `HouseA`/`HouseB` (6,116 / 5,996) because the windows were rebuilt cheaper |
| FallenOak | 1,972 | |
| Sedan | 1,328 | |
| PrivacyFence (×16) | 660 | |
| RoofLadder (×4) | 568 | |
| Clothesline / GardenShed | 344 / 332 | |

## Gameplay regression

| Check | Result |
| --- | --- |
| Routes from the spawn to 17 district targets (inside each house, each back corner, each truss foot, both gardens, driveway, lane) | **Pass, 17/17** |
| Loot blocked by the 48 new colliders | **Pass, 0 of 60** |
| Shelter roofs | **Pass, 15** (unchanged) |
| Shell/ladder meshes colliding | **None** (checked) |
| Roof climb, all four ladders, real avatar movement | **Pass**: climbed to the roof (y about 22) on each |
| Flood escape, 2 players | **Pass**: on the House 3 roof at level 12, 0 damage; in the lane 128 damage and 1 death |
| Porch shelter, Lightning, 2 players | **Pass**: House 2 porch is sheltered, 0 damage; the exposed garden took 146 damage and 1 death |
| Oak collision | **Pass**: trunk collider blocks at three points along it, and paths go round it |
| Two-client sync | **Pass**: same 30 strikes and 15 storm updates on both clients, the same 24 district pieces on both |
| Console | Clean |

## Performance delta (Studio, 2 players, Lightning)

| Metric | B final | C1 | Delta | Budget |
| --- | --- | --- | --- | --- |
| Loaded BasePart + MeshPart | 2,846 | 2,922 | +76 | ≤5,000 preferred |
| Shadow-casting parts | 1,430 | 1,515 | +85 | — |
| Server heartbeat | 60.5 /s | 60.7 /s | — | ≥58 |
| Server script heartbeat time p95 | 0.21 ms | 0.18 ms | — | Storm work ≤2 ms |
| District build time | — | 4 ms | — | — |
| District triangles (4 houses + kit) | 24,224 (V2 shells) | 40,432 | +16,208 (16 fence sections are 10,560 of it) | — |

Client frame time, draw calls, triangles on screen, memory and every phone gate: **NOT TESTED**.

## Remaining weaknesses (for review)

1. **Lightning storm readability.** The district is very dark: windows don't glow (glass, not
   neon), only the porch lamps are lit, and the oak disappears (`after-lane-lightning.jpg`). Options
   are faint neon window panes or one street lamp at each end of the lane, decided at review rather
   than adding lights unasked.
2. From the street, the siding reads faintly in flat light; it reads well up close.
3. Two shell variants still share a silhouette. A third roof form (hip roof) would need its own
   collision wedges in `MapBuilder`, so it was left out of C1.
4. Interiors are the V2 furniture set.
5. The ladder's lower wall brackets stick out slightly past the wall.
6. `PrivacyFence` is 660 triangles, above the 100–500 guideline for a repeated small prop. The 16
   sections are 10,560 triangles. Unbevelling the boards would roughly halve that; not done yet.

## Fence optimisation (C1 review fix 2): done and verified in game

The 308-triangle `PrivacyFence` was imported on 2026-10-12 and replaces the 660-triangle mesh
(new mesh IDs in `assets/ASSET-MANIFEST.md`).

- All 16 placed sections use the new mesh (checked by mesh ID in Play).
- Collision unchanged: rays across the fence line hit it at 4 of 4 points; routes from the spawn to
  both gardens and both ladder feet still succeed.
- **Savings: 16 × (660 − 308) = 5,632 triangles** (10,560 → 4,928). District total 40,432 → 34,800.
- Same garden camera, before and after: `v3/c1/fence-before-660.jpg`, `v3/c1/fence-after-308.jpg`.
  No visible difference.
