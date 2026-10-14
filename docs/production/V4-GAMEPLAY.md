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

---

# Milestone M1: the pursuit system (2026-10-14, complete-game directive)

Built on the first slice. Code: `EventService`, `PursuitService`, `Pursuit` (shared rules), `PursuitHud`, `Movement`.

## What changed

- **Event catalog and director (B5).** After each storm passes there's one opportunity, in rotation, **never the same kind or site twice in a row** (unit-tested over 200 picks). Every event ends before the next storm hits.
  - **Storm Pursuit:** the twister chase.
  - **Dangerous Extraction:** no pursuer. The core is unstable and telegraphed **surges** erupt 25–45 studs ahead on the straight line home (cyan, 9-stud radius, 25 damage, 1.6 s warning), so the obvious road is the dangerous one. 35 s window, 120 bonus.
  - **Salvage Rush:** six valuable finds (2 Engines, 2 Registers, a Safe, a Jukebox) spread round the site for 30 s, at normal sale values plus 6 XP each. The announcement names the top salvager at the end.
- **Five sites (B4):** Warehouse 7 (difficulty 2), Super Saver (1), Fuel & Go (1), the Houses (2), Starlite Motel (3).
  - Each spot **checks itself at runtime**: open sky, solid ground, and a walkable route home.
  - If something is in the way, it nudges to the nearest good spot (the Motel's did).
  - Rush finds pick distinct open spots.
- **Route-bound twister (B3).** It no longer passes through buildings.
  - It paths along the streets with a wide agent (radius 5), re-planning every 0.6 s.
  - Gaps narrower than about 10 studs and roofs are real escapes. With no route it pushes straight at you at half speed, so a gap buys time but nowhere is safe for good.
  - It spawns only on open ground, never on a dock or a roof.
  - Speed starts at 27, gains 1 per second, and caps at 32: below a max-Boots sprint (34), so Boots matter.
- **The pursuer's look and states (B2).** A tapered funnel, dark at the base and paler up top, with orbiting debris. It leans toward where it's heading and has a red catch ring at its exact radius. States the player can read:
  - **Forming:** grows out of the ground.
  - **Chasing**
  - **WindUp:** the base glows red and spins faster just before a debris strike.
  - **Stunned:** shrinks and pales after a catch.
  - **Searching:** no route to you.

  Debris strikes have their **own visuals** (a brown dust ring, chunks slamming down, a dust puff). Surges are a cyan ring with an electric pulse. **Neither reuses the storm's lightning.** Audio uses existing licensed cues only.
- **Records (B7):**
  - total extractions and best time
  - **streak**: clean extractions in a row, never caught that event
  - **best streak**
  - **hardest site** extracted from
  - **rush finds**

  Old profiles are reconciled. The extraction card calls out "NEW PERSONAL BEST", "N IN A ROW" and "HARDEST SITE YET".
- **Controls (A2):**
  - With Roblox's Shift Lock on, sprint moves to **Ctrl** (a one-time tip says so).
  - **No sprinting while climbing, swimming or seated.**
  - The field of view snaps back on death.
  - Held keys are cleared when the window loses focus, so sprint can't stick on.

## Evidence (Studio, base speeds: run 20, sprint 28; scripted runner with real prompts and pathfinding)

| Event | Site (difficulty) | Result | Notes |
| --- | --- | --- | --- |
| Pursuit, first route-bound build | Warehouse 7 (2) | Extracted 12.7 s, twister never moved | **Bug:** spawned on the loading dock, so no route ever. Fixed: spawns only on open ground, never stuck. |
| Pursuit | Warehouse 7 (2) | Extracted 12.2 s | Gap only grew. **Bug:** paths ended where the runner *was*, so it idled at the end. Fixed: with a good route it charges at full speed past the end of its path. |
| **Pursuit (final)** | **Warehouse 7 (2)** | **Extracted 12.3 s, 0 catches** | Gap held at 15–22 studs the whole chase; 2 strikes dodged |
| **Pursuit (final)** | **Starlite Motel (3)** | **Extracted 13.9 s, 0 catches, 69 HP** | Race 19 s from the Scrapyard. Gap closed 20 → **10.8** before the safe line; 1 of 3 strikes hit |
| **Extraction** | **Fuel & Go (1)** | **Extracted 10.2 s, 77 HP** | 4 surges on the line home, 1 hit |
| **Rush** | **Super Saver** | Finds spread over 6 open spots | Grab counted (5 left), XP and record. First build stacked 3 finds on one spot: fixed. |
| Site checks | all 5 | All resolve | The Motel's nudged to (−6, 139) |

Captures: `docs/art/v4/pursuit/05` (the route-bound twister chasing), `06` (stunned after a catch), `07` (Rush banner).

## Still open in Phase A/B

- **Multiplayer (B6)** with real clients: two racing for one cache, simultaneous grabs, 4/8/12 players. Studio's two-client test wouldn't start (2 attempts in M0). The rules are server-side and player-agnostic (one `taken` flag per item; one transition to Done), but this **needs a real-server session with people**.
- **Phones:** real-device controls and performance.
- **Cooperative Recovery** (the fourth event idea): deferred. Three solid kinds first, as directed.
- **Evasive action (A3)** and **custom animations (A4)**: animations need uploaded assets (owner); the evasive action is next, with M2.
- The pursuer still uses part-built visuals. A modelled creature or funnel asset belongs in Phase E art.

---

# Milestone M2: rewards worth chasing, the dodge (2026-10-14)

Developed on `v4-gameplay` while RC8 (place v142) is under private test. Not published. Part 1 below
is what went in first; **part 2** (further down) completes M2 and supersedes part 1 where they differ
(the dodge is now server-checked, hits wait 0.35 s, and the Golden Core has its own model).

## Part 1: built

- **The dodge (A3).** Q, gamepad B, or the DODGE touch button (placed above-left of jump).
  - A 0.22 s burst at 58 studs/s in the move direction (facing direction if standing), with a 2.5 s cooldown.
  - Ground only: not climbing, swimming, seated or mid-air.
  - Dust and a whoosh for feedback. The camera stays Roblox's.
  - Nothing changes on the server: no immunity, no reward.
  - **Chosen over a slide:** it reads with effects alone (a slide needs a crouch animation, which needs an uploaded asset), and it works in wind, floods and on every surface.
  - When the twister is within 12 studs, the carrier's banner says **"DODGE! (Q / B)"**.
- **Fair hits under latency.** Studio showed a runner who was clearly outside a debris circle on their own screen still taking the hit: the server sees a sprinting player 3–6 studs late.
  - Strikes and surges are now judged 0.15 s after landing, on a circle 1.5 studs smaller.
  - The catch ring is 1.5 studs smaller too.
- **Golden Storm Core (C1/C2).** A jackpot cache prize worth 600 (a Storm Core is 175).
  - **Odds are real:** 15%, decided when the cache spawns, so the banner and announcement say **GOLDEN CACHE** only when it truly is one. No fake jackpots.
  - It's the Storm Core model tinted gold, with the same rules: glow, contracts and delivery announcement count it as a core.
  - Picking it up is a **"JACKPOT!"** moment: a GOLDEN stamp, the delivery sting and a big sparkle burst.
- **The Salvage Log (C3, collectible progression).** The first find of each kind of salvage is recorded server-side (`Collection.Found`), with "NEW IN YOUR SALVAGE LOG: Safe (7/12)".
  - Commons are logged quietly until the JOBS board unlocks, so a new player's first minute isn't a stream of notices.
  - Rare and better always announce.
- **The extraction receipt (C3).** A clipboard card:
  - GOLDEN EXTRACTION or EXTRACTION RECEIPT
  - the site
  - the time, as the biggest thing on the card
  - the bonus
  - what the core sells for
  - stamps: NEW BEST, N IN A ROW, HARDEST YET

  A sparkle burst plays too (larger for golden). Other players get a one-line notice.

## Part 1: evidence (Studio)

| Test | Result |
| --- | --- |
| Dodge from standing | 13.3 studs |
| Dodge again within the cooldown | 0 studs (blocked) |
| Dodge while moving | 16.4 studs in 0.5 s (walking alone: about 10) |
| Dodge mid-jump | Blocked |
| **Dodge against real debris strikes** (alternating, runner sprinting the line the strike aims at) | **Dodged: server distance 27.2, miss. Not dodged: 4.7, hit.** The server's view now matches the player's (29.0 / 5.3). |
| Golden Pursuit at the Motel (forced, Studio-only debug) | Banner and announcement "GOLDEN CACHE · STARLITE MOTEL"; gold-tinted core under the beam (`docs/art/v4/m2/01`) |
| Golden extraction | 16.6 s; receipt card shown (`docs/art/v4/m2/02`); bag "SELLS FOR 600"; +150 bonus |

Lint, types and 44 unit tests pass.

# Milestone M2, part 2: completing it (2026-10-14, "M2 Review")

Everything below was run in Studio on the place, not on phones or real servers. A scripted runner
finishing an event says nothing about whether it's fun.

## Built

- **Salvage Log screen** (`Jobs.luau`, third tab **SALVAGE LOG** on the JOBS board, Workshop style).
  - A progress strip: "SALVAGE LOG 4 / 12 FOUND", a fill bar, and the lifetime total of finds.
  - One tile per kind, ordered by rarity, then value. A tile has a rarity edge and a rarity pill.
  - **Found** kinds show:
    - a live 3D thumbnail of the real model (a ViewportFrame of `ReplicatedStorage.SalvageModels`)
    - the name, the lifetime count ("x2") and the sale value
    - where it turns up: the top 3 districts by spawn weight, or "Mid-storm, anywhere in town" or "The rare prize of a cache event"
  - The Golden Storm Core tile is yellow with a **JACKPOT** stamp.
  - **Undiscovered** kinds are a kraft card with "?", "???", the rarity, "Not found yet" and "Keep salvaging". No name, value, model or location, so special spawn places stay secret.
- **Lifetime counts** (`SalvageLog.luau`, pure and unit-tested): `Collection.Counts` sits beside `Collection.Found`.
  - Older saves are backfilled additively on load: a kind already found counts as 1. Nothing is removed or reset.
  - Discoveries still give no reward beyond the notice, so there's nothing to farm or duplicate.
  - **Recoveries don't count:** dropped bags (as before) and now **an event core knocked loose and grabbed again**. Studio found that bug (below); it also stopped regrabs counting toward "collect" contracts.
- **Golden Storm Core model** (`assets/roblox/salvage/GoldenCore.model.json`, from `tools/asset_pipeline/build_golden_core.py`).
  - Its own silhouette, no longer a tinted copy: a tall gold reliquary cage on a dark plinth, a faceted crystal star around a molten core, and a crown of four spikes with a diamond on top.
  - 2.2 × 3.5 × 2.2 studs (the Storm Core is 2.2 × 2.1 × 2.2), from 19 plain Roblox parts. **No mesh upload and no asset IDs needed.**
  - The carrier's glow is gold, range 18 and brightness 3.5, against the Storm Core's 12 / 2.5.
  - `ModelFrom`/`Tint` were removed from the loot code.
- **Dodge authority** (`DodgeService.luau`, `MoveRules.luau`, pure and unit-tested).
  - **Requests:** each dodge also sends a request. The server honours it only when the player is alive and grounded (raycast), it's off cooldown on the server clock (2.5 s, 0.2 s jitter allowance), and the requester is under 6 requests a second.
  - **Honoured dodges** show dust to other players (DodgeFx).
  - **Refused requests** are counted in the session report, never sent to analytics, so a cheater can't flood the dashboards.
  - **Positions are sampled at 10 Hz.** A move further than 1.75 × top sprint speed, plus one honoured dodge, plus 6 studs of slack over 0.5 s is implausible. Hits are then judged at the position from **before** the move for 1 s.
  - **What uses the trusted position:** strikes, surges, the twister's catch, and lightning.
  - **What the server can't do:** stop the client moving, since Roblox physics is client-owned. It decides what a move counts for.
- **Dodge fixes:**
  - **The burst ends when the character leaves the ground:** jumping during a dodge used to carry the dodge speed through the jump. Its horizontal speed is now clamped to walk speed.
  - **Gamepad B passes through** while a menu has focus.
- **Fair hits under real latency.** `HitGrace` 0.15 → 0.35 s, plus each player's `GetNetworkPing()` capped at 0.25 s (`DodgeService.lagAllowance`). The measurements and reasoning are below.
- **Animations** (`assets/roblox/animations/*.model.json` from `tools/asset_pipeline/build_animations.py`; `CharacterAnims.luau`).
  - Three R15 KeyframeSequences:
    - **Dodge:** 0.34 s, Action priority. A low lunge with the arms swept back.
    - **CoreCarry:** a 0.9 s loop, arms only, so the run cycle keeps the legs. Both arms hug the core to the chest with a slow heave.
    - **Celebrate:** 1.2 s. Two fist pumps overhead in a V, with a hop.
  - **Validated on the real rig.** It's R15 with AnimationConstraint joints; KeyframeSequence poses drive it by part name. Checked by measuring hand and head positions in Studio:
    - Celebrate: hands at (±1.7, 2.6) above the head (2.0).
    - Carry: hands at chest height, 1.6 studs in front.
    - My first celebration crossed the hands over the head. Overhead the arm's frame flips, so the roll signs were reversed.
  - **IDs:** `Config.Animations` stays 0 (not uploaded). **No IDs were invented.**
  - **In Studio** the KeyframeSequences preview through `KeyframeSequenceProvider` (`ReplicatedStorage.StudioAnimations`, Studio only).
  - **On a live server** nothing plays until the owner uploads them. The fallbacks remain: the dodge's dust and whoosh, the carrier glow, and the receipt card with its burst.
  - Upload steps: [`docs/art/v4/ANIMATIONS.md`](../art/v4/ANIMATIONS.md).

## Evidence (Studio, place 99653875913460, `_STUDIO` save store)

**Salvage Log and Golden Core**

| Test | Result |
| --- | --- |
| First Mini Safe picked up | "DISCOVERY Safe 2/12" once; count 1 |
| Second Mini Safe | No discovery notice; count 2 |
| Die carrying both Safes, recover the bag | Both back in the bag; count stays 2; no notice |
| First Engine / Cash Register | "DISCOVERY Engine 3/12" / "Register 4/12" |
| Golden Core on the ground | 2.2 × 3.5 × 2.2, 19 parts, all non-colliding, non-touching and non-query; flush on the ground (gap 0.00); "Grab" prompt, 1.2 s hold, 16 studs (`m2/03`, `m2/06`) |
| Carried golden | Server bag `["GoldenCore"]`; CoreGlow kind GoldenCore, range 18; the item leaves the world |
| Sell golden alone | Receipt line GoldenCore ×1 @ 600, total **600**, no multipliers. An earlier +680 was 600 plus an 80-coin Core contract completing. (`m2/08`) |
| Engine + golden sale | 600 + 60 = **660** |
| **Bug found:** golden knocked loose by the twister, then regrabbed | Count rose 3 → 6 in one event; regrabs counted as fresh finds (and toward contracts). **Fixed** (loose cores are recoveries). |
| After the fix: grab, die (core drops), respawn, regrab | Count 8 → 9 on the first grab, stays 9 on the regrab |
| After the fix: full Warehouse golden Pursuit, caught 3 times | Count +1 total (10 → 11); extracted, **+150**; celebration track playing |
| Golden probability | Unit test: 20,000 seeded rolls within 3σ of 15%; boundary 0.1499 → golden, 0.15 → ordinary |

The test profile's Golden count (x11 in `m2/04`) includes the inflated counts from before the fix. That's the Studio-only save; no real save was touched.

**Dodge** (real Q presses unless noted)

| Test | Result |
| --- | --- |
| From standing, open ground | 12.4 studs; honoured by the server; no flags |
| Into a wall 6 studs ahead (face at x = 1009) | Stopped at x = 1007.46 (body against the wall); no pass-through |
| Mid-air (jump, then Q) | 0 studs; no request sent |
| Sprint jump vs sprint + dodge + jump | Airborne distance 14.8 vs 15.6 studs (noise); the burst no longer extends a jump. A 20-stud pit is uncrossable either way. |
| Right after respawn | 12.6 studs, honoured; a plain respawn raises no movement flag |
| During a windstorm gust (wind acceleration 150) | 12.3 studs in 0.35 s |
| Exploit: 10 Dodge requests in 1 s plus 1 malformed | 1 honoured; 7 refused (cooldown or bad); 3 dropped by the rate limit |
| Exploit: client teleports 40 studs | First version: judged half-way (x 21.4). Roblox replicates a teleport as a fast slide over about 0.2 s. **Fixed:** judged at the pre-teleport spot (x 4.5) within about 0.2 s, held 1.3 s, then live again |
| Keyboard Q, gamepad B, touch | Bound (Q, ButtonB) with a touch button titled DODGE. Studio can't inject ButtonB ("bound to a CoreGUI action") and has no touch here: **controller and phone are unverified.** |

**Hits under latency** (debris strike centred on the player; the client dodges a set delay after it sees the warning)

| Setup | Dodge at (s after warning) | Server verdict |
| --- | --- | --- |
| No added lag, old grace 0.15 | 1.30 | Hit ×3 (d 0.0–1.1) |
| Measured | — | Client clears the circle 0.12 s after the press; the **server sees it 0.42 s after**. Server→client is 0.03–0.05 s. |
| No added lag, grace 0.35 | 1.20 / 1.30 | Miss (d 11.2 / 6.0, 7.9) |
| No added lag, grace 0.35 | 1.36 / 1.40 | Hit (d 2.7 / 1.9): the player was still inside on their own screen when the ring closed |
| 0.15 s lag each way, no allowance | 1.10 / 1.20 / 1.30 | Hit ×3, even 0.3 s before the visible close: unfair |
| 0.15 s lag each way, 0.25 s allowance | 1.10 / 1.20 / 1.30 | Miss / miss / hit (d 13.8 / 10.7 / 5.4) |

Studio's lag setting doesn't show in `GetNetworkPing()`, so the allowance was exercised with a Studio-only `QA_Ping` attribute. On real servers it comes from `GetNetworkPing()`. Every strike records the largest allowance applied in the session report (`StrikeLagAllowanceMs`), so the owner's playtest will show whether real pings land in range.

**Full M2 journey** (one session, after the fixes)

1. Discover a Cash Register: "DISCOVERY Register 4/12".
2. A golden Pursuit at the Warehouse: GOLDEN CACHE.
3. Grab: JACKPOT card; the carry animation plays (`m2/06`).
4. Four strikes, each with a dodge.
5. Caught three times and regrabbed: no recount.
6. Extracted: +150; gold glow; "SELLS FOR 600" (`m2/07`).
7. Sold: +600 receipt and server announcement (`m2/08`).
8. Log: Golden ×11, JACKPOT stamp; Register, Engine and Safe found; 8 mystery tiles (`m2/04`, `m2/05`).

The scripted runner got caught soon after grabbing in most runs. That's a bot taking the pathfinder's route, not a balance verdict. Whether the chase is fair to people is for the owner's playtest.

**Performance** (Studio process; Studio caps an unfocused window at about 15 fps, so FPS is meaningless here; **not a device measurement**)

| Same conditions, idle at spawn | RC8 | M2 |
| --- | --- | --- |
| Render CPU per frame (median / p95) | 7.51 / 8.42 ms | 6.72 / 7.46 ms |
| Script heartbeat (median) | 0.31 ms | 0.34 ms |
| Physics step (median) | 0.39 ms | 0.44 ms |

- **Salvage Log open** (12 thumbnails): render CPU +0.4 ms.
- **Server heartbeat through the journey:** 29,782 samples, median 16.7, p99 18.0 ms. One 200 ms spike, at a storm phase change.
- **Golden Core:** 19 parts, one at a time.
- **DodgeService:** one raycast per request, plus a 10 Hz position sample per player.

The V3 device budgets are unchanged: no new textures and no new meshes. Phones are still the owner's to measure.

**Animation previews:** `m2/09` is the final celebration. `m2/10` (carry) and `m2/11` (dodge) are **first-pass** poses, tuned after these captures: carry forearms flatter, dodge 0.55 studs lower instead of 0.9.

## Known limitations (M2)

- **Animations:** nothing plays live until the owner uploads them (steps in `ANIMATIONS.md`). The fallbacks work without them.
- **Controller and phone:** the dodge button and gamepad B are bound but unverified on devices.
- **The movement check catches teleports and gross speed hacks, not subtle ones.** Its budget is generous so gusts and falls never flag honest players. A teleport timed in the ~0.2 s before a hit resolves can still be judged at a mid-slide spot.
- **The lag allowance relies on `GetNetworkPing()`.** It's capped at 0.25 s; its real-server values still need checking (logged per session).
- **Not covered:** real multiplayer (other players' dodge dust), phones and fun.
- **Lightning:** uses the trusted position but not the lag allowance (unchanged V3 timing).
