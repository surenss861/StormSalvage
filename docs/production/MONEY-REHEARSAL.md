---
related-code:
  - "[[Wallet.luau]]"
  - "[[RestorePlan.luau]]"
  - "[[ProfileRestore.luau]]"
  - "[[DataService.luau]]"
domain: data
type: guide
status: wip
tags: [storm-salvage, data, v4]
---

# Exact-money migration rehearsal (RC11 review, 2026-10-14)

**Stage A** (non-destructive preparation) is **done and passed**. Its findings changed the build, so the Stage B candidate is **RC12** (§5), not RC11.

**Stage B** (the private published rehearsal) has **not started**. It needs the owner's separate deployment confirmation.

**Unchanged throughout:**
- The published RC8 (place version 142, the rollback reference).
- `main` (`0ef9465`).
- The production DataStore: read-only check, still at version `…0175` from 2026-10-13 02:22:47 UTC.
- Robux products: all off.

## 1. Stage A results

**Snapshot of the LIVETEST profile** (read-only; stored outside git at `.tools/snapshots/livetest-player_8482925865-20261014.json`, SHA-256 `92a15f09…677b`):
- Store `StormSalvage_v1_LIVETEST`, key `player_8482925865`.
- **Version `08DF295925AFC591.0000000025.08DF29AF3FCD58F2.01`**, updated 2026-10-14 04:54:37 UTC.
- 3,313 coins, 1,188 lifetime, schema 1, no lock, no receipts.
- Plus the 5 most recent version ids.
- Re-read at the end of Stage A: the same version (untouched).

**The RC11 artifact:** `b1cad21220d701cf84dc335c4e8946b9d82f788f7cf3c2aa455582debd2ca24d`, re-verified from disk.

**Lock, shutdown and receipt tests** ran in Studio against the real DataService. Each "server" was a separately loaded copy of the real module, with its own session id and lock tokens, pointed at a disposable store, `StormSalvage_v1_STUDIO_REHEARSAL`. The harness refuses any other store name, and the production and LIVETEST names were refused when tried.

**Session locks and migration:**

| Test | Result |
| --- | --- |
| Schema-1 profile (3,313 / 1,188) loaded by server A | **PASS:** exact strings; pre-migration backup written once, schema 1 untouched |
| A earns 5 Qi, autosaves | **PASS:** stored 5,000,000,000,000,003,313; mirror 1 Qa |
| Server B loads while A's lock is live | **PASS:** refused |

**Forced shutdown:**

| Test | Result |
| --- | --- |
| A crashes with 777 unsaved; the lock ages past expiry (6 min) | **PASS:** B takes over with A's last autosave; the 777 is the crash loss (since the last autosave) |
| The dead A's late save | **PASS:** refused (`lostLock`); the store unchanged |

**Purchase receipts:**

| Test | Result |
| --- | --- |
| 5 concurrent deliveries of one PurchaseId on B | **PASS:** granted once, recorded once, +1,000 once |
| The dead A tries to grant | **PASS:** refused |
| Injected grant-write failure, then the retry, then a duplicate | **PASS:** nothing, then once, then "already" |

**Release and restores:**

| Test | Result |
| --- | --- |
| B leaves (release) | **PASS:** lock cleared; receipts kept; C loads at once |
| Restore while the profile holds a live lock | **PASS:** refused |
| **Restore from the pre-migration copy** (+2 purchases since) | **PASS:** 3,313 + 2 × 1,000 = **5,313**, lifetime 1,188, receipts once each, lock cleared, labelled |
| The restored profile on a new server: load, play, save; the purchase re-delivered | **PASS:** loads; duplicate refused; saves exactly |
| Restore again from the same copy | **PASS:** each receipt still once |
| **Restore from a real older DataStore version** (`_STUDIO` test key; its current state preserved first and put back after) | **PASS:** 05:59 schema-1 version (6,375) + 2 purchases since = **8,375**, migrated |
| The real game loads that restored profile; Roblox re-delivers a purchase; earn and save | **PASS:** cash 8,375, duplicate ignored, then 8,400 |
| The restore tool against the production store | **PASS:** refused |

**Rollback reconciliation:**
- **Unit-emulated** (`tests/rollback.spec.luau`, from each build's source):
  - RC8: `Coins += / -=`, no cap
  - RC9: the same
  - RC10: capped `Money.grant`, clamping reconcile
- **Fuzz:** 600 random chains of new-build and older-build sessions, about 2,850 older-build earnings, 583 of them crossing RC10's cap and 1,065 made at the cap.
- **Checked after every new-build load:**
  - cash equals an independent exact reference (start + spends + each build's own credited earnings)
  - lifetime equals its reference
  - the mirror is min(cash, 1 Qa)
  - `Wallet.Mirror` matches what was written

  **All pass.** Fixed cases: RC10 across its cap, RC9 above the mirror, RC8 can't overspend, 50 round trips with no drift, two older sessions in a row.
- **Real builds in Studio** (`_STUDIO` test profile):
  - **RC8** (`2996d74`): loaded a schema-2 profile, earned 700, spent 100 (Armor 1). Roll-forward applied **+600 cash, +700 lifetime**; Wallet, licence and titles kept.
  - **RC9** (`8ccc3ff`): loaded and re-saved M3 fields without loss.
  - **RC10** (`53fe778`): loaded a 5 Qi profile, spent 150,000. Roll-forward gave exactly 4,999,999,999,999,852,000.

## 2. What Stage A changed (why RC12)

1. **DataStore versions are about hourly.** A dozen writes in minutes produced **one** version: Roblox keeps roughly one version per key per hour, and the LIVETEST key's versions are hours apart. So "the version just before migration" may not exist.
   - **Fix:** on the first load that migrates a schema-1 profile, DataService writes the **untouched pre-migration profile** to `<store>_Backups` as `premigration_player_<id>`, once (never overwritten). A failed backup write is logged and doesn't block play.
2. **Restoring is now a tested procedure, not just keeping a version:**
   - **`RestorePlan.luau`** (pure, 5 unit tests) works out the restore.
   - **`ProfileRestore.luau`** (operator tool: Studio command bar or a QA run) performs it.
   - **What a restore does:** puts back the chosen state, and re-applies every purchase confirmed since then, exactly once, from the purchase audit log (PurchaseIds never removed). It refuses while a live lock exists, clears the lock, labels the profile, refuses unknown products, and refuses the production store. It's one atomic UpdateAsync, with the plan re-made inside the transform.
3. **Every server logs its place version at start:**
   - `[Environment] … place 99653875913460 version N, store …`
   - The rehearsal checks it instead of assuming that publishing ended old servers.
4. **A Studio-only test hook:** `DataService.useStoreForTest` (rehearsal stores only).
5. **Test fix:** the fuzz generators used an LCG's low bits, whose period is tiny. They now use the high bits; coverage went from about 24 to about 2,850 older-build operations.

## 3. Which rollback operations are data-safe

| Operation | Money | Everything else |
| --- | --- | --- |
| New build → RC8 or RC9 → new build | **Exact.** Every earning and spend in RC8/RC9 is applied on return, even above 1 Qa. | Kept: they save whole tables, so Wallet, licences, titles, Press, records and the Log survive |
| New build → RC10 → new build | Spends exact. **Earnings are exact only up to RC10's 1 Qa cap:** coins earned in RC10 while its view (min(cash, 1 Qa)) is at the cap are **lost**, and so are lifetime earnings while lifetime is at or above 1 Qa | Kept |
| In an older build, a player with more than 1 Qa | Sees 1 Qa and can spend up to it; can't buy anything costing more (refused, not lost) | — |
| Any number of round trips without money changes | Exact: no drift (tested 50×, fuzzed 600 chains) | Kept |
| Two older-build sessions before the new build returns | One combined, exact delta | Kept |
| A server crash | Progress since the last autosave (≤120 s) is lost, as before. No duplication: the dead server can't write after a takeover | — |
| **Restore** (from `premigration` or a DataStore version) | The state at that point; **confirmed purchases since are re-applied once**; nothing doubled | **Gameplay progress after that point is lost: that's what a restore is.** Use only for corruption or a failed migration |
| Restoring over a profile in use | Refused | — |
| A Robux receipt delivered to an older build | (Purchases are off.) Older builds add to the numeric mirror and record the PurchaseId; the new build applies the delta | — |

## 4. Stage B procedure (needs the owner's explicit confirmation first)

**Where:** the private place `99653875913460`, LIVETEST store only. RC8 = place version 142, the reference. Candidate: **RC12** (§5).

**Abort criteria (stop and roll back to RC8 v142):**
- any server log or in-game balance that differs from the expected exact value
- a missing pre-migration backup
- any DataStore error during migration
- a `[DataService] corrupt legacy money` warning

**B0, before publishing (me, read-only):**
1. Re-snapshot the LIVETEST profile and its version id.
2. Re-verify the RC12 artifact checksum.
3. Confirm RC8 v142 is in the version history.

**B1, publish RC12 (owner, Studio):**
1. Open the exact RC12 file and publish it to the private place.
2. **Then Creator Hub → the experience → Servers → Shut down all servers** (or "Migrate to latest update").
3. **Verify:** join, open F9 → Server, and find `[Environment] Production (live test) … version <the new version>`.
   - Old servers keep their version until shut down; never assume.

**B2, migration (owner joins, me reading the store):**
1. On join, the balance shows **3,313**.
2. Leave.
3. **I read LIVETEST:**
   - `Wallet.Cash = "3313"`, `Lifetime = "1188"`, mirror 3,313
   - `premigration_player_8482925865` exists in `StormSalvage_v1_LIVETEST_Backups` and equals the snapshot

**B3, reconnect and play:**
1. Rejoin (the same balance).
2. Sell some salvage and buy one cheap upgrade. Note the exact receipt numbers.
3. Leave.
4. **I verify** the stored exact balance equals the expected sum.

**B4, roll back to RC8:**
1. Owner restores **version 142** in version history (or publishes the RC8 file).
2. Shut down all servers.
3. **Verify:** join, F9. RC8's line has **no** "version" field; that's how to tell it's RC8.
4. Earn and spend a little; note it.
5. Leave.
6. **I verify:** Wallet untouched; the mirror changed by exactly that amount.

**B5, roll forward to RC12:**
1. Owner publishes RC12 again.
2. Shut down all servers.
3. **Verify:** the log shows the new version; F9 shows `applied an older build's money changes: +X +Y` matching B4.
4. **I verify** the exact balance.

**B6, restore on a disposable key** (never the primary profile without preserving it first):
1. **Preferred:** a disposable second account plays B2–B5. Then I preserve its profile and run `ProfileRestore.run("StormSalvage_v1_LIVETEST", "player_<alt>", "premigration")`.
2. **The alt rejoins and verifies:** the balance is the pre-migration one plus any purchases since (none, with purchases off), the profile loads, plays and saves normally, and the server log is clean.
3. **Without an alt:** I copy the owner's current profile and backup to `rehearsal_restore` keys in LIVETEST and restore those, verified by reading. The primary profile isn't touched.

**B7, finish:** the owner chooses which build stays published.
- **Recommended:** go back to the build under player test (RC9 or RC8) until the exact-money build has its own playtest, and keep RC12 as the next candidate.

## 5. RC12

RC12 = RC11 + the Stage A changes (§2). It is cut by CI from the commit that records this document and inspected like every RC (`RC12-CANDIDATE.md`).
