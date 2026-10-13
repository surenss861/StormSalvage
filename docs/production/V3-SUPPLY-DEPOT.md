---
related-code:
  - "[[Tools.luau]]"
  - "[[DetectorHud.luau]]"
  - "[[DetectorService.luau]]"
  - "[[Detector.luau]]"
  - "[[Shop.luau]]"
domain: salvage-economy
type: spec
status: wip
tags: [storm-salvage, salvage-economy]
---

# V3 Supply Depot: Tools tab and the Salvage Detector

**Status:** in **RC7** (`rc-20261013-7`, commit `e3d1ab9`), approved by the owner for private gameplay testing. Not deployed: the live private place still runs RC6 until a separate deployment approval. Robux purchases stay off (`PurchasesEnabled = false`, every product ID is 0).

The owner's directive was to expand the existing Gear Shop rather than build a second shop. The shop now has three tabs, in this order:

| Tab | Pays with | What's there |
| --- | --- | --- |
| **Equipment** | Coins | Backpack, Running Boots, Storm Armor (unchanged) |
| **Tools** (new) | Coins | Permanent tools. Phase one: the **Salvage Detector**, 2,500 coins |
| **Supply Counter** | Robux | 3 coin packs and the Heavy-Duty Pack (unchanged, still disabled) |

Staged discovery is unchanged: a new player sees only Equipment. **Tools** and **Supply Counter** appear after the first equipment upgrade.

## Salvage Detector (phase one)

**What it does.** Owners get a small dial in the lower right of the HUD; on phones it sits bottom centre-right, clear of the thumbstick and jump zones.
- The centre of the dial is you, and up is where the camera faces.
- Up to **3 blips** mark the nearest **ordinary salvage** within **55 studs**, even behind walls.
- The readout says how far the nearest one is ("SALVAGE 15m"), or "NOTHING NEAR".
- Price: **2,500 coins**, permanent. That's about 24% of all equipment (10,475) and roughly 20–30 minutes of early play.

**What it never does** (the server enforces this; the client only draws what it's sent):
- It never reveals **Epic finds or Storm Cores**: only Common, Uncommon and Rare. The high-value finds still need exploring.
- It never reveals a **dropped bag**, whether yours or another player's.
- It never collects anything, never extends pickup reach, and never touches the prompt distance checks.

**How it's built:**

| Piece | File | Notes |
| --- | --- | --- |
| Rules (pure) | `src/shared/Detector.luau` | `pick`: filters out dropped bags and other rarities, keeps what's in range, returns the nearest `max`. `sameSet` checks whether the set changed. Unit-tested. |
| Scanner | `src/server/DetectorService.luau` | Runs once a second for each owner. Gathers the loot list once per tick and shares it across all owners. Sends `DetectorPing` (X/Z only) **only when the set of blips changes**. |
| Purchase | `PlayerService.buyTool` | Rate limit of 8/s, shared with upgrades. Checked by `Economy.checkTool`. Coins and ownership change together in the session profile, so they save, or fail to save, together. |
| Save | `Data.Tools = { Owned = {} }` | Added to `DataService.default()`. Older profiles get it from reconcile. Older code keeps the table untouched, because it saves whole tables (the same rollback behaviour as the RC4 fields). |
| UI | `src/client/Tools.luau`, `src/client/DetectorHud.luau` | Workshop pegboard tag and spec sheet with an OWNED stamp. The dial is drawn on the HUD. Reduced Effects turns off the sweep. |
| QA | `DebugService.cleartools` | Studio only. Debug `state` now lists tools. |

## Studio tests (2026-10-13, `_STUDIO` store, real remotes and real clicks)

| Test | Result |
| --- | --- |
| Buy with 2,400 coins | Refused: "Need 100 more coins." Nothing changed. |
| Hostile `BuyTool` input: nil, a table, a 5,000-character string, unknown "Radio", a number, wrong case "detector" | All ignored, no change, no server errors |
| **5 buy requests in the same frame** with 3,000 coins | **Charged once** (3,000 → 500). Owned. The other 4 were refused as already owned. |
| **Real mouse click** on BUY (2,750 coins) | −2,500 → 250 coins, "Salvage Detector unlocked!", OWNED stamp, dial on the HUD at once |
| Save, stop, start | 500 coins and Detector owned, restored |
| Epic Safe at 2 m, Storm Core at 3 m, Can at 6 m | First blip the Can at 6 m. The Safe and the Core were **never sent**. Readout "SALVAGE 6m". |
| Died with 3 items; the bag lay 5–7 m away | The bag items were **never sent**. Blips went to ordinary salvage 15 m+ away. |
| Dial in Calm, Lightning and Flash Flood; Tools tab on desktop and in the phone preview | Readable in every case (captures under `docs/art/v3/ui/tools/`) |
| Server cost | One scan of 63 loot items took 0.083 ms. 12 owners at 1 Hz is under 1 ms per second, and the shared loot list makes it less. |
| Unit tests | 33 pass, including 7 new ones: detector rules, and the tool purchase check |

| **Rollback:** RC6 code (no tools) loads a profile that owns the detector, changes coins and saves | Saved (coins 4,321) and **`Tools.Owned.Detector` kept** |

**Not yet tested:**
- a real phone
- with real players

## RC7 pre-tag verification (2026-10-13, owner's checklist)

All checks ran on exact commit `e3d1ab9`, loaded into Studio. No code changes were needed, so RC7 is tagged on that commit.

| # | Check | Result |
| --- | --- | --- |
| 1 | Branch commit and CI | HEAD = origin = `e3d1ab9`, clean tree, CI passed. `main` still `0ef9465`. |
| 2 | Release artifact | Inspected below |
| 3 | Persistence and RC6 rollback | **Round trip:** bought under the new code, then RC6 loaded and saved the profile (coins changed to 4,321), then the new code loaded it again: **Detector still owned**, 4,321 coins. Earlier: save, stop, start restored ownership. |
| 4 | Client cleanup | After 3 deaths and respawns plus 5 shop open/close cycles: 1 HUD, 1 client Main, 1 dial, 1 Tools view, blip frames at most 3, dial still live. The scan loop (server) and the listeners (client) are created once, at startup. |
| 5 | Scan rate and cost at 12 owners | Fixed **1 scan per second**. During a live Lightning storm, 87 loot items (3 natural Storm Cores, plus an Epic Safe and a Storm Core beside each of 12 owner positions): **0.168 ms per tick for 12 owners**, about 0.02% of one core. Real pings while moving through town: **0.58/s** (35 a minute, about 1.4 KB a minute). Standing still sends nothing. |
| 6 | Only owners get data; nothing excluded leaks | Non-owner moving through town for 20 s: **0 pings**, no dial. Owner standing beside each placed Safe and Core: 6 pings, 15 blips, **0** at Epic or Core positions. Simulated: 13,500 blips for 12 owners, **0** Epic or Legendary. |
| 7 | Studio multiplayer (2 clients) | **Both clients connected** this time. Player1 bought the detector (2,600 → 100); Player2 didn't. Walking side by side for 20 s: **Player1 11 pings, Player2 0**, and Player2 had no dial. **Player2 picked up the Toaster** Player1's dial pointed at (a real prompt press): Player1's next ping dropped it within a second. Player2 sees Player1's nameplate ("Player1 / Storm Runner"), the first two-player check of nameplates. |

Studio frame-rate and memory figures (14 fps, 4.5 GB) come from the Studio process under MCP control; they don't measure the game or a device.

### RC7 artifact

- **File:** `StormSalvage-rc-20261013-7-e3d1ab9.rbxl` (CI run 38469329110, release-candidate workflow passed)
- **SHA-256:** `61c51a90eeb727da8702dac833140391bfe0d030c2dcbe685ffcf262f270e097`
- **Inside the file:**
  - `LiveTestMode = true`, `PurchasesEnabled = false`, **0** product IDs
  - `ProductionPlaceIds = { 99653875913460 }`, Heavy-Duty +2
  - Detector 2,500 coins, 55 studs, 3 blips
- **Contents:** 51 scripts and **no QA scripts**: no autopilot, soak or harness scripts, and no QA attributes. The asset pivot table matches the assets.

### RC7 vs RC6 (`8ec7259..e3d1ab9`)

- **New:** `shared/Detector` (rules), `server/DetectorService` (scans), `client/Tools` (the tab), `client/DetectorHud` (the dial).
- **Changed behaviour:**
  - `PlayerService`: `buyTool`, `ownsTool`, `Tools` in the player state
  - `Shop`: three tabs
  - `Economy`: `checkTool`
  - `Config`: `Tools`
  - `Remotes`: `BuyTool`, `DetectorPing`
  - `DataService`: `Tools` default
  - `LootService`: a `folder()` getter
  - `SessionStats`: a `Tool_` event
  - `DebugService`: `cleartools` and tools in `state`, both Studio only
  - `Main` (server and client): wiring
- **Comment-only:** Code Graph headers in the other 36 scripts.
- **Unchanged:** receipts, purchase handling, save locks and every RC3+ purchase-safety path. The new `Tools` table follows the existing save rules.

## Gameplay impact (measured)

**The question:** does the detector make ordinary salvage runs easier, without making them trivial?

**The bot.** The old economy bot always knew where every item was, so a detector couldn't change anything for it. The QA autopilot now has a sight setting (`QA_BotSight`):
- **eyes:** it knows only loot within 60 studs with a clear line of sight. With nothing in view, it walks to a random street point and looks again.
- **detector:** the same, plus exactly what the real `DetectorPing` sends.

**The runs.** Each was about 10 minutes, from a fresh profile, with the same seed for the paired runs. The bot ignores storms on purpose.

| Seed | Bot | Pickups | Found by detector | Coins earned | Sales | Storm Cores | Time searching streets | Equipment at the end |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 42 | eyes | 40 | n/a | 615 | n/r | n/r | 350 s (58%) | B2 S1 A1 |
| 42 | eyes + detector | **51** | 17 | 1,405 | 835 | 1 | **242 s (39%)** | B3 S2 A2 |
| 7 | eyes | 41 | n/a | 1,190 | 760 | 3 | 247 s (40%) | B2 S2 A2 |
| 7 | eyes + detector | **51** | 11 | 1,506 | 966 | 2 | **226 s (37%)** | B3 S2 A2 |

(n/r = not recorded for that run.)

**Findings:**
1. **A consistent gain in salvage collected: +28% and +24%** pickups on the two seeds. That's the detector doing its job: 11–17 of 51 pickups were found through it, items the bot couldn't see.
2. **The income gain is real but noisy: +27% to +128%.** Storm Cores dominate the variance. On seed 7 the plain bot found 3 cores to the detector bot's 2 and still finished behind. Seed 42's +128% is partly luck (the detector bot's run had a 237-coin core trip) and partly compounding: more early sales, a bigger bag sooner, more per trip.
3. **It doesn't make the game trivial.** Even with the detector, the bot spent 37–39% of its time searching; the detector cut street searching by 8–31%. Epic finds and Storm Cores still came only from looking around.
4. **This bot searches badly**: it picks random street points. A real player who knows the town wastes less time searching, so expect a **smaller** gain for people than for the bot. Measure it in the private test (SessionStats records the purchase as `Tool_Detector`).

**Price check.** Early income is roughly 60–140 coins a minute. At about +25%, 2,500 coins pays for itself in about 1.5–3 hours of play. It's a mid-term goal, bought after the first equipment levels, comparable to Backpack 5 (2,500).

**Recommendation:**
- Keep 2,500 coins, 55 studs, 3 blips, ordinary salvage only.
- Don't build the Magnetic Grabber or the Advanced Salvage Detector until real players have used the detector. A bigger range would mostly sell search time that's already reduced.

## Designed, not shipped

Each of these needs the detector's results and the owner's go-ahead before it's built.

**Coin tools:**
- **Storm Radio (proposed 3,500 coins).** An earlier, short heads-up about the next storm type and what to do, before the normal warning phase. Free players keep every standard warning.
- **Magnetic Grabber (proposed 5,000 coins).** A small extra pickup reach, for example 10 → 12 studs for ordinary salvage only. The server's `isNear` check would have to use the owner's real reach, so the client can't fake it. It's a direct power increase, so build it last and measure it like the Heavy-Duty Pack.

**Robux products** (specs only, nothing created on Roblox):
- **Advanced Salvage Detector (proposed 199 R$ pass).** It would require the coin detector first. The ideas are a larger range (55 → 75) and a direction arrow to the nearest blip. Same reveal rules: never Epic, Storm Cores or bags.
  - **Risk:** this sells a search advantage, so set it only after the free detector's effect is known.
- **VIP Salvager (proposed 249 R$ pass).** Cosmetic only: an outfit, an exclusive nameplate finish, a title and a pickup effect. No coin, XP or storm multipliers. It fits the existing nameplate system.

**Ruled out:**
- paid invulnerability
- paid-only Storm Cores
- automatic collection
- paid revives
- damage advantages
