"""V3 Milestone C5: Starlite Motel. Front faces Blender -Y; origin at the base centre.

The motel keeps MapBuilder's 110 x 30 x 14 gameplay box (one central door, back truss) and its
15 x 3 loot grid (rows 5, 12 and 19 studs in from the front wall). Rooms are made with
partition walls between loot columns, running from the back wall to 8 studs in from the front,
so every room opens onto a front corridor. All furniture sits in the 7-stud band along the back
wall, where there is no loot. Signs carry a "Signboard" mesh; code paints them.

blender -b --python tools/asset_pipeline/build_v3motel.py
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from kit import box, build_set, cyl, jitter, rng, sphere, wedge  # noqa: E402,F401


def room_partition(c):
    """Interior wall between two rooms: 21.5 deep (along Y, origin at its back end, wall runs to
    -Y), 13.4 tall, 0.6 thick. Wallpaper both sides, a baseboard, a picture on one side and a
    framed end post at the corridor."""
    L, H = 21.5, 13.4
    box(c, "Wall", "Smooth", "Plaster", (0.6, L, H), pos=(0, -L / 2, H / 2), bevel=0.0)
    for sx in (-1, 1):
        box(c, "Base", "Planks", "Bark", (0.15, L, 0.7), pos=(sx * 0.37, -L / 2, 0.35), bevel=0.0)
        box(c, "Rail", "Smooth", "Cream", (0.12, L, 0.25), pos=(sx * 0.36, -L / 2, 4.2), bevel=0.0)
    box(c, "EndPost", "Smooth", "Cream", (0.9, 0.9, H), pos=(0, -L + 0.45, H / 2), bevel=0.06)
    # A framed seaside print (motels love them) on the +X face, at the bed end.
    box(c, "Frame", "Planks", "Bark", (0.12, 3.4, 2.4), pos=(0.38, -3.5, 7.0), bevel=0.0)
    box(c, "Print", "Smooth", "Teal", (0.08, 3.0, 2.0), pos=(0.43, -3.5, 7.0), bevel=0.0)
    box(c, "Print", "Smooth", "Sand", (0.09, 3.0, 0.7), pos=(0.44, -3.5, 6.3), bevel=0.0)


def motel_bed(c):
    """Double bed: headboard against the back wall (+Y), length along -Y. 5.6 wide, 7.6 long."""
    box(c, "Frame", "Planks", "Bark", (5.6, 7.4, 1.0), pos=(0, -3.7, 0.5), bevel=0.06)
    box(c, "Headboard", "Planks", "Bark", (5.8, 0.4, 4.2), pos=(0, 0, 2.1), bevel=0.08)
    box(c, "Mattress", "Fabric", "White", (5.2, 7.0, 0.9), pos=(0, -3.7, 1.45), bevel=0.2)
    box(c, "Blanket", "Fabric", "Coral", (5.4, 4.6, 0.35), pos=(0, -5.0, 1.95), rot=(0, 0, 0), bevel=0.15)
    box(c, "Fold", "Fabric", "Cream", (5.4, 0.7, 0.4), pos=(0, -2.6, 2.0), bevel=0.15)
    for sx in (-1.3, 1.3):
        box(c, "Pillow", "Fabric", "Cream", (2.2, 1.2, 0.6), pos=(sx, -0.9, 2.1), bevel=0.25, segments=2)


def bed_stripped(c):
    """The same bed after the roof leak: blanket gone, mattress shoved half off the frame and
    stained, one pillow on the floor."""
    box(c, "Frame", "Planks", "Bark", (5.6, 7.4, 1.0), pos=(0, -3.7, 0.5), bevel=0.06)
    box(c, "Headboard", "Planks", "Bark", (5.8, 0.4, 4.2), pos=(0, 0, 2.1), bevel=0.08)
    box(c, "Mattress", "Fabric", "White", (5.2, 7.0, 0.9), pos=(1.6, -4.4, 1.2), rot=(0, -12, 8), bevel=0.2)
    box(c, "Stain", "Smooth", "Bark", (2.6, 2.4, 0.05), pos=(1.4, -4.0, 1.72), rot=(0, -12, 8), bevel=0.0)
    box(c, "Pillow", "Fabric", "Cream", (2.2, 1.2, 0.6), pos=(-2.8, -7.6, 0.3), rot=(0, 0, 30), bevel=0.25, segments=2)


def nightstand(c):
    """Bedside table with a lamp (shade is Neon: code tags it as a lamp so it flickers)."""
    box(c, "Table", "Planks", "Bark", (1.8, 1.6, 2.0), pos=(0, 0, 1.0), bevel=0.06)
    box(c, "Drawer", "Planks", "Sand", (1.5, 0.08, 0.6), pos=(0, -0.82, 1.4), bevel=0.0)
    cyl(c, "LampBase", "Metal", "Mustard", 0.3, 1.2, pos=(0, 0, 2.6), verts=8, bevel=0.0)
    cyl(c, "Shade", "Neon", "WindowWarm", 0.6, 0.8, pos=(0, 0, 3.5), verts=8, radius_top=0.4, bevel=0.0)


def dresser_tv(c):
    """Low dresser with a boxy CRT on top, rabbit ears. 4.4 wide, 1.6 deep (front -Y)."""
    box(c, "Dresser", "Planks", "Bark", (4.4, 1.6, 2.8), pos=(0, 0, 1.4), bevel=0.08)
    for z in (0.8, 1.7, 2.5):
        box(c, "Drawer", "Planks", "Sand", (4.0, 0.08, 0.6), pos=(0, -0.82, z), bevel=0.0)
    box(c, "TV", "Smooth", "Gunmetal", (2.4, 1.6, 1.9), pos=(0.4, 0.1, 3.75), bevel=0.15)
    box(c, "Screen", "Glass", "Teal", (1.8, 0.08, 1.4), pos=(0.4, -0.72, 3.8), bevel=0.0)
    for a in (-25, 25):
        box(c, "Antenna", "Metal", "Steel", (0.06, 0.06, 1.6), pos=(0.4 + a / 50, 0.1, 5.3), rot=(0, a, 0), bevel=0.0)


def open_suitcase(c):
    """Suitcase open on the floor, clothes spilling out: someone left in a hurry."""
    box(c, "Base", "Fabric", "Cobalt", (3.0, 2.0, 0.8), pos=(0, 0, 0.4), bevel=0.15)
    box(c, "Lid", "Fabric", "Cobalt", (3.0, 0.8, 2.0), pos=(0, 1.3, 1.0), rot=(-20, 0, 0), bevel=0.15)
    for i, (sw, x, y) in enumerate((("Coral", -0.6, -0.2), ("Cream", 0.5, 0.2), ("Mustard", 1.6, -1.4), ("Teal", -1.4, -1.6))):
        o = box(c, "Clothes", "Fabric", sw, (1.4, 1.1, 0.2), pos=(x, y, 0.9 if i < 2 else 0.12), bevel=0.06)
        jitter(o, 15)


def luggage_pile(c):
    """Two stacked hard-shell cases and a duffel bag."""
    box(c, "Case", "Smooth", "Coral", (2.2, 1.0, 3.0), pos=(0, 0, 1.5), bevel=0.2)
    box(c, "Case", "Smooth", "Teal", (1.8, 0.9, 2.4), pos=(1.9, 0.1, 1.2), rot=(0, 0, 6), bevel=0.2)
    box(c, "Handle", "Metal", "Gunmetal", (0.8, 0.2, 0.3), pos=(0, 0, 3.15), bevel=0.0)
    box(c, "Duffel", "Fabric", "Mustard", (2.8, 1.3, 1.3), pos=(0.8, -1.2, 0.65), bevel=0.4, segments=2)


def armchair(c):
    """Worn motel armchair, slightly turned."""
    box(c, "Seat", "Fabric", "Mustard", (2.4, 2.4, 1.0), pos=(0, 0, 1.0), bevel=0.25)
    box(c, "Back", "Fabric", "Mustard", (2.4, 0.6, 2.2), pos=(0, 1.0, 2.0), bevel=0.25)
    for sx in (-1.2, 1.2):
        box(c, "Arm", "Fabric", "Mustard", (0.5, 2.4, 1.6), pos=(sx, 0, 1.3), bevel=0.2)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            box(c, "Leg", "Planks", "Bark", (0.25, 0.25, 0.5), pos=(sx, sy, 0.25), bevel=0.0)


def front_desk(c):
    """Office counter: 8 long, 2 deep (customers at -Y). Bell, guest book, a key board with room
    keys on the wall behind, a NO VACANCY lightbox (code paints it)."""
    box(c, "Counter", "Planks", "Teal", (8.0, 2.0, 3.4), pos=(0, 0, 1.7), bevel=0.1)
    box(c, "Top", "Smooth", "Cream", (8.4, 2.4, 0.2), pos=(0, -0.1, 3.5), bevel=0.04)
    sphere(c, "Bell", "Metal", "Mustard", 0.3, pos=(-2.6, -0.6, 3.75), scale=(1, 1, 0.6), subdiv=1)
    box(c, "Book", "Smooth", "Coral", (1.4, 1.0, 0.2), pos=(1.2, -0.5, 3.7), rot=(0, 0, 8), bevel=0.0)
    box(c, "KeyBoard", "Planks", "Bark", (4.0, 0.2, 2.6), pos=(0, 3.4, 6.0), bevel=0.04)
    for i in range(8):
        x = -1.5 + (i % 4) * 1.0
        z = 6.6 - (i // 4) * 1.1
        box(c, "Key", "Metal", "Mustard", (0.15, 0.1, 0.6), pos=(x, 3.25, z - 0.3), bevel=0.0)
        box(c, "Tag", "Smooth", "Coral", (0.3, 0.06, 0.3), pos=(x, 3.22, z - 0.75), bevel=0.0)
    box(c, "LightBox", "Smooth", "Signboard", (4.2, 0.3, 1.2), pos=(0, 3.4, 8.6), bevel=0.06)


def wall_sconce(c):
    """Walkway wall light by each room door (Neon globe: code tags it as a lamp)."""
    box(c, "Plate", "Metal", "Gunmetal", (0.6, 0.15, 0.9), pos=(0, 0.05, 0), bevel=0.03)
    box(c, "Arm", "Metal", "Gunmetal", (0.12, 0.6, 0.12), pos=(0, -0.3, 0), bevel=0.0)
    sphere(c, "Globe", "Neon", "WindowWarm", 0.35, pos=(0, -0.6, -0.1), subdiv=1)


def storm_shutter(c):
    """Plywood storm shutter screwed over a room window (local -Y faces out): 4.4 x 4.8, with
    a painted X and the room number (code paints the Signboard)."""
    box(c, "Ply", "Planks", "Sand", (4.4, 0.25, 4.8), pos=(0, 0, 2.4), bevel=0.03)
    for a in (40, -40):
        box(c, "Cross", "Smooth", "Coral", (0.3, 0.05, 6.0), pos=(0, -0.15, 2.4), rot=(0, a, 0), bevel=0.0)
    box(c, "Mark", "Smooth", "Signboard", (1.6, 0.04, 0.8), pos=(0, -0.17, 4.2), bevel=0.0)


BUILDERS = [
    ("RoomPartition", room_partition),
    ("MotelBed", motel_bed),
    ("BedStripped", bed_stripped),
    ("Nightstand", nightstand),
    ("DresserTV", dresser_tv),
    ("OpenSuitcase", open_suitcase),
    ("LuggagePile", luggage_pile),
    ("Armchair", armchair),
    ("FrontDesk", front_desk),
    ("WallSconce", wall_sconce),
    ("StormShutter", storm_shutter),
]

if __name__ == "__main__":
    build_set("v3motel", BUILDERS, layout_spacing=4)
