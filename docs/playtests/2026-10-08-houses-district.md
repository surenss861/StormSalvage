# Studio playtest: Scrapyard kit and Houses district (2026-10-08)

All tests ran in Roblox Studio Play mode through the Studio MCP connection, with one player. Screenshots are in [`../qa-screenshots/v2/`](../qa-screenshots/v2/).

## What changed

- 47 Blender assets are in the game: 11 salvage items, 15 Scrapyard pieces, and 21 town pieces (2 house shells, 4 furniture pieces, 15 street props and debris).
- Each house keeps its invisible gameplay walls, floor and roof, so collision, shelter raycasts, flood and lightning rules are unchanged. The Blender shell draws the house and is recolored per house from the palette.
- The house loot grid moved 2 studs inward (`LootMargin = 6`, 9 points per house), so furniture against the walls never overlaps loot. With 4 houses the zone still has 36 points for a cap of 10 items.
- Porch roofs now count as shelter.

## Results

| Check | Result | Evidence |
| --- | --- | --- |
| All 21 town imports: scale, orientation, mesh count | Pass | Sizes match the Blender bounds; fronts face −Z |
| Palette styling | Pass | 21 of 21 styled, no unknown names |
| Map builds with no warnings | Pass | Console clean on start |
| Loot vs furniture overlap | Pass | 0 overlaps across 4 houses |
| Walk in through the front door | Pass | Pathfinding from the yard to inside House 3 |
| Shelter inside houses | Pass | `isSheltered` true inside all 4 |
| Shelter on porches | Pass (after fix) | Was false; added porch shelter parts. 100 HP after 12 s on a porch in a lightning storm |
| Lightning in the open yard | Pass | 100 → 34 HP in 8 s, so the danger is real outside |
| Pickup of model loot | Pass | Old TV picked up, toast and bag updated |
| Selling at the new shack counter | Pass | +15 coins |
| Survivor bonus | Pass | +25 after the storm |

## Defects found and fixed

1. **Bed sideways in the room**: it stuck 7 studs out from the wall toward the loot grid. Now runs along the east wall; verified in `houses-after-interior-bed-fixed.jpg` (the earlier interior shot shows the bug).
2. **Porches looked like cover but weren't**: added shelter parts.
3. **Crane jib pointed off the plateau**: Blender +X becomes Roblox −X on import, so the model is now rotated 180°.
4. **CorrodedMetal painted every metal surface brown**: now limited to rust swatches.
5. **Roof slopes in the house generator were rotated the wrong way**: fixed before import.
6. **Rojo 7.4 couldn't read `.rbxm` files from current Studio**: pinned Rojo 7.7.1.
7. **Test-camera artifact**: prompts don't trigger while the QA camera is scripted far away. This is a testing issue, not a game bug; documented so it isn't mistaken for one.

## Performance (server, Studio, windstorm)

- 1,369 parts (951 MeshParts) and 4,880 instances.
- Heartbeat median 16.7 ms, p95 17.7 ms, p99 18.7 ms; one frame of about 50 ms in a 10 s window.
- Moving all 63 loot items with their welded meshes costs 0.02 ms per frame on the client.
- Client frame rate still can't be measured in Studio (window throttling). It needs a real device.

## Still open for this district

- The houses' lane and back yards are sparse compared with the front yards.
- The interiors are one room. Interior walls or a second room would make searching more interesting, but they'd change the loot grid.
- No multiplayer or real-device test yet.
