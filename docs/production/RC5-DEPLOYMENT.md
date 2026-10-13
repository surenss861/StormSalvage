# RC5 private deployment: owner checklist

**Build:** `rc-20261013-5`, commit `858aa8f`, approved for private testing by the owner on 2026-10-13. Not for a public launch; purchases stay off.

**File to publish:** `.tools/rc/StormSalvage-rc-20261013-5-858aa8f.rbxl` (in the repo folder, git-ignored). This is the CI artifact from run 38390046991.

- SHA-256: `ba03c100113eff234bc1204994179cdeb6e4b6e8f073d622424be4b961246575`
- **Inspected inside the file:**
  - `Config.LiveTestMode = true`
  - `PurchasesEnabled = false`
  - no product IDs
  - `ProductionPlaceIds = { 99653875913460 }`
  - the `_LIVETEST` store present
  - 45 scripts, and no QA scripts

**Only two places in the code open a DataStore:** the profile store and its `_Purchases` audit store, and both use `Config.DataStoreName`. In this build that name resolves to `StormSalvage_v1_LIVETEST` on the live place (unit-tested).

## Baseline taken before publishing (read-only, 2026-10-13 16:2x UTC)

| Store | Key `player_8482925865` (your account) |
| --- | --- |
| `StormSalvage_v1` (real saves) | Latest version `08DF2633FC1D5556.0000000175.08DF28D0DF8E075C.01` written 2026-10-13 02:22:47 UTC. 200 coins, Backpack 4, Boots 4, Armor 3. |
| `StormSalvage_v1_LIVETEST` | Doesn't exist yet |

The last real-save writes (01:53 and 02:22 UTC) are from before Studio isolation landed (04:38 UTC, commit `0805251`). Nothing has written your real save since.

## Rollback target (recorded 2026-10-13, read-only, from Creator Hub)

Place `99653875913460` → Version History, filtered to **published only** (`evidence/rc5-rollback-version-history.jpg`):

- **The currently published version is 2**, saved October 8, 2026 at 11:16 PM local time. **That's the rollback target.**
- Versions 3–119, the latest saved October 13 at 12:50 PM local time, are **saves only, never published**. Live servers still run the October 8 build, which predates the save-store isolation and `LiveTestMode`. Anyone joining the live game today writes to the real store with that old code.

## Publish log (2026-10-13)

1. **14:26 local.** The first attempt used "Publish to Roblox As…", which created a **new private experience**, "ztromsalvage1" (experience `10770701335`, place `122733895388261`). Nothing saves there: RC5 doesn't recognise that place ID, so it finds no matching store and fails closed. It's left private and unused.
2. **14:30 local.** Storm Salvage **version 121 published**, and the experience is still Private. Comparing every script in the Studio window that's connected to the place:
   - **It is not the RC5 artifact.** All 45 game scripts are byte-identical to branch HEAD `ac5ba68`, the RC6 work: Heavy-Duty Pack +2, with `Config` and `MonetizationService` differing from RC5.
   - The window also holds Rojo and LuauLSP settings objects, which the RC5 file doesn't have. So the window that was published was the **Studio testing window**, not the RC5 file.
   - Data safety is the same as RC5: `LiveTestMode = true`, `PurchasesEnabled = false`, and the same `Environment` and `DataService` code, so saves go to `_LIVETEST`.
   - But the build isn't traceable to a tagged candidate. **Plan:** republish the actual RC5 file before any testing counts.

## Steps (you)

1. ~~Record the rollback version.~~ Done above: version **2**.
2. **Close the Studio window I've been testing in** without saving or publishing. It runs the newer working code, which is not RC5.
3. **Open the RC5 file.** In Studio, File → Open from File… → the `.rbxl` above.
4. **Publish.** File → **Publish to Roblox As…**, choosing **Storm Salvage**, the existing start place `99653875913460`. Check the destination before confirming.
5. **Keep it private.** Creator Hub → experience settings: confirm it's still **Private**.
6. **Check the environment.** Join from the Roblox app, press **F9 → Server log**, and look for:
   `[Environment] Production (listed production place, LIVE TEST namespace (real saves untouched)), place 99653875913460, store StormSalvage_v1_LIVETEST`.
   If it says `store StormSalvage_v1` without LIVE TEST, **stop: leave the game without collecting or buying anything** and tell me.
7. **Smoke test (about 5 min).**
   1. Collect, sell, buy one upgrade.
   2. Open JOBS (after the first sale) and finish or advance a job.
   3. Leave, rejoin: the same coins, upgrade and job progress should be there.

## Steps (me, right after your smoke test)

- **Confirm the real save is untouched:** `StormSalvage_v1` / `player_8482925865` still has latest version `…0175` from 02:22:47 UTC (read-only check).
- **Confirm test progress landed in the test store:** `StormSalvage_v1_LIVETEST` now has your key, with the progress you made.
- Then multiplayer and device testing per `V3-PRELAUNCH-TEST-PLAN.md`, plus the open RC5 items in the tracker.

## Rollback

Version History → **Restore** version **2**. Restoring only saves it, so then open it in Studio and publish it. Finally **Shut Down All Servers**. Test data stays in `_LIVETEST`, and your real save is never involved.
