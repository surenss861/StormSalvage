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
