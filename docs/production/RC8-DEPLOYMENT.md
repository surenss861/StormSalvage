---
related-code:
  - "[[EventService.luau]]"
  - "[[PursuitService.luau]]"
  - "[[Movement.luau]]"
domain: data
type: guide
status: wip
tags: [storm-salvage, data, v4]
---

# RC8 private deployment

**Build:** `rc-20261014-8` at commit `2996d74`, approved by the owner on 2026-10-14 for the **existing private experience only**.
- No public release. No Robux.
- No changes to the published RC8 during tests.

**File:** `StormSalvage-rc-20261014-8-2996d74.rbxl`, CI release-candidate run.
- **Full SHA-256** `932b24e54dc2fc9deca6d5a3eb49d2f2890505c611fe207bca4d09b788bd6d2e`
  - the CI file and the owner's Desktop copy match exactly
- **Inspected inside the file:**
  - `LiveTestMode = true` (saves go to `StormSalvage_v1_LIVETEST`)
  - `PurchasesEnabled = false`, 0 product IDs
  - `ProductionPlaceIds = { 99653875913460 }`
  - 56 scripts; **no QA scripts** (no runner or autopilot) and no QA attributes
  - the asset pivot table matches the assets

## Rollback target (recorded before publishing)

The published versions are 133, 124, 122, 121 and 2 (`evidence/rc8-rollback-version-history.jpg`).

**RC7 is version 133**, published October 13, 2026 at 5:35 PM local. That's the rollback: open 133 in Studio, publish it to place `99653875913460`, then Shut Down All Servers.

## RC7 Salvage Detector test (finished before RC8 replaces RC7)

- **Owner-approved top-up:** 2,500 coins, added only to the disposable `StormSalvage_v1_LIVETEST` test profile.
  - It used Studio's direct DataStore access from the Edit DataModel, not a game remote.
  - It refuses if a live server holds the profile.
  - Result: 813 → **3,313**, read back.
- **The real save** (`StormSalvage_v1`) was untouched: still at `…0175` from 2026-10-13 02:22:47 UTC.
- **Owner steps:**
  1. Join the live RC7.
  2. Gear Shop → TOOLS → buy the Salvage Detector.
  3. Check the dial appears in town.
  4. Leave and rejoin.
  5. Confirm it's still owned.
- **Me afterwards:** read the save; `Tools.Owned.Detector` should be true and coins 813.

## RC8 steps

1. ✅ Rollback version recorded (133).
2. ✅ Artifact verified (full checksum, contents).
3. **Owner:** close every Studio window without saving. Open `StormSalvage-rc-20261014-8-2996d74.rbxl` **from the Desktop**.
4. **Before publishing:** I check that window's scripts against the RC8 artifact (56 scripts, hash by hash) and that there's no QA content.
5. **Owner:** File → Publish to Roblox As… → **Storm Salvage** (existing) → place **Storm Salvage** (`99653875913460`) → Overwrite.
6. **Me:** Version History shows a new published version, and the experience is still Private.
7. **Owner:** join. **Me:** read the save to confirm the `_LIVETEST` writes and the new `Records` field. Then the two-player playtest (`V4-GAMEPLAY.md`, RC8 playtest checklist).
