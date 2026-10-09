# Storm Salvage V1: Studio QA Report

Date: 2026-10-08. Every result below was produced in Roblox Studio through the built-in Studio MCP server: Play mode, real keyboard and mouse input, server and client inspection, and screenshots. Things that weren't tested are listed in **Not verified**. Screenshots are in [`qa-screenshots/`](qa-screenshots/).

## Verdict

The core loop works end to end in Studio: spawn, salvage, sell, upgrade, all three storms, Storm Cores, death drop, and the survivor bonus. I fixed 13 defects found during play and retested each one. The game is **ready for a private playtest with real people**. It is **not ready for public launch**. The blockers are listed at the bottom.

## Test results

| Area | Result | How it was tested |
| --- | --- | --- |
| Spawn and movement | Pass (after fix) | Spawned facing away from town; now faces the shops and gate |
| Picking up salvage | Pass | Held E on items with real key input; bag count, value, toast, and sound update |
| Bag capacity | Pass | Capacity 3 → 5 after the Backpack upgrade |
| Selling | Pass | Walked back up the ramp with character navigation, pressed E: coins credited, bag emptied |
| Buying upgrades | Pass | Clicked each Buy button: coins deducted correctly, walk speed 16 → 18, armor applied. "Need X more coins" shown |
| Windstorm | Pass (after tuning) | Debris hits players (14 damage, max 16 debris pieces), wind push now about 10 studs per 10 s |
| Flash flood | Pass (after fix) | Used to kill in about 10 s; now about 25 s for a player standing still. Ladder climb out of water confirmed on the warehouse |
| Lightning | Pass | Warning circles shown 1.6 s before each strike; 35 damage per strike; a player standing still dies in about 10 s, a moving player can dodge |
| Shelter (roofs, awnings) | Pass | No damage while under the motel awning for a whole storm |
| Storm Cores | Pass (after fix) | Used to spawn indoors; now always on open ground. Pickup, 250 value, and server-wide announcement confirmed |
| Survivor bonus | Pass (after fix) | +25 coins when in town for at least half the storm and alive. Players who die, or walk down at the last second, no longer get it |
| Death and dropped bag | Pass (after redesign) | Bag drops where the player died; the owner recovered it after respawning |
| Flood fully drains | Pass | 0 water left in the terrain after the storm |
| Round transitions | Pass | Calm → Warning → Storm → Aftermath → Calm, for every storm type |
| HUD and shop on a phone | Pass (after fix) | iPhone 7 (666×374) in the device simulator: HUD now scales down; shop fits |
| Console errors | Pass | 0 errors or warnings in the final run, after fixing a client error found in the second-to-last run |
| Lint (selene), formatting (StyLua), type check (luau-lsp + Roblox definitions), Rojo build | Pass | All pass. StyLua was **not** passing in the original build |

## Defects found in play and fixed

1. **Flash flood was nearly unwinnable.** Players took 10 HP/s from the first 4 studs of water, so death came about 10 s into the storm. Now 5 HP/s, tunable in `Config.StormTuning`.
2. **Survivor bonus could be farmed.** It paid anyone standing in town at the final second, including players who had died. It now requires half the storm spent in town without dying.
3. **Players spawned facing away from town and the shops.**
4. **Storm Cores spawned inside buildings**, which contradicted the risk/reward design. They now spawn on open ground, with extra pickup reach in case they're under flood water.
5. **The "SELL HERE" sign didn't render** in Studio captures (`AlwaysOnTop` billboard).
6. **The main road ran straight through the motel.**
7. **Death drops silently deleted items** beyond the 10th, and floated on flood water.
8. **No server-side distance check** on loot and sell prompts: a hacked client could trigger them from across the map.
9. **A save could report success without saving** when another server held the profile lock. That could confirm a Robux purchase without saving it.
10. **The HUD stats panel sat under the Roblox chat window.**
11. **The HUD took over a third of a phone screen.**
12. **The Gear Shop covered "Need X more coins" messages.**
13. **A wind-push regression I introduced** while refactoring the HUD: it broke the push and leaked one object per frame. Caught by the console in the regression run and fixed.

## Changes beyond bug fixes

- **World pass.** Scrapyard rebuilt as a fenced hub with two facing shops, a crane landmark, scrap piles, and a gate arch. Storefront signs, gabled houses, sidewalks and crosswalks, a parking lot, shipping containers, a motel walkway and neon sign, a storm siren tower, power lines, and better trees. Loot now floats and spins, with real shapes. A warm daytime lighting grade turns cold and dark during storms; flood water is muddy. The map has 667 parts (it had 283), all anchored, with decorative parts set not to cast shadows.
- **Sound.** Siren on storm warnings; rain, flood, and wind ambience; distance-delayed thunder with a screen flash; and sounds for pickup, rare finds, selling, and upgrades. All come from Roblox's licensed ProSoundEffects and APM libraries (IDs in `Config.Sounds`).
- **Dropped-bag design.** Only the owner can grab their bag for 20 s; after that anyone can, until it despawns at 60 s. This keeps the drama without letting someone camp a new player's first death.
- **QA tooling.** `DebugService` (exists only in Studio) can skip phases, force a storm type, and grant coins. `tools/studio-sync.luau` syncs `src/` into Studio when Rojo isn't running.

## Performance (measured in Studio)

- Server: steady 60 Hz heartbeat during a windstorm, 20 ms worst frame, 60 physics FPS, at most 16 debris pieces.
- Client game code: animating all 63 loot items takes 0.26 ms per frame; a shelter check takes about 1 µs.
- Client frame rate couldn't be measured meaningfully. Studio capped its unfocused window at about 15 fps even when the camera looked at empty sky. Measure on a real device.

## Not verified (needs a published test place or real hardware)

- **DataStore saving and loading, session locking, and recovery.** The place is unpublished (PlaceId 0), so every session used a temporary profile. I reviewed the code and fixed the lock bug above, but it hasn't run against real DataStores.
- **Purchases and `ProcessReceipt`.** All product IDs are 0, so purchases are hidden. Reviewed only: receipts are recorded in the profile, and a grant is only confirmed after a successful save.
- **Multiplayer.** The Studio MCP drives one client. Not tested: two players racing for the same item, taking someone else's bag after 20 s, the protected-bag message, and joining mid-storm.
- **Real phones.** Layout was checked in the device simulator only. Not tested: touch prompts, frame rate, heat, and memory on low-end Android.
- **Audio feel.** The sounds load and trigger, but I couldn't listen to them. Someone needs to check volume balance by ear.

## Publishing a private test version

1. In Studio, **File → Publish to Roblox As…** and create a **new** experience, for example "Storm Salvage (Test)". Don't use the future production experience.
2. **Game Settings → Security**: turn on **Enable Studio Access to API Services** (DataStores in Studio, for test data only).
3. **Game Settings → Permissions**: keep the experience **Private** and add testers as collaborators or friends.
4. Run two Studio sessions (**Test → Clients and Servers**, 2 players), then a live server with a friend:
   - Leave and rejoin: coins and upgrades persist.
   - Join a second server immediately after leaving: no data duplication, and the profile loads after the lock releases.
   - Die holding loot: the other player sees "That's X's bag" for 20 s, then can take it.
5. Create one test developer product (say, 5 Robux) on the test experience, put its ID in `Config.DevProducts`, buy it with a test account, and confirm it's granted exactly once after a rejoin.
6. Watch the frame rate and heat on at least one low-end Android phone during a windstorm.

## Launch blockers, by priority

1. **Real DataStore test** in the private place (step 4 above). Persistence bugs are the most expensive kind to ship.
2. **Two-player test** of loot contention and the protected bag.
3. **Low-end phone test** for frame rate and touch prompts.
4. **First real playtest** with 3–5 people who've never seen the game. Watch whether they voluntarily play a second storm cycle, and whether anyone gets lost finding the Scrapyard.
5. **Economy tuning** from playtest data. Current values: first upgrade after about 2–3 trips; full Backpack upgrades cost 4,100 coins.
6. **Monetization setup**: create real game passes and products, then test receipts (step 5). Only after 1–4 hold up.
7. **Polish backlog** (not blocking): house interiors are empty boxes, loot is plain shapes rather than meshes, and only 3 of the 6 planned upgrades exist.
