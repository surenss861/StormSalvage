---
related-code:
  - "[[Hud.luau]]"
  - "[[EventStrip.luau]]"
  - "[[Notifications.luau]]"
  - "[[UI.luau]]"
domain: ui
type: spec
status: wip
tags: [storm-salvage, ui, hud, v4]
---

# V4 HUD: Storm-Scarred Arcade

The owner's direction (2026-10-14): a clean, premium industrial HUD that stays restrained so the
gameplay takes centre stage, with richer full-screen menus. The concepts are visual references
(Higgsfield). This is how they map onto native Roblox GUI.

## Rules

- The middle of the screen belongs to the twister, debris warnings, extraction routes and other
  players. Nothing permanent goes there.
- **One objective strip** at the top centre. Sources submit prioritised entries; the highest
  wins the strip, at most two others shrink to pills (one on phones). Never stacked banners.
- Menus hide every strip entry except personal danger.

| Priority | Entry |
| --- | --- |
| 100 | Personal danger (lightning about to hit you, in the flood) |
| 80–95 | Your own objective: carrying a core (90, the bar is the twister's closeness), too close to the Titan (95), siphoning (88, the bar is your siphon), inside the Eye with the Heart in reach (86), cutting a lock (80, the bar is the vault's progress) |
| 55–74 | Events: wreck vault open, Eye, Titan, cache race, dropped core, rush |
| 45–50 | The storm (type, the live line, time left) |
| 30 | Storm Cores in town |
| 20–25 | Calm and aftermath |

## Layout

| Where | What |
| --- | --- |
| Top left | District chip ("GALE HOLLOW · RAIL YARD"); the objective note under it |
| Top centre | The objective strip and its pills |
| Top right | Wallet (gold, condensed numerals) with your band under it; Shop / Jobs / Menu buttons |
| Right | Server notices, right-aligned, under the buttons |
| Bottom left | Salvage bag (count, slots coloured by rarity, what it sells for) and health |
| Bottom right | Dodge (Q, cooldown ring) and Sprint (Shift) beside the detector radar; keyboard and gamepad only |
| Left middle | The find card (rarity, name, worth, bag), a few seconds |

**Phones (compact):**
- The bag and health go to the top left; the bottom left belongs to the dynamic thumbstick.
- The strip sits right of centre.
- The wallet and buttons stay at the top right, above the jump button.
- Touch keeps Roblox's own dodge button.

## Look

`UI.Arcade` tokens:

| Token | Use |
| --- | --- |
| Plate (24, 25, 29) | Panel backgrounds, ~8% see-through |
| Edge (62, 64, 71) | Panel edges |
| Amber (255, 176, 46) | Hazard, primary |
| Gold (255, 206, 74) | Wealth |
| Text, Dim | Copy |
| Health, Hurt | Health bar |

- **Type:** `UI.Heading` (Oswald Bold) for titles and numbers; Gotham for body text.
- **Plates:** `UI.arcadePlate` gives 6 px corners and a 1.5 px edge.
- **Accents:** the strip and cards carry a 5 px accent stripe in the entry's colour (storm type, rarity, event).

## Evidence (Studio)

Screenshots in `docs/art/v4/hud/`:

| State | Screenshot |
| --- | --- |
| Calm exploration | `hud-calm.jpg` |
| Carrying a Golden Core with the twister 8 m behind | `hud-carrying-core.jpg` |
| A Mythic find | `hud-mythic-find.jpg` |
| A lightning storm with the Eye and the Titan (one strip, two pills) | `strip-storm-eye-titan.jpg` |
| Studio phone frame | `strip-phone.jpg` |

**Not verified:** a real phone. The phone frame only approximates the device.

## Menus (Arcade theme)

`UI.useTheme("Arcade")` is now the default. It remaps the Workshop's `UI.Mat` tokens:

- paper and wood become dark plates;
- ink becomes light;
- tape and stickers become amber.

The Gear Shop, Jobs, Salvage Log, Settings and the cards pick it up without per-screen rewrites.

- **Hardcoded colours became tokens:** `Highlight`, `Muted`, `Locked`, `TrackOff`, `StickerText`, `Cork`, `BarTrack`, `Reward`.
- **Readable buttons:** `UI.inkOn` picks dark text on light buttons (amber, gold).
- **Bold headings:** Enum Oswald text gets the bold Oswald face.

**Salvager ID:** the player card is rebuilt to the concept:

- the earned title over the avatar portrait;
- reputation (rank, band, XP bar);
- lifetime and net worth in gold;
- records;
- three achieved badges (their best title in each category);
- "earned in the storm, never bought".

Screenshots: `menu-gear-shop.jpg`, `menu-salvage-log.jpg`, `menu-salvager-id.jpg`. In Studio the avatar thumbnail is a placeholder silhouette; check it on a live server.

## Still to do (M9)

- Richer per-screen layouts from the concepts: the Gear Shop's large gear preview and upgrade-track list, and the Salvage Log's detail panel.
- The receipt and remaining cards (Clipboard, Note, Main's tags).
- A custom E prompt.
