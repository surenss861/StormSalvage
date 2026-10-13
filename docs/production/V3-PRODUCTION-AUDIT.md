---
related-code:
  - "[[DataService.luau]]"
domain: data
type: spec
status: stable
tags: [storm-salvage, data]
---
# Storm Salvage V3: production audit (2026-10-13)

Branch `v3-art-direction`. Findings classified P0 / P1 / P2. "Verified" means a test was run and
its evidence recorded; anything else says so.

## P0

| # | Finding | Fix | Status |
| --- | --- | --- | --- |
| 1 | Environment isolation assumed any unknown place is a test place, and **Studio sessions read and wrote the live DataStore** (earlier purchase and upgrade tests changed the developer's real profile) | Explicit environments in `Config`: Production (listed place ids), Staging (listed), Studio (always `_STUDIO`), Unknown (no DataStores: temporary profiles, nothing saved, purchases refused) | **Studio-verified**: in Studio the server reports `Environment=Studio`, store `StormSalvage_v1_STUDIO`, fresh profile; a read-only snapshot of the live profile before and after all tests was identical (200 coins, Armor 3 / Boots 4 / Backpack 4, 11 receipts). Unknown-place fail-closed path is code-reviewed, not runtime-tested (needs a non-listed published place) |
| 2 | Production place id `99653875913460` is an assumption | Listed in `Config.ProductionPlaceIds` with a CONFIRM note | **Needs you** to confirm against the Creator Hub |
| 3 | Purchase fulfillment across servers | Bounded-history dependency removed (below) | Studio-tested (below); real cross-server delivery **not tested** (needs a published place and real products) |

### Receipt fulfillment review

- The grant and its PurchaseId are written to the profile in **one** `UpdateAsync`
  (`DataService.grantReceipt`); the transform is deterministic, does no side effects, and checks
  the PurchaseId inside the transform, so retries of the transform can't double-grant.
- Cross-server: `grantReceipt` refuses when another server holds the session lock (same check as
  saves), so only the server owning the profile can fulfil. The in-memory `inFlight` set only
  serialises duplicate callbacks *within* a server; it isn't relied on across servers.
- Partial failure: if the profile write committed but the call errored, the retry finds the
  PurchaseId in the stored profile, applies the grant to the live session once, and finishes.
  If an autosave from the live session (without the grant) overwrote the profile in between, the
  PurchaseId is overwritten too, so the retry grants once more, correctly. Saves write the whole
  session state, never deltas, which is what makes this safe.
- The profile's PurchaseId list is **never pruned** (the earlier 100-entry cap was removed), so
  the invariant "PurchaseId in the stored profile ⇔ reward in the stored profile" holds for the
  profile's lifetime without any other store. The lifetime `_Purchases` store is written after the
  profile and is now only an audit log and a fast skip; correctness doesn't depend on it.
  Cost: ~20 bytes per purchase, so a profile reaches the 4 MB DataStore limit only after
  ~200,000 purchases.
- Lock transitions: a server that doesn't hold the session lock can't grant (tested: a foreign
  lock gives `NotProcessedYet`, nothing stored, and that session stops saving). The new owner
  loads the profile including any PurchaseId written before the hand-off.

Studio run 2026-10-13 against the real handler (simulated receipts, `_STUDIO` profile, fault
injection, DataStore read back after each step):

| Scenario | Result |
| --- | --- |
| A First delivery | PASS: Granted, +1000 live and stored |
| B Same receipt again | PASS: Granted, no change |
| C Grant write fails, retry | PASS: NotProcessedYet, live unchanged; retry grants once |
| D History write fails after grant, retry | PASS: retry Granted, no second grant |
| E Final save fails, retry | PASS: retry Granted, no second grant |
| F History read fails, retry | PASS: nothing granted; retry grants once |
| G Two concurrent deliveries | PASS: one Granted, one NotProcessedYet, one grant |
| H History record deleted, receipt redelivered | PASS: profile list alone blocks the regrant; history re-recorded |
| Totals | 6 receipts → +6000 live, stored = live, all 6 PurchaseIds kept |

## P1 / P2

| # | Finding | Fix | Status |
| --- | --- | --- | --- |
| 4 | `BuyUpgrade` (the only client-to-server remote) had no rate limit | 8 requests/s per player, oversized ids rejected | **Studio-tested**: malformed ids (nil, numbers, NaN, inf, tables, booleans, "", 5000 chars, "Coins", "__index") got 0 responses; 60-request burst got 8; a funded 60-request burst bought exactly one level with an exact coin deduction |
| 5 | Economy rules lived inline in `PlayerService`, untestable outside Studio | `src/shared/Economy.luau` (pure): sell total and upgrade eligibility, now used by the server | 8 unit tests pass (`tests/`, Lune) |
| 6 | No CI | `.github/workflows/ci.yml`: stylua, selene, luau-lsp types, Rojo build, unit tests; tools pinned in `rokit.toml`; `tools/ci/check.sh` runs the same locally | Passes locally; first GitHub run on push |
| 7 | Sell / pickup races | Reviewed: sale empties the bag before any yield; pickup marks the item taken before any yield, so concurrent triggers can't double-award | **Studio-tested**: two clients touching one Safe → exactly one got it; 5 sales started in one frame → one payout; empty-bag sales pay nothing |

## Not started in this pass

Memory-leak soak (shop open/close, deaths, weather cycles), 4/8/12-player load, low-graphics
rendering investigation on hardware, join timing, release runbook. UI creative reset in progress.

## Persistence beyond the receipt suite (Studio, `_STUDIO`, 2026-10-13)

| Check | Result |
| --- | --- |
| Environment resolution (pure `Environment.resolve`, 8 unit tests in CI) | Studio is `_STUDIO` on any place id, including the live one. A listed live place uses the real store and a listed staging place uses `_STAGING`. Unlisted, unpublished, invalid, or listed-as-both places get **no store**. |
| Unknown environment at runtime | Code path: no store means `DataService.load` returns a default profile with `CanSave=false`, so nothing saves, receipts get `NotProcessedYet` and Robux buttons are refused. Not runtime-tested; it needs a non-listed published place. |
| Long-lived profile: 1,000 / 5,000 / 20,000 receipt IDs | Stored 21 KB / 109 KB / 449 KB (0.5% / 2.6% / 10.7% of the 4 MB limit); saves took 0.32 / 0.38 / 0.50 s. Real PurchaseIds are longer, so the ceiling is roughly 100k purchases per player. |
| Redelivery of the **oldest** of 20,000 IDs with no history record | Granted nothing (coins unchanged), so the profile list alone blocks it. A new ID granted exactly once, and its redelivery granted nothing. About 1 s per receipt. |
| Stale lock (crashed server, 401 s old) | Taken over; the profile loaded 0.1 s after join with saving on and no data lost. |
| Live lock held by another server | 6 retries, then the player is kicked at 41.6 s; the profile and the other server's lock are untouched. |
| Release on shutdown (Studio Stop) | The lock is released within 5 s of Stop (`BindToClose` save with release). |
| Cross-server redelivery | **Not tested**: it needs two real servers in a published place. Covered by design (lock check inside the grant transaction) and by the foreign-lock test. |

The test profile was cleaned afterwards (synthetic IDs and the planted lock removed).

## RC2: save-lock ownership fix (found in the RC1 review, 2026-10-13)

**Defect in RC1.** `save` and `grantReceipt` refused only when the stored lock belonged to *another* session; a profile with **no lock** was accepted. That allowed this sequence:
1. Server A stalls, its lock expires, and the player moves to server B, which takes over.
2. B grants a paid product (durable, and Roblox is told PurchaseGranted).
3. The player leaves B, which releases the lock.
4. A wakes up and autosaves its stale whole-profile copy, wiping B's progress **and the paid grant and its PurchaseId**. Roblox won't redeliver, so the purchase is lost.

A second instance of the same defect: an autosave racing the player's own leave could re-lock a released profile and lock the player out of other servers for up to 6 minutes.

**Reproduced on RC1 code** (Studio, `_STUDIO`): after B granted +5,000 and released, A's autosave returned `true` and the stored profile went from 11,100 back to 6,100 coins, with receipt `B-paid-2` gone.

**Fix (RC2).**
- Every write after load (`save`, `grantReceipt`) requires the stored lock to be **this server's own** (`ownedByUs`). A missing lock counts as lost.
- After the leave-save releases the profile, the session is marked unsaveable.
- Load and takeover are unchanged: a lock is taken over only after 360 s without a refresh, and `UpdateAsync` re-runs a delayed write's check against the newest stored value, so an old owner's late write sees the new owner (or no owner) and is refused.

**RC2 verification (Studio):**

| Test | Result |
| --- | --- |
| Same attack on RC2 | A's autosave `false`, A's late receipt `NotProcessedYet`, B's +5,000 and `B-paid-1` intact, A stops saving |
| Normal ownership | Save and receipt work while the lock is ours |
| Receipt suite A–H | All pass; +6,000 exactly; stored = live |
| Release on leave | Lock released after Stop |
| Stale-lock takeover then save | Loaded in 0.1 s; the new owner saves normally |
| Live-lock contention | Load code unchanged since the RC1 test (6 retries, kick at 41.6 s, data untouched) |

**Residual (by design, not a safety issue):** if server A stalls and loses its lock, any progress A made after its last successful save is lost when it's refused. That trades a little progress for never overwriting newer data or purchases. A crashed server's lock blocks the player's rejoin for up to 360 s (each try retries for about 42 s, then shows "Couldn't load"). A shorter expiry would need a lock heartbeat; deferred.

## RC3: ownership review of the six RC2 conditions (2026-10-13)

| # | Condition | Finding | Status |
| --- | --- | --- | --- |
| 1 | Ownership checked atomically at commit | Every check runs inside the `UpdateAsync` transform, which Roblox re-runs against the newest value if the key changed | Holds (code review) |
| 2 | Old servers can't release newer locks | A release is a save with `Lock = nil` and goes through the same ownership check | Holds (code + RC2 attack test) |
| 3 | No writes after a completed leave | The session is marked unsaveable; the token is forgotten on release; a missing lock counts as lost | Holds; tested |
| 4 | Concurrent autosave, leave and purchase | 10 purchases racing 10 saves: exact. Shutdown during in-flight purchases (2 rounds): consistent, lock released. **This found defect B below.** | Fixed in RC3; tested |
| 5 | Receipt fulfilment atomic with the profile | The grant and PurchaseId are in one transform. **But the history store was still read as a shortcut: defect B.** | Fixed in RC3 |
| 6 | Tokens can't be reused by an older session | **Defect A:** the token was per server (JobId), so a rejoin on the same server shared it with the old session | Fixed in RC3; tested |

**Defect A (RC2): the lock token was shared across sessions on one server.**
- **Risk:** a delayed write from a player's earlier session on the same server could pass as the new session.
- **Fix:** every load makes a token `JobId/guid`. Writes capture their session's token, and the token is forgotten on release.
- **Same-server takeover:** a stale lock from this server is taken over at once, which is safe because the old session's writes carry its old token.
- **Test:** with a different session from the same server holding the lock, our save was refused, our receipt got `NotProcessedYet`, and the coins were unchanged.

**Defect B (RC2): the purchase-history shortcut could swallow a paid purchase.**
- **How it happened:**
  1. A grant committed.
  2. The shutdown save wrote the session's copy, which didn't have the grant yet. That is consistent by design: the reward and its ID drop together, so Roblox redelivers.
  3. The handler then wrote the history record anyway.
  4. On redelivery the history check answered PurchaseGranted **without granting**.
- **Reproduced in Studio:** after a shutdown mid-purchase, receipt #1 had a history record but no profile grant.
- **Fix:** the history store is never read; it is a write-only audit log, written only after the save that contains the reward. `purchaseRecorded` and the `historyRead` fault are removed.
- **Tests:**
  - redelivering the 6 interrupted purchases (including #1) granted each exactly once, and a second redelivery changed nothing
  - new scenario I (a history record but no grant) grants once
  - the shutdown-race rounds left no history record without its grant

**RC3 regression (Studio, `_STUDIO`):**
- receipt suite A–E, G, H, I: exactly +6,000, stored equal to live
- the stale-owner attack was refused and B's grant survived
- 10 purchases racing 10 saves: exact
- shutdown races: 2 rounds consistent
- release on leave, stale takeover and normal saving: all pass
- 19 unit tests pass

Scenario F (a history-read failure) is retired because history is no longer read.

**Still not tested (needs two real servers):** cross-server redelivery and lock hand-off between two live game servers. The Studio tests stand in for the other server by writing the DataStore from the Edit session. Planned for the private live experience on `_LIVETEST` (test plan §4).

## RC3: live-test data namespace (no staging experience)

- The live place (`99653875913460`, confirmed) uses `StormSalvage_v1_LIVETEST` while `Config.LiveTestMode = true`, so existing real saves are never opened during testing.
- 3 new unit tests cover it, and Studio is still `_STUDIO`.
- **Release guard:** `tools/ci/release-gate.sh`, run on `release-*` tags, fails while the flag is on or the place ID differs. Verified both ways.
