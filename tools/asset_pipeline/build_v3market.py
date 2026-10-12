"""V3 Milestone C2: the Super Saver supermarket. Front faces Blender -Y; origin at the base centre.

The store keeps MapBuilder's gameplay box (70 x 50 x 18, door +Z, solid back wall) and its 9 x 7
loot grid. Everything here fits around that grid:
  - shelf variants share the V2 AisleShelf footprint (12 x 2, under 7 tall), so the three shelf
    rows stay exactly where the loot rows expect them;
  - checkout counters are 1.6 x 4, made to stand in the gaps between loot columns;
  - ceiling pieces hang above 11 studs, floor clutter is under 0.4 tall and never collides.
Signs carry a "Signboard" mesh; code paints their text.

blender -b --python tools/asset_pipeline/build_v3market.py
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from kit import box, build_set, cyl, jitter, rng, sphere, wedge  # noqa: E402,F401

GOODS = ["Coral", "Mustard", "Cobalt", "Teal", "Cream", "Mint", "Terracotta"]


# --------------------------------------------------------------------------- shelf variants (12 x 2)

def shelf_freezer(c):
    """Double-sided freezer run: glass doors on both faces, cold-lit interior, frost along the
    kick plate, one cracked door taped up after the storm. Stays inside the 12 x 2 footprint."""
    box(c, "Body", "Metal", "White", (12, 1.6, 6.4), pos=(0, 0, 3.4), bevel=0.08)
    box(c, "Kick", "Metal", "Gunmetal", (12.1, 2.0, 0.6), pos=(0, 0, 0.3), bevel=0.05)
    box(c, "Top", "Smooth", "Cobalt", (12.2, 2.0, 0.8), pos=(0, 0, 6.9), bevel=0.1)
    for side in (-1, 1):
        y = side * 0.82
        box(c, "Cold", "Neon", "Mint", (11.4, 0.1, 5.2), pos=(0, y * 0.98, 3.6), bevel=0.0)
        for i in range(4):
            x = -4.5 + i * 3.0
            box(c, "Door", "Glass", "Glass", (2.8, 0.12, 5.4), pos=(x, y + side * 0.08, 3.6), bevel=0.0)
            box(c, "DoorFrame", "Metal", "Steel", (0.2, 0.2, 5.6), pos=(x - 1.5, y + side * 0.12, 3.6), bevel=0.0)
            box(c, "Handle", "Metal", "Steel", (0.15, 0.2, 1.6), pos=(x + 1.1, y + side * 0.2, 3.8), bevel=0.0)
        for z in (1.6, 3.2, 4.8):
            for k in range(5):
                if rng.random() < 0.8:
                    box(c, "Goods", "Smooth", GOODS[rng.randrange(len(GOODS))], (1.4, 0.6, 1.0),
                        pos=(-5 + k * 2.4, side * 0.45, z + 0.5), bevel=0.0)
        box(c, "Frost", "Smooth", "White", (11.6, 0.1, 0.25), pos=(0, side * 0.95, 0.75), bevel=0.0)
    for a in (35, -35):
        box(c, "Tape", "Smooth", "Mustard", (0.2, 0.05, 4.2), pos=(1.5, -0.98, 3.6), rot=(0, a, 0), bevel=0.0)


def shelf_produce(c):
    """Produce island: two tiers of angled crates each side, a misting bar, a price rail. Each
    crate holds one heaped mound plus a couple of loose fruit (cheap: it's repeated four times)."""
    box(c, "Base", "Planks", "Bark", (12, 2, 1.2), pos=(0, 0, 0.6), bevel=0.08)
    box(c, "Spine", "Planks", "Bark", (12, 0.4, 3.6), pos=(0, 0, 2.6), bevel=0.06)
    fruit = ["Coral", "Mustard", "Leaf", "Terracotta", "Mint"]
    for side in (-1, 1):
        for tier, (z, y) in enumerate(((1.5, 0.6), (3.0, 0.35))):
            for k in range(4):
                x = -4.5 + k * 3.0
                box(c, "Crate", "Planks", "Sand", (2.8, 0.9, 0.5), pos=(x, side * y, z), rot=(side * -18, 0, 0), bevel=0.0)
                sw = fruit[(k + tier * 2 + (side > 0)) % len(fruit)]
                if rng.random() < 0.85:  # raided crates are empty
                    sphere(c, "Fruit", "Smooth", sw, 1.0, pos=(x, side * (y + 0.05), z + 0.3), scale=(1.3, 0.38, 0.32), subdiv=1)
                    for j in (-0.8, 0.7):
                        sphere(c, "Fruit", "Smooth", sw, 0.3, pos=(x + j, side * (y + 0.1), z + 0.55), subdiv=1)
        box(c, "PriceRail", "Smooth", "Cream", (12, 0.15, 0.4), pos=(0, side * 0.98, 1.2), bevel=0.0)
    box(c, "MistBar", "Metal", "Steel", (12, 0.3, 0.3), pos=(0, 0, 4.7), bevel=0.0)
    box(c, "Canopy", "Planks", "Cream", (12.2, 2.0, 0.3), pos=(0, 0, 5.1), bevel=0.06)


# --------------------------------------------------------------------------- checkout

def checkout_counter(c):
    """One checkout lane, 1.6 wide x 4 long (along Y; the cashier side is +X). Belt, register with
    a lit display, card reader, candy rack at the far end, and a lane-number light on a pole."""
    box(c, "Counter", "Smooth", "Cream", (1.6, 4.0, 2.6), pos=(0, 0, 1.3), bevel=0.1)
    box(c, "Kick", "Metal", "Gunmetal", (1.62, 4.02, 0.4), pos=(0, 0, 0.2), bevel=0.0)
    box(c, "Belt", "Rubber", "Rubber", (1.1, 2.6, 0.12), pos=(0, -0.5, 2.66), bevel=0.0)
    box(c, "BeltEnd", "Metal", "Steel", (1.2, 0.2, 0.25), pos=(0, 0.85, 2.7), bevel=0.0)
    box(c, "Register", "Smooth", "Gunmetal", (0.9, 0.9, 0.5), pos=(0.2, 1.4, 2.85), bevel=0.06)
    box(c, "Display", "Neon", "Teal", (0.7, 0.08, 0.45), pos=(0.2, 1.0, 3.3), rot=(-15, 0, 0), bevel=0.0)
    box(c, "Reader", "Smooth", "HazardBlack", (0.3, 0.4, 0.5), pos=(-0.55, 1.3, 2.9), bevel=0.03)
    box(c, "Bagger", "Metal", "Steel", (1.3, 0.8, 0.12), pos=(0, 1.8, 2.66), bevel=0.0)
    # Candy rack facing the queue (-Y end).
    box(c, "Rack", "Metal", "Steel", (1.4, 0.5, 3.4), pos=(0, -2.25, 1.7), bevel=0.04)
    for z in (0.9, 1.8, 2.7):
        for k in range(3):
            box(c, "Candy", "Smooth", GOODS[(k + int(z * 2)) % len(GOODS)], (0.38, 0.25, 0.5),
                pos=(-0.45 + k * 0.45, -2.45, z + 0.3), bevel=0.0)
    # Lane light: pole at the cashier end with a numbered box (Signboard; code paints the number).
    cyl(c, "Pole", "Metal", "Steel", 0.08, 4.6, pos=(0.55, 1.8, 4.9), verts=6, bevel=0.0)
    box(c, "LaneSign", "Smooth", "Signboard", (0.5, 0.9, 0.9), pos=(0.55, 1.8, 7.5), bevel=0.06)
    box(c, "LaneLamp", "Neon", "Mustard", (0.55, 0.95, 0.15), pos=(0.55, 1.8, 8.05), bevel=0.0)


# --------------------------------------------------------------------------- ceiling and signs

def aisle_sign(c):
    """Double-sided hanging aisle board on two chains (code paints both faces)."""
    box(c, "Board", "Smooth", "Signboard", (8, 0.3, 1.8), pos=(0, 0, 0), bevel=0.1)
    box(c, "Trim", "Smooth", "ContainerGreen", (8.4, 0.25, 2.2), pos=(0, 0, 0), bevel=0.1)
    for x in (-3.2, 3.2):
        box(c, "Chain", "Metal", "Steel", (0.08, 0.08, 4.0), pos=(x, 0, 3.1), bevel=0.0)


def ceiling_light(c):
    """12-stud fluorescent fixture hanging on two cables; the tube is Neon (code lights a few)."""
    box(c, "Housing", "Metal", "White", (12, 1.2, 0.35), pos=(0, 0, 0.2), bevel=0.05)
    box(c, "Tube", "Neon", "White", (11.6, 0.7, 0.12), pos=(0, 0, 0.0), bevel=0.0)
    for x in (-5, 5):
        box(c, "Cable", "Metal", "Steel", (0.06, 0.06, 3.0), pos=(x, 0, 1.85), bevel=0.0)


def staff_doors(c):
    """Swinging stockroom doors on the back wall (visual; the gameplay wall stays solid): two
    steel doors with porthole windows and kick plates, a frame, and a STAFF ONLY board above."""
    box(c, "Frame", "Metal", "Gunmetal", (6.6, 0.5, 8.4), pos=(0, 0.1, 4.2), bevel=0.06)
    for sx in (-1, 1):
        box(c, "Door", "Metal", "Steel", (3.0, 0.3, 7.6), pos=(sx * 1.55, -0.25, 3.9), bevel=0.06)
        cyl(c, "Porthole", "Glass", "WindowWarm", 0.5, 0.35, pos=(sx * 1.55, -0.4, 5.6), rot=(90, 0, 0), verts=10, bevel=0.0)
        box(c, "KickPlate", "Metal", "Gunmetal", (2.8, 0.1, 1.2), pos=(sx * 1.55, -0.42, 0.8), bevel=0.0)
    box(c, "StaffSign", "Smooth", "Signboard", (5.0, 0.2, 1.1), pos=(0, -0.3, 9.1), bevel=0.06)


# --------------------------------------------------------------------------- stock and receiving

def box_stack(c):
    """Pallet of cardboard cartons, shrink-wrapped, one top carton torn open."""
    box(c, "Pallet", "Planks", "Sand", (4.0, 4.0, 0.5), pos=(0, 0, 0.25), bevel=0.04)
    for layer in range(3):
        for i in range(2):
            for j in range(2):
                if layer == 2 and i == 1 and j == 1:
                    continue
                o = box(c, "Carton", "Planks", "Sand" if (i + j + layer) % 2 else "Bark", (1.9, 1.9, 1.3),
                        pos=(-0.97 + i * 1.94, -0.97 + j * 1.94, 1.15 + layer * 1.32), bevel=0.06)
                jitter(o, 1.2)
    box(c, "Wrap", "Glass", "Glass", (4.05, 4.05, 3.6), pos=(0, 0, 2.3), bevel=0.0)
    box(c, "Flap", "Planks", "Sand", (1.9, 0.9, 0.08), pos=(0.97, 0.97 + 0.45, 4.3), rot=(50, 0, 0), bevel=0.0)


def baler(c):
    """Cardboard baler by the receiving door, a finished bale strapped beside it."""
    box(c, "Body", "Metal", "SafetyYellow", (3.2, 2.6, 6.0), pos=(0, 0, 3.0), bevel=0.12)
    box(c, "Chamber", "Metal", "Gunmetal", (2.6, 0.2, 2.6), pos=(0, -1.35, 2.2), bevel=0.04)
    box(c, "Ram", "Metal", "Steel", (0.8, 0.8, 1.6), pos=(0, 0, 6.8), bevel=0.06)
    box(c, "Panel", "Smooth", "HazardBlack", (0.8, 0.15, 1.0), pos=(1.0, -1.35, 4.6), bevel=0.04)
    box(c, "Button", "Neon", "Coral", (0.25, 0.1, 0.25), pos=(1.0, -1.45, 4.8), bevel=0.0)
    box(c, "Bale", "Planks", "Sand", (2.4, 2.4, 2.2), pos=(3.1, 0.2, 1.1), bevel=0.08)
    for z in (0.6, 1.6):
        box(c, "Strap", "Smooth", "HazardBlack", (2.45, 2.45, 0.12), pos=(3.1, 0.2, z), bevel=0.0)


def spilled_goods(c):
    """Floor clutter from the storm: tipped cans, a split cereal box, a puddle of juice. Flat
    (under 0.4 tall) and never collides, so loot stays visible and reachable."""
    box(c, "Juice", "Glass", "Coral", (2.6, 1.8, 0.04), pos=(0.4, 0.3, 0.03), rot=(0, 0, 25), bevel=0.0)
    for k in range(6):
        cyl(c, "Can", "Metal", GOODS[k % len(GOODS)], 0.18, 0.5, pos=(rng.uniform(-1.6, 1.6), rng.uniform(-1.2, 1.2), 0.18),
            rot=(90, 0, rng.uniform(0, 180)), verts=8, bevel=0.0)
    box(c, "Cereal", "Smooth", "Mustard", (0.9, 0.3, 1.2), pos=(-1.4, 0.8, 0.16), rot=(85, 0, 30), bevel=0.0)
    for k in range(8):
        box(c, "Flakes", "Smooth", "Sand", (0.15, 0.15, 0.05), pos=(-0.9 + rng.uniform(-0.6, 0.6), 1.2 + rng.uniform(-0.5, 0.5), 0.03),
            rot=(0, 0, rng.uniform(0, 90)), bevel=0.0)


def roof_leak(c):
    """Where the storm got in: a dropped ceiling tile dangling at y ~14, a bucket and a wet-floor
    sign underneath. Origin on the floor."""
    box(c, "Tile", "Smooth", "Cream", (4.0, 4.0, 0.15), pos=(0.8, 0, 14.0), rot=(32, 0, 8), bevel=0.0)
    box(c, "Stain", "Smooth", "Bark", (3.0, 3.0, 0.05), pos=(-0.6, 0.4, 17.4), bevel=0.0)
    cyl(c, "Bucket", "Plastic", "Cobalt", 0.6, 1.0, pos=(0, 0, 0.5), verts=10, radius_top=0.7, bevel=0.0)
    cyl(c, "Water", "Glass", "Glass", 0.62, 0.05, pos=(0, 0, 0.85), verts=10, bevel=0.0)
    for side in (-1, 1):
        box(c, "WetSign", "Plastic", "SafetyYellow", (1.2, 0.08, 2.0), pos=(1.6, side * 0.35, 1.0), rot=(side * 12, 0, 0), bevel=0.0)


def boarded_window(c):
    """Plywood over a storm-cracked shop window (local -Y faces out), screwed to battens, with
    tape on the neighbouring pane. Code paints a message on the PlyText mesh."""
    box(c, "Ply", "Planks", "Sand", (9.0, 0.3, 8.6), pos=(0, 0, 4.3), bevel=0.04)
    box(c, "Ply", "Planks", "Sand", (4.5, 0.3, 4.4), pos=(-6.6, 0, 6.2), rot=(0, 4, 0), bevel=0.04)
    for z in (1.0, 7.6):
        box(c, "Batten", "Planks", "Bark", (9.6, 0.3, 0.5), pos=(0, -0.25, z), bevel=0.0)
    box(c, "PlyText", "Smooth", "Signboard", (7.0, 0.05, 2.4), pos=(0, -0.18, 4.4), bevel=0.0)
    for a in (40, -40):
        box(c, "Tape", "Smooth", "Cream", (0.25, 0.04, 10.0), pos=(7.8, 0.05, 6.5), rot=(0, a, 0), bevel=0.0)


BUILDERS = [
    ("ShelfFreezer", shelf_freezer),
    ("ShelfProduce", shelf_produce),
    ("CheckoutCounter", checkout_counter),
    ("AisleSign", aisle_sign),
    ("CeilingLight", ceiling_light),
    ("StaffDoors", staff_doors),
    ("BoxStack", box_stack),
    ("Baler", baler),
    ("SpilledGoods", spilled_goods),
    ("RoofLeak", roof_leak),
    ("BoardedWindow", boarded_window),
]

if __name__ == "__main__":
    build_set("v3market", BUILDERS, layout_spacing=4)
