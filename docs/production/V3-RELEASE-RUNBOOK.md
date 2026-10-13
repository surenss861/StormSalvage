# Storm Salvage V3: staging, release and rollback runbook

For whoever publishes Storm Salvage. Nothing here is automatic: every publish, merge and purchase
change is a deliberate step by the owner. Steps marked **(owner)** need your Roblox account.

## 0. Environments (how data is kept apart)

The server decides at startup (`src/shared/Environment.luau`, unit-tested in
`tests/environment.spec.luau`) and logs one line, e.g.
`[Environment] Staging (listed staging place), place 123, store StormSalvage_v1_STAGING`.

| Where the server runs | Data store | Purchases |
| --- | --- | --- |
| Any Studio session, any place | `StormSalvage_v1_STUDIO` | Simulated only |
| A place listed in `Config.StagingPlaceIds` | `StormSalvage_v1_STAGING` | Only once real product IDs are configured and you approve |
| A place listed in `Config.ProductionPlaceIds` | `StormSalvage_v1` (live player data) | Same |
| Any other place, or a place in both lists | **None**: temporary profiles, nothing saved, receipts refused | Refused |

## 1. Set up staging (one time) (owner)

1. **Create the experience.** In the Creator Hub, Creations → **Create Experience**. Name it e.g.
   "Storm Salvage STAGING" and keep it **Private**. It must be a separate experience, not a new
   place inside the live one: DataStores are per experience, which gives a second wall around
   live data.
2. **Turn on data access.** Open the new experience's Settings → Security and enable **Studio access to API Services**.
3. **Send me two IDs:**
   - the new place ID
   - confirmation that `99653875913460` is the live place (Creator Hub → the live experience → the place's URL)

I'll then add the staging place to `Config.StagingPlaceIds`, correct `ProductionPlaceIds` if
needed, and push.

4. **Publish to staging.**
   - Open the release-candidate `.rbxl` (section 2) in Studio and use File → **Publish to Roblox As...**, choosing the *staging* experience.
   - Join it from the Roblox app and check the server log (Developer Console F9 → Server) for `[Environment] Staging ... StormSalvage_v1_STAGING`.
   - If it says `Unknown` or `NONE`, the place ID isn't listed. Nothing will save, which is the safe failure; fix the config before testing.
5. Invite testers through the experience's Collaborators or a private server, never a public link.

## 2. Make a release candidate

1. Everything to release is on `v3-art-direction` and CI is green on that commit.
2. Tag it: `git tag rc-20261013-1 <sha> && git push origin rc-20261013-1`.
3. **Release candidate** workflow (`.github/workflows/release-candidate.yml`):
   - reruns all checks and the unit tests
   - builds `StormSalvage-rc-…-<sha>.rbxl` plus its SHA-256
   - stores it as a build artifact for 90 days

   Download it from the run page. It never publishes.
4. Record in the tracker the RC tag, commit, artifact SHA-256 and the staging place version it was published as.

Tags are the trigger. The workflow's "Run workflow" button only appears once the workflow file is on `main`, and `main` is untouched until approval.

## 3. Staging test pass (before anything goes live)

The exact scripts and evidence templates are in `V3-STAGING-TEST-PLAN.md`: the smoke test after every publish (§0), 4/8/12 players (§1), devices (§2), mobile UI (§3), persistence (§4) and the rollback rehearsal (§5).

Use `docs/production/V3-RELEASE-CHECKLIST.md`. The minimum is:
- the device runs per `V3-PERFORMANCE-BUDGETS.md` B–D
- 4, 8 and 12-player sessions (section E)
- a mobile UI check on real phones
- an unfamiliar-player playtest
- if purchases are in scope, one real test purchase of each product in staging

Every result is recorded with the section I evidence fields. A blank is "NOT TESTED".

## 4. Publish to production (owner, only with explicit approval)

1. **Note the rollback version.** Creator Hub → the live experience → place → **Version
   History**, and write down the current version number. That is the rollback target.
2. **Check the data format.** Confirm that the RC doesn't change the saved-data shape (`DataService.default`, `Version = 1`). V3 so far adds no fields that old servers can't read: `reconcile` fills missing fields, and old code ignores extra ones.
3. **Publish.** Open the RC `.rbxl` and Publish to the **live** experience.
4. **Watch the first live server** (section 6) for 30 minutes.
5. **Merge.** Merge `v3-art-direction` into `main` via a pull request (branch protection requires CI) only after the release is accepted. `main` must always match what is live.

## 5. Roll back

**Trigger:** any of the section 6 stop signals, a crash or join failure, or data being wrong.

1. **Revert the place.** Creator Hub → live place → Version History → **Restore** the version noted in 4.1. New servers start on the old version immediately.
2. **Clear old servers.** Use the experience's **Shut Down All Servers** (or "Migrate to Latest Update") so no server keeps running the bad build. Players rejoin into the restored version, and `BindToClose` saves every profile with its lock released before shutdown (Studio-measured: the release lands within about 5 s).
3. **Data stays compatible.** Rolling back V3 → V2 needs no data migration, because both use `Version = 1`.
   - If a future release changes the data shape, that release must ship its own reader for the old shape *before* any rollback is possible. Add a check to this runbook at that point.
4. **Purchases are safe.** Every grant is durable in the profile before Roblox is told PurchaseGranted, and receipt IDs are never pruned, so a rollback can't double-grant or lose a purchase.
5. **Afterwards.** Revert or fix on the branch, make a new RC and go through staging again. Don't hot-patch the live place from Studio.

## 6. Monitoring a live or staging server

| Signal | Where | Normal | Stop and investigate |
| --- | --- | --- | --- |
| `[Environment] …` | Server log at start | The expected environment and store | `Unknown` / `NONE` on staging or live |
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
- running destructive tests against `StormSalvage_v1` (live) profiles
