# Storm Salvage — post-environment production order

Do NOT start all these branches of work at once. Complete and QA the five
districts; then use evidence to decide which improvements matter.

## 1. Gameplay mechanics — improve the existing loop

- First-time flow: in an unaided test, player spawns facing the salvage route;
  show a single meaningful objective and an actual nearby item.
- Carrying: verify capacity display, item pickup range, and failed grab feedback.
  Ensure high-value finds visibly motivate a return trip.
- Storm differentiation: wind forces cover and path choice; flood forces elevation
  and timed evacuation; lightning forces continuous movement and quick decisions.
- Death-drop protection: two clients verify owner-only first 20 s, shared afterward,
  exactly one loot pickup per item. Review whether the penalty discourages newcomers.
- Rewards: don't award survivors merely for standing on the boundary at the end.
  Validate current half-storm-in-town rule and calculate real earning rates.

## 2. UI — componentize carefully

Current `src/client/Main.client.luau` handles UI, sound, and weather effects.
Extract UI by responsibility in small safe commits only if it reduces regression
risk. Start with HUD then shop, keeping existing network contracts unchanged.

Desktop/mobile verification screens:
- Calm spawn; full bag; storm warning; lightning warning; flood damage;
  rare item; sale receipt; invalid upgrade; max-level; non-saving profile;
  rejoin; pause/settings; narrow iPhone landscape.

Implement short, context-aware guidance, no multi-screen tutorials.
Make storm state prominent but not intrusive. Ensure CoreGui/Chat areas are safe.
Use accessible contrast and settings for motion/sound intensity.

## 3. Animation and sound

- Add sell-counter response, item hover/rarity cue, coin gain confirmation,
  upgrade celebration, lightning charge/impact, wind debris shake, flood rise.
- Audio: separate ambience, UI and effects groups; independent volume controls.
  Use licensed Roblox audio and verify actual loudness by ear on real devices.
- Introduce a reduced-effects setting. Don't obscure lightning warnings with
  unnecessary particles or camera shake.
- Test simultaneous sound playback and respawn cleanup. Avoid effects leaks.

## 4. Progression and economy

Measure median coin rate / minute, time to first upgrade, upgrade-tier payback,
storm participation, death loss, return rate, and time to full bag. Rebalance
in `src/shared/Config.luau` from recorded playtests, not intuition alone.

Propose only upgrades that create decisions: backpack, boots, armor first;
consider collection efficiency, short-range detection, and hazard warnings
only if players request them. Keep all advantages earnable by free players.

Do not enable purchases before successful real DataStore and receipt QA.
Test `ProcessReceipt` retry on failed saves, duplicate purchase callback,
server hop, and unavailable-profile session. All grants must persist before
`PurchaseGranted` is returned.

## 5. Multiplayer test matrix

Use Studio **Test → Clients and Servers → 2 players** and a private published
experience for cross-server tests. The MCP's single-player tests do NOT count.

| Case | Steps | Expected |
|---|---|---|
| Same loot | Two clients hold pickup on one item simultaneously | One claim, item disappears once |
| Bag protection | P1 dies carrying items; P2 attempts at 5 s | P2 denied; P1 allowed |
| Bag expiration | P2 retries after 21 s | P2 may collect each item once |
| Bag lifetime | Leave items past 60 s | Disappear without duplicate value |
| Server join | P2 joins mid-lightning/mid-flood | Correct phase, cues, and UI synced |
| Two players storm | Both seek shelter separately | Damage rules correct for each |
| Purchase retry | Simulate DataStore save failure during receipt | NotProcessedYet, no lost purchase |
| Session locking | Rejoin rapidly from another server | No concurrent profile writes |
| Buy upgrade | Clients rapidly request same upgrade | One authoritative transaction per purchase; no negative coins |
| Shutdown | Server closes during pending save | Durable state or recoverable retry |

## 6. Real-player feedback

Recruit 3–5 people unfamiliar with Storm Salvage. Give no verbal instructions.
Observe: time to first pickup, sale, upgrade, shelter recognition, first death,
first storm completion, and whether they voluntarily play again. Use both
quantitative session events and questions: 'What confused you?', 'What felt
exciting?', 'Why did you stop?' Prioritize fixes by observed impact.

## 7. Release standard

Private test only until gameplay, save data, monetization receipt safety,
server authority, visuals, and phone performance meet their gates. Publish
and market only after a real audience has validated the repeatable loop.
