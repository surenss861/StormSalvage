# Storm Salvage V3: Milestone B final report (B2 polish gate)

Branch `v3-art-direction`. Responds to the B2 creative review of `f4fd611`. `main` is untouched
(`0ef9465`). **Milestone C has not started; this report is for final Milestone B approval.**

All measurements are from Roblox Studio on a Mac. No physical device was used, so phone FPS,
memory, draw calls and thermal results are **NOT TESTED**.

## What changed in the polish pass

| Review item | Change | Evidence (`docs/art/v3/b2-final/`) |
| --- | --- | --- |
| P0 Scrap Buyer sign hidden by the dial | Dial lowered from 10.5 to 6.2 studs on its pylon (Blender). Counter, prompt, collision and weigh plate unchanged | `fixed-yard.jpg`, `eye-spawn-scrap-buyer-sign.jpg` |
| P1 Fountain was the weakest asset | New `FountainV3`: octagonal stone basin with capped posts and iron strap repairs, fluted column, two scalloped bowls, teal storm-cog finial. 3,904 tris. The invisible basin collider widened to 15.6 studs, a column collider was added, and the spray moved down to the top bowl. The plaza stays open | `fixed-square.jpg`, `eye-fountain.jpg` |
| P1 Spawn plate isolated | Chamfered steel frame, four bollards, hazard border and painted arrows toward the gate. A tool wall, workbench and gas cylinders sit to the west, and a marked loading bay with pallets, drums and a sorted pile to the east. The centre path is clear | `fixed-yard.jpg`, `fixed-over.jpg` (before: `spawn-before.jpg`) |
| P1 Shredder lacked ground presence | Concrete plinth with a steel edge, a hazard apron and a KEEP CLEAR box. It sits behind the spawn, off every route | `fixed-over.jpg` |
| P1 Street and plaza transitions | Shopfront sidewalk with planters joins the storefronts to the plaza paving. The ramp guard rails are rebuilt as W-beam (posts, spacer blocks, reflectors) that follow the slope with upright posts | `fixed-square.jpg`, `fixed-road.jpg` |
| P2 Sandbags, kit pieces | `SandbagWall` sections replace the primitive bags. A `GuardRail` section lies torn off by the fallen billboard. `Bollard`s frame the spawn | `eye-sandbag-wall.jpg`, `eye-guardrail-debris.jpg` |
| P2 Water tower | New `WaterTowerV3`, moved from 380 studs to about 195 studs from the square. It now shows on the skyline above the Fuel & Go; before, it was past the client draw distance and never seen | `eye-fountain-water-tower.jpg` |
| P2 Elevated-view hard edge | **Root cause:** Atmosphere haze only renders with a Sky object, and calm weather had none. Distant terrain cut off at the draw distance, so flat ground met the sky. **Fix:** a plain calm Sky (V3 profile only) and lighter calm haze (Density 0.30, Offset 0.05, Haze 1.4), so the horizon fades. The far ridge was also raised and made continuous | `edge-east-before.jpg`, `edge-east-after.jpg`, `gate-vista-calm-haze.jpg` |

The hanging car is kept. The new decoration is about 70 small primitive parts (mostly painted ground marks) plus 9 imported asset
instances, all at the spawn, the shredder and the plaza edges.

## Regression (Studio, after all changes)

| Check | Result |
| --- | --- |
| Routes from the spawn to 21 targets (both counters, gate, loading bay, tool wall, ramp foot, stairs, 7 square and shopfront points around the fountain, all districts, motel interior, tow yard) | **Pass, 21 of 21** |
| Loot blocked by the 412 colliding V3/hero parts | **Pass, 0 of 60** |
| Shelter roofs | **Pass, 15** (unchanged) |
| Gear Shop purchase through the shop UI (real clicks) | **Pass**: Backpack 3 → 4, coins 1,327 → 327, save → DataStore `player_<id>` read back Coins 327 / Backpack 4, still there after a fresh Play session (bag 0/14). DataStore format unchanged |
| QA bot, 5 min (collect, sell, upgrade) | **Pass**: 4 full 14-item sales, 695 coins earned, and the bot bought Armor 3 (900 coins), saved and read back as Armor 3 / Coins 172 |
| Lightning + shelter, 2 players | **Pass**: sheltered player under the Fuel & Go canopy took 0 damage. Exposed player by the fountain took 145 damage and died once |
| Flood | **Pass**: water rose through levels 4 → 8 → 12 over the square and the road, and cleared fully in the aftermath |
| Multiplayer consistency | **Pass**: both clients got the same 23 strikes at the same positions and the same 17 storm updates, and saw all 8 hero assets and the same sky |
| Console | No warnings or errors from game scripts |

**Defect found and fixed during regression:** six stray copies of earlier hero models (from an
importer batch) sat in Workspace above the Motel entrance and blocked the Motel interior (routes
19/20). They were moved to `ServerStorage.StrayImports`, not deleted, and the Motel passes again.
Please delete that folder once you've confirmed nothing in it is needed.

## Performance (V3 contract sections C, E, I)

| Metric | Measured | Budget | Status |
| --- | --- | --- | --- |
| Server heartbeat, 2 players, Lightning storm, 30 s | 60.5 /s | ≥58 /s | Pass (Studio) |
| Server script heartbeat time p50 / p95 / max | 0.12 / 0.21 / 0.22 ms | Storm work ≤2 ms p95 | Pass (Studio) |
| Server frame interval p95 / p99 | 17.4 / 17.6 ms (vsync-bound) | CPU p95 ≤10 ms | Server CPU frame time **NOT TESTED** (no MicroProfiler run) |
| Moving debris | 0 | ≤20 | Pass |
| Locally loaded BasePart + MeshPart (no streaming) | 2,846 (936 + 1,910) | ≤5,000 preferred | Pass (Studio) |
| Shadow-casting parts / lights / particle emitters | 1,430 / 49 / 1 | — | Recorded |
| V3 mesh assets in scene, total triangles | 48,080 (7 heroes 36,088; fountain 3,904; water tower 2,324; 3 sandbag sections 3,960; guard rail 332; 4 bollards 1,472) | Hero ≤10,000 each; props 100–2,000 | Pass: largest is GearWorkshop at 8,136 |
| Client GraphicsMeshParts / GraphicsTexture memory | 10.7 / 43.3 MB (Studio) | ≤100 MiB each | Studio only; device **NOT TESTED** |
| Slice build / world-edge build at startup | 25 ms / 296–789 ms across runs | — | Recorded (one-off server startup) |
| Client frame time, five worst-view cameras | Studio throttled the unfocused window to 15 FPS on every view | B gates | **NOT TESTED**, needs a device run |
| Draw calls p95, visible triangles p95 | — | ≤600 / ≤400k | **NOT TESTED** (not readable from scripts; needs device stats) |
| Phone FPS, memory, thermal, join time | — | B, D gates | **NOT TESTED** |

Server memory showed 2,344 MB, but that is the whole Studio process. Section D forbids comparing it
with standalone totals, so it isn't recorded as a server figure.

## Outstanding device gates (blocking production, not this review)

1. A 15-minute physical-device run on the low-end phone (section B): FPS p10 / median, frame-time
   p95 / p99, and thermal.
2. Device draw calls, visible triangles, client memory, PlaceMemory and mesh/texture memory at the
   five worst-view cameras plus each storm phase (sections C and D).
3. Join-to-playable, five cold joins (section D).
4. 4 / 8 / 12-player server runs in a published test experience (section E).
5. Confirm on device that the calm haze hides the far edge at low graphics quality.

## Known minor items

- From the default spawn camera the left gantry tower covers the "S" of SCRAP BUYER. It reads in
  full a step forward and from the `yard` camera.
- The fountain spray emitter is subtle in still captures.
