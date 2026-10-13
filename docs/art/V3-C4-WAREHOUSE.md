---
related-code:
  - "[[DistrictWarehouse.luau]]"
domain: world
type: spec
status: stable
tags: [storm-salvage, world]
---
# Storm Salvage V3: Milestone C4, Warehouse 7 (done, Studio-tested)

Branch `v3-art-direction`. Built under the autonomous completion directive (no stop for review).
All measurements are from Roblox Studio; phone and standalone-client gates stay **NOT TESTED**.

## Audit (before, avatar height)

| Weakness | Evidence (`docs/art/v3/c4/`) |
| --- | --- |
| Interior is eight identical 9-stud racks on a wood-plank floor; no zones, nothing tall | `before-interior.jpg` |
| Exterior reads as a sign on a box; the loading dock has nothing at it | `before-front.jpg`, `before-dock.jpg` |

The shell (sawtooth roof, bay doors, sign) and the rack layout between loot rows already work,
so C4 keeps the layout and builds the zones into the existing rack rows.

## What changed

| Zone | Change | Evidence |
| --- | --- | --- |
| Receiving (front row) | Wrapped, strapped freight stacks of three heights labelled INBOUND, a RECEIVING floor stencil inside the door | `after-interior.jpg` |
| Storage (middle rows) | 14-stud selective racks in two kinds: cartons on four levels, and drums and sacks on three. Coral beams, cobalt uprights, bay labels A-1 to C-2 | `after-interior.jpg` |
| High value (back row, east) | Welded mesh cage with tagged crates and a padlock, signed HIGH VALUE. Reward rules unchanged | — |
| Equipment | Overhead 10 TON bridge crane across the hall between the storage rows (hook above the centre aisle, at about 10 studs), a 480V breaker wall with conduit and an extinguisher, a painted forklift lane down the centre aisle, a concrete floor | `after-interior.jpg` |
| Exterior | GALE FREIGHT box truck backed up to the east loading dock with freight inside, dock lights over both bay doors, two siding repair patches, two roof extractor fans | `after-front.jpg` |
| Storm | The V2 hanging lamps and the dock lights are work lamps: they flicker in warnings and short out on nearby strikes. Two puddle spots by the dock | `after-interior-lightning.jpg` |

Code: `src/server/DistrictWarehouse.luau` (new). Without `ServerStorage.Assets.v3ware` the V2
warehouse builds unchanged (checked in Play: no warnings).

**Vertical gameplay.** Each rack-row piece gets one invisible collider. The tall racks' colliders
reach y 21.5, just under the roof, so a rack top is never a reachable ledge or a new refuge above
the 12-stud flood line; the warehouse still floods as in V2 and the back truss stays the roof
escape. The crane is visual-only and non-colliding, so it never looks climbable but solid.

## Imported assets

Ten models, `assets/roblox/v3ware/`, mesh IDs in `assets/ASSET-MANIFEST.md`. Placed total
**11,084 triangles** (replacing eight V2 racks). Heaviest: TallRackB 1,560 (first pass 4,104;
drums and sacks unbevelled).

| Asset | Triangles | Placed |
| --- | --- | --- |
| TallRackB | 1,560 | 2 |
| BoxTruck | 1,456 | 1 |
| MeshCage | 1,100 | 1 |
| OverheadCrane | 808 | 1 |
| TallRackA | 772 | 3 |
| SidingPatch | 388 | 2 |
| FreightStack | 288 | 2 |
| BreakerPanel / RoofFan | 236 each | 1 / 2 |
| DockLight | 112 | 2 |

## Gameplay regression

| Check | Result |
| --- | --- |
| Loot grid (72 points): overlapped by new colliders / unreachable from the door | **0 / 0** |
| Live loot overlapped | **0** |
| Avatar walked (real movement) to the four corners and the cage | **Pass**, all within 1.5 studs |
| Back truss climb (flood escape) | **Pass**: reached the roof (y 29) |
| Routes from the spawn (door, back corners, cage, truss, dock, truck side, plus Fuel & Go and Motel) | **Pass, 9/9** |
| Shelter roofs | **Pass, 15** (unchanged); inside sheltered; dock, truck and yard exposed |
| Lightning, 2 players | Inside 0 damage; dock 145 and 1 death |
| Flood, 2 players | Roof 0 damage at level 12; inside the hall 112 damage (as in V2) |
| Two-client sync | Same 21 strikes on both clients, the same 30 warehouse pieces |
| Console | Clean |

## Performance delta (Studio, 2 players)

| Metric | After C3 | C4 | Delta | Budget |
| --- | --- | --- | --- | --- |
| Loaded BasePart + MeshPart | 3,260 | 3,264 | +4 (racks replaced) | ≤5,000 preferred |
| Shadow-casting parts | 1,394 | 1,359 | −35 | — |
| New lights | — | 2, shadowless | +2 | — |
| Server heartbeat / script time p95 | 60.6 /s, 0.17 ms | 60.5 /s, 0.21 ms | — | ≥58 /s; storm ≤2 ms |
| District build time | — | 3 ms | — | — |

Client frame time, draw calls, triangles on screen, memory and phone gates: **NOT TESTED**.

## Remaining weaknesses

1. The crane's 10 TON plate was dark-on-dark (fixed in code: yellow text).
2. The truck stands slightly proud of the dock edge from some angles.
3. Compressor hose fix (C3): the re-exported `Compressor.fbx` still wasn't picked up by the last
   import; the game uses the old hose mesh.
