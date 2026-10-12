# Storm Salvage V3: Milestone C2, Super Saver supermarket (ready for creative review)

Branch `v3-art-direction`. Follows the C1 review of `1e5d6d8` (C1 fixes in `0aab9bc`). `main` is
untouched. **C3 Gas Station has not started; stopping here for C2 review.**

All measurements are from Roblox Studio. Phone and standalone-client gates stay **NOT TESTED**.

## Audit (before, player height)

| Weakness | Evidence (`docs/art/v3/c2/`) |
| --- | --- |
| Interior is one repeated shelf unit in rows on a wood-plank floor; no checkout, no departments, no ceiling fixtures or signs | `before-interior.jpg` |
| No storm story inside or out | `before-interior.jpg`, `before-storefront.jpg` |
| Parking lot cars are V2 primitive blocks | `before-storefront.jpg` |

The storefront and the loot layout (9 × 7 grid between three shelf rows) already work, so C2 keeps
the layout and dresses the store around it.

## What changed

| Change | Detail | Evidence |
| --- | --- | --- |
| Departments | Front shelf row is now produce islands (crates, misting bar), back row is double-sided freezers (one cracked door taped), middle row stays V2 pantry shelving. Same 12 × 2 footprints as the shelves they replace | `after-interior.jpg` |
| Aisle signs | PRODUCE / PANTRY / FROZEN hanging over the centre aisle, readable from the door, with STAFF ONLY visible at the far end | `after-interior.jpg` |
| Checkout line | Four numbered lanes along the front windows (belt, register, candy rack, lit lane-number light), set in the gaps between loot columns; door lanes left open | `after-checkout.jpg` |
| Ceiling | 12 fluorescent fixtures; 3 carry a shadowless light. All are tagged as work lamps, so they flicker in storm warnings and short out on nearby strikes | `after-interior-lightning.jpg` |
| Stockroom | STAFF ONLY double doors on the back wall (the wall stays solid, per your decision), a receiving area outside the loading door with a cardboard baler and stock pallets | `after-interior.jpg` |
| Storm story | A roof leak (dangling ceiling tile, stain, bucket, wet-floor sign), flat spilled stock in two aisles (no collision), and a boarded front window painted "STILL OPEN!" | `after-storefront.jpg` |
| Floor | Shop tile (same part, so collision is unchanged) | all interior shots |
| Parking lot | V2 block cars replaced by the Houses sedan, recoloured and without its fallen branch; two carts the wind tipped; one restrained lot lamp | `after-storefront.jpg` |

Code: `src/server/DistrictSupermarket.luau` (new), called from `MapBuilder` after C1. Without
`ServerStorage.Assets.v3market` the V2 store builds unchanged (checked in Play: no warnings).
The Sedan comes from `v3houses`, so it's reused rather than rebuilt.

## Imported assets

Eleven models, `assets/roblox/v3market/`, mesh IDs in `assets/ASSET-MANIFEST.md`. Signs, ceiling
lights, staff doors, spills, the leak and the boarded window are visual-only. Shelves, counters,
box stacks and the baler use box collision.

| Asset | Triangles | Placed | Note |
| --- | --- | --- | --- |
| ShelfProduce | 1,320 | 4 | First pass was 2,472; fruit merged into one mound per crate |
| ShelfFreezer | 816 | 4 | |
| BoxStack | 552 | 2 | |
| CheckoutCounter | 420 | 4 | |
| StaffDoors | 272 | 1 | |
| SpilledGoods | 288 | 2 | |
| Baler | 256 | 1 | |
| BoardedWindow | 148 | 1 | |
| RoofLeak | 120 | 1 | |
| AisleSign | 112 | 3 | |
| CeilingLight | 80 | 12 | |
| **Placed total** | **13,996** | | Minus the 8 V2 shelves removed |

## Gameplay regression

| Check | Result |
| --- | --- |
| Every interior loot grid point (63), path from the door | **Pass, 63/63 reachable; 0 overlapped by new colliders** |
| Live loot overlap check | 4 of 60 flagged by the 2.5-stud radius check against mesh bounding boxes; measured gap to the real surface is about 2.4 studs on all four, the same clearance the V2 shelves left. Not blocked |
| Routes from the spawn (door, checkout, frozen aisle, receiving, back truss, lot, plus Houses and Motel) | **Pass, 8/8** |
| Shelter roofs | **Pass, 15** (unchanged) |
| False shelter at the receiving area, lot lamp, parked cars | **None** |
| Lightning, 2 players | **Pass**: checkout aisle sheltered, 0 damage; parking lot exposed, 145 damage, 1 death |
| Two-client sync | **Pass**: same 33 strikes and storm updates on both clients, the same 40 store pieces on both |
| Console | Clean |

## Performance delta (Studio, 2 players, Lightning)

| Metric | After C1 fixes | C2 | Delta | Budget |
| --- | --- | --- | --- | --- |
| Loaded BasePart + MeshPart | 2,927 | 3,102 | +175 | ≤5,000 preferred |
| Shadow-casting parts | 1,454 | 1,568 | +114 | — |
| New lights | — | 4 (3 ceiling, 1 lot), all shadowless | +4 | — |
| Server heartbeat | 60.7 /s | 60.6 /s | — | ≥58 |
| Server script heartbeat time p95 | 0.18 ms | 0.16 ms | — | Storm work ≤2 ms |
| District build time | — | 7 ms | — | — |

Client frame time, draw calls, on-screen triangles, memory and every phone gate: **NOT TESTED**.

## C1 fix status

- Lane lamps: done and verified (`docs/art/v3/c1/fix-lane-lightning-lamps.jpg`).
- Fence 660 → 308 triangles: built and committed, **but not in game yet**. `PrivacyFence.fbx` was
  not in this import batch (the stored copy still has the 660-triangle mesh IDs), so the
  same-camera before/after is still owed.

## Remaining weaknesses (for review)

1. **Shadow casters.** The store adds 187 shadow-casting parts, mostly shelf goods and freezer
   pieces. Turning shadows off on goods and small fixtures inside a roofed building is likely free
   visually; not done yet.
2. From inside the store, the checkout line is hidden behind the produce row from most angles; it
   reads from the front aisle and the door.
3. The produce island is the most expensive piece at 1,320 triangles × 4.
4. The tile floor washed out bright in calm light, so I darkened it one step; recheck on device.
5. Stockroom is a door only (your decision); walk-in stockroom stays on the backlog.
