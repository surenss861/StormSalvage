# Studio playtest: supermarket, gas station, warehouse, motel, town square (2026-10-08)

Tested in Roblox Studio Play mode through the Studio MCP connection, with one player. Screenshots are in [`../qa-screenshots/v3/`](../qa-screenshots/v3/).

## What's in

- 38 imported models: 18 from `build_districts.py` (four building shells and their interiors) and 20 from `build_district_props.py` (props curated from the five-district source pack).
- The asset manifest now covers 85 models with their recorded mesh IDs.
- Every shell sits over the original invisible gameplay walls and roofs. Collision, shelter raycasts, flood rules and the loot grid are unchanged. Old primitive dressing is removed or hidden by `upgradeDistricts()`.

## Results

| Check | Result | Evidence |
| --- | --- | --- |
| All 38 imports present, no duplicates | Pass | Sizes match the Blender bounds |
| Palette styling | Pass | 38/38 styled, no unknown names |
| Console on start | Pass | No warnings or errors |
| Loot grid vs furniture, shelves, racks | Pass (after fix) | Was 7 overlaps (supermarket west wall shelves); now 0 of 236 grid points |
| Every loot point reachable from the building's door | Pass | Pathfinding: Supermarket 63/63, Warehouse 72/72, Gas Station 20/20, Motel 45/45, each house 9/9 |
| Shelter where it looks like cover | Pass | Gas canopy, motel walkway, bus stop, all interiors |
| No shelter where it looks open | Pass | Plaza, repair bay, forecourt edge |
| Pickup inside a supermarket aisle | Pass | Scrap can grabbed with E, beside a sparkling register |
| Spawn to plaza route | Pass | Pathfinding success |
| Server performance (windstorm) | Pass | 1,794 parts (1,464 MeshParts); heartbeat median 16.6 ms, p99 20.0 ms, max 20.8 ms; 0 errors |

## Defects found and fixed

1. **Supermarket west wall shelves covered a loot column** (that column is 1.5 studs from the wall). The wall shelves are now on the east side only.
2. **Old primitive shipping containers by the warehouse** rendered as brown CorrodedMetal boxes. They're replaced with the Scrapyard container model, keeping their collision.
3. **Cargo stack blocked a warehouse bay door**: moved to the building's corner.
4. **Pack clock tower**: its clock faces stuck out sideways and the roof was split. Rewritten before import.

## Not yet done

- Parked cars around town are still the original box primitives.
- The motel and gas station interiors are one open room each; the motel rooms aren't separated.
- No multiplayer, real-device or DataStore tests yet. See `docs/production/FIVE-DISTRICT-QA.md` and `FOLLOWUP-SYSTEMS.md` for the gates.
