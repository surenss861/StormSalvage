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
| D Premium UI | **Reset in progress**: Instrument and Stencil rejected (Instrument stays as the functional baseline). Three complete directions built and Studio-captured (Salvage Adventure, Storm Chaser, Scrapyard Workshop; Calm, Lightning, shop, receipt, rarity, phone layout): `docs/art/V3-UI-STUDIES.md`. Recommendation: Workshop with fixes. **Waiting for your choice; nothing implemented.** | `docs/art/v3/ui/studies/` |
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

## Production audit

See `docs/production/V3-PRODUCTION-AUDIT.md` (P0 environment isolation implemented, CI and unit tests added).

## Blockers needing you

0. Create the private test experience and send its place ID; confirm `99653875913460` is the live place (`Config.ProductionPlaceIds`). Any unlisted place gets no DataStores (temporary profiles, purchases refused).

1. Re-import `assets/exports/v3fuel/Compressor.fbx` (minor; skipped twice).

## Device gates (Not tested)

Phone FPS / frame time, draw calls, triangles on screen, memory, thermal, join time, 4/8/12-player
servers. Need physical devices and a published private test place.
