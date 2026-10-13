# Storm Salvage V3: production audit (2026-10-13)

Branch `v3-art-direction`. Findings classified P0 / P1 / P2. "Verified" means a test was run and
its evidence recorded; anything else says so.

## P0

| # | Finding | Fix | Status |
| --- | --- | --- | --- |
| 1 | Environment isolation assumed any unknown place is a test place, and **Studio sessions read and wrote the live DataStore** (earlier purchase and upgrade tests changed the developer's real profile) | Explicit environments in `Config`: Production (listed place ids), Staging (listed), Studio (always `_STUDIO`), Unknown (no DataStores: temporary profiles, nothing saved, purchases refused) | Implemented; static checks pass. **Studio runtime check pending** (Studio closed mid-session) |
| 2 | Production place id `99653875913460` is an assumption | Listed in `Config.ProductionPlaceIds` with a CONFIRM note | **Needs you** to confirm against the Creator Hub |
| 3 | Purchase fulfillment across servers | Reviewed (below): no code change needed | Reasoned; cross-server delivery **not tested** (needs a published place) |

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
- The lifetime `_Purchases` store is written **after** the profile, so "recorded there" implies
  "granted in the profile". It is a fast skip and the guard against the 100-entry profile list
  being pruned. Known residual: if the history write fails *and* more than 100 newer receipts
  arrive before the retry, a regrant is possible. Practically unreachable; documented.

## P1 / P2

| # | Finding | Fix | Status |
| --- | --- | --- | --- |
| 4 | `BuyUpgrade` (the only client-to-server remote) had no rate limit | 8 requests/s per player, oversized ids rejected | Implemented; runtime spam test **pending** |
| 5 | Economy rules lived inline in `PlayerService`, untestable outside Studio | `src/shared/Economy.luau` (pure): sell total and upgrade eligibility, now used by the server | 8 unit tests pass (`tests/`, Lune) |
| 6 | No CI | `.github/workflows/ci.yml`: stylua, selene, luau-lsp types, Rojo build, unit tests; tools pinned in `rokit.toml`; `tools/ci/check.sh` runs the same locally | Passes locally; first GitHub run on push |
| 7 | Sell / pickup races | Reviewed: sale empties the bag before any yield; pickup marks the item taken before any yield, so concurrent triggers can't double-award | Reasoned; two-client race **not yet run** |

## Not started in this pass

Memory-leak soak (shop open/close, deaths, weather cycles), 4/8/12-player load, low-graphics
rendering investigation on hardware, join timing, release runbook, UI creative reset.
