---
related-code:
  - "[[Onboarding.luau]]"
  - "[[OnboardingGuide.luau]]"
  - "[[LootService.luau]]"
domain: progression
type: spec
status: wip
tags: [storm-salvage, onboarding, ux, v4]
---

# V4 onboarding: learn by playing

There is no tutorial screen. The objective note shows the next thing to learn. A guide (a chevron at your feet and a marker with the distance over the target) points at where to go. Each lesson comes from your saved progress, so a rejoin carries on where you were. Urgent moments interrupt the loop and hand back to it afterwards.

| # | Lesson | Shown when | Points at |
| --- | --- | --- | --- |
| 1 | Grab glowing salvage | Nothing sold, bag empty | Your welcome find, else the nearest takeable salvage in town |
| 2 | Fill and sell your bag | Carrying, nothing sold yet | More salvage, or the Scrap Buyer once full |
| 3 | A storm is coming: shelter | A storm, and no storm seen yet | The Scrapyard |
| 4 | Join an event | An event is live, after the first sale, before any extraction or rush find | The event's beam |
| 5 | Escape with the core | Carrying a core, before the first extraction | The Scrapyard |
| 6 | Spend your earnings | First sale done, no gear bought | The Gear Shop once affordable |
| 7 | Work toward the next licence | Until the Pro licence | (the Gear Shop Tools tab checklist) |

After lesson 7 the note shows the pinned job.

**The first reward comes fast.** A new player (nothing sold yet) gets a glowing Jukebox, worth 140 coins, waiting just past the foot of the ramp. It's owner-only, so only they can take it. Selling it alongside two scraps pays for the first Backpack.

**Fixes made while playing it:**
- The welcome find was first under the ramp, unreachable from it.
- The guide pointed at "nearest" loot below the plateau cliffs. From the plateau it now points into town.
- The storm lesson keyed on "storms survived in town", so a player who sheltered safely would have been nagged forever. It now uses a new `Stats.StormsSeen` counter.
- A Studio QA session with saving off left its profile locked. A no-save session now releases the lock without writing (`DataService.releaseOnly`).

**Evidence:**
- Unit tests (`onboarding.spec.luau`): the loop in order, storm and core interruptions, events after the first sale, and every step's target known.
- Studio, as a fresh player (Studio-only `freshplayer`: saving off, profile untouched):
  - Collect: guided from spawn to the find in 8 s and picked it up.
  - Sell: guided to the Scrap Buyer and sold.
  - A natural storm interrupted with the shelter lesson.
  - Spend: guided to the Gear Shop, bought the Backpack through the UI (bag 3 → 5).
  - The licence lesson followed.
  - Screenshots: `docs/art/v4/onboarding/`.

## No-shortcut run: fresh profile to the Pro licence (Studio, 2026-10-14)

**What was tested.** A brand-new profile played from nothing to the first licence, with no granted rank, coins, licences or extractions.
- **The profile.** The Studio-only ServerStorage attribute `QA_ProfileStore` points the session at a new, empty, disposable store, `StormSalvage_v1_STUDIO_REHEARSAL_OB1`. It only accepts rehearsal-prefixed names and fails safe with a warning. The paused DataStore rehearsal's stores and real profiles were never touched.
- **The player.** A scripted client, `tools/qa/onboarding-bot.luau`, which never ships (tools/ is outside the Rojo tree). It does only what a player's client can do:
  - walk at the character's own speed;
  - hold the real prompts, so the server's distance and hold-time checks apply;
  - fire the Gear Shop's own remotes;
  - sprint through the Studio-only `QA_Sprint` attribute, standing in for holding Shift.
- **The licence purchase** was done by hand through the real Gear Shop Tools tab.

**What happened** (about 65 minutes of play, 28 storms):

| Clock | Milestone |
| --- | --- |
| 0:00 | Fresh profile: 0 coins, 3-slot bag. The objective was "Grab glowing salvage in town." A windstorm arrived at once, and the shelter lesson took over. |
| ~1 min | First sale; first Backpack bought (50). |
| ~12 min | Rank 3 (Salvager) passed through finds, contracts and sales. |
| ~23 min | First event core extracted (Extraction, Pine Rest). |
| ~62 min | Second extraction (a Storm Pursuit, twister chasing). |
| ~65 min | Third extraction (Extraction). |
| ~65 min | Requirements panel: both DONE. Bought the licence: "Pro Salvage License earned!", PRO tag, Professional title. |

**Persistence and the ledger.**
- Stopping and restarting Play reloaded the profile with the licence, 1,105 coins and the 14-slot bag. The guide had finished: the objective slot showed the pinned job.
- The ledger is exact. Lifetime earned was 10,080. Spending was 8,975:

  | Item | Coins |
  | --- | --- |
  | Backpack | 1,600 |
  | Boots | 1,025 |
  | Armor | 1,350 |
  | Pro licence | 5,000 |

  That leaves 1,105, matching the balance.

**Screenshots** (in `docs/art/v4/onboarding/`):
- `fresh-profile-start.jpg`
- `pro-requirements-done.jpg`
- `pro-licence-bought.jpg`
- `after-rejoin-pro.jpg`

**Found and fixed during the run:**
- The licence lesson sent players to "Gear Shop · Supply Counter" (the Robux tab). It now says "Gear Shop · Tools".

**Observed, not changed:**
- The bot missed several event races at first. Each cache disappears 25 s after it appears (`ClaimSeconds`), and events start right after a storm, when the player is up on the Scrapyard and ordinary Storm Cores are lying in town. Once it dropped everything and sprinted, it made the 375-stud race comfortably.
- A human who knows to sprint at the beam should make it. Whether a new player does is a question for real playtests.
- Three of the ~65 minutes were spent waiting on an Extraction event, since sites and kinds rotate.

**Not verified:** a real new player's first session. Bots follow the guide perfectly; people don't.
