# Studio test: UI, animation, audio and game feel (2026-10-09)

Priority 4: rebuild the HUD, notifications, shop, settings and sound so the game feels
finished, without changing gameplay. No damage, economy, upgrade price, Storm Core value or
DataStore format was changed.

Tested in Roblox Studio over MCP. The layouts were checked on 4 simulated screens, in solo
Play, and in a `StudioTestService` session with 2 clients plus a late joiner. The design rules
are in [`../ui-design-spec.md`](../ui-design-spec.md). Screenshots are in
[`../qa-screenshots/v6/`](../qa-screenshots/v6/) (`before-*` from commit `b45ccc7`, `after-*`
from this change).

Nobody listened to the sound, and nothing was run on a real phone. See "Not verified".

## What changed

### HUD

| Before | After |
| --- | --- |
| Two wide dark panels in the top centre (storm banner and stats) | One slim **storm strip**: a coloured dot, storm name, a timer chip, and a Storm Core chip when cores are out. A second line (what to do right now) appears only during the warning and the storm. The outline takes the storm's colour and pulses gently during the warning |
| Coins and bag inside the top panel | A **right rail**: coins (the only gold number on screen), then the bag with count, fill bar (green, amber, red) and "Sell value 105" |
| Bright blue 150 px UPGRADES button fixed on the right | A compact rust-orange **SHOP** button and a **Settings** button, 64 design px (45 pt on a Galaxy A16) on touch screens and 52 px with a mouse |
| Tutorial hint always stretched across the bottom | A small plate shown only until the first sale and hidden during storms, danger alerts and open panels. It now changes with what you're doing: "grab salvage", "grab more or sell", "bag full, sell" |
| Storm warning toast in the toast column | The strip carries the warning, and the storm's own sound plays |
| Personal alert as loose text under the panels | A pill in the **alert slot** right under the strip, outlined in its danger colour |

The HUD is laid out inside Roblox's safe area and scaled by `viewport height / 600`, clamped
between 0.7 and 1.15.

### Notifications

Each kind of message has its own place and priority, as in the spec:

| Priority | Message | Where |
| --- | --- | --- |
| P4 | Personal danger ("MOVE! Lightning is about to strike here") | Alert slot, under the strip |
| P3 | Storm phase | Storm strip (stays above the shop and settings) |
| P2 | Find cards, bag full, sale receipts | Card slot, left side. A lower-priority card waits instead of replacing one still being read (1.5 s), then gets its turn |
| P1 | Server notices (upgrades, "X grabbed a Storm Core!") | Feed, bottom centre between the thumbstick and jump button, at most 3, duplicates merged |
| P0 | Tutorial hint, district titles | Bottom plate / alert slot; hidden by anything above |

### Salvage, cards and receipts

- **Value isn't money.** Pickup pops now read **"Mini Safe · 90 value"** in the rarity colour,
  with no "+" and no gold. Find cards say "Salvage value 60". The bag shows "Sell value". Gold
  is used only for coins you actually have.
- Cards slide in from the left with a small pop and slide out. Desktop players can click to
  dismiss. On touch screens the card lets touches through, because it sits where Roblox's
  dynamic thumbstick starts.
- The receipt keeps the server's itemized lines, adds "Balance N coins", and counts the total
  up over 0.5 s to the exact payout. At the same time the coin balance counts up, pops, and a
  "+290" drifts off it. Spending shows "-150". All of this is display only; the coins were
  already paid by the server.
- A Storm Core delivery gets the "STORM CORE DELIVERED!" header, a short orchestral sting, and a
  gold sparkle burst around the player. There is no full-screen effect.

### District signs

The giant floating names over each building ("Warehouse", "Houses", "Town Square") are gone.
Each building already has its own storefront sign. Walking into a district now shows a short
title in the alert slot, with that district's best finds taken from the loot tables, e.g.
"WAREHOUSE · Best finds: Mini Safe, Engine Block". The Scrapyard says "Safe from storms · sell
and upgrade here". To support this, the server publishes invisible, non-colliding district
footprints in `Map.Districts`.

### Shop and Settings

- **Gear Shop** (modal): each row shows level pips, "5 slots -> 7 slots", and a price button
  that turns grey with "need 40 more" when you can't afford it. The press still goes to the
  server, which explains. When the server confirms a purchase, the row's outline flashes green,
  the new pip pops, and the button reads "UPGRADED!".
- **Settings** (new, its own modal): Master, Effects and Weather volume sliders (tap or drag,
  5% steps, a sample plays as you change them), and the existing **Reduced Effects** toggle,
  moved out of the shop.
  - Settings last for the whole play session, including respawns, but are not saved between
    sessions. Saving them would mean changing the player's DataStore profile, which isn't worth
    the risk for a volume slider. The panel says so.
- Both panels sit over a dimmed backdrop (tap outside or X to close), and only one is open at a
  time. The storm strip and danger alerts stay on top of them.

### Sound

All cues go through two `SoundGroup`s, **Effects** and **Weather**, whose volume is master ×
group from Settings. Each cue has a minimum repeat interval so fast collecting can't pile up
sounds, and a few cues can overlap in small pools.

| Moment | Sound (all Roblox-licensed: Pro Sound Effects or APM uploads) |
| --- | --- |
| Any pickup | Bag Drop Bag Bumping Wall 2 `9113244443` (pitch rises slightly with rarity) |
| Rare find | + Magic Glows Soft Clusters Of Chiming Hits 1 `9116394545` |
| Epic find | + Magic Glows Soft Clusters Of Chiming Hits 4 `9116395089` |
| Storm Core find | + Sparkle Bell Tree Wind Chimes 1 `9119447936` |
| Sale | Coins Or Keys Jingle 6 `9113849492` |
| Big sale (150+) | + Coin Throws 2 `9113849583` |
| Storm Core delivered | + Rising Together (sting a), APM `9043511769` |
| Upgrade bought | Mascot Party - Mnemonic1, APM `9045119921` |
| Button press | Switch In-Line Plastic Switch Clicks 14 `9119727934` |
| Any storm warning | Air Raid Siren Old Fashioned 1 `9113073742`, now faded out after 4 s |
| Wind warning | + Fast Pass By Airy Whooshes Windy 1 `9114373454` |
| Flood warning, each rise | + Water Surge 4 `9120607126` |
| Lightning warning | + Artillery Distant 2 `9113169432` slowed to a low rumble |
| Gust hits | Whoosh Combo Of Impacts Bys 6 `9120704324` |
| Lightning strike | Artillery Distant 2 `9113169432`, now **played from the strike point** (gets quieter with distance and pans), pitch varied per strike |
| Rain, flood water, wind loops | Unchanged ids, crossfaded 1 s in and 2.5 s out |

**Asset check:** all 17 unique ids returned `Success` from `ContentProvider:PreloadAsync` in
this experience, and every `Sound` reported `IsLoaded` with its length (0.66 s to 46 s).
The new ids were chosen from search results published by the ProSoundEffects and APMOfficial
accounts. Their store descriptions say "Courtesy of Pro Sound Effects" or "Courtesy of APM
Music".

**Timing check** (client log of which sounds started, while forcing each storm): every warning
played the siren, then its own cue 0.6 s later (WarnWind, WarnFlood, WarnLightning). When each
storm started, its ambience followed: Wind; Flood and Rain; or Rain.

### Storm presentation

- **Climb markers:** a small yellow chip (84×24, was 120×34). It only shows to a player who is
  below the flood line during a flood warning or flood, and only for ladders within 110 studs
  (the ramp's within 170). Checked: with the player at street level, 1 ladder and the ramp
  were on and the other 7 ladders off. A late joiner on the hill saw none.
- **Status lines** no longer repeat the timer (the strip has a timer chip) and use the danger
  palette: lull green, gust warning amber, gust red, water blue.
- **Personal alerts** no longer tick every frame ("Gust in 1.3s - you're in the open!" became
  "You're in the open - gust coming!"), so the pill doesn't flicker.
- **Beacons:** Storm Core and dropped-bag light columns widen with distance (0.8 studs up close,
  up to 5 at 500 studs), so they stay visible from the Scrapyard
  (`after-desktop-bag-beacon-from-hill.jpg`). A dropped bag gets **one** beacon and one
  "YOUR BAG · 33s" countdown, instead of one per item.

## Test results

| Check | Result | Evidence |
| --- | --- | --- |
| Common pickup | **Pass** | Bag 1/3, "Sell value 5", no card |
| Value wording | **Pass** | Pop text read back from the client: "Mini Safe · 90 value", "Engine Block · 60 value" |
| Rare / Epic / Legendary cards | **Pass** | `after-desktop-rare-find.jpg`, `after-a16-epic-find.jpg`, `after-desktop-storm-core-find.jpg` |
| Card priority | **Pass** | Card priority sampled every 0.4 s after an Epic pickup that also filled the bag: Epic (3) for 3.7 s, then BAG FULL (1) for 3 s, then empty. The BAG FULL card waited instead of replacing the Epic card |
| Card slide-in | **Pass** | Card x position over time: -27 at the first frame, then rests at 13. With Reduced Effects on it appears at 13 at scale 1.0 straight away |
| Receipt accuracy | **Pass** | 3 items: lines 140 / 90 / 60, total +290, balance 315 = the server's leaderstats. Mixed Storm Core + Mini Safe: +265, balance 755 |
| **"+572" screenshot question** | **Not a current bug** | Core and Mini Safe sold together: the announcement read "FrankMevash delivered a Storm Core! **+175**" while the receipt total was +265. The old screenshot came from before the fix in `b45ccc7`. Nothing was changed |
| Hint flow | **Pass** | "Head down into town..." → after a pickup "Grab more, or sell..." → when full "Bag full! Sell..." → gone after the first sale |
| Upgrades | **Pass** | Backpack, Boots and Armor bought through the shop buttons. 755 → 705 → 630 → 530, each row celebrated, a feed notice for each |
| Settings | **Pass** | Dragging and tapping set the sliders. Group volumes multiplied correctly (Master 25% × Effects 50% = 0.125). Volumes and Reduced Effects survived a respawn |
| Shop opened from the Gear Shop prompt | **Pass** | `after-a16-shop.jpg` |
| Death and bag recovery | **Pass** | One beacon and a "YOUR BAG · 18s" label, seen from the hill |
| District titles | **Pass** | "SCRAPYARD · Safe from storms · sell and upgrade here" on spawn and respawn. Hidden while a panel is open |
| All three storms | **Pass** | Wind (`after-iphone17pro-gust-warning.jpg`), flood (`after-desktop-flood-warning.jpg`, `after-ipad-flood-warning-rare.jpg`), lightning (`after-a16-lightning-danger.jpg`) |
| Notification overlap | **Pass** | `after-a16-lightning-danger.jpg` shows the strip with its cores chip, the danger alert and a feed notice together on the smallest phone, with no overlap |
| Studio output | **Pass** | No warnings or errors in the console during the solo and multiplayer sessions |
| Format, lint, types, build | **Pass** | StyLua, selene 0 errors / 0 warnings, luau-lsp clean, `rojo build` OK |

### Layouts (Studio device simulator)

| Screen | Viewport | HUD scale | Result |
| --- | --- | --- | --- |
| Laptop | 1365×768 | 1.15 | All HUD, cards, shop and settings checked |
| Galaxy A16 | 685×338 | 0.70 | Shop 67×44 pt and Settings 44×44 pt targets. The rail ends 13 pt above the jump button. The card clears the thumbstick graphic. The shop's three rows and settings' four rows fit without scrolling (`after-a16-shop.jpg`, `after-a16-settings.jpg`) |
| iPhone 17 Pro | 750×381 | 0.70 | Gust warning and alert pill fit (`after-iphone17pro-gust-warning.jpg`); settings fit |
| iPad 10th gen | 1179×819 | 1.15 | Strip, alert, card, pop and rail together with no overlap (`after-ipad-flood-warning-rare.jpg`) |

### Multiplayer (2 clients and a late joiner)

| Check | Result |
| --- | --- |
| A Storm Core grab notifies everyone; only the finder gets the card | **Pass**: both feeds read "Player1 grabbed a Storm Core!". Player1 had the Legendary card (priority 4); Player2 had none |
| Each player's cards stay their own | **Pass**: Player2's Epic card didn't affect Player1's |
| Simultaneous sales (both pressed at the same server time) | **Pass**: each client showed exactly one receipt, Player1 +175 (balance 2330) and Player2 +90 (balance 389), matching the server and the coin label |
| Late joiner during a flood | **Pass**: Player3 joined at water level 12. Their strip read "FLASH FLOOD · 21s left · Water at its peak - stay high" with the cores chip. They were safe on the hill, so they got no danger alert and no climb markers |

### Performance

- **Server**, 3 players: heartbeat median 16.7 ms, p99 17.5 ms, max 17.8 ms. The Priority 3
  baseline was median 16.6 ms, p99 18.0 ms.
- **Client**, during a lightning storm: render CPU time per frame median 5.6 ms, max 15.5 ms;
  client heartbeat 0.35 ms. Studio throttled every Play window to 15 fps during these runs
  (each frame took a steady 66.7 ms, including the focused window), so frame rate couldn't be
  measured. The CPU numbers say the client does well under one 60 fps frame of work. No
  before-change client numbers were taken, so this isn't a comparison. Nothing was measured on
  a real phone.

## Defects found and fixed during testing

1. **Danger hidden under panels.** The storm strip and alerts were under the modal backdrop.
   They now draw above the shop and settings.
2. **The card blocked the thumbstick on touch screens.** It sat where Roblox's dynamic
   thumbstick starts and was a button. On touch it's now a pass-through frame.
3. **The dim backdrop stopped short** of the screen edges on phones (clipped to the safe area).
   It now covers the whole screen.
4. **Panels didn't fit on a 338 pt phone.** The third shop row and the Reduced Effects toggle
   were cut off. Panels are taller, rows tighter, and the settings footnote moved under the
   title.
5. **The district title overlapped a panel's top edge.** Titles are skipped while a panel is
   open.
6. **The bag icon read as a padlock.** Redrawn as a backpack.
7. **Text too small on phones.** 12 px captions came out about 8 pt on the A16. The smallest
   text is now 13 px.

## Not verified

These need a person, a real device, or both:

- **Listening (headphones and a phone speaker).** Assets load and fire at the right moments,
  but nobody has heard the mix. Check:
  1. Do Rare, Epic and Storm Core finds sound clearly different and rewarding, and not too loud
     next to the plain pickup?
  2. Is the Storm Core delivery sting (APM, about 4 s) satisfying, or too long or out of place?
  3. Can you tell the three storm warnings apart with your eyes closed (whoosh, water surge,
     low rumble) over the siren?
  4. Does the siren fading out after 4 s still feel urgent enough?
  5. Gust whoosh: does it line up with the push?
  6. Thunder from the strike point: is near versus far believable, and is a long lightning storm
     tiring?
  7. Is the button click too loud or too frequent?
  8. Do the Settings sliders at 0% fully silence their group?
- **Real touch.** In the simulator, mouse clicks don't reach GUI buttons, so on phone layouts
  the shop was opened through its in-world prompt and settings through a Studio-only hook.
  Not checked by hand:
  - tapping SHOP and Settings
  - dragging a slider with a finger
  - that touches really pass through a card to the dynamic thumbstick
- **Real phone performance** and readability at arm's length.
- **Climb markers can hide behind buildings and trees.** They're drawn in the world (not on top)
  because on-top billboards didn't render in earlier Studio captures. Worth checking in a real
  client whether always-on-top reads better.
- **Grabbing a Storm Core while swimming.** Two scripted presses at 10 studs from the water's
  surface failed in this session, while a press at 3.4 studs worked. The same grab passed in
  Priority 2. This phase didn't touch prompts or reach checks, so it's probably the scripted
  press, but a person should try it once.
- **The first-time player experience with a truly empty profile.** The hint flow was checked on
  the Studio account (no sales yet at the start), not on a brand-new DataStore key.

## Remaining release blockers (unchanged by this phase)

- **Purchases:** a pending purchase grant can be spent before its save completes, and replaying
  the exact same failed receipt is untested. Both must be resolved before real products go live.
- A separate test experience for destructive DataStore and purchase tests.
- Real-player sessions (5–10 people who haven't seen the game) and real-device checks.
