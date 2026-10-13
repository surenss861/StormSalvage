---
related-code:
  - "[[LookService.luau]]"
domain: world
type: spec
status: stable
tags: [storm-salvage, world]
---
# Storm Salvage V3: world consistency pass

After C1-C5, the town walked as one place (overview plus ground-level views from the central
junction). Studio only; evidence in `docs/art/v3/world/`.

## The ten highest-impact weaknesses, in order

| # | Weakness | Action |
| --- | --- | --- |
| 1 | **Draw distance at low graphics quality.** At Automatic quality (which Studio drops to when the window is busy), elevated views lose the whole far half of town and the backdrop hills; at max quality everything renders (`overview-auto-quality.jpg` vs `overview-max-quality.jpg`). This is the real cause of the flat-edge look flagged in B. | **Device gate.** Must be judged on a phone at quality 2-3. Mitigations already in: calm haze, key landmarks within ~200 studs. Not something Studio can verify |
| 2 | Crosswalk stripes bloomed pure white at the junction (`junction-ne-before-paint.jpg`) | **Fixed**: worn off-white road paint |
| 3 | Large flat lawns between the Supermarket, the road and the Fuel & Go | Open space is deliberate storm-exposure ground; leave, revisit in playtest |
| 4 | V2 Supermarket and Fuel & Go shells are plain flat-roofed boxes next to the V3 Houses | Acceptable at player height; their storefronts and interiors carry the identity. Backlog |
| 5 | Motel facade shows 8 doors while the inside has 6 rooms | Backlog (C5 note) |
| 6 | Cracked-concrete material is very busy on Fuel & Go walls and ceilings (C3 review note) | Backlog; compare with the supermarket's quieter surfaces in a material pass |
| 7 | Compressor hose detached | Fixed in Blender; re-import pending |
| 8 | Street lamps glow in full daylight | Minor; they double as storm lighting |
| 9 | Scrap Buyer sign partly hidden by the gantry from the default spawn view (B backlog) | Backlog, low severity |
| 10 | Fountain spray hard to read (B backlog) | Backlog, low severity |
