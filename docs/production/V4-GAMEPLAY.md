---
related-code:
  - "[[Movement.luau]]"
  - "[[PursuitService.luau]]"
  - "[[Pursuit.luau]]"
  - "[[PursuitHud.luau]]"
  - "[[pursuit-runner.luau]]"
domain: world
type: spec
status: wip
tags: [storm-salvage, world, v4]
---

# V4 Gameplay: movement and Storm Pursuit (first deliverable)

**Branch:** `v4-gameplay`, cut from `v3-art-direction`.
- It's an experiment: not in any release candidate and not published.
- RC7 is untouched and stays the rollback baseline. The live private place still runs RC7.
- `main` is unchanged, and Robux purchases stay off.

The owner's V4 directives asked for one thing first: make the core play exciting, through:
- **A.** a movement prototype
- **B.** one playable Storm Core chase with a real moving threat
- **C.** the feedback those two need

Then stop for a gameplay review.

## A. Movement

| | Before (RC7) | V4 prototype |
| --- | --- | --- |
| Base speed | 16 | **Run 20, sprint 28** |
| Running Boots, levels 0–4 | 16 / 18 / 20 / 22 / 24 | Run 20 → 24, sprint **28 → 34** (+1 / +1.5 per level) |
| Sprint control | none | **Keyboard:** hold Shift. **Touch and gamepad:** sprint starts by itself after 0.45 s of steady movement; gamepad can also click the left stick. |
| Feel | instant speed | 0.22 s ease-in to sprint, instant drop back to run on stopping; field of view widens 70 → 76 while sprinting (not in Reduced Effects) |

**How it works:**
- The server sets `RunSpeed` and `SprintSpeed` on the character from the Boots level, and `Movement.client` moves `WalkSpeed` between them.
- Roblox's own controller, camera and animations stay in charge. **Nothing is sold:** sprint is free for everyone.
- Pickup distance checks are unchanged (`isNear` uses positions, not speed).
- Storm wind push still applies: it's a separate client force.

**Travel time from the Scrapyard** (real pathfinding routes, measured in Studio):

| District | Path | Old 16 | Run 20 | **Sprint 28** | Sprint, Boots max 34 |
| --- | --- | --- | --- | --- | --- |
| Town Square | 209 studs | 13.1 s | 10.5 s | **7.5 s** | 6.2 s |
| Fuel & Go | 266 | 16.7 s | 13.3 s | **9.5 s** | 7.8 s |
| Super Saver | 328 | 20.5 s | 16.4 s | **11.7 s** | 9.7 s |
| Warehouse 7 | 357 | 22.3 s | 17.9 s | **12.8 s** | 10.5 s |
| Houses | 366 | 22.9 s | 18.3 s | **13.1 s** | 10.8 s |
| Starlite Motel | 409 | 25.6 s | 20.5 s | **14.6 s** | 12.0 s |

**Takeaways:**
- Sprinting cuts every trip by about 43%.
- Boots stay useful: max Boots saves another 2–3 s per trip, and in the chase it's the difference between scraping through and escaping comfortably.
- A scripted sprint from the Scrapyard to Warehouse 7 took 13.2 s, against the computed 12.8 s.

**Not done yet:**
- **Custom animations:** Roblox's default run animation speeds up with WalkSpeed, and I have no verified animation asset IDs to add more. A slide or dash comes only after this baseline is judged.
- **Device testing:** auto-sprint on a real phone is untested.
- **Shift lock:** players who turn on Roblox's Shift Lock share the Shift key with sprint.

## B. Storm Pursuit (the chase)

**How it plays**, every storm cycle, 6 s after a storm passes:

1. **The cache.**
   - A siren sounds and a gold beam goes up over Warehouse 7's loading yard.
   - Everyone gets **RARE CACHE · WAREHOUSE 7 · 0:25** under the storm sign, and a distance tag on the beam.
   - The prize is a real Storm Core.
2. **The race.** First to the cache takes it, through the normal server-checked prompt. If nobody takes it in 25 s, it's gone.
3. **The chase.**
   - A **rogue twister** forms 22 studs behind the carrier: a dark funnel with a **red catch zone drawn on the ground at its exact radius**.
   - Its speed builds from 25 by 0.6 a second up to 30. That's slower than a sprint at first and faster than a base sprint after about 5 s.
   - It moves in a straight line and **passes through buildings**, so the open road is the fast way home and every detour costs you.
   - Every 5 s it throws a **telegraphed debris strike** (1.4 s warning) at the spot you'll reach if you don't change course.
   - The carrier sees **EXTRACT TO THE SCRAPYARD · 0:38** and **TWISTER 14m BEHIND · SPRINT!** in red when it's close, plus an EXTRACT tag on the Scrapyard gate.
   - Everyone else sees **«NAME» HAS THE CORE**.
4. **Caught.**
   - The core is flung 9 studs sideways onto open ground (a wall on one side flips it; both sides blocked drops it at your feet), and you take 15 damage.
   - The twister stalls 3 s and **never guards the dropped core**.
   - Anyone can grab it, the first carrier or another player, and whoever re-grabs gets a 1.5 s head start.
5. **The safe line.** The twister stops at **the foot of the climb up to the Scrapyard**: reaching the climb is the moment you know you made it.
6. **Extracted.**
   - Reaching the plateau gives a **150-coin extraction bonus and 40 XP, once per event**, and a gold card: "EXTRACTED in 12.1s! +150 bonus · sell the core on the hill", with **NEW PERSONAL BEST** when it is.
   - Everyone else sees who extracted it and how fast.
   - The core then sells at the Scrap Buyer for its **normal 175**, through the normal sale.
   - Records (`Extractions`, `BestExtract`) are saved in the profile.
7. **Out of time.** After 45 s, or just before the next storm hits, the core destabilises and is removed.

**Rules that keep it safe:**
- **Server authority:** every rule runs in `PursuitService`.
  - The bag changes only through `PlayerService.removeCarried` and `tryCarry`.
  - The bonus is granted only after the single transition to Done, so it can't be granted twice.
- **Death:** dying with the core drops **only the core** as a free pickup. The rest of the bag goes into your normal owner-protected death bag. (Tested: died carrying Can, Pipe and the core. The core dropped loose, the Can and Pipe went to the owner bag, with no duplicate core.)
- **Leaving:** leaving the game with the core drops it at your last position.
- **No PvP:** no stealing from a living player, and no paid advantage. Sprint is free; Boots are coin upgrades.
- **Timing:** the event always ends before the next storm hits. It can overlap the 12 s warning siren, never the storm.

### Evidence: scripted runs (Studio, base speeds, real prompts and real pathfinding)

A QA runner (`tools/qa/pursuit-runner.luau`) plays the event like a determined player. `QA_Sprint` (Studio only) forces sprinting, because a script can't hold Shift.

| Build | Movement | Race to the cache | Result | Catches | Twister's closest | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| First version (Boots 2) | sprint 31 | 15.2 s | Extracted 15.4 s | 0 | 16 studs | first full playthrough |
| Twister 24, no ramp | sprint 28 | 13.4 s | Extracted 12.2 s | 0 | 20 studs | too easy |
| Twister 24 | run 20 | 17.8 s | **Expired** | 5 | 1.5 | running fails, as intended |
| Twister guarded the dropped core | sprint 28 | 13.4 s | Expired | **9** | 0.6 | catch loop: unfair, fixed |
| Ramp 0.7 (dt bug fixed) | sprint 28 | 13.4 s | Extracted 15.1 s | 1 | 11 | caught on the climb: unfair, fixed with the safe line |
| **Final tuning** | **sprint 28** | **13.2 s** | **Extracted 12.1 s** | **0** | **18.4** | close but fair |
| **Final tuning** | **run 20** | 17.7 s | **Expired** | 2 (then a death) | 9.5 | running gets caught, and stacked damage can kill |

Engineering bugs found and fixed along the way:
1. **The twister ran about 15% slow.** It used a nominal 0.1 s step instead of real elapsed time.
2. **The QA runner never sprinted.** Scripted movement leaves `MoveDirection` at zero, which hid point 1 for several runs.
3. **A dropped core could land against a wall.**
4. **The twister guarded the loose core**, making recovery impossible.
5. **The same extraction message appeared twice.**
6. **The race subtitle kept the danger colour** from the previous event.
7. **The event could run into the next storm.**

**Performance:**
- **Server:** the event is one anchored part moved at 10 Hz plus one state message per phase change. The heartbeat stayed at a 60 Hz median through the runs.
- **Client:** 9 parts and one dust emitter (6/s in Reduced Effects, 22/s otherwise), eased toward the server position every frame.
- Studio frame-rate and memory numbers are from the Studio process and don't measure a device.

## C. Feedback and audio

- **Banner:** one plate under the storm sign, shown only while an event runs; no permanent panel.
- **World markers:** a gold beam and a distance tag on the cache or dropped core. For the carrier, an EXTRACT tag on the gate.
- **Audio, all existing licensed sounds** (no new IDs):
  - siren for the announcement
  - wind whoosh when the chase starts and on a drop
  - the twister's wind roar, louder as it closes in
  - the Core sting on extraction
- **Captures:** `docs/art/v4/pursuit/`
  - `01` the race announced, seen from the Scrapyard
  - `02` the twister and its red catch zone
  - `03` caught, with the core dropped and the banner switched
  - `04` the extraction card

## Honest assessment (for the gameplay review)

**What works, by evidence:**
- **The structure creates real decisions.**
  - Sprinting the open road with no detours escapes, with the twister about 18 studs back.
  - Plain running gets caught and usually fails.
  - A catch costs about 2–3 s and some health, and isn't the end.
  - The safe line and the visible catch zone make danger readable.
- **Rewards are correct and single:** one 150 bonus, and the core sells normally.

**What a bot can't tell us:**
- **Whether it's fun:** whether players notice the announcement, want to race for it, feel the chase is fair, and want to do it again. That needs real players.

**Known weaknesses:**
- **The twister's look is functional, not finished:** stacked discs, dust and the red ring. It reads clearly but needs art.
- **The debris strikes reuse the lightning warning visuals** (flash and thunder).
- **The race window (25 s) favours players already in town.** From the Scrapyard a base sprinter needs about 13 s, so it's fine, but it shows only one district is in play.
- **Repeats every storm cycle**, about every 2.5 minutes. That may be too often once the novelty wears off. It's one config value.
- **Multiplayer still untested:** the two-client Studio test wouldn't start on two attempts. The hand-off rules are player-agnostic and solo-tested, but real two-player play, including two people racing for the cache, is still to verify.

**Not done (out of scope for this deliverable):**
- a slide or dash
- custom animations
- more districts and more event types
- a cooperative bonus

## How to review it

1. In Studio, open the `v4-gameplay` code.
2. Play, wait about 6 s into a calm, and the cache drops.
3. Sprint with Shift.
4. To trigger an event any time: `ServerStorage.StormSalvageDebug:Invoke("pursuit")`.
