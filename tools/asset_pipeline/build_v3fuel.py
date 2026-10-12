"""V3 Milestone C3: Fuel & Go. Front faces Blender -Y; origin at the base centre.

The store keeps MapBuilder's 40 x 30 x 14 gameplay box and its 5 x 4 interior loot grid
(x -136..-108, z -91..-70 in world space), so interior pieces are wall-hugging and shallow:
  - wall cooler and wall rack are 1.4 / 1.2 deep (their faces stay >2 studs from the loot rows),
  - the snack gondola is 1.6 wide and sits between two loot columns,
  - the counter is 2 deep in the 7-stud band east of the last loot column.
The repair bay stays open-air (no roof, so nothing there promises shelter); its garage door is
a closed roll-up door painted on the store's solid west wall.
Text goes on "Signboard" meshes; code paints it.

blender -b --python tools/asset_pipeline/build_v3fuel.py
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from kit import box, build_set, cyl, jitter, rng, sphere, wedge  # noqa: E402,F401

GOODS = ["Coral", "Mustard", "Cobalt", "Teal", "Cream", "Mint", "Terracotta"]


# --------------------------------------------------------------------------- store interior

def wall_cooler(c):
    """Single-sided drinks cooler against a wall: 12 wide, 1.4 deep, 7.5 tall. Glass doors with
    bottles behind, a lit header, one door propped open with a crate."""
    box(c, "Body", "Metal", "White", (12, 1.4, 7.0), pos=(0, 0, 3.5), bevel=0.08)
    box(c, "Header", "Smooth", "Coral", (12.2, 1.5, 0.9), pos=(0, 0, 7.4), bevel=0.1)
    box(c, "HeaderGlow", "Neon", "Cream", (10, 0.1, 0.4), pos=(0, -0.78, 7.4), bevel=0.0)
    box(c, "Cold", "Neon", "Mint", (11.4, 0.1, 5.6), pos=(0, 0.45, 3.8), bevel=0.0)
    for z in (1.4, 3.0, 4.6, 6.0):
        box(c, "Shelf", "Metal", "Steel", (11.4, 1.0, 0.1), pos=(0, 0, z), bevel=0.0)
        for k in range(14):
            if rng.random() < 0.8:
                cyl(c, "Bottle", "Smooth", GOODS[(k + int(z)) % len(GOODS)], 0.22, 1.0,
                    pos=(-5.3 + k * 0.8, -0.1, z + 0.55), verts=6, bevel=0.0)
    for i in range(4):
        x = -4.5 + i * 3.0
        box(c, "Door", "Glass", "Glass", (2.8, 0.1, 6.0), pos=(x, -0.72, 3.7), bevel=0.0)
        box(c, "DoorFrame", "Metal", "Gunmetal", (0.16, 0.16, 6.2), pos=(x - 1.45, -0.74, 3.7), bevel=0.0)
        box(c, "Handle", "Metal", "Steel", (0.12, 0.2, 1.4), pos=(x + 1.1, -0.85, 3.9), bevel=0.0)
    box(c, "Kick", "Metal", "Gunmetal", (12.1, 1.5, 0.5), pos=(0, 0, 0.25), bevel=0.0)


def snack_gondola(c):
    """Low double-sided snack shelf, 8 long x 1.6 wide x 4.5 tall, raided gaps."""
    box(c, "Base", "Metal", "Gunmetal", (8, 1.6, 0.5), pos=(0, 0, 0.25), bevel=0.04)
    box(c, "Back", "Metal", "Steel", (8, 0.2, 4.0), pos=(0, 0, 2.5), bevel=0.0)
    for z in (1.2, 2.4, 3.6):
        box(c, "Shelf", "Metal", "White", (8, 1.6, 0.12), pos=(0, 0, z), bevel=0.0)
        x = -3.7
        while x < 3.6:
            w = rng.uniform(0.5, 0.9)
            for side in (-1, 1):
                if rng.random() < 0.75:
                    box(c, "Snack", "Smooth", GOODS[rng.randrange(len(GOODS))], (w, 0.6, rng.uniform(0.5, 0.9)),
                        pos=(x + w / 2, side * 0.45, z + 0.4), bevel=0.0)
            x += w + 0.12
    for sx in (-4, 4):
        box(c, "End", "Smooth", "Coral", (0.2, 1.7, 4.6), pos=(sx, 0, 2.3), bevel=0.04)
    box(c, "Topper", "Smooth", "Signboard", (3.0, 0.15, 0.8), pos=(0, 0, 4.9), bevel=0.0)


def wall_rack(c):
    """Single-sided auto-supplies wall rack, 8 wide, 1.2 deep: oil, wipers, maps, an air
    freshener spinner."""
    box(c, "Pegboard", "Planks", "Sand", (8, 0.2, 6.0), pos=(0, 0.5, 3.4), bevel=0.0)
    for z in (1.0, 2.6, 4.2):
        box(c, "Shelf", "Metal", "Gunmetal", (8, 1.2, 0.12), pos=(0, 0, z), bevel=0.0)
        for k in range(9):
            if rng.random() < 0.8:
                if z < 2:
                    box(c, "OilCan", "Smooth", "Mustard" if k % 2 else "Cobalt", (0.6, 0.5, 1.0),
                        pos=(-3.5 + k * 0.85, -0.1, z + 0.56), bevel=0.0)
                else:
                    box(c, "Box", "Smooth", GOODS[(k + int(z)) % len(GOODS)], (0.7, 0.5, 0.8),
                        pos=(-3.5 + k * 0.85, -0.1, z + 0.46), bevel=0.0)
    for k in range(6):
        box(c, "Wiper", "Rubber", "Rubber", (0.12, 0.12, 1.8), pos=(-3 + k * 1.2, 0.3, 5.6), rot=(0, 8, 0), bevel=0.0)
    box(c, "Header", "Smooth", "Signboard", (8.2, 0.2, 0.8), pos=(0, 0.4, 6.8), bevel=0.0)


def shop_counter(c):
    """Cash counter, 8 long (along Y) x 2 deep; the customer side faces -X. Register, lottery
    display, a donation jar and a hot-dog roller; a cigarette/lottery cabinet on the wall behind."""
    box(c, "Counter", "Planks", "Teal", (2.0, 8.0, 3.2), pos=(0, 0, 1.6), bevel=0.1)
    box(c, "Top", "Smooth", "Cream", (2.4, 8.2, 0.2), pos=(-0.1, 0, 3.3), bevel=0.04)
    box(c, "Kick", "Metal", "Gunmetal", (2.02, 8.02, 0.4), pos=(0, 0, 0.2), bevel=0.0)
    box(c, "Register", "Smooth", "Gunmetal", (1.0, 1.2, 0.6), pos=(0.2, -2.0, 3.7), bevel=0.06)
    box(c, "Display", "Neon", "NeonGreen", (0.08, 0.8, 0.45), pos=(-0.35, -2.0, 4.2), rot=(0, -15, 0), bevel=0.0)
    box(c, "Lottery", "Smooth", "Mustard", (0.9, 1.4, 1.1), pos=(-0.3, 1.0, 3.95), bevel=0.04)
    cyl(c, "Jar", "Glass", "Glass", 0.3, 0.6, pos=(-0.6, 2.4, 3.7), verts=8, bevel=0.0)
    box(c, "Roller", "Metal", "Steel", (1.2, 1.4, 0.5), pos=(0.1, 3.2, 3.65), bevel=0.04)
    for k in range(4):
        cyl(c, "HotDog", "Smooth", "Terracotta", 0.12, 1.1, pos=(0.1, 2.75 + k * 0.3, 3.95), rot=(0, 90, 0), verts=6, bevel=0.0)
    # Back cabinet on the wall (+X side, 3 studs behind the counter).
    box(c, "Cabinet", "Metal", "HazardBlack", (0.8, 6.0, 4.0), pos=(3.0, 0, 5.0), bevel=0.06)
    for z in (3.8, 5.0, 6.2):
        for k in range(8):
            box(c, "Pack", "Smooth", GOODS[(k + int(z * 2)) % len(GOODS)], (0.15, 0.55, 0.8),
                pos=(2.55, -2.6 + k * 0.72, z), bevel=0.0)
    box(c, "CabinetSign", "Smooth", "Signboard", (0.2, 5.0, 0.8), pos=(2.55, 0, 7.4), bevel=0.0)


# --------------------------------------------------------------------------- forecourt and bay

def air_machine(c):
    """Coin air/water machine with a coiled hose."""
    box(c, "Body", "Smooth", "Cobalt", (1.6, 1.2, 3.6), pos=(0, 0, 2.0), bevel=0.15)
    box(c, "Top", "Smooth", "White", (1.7, 1.3, 0.4), pos=(0, 0, 3.95), bevel=0.08)
    box(c, "Face", "Smooth", "Signboard", (1.2, 0.08, 1.0), pos=(0, -0.62, 3.0), bevel=0.0)
    box(c, "Coin", "Metal", "Steel", (0.3, 0.1, 0.5), pos=(0.45, -0.63, 2.0), bevel=0.0)
    box(c, "Base", "Concrete", "Concrete", (2.2, 1.8, 0.2), pos=(0, 0, 0.1), bevel=0.04)
    for k in range(6):
        a = k * 60
        r = math.radians(a)
        box(c, "Hose", "Rubber", "Rubber", (0.12, 0.6, 0.12), pos=(0.95, math.cos(r) * 0.35, 1.8 + math.sin(r) * 0.35),
            rot=(a, 0, 0), bevel=0.0)


def pump_bag(c):
    """'Out of order' bag tied over a pump head (fits FuelPump: 2.4 x 1.8 top at 4.9)."""
    box(c, "Bag", "Fabric", "Mustard", (2.7, 2.1, 2.4), pos=(0, 0, 4.4), bevel=0.25, segments=2)
    box(c, "Tie", "Fabric", "HazardBlack", (2.75, 2.15, 0.2), pos=(0, 0, 3.4), bevel=0.05)
    box(c, "Tag", "Smooth", "Signboard", (1.6, 0.06, 0.9), pos=(0, -1.09, 4.4), bevel=0.0)


def canopy_panel(c):
    """A fascia panel the wind tore loose: hangs from one bolt, twisted. Origin at the bolt."""
    o = box(c, "Panel", "Smooth", "Coral", (6.0, 0.25, 1.6), pos=(-2.6, 0, -1.4), rot=(0, 28, 6), bevel=0.05)
    box(c, "Backing", "Metal", "Steel", (5.8, 0.15, 1.4), pos=(-2.55, 0.18, -1.38), rot=(0, 28, 6), bevel=0.0)
    box(c, "Bolt", "Metal", "Gunmetal", (0.3, 0.4, 0.3), pos=(0, 0, 0), bevel=0.0)


def garage_door(c):
    """Closed roll-up garage door with frame, painted on a wall (local -Y faces out). 9 x 10."""
    box(c, "Frame", "Metal", "Gunmetal", (10.0, 0.4, 10.6), pos=(0, 0, 5.3), bevel=0.06)
    box(c, "Door", "Metal", "Steel", (9.0, 0.3, 9.6), pos=(0, -0.25, 4.8), bevel=0.04)
    for i in range(12):
        box(c, "Slat", "Metal", "Steel", (9.0, 0.45, 0.12), pos=(0, -0.4, 0.5 + i * 0.8), bevel=0.0)
    box(c, "Housing", "Metal", "Coral", (10.4, 1.2, 1.2), pos=(0, -0.5, 10.2), bevel=0.1)
    box(c, "Handle", "Metal", "Gunmetal", (1.2, 0.2, 0.2), pos=(0, -0.5, 0.9), bevel=0.0)
    box(c, "Dent", "Metal", "Gunmetal", (2.0, 0.1, 1.4), pos=(2.6, -0.42, 3.2), rot=(0, 12, 0), bevel=0.0)
    box(c, "BaySign", "Smooth", "Signboard", (6.0, 0.15, 1.2), pos=(0, -0.3, 11.6), bevel=0.04)


def compressor(c):
    """Shop air compressor: horizontal tank on wheels, motor, coiled yellow hose."""
    cyl(c, "Tank", "Metal", "Coral", 0.9, 3.6, pos=(0, 0, 1.3), rot=(0, 90, 0), verts=12, bevel=0.1)
    box(c, "Motor", "Metal", "Gunmetal", (1.4, 1.0, 1.0), pos=(0.4, 0, 2.6), bevel=0.08)
    cyl(c, "Pulley", "Metal", "Steel", 0.4, 0.2, pos=(-0.6, 0.55, 2.6), rot=(90, 0, 0), verts=8, bevel=0.0)
    for x in (-1.4, 1.4):
        cyl(c, "Wheel", "Rubber", "Rubber", 0.35, 0.25, pos=(x, 0.95, 0.35), rot=(90, 0, 0), verts=8, bevel=0.0)
        cyl(c, "Wheel", "Rubber", "Rubber", 0.35, 0.25, pos=(x, -0.95, 0.35), rot=(90, 0, 0), verts=8, bevel=0.0)
    # Coiled hose hung on the tank's side (ring in the XZ plane, just proud of the tank at -Y).
    for k in range(8):
        a = k * 45
        r = math.radians(a)
        box(c, "Hose", "Rubber", "SafetyYellow", (0.42, 0.15, 0.15),
            pos=(0.9 + math.cos(r) * 0.55, -0.98, 1.35 + math.sin(r) * 0.55), rot=(0, -(a + 90), 0), bevel=0.0)


BUILDERS = [
    ("WallCooler", wall_cooler),
    ("SnackGondola", snack_gondola),
    ("WallRack", wall_rack),
    ("ShopCounter", shop_counter),
    ("AirMachine", air_machine),
    ("PumpBag", pump_bag),
    ("CanopyPanel", canopy_panel),
    ("GarageDoor", garage_door),
    ("Compressor", compressor),
]

if __name__ == "__main__":
    build_set("v3fuel", BUILDERS, layout_spacing=4)
