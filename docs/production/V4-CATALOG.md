---
related-code:
  - "[[Catalog.luau]]"
  - "[[MonetizationService.luau]]"
  - "[[SupplyCounter.luau]]"
  - "[[Progression.luau]]"
domain: salvage-economy
type: spec
status: wip
tags: [storm-salvage, monetization, v4]
---

# V4 premium catalogue (designed and plumbed, switched off)

Owner's rules:
- Robux stays disabled until final validation and explicit approval.
- Entitlements stay server-authoritative.
- RC3+ receipt safety is preserved.
- Earned prestige stays separate from paid cosmetics.

All of the catalogue data lives in `src/shared/Catalog.luau` (pure data, unit-tested). `Config` re-exports it.

## Items

| Item | Kind | What it gives | Shown | Planned R$ |
| --- | --- | --- | --- | --- |
| Pocket Change / Scrap Bundle / Salvage Haul | Developer product | 300 / 1,200 / 3,000 coins | Always | 29 / 99 / 199 |
| Industrial Crate | Developer product | 1,000,000 coins | Bands 2–3 | 299 |
| Hunter Cache | Developer product | 80,000,000 coins | Bands 3–4 | 499 |
| Vault Haul | Developer product | 50,000,000,000 coins | Bands 4–5 | 799 |
| Legend Hoard | Developer product | 3,000,000,000,000 coins | Band 5 | 999 |
| Heavy-Duty Pack | Game pass | +2 bag slots (session entitlement) | Always | 149 |
| Neon Storm / Gilded Wreck nameplate | Game pass | A supporter nameplate finish | Always | 99 each |

Prices are planned. The price players pay is the one set on the Creator Hub, read live via `GetProductInfo`.

## Rules (enforced)

- **Off:**
  - `PurchasesEnabled = false`.
  - Every product and pass `Id = 0` in the repo, so nothing is on sale. The UI says "not on sale yet".
  - Activation is an owner step (create the products, set the ids, flip the switch) after final validation.
- **Fixed amounts:**
  - Every pack grants the same whole number of coins whoever buys it. It is never computed from the buyer's band or state.
  - Receipt retries, duplicate callbacks and profile restores are therefore exact. `RestorePlan` re-applies by product id.
  - The RC3+ invariant is untouched: the PurchaseId and its reward are written in one UpdateAsync.
- **High-scale packs, not band-scaled packs:**
  - The bigger packs are separate fixed products, shown only from the band where they matter.
  - Each is at most about 30% of that band's whole gear track (catalog test), the same rule the owner set for band 1.
- **Purchases are cash, never earnings:**
  - `Wallet.deposit` adds cash but not lifetime earned.
  - Bought coins never count toward wealth titles, lifetime earned, net worth from earnings, or either leaderboard (leaderboard test).
- **Supporter finishes (paid cosmetics):**
  - Robux only. `canBuyFinish` refuses them for coins (test).
  - Ownership is Roblox's record, checked each session, and is never written to `Cosmetics.Owned`.
  - They add nothing to net worth (Cost 0) and have no rank gate.
  - The equipped finish shows only while the pass is confirmed. It is listed under SUPPORTER on the Nameplate tab.
- **Earned prestige is never for sale:**
  - Titles come only from records, licences, finds and lifetime earnings (test: a view with no achievements earns none).
  - The Salvager ID's badges are titles.
- **Server-authoritative:**
  - The client only opens Roblox's purchase window.
  - Coins are granted only in `ProcessReceipt`.
  - Passes are granted from `UserOwnsGamePassAsync` or the server-side `PromptGamePassPurchaseFinished`.

## Not done (owner gates)

- Creating the products and passes on the Creator Hub.
- Live purchase testing.
- The activation decision.
