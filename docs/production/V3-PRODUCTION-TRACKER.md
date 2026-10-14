---
related-code:
  - "[[Main.server.luau]]"
domain: core
type: readme
status: stable
tags: [storm-salvage, core]
---
# Storm Salvage V3: production tracker (C4 to G)

Single source of truth for the completion push. Branch `v3-art-direction`; `main` stays at
`0ef9465` until you approve a merge. Status words: **Done** (implemented and verified as
described), **Studio-tested**, **Blocked** (needs something only you can do), **Not tested**
(no evidence yet; never counted as a pass).

## Phase status

| Phase | Status | Evidence |
| --- | --- | --- |
| C1 Houses | Done | `docs/art/V3-C1-HOUSES.md` (fence 308 tris verified in game) |
| C2 Supermarket | Done | `docs/art/V3-C2-SUPERMARKET.md` |
| C3 Fuel & Go | Done (canopy fix in) | `docs/art/V3-C3-FUEL.md`; compressor hose fixed in Blender, **re-import still pending** |
| C4 Warehouse | Done (Studio-tested) | `docs/art/V3-C4-WAREHOUSE.md` |
| C5 Motel | Done (Studio-tested) | `docs/art/V3-C5-MOTEL.md` |
| World consistency pass | Done (findings + crosswalk fix) | `docs/art/V3-WORLD-CONSISTENCY.md`; finding 1 is a device gate |
| D Premium UI | **Studio-tested, Workshop implemented** (approved 2026-10-13 with Chaser weather hierarchy and Adventure accessibility): cash tag, crate, tin storm sign with non-scrolling survival orders, sticky-note objective, rarity tags/stamps, clipboard sale tally, pegboard Gear Shop on real `BuyUpgrade`, separate phone composition, Reduced Effects verified. QA table in `docs/art/V3-UI-WORKSHOP.md`. Settings restyled. Black screen not reproduced in 15 scenarios; `ViewHealth` diagnostic added. Modal click-through bug fixed. Client soak: 51 cycles, flat instance counts (`docs/production/V3-SOAK-AND-DEATH-QA.md`). **Open:** physical-device check | `docs/art/v3/ui/workshop/` |
| E Gameplay polish | **In progress**: camera kept inside buildings (`src/client/CameraOcclusion.luau`), freezer gap verified. **To do**: pickup/sell/upgrade feel, audio levels, death and bag recovery review | |
| F QA and optimisation | In progress: per-district Studio regressions; full-town bot loop after C5 (2 full sales, storm survived, 0 errors). Device gates **Not tested** | |
| G Purchase safety | **Studio-tested** (below) | |
| G Release prep | **Partial**: AnalyticsService FirstSession funnel + custom events (verified firing in a 4-min bot run); release checklist `docs/production/V3-RELEASE-CHECKLIST.md` | |

## G: purchase safety (Studio-tested 2026-10-12)

The three review risks are fixed in `MonetizationService` / `DataService`:

1. **Pending grant spendable before it's durable.** The grant and its PurchaseId are now written
   to the stored profile in one `UpdateAsync` (`DataService.grantReceipt`) *before* the live
   session gets the reward. A failed write leaves the live balance untouched, so there's nothing
   to spend and nothing to claw back (the old undo-with-`max(0, …)` path is gone).
2. **Failed receipt retried, then re-delivered.** Every failure returns `NotProcessedYet`; a retry
   finds the PurchaseId in the profile or the lifetime history and finishes the bookkeeping
   without granting again.
3. **Bounded history.** Removed on 2026-10-13: the profile's PurchaseId list is never pruned, so
   correctness no longer depends on the purchase-history store (now an audit log and fast skip).
   Re-tested A–H in the `_STUDIO` store; see `V3-PRODUCTION-AUDIT.md`.

Also: a receipt already being processed in this server is never processed concurrently.

Test run against the real receipt path in Studio (simulated receipts, Studio-only fault injection
via `debug:Invoke("faults", op, n)`, unique PurchaseIds, DataStore read back after each step):

| Scenario | Result |
| --- | --- |
| A First delivery | PASS: Granted, +1000 live and stored, history recorded |
| B Same receipt again | PASS: Granted, no change |
| C Grant write fails, then retry | PASS: NotProcessedYet with live balance unchanged; retry grants once |
| D History write fails after a durable grant, then retry | PASS: retry Granted, no second grant |
| E Final save fails, then retry | PASS: retry Granted, no second grant, stored = live |
| F History read fails, then retry | PASS: nothing granted; retry grants once |
| G Two concurrent deliveries of one receipt | PASS: one Granted, one NotProcessedYet, one grant |
| H Receipt pruned from the profile, re-delivered | PASS: lifetime history blocks the regrant |

That 2026-10-12 run used your real profile (restored to 347 coins afterwards). It's superseded by
the 2026-10-13 re-run, which used the disposable `_STUDIO` profile only; your live profile was
snapshotted read-only before and after and is unchanged.

**Still required before enabling real purchases** (needs you): real product and game-pass IDs in
`Config`, a test purchase in a private published place, and your explicit go-ahead. Not done.

## Production hardening (2026-10-13, Studio-tested in `StormSalvage_v1_STUDIO`)

- Live profile untouched: a read-only snapshot before and after all tests was identical.
- Receipt suite A–H passes after removing receipt pruning (see the audit).
- BuyUpgrade with malformed input, spam and a funded burst: correct.
- Two-client pickup race and five same-frame sales: one award each.
- Branch protection on `main`:
  - CI check `checks` required, and the branch must be up to date
  - no force pushes or deletion
  - admins can still bypass

## Production validation, 2026-10-13 (Studio)

- **Environment:** a pure resolver with 8 unit tests in CI; Studio is always `_STUDIO` and unknown or conflicting places fail closed. The server logs `[Environment] …` at start.
- **Persistence:**
  - a 20,000-receipt profile is 449 KB (10.7% of the limit) and the oldest ID is still deduped
  - a stale lock is taken over; a live lock gives a kick after 41.6 s with data untouched
  - the release on shutdown lands within 5 s
- **Release operations:** a `rc-*` release-candidate build workflow (artifact only, never publishes); **RC 1** = tag `rc-20261013-1` at `1753ec0`, built successfully (run 38358010863, artifact `release-candidate-1753ec0…`). Not published anywhere. and `V3-RELEASE-RUNBOOK.md` (staging setup, publish, rollback, monitoring).
- **Profiling:** `PerfProbe` prints a `[Perf]` line once a minute in staging and Studio only, using the performance contract's fields.
- **4-player smoke test:** items conserved under contention; owner-only bag window enforced (`V3-SOAK-AND-DEATH-QA.md` §4).
- **Low graphics proxy:** beacons and labels survive the lowest Studio level; device check still needed (§5).

## Progression (2026-10-13)

Salvage Contracts (3 jobs, board + JOBS button, pinned job on the HUD), Salvager Reputation (7 ranks, titles only) and nameplate finishes (a 30,000-coin cosmetic sink), all server-authoritative. Studio-tested, including duplicate sales, dropped-bag farming, hostile input, rejoin and rollback to RC3. Job rewards were rebalanced from bot runs to about 27% of income. Details: `V3-PROGRESSION.md`.

## Monetization (2026-10-13)

The Supply Counter is built as a Gear Shop tab, with three coin packs and the Heavy-Duty Pack pass. It is **off**: `PurchasesEnabled = false` and all IDs are 0. Studio-tested: exact coins, duplicate and concurrent deliveries, no pass stacking, server-confirmed delivered state. Economy check and setup steps: `V3-MONETIZATION.md`. **Needs you:** a decision on pack sizes, the four Creator Hub IDs, and later approval for one real test purchase.

## Release candidates

| RC | Tag | Commit | Contents | Status |
| --- | --- | --- | --- | --- |
| RC1 | `rc-20261013-1` | `1753ec0` | Workshop UI, data environments, persistence QA, runbook | Superseded: the RC1 review found the lost-lock overwrite defect |
| RC2 | `rc-20261013-2` | `d35302d` | RC1 + strict save-lock ownership + `[ServerPerf]` | Superseded: the RC3 review found per-server tokens and the history shortcut |
| RC3 | `rc-20261013-3` | `1ce6f6f` | RC2 + per-session lock tokens + history never read (write-only audit after save) + live-test data namespace and release gate | Studio regression passes (audit, RC3 sections). Superseded by RC4 for testing; still the purchase-safety baseline. |
| RC4 | `rc-20261013-4` | `b5a8749` | RC3 + Supply Counter (packs 300/1,200/3,000, Heavy-Duty Pack; purchases **off**) + Contracts, Reputation and nameplate finishes | Studio: progression suite, receipt A–I, rollback-to-RC3 compatibility. Approved by you for private testing. Superseded by RC5 (your requested discovery change). |
| RC5 | `rc-20261013-5` | see tag | RC4 + staged discovery (JOBS after first sale, Supply after first upgrade) + finish materials (PlateStyle) + Studio-only QA seed | **Approved for private testing** (owner, 2026-10-13). Deployment steps and data baseline: `RC5-DEPLOYMENT.md`. Published privately as place version 122. **Blocking defect found live:** every building and prop sat half underground (asset pivots lost, see RC6). Superseded by RC6. |
| RC6 | `rc-20261013-6` | see tag | RC5 + **asset pivot fix** (AssetPivotFix + generated AssetPivots, CI-checked) + Heavy-Duty Pack +2 (owner decision) | Fix verified in Studio on the exact broken state that RC5 had live: 146 pivots restored, 402 of 403 placed models on their base (the 1 left is a deliberately tipped-over cart). Town and yard captures in `evidence/pivots-*`. **Published privately as place version 124** (scripts identical to the artifact). Owner confirms the buildings are fine. **Smoke test passed live** (collect, sell, bag upgrade, job completion, rejoin; save matches: 25 coins, Backpack 1). Real save untouched. |
| RC7 | `rc-20261013-7` | `e3d1ab9` | RC6 + **Supply Depot phase one**: Gear Shop Tools tab and the Salvage Detector (2,500 coins). Code Graph headers; the +4 references in the monetization doc corrected to +2 | **Approved for private gameplay testing** (owner). All 7 pre-tag checks passed, including 2-client multiplayer. Artifact SHA-256 `61c51a90…e097`. **Not deployed**: the live place stays on RC6 until a separate deployment approval. Details: `V3-SUPPLY-DEPOT.md`. |
| V4 (experiment) | branch `v4-gameplay` | not tagged | RC7 + **movement** (run 20 / sprint 28, Boots → 24/34) + **Storm Pursuit** (rare cache, rogue twister chase, extraction bonus, records) + HUD and audio feedback. Designs only: `V4-ECONOMY.md`, `V4-STATUS.md` | Studio-tested with scripted runs (`V4-GAMEPLAY.md`). Real multi-client play is untested. **For gameplay review, not release.** |

## Production audit

See `docs/production/V3-PRODUCTION-AUDIT.md` (P0 environment isolation implemented, CI and unit tests added).

## Blockers needing you

0. Live place confirmed (`99653875913460`, experience `10769947641`). No staging experience: testing uses the private live experience with `LiveTestMode` on. **Needs you:** approval to publish RC3 there.

1. Re-import `assets/exports/v3fuel/Compressor.fbx` (minor; skipped twice).

## Device gates (Not tested)

Phone FPS / frame time, draw calls, triangles on screen, memory, thermal, join time, 4/8/12-player
servers. Need physical devices and a published private test place.
