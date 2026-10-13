# V3 UI: Scrapyard Workshop (implemented)

You approved this direction on 2026-10-13. It is Scrapyard Workshop, with Storm Chaser's weather hierarchy and Salvage Adventure's accessibility (see `V3-UI-STUDIES.md`). It is now the real game UI on `v3-art-direction`. The study modules have been removed and their captures are kept in `docs/art/v3/ui/studies/`.

## What changed (presentation only)

The server, economy, remotes and save logic are unchanged. Every number the UI shows comes from `PlayerState`, `StormState`, `Pickup` and `SaleReceipt`.

| Piece | File | Design |
| --- | --- | --- |
| Theme | `UI.luau` (`Workshop`, `UI.Mat`) | Replaces Instrument and Stencil. Marker lettering is for titles only. Every number (coins, prices, timers, counts) uses the bold plain face (GothamBlack). |
| Coins | `Hud.luau` | Cardboard cash tag. Counts up on a gain and floats the difference. |
| Bag | `Hud.luau` | Wooden crate with one slot per capacity, each coloured by the rarity of what's in it. Shows "SELLS FOR n" and turns red at "FULL n/n". |
| Storm | `Hud.luau` | Tin sign with a band in the storm's own colour, the storm name, and mm:ss flip tiles. The tiles turn red in the last 3 s. |
| Survival orders | `Hud.luau` | A paper strip under the sign with the live line ("GUST IN 0.6S"), the full storm instruction and the Storm Core count. It never scrolls and stays on screen for the whole warning and storm. It steps aside only while the shop or settings is open, and the sign keeps the countdown. |
| Objective | `Notifications.luau` | Sticky note ("TO DO") with plain bold text. It hides during storms, danger alerts, open menus and event cards. |
| Finds | `SalvageFeedback.luau` | Common: a value pop. Uncommon: a pop plus a few sparks. Rare: a manila tag with blue grade tape. Epic: the tag plus an "EPIC" stamp. Legendary/Storm Core: the tag plus a gold star and a "get it to the Scrap Buyer alive" reminder. Tags sit at the screen edge, never over the play area. |
| Sale | `SalvageFeedback.luau` | Clipboard tally: itemised lines with rarity chips, bonuses in red pen, the payout circled as the biggest number, a "PAID" stamp, and the new balance. |
| Gear Shop | `Shop.luau` | Pegboard with three hanging tool tags (level punched in, price sticker that is orange if affordable, grey if not, green MAX). A spec sheet then gives, in order: name, level, description, now → next, level track, your coins, BUY. "INSTALLED" stamps only after the server confirms. |
| Buttons | `Hud.luau` | Manila "GEAR SHOP" tool tag and a riveted tin Settings plate, on the right edge. |

## Phone layout

The phone layout is a separate composition (`UI.compact()`, used on touch devices), not the desktop one scaled down:
- Cash and crate share one short row at the top left.
- The sign and orders sit right of centre.
- The objective joins the stack under the sign.
- Event cards appear on the right, left of the button rail.
- District titles yield to cards.

Roblox's dynamic thumbstick starts anywhere in the left 40% of the bottom two thirds. The jump button is 70 pt, 95 pt from the right and 90 pt from the bottom.

Studio preview: set the ReplicatedStorage attribute `QA_PhoneFrame = true` during Play. It lays the HUD out at 844 × 390 pt with an approximate top bar and draws both control zones in red.

## Reduced Effects

When Reduced Effects is on, the following are switched off:
- the sign's calm sway and phase jolt (rotation measured at exactly 0° with it on, and ±0.8° with it off)
- card tilt and slide-in
- stamp thumps
- count-ups
- scale pops

Particle bursts drop to a third. Every warning and card still shows.

## Runtime QA (Studio Play, disposable `_STUDIO` profile, 2026-10-13)

| Check | Result |
| --- | --- |
| First pickup (Scrap Can) via the real ProximityPrompt | Crate 1/3, grey slot, "SELLS FOR 2", objective updates |
| Rare find (Cash Register) during a natural Lightning warning | Blue RARE FIND tag; the sign reads LIGHTNING STORM COMING with the instruction strip (`01`) |
| Epic find (Mini Safe) during the storm in town | EPIC tag and stamp; FULL 3/3 in red; live line "STEP OUT OF RED CIRCLES!"; Storm Core count (`02`) |
| Death by lightning in town | Bag dropped; crate back to EMPTY 0/3; HUD consistent. The screen went black after the death and respawn. Lighting and camera were normal and stopping Play cleared it. Cause not found yet (see open items) |
| Storm Core sale | Server values 175+90+45 = 310; 420 → 730; STORM CORE DELIVERED (`03`) |
| Mixed sale with "+1 more" | 90+45+30+22+4 = 191; 950 → 1,141 |
| Purchase via a real button click | Backpack level 0 → 1, 730 → 680, INSTALLED only after server state (`05`) |
| Insufficient funds | NEED 120 MORE; the server notice moves to the top right while the menu is open (`06`) |
| Max level | Four purchases to Backpack 5/5; MAX sticker; MAXED OUT; 20 slots (`07`) |
| Wind storm, phone layout | Live gust line + instruction + danger alert, all clear of the thumbstick and jump zones (`09`) |
| Flood storm, phone layout | "WATER 4/12 · RISING IN 6S" plus the instruction |
| Phone sale | 175+90+15+2 = 282; 1,248 → 1,530; clipboard on the right, clear of both zones (`12`) |
| Reduced Effects toggled through the real Settings button | Sway 0.000° when on, 0.800° when off |
| Shop opened and closed 21 times | 1,012 PlayerGui instances before and after (no leak from menus) |
| Console | No errors or warnings from game scripts |

Captures are in `docs/art/v3/ui/workshop/`. Files `10` and `11` show phone problems from before their fixes: the orders strip touching the thumbstick zone, and the district title over the clipboard.

## Open items

1. **Black screen once after a death** (not reproduced). It happened right after my scripted teleport to just behind the Scrap Buyer counter at (-32, 32, -265).
   - A forced death during a Lightning storm, followed by a respawn, rendered normally (`13`).
   - The likely cause is the camera ending up inside the counter's mesh after the scripted teleport. That is a QA-script artefact, not a UI or storm bug, but it isn't proven.
   - Re-check during the multiplayer and bot soak.
2. **Physical-device check:** the phone results come from the Studio preview only. On real phones, check thumbstick clearance, text size, notch and safe areas, and Settings scrolling. Needs a published private test place.
3. **Before/after:** the before captures are in `docs/art/v3/ui/` (Instrument `conceptA-*`, `gear-shop-current.jpg`, `sale-ticket-first-pass.jpg`); the after captures are in `workshop/`.
4. Settings is still the generic modal (dark plate) and wasn't re-dressed, though it's functional.
5. On phones, "NEXT STORM IN" wraps to two lines. It is readable but could be shortened.
