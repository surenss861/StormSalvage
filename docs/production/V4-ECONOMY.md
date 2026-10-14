---
related-code:
  - "[[Economy.luau]]"
  - "[[PlayerService.luau]]"
  - "[[ContractService.luau]]"
  - "[[MonetizationService.luau]]"
  - "[[DataService.luau]]"
domain: salvage-economy
type: spec
status: draft
tags: [storm-salvage, salvage-economy, v4]
---

# V4 Economy: aspirational progression (design; bands 1–2 now built)

> **2026-10-14 update (M3):** the safe-integer helper, the formatter and bands 1–2 are built, on a
> faster curve than the one below (first 1M at about 2.2 h instead of about 10 h). The owner asked
> for impressive wealth much earlier. What was built, the simulations and the Studio evidence:
> [`V4-M3.md`](V4-M3.md). Sections 2–9 below are the original draft, kept for reference.

The owner wants a ladder from coins to millions, billions and trillions, where bigger numbers come from **bigger accomplishments**, not from multiplying every price. This document is the required pre-implementation deliverable:
- the audit
- earnings bands and milestone times
- sinks and event rewards
- inflation controls and Robux strategy
- number representation, migration and rollback

**Nothing in it is implemented.** The one V4 piece already built is a fixed 150-coin extraction bonus; it would move onto this ladder.

## 1. Audit: where currency moves today

| Kind | Where | Notes |
| --- | --- | --- |
| **Grant**: sale | `PlayerService.sell` | Base value × multipliers (`Economy.sellTotal`, floor) |
| **Grant**: storm survivor | `StormService.rewardSurvivors` → `PlayerService.addCoins` | +25 |
| **Grant**: job | `ContractService` completion | Writes `Data.Coins` and `Stats.TotalEarned` directly |
| **Grant**: Robux pack | `MonetizationService` receipt | Atomic with the PurchaseId (RC3+ invariant) |
| **Grant**: V4 extraction | `PursuitService.extracted` → `addCoins` | 150, once per event |
| **Grant**: Studio only | `DebugService.setcoins` | Studio-gated |
| **Spend** | `buyUpgrade`, `buyTool`, `ContractService` buyFinish | Synchronous checks (`Economy.checkUpgrade` / `checkTool`, `Progression.canBuyFinish`) |
| **Stored** | `Data.Coins`, `Data.Stats.TotalEarned` | Plain numbers in the profile (DataStore JSON = doubles) |
| **Mirrored** | `leaderstats.Coins` (IntValue) | 64-bit integer: fine |
| **Displayed** | Cash tag, Shop, Tools, Supply Counter, Jobs, receipts | `UI.comma` everywhere (full digits) |

**What the audit found:**
1. **Precision.** Luau numbers are doubles, so integers are exact only up to 2^53 − 1 ≈ **9.007 × 10^15** (about 9 Qa). Trillions (10^12) and low quadrillions are safe as plain integers. Anything past about 9 Qa is not.
2. **Display.** `UI.comma` prints every digit: "1,234,567,890,123" doesn't fit the cash tag. It needs a compact formatter (1.23T).
3. **Clean grant paths.** Every grant is server-side, and only 5 code paths add coins. That makes the economy easy to rescale centrally.
4. **Lifetime earnings already exist.** `Stats.TotalEarned` is the natural basis for wealth status.

## 2. The ladder: five bands

Each band unlocks **a new class of salvage and events**, not just bigger prices. Within a band, coin upgrades raise income about 15×. Entering the next band (a **Salvage License**: a coin sink plus an accomplishment) gives access to salvage worth about 10× more.

| Band | Lifetime earned | Unlock (license) | What's new to chase | Typical income (entry → exit) | Time in band* |
| --- | --- | --- | --- | --- | --- |
| 1. Scrap Rookie | 0 → 100K | none | Today's town salvage and the Warehouse cache | 100 → 1.5K / min | 3–5 h |
| 2. Professional Salvager | 100K → 10M | 75K + 10 jobs done | Industrial salvage (crates, machinery), rotating caches in all five districts | 1.5K → 60K / min | ≈ 8 h |
| 3. Storm Hunter | 10M → 1B | 7.5M + 10 extractions | Storm-only salvage, bigger events (e.g. a wrecked armoured transport), harder twisters | 60K → 3M / min | ≈ 15 h |
| 4. Salvage Magnate | 1B → 1T | 750M + Storm Hunter titles | Experimental salvage, multi-stage extractions | 3M → 1.5B / min | ≈ 40 h |
| 5. Storm Legend | 1T → 1Qa (cap) | 750B | Mythic Storm Cores (rare, advertised, real odds), records | ≥ 1.5B / min | open-ended |

\* Engaged play. These are targets to tune against measured runs, not promises.

**Milestone targets**, roughly:
- first 1K: about 10 minutes
- **first 1M:** about 10 hours
- **first 1B:** about 27 hours
- **first 1T:** about 70 hours

The early game keeps today's feel: several upgrades in the first session.

**What makes a band bigger, in order:**
1. **New salvage classes** spawn only once you hold that band's license. (Everyone sees the same world. Unlicensed players see licensed salvage as locked: "Industrial salvage: Pro license".)
2. **Band-scaled events.** The Storm Pursuit reward becomes "N minutes of this band's base income" instead of a fixed 150, so the chase stays the best moment at every band.
3. **Band gear.** The Backpack, Boots and Armor tracks continue into each band, and band gear multiplies sale value modestly (×1.0 → ×1.5 within a band).

## 3. Spending goals (sinks)

| Sink | Share of spend | Why players want it |
| --- | --- | --- |
| **Salvage Licenses** | about 25% | The gate to the next band; a big, visible goal |
| **Band gear** (bag, boots, armour, detector range) | about 45% | Felt in every run |
| **Prestige cosmetics** (nameplate finishes per band, workshop and garage looks) | about 20% | Status (see `V4-STATUS.md`) |
| **Extraction licences** (harder event tiers) | about 10% | Opt-in risk for more reward |

## 4. Event reward bands

| Event | Available from | Reward | Rules |
| --- | --- | --- | --- |
| Rare cache (built) | Band 1 | Core value + extraction bonus = about 3 min of band income | One per storm cycle |
| District caches | Band 2 | About 5 min | Any district, announced |
| Armoured transport wreck | Band 3 | About 15 min, split among contributors | Public; a cooperative bonus |
| Multi-stage extraction | Band 4 | About 30 min | Opt-in, personal-best timing |
| Mythic Storm Core | Band 5 | About 2 h | Genuinely rare. **Odds published; no fake countdowns or jackpots.** |

**Every payout comes from the band table on the server.** No client sends an amount, and no event pays twice: each uses the single-transition pattern the Storm Pursuit already uses.

## 5. Inflation and exploit controls

- **Server authority.** All grants come from code paths keyed to the band table. No trading and no player-to-player transfers in V4.
- **Rate sanity.** If a player's measured income exceeds 3× the band's maximum for 10 minutes, log it (SessionStats) and flag it for review. No automatic punishment.
- **Sinks scale with bands**, so balances don't pile up uselessly.
- **Licences need accomplishments, not just coins**, so buying coins can't skip a band.
- **No compounding exploits.** Multipliers come only from gear owned and band. There's no prestige-reset farming in V4.

## 6. Robux strategy

- **Today's fixed packs (300 / 1,200 / 3,000) go worthless by band 2.**
  - Replace them with **band-relative packs**: "about 10 / 40 / 100 minutes of your band's *base* income".
  - That's computed by the server from your band, never from your personal rate, so it can't be gamed.
  - Robux prices stay fixed.
- **Cap:** a pack never gives more than about 15% of the next licence's coin cost. Licences also need accomplishments, so **paying never skips a band.**
- **Passes:** permanent convenience only (Heavy-Duty capacity). No income multipliers.
- **Model before launch:** a free and a paying player over 1, 10 and 50 hours. Payers should reach bands at most about 20–30% sooner, not skip them.
- **All real purchases stay disabled** until real transactions and this model are verified.

## 7. Number representation

- **Store** coins and lifetime earnings as **integers, capped at 1 × 10^15 (1 Qa)**, safely below 2^53.
  - Every grant and spend goes through one helper that floors, clamps at the cap, and refuses NaN or infinity (an extension of `Economy`), with unit tests at the boundaries.
- **Display** goes through one formatter:
  - K, M, B, T, Qa (and Qi, but only if a big-number type is ever adopted)
  - 3 significant figures: `1.23K`, `45.6M`, `789B`, `1.00T`
  - Exact digits in tooltips and receipts
- **If the game ever needs more than 1 Qa**, switch to a (mantissa, exponent) representation with a profile migration.
  - Don't let plain numbers drift past 2^53.
  - This is a deliberate later decision, not a default.

## 8. Migration and rollback

- **Existing profiles:**
  - Coins (today at most tens of thousands) stay as they are.
  - Everyone starts in band 1, unlocked by `Stats.TotalEarned`.
  - New fields: `Band`, `Licenses`, `Records`. They're reconciled on load, like the RC4 and RC7 fields.
- **Rollback to RC7 or earlier:**
  - Older code keeps the new fields (tested for `Tools` and `Records`).
  - Balances under 2^53 load and display fine with full digits.
  - **Risk:** a band-4 player rolled back to RC7 could buy everything in RC7 instantly. That's harmless to data but changes the experience.
  - So, before the economy goes live, the release plan should choose: **a new save namespace for V4** (clean), or a one-way migration with rollback limited to the bug-fix window.
- **DataStore budgets:** no new stores and no extra writes per grant. The profile still saves on autosave and leave.

## 9. Proposed first build (after review)

Not part of the current deliverable. It would come after the pursuit is judged fun.

1. The integer helper and the compact formatter, with unit tests.
2. The band table in `Config`, with bands 1–2 only.
3. The pursuit reward re-expressed as minutes of band income.
4. One band-2 licence and one industrial salvage class in one district.

Then measure with the economy bot and real players before going further.
