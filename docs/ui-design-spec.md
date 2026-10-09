# Storm Salvage UI design spec

The rules every screen, card and sound cue follows. The tokens are implemented in
[`src/client/UI.luau`](../src/client/UI.luau) and the audio routing in
[`src/client/Audio.luau`](../src/client/Audio.luau), so new UI should use those rather than
setting colors and sizes by hand.

## Direction

Chunky, warm, industrial salvage: heavy rounded plates with a dark outline, bold rounded
display type, warm yellows and oranges for money and salvage, cool blues and storm colors for
danger. The world is the star: the HUD stays at the edges and only grows when something needs
the player's attention right now.

## Layout

All HUD elements sit inside one root frame inside Roblox's safe area (`ScreenInsets =
CoreUISafeInsets`), scaled by a single `UIScale`. Sizes below are in design pixels before
that scale.

```
+-------------------------------------------------------------+
| [Roblox]        [ STORM STRIP: name . status . time ]       |
|                 [ danger alert / district title  ]          |
|                                                [ coins    ] |
| [ event card ]                                 [ bag  2/5 ] |
| [  (finds,   ]                                 [SHOP][SET ] |
| [  receipts) ]                                              |
|                     feed (server notices)                   |
|  (thumbstick)         tutorial hint             (jump)      |
+-------------------------------------------------------------+
```

| Region | Position | Contents |
| --- | --- | --- |
| Storm strip | top centre, 8 px down | Phase, storm name, timer chip; status line only during Warning and Storm |
| Alert slot | under the strip | Personal danger (P4); otherwise the district title (P0) |
| Right rail | right edge, top at 20% of height on touch (clear of the jump button) and 30% on desktop (below the player list) | Coins, bag (count, fill bar, sell value), Shop and Settings buttons |
| Event card | left edge, centred at 46% | One card at a time: finds, bag full, sale receipt. Click to dismiss with a mouse; on touch screens it lets touches through to the thumbstick underneath |
| Feed | bottom centre, above the hint | Up to 3 short server notices |
| Hint | bottom centre | Tutorial guidance, hidden whenever anything more important is showing |
| Modals | centre at 57% of height, up to 86% tall | Gear Shop, Settings, over a dimmed backdrop. The storm strip and danger alerts stay on top |

The left third of the bottom half (thumbstick) and the bottom-right corner (jump button) stay
empty on every layout. The top-left corner belongs to the Roblox menu and chat, and the
top-right to the player list (the rail starts below it).

**Scale.** `scale = clamp(viewportHeight / 600, 0.7, 1.15)`. Phones in landscape land at
0.7, laptops at 1.0 to 1.15. Touch devices get 64 px buttons (45 pt on a Galaxy A16) and
desktops 52 px.

## Type

| Role | Font | Size | Used for |
| --- | --- | --- | --- |
| Display | FredokaOne | 28 | Receipt total, find card item name |
| Title | FredokaOne | 20 | Storm name, coin count, card headers |
| Label | GothamBold | 14 | Status lines, bag count, buttons |
| Body | GothamMedium | 14 | Receipt rows, descriptions |
| Caption | GothamMedium | 13 | Secondary details (bag value, hints in cards). Nothing smaller: 13 px is about 9 pt on the smallest phone |

Fixed `TextSize` scaled by the root `UIScale` (not `TextScaled`), so hierarchy is the same on
every screen. Text on plates has no outline; text floating over the world (pops, markers) gets
a 1.5 px dark stroke.

## Color

| Token | RGB | Meaning |
| --- | --- | --- |
| Plate | 24, 26, 32 @ 18% transparent | All panels |
| Outline | 10, 10, 14 | 2 px panel stroke |
| Text | 245, 244, 238 | Primary text |
| TextDim | 185, 188, 198 | Secondary text |
| Coin | 255, 205, 70 | Real coins only (balance, payouts) |
| Value | rarity color | Loot value, which is not money until sold |
| Safe | 110, 220, 130 | Calm, success |
| Warn | 255, 172, 64 | Warnings, gust coming |
| Danger | 255, 84, 70 | Personal danger, bag full |
| Water | 96, 172, 255 | Flood |
| Storm colors | per storm in `Config.Storms` | Strip accent during that storm |

Gold is reserved for coins the player actually has. Carried loot is shown as "value" in
rarity colors, so "Mini Safe · 90 value" never reads as money earned.

## Shapes

- Radii: 6 (chips, bars), 10 (panels, cards, buttons), 14 (modals).
- Panels: Plate fill, 2 px Outline stroke. Cards add a 6 px rarity or event accent bar on the left.
- Spacing: 4 / 8 / 12 / 16. Panel padding 10–12.

## Buttons

- Minimum touch target: 64 design px on touch devices (about 45 pt on the smallest phone
  tested) and 52 px on desktop.
- States: rest, hover (desktop: lighten 8%), press (scale 0.94 for 0.08 s, click sound),
  disabled (gray, no sound).
- Primary actions are green (buy), secondary are slate, and closing is a plain X on the plate.

## Motion

| Token | Duration | Easing | Use |
| --- | --- | --- | --- |
| Press | 0.08 s | Quad out | Button press |
| Enter | 0.22 s | Quint out (Back 1.05 for cards) | Cards, modals, strip expanding |
| Exit | 0.18 s | Quad in | Cards and toasts leaving |
| Count | 0.5 s | Quad out | Coin balance and receipt totals counting up |
| Pulse | 0.6 s period | Sine | Danger alert, timer chip in the last 3 s |

No full-screen flashes (the lightning flash is capped at 35% brightness and off with Reduced
Effects), no camera shake, no bounce beyond 1.08. With Reduced Effects on, scale and slide
animations become plain fades, and pulses stop.

## Notifications

One place per kind of message, with explicit priorities:

| Priority | Kind | Slot | Rule |
| --- | --- | --- | --- |
| P4 | Personal danger ("MOVE! Lightning...") | Alert slot | Always shown; replaces the district title |
| P3 | Storm phase | Storm strip | Strip expands during Warning and Storm |
| P2 | Event cards | Card slot | Receipt and Storm Core cards can't be bumped by a lower-priority card for 1.5 s; a bumped card waits (one pending) |
| P1 | Server notices | Feed | Max 3, duplicates refresh instead of stacking |
| P0 | Hint, district title | Bottom / alert slot | Hidden while a storm warning or storm, a danger alert, or a modal is up |

Common pickups never use a slot; they get a world-space pop where the item was.

## Sound

Three `SoundGroup`s under `SoundService`: Master, with Effects (UI, pickups, sales, warnings)
and Weather (rain, flood, wind, thunder) beneath it. Settings drive the group volumes.

- Every cue has a minimum repeat interval (pickups 0.08 s, cards 0.25 s) so fast collecting
  doesn't stack sounds.
- Rarity is told by different sounds, not just volume: common is a bag thump; Rare adds a
  soft chime; Epic adds a bigger shimmer; a Storm Core adds a bell-tree sparkle.
- Each storm has its own warning identity layered on the shared siren: wind is an airy
  whoosh, flood is a water surge, and lightning is a low distant rumble.
- Loops crossfade (1 s in, 2.5 s out) instead of cutting.

## Accessibility

- Text contrast on plates is at least 7:1 for primary text.
- Color is never the only signal: rarity cards also say "RARE" or "EPIC", and danger alerts
  have words.
- Reduced Effects: no lightning flash, no tree sway, half the wind streaks, no UI scale or
  slide motion.
