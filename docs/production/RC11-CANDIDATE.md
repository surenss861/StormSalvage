---
related-code:
  - "[[BigMoney.luau]]"
  - "[[Wallet.luau]]"
domain: data
type: guide
status: wip
tags: [storm-salvage, data, v4]
---

# RC11 candidate (exact extreme-number money): built and inspected, not deployed

**Build:** `rc-20261014-11` at commit `fa8b20f` on `v4-gameplay`, from the CI release-candidate run.
- RC10 stays frozen; RC9 stays the approved private-test candidate.
- RC8 (place version 142) stays published and is the rollback target.
- `main` is unchanged.

**File:** `StormSalvage-rc-20261014-11-fa8b20f.rbxl`
- **Location:** `.tools/rc/` and the owner's Desktop.
- **Full SHA-256** `b1cad21220d701cf84dc335c4e8946b9d82f788f7cf3c2aa455582debd2ca24d`. The CI checksum, the download and the Desktop copy match.

## Inspected inside the file

- **Flags:** `LiveTestMode = true`, `PurchasesEnabled = false`, `ProductionPlaceIds = { 99653875913460 }`.
- **67 scripts:** RC10's 66, minus `Money`, plus `BigMoney` and `Wallet`. No script calls the old `Money.grant`. No QA scripts or attributes.
- **Money:** `BigMoney.MAX_DIGITS = 303`, `Wallet.SCHEMA = 2`.
- **Assets:** all of M2's and M3's (Golden Core, industrial models, animations); the pivots match all 151 assets.

## Deploying it changes saved data (owner gate)

The first load by this build converts a profile to schema 2: exact money strings in `Wallet`, with the numeric fields kept as a legacy mirror.
- **Rolling back to RC8, RC9 or RC10 is supported:** they work on the mirror, and their changes are folded back in on roll-forward (tested with RC10).
- **The exception:** earnings past 1 Qa made *while rolled back* to RC10 are lost.

**Before production, follow `V4-BIG-NUMBERS.md` §3:**
1. **Rehearse** on LIVETEST, including a rollback to RC8 and a roll-forward.
2. **Verify** the DataStore version restore on a LIVETEST key.
3. **Keep** the rollback window short.

## Known limitations

- **Not re-run here:** forced shutdown mid-save and stale-lock takeover. The locking code is unchanged; re-run them in the LIVETEST rehearsal.
- **Earlier limitations still apply:** RC9 and RC10 limitations (animations, devices, multiplayer, bands 3+ designed only).

**Nothing has been published.**
