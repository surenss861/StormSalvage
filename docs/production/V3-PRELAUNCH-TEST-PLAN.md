---
related-code:
  - "[[DebugService.luau]]"
domain: qa
type: guide
status: stable
tags: [storm-salvage, qa]
---
# Storm Salvage V3: pre-launch test plan (private live experience)

There is no staging experience. Every "staging" step below runs in the existing **private** Storm Salvage experience with `Config.LiveTestMode = true`, so all data goes to `StormSalvage_v1_LIVETEST` and real saves are never opened. Each section is kept as written.

For the owner and testers running the staging gates. It sets out exactly what to do, what to read and where to write it down. Thresholds come from `V3-PERFORMANCE-BUDGETS.md` (unchanged). A blank result is **NOT TESTED**, never a pass.

**Build under test:** the RC2 tag (see the tracker). Every result row names the RC tag and the staging place version.

## 0. Smoke test after every staging publish (5 min, one tester)

1. Join the private experience from the Roblox app. Open F9 → **Server** and confirm `store StormSalvage_v1_LIVETEST` and `LIVE TEST`.
   - If it shows `StormSalvage_v1` without LIVE TEST, **stop**: that is a release build on real data.
2. Grab one item, sell it, buy one upgrade and leave.
3. Rejoin. Coins and the upgrade must still be there, which proves saving works on `_LIVETEST`.
4. F9 → **Client** shows `[Perf]` lines once a minute; F9 → **Server** shows `[ServerPerf]` lines.

## 1. Multiplayer: 4, 8 and 12 players

**Setup:** one private staging server with N real Roblox accounts on separate devices, at least 2 of them phones. One person is the **recorder**, who keeps F9 → Server open and copies every `[ServerPerf]` line.

**Script (about 15 min per size, same for 4, 8 and 12):**

| Minute | Everyone does | Recorder checks |
| --- | --- | --- |
| 0–2 | Join. One player leaves and rejoins at minute 1 | Join wave in `[ServerPerf]`; no `[DataService] save failed` |
| 2–5 | Calm: scatter through all 5 districts and collect | Coins and bag counts on screen match what people report |
| 5 | **Contention:** everyone runs to the Town Square fountain and grabs the same items at once | No two people hold the same item; nothing spawns twice |
| 5–8 | Storm 1 (whatever arrives): play it naturally; 2 people deliberately die in the open | Dropped bags: others can't take them for 40 s, and the owner can |
| 8–10 | Everyone sells at the same moment (countdown on voice chat) | Every receipt total matches its own bag; no double payouts |
| 10–12 | Storm 2: Storm Cores. Race for them | Each core goes to exactly one person |
| 12–14 | Everyone buys upgrades; 2 people spam the buy button | One level per purchase; coins deducted once |
| 14–15 | **Leave wave:** half the players leave and rejoin within 30 s, the rest leave | Rejoiners keep their exact coins and upgrades; no "Couldn't load" kicks |

**Pass:**
- **Heartbeat:** at least 58/s in at least 99% of 1 s windows (the `[ServerPerf]` p1 value), repeatedly above 55.
- **No authority faults:** no duplicated items, coins or upgrades.
- **Saving:** every player's data survives the leave wave.
- **Errors:** zero `[Monetization]` or `[ClientDiag]` lines.
- **Server CPU:** p95 ≤ 10 ms; capture a MicroProfiler dump at minute 9.

**Evidence row (one per size):**

```
rc_tag, place_version, players, duration_s, devices(model×n), heartbeat_p1, heartbeat_p10, heartbeat_median,
worst_step_ms, server_mem_mb_start, server_mem_mb_end, server_cpu_ms_p95 (MicroProfiler), duplicates_seen(Y/N + detail),
lost_progress(Y/N + who), kicks, errors_in_log, notes, verified_by
```

## 2. Physical-device performance (contract sections A–D, G)

**Devices:** entry Android at graphics 2–3, a mid-range phone at 5–6, and a desktop at 7–8. For each, record the model, RAM, OS, Roblox build, graphics level, charging state and room temperature.

**Procedure (per device, one solo staging server):**
1. **Cold join ×5.** Force-close Roblox, then join. Time from tapping Play until you can walk and see a salvage item glow. Record all 5.
2. **Turn on instrumentation.**
   - Open the performance overlay (Ctrl+F7 on desktop; on phones use the in-app *Performance Stats* setting).
   - Keep F9 → Client available.
3. **Run the section G scenarios in order, 2 min each:**
   - Scrapyard idle + selling
   - Town Square scavenging
   - Wind, Flood and Lightning
   - interiors (supermarket, warehouse, motel)
   - a 20-minute soak covering every storm phase
4. **Every minute,** copy the `[Perf]` line: FPS 1 s p10 and median, frame p95 and p99, worst frame, memory and quality level.
5. **At minutes 5, 15 and 20 of the soak,** take the Developer Console **Memory** tab: total, PlaceMemory, GraphicsMeshParts, GraphicsTexture.
6. **Draw calls and triangles** come from the overlay at the 5 worst views (contract section C). Scripts can't read these.
7. **Low graphics.** At quality 2–3, stand at the Scrapyard edge and look over town. Record whether the far town, the Motel and the Storm Core beacons stay visible (world-consistency finding 1).
8. **Respawn memory.** Die 10 times in the open. Read memory before and after. In Studio, each respawn added about 0.5 MB, and that also happens with **no game code running**, so it's Roblox's own respawn behaviour. On device, confirm whether it settles or keeps growing.

**Evidence:** one row per device and scenario with the contract section I fields. Blank means NOT TESTED.

## 3. Mobile UI on real phones (about 10 min per phone)

- **Thumbstick:** drag from anywhere in the left 40% of the bottom two-thirds of the screen. Nothing in the HUD should block or steal it, including during a storm when the orders strip is up.
- **Buttons:** Jump, Gear Shop and Settings are all reachable with a thumb, and nothing overlaps them.
- **Readability:** coins, the crate count, the storm clock and the orders text are readable at arm's length.
- **Shop and Settings:** open both; buy an upgrade; drag every slider; toggle Reduced Effects. Tap empty panel space: the menu must stay open. Tap outside: it closes.
- **Notched phones:** nothing sits under the notch or rounded corners in either landscape orientation.
- **Evidence:** screenshots in calm, during a storm, with the shop open, and of the sale clipboard, plus a short screen recording of one storm.

## 4. Persistence and receipts on real servers

Purchases stay **disabled** (all product IDs 0). What can be proven without spending Robux:

1. **Server hop:** play on server A, earn coins, then join a *different* staging server through the friends list or a second private server. Within 45 s you're either loaded with exactly the same coins, or kicked with "Couldn't load your save data" if A is still saving. Rejoin, and it must load.
2. **Crash recovery:** the owner uses Creator Hub → **Shut Down All Servers** while players are mid-session. After rejoining, progress up to the shutdown save is there, and nobody is locked out for more than one 42 s retry cycle.
3. **Ownership:** the RC2 rule that a server may write only while the stored lock is its own was proven in Studio, including the stale-owner attack that RC1 failed (`V3-PRODUCTION-AUDIT.md`). Staging confirms that nobody loses progress during steps 1 and 2.
4. **Real receipts (owner approval required):** with no staging experience, a test product would live in the real experience. It stays **unconfigured** in `Config` (ID 0) until you approve a priced test. If approved, use one cheap product, set its ID only in a test RC (still `_LIVETEST`), then:
   - buy it once
   - leave mid-purchase once
   - buy, then immediately hop servers once

   Confirm exactly one grant per purchase in the profile and in `StormSalvage_v1_LIVETEST_Purchases`. This costs real Robux, so it is your call.

## 5. Rollback rehearsal (private live experience, `_LIVETEST` data)

1. Note the staging place version (V1). Publish RC2 (V2).
2. Two testers play and earn coins on V2.
3. Restore V1 in Version History, then **Shut Down All Servers**.
4. Testers rejoin on V1. Coins earned on V2 must still be there (same data format), with no errors.
5. Restore V2 the same way and rejoin again.
6. **Evidence:** timestamps for each step, versions and both testers' coins at each step.

## 6. What must pass before public release (non-waivable gates)

1. Real phone performance (section 2) within the contract, or exceptions accepted with data.
2. 12-player stability (section 1).
3. Cross-server data safety (section 4, steps 1–3) and, if purchases are in scope, receipt safety (step 4).
4. A successful staging rollback rehearsal (section 5).

After those come the unfamiliar-player onboarding and UX playtest (checklist).
