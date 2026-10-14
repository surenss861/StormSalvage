---
related-code:
  - "[[ContractService.luau]]"
  - "[[Nameplates.luau]]"
  - "[[PlateStyle.luau]]"
  - "[[Progression.luau]]"
domain: progression
type: spec
status: draft
tags: [storm-salvage, progression, v4]
---

# V4 Status and prestige (design; first slice built)

> **2026-10-14 update (M3):** nine earned titles (not three), the nameplate title and the player
> card are built. See [`V4-M3.md`](V4-M3.md). The card opens by tapping or clicking a character
> (a raycast), not the billboard, because billboards on characters can't take input.

**The goal:** players feel successful, wealthy and recognisable, and other players can see it, without cluttering the screen. This builds on what exists:
- the 7 Salvager ranks (Scrap Rookie → Storm Legend)
- nameplate finishes as materials (PlateStyle)
- the overhead nameplate (name, rank title, finish)
- `Stats.TotalEarned` (lifetime earnings, already saved)
- V4 `Records` (extractions, best extraction time)

## The five status types (proposal)

| Type | What it shows | Source of truth | When |
| --- | --- | --- | --- |
| **Wealth** | Lifetime-earned milestones: First Fortune (1M), Billionaire (1B), Storm Tycoon (1T). Kept after spending. | `Stats.TotalEarned`, server only | With the V4 economy bands |
| **Earned titles** | E.g. **Stormbreaker** (first extraction), **Untouchable** (10 extractions without being caught), **Quick Hands** (extraction under 12 s) | `Records` + event outcomes, server only | **First slice** |
| **Inspect card** | Tap or click a player: rank, chosen title, lifetime earned (compact), extraction count and best time, equipped finish | Server sends a public summary on request | **First slice** |
| **Leaderboards** | All-time lifetime earned and extractions, plus **weekly** boards so newcomers can compete | OrderedDataStores; weekly keys (`week_2026_42`) | After the economy is stable |
| **Trophy garage / crews** | Personal display; crews with shared records | Large systems | Later; not before the chase is proven |

## On-screen rules

- **Overhead:** name, **one chosen title**, the finish. Nothing more at normal distance.
- **Everything else** goes on the inspect card: wealth, records, badges.
- **Achievement moments:** the existing notification card style, once per unlock.

## Integrity rules

- **Server-only.** Titles, wealth milestones and records are computed and granted only on the server, from server-verified events. Clients can only choose which owned title to show, the same pattern as equipping a finish.
- **Never for sale.** Titles, leaderboard places and wealth records can't be bought. The Robux side sells *expression*: premium finish styles, trails, outfits, auras. Those are clearly separate from earned prestige, and an earned title can't be faked by a cosmetic.
- **Existing ranks and owned finishes are preserved** exactly.

## Data and budgets

- **New profile fields** (reconciled on load; older code keeps them):
  - `Titles = { Owned = {}, Shown = nil }`
  - `Records` (exists from V4)
- **Leaderboards (later):**
  - OrderedDataStore writes only on leave and autosave, at most one per board per player per save.
  - Reads cached server-wide and refreshed every 2–5 min, within DataStore request budgets.
  - Weekly boards use one new key per week; old weeks are read-only.
- **Numbers:** wealth uses the integer rules in `V4-ECONOMY.md` (capped below 2^53) and the compact formatter for display.

## Proposed first vertical slice (after the pursuit review)

1. **Three earned titles** from the pursuit (Stormbreaker, Untouchable, Quick Hands):
   - granted server-side
   - one shown under the name on the nameplate
   - chosen in the Jobs board's locker, where finishes are already chosen
2. **An inspect card:**
   - a ProximityPrompt-free tap on another player's nameplate (click detector on the billboard)
   - the server returns a small public summary: rank, title, extractions and best time, lifetime earned in compact form, finish
3. **Tests:**
   - titles can't be granted by a client
   - the card shows only public fields
   - a rollback to RC7 keeps `Titles`
   - nameplates stay readable on a phone at normal distance

Leaderboards, wealth milestones, the garage and crews wait until the V4 economy is reviewed and the chase is proven fun.
