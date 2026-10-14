---
related-code:
  - "[[PendingRewards.luau]]"
  - "[[RewardClaims.luau]]"
  - "[[Leaderboard.luau]]"
  - "[[Onboarding.luau]]"
domain: release
type: guide
status: wip
tags: [storm-salvage, release, v4]
---

# RC13: the V4 feature-freeze candidate (built and inspected, not deployed)

**Build:** `rc-20261014-13` at commit `be74045` on `v4-gameplay`, from CI release-candidate run 38561205179.
- RC8 (place version 142) stays published privately and is the rollback target.
- `main` is unchanged.
- Nothing was published or migrated.
- The DataStore rehearsal stays paused at B0.

**File:** `StormSalvage-rc-20261014-13-be74045.rbxl` (742,443 bytes)
- **Location:** `.tools/rc/rc-20261014-13/` and the owner's Desktop.
- **Full SHA-256:** `357b0cfaac6566ae5b552139dbf889556fa7c77eb70fdc09b1036d7ca3bcd83f`. The CI checksum, the download and the Desktop copy match.

**This is the last feature build.** From here: stabilisation, and real multiplayer and device QA (see the list at the end).

## Inspected inside the file

**Flags:**
- `LiveTestMode = true`.
- `PurchasesEnabled = Catalog.PurchasesEnabled = false`.
- Every product and pass id is 0 (`catalog.spec`).
- `ProductionPlaceIds = { 99653875913460 }`.

**Scripts:** 89. No QA scripts, QA-named instances or bot code.
- The only QA-named module is `QASeed`, which reads its seed only in Studio.
- `DebugService` ships inert: `init` returns unless `RunService:IsStudio()`, so the debug BindableFunction never exists on a server.

**Every test hook is Studio-gated or only reachable through DebugService** (audited by search):
- `failNextForTest`, `useStoreForTest`, `QA_ProfileStore`, `spawnForTest`, `addXPForTest`, `qaStress`;
- client `QA_PhoneFrame`, `QA_Sprint`, `QA_OwnPlate`, `QA_Ping`.

**World:** the CI world manifest passes (43 checks: every spawned model and district builder is present). The pivots match all 162 assets.

**Checks:**
- stylua, selene and luau-lsp are clean;
- 152 unit tests pass;
- `rojo build` succeeds.

## What's in it (since RC12, 34 commits)

### M4 and M5
- Bands 3–5:
  - **Storm Hunter:** the Storm's Eye.
  - **Heavy Salvage:** the Armored Wreck.
  - **Storm Legend:** the Storm Titan and Mythic Cores.
- Rail Yard, Flood Control Works, Ballpark and Pine Rest districts.

### A. Cooperative rewards
- Work is counted per user id.
- Shares are owner-only drops. Absent contributors' shares are **held**, never handed to anyone else:
  - stored in `<store>_Pending`;
  - at most 20 per player, each lasting 72 h;
  - paid on rejoin at the owner's own Press, in one profile write that also records the claim id, so each share pays exactly once.
- **Unit tests:** `coop.spec` and `pendingrewards.spec`.
- **Studio:**
  - an absent 67% contributor got 3 bars and the Crown Jewels held;
  - the rejoin paid exactly +13,050,000 at Press ×3;
  - a replayed id paid nothing.
- Details: `V4-COOP.md`.

### B. Leaderboards
The top N is exact, ties included.
- **Method:** a monotone index, plus a scan of the cutoff's whole tie group (`GetSortedAsync` by exact value).
- **Unit test:** a 150-way adversarial tie, more than the page or any shortlist, proves the method and shows a shortlist would be wrong.
- **Studio, real OrderedDataStore:** a 40-way tie gave the exact top 10 in 3 reads.
- **Bounds:** if the cutoff tie group passes 500 entries or the read budget runs out, the result is marked not exact. The board then shows "Huge tie at the cutoff: order near the bottom may vary" instead of presenting it as exact.
- Details: `V4-LEADERBOARDS.md`.

### C. M6: storm and event presentation
- Storm-specific lighting and grading.
- Readable lightning warning rings.
- A brown/sand rogue twister with an amber band that flashes on wind-up, and its own whirl sound.
- Titan roar, hum and inhale; Wreck alarm and vault burst.
- Tiered rare-loot effects.
- Reduced Effects variants, spatial audio and a Music group.
- Procedural pose fallbacks until the authored animations are uploaded.
- All sound ids are real Creator Store assets. None are fabricated.

### D. M9: menus and onboarding
**Arcade theme menus:**
- **Gear Shop:** an upgrade track lists every level's effect and price, with the next level in focus.
- **Salvage Log:**
  - rarity filters;
  - silhouettes for kinds not yet found;
  - a detail panel with a turning 3D view.
- The Salvager ID and its trophy case.

**Phone pass (Studio phone frame, 844 × 390 pt):**
- Every visible control on every menu tab measures ≥ 44 pt.
- Supply cards, Settings rows and the Salvage Log filter were reworked for phones.
- Settings contrast was fixed. A Music fader tap set the Music group to 0.25.
- Modal priority: opening one menu closes the other. B and Backspace close.

**Onboarding:** a fresh, disposable profile was played to the Pro licence with no granted rank, coins, licences or extractions.
- The player was a client-input-only bot (`tools/qa/onboarding-bot.luau`).
- The licence was bought by hand through the real Tools tab.
- It persisted across a rejoin, and the ledger is exact.
- Details: `V4-ONBOARDING.md`.

## E. Integrated checks on this code

**Bands 1–5 in Studio:** the full sequence ran with **0 server and 0 client errors**:
- Wind, Flood and Lightning storms;
- three rotating post-storm events;
- the Storm's Eye, the Armored Wreck and the Storm Titan.

**Heaviest combination:** a Lightning storm, Titan, Eye and Wreck at once, sampled for 30 s.

| Measure | Result |
| --- | --- |
| Server heartbeat | 60.0 Hz |
| Median step | 16.7 ms |
| p99 step | 17.5 ms |
| Worst step | 34.7 ms |
| Enabled particle emitters | 19 |

The HUD stayed readable: the Titan card, the Wreck and Cores pills and the job objective.

**Client frame rate is not measured:** Studio caps the client at about 15 fps here.

**Persistence and compatibility:**
- **Reconcile:** fills missing keys two levels deep (for example `Stats.StormsSeen`) and keeps unknown ones.
- **`ClaimedRewards`:** optional; absent means nothing claimed.
- **Money rollback:** across RC8, RC9 and RC10 it remains covered by `rollback.spec` (600 random chains) and `restore.spec`.
- **Saves:** no save format change since RC12 besides the additive fields above.

**Security:**
- Purchases, rewards, coop shares and leaderboard amounts are decided on the server.
- The client sends only intents: buy, hold a prompt, dodge.
- New in this candidate: client UI, and Studio-only QA switches that fail safe.

## Owner gates (unchanged)

These still need the owner, in this order:
1. Deployment approval.
2. The LIVETEST migration rehearsal: Stage B, paused at B0 (`MONEY-REHEARSAL.md`).
3. Uploading the authored animations.
4. Any decision to enable purchases.

## Not verified: needs real devices or real servers

These were **not** tested and must not be read as passed.

**Devices**
- **Real phones and tablets:** thumb reach, the notch and safe areas, and the dynamic thumbstick overlapping open menus. The 44 pt numbers come from the Studio frame.
- **A real controller:**
  - gamepad focus order on hardware;
  - ButtonB to close (Studio's virtual input can't send it);
  - the d-pad across the menu grids.
- **Client frame rate and memory on low-end phones** with the heaviest storm and event combination, and Reduced Effects on those devices.
- **Audio on real speakers and headphones:** the music and effects mix, and spatial falloff.

**Servers and multiplayer**
- **Real multi-client coop:**
  - Wreck and Titan shares split across players;
  - real disconnects mid-event;
  - rejoining on a *different* server to claim a held share;
  - two servers claiming at once.
- **Leaderboards under live load:** write budgets with many servers, OrderedDataStore throttling, and weekly rollover on a real clock.
- **DataStore failure modes on live servers:** throttling, forced shutdown mid-save, and stale-lock takeover. These were tested in Studio earlier, not re-run here.
- **Event pacing for real people:**
  - whether new players reach a 25 s event cache in time (the bot needed to sprint);
  - whether the Wreck's crew bonus and the Titan's pull feel fair.
- **A real new player's first session**, as opposed to a bot following the guide.
