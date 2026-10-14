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
| 7 | Work toward the next licence | Until the Pro licence | (the Supply Counter checklist) |

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

**Not verified:** a real new player's first session. Bots follow the guide perfectly; people don't.
