# Storm Salvage V3: release checklist (G)

Everything here needs you or real hardware/players; none of it is done by Studio testing.
Tick only with evidence.

Procedures: `V3-RELEASE-RUNBOOK.md` (staging setup, RC builds, publishing, rollback, monitoring).

## Done in Studio (evidence in the linked docs; not a substitute for the items below)

- [x] Environment mapping: unit-tested (Studio is always `_STUDIO`, listed staging is `_STAGING`, unlisted or conflicting places fail closed)
- [x] Receipt suite A–H, 20,000-receipt profile, stale lock and live lock (`V3-PRODUCTION-AUDIT.md`)
- [x] Death, respawn and camera scenarios, plus a 51-cycle client soak (`V3-SOAK-AND-DEATH-QA.md`)
- [x] Workshop UI runtime QA (`../art/V3-UI-WORKSHOP.md`)

## Before a private playtest

- [x] Live place confirmed by the owner (`99653875913460`, experience `10769947641`); no staging experience.
- [ ] **(owner approval)** Publish the RC to the private live experience; F9 shows `LIVE TEST … StormSalvage_v1_LIVETEST`.
- [ ] Device runs per `V3-PERFORMANCE-BUDGETS.md` sections B-D on an entry-level Android
      (quality 2-3), a midrange phone and a desktop: FPS p10/median, frame time p95/p99, draw
      calls, triangles, client/place/mesh/texture memory, thermal, five cold joins.
- [ ] Check at quality 2-3 that the far town and backdrop don't pop out from the Scrapyard
      (world consistency finding 1).
- [ ] 4 / 8 / 12-player server run: heartbeat, server CPU p95/p99 (MicroProfiler), memory,
      join/leave waves.
- [ ] Mobile UI on real phones: touch targets, safe areas, joystick overlap, shop scrolling.

## Before enabling purchases

- [ ] Create the products and passes on the Creator Hub; put the real IDs in
      `src/shared/Config.luau` (`GamePasses`, `DevProducts`). They are 0 (disabled) today.
- [ ] One real test purchase of each developer product in the private place; confirm the grant,
      the profile record and the `StormSalvage_v1_Purchases` record.
- [ ] Your explicit go-ahead.

## Before public release

- [ ] Unfamiliar-player playtest observed and written up (first pickup, sale, upgrade, storm,
      death, replay intent).
- [ ] Analytics dashboard shows the FirstSession funnel and custom events from the test place.
- [ ] Icon, thumbnails and description from real gameplay screenshots.
- [ ] Rollback rehearsed once on staging: publish an RC, restore the previous version, shut down servers, rejoin, and confirm the profile is intact.
- [ ] Note the live place's version number before publishing (runbook 4.1). V3 merges to `main` only after approval.
- [ ] Release build has `Config.LiveTestMode = false` (enforced by the `release-*` tag gate); F9 shows `store StormSalvage_v1`.
