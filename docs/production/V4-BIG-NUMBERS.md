---
related-code:
  - "[[BigMoney.luau]]"
  - "[[Wallet.luau]]"
  - "[[DataService.luau]]"
  - "[[PlayerService.luau]]"
  - "[[MonetizationService.luau]]"
domain: salvage-economy
type: spec
status: wip
tags: [storm-salvage, salvage-economy, data, v4]
---

# V4 extreme-number economy: exact money beyond quadrillions (2026-10-14)

**Owner decision:** remove the 1 Qa currency ceiling. Built on `v4-gameplay` only.
- RC10 stays frozen, and RC8 (place version 142) stays published and untouched.
- `main` is unchanged.
- **Nothing in production changed:** no production DataStore was touched, purchases stay off, and nothing was published.

## 1. Representation (`BigMoney.luau`)

**Money is an exact non-negative integer of up to 303 decimal digits** (0 to 10^303 − 1), carried as a **canonical decimal string**: no sign, no leading zeros, digits only. That string is what's saved, sent over remotes and passed between modules.

**Arithmetic** runs on base-1,000 limbs:
- compare, add, subtract (refuses to go negative), multiply
- multiply by a small whole number
- divide by a small whole number, with remainder
- multipliers as exact fractions of 1,000 (×1.5 = 1500/1000), applied together and rounded down **once**

**No balance ever goes through `tonumber()` or float maths.** The one exception is `BigMoney.approx`, which is labelled for analytics and progress bars only.

**Input rules** (`BigMoney.parse`):
- **Accepted:** canonical digit strings, and whole Luau numbers from 0 to 2^53 − 1 (exact there).
- **Rejected:** negatives, fractions, NaN and infinity, signs, spaces, exponents ("1e10"), hex, non-ASCII digits, empty strings, anything over 303 digits, and raw strings over 400 characters (refused without being read).

**Legacy numbers** (saved balances) convert exactly through `fromLegacyNumber`: the double's own integer value, every digit. NaN, infinity and negatives are refused, never zeroed.

### The one suffix table (every display uses it)

| 10^n | Suffix | 10^n | Suffix | 10^n | Suffix |
| --- | --- | --- | --- | --- | --- |
| 3 | K | 24 | Sp | 45 | Qad |
| 6 | M | 27 | Oc | 48 | Qid |
| 9 | B | 30 | No | 51 | Sxd |
| 12 | T | 33 | Dc | 54 | Spd |
| 15 | Qa | 36 | Ud | 57 | Ocd |
| 18 | Qi | 39 | Dd | 60 | Nod |
| 21 | Sx | 42 | Td | 63 | **Vg** |

**Display rules:**
- **Above Vg,** it switches to scientific notation: `1.25e120`, then up to `9.99e302`.
- **Three significant digits, always rounded down** ("999Qa", never "1.00Qi", for one unit below). The rounding works on the digits themselves, so floats can't creep in.
- **Formats:**
  - `compact` for big labels
  - `full` for every digit with separators
  - `tag` for the cash tag: every digit under a million, compact after, **at most 9 characters at any size** (tested at every power of ten from 0 to 302)

## 2. Every money mutation goes through `Wallet.luau`

The full audit of reads and writes:

| Path | Now |
| --- | --- |
| Loot sales (with Salvage Press and boost multipliers) | `Economy.sellTotal` (exact) → `PlayerService.addCoins` → `Wallet.earn` |
| Storm survivor bonus, Pursuit and Extraction bonuses (golden ×3) | `addCoins` → `Wallet.earn` |
| Contract rewards | `Wallet.earn` |
| Upgrades (Backpack, Boots, Armor, Press), tools, licences, nameplate finishes | `Economy` / `Bands` / `Progression` checks on exact strings → `Wallet.spend` |
| Developer-product coin packs (off) | `Wallet.deposit`: cash only, never lifetime earnings; same atomic write as the PurchaseId |
| Lifetime earnings | Only `Wallet.earn` raises it; spending never lowers it |
| Studio QA only | `Wallet.setCashForTest` (DebugService, Studio-gated) |

**No other code writes money.** `Data.Coins` and `Stats.TotalEarned` still exist, but only as the legacy mirror described next. The old capped `Money` module is gone.

## 3. Persistence, migration and rollback

**Schema 2:**
```
data.Wallet = { Schema = 2, Cash = "<digits>", Lifetime = "<digits>",
                Mirror = { Coins = n, TotalEarned = n }, Repaired = {...}? }
data.Coins, data.Stats.TotalEarned  = the legacy mirror (numbers)
```

**Migration** (`Wallet.load`, inside `DataService.reconcile`, so it runs on every load and inside every UpdateAsync transform, including receipt grants):
- **A schema-1 profile** (numbers only) converts **exactly**.
- **A corrupt legacy value** (NaN, infinite, negative) is **never silently zeroed.** The original is kept in `Wallet.Repaired`, a warning is logged, and the balance starts from 0.
- **It's idempotent:** loading twice changes nothing, so UpdateAsync retries are safe.

**Why it's reversible: the legacy mirror.** Older builds (RC8, RC9, RC10) only read numbers.
1. **What's written:** after every change, the Wallet writes the exact balance into `Coins` / `TotalEarned` if it's at most 1 Qa, else exactly 1 Qa. That's RC10's own cap, so RC10's validation accepts it unchanged. The value written is also remembered in `Wallet.Mirror`.
2. **During a rollback:** an older build loads the profile, plays, earns and spends on those numbers, and saves.
3. **On the next load here:** the difference between the mirror and what was written is applied to the exact balance.

**Tested in Studio,** on the `_STUDIO` test profile with RC10's exact `53fe778` scripts:

| Step | Result |
| --- | --- |
| New code saves 5,000,000,000,000,002,000 cash | Stored `Wallet.Cash` exact; `Coins` mirror = 1,000,000,000,000,000 |
| RC10 loads it | No errors; RC10 accepts the mirror; Press level kept |
| RC10 buys Press level 3 (150,000) | RC10's mirror → 999,999,999,850,000; Press = 3; saved |
| New code loads it again | Logs "applied an older build's money changes: -150000". Cash **4,999,999,999,999,852,000** (exact); Press 3 kept |

Unit tests cover the same, plus earnings during a rollback, untouched round trips, and damaged wallets.

**Hazards (explicit):**
1. **Earnings past 1 Qa made *while rolled back*** to RC10 are lost: RC10 caps at 1 Qa. RC8 and RC9 have no cap, and their gains are applied. Spending in any older build is always applied.
2. **While rolled back,** a player with more than 1 Qa *sees* 1 Qa. Nothing is lost by that; the exact balance comes back on roll-forward.
3. **RC8 and RC9 don't have `Wallet`.** They keep it untouched because they save whole tables (verified for RC9 with the M3 fields).
4. **A profile saved by an older build *before* it ever met schema 2** has no Wallet. It simply migrates again from its numbers: the normal path.

**Mixed-version servers during a deploy:** safe for the same reason. A player moving between an old and a new server is reconciled on each new-server load.

**Session ownership and locks are unchanged:** the same keys, lock tokens, `ownedBy` checks and stale-lock rules. Wallet changes ride in the same session data and the same UpdateAsync writes.

**Crash recovery:** the exact strings and the mirror are written in the same table, in the same atomic UpdateAsync. There's no state where one is saved without the other.

**Before any production migration** (an owner gate, not done):
1. **Rehearse** on the private place with `LiveTestMode` (the `_LIVETEST` store), including a rollback to RC8 and a roll-forward.
2. **Record the restore path:** DataStore keys keep 30 days of versions (`ListVersionsAsync` / `GetVersionAsync`); restoring a key's pre-migration version is the last-resort restore. Verify it on a LIVETEST key before production.
3. **Keep the rollback window short.** Note hazard 1 for anyone past 1 Qa.

## 4. Replication and UI

**Over remotes:** `PlayerState.Coins`, `Lifetime` and `CarriedValue`, receipt `Base`, `Total`, `Balance`, `Lines[].Value` and `CapLoss`, and the player card's `LifetimeEarned` and `NetWorth` are all exact strings.

**On screen:**
- **The client** compares and formats through `BigMoney`; nothing parses money with `tonumber` except to animate a count-up, and only while the value has 15 digits or fewer.
- **The player list:** `leaderstats.Coins` is now a **StringValue** showing the tag ("38,900", "2.25Qi"). An IntValue tops out at 9.2 × 10^18.

**Verified in Studio:**

| Where | Result |
| --- | --- |
| HUD cash tag | "38,900" / "5.00Qi" / "2.24Qi" (rounded down from 2,249,999,999,999,940,000) / "9.99e302" at the max |
| Gear Shop | "YOU HAVE 2,249,999,999,999,940,000 COINS"; stickers "150K"; BUY · 150,000 |
| Tools tab, nameplate locker | Exact comparisons |
| Receipts | Every digit up to 999,999,999, compact above; "Coins now" exact up to 15 digits, compact after |
| Player card | Lifetime and **Net Worth** |
| Titles | Wealth ladder |

Screenshots: `docs/art/v4/bignum/01-04`.

**Status values:**
- **Cash:** what can be spent.
- **Lifetime earnings:** only ever rises; drives the wealth titles First Fortune, Billionaire, Trillionaire, Quadrillionaire and Quintillionaire.
- **Net worth:** cash plus the purchase price of owned upgrades, tools, licences and finishes. Spending moves value from cash to assets, so it doesn't drop.

## 5. Robux safety

- **Purchases stay off.** Coin packs are fixed amounts per product, applied with `Wallet.deposit` in the same atomic write as the PurchaseId, and never counted as earnings.
- **Idempotency, re-tested at quintillion-scale balances:**
  - injected grant-write failure → NotProcessedYet, nothing granted
  - retry → granted once, exactly 1,000
  - duplicate delivery → nothing more
  - new purchase → granted again
- **A rule for any future band-scaled pack:** the amount must be fixed per developer product (one product per band), or snapshotted durably when the prompt opens. It must **never** be computed from the player's state when a (possibly delayed) receipt arrives. Not built; needs a separately approved design.

## 6. Performance (`tools/econ/bench.luau`, `evidence/bignum-bench.txt`; Lune on a desktop CPU)

| Operation | 20 digits | 303 digits |
| --- | --- | --- |
| compare | 0.03 µs | 0.04 µs |
| add | 2.7 µs | 22 µs |
| subtract | — | 17 µs |
| ×1.5 (one factor) | — | 46 µs |
| full Wallet.earn (a sale) | — | 43 µs |
| compact / full format | — | 7 / 14 µs |

**The worst realistic case is under 0.1 ms per sale,** even with 300-digit balances. Studio: 500 concurrent grants of 123,456,789,012,345,678 took 38 ms and summed exactly.

**Sizes:**
- profile money at 1.25 Qi: 226 bytes of JSON; at the maximum: 794 bytes (RC10: 71 bytes). The DataStore limit is 4 MB per key.
- PlayerState money fields at the maximum: under 1 KB.

**No unbounded loops:** every loop is bounded by 303 digits (101 limbs).

## 7. Tests

**Unit tests** (95 in CI):
- **`bigmoney.spec`:**
  - parsing and rejection (20 bad inputs)
  - exact legacy conversion
  - compare, and boundaries at 10^0, 10^3, 10^6, 10^15, 10^18, 10^33, 10^63 and 10^302, one below and one above
  - MAX + 1
  - 3,000 seeded fuzz cases against native maths
  - identities at 300 digits (commutative, distributive, (a×k)/k)
  - exact multipliers, every suffix, scientific notation, tag width at all sizes
- **`wallet.spec`:**
  - migration (including 1 Qa and the LIVETEST-sized 3,313 profile)
  - corrupt values kept, earn/spend/deposit
  - the cap, rollback deltas (spend, earn, past 1 Qa, untouched), a damaged wallet
  - 10,000 rapid grants
- **Others:** `economy.spec` (exact sales and checks at sextillions), `titles.spec` (the wealth ladder at 1 Qi and one under).

**Studio integration** (`_STUDIO` store, real UI and prompts):

| Test | Result |
| --- | --- |
| Profile migration | 38,900 / 45,075 → exact strings |
| Exact maths at quintillions | 1.25 Qi + an earned 1 Qi → **2,250,000,000,000,000,000**; Press 2 → exactly −60,000; Turbine sale ×2 → +18,000 to **2,249,999,999,999,958,000** |
| Wealth titles | All five granted at 1 Qi lifetime |
| The maximum | Cap at exactly 10^303 − 1, shown as "9.99e302" |
| Receipts | Idempotency and failure injection (§5) |
| Rollback and roll-forward with RC10 | §3 |
| Regression | Golden Pursuit extraction (+18,000 band-2 bonus); golden sale with Press 3 (600 × 3 = 1,800); "Deliver a Storm Core" contract (+135): all exact |

**Not run here:** a forced server shutdown mid-save and stale-lock takeover. That locking code is unchanged since its V3 tests (`V3-SOAK-AND-DEATH-QA.md`); Wallet adds no new write path. Re-run them in the LIVETEST rehearsal.

## 8. High-scale progression model (design for review; only bands 1–2 are built)

**Big numbers come from new things to chase, not bigger prices on the same scrap.** Every band beyond 2 uses one template:

| Part | What a band adds |
| --- | --- |
| Salvage class | 4 new kinds with their own models and districts or event spawns (rarity ladder inside the band) |
| Signature event | A harder extraction or chase unique to the band (armoured transport, storm-eye dive, multi-stage haul) |
| Gear track | One band tool (sale press, capacity rig, route scanner), about 6 levels |
| Licence | Coins **plus** accomplishments in the previous band (extractions, discoveries, records) |
| Prestige | A band title and a nameplate finish; wealth titles at each named suffix |
| Sinks | Licence + gear ≈ 70% of what a band pays, so balances don't pile up |

**The scale model:**
- **Bands 3–6:** each band's items are worth about 30× the last (the same step as band 1 → 2).
- **From band 7:** about 1,000× per band, so each band is roughly one named suffix, with income and costs scaling together. Time per band stays about 10–20 hours of engaged play, set by the accomplishments rather than the numbers.

**Where the suffixes land:**

| Lifetime earnings | About band |
| --- | --- |
| 1 T | 5 |
| 1 Qi | 8–9 |
| 1 Dc | 13–14 |
| 1 Vg | 23–24 |

**What stays open:**
- **Numeric range:** BigMoney reaches 10^303 (about band 100), so it's never the limit.
- **A possible prestige layer** (rebuild the yard for permanent tokens) is an owner decision for later.
- **Implementation pace:** no dozens of bands at once. Band 3 is the next candidate after real playtests of bands 1–2.
