---
related-code:
  - "[[DodgeService.luau]]"
  - "[[SalvageLog.luau]]"
  - "[[CharacterAnims.luau]]"
domain: data
type: guide
status: wip
tags: [storm-salvage, data, v4]
---

# RC9 candidate (V4 M2): built and inspected, not deployed

**Build:** `rc-20261014-9` at commit `8ccc3ff` on `v4-gameplay`, from the CI release-candidate run.
- `main` is unchanged (`0ef9465`).
- The published RC8 (place version 142) is untouched.

**File:** `StormSalvage-rc-20261014-9-8ccc3ff.rbxl`
- **Location:** `.tools/rc/` and the owner's Desktop.
- **Full SHA-256** `e897256dd2b66b53f1928c34c2bf4d6767e7cad58e202cb3f64a4e68d5f5ed97`. The CI checksum file, the downloaded artifact and the Desktop copy match.

## Inspected inside the file

- `LiveTestMode = true` (saves go to `StormSalvage_v1_LIVETEST`).
- `PurchasesEnabled = false`.
- `ProductionPlaceIds = { 99653875913460 }`.
- **61 scripts:** RC8's 56, plus `Dodge` (M2 part 1) and `MoveRules`, `SalvageLog`, `DodgeService`, `CharacterAnims`. No QA scripts; no QA attributes.
- **Assets:**
  - `ServerStorage.Assets.salvage.GoldenCore`: 19 parts, pivot at the base.
  - `ServerStorage.Assets.animations`: Dodge, CoreCarry, Celebrate KeyframeSequences.
  - The asset pivot table matches all 147 assets.
- **Tuning:** `Config.Animations` all 0 (not uploaded, so the fallbacks play). `HitGrace` 0.35, `GoldenChance` 0.15, Golden value 600.

## What's in it (vs RC8)

Everything in `V4-GAMEPLAY.md` "Milestone M2", parts 1 and 2:
- the dodge, with server authority
- fair hits under latency
- the Golden Storm Core (own model, gold carrier glow, JACKPOT pickup, GOLDEN delivery)
- the Salvage Log screen and lifetime counts
- the extraction receipt
- the three character animations (Studio preview only until uploaded)

**Save data:** additive only. `Collection.Counts` is added, and kinds already found count as 1. Nothing is removed, renamed or reset; same namespace.

## Known limitations

- **Animations:** don't play live until the owner uploads them (`docs/art/v4/ANIMATIONS.md`).
- **Not verified on hardware:** gamepad B, the touch DODGE button, phone performance, and real multi-client play (including other players seeing a dodge).
- **The movement check is coarse:** it catches teleports and gross speed hacks, not subtle speed changes. A teleport timed in the ~0.2 s before a hit resolves can be judged mid-slide.
- **The lag allowance uses `GetNetworkPing()`** (capped at 0.25 s). The largest value applied per session is in the session report (`StrikeLagAllowanceMs`), to check on real servers.
- **Fun:** not claimed. The scripted runner extracted, but was often caught soon after grabbing; whether the chase is fair to people is for the playtest.

## Deploying it (needs the owner's approval first)

The same procedure as RC8 (`RC8-DEPLOYMENT.md`):
1. Record the current version as the rollback target. RC8 is **version 142**.
2. Open this exact file in Studio and publish it to the private place `99653875913460`.
3. Verify the published scripts against this file.
4. Shut down the old servers.

**Nothing has been published.**
