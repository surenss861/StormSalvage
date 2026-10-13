# V3 progression: Salvage Contracts, Reputation, nameplate finishes

Built 2026-10-13, following the owner's retention directive (contracts first, then reputation, then a lightweight coin sink). It is Studio-tested and part of RC4; nothing is published.

## What players get

- **Contracts.** Three jobs are always open. They're on the **Contract Board** beside the spawn aisle (prompt "View Jobs") and behind a **JOBS** button next to Settings. Finishing a job pays coins and XP and deals a different job at once. One job can be **pinned**; it then shows on the HUD's sticky note ("JOB: Sell 8 salvage 3/8"), but only after the first-session tutorial chain is done. **Swap** replaces a job you don't want, once every 2 minutes.
  - Kinds: collect N salvage · salvage N items in a named district · sell N salvage · earn N coins from sales · survive a storm in town · deliver a Storm Core
  - Targets and rewards grow 35% per rank
- **Reputation.** Salvager XP is never spent. It comes from jobs (most), +1 per item sold and +10 per storm survived. There are seven ranks: Scrap Rookie (0), Scavenger (150), Salvager (400), Storm Runner (900), Wreck Diver (2,000), Yard Boss (4,500), Storm Legend (9,000). A rank is a title on your nameplate and unlocks finishes. It **never** gives stats, multipliers or coins.
- **Nameplate finishes (the coin sink).** Every player's overhead nameplate shows their name, rank title and a finish. The finishes are Cardboard (free), Galvanised Tin 500, Brass 1,500, Hazard Stripe 3,000, Copper Patina 5,000, Chrome 8,000 and Storm Glass 12,000, each needing the matching rank. That's **30,000 coins** of purely cosmetic goals, roughly 3× the cost of all equipment. Roblox's default overhead name is replaced by the nameplate.

## Authority and safety

- Progress comes **only** from the server's own events, each reported once by a code path that already guarantees it happens once:
  - a pickup the server granted (LootService's `taken` flag)
  - a paid sale (the bag is emptied before anything else)
  - the storm-survivor check

  Recovering your **own dropped bag doesn't count** as collecting again.
- **Completion is atomic.** Coins, XP and the replacement job change in one step that can't be interrupted, inside the profile. They save, or fail to save, together with everything else under the RC3 session-owned save. No new store, no new currency.
- **Client powers.** The client can only pin, swap (with a server cooldown) and buy or equip a finish. Each is validated (types, a length cap, a rate limit of 6/s, rank and cost) and charged synchronously.

## Studio tests (`_STUDIO`, real prompts and real sales where possible)

| Test | Result |
| --- | --- |
| Old profile (no new fields) loads | Fields added (3 distinct jobs, XP 0, Cardboard); coins untouched |
| 7 real pickups | Collect 7/8 |
| **5 sales fired in the same frame** | One payout (+14), Sell 7/8, +7 XP |
| 8th pickup | Collect job done: +50 coins (pre-rebalance value), +25 XP, new job dealt, feed message, pinned note updated |
| Die, then recover your own dropped bag | Items return to the bag; **Collect progress unchanged** (3 → 3) |
| Real storm survived in town | +10 XP, +25 coins (existing bonus) |
| Pin and swap (real clicks) | Pinned shown on the HUD; swap replaced a job; a second swap refused (120 s cooldown) |
| Rejoin | XP, coins, the exact jobs, progress and pin all restored |
| Rank-up (+118 XP to 150) | Scavenger; rank-up card names the unlocked finish; nameplate title updates |
| Buy a finish with too few coins | Refused, coins unchanged |
| **5 rapid buys** of a 500-coin finish | Charged once (600 → 100); owned; equipped |
| Hostile remote input (nil, tables, a 5,000-character string, locked/unknown finishes, 40× spam) | All ignored; no change; no server errors |
| **Rollback:** RC3 code (no contracts) loads this profile and saves | XP, jobs and the owned finish **preserved** (RC3 saves whole tables) |
| Purchase-safety suite A–I on RC4 | +6,000 exact, stored = live, jobs and XP untouched |
| Nameplate | Shows name, rank and finish; default name hidden (`docs/art/v3/ui/jobs/04`) |

**Not tested:**
- seeing *another* player's nameplate: Studio's second test client failed to connect, so I checked with the Studio-only own-plate switch instead
- the mobile layout of the Jobs board, on device
- contracts across a real server hop (they're in the profile, so they follow the same save path as coins)

## Economy (10-minute autopilot runs, fresh profile; small sample, high variance from Storm Cores)

| Run | Sales | Jobs | Storm bonus | Total | Per min | XP | Upgrades | First sale / first upgrade |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Before contracts (earlier session) | 796 (543 from Cores) | n/a | in sales | 796 | ~84 | n/a | B1 S1 A1 | 113 s / 150 s |
| Free, contracts at the **first** reward values | 322 (no Cores) | **470** (7 jobs) | 75 | 867 | ~83 | 327 (Scavenger at ~5 min) | B2 S2 A1 | 39 s / 128 s |
| Paid (+4 slots), **rebalanced** rewards | 982 (one 458 Core trip) | 390 (9 jobs) | 75 | 1,447 | ~140 | 439 (Salvager) | B3 S2 A2 | 63 s / 64 s |

**Findings and changes:**
1. **Job coins were too high.** At the first values, jobs paid more than salvaging (54% of income), because ordinary play advances two jobs at once. Coin rewards were **halved** (Collect 25, District 35, Sell 25, Earn 30, Survive 60, Core 80 at rank 1). In the paid run jobs were **27%** of income: they reward variety without replacing salvaging.
2. **Rank pace.** About 30–45 XP/min early, so Scavenger in about 5 min and Salvager in about 10–15 min, both inside the first 30 minutes. XP per job grows 35% per rank. The upper ranks were raised (2,000 / 4,500 / 9,000), giving Storm Legend at roughly 5–7 hours of play: days of sessions, not one sitting. This is an estimate to check with real players.
3. **Heavy-Duty Pack (+4).** This is strongest at the start (3 → 7 slots, +133% bag). The paid run's sales without its Core trip were about 524 against 322 for the free run, roughly +60%, from very different storm luck. Later, 20 → 24 slots is +20%. Free Backpack upgrades are still bought (the paid bot bought level 3). **Recommendation:** keep +4 for now, and measure with real players whether early free upgrades feel pointless. If they do, consider +2 early scaling to +4.
4. **Coin packs** are now 300 / 1,200 / 3,000 (owner decision): 3%, 11% and 29% of all equipment, and only 1–10% of equipment plus finishes.
5. **After max equipment** coins still matter: 30,000 coins of finishes, and jobs keep paying.

## Data and rollback

- **New profile fields:** `Rep { XP }`, `Contracts { Active, Done, Pinned }`, `Cosmetics { Owned, Plate }`. Missing fields are filled on load, and malformed jobs are repaired.
- **Rollback.** Older code (RC3) keeps the fields untouched; this was tested. Rolling back loses no progression, and rolling forward again restores it.
- **Live-test data.** Contract and XP progress made during `LiveTestMode` stays in `_LIVETEST`, like coins.
