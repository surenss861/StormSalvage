# Studio test: salvage, selling and progression (2026-10-09)

Priority 3: make the find → grab → escape → sell → upgrade loop rewarding and readable,
and back the economy with measurements. Tested in Roblox Studio over MCP, in solo Play
and in a `StudioTestService` session with 2 clients (plus a late joiner). Screenshots are in
[`../qa-screenshots/v5/`](../qa-screenshots/v5/).

**About the economy numbers.** No real players were tested. Progression was measured with
a QA autopilot ([`tools/qa/autopilot.luau`](../../tools/qa/autopilot.luau)): a client script
that walks to the nearest salvage with pathfinding at normal speed, presses the real prompts,
sells when the bag is full, buys the cheapest affordable upgrade, and ignores storms. Think of
it as an efficient but naive new player: real first-timers will explore differently and be
slower to learn the map. Each condition has one 10-minute run, so the numbers show the shape
of the economy, not exact averages.

## What changed

### Pickups

- Every pickup shows a "+value Name" pop rising from where the item was, colored by rarity,
  and the bag bar pulses. Common pickups no longer add a toast line, so grabbing quickly
  doesn't stack text.
- **Rare, Epic and Legendary** pickups add a find card on the left of the screen ("RARE FIND
  · Engine Block · +60 · Bag 2/20"), sparkles where the item was, and a brighter, higher
  pickup sound. Cards share one slot: a new card replaces the old one, and tapping a card
  dismisses it.
- Filling the bag shows a "BAG FULL · Sell at the Scrap Buyer on the hill" card, and the
  bag bar turns red.
- Repeating the same message (like "Bag full!" on every grab attempt) refreshes the toast
  already on screen instead of adding another.
- Only Storm Cores are announced to everyone; Epic finds get the finder's own card.

### Storm Cores

- Each core in town has a light column and a "STORM CORE 175" label visible from 500
  studs away. The banner counts the cores left ("| 3 Storm Cores").
- Carrying a core makes you glow gold for everyone, so everyone can see who has the
  prize.
- Delivering one announces "X delivered a Storm Core! +175", and the receipt says "STORM CORE
  DELIVERED!".
- **Value 250 → 175** (see Economy). Still 3 per storm.

### Selling

- The server builds a **sale receipt** from the same numbers it pays out: items grouped and
  sorted by value (the top 4, then "+ N more"), base value, each active multiplier, the total,
  and the new balance. Each receipt is numbered per session, and the client never shows the
  same receipt twice. The total counts up over 0.45 s; the card lasts 3.2 s (5 s with a core)
  and can be tapped away.
- The old "Sold for X coins!" toast is gone; the receipt replaces it.

### Death recovery

- **Owner-only window 20 s → 40 s, bag lifetime 60 s → 75 s** (see the measurements below).
- Your own dropped items show a light column and a "YOUR BAG 33s" countdown, which
  changes to "(anyone can take it!)" when the window ends.
- Dropped items can be grabbed from 16 studs (was 10), like Storm Cores, so a bag that
  ends up under a flood can be reached from the surface.

### Layout

- The tutorial hint moved to the bottom edge, between the touch controls; before, it
  overlapped the toast column.
- The new card slot sits on the left, at 42% of the screen height. Checked on a Galaxy A16
  (685×338 viewport): it stays clear of the thumbstick, banner and prompts.

### Instrumentation

`src/server/SessionStats.luau` tracks each player's first session in memory. It records time
from joining to first pickup, sale, upgrade and survived storm; every trip (start, sale, coins,
items by rarity, time from last pickup to sale, Storm Core or not, and lost bags); deaths
before the first upgrade; and whether the player went out again after selling. One summary
line is printed when a player leaves, and `StormSalvageDebug:Invoke("session")` returns the live
report. It doesn't sample every frame and saves nothing.

New Studio-only debug commands: `spawn` (one item of any kind at a position) and `boost`
(turn on 2x Salvage, to test sale multipliers).

## Economy

### Expected value of a bag, from the spawn tables (per-item averages)

| Zone | Avg item | Bag 3 | Bag 5 | Bag 7 |
| --- | --- | --- | --- | --- |
| Town Square (closest to spawn) | 6.1 | 18 | 31 | 43 |
| Houses | 11.2 | 34 | 56 | 78 |
| Gas Station | 17.6 | 53 | 88 | 123 |
| Warehouse | 19.2 | 58 | 96 | 134 |
| Supermarket | 25.0 | 75 | 125 | 175 |
| Motel (farthest) | 36.0 | 108 | 180 | 252 |

Walking from spawn takes 17 s (Town Square) to 32 s (House 3). Value rises with distance,
which is the intended risk/reward.

### First ten minutes, before and after

| | Before (Core 250) | After (Core 175) |
| --- | --- | --- |
| First pickup | 25 s after starting | 16 s |
| First sale | 59 s (195 coins; a Mini Safe nearby) | 33 s (12 coins; three cans) |
| First upgrade | 60 s | 129 s (after 4 Town Square trips: 12, 12, 9, 26 coins) |
| Upgrades at 10 min | Backpack 3, Boots 2, Armor 2 | Backpack 2, Boots 2, Armor 2 |
| Ordinary trips | 53, 16, 36 coins | 12–36 coins early; 175–242 later with bigger bags in better zones |
| Storm Core coins / all coins sold | 1008 / 1308 (77%) | 525 / 963 (55%) |
| Time from last pickup to sale | 14–24 s | 14–23 s |
| Deaths | 0 in 4 storms | 0 in 4 storms |
| Went out again after selling | yes | yes |

**What the evidence supports**

- **Storm Cores were outearning everything else.** At 250, four cores in one trip paid more than
  every other trip combined, so ordinary salvage hardly mattered. At 175, cores are still the
  biggest single item (the best Epic, the Jukebox, is 140) and still worth a storm's risk, but
  normal trips make up almost half of income.
- **The first upgrade comes in 1–2 minutes either way.** A lucky rare nearby gets you there in
  one trip; a commons-only start takes about four short Town Square trips (about 2 minutes).
  I left the Backpack price (50) alone. The bot always takes the nearest item, so it collects
  the 2-coin cans first; real players, steered by the rarity glow, will probably do better.
  Revisit with real players.
- **Upgrade prices are unchanged.** After 10 minutes the bot had the second level of every
  upgrade, with income rising as bigger bags reached better zones. Nothing here argues for
  changing prices before real-player data.
- **Paid multipliers** (not enabled): VIP ×1.2 and 2x Salvage multiply the whole sale. At 2x,
  every upgrade above would come in half the time. That's a big advantage to review before
  real products go live (Priority 6).
- **Armor**: 15% per level, measured exactly (level 4: flood 2.0 HP/s instead of 5.0).

### Death recovery

| From the respawn point (5 s respawn) | Walk at speed 16 | Back at the bag |
| --- | --- | --- |
| Town Square | 17.4 s | 22 s |
| Gas Station | 19.5 s | 25 s |
| Supermarket | 24.6 s | 30 s |
| Houses 1–4 | 25.9–31.8 s | 31–37 s |
| Warehouse | 27.6 s | 33 s |
| Motel | 29.1 s | 34 s |

With the old 20 s window, the owner could never get back in time, so the protection didn't
really protect. 40 s covers the slowest district at base speed with a small margin, and other
players still get the last 35 s, so the competition for dropped bags remains.

## Test results

| Check | Result | Evidence |
| --- | --- | --- |
| All 11 salvage types can be collected | **Pass** | Spawned and grabbed each; the bag showed 11 items worth 572 (the exact sum). |
| Common pickup feedback | **Pass** | "+2 Scrap Can" pop, bag 1/20, no toast. `pickup-common.jpg` |
| Rare / Epic / Legendary feedback | **Pass** | Cards for Engine Block, Retro Jukebox, Mini Safe and Storm Core; the core card says to get it to the Scrap Buyer. `pickup-*.jpg` |
| Storm Core beacon and glow | **Pass** | Beacon present before the grab; the carrier glows; "grabbed a Storm Core!" sent to everyone. |
| Bag limit | **Pass** | Bag 3/3: two more grabs refused; one "Bag full!" toast, not two. `bag-full.jpg` |
| Two players, one item | **Pass** | One player got it. |
| Receipt matches the server | **Pass** | Solo: 11 items, total 572, "+7 more" = 107, balance 900 → 1472. Two clients selling at once: P1 +15 → 2130, P2 +22 → 299; each got exactly one receipt matching its balance. |
| Multipliers | **Pass** | 2x Salvage: base 17 × 2 = total 34, shown as a "2x Salvage x2" line. `sale-receipt-boost.jpg` |
| No duplicate sales | **Pass** | Selling again with an empty bag gave no receipt and no coins ("Your bag is empty"). |
| Upgrade levels | **Pass** | Backpack to 20 slots; Boots 18/20/22/24, then refused; Armor to level 4, 60% reduction measured; total spent 10,475 = sum of all costs. |
| Death drop and recovery | **Pass** | Owner window 39 s at drop; another player was refused at 8 s and 33 s and got it at 45 s; reach 16; "YOUR BAG 33s" seen from the hill. `your-bag-from-hill.jpg` |
| Storm Cores in all three storms | **Pass** | The autopilot collected one in a windstorm, a flood and a lightning storm. |
| Late joiner sees the true flood state | **Pass** | Player3 joined at level 8: "Water 8/12 - rising in 4s" while their own terrain read about 10, then "at its peak" once at 12. |
| Saving | **Pass** | Player2 left: stored coins 299, items sold 3, lock released. Player1 loaded the coins saved in earlier sessions. |
| Phone-size viewport | **Pass (simulator)** | Galaxy A16 (685×338): Epic card, pop and HUD readable; shop fits, with affordable and unaffordable states clear. `phone-a16-*.jpg` |
| Server performance | **Pass** | Solo with the autopilot playing: heartbeat median 16.6 ms, p99 18.0 ms, max 18.8 ms. |
| Lint, format, types, Rojo build | **Pass** | selene 0 errors, StyLua, luau-lsp clean, `rojo build` OK. |

### Defects found and fixed

1. **Bag protection didn't protect**: 20 s was shorter than any walk back. Now 40 s (75 s total).
2. **Dropped bags under a flood were out of reach** from the water's surface (reach 10). Now 16.
3. **Storm Cores dominated income** (77% of coins in the baseline run). Value 250 → 175.
4. **Toast spam** on repeated "Bag full!". Repeats now refresh one toast.
5. **Hint overlapped toasts** at the bottom of the screen. Moved to the bottom edge.
6. **The core announcement showed the whole sale total**, not the core's value. Fixed.
7. **The receipt card reached the thumbstick** on tall receipts. Moved up.

## Not verified

- **Real players and real phones.** Only the Studio device simulator was used; there were no
  touch tests on hardware and no client frame-rate measurement on a device.
- **Sound.** Pickup pitch rises with rarity, and selling and cores have louder or higher
  sounds, but nobody has listened to them.
- **The core light column and bag beacon** are thin and hard to see from far away in captures.
  The labels read well.
- **Two autopilots competing for loot** wasn't run: multiplayer test players load saved
  profiles (with coins), and wiping those keys is a destructive DataStore change I left for a
  separate test experience.
- **Purchase concurrency** (spending a pending grant during its save) and replaying the
  exact same failed receipt remain open before real products go live.
