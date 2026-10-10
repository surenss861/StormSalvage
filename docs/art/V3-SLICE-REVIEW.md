# Storm Salvage V3: Milestone B vertical slice (for creative review)

Branch `v3-art-direction`, not merged. Approved direction: Study A (Storm-Scarred Arcade) with
Study B's distance haze and per-weather skies ([`V3-ART-DIRECTION.md`](V3-ART-DIRECTION.md)).

Everything here was captured in Roblox Studio at 1920×1080 from the same fixed cameras as the
V2 baseline. Before shots: `v3/studies/V2-*.jpg`. After shots: `v3/slice/V3-*.jpg`.

## What changed

| Area | V2 | V3 slice |
| --- | --- | --- |
| **Scrapyard arrival** (`V3-yard.jpg`) | Two shacks on empty dirt | Painted yard road from spawn to gate with safety lines and a hazard-striped gate edge; a yellow arrival gantry ("STORM SALVAGE CO." facing the spawn, "WE BUY WHAT THE STORM LEAVES" facing the gate); festoon lights from the gantry to both counters and across the aisle |
| **Selling and upgrades** | Counters only | A flush steel weigh-scale plate with a small dial in front of the Scrap Buyer (where you stand to sell); a mechanic's lean-to by the Gear Shop with a blue patch panel, tyres, drums and a work lamp |
| **Yard framing** (`V3-overview.jpg`) | Props along the fences | Containers, pallets, tyres and a scrap pile frame the gate approach; ground wear and tyre tracks; two wind flags at the gate |
| **Departure road** (`V3-road.jpg`) | Flat wedge over a lawn | Concrete retaining walls and guard rails on the ramp; chevron "SLOW" boards; a "Welcome to Gale Hollow" billboard (back: "Scrapyard ^"); Bud's Towing, a fenced lot of wrecked cars; a footpath from the side stairs through tree groves. The gate-to-clock-tower sightline stays open |
| **Town Square** (`V3-square.jpg`) | Cobble pad on grass | Paving out to the clock tower, siren and statue; a low stone curb; festoon lights crossing above the fountain; sandbags at the siren tower and statue; boards at the clock tower; a "STORM SHELTER: FUEL & GO CANOPY" sign pointing at real cover |
| **World edge** (`V3-world-edge-south.jpg`) | Flat lawn that stops at the sky | Terrain ground to 1,400 studs; three rings of hills (near, edge row, distant ridge); 37 backdrop trees; a "Gale Hollow" water tower and a line of power pylons |
| **Navigation** (`V3-town-to-yard.jpg`) | | From the square, the clock tower, gate arch and crane line up and lead back to the yard |
| **Lighting** | One calm and one storm look | Golden-hour calm with B's depth haze; wind (dusty ochre overcast), flood (dark teal), lightning (dark violet), and a warmer gold aftermath |
| **Weather reactions** | Tree sway only | Flags follow the wind and whip in gusts; work lamps and floodlights stutter in warnings; festoon bulbs flicker in lightning storms; puddles after floods that dry up in the next calm |

Everything is in `src/server/WorldSlice.luau` (layout, server-built once at startup),
`src/server/LookService.luau` (the V3 look) and `src/client/EnvironmentFX.luau` (reactions).
`V2` is still switchable: `StormSalvageDebug:Invoke("look", "V2")`.

## Gameplay checks (Studio Play)

| Check | Result |
| --- | --- |
| Builds without warnings or errors | Pass |
| No new shelter roofs (shelter = `Map.Roofs`, still 15 parts) | Pass |
| No loot spawn blocked by the 171 new colliding parts (radius-3 overlap test on all 60 items) | Pass |
| Pathfinding from the spawn to 13 targets (both counters, ramp foot, stairs, 3 square corners, all districts, tow-yard gate) | Pass, all succeed, lengths unchanged (e.g. square centre 277 studs) |
| Flood fills to 12 and recedes; hills untouched (terrain kept outside the flood box) | Pass |
| QA autopilot collecting, selling and upgrading through the new layout (calm held, 5 min) | Pass after one fix: 5 sales at 36, 76, 128, 165 and 251 s, 47 items, coins 313 → 463, bought Backpack level 3 |
| Lightning still hurts exposed players; the shelter the new sign points to protects | Pass: 74 damage in 15 s exposed in the square, 0 under the Fuel & Go canopy |
| Flood, lightning and aftermath captured in the slice (`V3-storm-*.jpg`, `V3-aftermath.jpg`) | Pass: puddles appeared after the flood and were visible in the next storm |

## Performance (Studio, solo)

| Metric | V2 | V3 slice | Budget |
| --- | --- | --- | --- |
| BaseParts in workspace | 1,759 | 2,414 | ≤5,000 preferred |
| Shadow-casting parts | 1,268 | 1,386 | (new parts don't cast shadows) |
| Lights | 26 | 38 | small, non-shadowed |
| Server work per frame (`Stats.HeartbeatTime`) | 0.09 ms | 0.04 ms median, 0.11 ms max | ≤10 ms p95 |
| EnvironmentFX client cost (lightning storm, gusting) | – | 0.018 ms/frame | ≤2 ms combined |
| Slice build time at server start | – | 7 ms (parts) + 339 ms (terrain, once) | |
| Draw calls, triangles, client memory, FPS, join time | NOT TESTED | NOT TESTED | needs the standalone client or a real phone |

## Defects found and fixed

1. **Raised weigh-scale plate broke selling for the QA bot.** The 0.4-stud solid plate made the
   bot's approach to the counter fail; its fallback walked behind the counter into the shack and
   got stuck. The plate is now flush and non-colliding. Selling then passed (above).
2. **Gantry signs faced the wrong way**, flipped. **Painted floor arrows** sat in the walkway and
   read as clutter, removed. **Weigh-scale dial** was too tall and blocked the view of the shack,
   made smaller and lower. **Ground-wear patches** looked like holes, recoloured close to the floor.
   **Festoon wires** were too thick, thinned.
3. **The horizon was still flat from the hub**; added an edge row of hills, a distant ridge, and
   extended terrain ground to 1,400 studs so the sky no longer shows past the ground's edge.

## Known defects

1. **A clear cyan band under the storm cloud deck** when seen from the raised road camera in a
   storm. Raising the haze offset didn't remove it (tested, reverted). Needs a sky/cloud fix.
2. **Studio-only test issue:** in MCP-driven Play sessions the client camera kept ending up
   `Scriptable` (no game code sets camera type), which hides proximity prompts. The autopilot now
   resets the camera. Worth a 2-minute check in a normal Play session that prompts behave.
3. Most new pieces are primitives (rails, sandbags, gantry, festoons, water tower). They're
   placeholders for Blender versions (B2).
4. Players can still walk behind the Scrap Buyer counter into the shack (that's V2 geometry,
   not new). Worth blocking in the district pass.

## Next (after review)

- **B2, Blender:** gantry, weigh scale, lean-to, guard rail, sandbag row, festoon string, water
  tower and billboard as modelled assets. You import them with the 3D Importer as before.
- Fix the storm horizon band.
- Then propagate to Houses, Supermarket, Gas Station, Warehouse and Motel (Milestone C).
