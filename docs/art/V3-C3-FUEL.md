# Storm Salvage V3: Milestone C3, Fuel & Go (ready for creative review)

Branch `v3-art-direction`. Follows the C2 review fixes (`bac623f`). `main` is untouched.
**C4 Warehouse has not started; stopping here for C3 review.**

All measurements are from Roblox Studio. Phone and standalone-client gates stay **NOT TESTED**.

## Audit (before, avatar height)

| Weakness | Evidence (`docs/art/v3/c3/`) |
| --- | --- |
| Store interior is an empty concrete box with a wood floor and loot on the ground | `before-interior.jpg` |
| Repair bay is a lift and a rack on a bare pad beside a blank wall | `before-repair-bay.jpg` |
| Forecourt works but has no wear or story; V2 block cars nearby | `before-forecourt.jpg` |

The canopy, pumps and price pylon already read well and the canopy is a tested shelter, so C3
leaves them alone and finishes the store, the bay and the forecourt dressing.

## What changed

| Area | Change | Evidence |
| --- | --- | --- |
| Store interior | Two lit drinks coolers along the back wall, an AUTO supplies rack on the west wall, SNACKS / CHIPS gondolas between loot columns, a cash counter with register, lotto display and hot-dog roller, and a LOTTO • SMOKES cabinet against the east wall. Two fluorescent strips, spilled stock, lino floor | `after-interior.jpg`, `after-interior-counter-side.jpg` |
| Storefront | One window boarded: "NO ICE TILL FRIDAY" | `after-forecourt.jpg` |
| Forecourt | Canopy light panel tagged as a work lamp (flickers in warnings, shorts on nearby strikes); two shadowless light pools under the canopy; a fascia panel hanging loose at the front-west corner; the east pump bagged OUT OF ORDER; an AIR 50¢ machine; two puddle spots | `after-forecourt.jpg`, `after-forecourt-lightning.jpg` |
| Repair bay | A closed SERVICE roll-up door on the store's west wall behind the lift (the wall stays solid), a compressor. Left open-air, so nothing there promises shelter | `after-repair-bay.jpg` |
| Cars | The two V2 block cars near the station are now recoloured sedans | `after-repair-bay.jpg` (background) |

Code: `src/server/DistrictFuel.luau` (new), called after C2. Without `ServerStorage.Assets.v3fuel`
the V2 station builds unchanged (checked in Play: no warnings). Reuses the C2 ceiling light,
boarded window and spill, and the C1 sedan.

## Defects found and fixed during C3 verification

1. **Pathfinder walked through the snack gondola.** Its 0.12–0.2 stud shelves and back panel are
   thinner than the navmesh resolution, so routes cut through and the avatar snagged. Gondolas and
   the wall rack now have one solid invisible collider each, and their meshes don't collide.
2. **Counter cabinet on the wrong side.** The lotto/cigarette cabinet landed on the customer side
   and squeezed the lane to the east loot column (one grid point unreachable). The counter is
   turned so the cabinet sits against the east wall; the lane is open again.
3. Fascia panel floated outside the canopy; garage door read as wall (cracked Metal variant). Moved
   and repainted.

## Imported assets

Nine models, `assets/roblox/v3fuel/`, mesh IDs in `assets/ASSET-MANIFEST.md`. Pump bag, canopy
panel and garage door are visual-only; the others use box collision (gondolas and rack via their
solid colliders).

| Asset | Triangles | Placed |
| --- | --- | --- |
| WallCooler | 1,276 | 2 |
| ShopCounter | 696 | 1 |
| SnackGondola | 624 | 2 |
| Compressor | 420 | 1 |
| WallRack | 384 | 1 |
| GarageDoor | 344 | 1 |
| AirMachine | 228 | 1 |
| PumpBag | 164 | 1 |
| CanopyPanel | 68 | 1 |
| **New meshes placed** | **6,104** | plus reused ceiling lights, boarded window, spill and two sedans |

## Gameplay regression

| Check | Result |
| --- | --- |
| Interior loot grid (20 points): overlapped by new colliders / unreachable from the door | **0 / 0** |
| Avatar walked (real movement) to the four corner loot points and the counter-side column | **Pass**, all reached within 1.5 studs |
| Routes from the spawn (store door, both back corners, counter column, bay, pumps, air machine, truss, cars, plus Supermarket and Houses) | **Pass, 11/11** |
| Shelter roofs | **Pass, 15** (unchanged) |
| Shelter where it looks like shelter | Under canopy **sheltered**, store **sheltered**; east pump, canopy's south edge, repair bay, garage door, air machine **exposed** |
| Lightning, 2 players | Canopy 0 damage vs east pump 145 and 1 death; store 0 vs repair bay 146 and 1 death |
| Flood | Water reached level 12 across the forecourt, store and bay (as in V2; the back truss is the roof escape) and cleared fully in the aftermath |
| Two-client sync | Same 42 strikes on both clients, the same 24 station pieces on both |
| Console | Clean |

## Performance delta (Studio, 2 players, Lightning)

| Metric | After C2 fixes | C3 | Delta | Budget |
| --- | --- | --- | --- | --- |
| Loaded BasePart + MeshPart | 3,105 | 3,260 | +155 | ≤5,000 preferred |
| Shadow-casting parts | 1,364 | 1,394 | +30 (interior shadow pass from the start) | — |
| New lights | — | 3, all shadowless | +3 | — |
| Server heartbeat | 60.5 /s | 60.6 /s | — | ≥58 |
| Script heartbeat time p95 | 0.40 ms | 0.17 ms | — | Storm work ≤2 ms |
| District build time | — | 3 ms | — | — |

Client frame time, draw calls, triangles on screen, memory and every phone gate: **NOT TESTED**.

## Remaining weaknesses (for review)

1. The compressor's coiled hose sits slightly detached from the tank (Blender fix, needs a
   re-import).
2. The canopy's light panel is bright pure white in calm light, like the supermarket tubes were;
   left as the V2/B asset, can be toned the same way.
3. The store floods with the rest of the station, as in V2. Fine for gameplay (roof escape), but
   the store looks like cover.
4. ~~C1 `PrivacyFence` not imported~~ Done 2026-10-12: see `V3-C1-HOUSES.md`.

## C3 review fix: canopy lighting (done)

The canopy's 30 × 14 light panel was pure-white Neon. Dimming the Neon colour wasn't enough (even
mid-grey Neon blooms at that size), so it's now a plain warm-grey light panel (196, 192, 180), and
the two shadowless light pools moved down from y 10 to y 6 so they light the pumps instead of
washing out the panel. It's still tagged V3Lamp (flickers in warnings, shorts on strikes). Local to
the canopy; global lighting unchanged. Same camera, calm and Lightning:
`v3/c3/fix-canopy-calm.jpg`, `v3/c3/fix-canopy-lightning.jpg`.

Deferred per review: compressor hose (next Blender batch), Fuel & Go sign storm contrast (world
consistency pass), store-floods-but-blocks-lightning messaging (UI milestone D).
