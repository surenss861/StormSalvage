---
related-code:
  - "[[MonetizationService.luau]]"
  - "[[SupplyCounter.luau]]"
domain: salvage-economy
type: spec
status: stable
tags: [storm-salvage, salvage-economy]
---
# Storm Salvage V3: monetization (Supply Counter)

**Status: built and Studio-tested, not on sale.** `Config.PurchasesEnabled = false` and every product ID is `0`. No product exists on Roblox yet, no Robux has been spent, and the experience is still private.

## 1. Launch catalog (owner's plan; packs resized to 300 / 1,200 / 3,000 on 2026-10-13)

| Item | Type | Gives | Planned price | Config key |
| --- | --- | --- | --- | --- |
| Pocket Change | Developer product, repeatable | 300 coins | 29 R$ | `DevProducts.CoinsSmall` |
| Scrap Bundle | Developer product, repeatable | 1,200 coins | 99 R$ | `DevProducts.CoinsMedium` |
| Salvage Haul | Developer product, repeatable | 3,000 coins | 199 R$ | `DevProducts.CoinsLarge` |
| Heavy-Duty Pack | Game pass, permanent | +4 bag slots on top of Backpack upgrades | 149 R$ | `GamePasses.HeavyDuty` |

The old placeholder items are removed. "Big Bag" (+5) and "VIP" (+20% sell value) had never been created on Roblox (ID 0), and VIP was a paid power boost the plan doesn't include. The unused "2x Salvage" product is gone too.

Not built, as the plan says to defer them: Storm Recovery, Salvage Scanner, VIP cosmetics, subscriptions, loot boxes and extra currencies.

## 2. How it works

- **Where it appears.** The Gear Shop has two tabs: **Equipment** (the coin workbench, unchanged, and the default) and **Supply Counter**. Nothing pops up anywhere else: no prompts on death, in storms or on join.
- **Each ticket shows:**
  - the exact amount, in large type
  - REPEATABLE or PERMANENT
  - the price (the real Creator Hub price once the product exists, otherwise the planned price, labelled as such)
  - a button whose state follows the purchase: *Buy*, *Check the Roblox window*, *Delivering…*, *Delivered +2,000*, *Cancelled*, *Still processing* (after 20 s), *Owned*, *Not on sale yet*, and *Paused: saves off* if the player's saving is unavailable
- **Coins.** Coins are granted **only** by the server's receipt handler, from Roblox's receipt. The client never adds coins, and the "purchase finished" event on the client only moves the ticket to *Delivering*. "Delivered" appears when the server sends `PurchaseDelivered`, which happens after the reward is saved.
- **Receipt handling.** This is the RC3-hardened path: the grant and the receipt ID are written in one DataStore write under this session's lock; receipt IDs are never pruned; history is never read; and *delivered* is reported only after a save. A purchase survives leaving mid-purchase, a server shutdown, retries and server hops, because Roblox redelivers until the server reports it granted.
- **Heavy-Duty Pack.**
  - **Where it's stored:** on the session as a yes/no flag, so it can't stack. A second grant was tested and capacity stayed at 24.
  - **When it's granted:** on join (`UserOwnsGamePassAsync`, retried every 30 s up to 10 times if Roblox errors) and when Roblox's server-side "pass purchase finished" event fires.
  - **What's saved:** nothing. Roblox's ownership record is the source of truth, so it can't be lost or duplicated by saves.
- **Analytics.** Each delivered purchase logs a `Purchase_<Key>` custom event for Creator Hub dashboards.

## 3. Studio tests (`_STUDIO`, simulated receipts through the real handler)

| Test | Result |
| --- | --- |
| Each pack: first delivery and an immediate duplicate | +500 / +2,000 / +5,000 granted; each duplicate +0 |
| Salvage Haul delivered 3 times at once | One granted, two `NotProcessedYet`, +5,000 total |
| Grant write fails, then a retry | `NotProcessedYet`, then granted once |
| Totals | 14,500 coins, stored = live, exact |
| Heavy-Duty Pack granted twice | Capacity 20 → 24 → 24 (no stacking) |
| Clicking Buy while not on sale | No Roblox window; "This isn't on sale yet."; shop stays open |
| Delivered state on screen | Ticket shows "Delivered +2,000", the cash tag counts up, the notice appears and the pass shows "Owned" (`docs/art/v3/ui/supply/02`) |
| Phone layout (Studio preview) | Four tickets fit and stay readable (`supply/03`) |

Plus the RC3 receipt suite (A–I, ownership attacks, shutdown races) from `V3-PRODUCTION-AUDIT.md`, which this catalog runs on.

**Not tested (real Robux and real devices needed):**
- the real Roblox purchase window and its cancel path
- `PromptProductPurchaseFinished` timing
- real price loading
- `UserOwnsGamePassAsync` against a real pass
- a real purchase followed by a server hop
- phone tapping

## 4. Economy check: do the packs trivialize progression?

**Updated:** the packs are now 300 / 1,200 / 3,000 (3% / 11% / 29% of all equipment). Contracts and the 30,000-coin nameplate sink are added. The current measurements are in `V3-PROGRESSION.md`; the original analysis follows for the record.

**Measured, a 10-minute bot run from a fresh profile in Studio.** The bot is naive and ignores storms, so a skilled player will be faster.
- **Milestones:** first pickup at about 81 s, first sale at 113 s, first upgrade at **150 s** (it bought all three level-1 upgrades early).
- **Earnings:** 796 coins in about 9.5 min of active play, roughly **84 coins/min**. **543 of the 796 came from 3 Storm Core trips**; ordinary trips paid 10–54 coins.
- **Expect** roughly 40–120 coins/min early on depending on skill and storms, rising with Backpack upgrades.

**Cost of all equipment:**

| Path | Cost of every level |
| --- | --- |
| Backpack (5 levels) | 4,100 |
| Running Boots (4) | 2,825 |
| Storm Armor (4) | 3,550 |
| **All 13 levels** | **10,475** |

**What each pack is worth:**

| Pack | Coins | Share of all equipment | Play time it replaces (at about 84/min) |
| --- | --- | --- | --- |
| 500 / 29 R$ | 500 | 5% | about 6 min. **Buys every level-1 upgrade at once** (225 coins) plus Backpack level 2 |
| 2,000 / 99 R$ | 2,000 | 19% | about 24 min |
| 5,000 / 199 R$ | 5,000 | 48% | about 1 hour |
| All three | 7,500 | 72% | about 1.5 hours |

**My read:** free players still have something to do, since full equipment takes a free player roughly 2–3 hours. But the top pack buys nearly half the whole progression path in one tap, and there is nothing after maxed equipment to spend on. A buyer who maxes out quickly has no goal left. Before activation, either:
- **(a) Smaller packs,** e.g. 300 / 1,200 / 3,000, which keeps each pack under 30% of the path; or
- **(b) Keep the sizes** but add a coin sink after max level first, such as cosmetics.

Which way to go is a pricing decision for you. The quantities are one-line changes in `Config.DevProducts`. None of this is a revenue forecast.

## 5. Creator Hub setup (owner, when you decide to create the products)

Creating products doesn't put them on sale in the game. The in-game buttons stay off until `PurchasesEnabled` is true.

1. **Creator Hub → Storm Salvage → Monetization → Developer Products → Create.** Create three:
   - "Pocket Change": 29 R$, description "300 coins"
   - "Scrap Bundle": 99 R$, "1,200 coins"
   - "Salvage Haul": 199 R$, "3,000 coins"

   Upload a simple icon for each. Copy each product's **ID**.
2. **Monetization → Passes → Create a Pass.** "Heavy-Duty Pack": 149 R$, "+4 bag slots, permanent". Put it **on sale** in its settings, then copy the pass **ID**.
3. **Send me the four IDs.** I'll put them in `Config` (still with `PurchasesEnabled = false`), check in Studio that each ticket loads its real price, and cut a new RC.

## 6. Activation checklist (all must be true before `PurchasesEnabled = true`)

- [ ] Real IDs configured; real prices load in game.
- [ ] Pack sizes and prices decided (section 4).
- [ ] RC published to the private experience with `LiveTestMode = true`, so test purchases land in `_LIVETEST`.
- [ ] **(Your approval, real Robux.)** One purchase of the cheapest pack, then check the following.
  - Coins arrive, *Delivered* shows, and F9 → Server has no `[Monetization]` warnings.
  - Leave and rejoin: the coins are still there.
  - Buy, then immediately leave mid-window: the coins arrive on rejoin, exactly once.
- [ ] If the pass is in scope: buy it, check +4 slots, rejoin, and confirm it's still +4 and not +8.
- [ ] Your explicit go-ahead. Then `PurchasesEnabled = true` goes into the **release** build (`LiveTestMode = false`).

Test purchases in live-test mode credit coins to the `_LIVETEST` save. When the game launches with `LiveTestMode = false`, those coins won't be in your real save. The pass, which is stored on Roblox, does carry over.
