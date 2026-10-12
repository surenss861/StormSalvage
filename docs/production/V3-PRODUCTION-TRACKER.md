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
| C5 Motel | Not started | |
| World consistency pass | Not started | |
| D Premium UI | Not started | |
| E Gameplay polish | Not started | |
| F QA and optimisation | In progress (Studio regressions per district) | device gates **Not tested** |
| G Purchase safety | **Studio-tested** (below) | |
| G Release prep | Not started | |

## G: purchase safety (Studio-tested 2026-10-12)

The three review risks are fixed in `MonetizationService` / `DataService`:

1. **Pending grant spendable before it's durable.** The grant and its PurchaseId are now written
   to the stored profile in one `UpdateAsync` (`DataService.grantReceipt`) *before* the live
   session gets the reward. A failed write leaves the live balance untouched, so there's nothing
   to spend and nothing to claw back (the old undo-with-`max(0, …)` path is gone).
2. **Failed receipt retried, then re-delivered.** Every failure returns `NotProcessedYet`; a retry
   finds the PurchaseId in the profile or the lifetime history and finishes the bookkeeping
   without granting again.
3. **Bounded history.** The profile still keeps the last 100 PurchaseIds, but every granted
   PurchaseId is also recorded in a never-pruned purchase-history DataStore
   (`StormSalvage_v1_Purchases`, key `purchase_<PurchaseId>`), checked first.

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

The test account (your own profile) was restored to its pre-test 347 coins and saved.

**Still required before enabling real purchases** (needs you): real product and game-pass IDs in
`Config`, a test purchase in a private published place, and your explicit go-ahead. Not done.

## Blockers needing you

1. Re-import `assets/exports/v3fuel/Compressor.fbx` (minor; skipped twice).

## Device gates (Not tested)

Phone FPS / frame time, draw calls, triangles on screen, memory, thermal, join time, 4/8/12-player
servers. Need physical devices and a published private test place.
