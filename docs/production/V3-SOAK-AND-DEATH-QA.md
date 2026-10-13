# V3: client memory soak and death/black-screen investigation (Studio, 2026-10-13)

Everything here was executed in Studio Play against the disposable `StormSalvage_v1_STUDIO` profile. Studio numbers are **not device evidence**. See "What this does not prove" at the end.

## 1. Black screen after death (P0)

### What was seen

The black screen happened once, during the first Workshop QA run.
- **What happened:** my test script teleported the character to just behind the Scrap Buyer counter at (-32, 33, -269) during a Lightning storm. The 3D view then went black while the HUD kept updating, and stopping Play cleared it.
- **What the probe recorded at the time:**
  - camera type `Custom`, subject the character's Humanoid, 13 studs from the character
  - no full-screen GUI
  - normal Lighting exposure and brightness
- **One more detail:** only those frames included Roblox's own top bar and player list. The game never hides them, yet no other capture shows them.

### Reproduction attempts

A per-frame probe and a post-respawn view check ran for every scenario. The view check reports `VIEW OK` when all of these hold:
- camera type is `Custom`
- camera subject is the new Humanoid
- the camera is 0.4–40 studs from the character
- fewer than half of 35 view rays hit geometry within 1 stud of the lens
- no visible opaque full-screen GUI

| # | Scenario | Result |
| --- | --- | --- |
| 0 | The original sequence: Lightning storm, client teleport to the same spot behind the counter, sell | Sale completed, view normal, no death |
| 1 | Normal death (Health = 0) | VIEW OK, respawn 7.2 s |
| 2 | **Real** lightning death in town (stood in the open; struck after 11.6 s) | VIEW OK, screenshot normal |
| 3 | Death with the Gear Shop open | VIEW OK (the shop stays open across respawn; harmless, server-driven) |
| 4 | Death while selling | The sell prompt's hold time is 0, so the sale completes before the death (+105 coins, no duplicate). There's no mid-sale window. |
| 5 | Character replaced (`LoadCharacter`) during an active Wind storm (wind force attached) | VIEW OK; exactly 1 wind force in the world afterwards (no orphan) |
| 6 | Five rapid deaths in a row (killed as soon as each character spawned) | VIEW OK; respawn times 5.3–5.5 s |
| 7 | **Real** flood drowning in town (33 s) | VIEW OK |
| 8 | Camera in tight interiors: supermarket aisle and freezer side, motel room, warehouse, gas-station shop, house 1, behind and inside the Scrap Buyer counter | VIEW OK at all 8, including a screenshot from inside the counter |

### Conclusion

**Not reproduced.** In 15 death, lifecycle and camera scenarios the game view was never lost. The original evidence (normal camera, no overlay, normal lighting, plus a capture that unusually included Roblox's own interface) fits a Studio capture fault better than a game fault, but that is still an inference, not a proof.

### Instead of a blind camera reset: `ViewHealth`

`src/client/ViewHealth.luau` checks once a second, from 3 s after spawn, that the camera is `Custom`, follows the current Humanoid and is within 80 studs of it. If that fails 3 checks in a row it reports **once per character** through a new `ClientDiag` remote. The server logs `[ClientDiag] <player> view lost: <kind> (<distance>)` and sends the analytics event `ViewLost_<kind>`.

It never moves the camera, so it can't hide a cause. It is verified in Studio:
- Three deaths and idle time gave 0 false reports.
- Pointing the camera at another object for 5 s gave one report: `Subject (255)`.
- 50 spammed reports were rate-limited to nothing.
- Malformed payloads (a table, a 5,000-character string, nil) were ignored.
- An infinite distance was clamped.

Server-side, kinds are whitelisted, values are clamped, the limit is one report per kind per player per minute, and the data is never used for gameplay.

If the black screen happens on a real device, these logs show whether the camera lost its subject, changed type or drifted, or whether the camera was fine and the problem is rendering.

## 2. Client memory soak

The driver is `tools/qa/client-soak.luau` (QA only). One cycle runs, in order:
1. Spawn 3 loot items, including Epic every second cycle and a Storm Core every third.
2. Collect each through its real prompt.
3. Sell at the real Scrap Buyer.
4. Send a BuyUpgrade request.
5. Open and close the Gear Shop 3 times and Settings 2 times.
6. Die and respawn.
7. Advance the storm one phase.

The run was 3 warm-up cycles plus 48 measured. In total that was 51 deaths, about 150 pickups (including 17 Storm Cores), 51 sales, 306 shop toggles, 204 settings toggles and every storm type in every phase.

| Cycles | Client total MB* | Lua heap MB* | GUI MB | Instance MB | PlayerGui instances | Workspace instances | Leftover effects | Server instances | Loot |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0 (baseline) | 4651 | 791.8 | 34.1 | 104.5 | 968 | 5109 | 0 | 5047 | 60 |
| 3 (warm) | 4705 | 786.4 | 35.2 | 131.9 | 1024 | 5121 | 0 | 5047 | 60 |
| 9 | 4735 | 796.4 | 37.9 | 133.8 | 1024 | 5131 | 0 | 5047 | 60 |
| 15 | 4777 | 807.4 | 40.6 | 135.6 | 1024 | 5131 | 0 | 5047 | 60 |
| 21 | 4796 | 805.6 | 38.9 | 135.9 | 1024 | 5114 | 0 | 5047 | 60 |
| 27 | 4816 | 798.4 | 41.6 | 138.0 | 1024 | 5131 | 0 | 5047 | 60 |
| 39 | 4856 | 793.5 | 40.5 | 139.3 | 1024 | 5131 | 0 | 5047 | 60 |
| 51 | 4855 | 796.5 | 40.2 | 141.3 | 1024 | 5111 | 0 | 5049 | 60 |

\* In Studio the client, the server and Studio itself share one process, so "total" and "Lua heap" include Studio and plugins. Use them only as trends.

**Findings:**
- **Object counts:** PlayerGui, workspace, server instances, loot and leftover effects are all flat after warm-up. Nothing accumulates: no cards, billboards, beacons, particles, wind forces or modal pieces.
- **Lua heap:** flat at about 795 MB, so no growing tables or closures.
- **Total memory:** plateaued between cycles 39 and 51 (4,856 → 4,855 MB).
- **Watch item:** "Instance" memory rose about 0.17 MB per cycle (131.9 → 141.3 MB over 48 cycles) with no growth in instance count. That pattern fits engine-side caching of avatar and character assets reloaded on every respawn rather than a game leak, but Studio can't tell those apart. **Measure on a phone over a long session.**
- **Errors:** 0 errors and 0 warnings in the log for the whole run.
- **Connections:** event connections aren't directly observable in Roblox. Flat instance counts across 51 respawns and about 500 modal toggles, plus flat Lua heap, is the indirect evidence that per-character and per-open connections are being released.

## 3. Defects found and fixed in this pass

- **Menus closed on a missed click (real bug, every modal).** A click on empty space in the Shop or Settings panel passed through to the dimmed backdrop and closed the menu. Missing a slider by a few pixels closed Settings. The cause: GuiButtons get clicks through non-button frames above them. **Fix:** the backdrop ignores any click that lands on the panel (`UI.modal`). Verified with a click on empty panel space (menu stays open), a slider click (sets exactly 75%) and a click on the dimmed area (menu closes).
- **Notices sat on the shop's close button** when a storm started with the shop open. **Fix:** while a menu is open, notices stack downwards from the top right.

## 4. Four-player Studio smoke test (local server plus 4 clients on one Mac)

This is a smoke test for sync and authority bugs, **not** the section E server measurement. Five Studio processes on one machine skew every timing.

| Check | Result |
| --- | --- |
| 8 items in the plaza, all 4 clients rushing every item at the same instant through the real prompts (two rounds) | **Conserved:** carried + left in the world = 8 in both rounds; every item had exactly one owner and nothing was duplicated |
| Dropped bag, owner-only window (40 s) | Another player trying to take the dead player's 2 items: **both refused** |
| Owner recovers their own bag | Works (confirmed in single-player). In the multi-client run the owner's prompt wasn't shown, because Roblox shows one prompt per key and an unrelated Scrap Can 1.6 studs away claimed it. A player just presses again. |
| Server heartbeat with 5 Studio instances on one machine | 1 s windows: median 47.9/s, p10 40.0/s, min 22.5/s, worst frame 281 ms over 420 s. **This measures the overloaded Mac, not the game.** Real 4/8/12-player numbers need staging. |

## 5. Low graphics (Studio proxy for the device draw-distance item)

The Scrapyard edge was compared at Studio's lowest (`Level01`) and highest (`Level21`) quality, in the same storm phase and view (`evidence/gfx-*.jpg`).

- **What stays visible at the lowest level:**
  - all 3 Storm Core beacons (203–298 studs away), their labels
  - the storm sign and the near town
- **What the lowest level drops:** shadows, atmosphere and some far detail; in the Lightning view the far half of Main Street's lights.
- **What Studio can't show:** real phones also cut draw distance and texture quality based on device memory. The world-consistency finding 1 check ("does the far town pop out at quality 2–3?") **still needs a real low-end phone**.

## What this does not prove

The following are still open:
- phone FPS, memory, thermals or join time
- 4/8/12-player behaviour
- whether the black screen can happen on a real device

The phone composition has only been checked in the Studio preview.
