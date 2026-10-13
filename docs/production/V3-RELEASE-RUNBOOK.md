---
related-code:
  - "[[Config.luau]]"
  - "[[Environment.luau]]"
domain: data
type: guide
status: stable
tags: [storm-salvage, data]
---
# Storm Salvage V3: staging, release and rollback runbook

For whoever publishes Storm Salvage. Nothing here is automatic: every publish, merge and purchase
change is a deliberate step by the owner. Steps marked **(owner)** need your Roblox account.

## 0. Environments (how data is kept apart)

There is **no staging experience** (owner decision, 2026-10-13). Pre-launch testing happens in the existing **private** live experience: place `99653875913460`, experience `10769947641` (confirmed by the owner).

The server decides at startup (`src/shared/Environment.luau`, unit-tested) and logs one line, e.g.
`[Environment] Production (listed production place, LIVE TEST namespace (real saves untouched)), place 99653875913460, store StormSalvage_v1_LIVETEST`.

| Where the server runs | `Config.LiveTestMode` | Data store | Real saves |
| --- | --- | --- | --- |
| Any Studio session, any place | any | `StormSalvage_v1_STUDIO` | Never opened |
| Live place, pre-launch testing | `true` (current) | `StormSalvage_v1_LIVETEST` | **Never opened** |
| Live place, public release | `false` | `StormSalvage_v1` (real player data) | Used |
| Any other place | any | **None** (temporary profiles, nothing saved, receipts refused) | Never opened |

## 1. Data isolation in the private live experience

1. **Separate namespace.** Every RC published for testing has `Config.LiveTestMode = true`. Testers' progress lives only in `StormSalvage_v1_LIVETEST` and its `_Purchases` store. Your existing progression in `StormSalvage_v1` is not opened, read or written, so it can't be modified or reset by testing.
2. **Check before every test session.** F9 → Server must show `store StormSalvage_v1_LIVETEST`. If it shows `StormSalvage_v1` with no LIVE TEST, **stop**: that build is a release build.
3. **No destructive tests live.** Fault injection, lock attacks, profile padding and planted locks exist only in Studio (`DebugService` doesn't run outside Studio) and only touch `_STUDIO`. They are never run in the live experience.
4. **At launch.** The release build sets `LiveTestMode = false`, and players then load their real `StormSalvage_v1` saves. Test-session progress stays in `_LIVETEST` and does not carry over. That is intended, and testers should be told.
5. **Guard.** A `release-*` tag runs `tools/ci/release-gate.sh`, which fails while `LiveTestMode` is `true` or the live place ID differs. RC tags (`rc-*`) don't run the gate, because RCs are test builds.

## 2. Make a release candidate

1. Everything to release is on `v3-art-direction` and CI is green on that commit. Test RCs keep `LiveTestMode = true`.
2. Tag it: `git tag rc-20261013-1 <sha> && git push origin rc-20261013-1`.
3. **Release candidate** workflow (`.github/workflows/release-candidate.yml`):
   - reruns all checks and the unit tests
   - builds `StormSalvage-rc-…-<sha>.rbxl` plus its SHA-256
   - stores it as a build artifact for 90 days

   Download it from the run page. It never publishes.
4. Record in the tracker the RC tag, commit, artifact SHA-256 and the staging place version it was published as.

Tags are the trigger. The workflow's "Run workflow" button only appears once the workflow file is on `main`, and `main` is untouched until approval.

## 3. Private live-experience test pass (before anything goes public)

The exact scripts and evidence templates are in `V3-PRELAUNCH-TEST-PLAN.md`. They now run in the private live experience on the `_LIVETEST` namespace, starting with the smoke test after every publish (§0).

**Publishing an RC for testing (owner approval each time):**
1. Note the current place version (Version History) as the rollback target.
2. Open the RC `.rbxl` and use File → Publish to Roblox, choosing the existing Storm Salvage experience, which stays **private**.
3. Join, open F9 → Server, and confirm `LIVE TEST` and `StormSalvage_v1_LIVETEST`.

## 4. Public release (owner, only with explicit approval)

1. **Note the rollback version.** Creator Hub → the live experience → place → **Version
   History**, and write down the current version number. That is the rollback target.
2. **Check the data format.** Confirm that the RC doesn't change the saved-data shape (`DataService.default`, `Version = 1`). V3 so far adds no fields that old servers can't read: `reconcile` fills missing fields, and old code ignores extra ones.
3. **Build the release.** Set `Config.LiveTestMode = false` in one commit, then tag `release-YYYYMMDD-N`. The Release workflow runs the gate and the checks and builds the `.rbxl`.
4. **Publish.** Publish that release `.rbxl` and confirm F9 shows `store StormSalvage_v1` (no LIVE TEST). Then make the experience public, but only with approval.
5. **Watch the first public server** (section 6) for 30 minutes.
6. **Merge.** Merge `v3-art-direction` into `main` via a pull request (branch protection requires CI) only after the release is accepted. `main` must always match what is live.

## 5. Roll back

**Trigger:** any of the section 6 stop signals, a crash or join failure, or data being wrong. In the pre-launch phase a rollback only ever affects `_LIVETEST` data.

1. **Revert the place.** Creator Hub → live place → Version History → **Restore** the version noted in 4.1. New servers start on the old version immediately.
2. **Clear old servers.** Use the experience's **Shut Down All Servers** (or "Migrate to Latest Update") so no server keeps running the bad build. Players rejoin into the restored version, and `BindToClose` saves every profile with its lock released before shutdown (Studio-measured: the release lands within about 5 s).
3. **Data stays compatible.** Rolling back V3 → V2 needs no data migration, because both use `Version = 1`.
   - If a future release changes the data shape, that release must ship its own reader for the old shape *before* any rollback is possible. Add a check to this runbook at that point.
4. **Purchases are safe.** Every grant is durable in the profile before Roblox is told PurchaseGranted, and receipt IDs are never pruned, so a rollback can't double-grant or lose a purchase.
5. **Afterwards.** Revert or fix on the branch, make a new RC and go through staging again. Don't hot-patch the live place from Studio.

## 6. Monitoring a live or staging server

| Signal | Where | Normal | Stop and investigate |
| --- | --- | --- | --- |
| `[Environment] …` | Server log at start | `_LIVETEST` while testing; `StormSalvage_v1` after release | `NONE`, or the wrong store for the phase |
| `[DataService] save failed` | Server log | Rare and isolated | Repeating, or across many players (DataStore outage) |
| `profile locked by another server, retrying` | Server log | Occasional, during server hops | Players kicked with "Couldn't load your save data" more than once per hour |
| `[Monetization] receipt error` / `no handler for product` | Server log | Never | Any |
| `[ClientDiag] … view lost` / analytics `ViewLost_*` | Server log, Creator Hub Analytics | 0 | Any recurring pattern (camera lost after death) |
| Funnel `FirstPickup` → `FirstSale` → `FirstUpgrade` | Creator Hub Analytics | Matches the playtest | A step drops sharply after a release |
| Crash, join failure and memory | Creator Hub → Analytics → Performance | Within the `V3-PERFORMANCE-BUDGETS` gates | Any regression versus the previous version |

## 7. Things that are not allowed without the owner's explicit go-ahead

- publishing to the live experience
- making either experience public
- merging to `main`
- putting real product or game-pass IDs into `Config`
- changing `ProductionPlaceIds`
- setting `LiveTestMode = false`, which switches the live place to real player data
- running destructive tests against `StormSalvage_v1` (live) profiles
