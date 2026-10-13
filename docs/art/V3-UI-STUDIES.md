# V3 UI direction studies (D reset)

Instrument and Stencil are rejected as final directions; Instrument remains the functional
baseline in the shipped HUD. Three new directions were built as complete, separate interfaces
and captured in Studio Play on 2026-10-13. **No direction has been chosen or implemented.**

Comparison board (private artifact): https://claude.ai/artifact/WRUKyXa2yV8GmgX2oWE4Ge
Captures: `docs/art/v3/ui/studies/<direction>-<screen>.jpg`.

## How the studies run

Studio only (`src/client/UIStudies.luau`; nothing is reachable in a live server). Set
ReplicatedStorage attributes at runtime:

| Attribute | Values |
| --- | --- |
| `UIStudy` | `Adventure`, `Chaser`, `Workshop`, or unset for the normal HUD |
| `UIStudyScreen` | `hud`, `shop`, `receipt`, `rarity` |
| `UIStudyRarity` | a `Config.Loot` id (default `Safe`) |
| `UIStudyDevice` | `desktop` or `phone` (844 × 390 pt layout preview at UI scale 0.7) |

The HUD is live: coins, bag contents, carried value, storm phase, timer and objective. A real
pickup or sale also triggers that direction's rarity reveal and receipt. With no sale yet, the
receipt screen uses `UIStudyKit.SampleReceipt`. The shop is visual only and its buttons don't buy.

| Direction | Module | Idea |
| --- | --- | --- |
| Salvage Adventure | `StudyAdventure.luau` | Sticker plates with thick outlines, a weather dial and ribbon, a quest scroll, a Trading Post with tilted cards, a coin-burst receipt and gem rarity |
| Storm Chaser | `StudyChaser.luau` | Navy glass with corner brackets, a live radar (the blip closes in during the warning), a news chyron, an Equipment Loadout with spec bars, a tabular haul report and CAT 1–5 rarity |
| Scrapyard Workshop | `StudyWorkshop.luau` | A cardboard cash tag, a wooden crate bag, a tin sign with a flip clock that swings in storms, sticky notes, a pegboard shop with hanging tool tags, a clipboard tally and tape-grade rarity |

## Captures

| Screen | Adventure | Chaser | Workshop |
| --- | --- | --- | --- |
| HUD, Calm | yes | yes | yes |
| HUD, Lightning warning | **not captured** (the phase ended) | yes | yes |
| HUD, Lightning storm | yes | yes | yes (scrapyard; a strike killed the character in town) |
| Gear Shop | yes | yes | yes |
| Sale receipt | yes | yes | yes |
| Rarity reveal (Epic, plus the tier ladder) | yes | yes | yes |
| Phone layout preview | yes | yes | yes |

## Assessment (judgement from the captures, 1–5)

| | Adventure | Chaser | Workshop |
| --- | --- | --- | --- |
| Visual quality | 4 | 4 | 4 |
| Readability | 5 | 3 | 4 |
| Originality | 2 | 3 | 5 |
| Mobile usability (layout preview, not device) | 4 | 3 | 3 |
| **Total** | 15 | 13 | 16 |

**Adventure:**
- Most readable, with rarity coded three ways.
- Least original: it uses the common simulator-game dialect.
- The top-centre dial, banner and storm bubble take a lot of phone height.

**Chaser:**
- The radar is the best storm read, and the Loadout is the clearest shop.
- The scrolling chyron can hide the safety instruction mid-scroll.
- Labels drop to about 8 pt on phones, and the tone is cold for this audience.

**Workshop:**
- Most original and most specific to Storm Salvage; the pegboard shop and clipboard tally are the strongest screens.
- During a storm the left column reaches the phone thumbstick zone.
- Handwriting slows reading of key numbers.
- Price stickers are small, and the sign swing needs a reduced-motion off switch.

## Recommendation (awaiting your decision)

Choose Scrapyard Workshop, with three fixes before it replaces the HUD:

1. a compact phone layout (the notes merge into one strip)
2. a plain bold face for every number, keeping handwriting for labels
3. reduced motion stops the swing and the drop, and the price numerals get larger

Adventure is the safer second choice if readability for the youngest players outweighs identity. Chaser's radar blip is worth borrowing as the storm countdown either way.

## Still to do after the choice

- Wire the chosen direction into the real `Hud`, `Shop`, `SalvageFeedback` and `Notifications`, including buying, reduced motion, the onboarding chain and notices.
- Delete the two studies that weren't chosen.
- Verify on physical phones.
