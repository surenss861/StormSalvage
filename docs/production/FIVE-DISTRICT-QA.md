# Five-district build: precise production and QA gates

## Current geometry contract

Existing `MapBuilder.luau` building centers and sizes (studs):

| District | Center X,Z | W,H,D | Door face | Existing gameplay constraint |
|---|---|---|---|---|
| Supermarket | 120,-80 | 70,18,50 | S | Interior loot grid; original edge shelves |
| Gas Station | -120,-80 | 40,14,30 | S | Forecourt canopy is a tagged shelter |
| Warehouse | 125,90 | 70,22,60 | N | Roof/truss is current flood escape |
| Motel | 0,165 | 110,14,30 | N | Front awning currently provides shelter |
| Town Square | -50,-55 | 60×60 plaza | Open | Fountain center prevents loot spawn |

The shells are decorative, and may not have collision. Keep invisible base-part walls,
floors, shelter roof and ladder geometry until a tested replacement exists. The
motel's secondary mesh doorways are decorative until matching real wall openings,
room partitions and door interactions are separately built and tested.

## Import and art QA

- Confirm all 49 FBX exports exist, plus five `.blend` files and 49 per-model previews.
- Open each `.blend` and inspect silhouettes, pivot at ground center, face winding,
  normals, material splits, correct swatch naming and maximum individual mesh tris.
- Maintain existing art-direction rule: oversized readable geometry, no fragile thin
  props, warm town / cold storms, landmark visibility at ~100 studs.
- Verify asset dimensions in real Studio by comparing with an R15 avatar.
- Verify no duplicated buildings, canopies, signs, fountain or siren left visible
  after replacing existing primitive geometry.
- Check door widths, collision, shelter queries and loot spawn clearance in each
  district after every integration pass.
- Confirm client memory, load time, material draw calls and shadow costs on a phone.

## Per-district in-game tests

### Supermarket
- Enter the main door; navigate a full aisle and the backstock area.
- Pick up a common and a rare item without standing inside a shelf.
- Stormwater must not create an inescapable dead end. Shelving cannot block
  evacuation or the exterior exit; visual aisles must match simple collision.
- Test sight lines and pickup prompts behind shelf units.

### Gas Station
- Walk under the canopy and verify wind/lightning shelter semantics.
- Reach both pumps and the convenience-store counter.
- Preserve navigation around the original pumps while replacing their visuals.
- Verify warning effects and readable escape paths across the exposed forecourt.

### Warehouse
- Navigate racks, moving equipment and loading dock without trapping the avatar.
- If a mezzanine is made walkable, add separate simple collision and a reliable
  route from ground level; verify flood escape on it.
- Ensure the high-value items remain reachable, not hidden in visual-only crates.
- Test any ladder/truss still works after shell replacement.

### Motel
- Enter the actual gameplay doorway and reach all intended active rooms.
- Decorative doors must not imply accessible content if they are closed.
- Verify awning shelter with two players and confirm no roof visual blocks the way.
- Check beds, dressers and vending machines don't block active loot points.

### Town Square
- Confirm the fountain remains consistent with the existing exclusion radius.
- No imported prop may block storm cores or lightning warning visibility.
- Clock tower and siren must not overlap the existing siren/road system.
- Verify plaza escape routes on foot and during lightning.

## Publish/testing gates

Technical: DataStore real save/rejoin, two-player pickup race, dropped-bag
20-second owner exclusivity, moving storm round join, zero serious console
errors, acceptable low-end device FPS, no duplicate visual layers.

Experience: 3–5 new players can find a first item and sell it unaided, understand
storm warnings, and demonstrate willingness to play another storm cycle.
Record actual findings; do not pretend a green compiler test replaces them.
