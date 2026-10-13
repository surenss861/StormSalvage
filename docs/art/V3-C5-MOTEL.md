# Storm Salvage V3: Milestone C5, Starlite Motel (done, Studio-tested)

Branch `v3-art-direction`. Built under the autonomous completion directive. All measurements are
from Roblox Studio; phone and standalone-client gates stay **NOT TESTED**.

## Audit (before)

| Weakness | Evidence (`docs/art/v3/c5/`) |
| --- | --- |
| The inside is one 110-stud dormitory: six narrow single beds and four dressers along the back wall on wood planks. Nothing reads as motel rooms | `before-interior.jpg` |
| The facade, awning, doors and pole sign already read well from the road | `before-exterior.jpg` |

## What changed

| Area | Change | Evidence |
| --- | --- | --- |
| Rooms | Six partition walls (wallpaper, baseboard and dado rail, a seaside print) split the hall into rooms 101-106 and a central office along a front corridor. Each room has a hanging ROOM number board and a ceiling light | `after-corridor.jpg` |
| 101, 105 intact | Double bed (coral / teal blanket), nightstand lamp, dresser with a CRT TV, armchair | — |
| 102 roof leak | Stripped bed with a stained mattress shoved off the frame, ceiling stain, a dangling tile, a bucket | `after-room102-leak.jpg` |
| 103 left in a hurry | Bed, lamp, an open suitcase spilling clothes, a luggage pile | — |
| 104 flooded | Water line round the walls, mud on the carpet, a muddy bed, an armchair on its back | `after-room104-flooded.jpg` |
| 106 storage | Stripped bed, luggage piles | — |
| Office | Front desk with bell and guest book, a key board, a NO VACANCY lightbox, a soft light | — |
| Walkway and lot | A wall light by every room door (flicker in warnings, short on strikes), storm shutters painted CLOSED / BACK SOON on three windows, two guests' cars | `after-exterior-lightning.jpg` |
| Floor | Carpet instead of planks (same part) | all interior shots |

Code: `src/server/DistrictMotel.luau` (new). Without `ServerStorage.Assets.v3motel` the V2 motel
builds unchanged.

**Not built, by decision:** a walkable second storey (new gameplay space and a new flood refuge).
The motel stays single-storey for this release.

## Imported assets

Eleven models, `assets/roblox/v3motel/`, mesh IDs in `assets/ASSET-MANIFEST.md`. Placed total
**6,552 triangles**; largest piece MotelBed 436.

## Gameplay regression

| Check | Result |
| --- | --- |
| Loot grid (45 points): overlapped by new colliders / unreachable from the door | **0 / 0** |
| Each room's back band reachable | **Pass, 7/7** (six rooms and the office) |
| Avatar walked (real movement) into rooms 101, 102, 103, 104, 106 and the office | **Pass**, all within 1.5 studs |
| Back truss climb (flood escape) | **Pass**: reached y 21 on the roof |
| Routes from the spawn (door, end rooms, office, truss, lot, Warehouse) | **Pass, 7/7** |
| Shelter roofs | **Pass, 15** (unchanged) |
| Lightning, 2 players | Room 102 0 damage, parking lot 145 and 1 death; under the walkway awning 0, 8 studs out 105 |
| Flood, 2 players | Roof 0 damage at level 12; room 104 128 and 1 death (as in V2) |
| Two-client sync | Same 33 strikes on both clients, the same 66 motel pieces |
| Console | Clean |

## Performance delta (Studio, 2 players)

| Metric | After C4 | C5 | Delta | Budget |
| --- | --- | --- | --- | --- |
| Loaded BasePart + MeshPart | 3,264 | 3,438 | +174 | ≤5,000 preferred |
| Shadow-casting parts | 1,359 | 1,359 | 0 (interior shadow pass) | — |
| New lights | — | 1 (office), shadowless | +1 | — |
| Server heartbeat | 60.5 /s | 59.5 /s | — | ≥58 |
| Script heartbeat time p95 | 0.21 ms | 0.62 ms | +0.41 | Storm work ≤2 ms |
| District build time | — | 5 ms | — | — |

The script time p95 rose to 0.62 ms in this run (three Studio instances open, a flood running);
still under a third of the 2 ms storm budget. Watched in F.

## Remaining weaknesses

1. The facade still shows eight room doors while the inside has six rooms (the partitions sit
   between loot columns, not behind the doors).
2. The partition walls are plain: wallpaper colour only.
3. The dangling ceiling tile in 102 was too bright and large (fixed in code: smaller, stained).
