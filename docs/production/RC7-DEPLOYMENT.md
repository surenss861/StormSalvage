---
related-code:
  - "[[DetectorService.luau]]"
  - "[[Environment.luau]]"
domain: data
type: guide
status: wip
tags: [storm-salvage, data]
---

# RC7 private deployment

**Build:** `rc-20261013-7` at commit `e3d1ab9`, approved by the owner for **private** deployment on 2026-10-13.
- Live-test mode stays on and Robux purchases stay off.
- No public release and no merge into `main`.

**File:** `StormSalvage-rc-20261013-7-e3d1ab9.rbxl`
- SHA-256 `61c51a90eeb727da8702dac833140391bfe0d030c2dcbe685ffcf262f270e097`
- A copy is on the owner's Desktop, with the same checksum.

## Rollback target (recorded before publishing)

Version History, published only (`evidence/rc7-rollback-version-history.jpg`):
- **Rollback target: version 124**, RC6, published October 13 at 2:59 PM local.
- Earlier published versions: 122 (RC5), 121 (an untagged build, superseded) and 2 (the October 8 build).
- Versions 125–132 are unpublished saves from the Studio testing window. They aren't live; don't restore them.

**To roll back:** open version 124 in Studio, publish it to place `99653875913460`, then Shut Down All Servers.

## Steps

1. ✅ Record the rollback version (124).
2. ✅ Verify the artifact: CI build, SHA-256 matched on the Desktop copy, and contents inspected (`V3-SUPPLY-DEPOT.md`, RC7 artifact).
3. Owner: close the old Studio window without saving, then open the RC7 file from the Desktop.
4. **Before publishing:** I playtest that exact window. It must log `[AssetPivotFix] 146 asset pivots restored`, show the Tools tab and the detector working, and match the artifact's 51 scripts.
5. Owner: Publish to Roblox As… → **Storm Salvage** (existing experience) → place **Storm Salvage** (`99653875913460`) → overwrite.
6. Me: confirm in Version History that a new version is published, and that the experience is still Private.
7. Owner: smoke test: collect, sell, earn and **buy the Salvage Detector (2,500 coins)**, see the dial, leave, rejoin, still owned.
8. Me: read the saves without changing anything. `_LIVETEST` should have the detector and the coins; the real save should be untouched.
