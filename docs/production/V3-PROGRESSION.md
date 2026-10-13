---
related-code:
  - "[[ContractService.luau]]"
  - "[[Progression.luau]]"
  - "[[Jobs.luau]]"
  - "[[PlateStyle.luau]]"
  - "[[autopilot.luau]]"
domain: progression
type: spec
status: stable
tags: [storm-salvage, progression]
---
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

## RC4 review follow-up (2026-10-13)

### Staged discovery (owner request)

A new player first learns to salvage and survive. The extra systems appear as they progress:

| Moment | What appears |
| --- | --- |
| Join | HUD, Gear Shop (Equipment only), storm sign, tutorial note. **No JOBS button, no Supply Counter.** |
| First sale | The JOBS button, plus a one-time notice: "NEW: the JOBS board. Bonus contracts for coins and Salvager rank!" The pinned job takes over the note once the tutorial chain ends. |
| First equipment upgrade | The Supply Counter tab in the Gear Shop. |

- **What waits:** job and rank-up notices are held until the JOBS board is introduced.
- **What doesn't:** progress and XP accrue from the start on the server, so nothing is lost.
- **Verified in Studio:** with a brand-new profile, JOBS and Supply were hidden; after the first sale, JOBS plus the notice appeared; after the first upgrade, Supply appeared.

### Finishes are materials, not just colours

`PlateStyle.luau` dresses each finish, and the same code draws the overhead nameplate and the locker preview:
- Cardboard: a masking-tape corner
- Tin: four rivets and a galvanised gradient
- Brass: a polished sheen
- Hazard: black chevron stripes with a solid band for the name
- Copper: patina at the edges
- Chrome: a mirror highlight band
- Storm Glass: dark glass, a cyan glow edge and a lightning bolt

It builds and passes CI. **Not yet screen-verified:** Studio screen capture kept timing out at the end of this session.

### Matched economy comparison (same bot, same seed 42, fresh profile, 15 min)

The new Studio-only `QA_Seed` attribute makes loot spawns, storm order, strikes and contract deals identical between runs. The bots' paths still diverge once their bag sizes differ.

| | Free | Heavy-Duty (+4) |
| --- | --- | --- |
| Total coins | 1,380 | 2,127 (**+54%**) |
| Sales | 775 | 1,432 (+85%) |
| Jobs | 480 (9 done) | 570 (12 done) |
| Storm bonuses | 125 | 125 |
| XP / rank | 507 / Salvager (Scavenger at 293 s) | 641 / Salvager |
| Equipment after 15 min | B3 S2 A2 | B3 S3 A2 |
| First loot / sale / upgrade | 16 s / 40 s / 84 s | 18 s / 48 s / 92 s |
| Biggest trip | 275 | 423 (more room for Storm Cores) |

**Player journey (free run), in the order it happened:**
1. First loot at 16 s.
2. First sale at 40 s.
3. First upgrade at 84 s.
4. First job and rank: Scavenger at 293 s (under 5 min), Salvager at 778 s (about 13 min).
5. First cosmetic: **not reached in 15 min.** The bot spends every coin on equipment, and a real player choosing to save would take a few more minutes. That's acceptable, because finishes are meant as a medium-term goal.

The return session is covered by the rejoin test (everything persists), but a real return visit needs players.

**Heavy-Duty Pack:** paid players still buy Backpack upgrades (both reached B3), so free upgrades aren't made irrelevant. But **+54% total income in the first 15 minutes** is large for a 149 R$ pass.

**Recommendation (owner decision):**
- launch it as **+2** slots (about half the effect), or
- keep +4 but only from Backpack level 2 onward

Either way, re-measure with real players. Unchanged until you decide.

### Bot reliability (QA tool, not game)

The autopilot stalled several times behind the Scrap Buyer shack. Roblox only shows a prompt that's on screen and inside its range, and the bot's approach points were landing on the shack roof. The bot now looks at what it presses and walks to verified spots in front of the counter. Runs made before that fix are not used for conclusions.

## RC5 review follow-up

- **Heavy-Duty Pack is now +2 slots** (owner decision), in the next candidate RC6. RC5 is unchanged.
- **Matched +2 run** (seed 42, same bot, fresh profile, 15 min): total **1,557** (sales 1,082, jobs 375 from 7, storms 100). XP 404 / Salvager; Backpack 3. That's **+13% total** against the free run's 1,380, compared with +54% at +4. Sales were +40%, but this run had 2 deaths and two empty trips, so treat it as one noisy sample. **Free Backpack upgrades stay worthwhile:** the free run also reached Backpack 3, and the +2 player still bought Backpack 3. Re-measure with more seeds and real players in the private test.
- **Finishes in-game:** all seven drawn as real overhead nameplates over Town Square (`docs/art/v3/ui/jobs/06` Calm, `07` Lightning).
  - Calm: each finish is distinct and every name is readable.
  - Lightning: the storm grading dims them all. They stay legible, and Hazard and Storm Glass stand out most, but Chrome loses most of its shine. Acceptable for now; revisit if players say so.
