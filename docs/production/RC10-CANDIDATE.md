---
related-code:
  - "[[Money.luau]]"
  - "[[Bands.luau]]"
  - "[[StatusService.luau]]"
domain: data
type: guide
status: wip
tags: [storm-salvage, data, v4]
---

# RC10 candidate (V4 M3 first slice): built and inspected, not deployed

**Build:** `rc-20261014-10` at commit `53fe778` on `v4-gameplay`, from the CI release-candidate run.
- RC9 (`8ccc3ff`) stays the owner-approved private-test candidate. RC8 (place version 142) stays published and is the rollback target.
- `main` is unchanged.

**File:** `StormSalvage-rc-20261014-10-53fe778.rbxl`
- **Location:** `.tools/rc/` and the owner's Desktop.
- **Full SHA-256** `a5c9a429cfec12f1ea5c129ed3572cc2e22f5bbc74cf23047afadf52e63a8dad`. The CI checksum, the downloaded file and the Desktop copy match.

## Inspected inside the file

- `LiveTestMode = true`, `PurchasesEnabled = false`, `ProductionPlaceIds = { 99653875913460 }`.
- **66 scripts:** RC9's 61, plus `Bands`, `Money`, `Titles`, `StatusService`, `PlayerCard`. No QA scripts or attributes.
- **Assets:**
  - salvage models CopperSpool (8 parts), HydraulicPump (14), DieselGenerator (18), TurbineRotor (17), GoldenCore (19)
  - the three animation KeyframeSequences
  - the pivot table matches all 151 assets
- **Tuning:** `Config.Animations` all 0 (not uploaded), Pro licence 5,000, `Money.MAX` 1e15.

## What's in it

See [`V4-M3.md`](V4-M3.md): safe money and formatting, bands 1–2, titles and the player card.
- **Save data:** additive only (`Licenses`, `Titles`, `Upgrades.Press`, `Records.GoldenExtractions`).
- **Rollback:** RC9 code was tested loading and re-saving an M3 profile without losing them.

## Known limitations

- **Pacing:** milestone times are simulated, not measured with real players.
- **Bands 3–5:** designed only.
- **Not verified on hardware:** phones (tap-to-inspect, dodge button), controllers and real multiplayer.
- **Animations:** still need the owner's uploads; the fallbacks are active.
- **The ping allowance needs a real-server check** (`V4-M3.md` §7).
- **Rolling a band-2 player back** to RC9 or RC8 leaves an unspendable-feeling balance until roll-forward (`V4-M3.md` §6).

**Nothing has been published.**
