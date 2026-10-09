"""Town kit: houses, interiors, street props, storm debris. Front faces Blender -Y.

Houses are visual shells around the gameplay footprint used by MapBuilder.building():
30 x 28 studs, 12-stud walls 1 stud thick, an 8 x 9 door centered on the front wall.
Walls use the "Plaster" swatch and roofs "RoofRed" so MapBuilder can recolor each house.

blender -b --python tools/asset_pipeline/build_town.py
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from kit import box, build_set, cyl, jitter, rng, sphere, wedge  # noqa: E402,F401

W, D, H = 30.0, 28.0, 12.0
DOOR_W, DOOR_H = 8.0, 9.0


# --------------------------------------------------------------------------- house parts

def wall_with_openings(c, axis, offset, length, openings, swatch="Plaster", material="Plaster"):
    """A 1-stud wall along X (axis='x', at y=offset) or Y (axis='y', at x=offset).
    openings: list of (center, width, bottom, top) cut out of the wall."""
    mat = "Brick" if material == "Brick" else "Concrete" if material == "Concrete" else "Smooth"
    # Build the wall as vertical strips between openings plus header/sill pieces.
    cuts = sorted(openings)
    edges = [-length / 2]
    for center, width, _, _ in cuts:
        edges += [center - width / 2, center + width / 2]
    edges.append(length / 2)

    def piece(a0, a1, z0, z1):
        if a1 - a0 < 0.05 or z1 - z0 < 0.05:
            return
        mid, size = (a0 + a1) / 2, a1 - a0
        if axis == "x":
            box(c, "Wall", mat, swatch, (size, 1.0, z1 - z0), pos=(mid, offset, (z0 + z1) / 2), bevel=0.05)
        else:
            box(c, "Wall", mat, swatch, (1.0, size, z1 - z0), pos=(offset, mid, (z0 + z1) / 2), bevel=0.05)

    for i in range(0, len(edges), 2):
        piece(edges[i], edges[i + 1], 0, H)
    for center, width, bottom, top in cuts:
        piece(center - width / 2, center + width / 2, 0, bottom)
        piece(center - width / 2, center + width / 2, top, H)


def window(c, axis, offset, along, z, size=(4.0, 4.0), outward=1, shutter="Cobalt", boarded=False):
    """Window frame, glass, sill and shutters on a wall face. outward = +1/-1 along the wall normal."""
    w, h = size

    def at(a, depth, zz):
        return (a, offset + depth * outward, zz) if axis == "x" else (offset + depth * outward, a, zz)

    def sz(a, depth, zz):
        return (a, depth, zz) if axis == "x" else (depth, a, zz)

    box(c, "Glass", "Glass", "WindowWarm", sz(w, 0.3, h), pos=at(along, 0.0, z), bevel=0.0)
    for dz in (-h / 2 - 0.25, h / 2 + 0.25):
        box(c, "Frame", "Smooth", "Cream", sz(w + 1.0, 0.7, 0.5), pos=at(along, 0.45, z + dz), bevel=0.1)
    for da in (-w / 2 - 0.25, w / 2 + 0.25):
        box(c, "Frame", "Smooth", "Cream", sz(0.5, 0.7, h), pos=at(along + da, 0.45, z), bevel=0.1)
    box(c, "Mullion", "Smooth", "Cream", sz(0.25, 0.4, h), pos=at(along, 0.3, z), bevel=0.03)
    box(c, "Sill", "Smooth", "Cream", sz(w + 1.4, 1.2, 0.35), pos=at(along, 0.7, z - h / 2 - 0.55), bevel=0.08)
    for side in (-1, 1):
        box(c, "Shutter", "Planks", shutter, sz(1.6, 0.35, h + 0.6), pos=at(along + side * (w / 2 + 1.3), 0.55, z), bevel=0.08)
    if boarded:
        for i, tilt in enumerate((-12, 10)):
            o = box(c, "Board", "Planks", "Bark", sz(w + 0.8, 0.3, 0.6), pos=at(along, 0.8, z - 0.6 + i * 1.2), bevel=0.05)
            if axis == "x":
                o.rotation_euler.y += math.radians(tilt)
            else:
                o.rotation_euler.x += math.radians(tilt)


def gable_roof(c, ridge_h, overhang=1.5, swatch="RoofRed"):
    """Pitched roof over the W x D footprint, ridge along X, plus gable-end triangles."""
    half = D / 2 + overhang
    slope = math.hypot(half, ridge_h)
    angle = math.degrees(math.atan2(ridge_h, half))
    for side in (-1, 1):
        box(c, "Roof", "Slate", swatch, (W + overhang * 2, slope, 0.8),
            pos=(0, side * half / 2, H + ridge_h / 2 + 0.4), rot=(-side * angle, 0, 0), bevel=0.15)
        # Shingle rows for texture: thin offset strips
        for i in range(1, 4):
            t = i / 4
            box(c, "Shingle", "Slate", swatch, (W + overhang * 2 + 0.2, 0.5, 0.3),
                pos=(0, side * half * (1 - t), H + ridge_h * t + 0.75), rot=(-side * angle, 0, 0), bevel=0.08)
    box(c, "Ridge", "Smooth", "Cream", (W + overhang * 2 + 0.4, 1.0, 0.6), pos=(0, 0, H + ridge_h + 0.6), bevel=0.15)
    # Gable-end triangles (wall color), slightly inset
    for sx in (-1, 1):
        wedge(c, "Gable", "Smooth", "Plaster", (0.9, D / 2, ridge_h), pos=(sx * (W / 2 - 0.05), -D / 4, H + ridge_h / 2),
              rot=(0, 0, 180), bevel=0.0)
        wedge(c, "Gable", "Smooth", "Plaster", (0.9, D / 2, ridge_h), pos=(sx * (W / 2 - 0.05), D / 4, H + ridge_h / 2),
              rot=(0, 0, 0), bevel=0.0)
    # Fascia boards along the eaves
    for side in (-1, 1):
        box(c, "Fascia", "Smooth", "Cream", (W + overhang * 2, 0.5, 0.7), pos=(0, side * (half - 0.1), H + 0.15), bevel=0.08)


def trim(c):
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(c, "Corner", "Smooth", "Cream", (1.4, 1.4, H), pos=(sx * W / 2, sy * D / 2, H / 2), bevel=0.15)
    # Foundation as a ring around the walls, so the gameplay floor inside stays visible.
    for sy in (-1, 1):
        box(c, "Base", "Concrete", "Stone", (W + 1.2, 1.6, 1.2), pos=(0, sy * D / 2, 0.6), bevel=0.15)
    for sx in (-1, 1):
        box(c, "Base", "Concrete", "Stone", (1.6, D + 1.2, 1.2), pos=(sx * W / 2, 0, 0.6), bevel=0.15)
    # Door frame and step on the front wall (y = -D/2)
    for sx in (-1, 1):
        box(c, "DoorFrame", "Smooth", "Cream", (0.8, 1.2, DOOR_H + 0.4), pos=(sx * (DOOR_W / 2 + 0.4), -D / 2 - 0.2, (DOOR_H + 0.4) / 2), bevel=0.12)
    box(c, "DoorFrame", "Smooth", "Cream", (DOOR_W + 2.4, 1.2, 0.9), pos=(0, -D / 2 - 0.2, DOOR_H + 0.45), bevel=0.12)


def porch(c, width, post_swatch="Cream", roof_swatch="RoofRed"):
    depth = 5.0
    box(c, "Deck", "Planks", "Bark", (width, depth, 1.0), pos=(0, -D / 2 - depth / 2, 0.5), bevel=0.1)
    box(c, "Step", "Concrete", "Stone", (6, 1.6, 0.5), pos=(0, -D / 2 - depth - 0.8, 0.25), bevel=0.08)
    for sx in (-1, 1):
        box(c, "Post", "Smooth", post_swatch, (0.7, 0.7, 9.0), pos=(sx * (width / 2 - 0.6), -D / 2 - depth + 0.6, 5.5), bevel=0.12)
        box(c, "Rail", "Smooth", post_swatch, ((width - DOOR_W) / 2 - 1.5, 0.4, 0.4),
            pos=(sx * (DOOR_W / 2 + ((width - DOOR_W) / 2 - 1.5) / 2 + 0.8), -D / 2 - depth + 0.6, 3.0), bevel=0.06)
    box(c, "PorchRoof", "Slate", roof_swatch, (width + 1, depth + 1.2, 0.6), pos=(0, -D / 2 - depth / 2 + 0.2, 10.4), rot=(-12, 0, 0), bevel=0.12)
    box(c, "Lamp", "Neon", "WindowWarm", (0.6, 0.4, 0.8), pos=(DOOR_W / 2 + 1.2, -D / 2 - 0.9, 7.5), bevel=0.08)


def vines(c, x, y, height, spread=3.0):
    for i in range(7):
        s = rng.uniform(0.9, 1.6)
        sphere(c, "Vine", "Grass", "Leaf", s, pos=(x + rng.uniform(-spread, spread) * 0.3, y, rng.uniform(1, height)),
               scale=(1.0, 0.45, 1.2), subdiv=1)


def house(c, variant):
    front_open = [(0.0, DOOR_W, 0.0, DOOR_H), (-9.5, 4.4, 3.5, 8.3), (9.5, 4.4, 3.5, 8.3)]
    if variant == "B":
        front_open[1] = (-9.5, 7.0, 3.0, 8.5)  # bay window
    wall_with_openings(c, "x", -D / 2, W, front_open)
    wall_with_openings(c, "x", D / 2, W, [(-7, 4.4, 3.5, 8.3), (7, 4.4, 3.5, 8.3)])
    wall_with_openings(c, "y", -W / 2, D, [(-5, 4.4, 3.5, 8.3), (6, 4.4, 3.5, 8.3)])
    wall_with_openings(c, "y", W / 2, D, [(-5, 4.4, 3.5, 8.3), (6, 4.4, 3.5, 8.3)])
    shutter = "Teal" if variant == "A" else "Mustard"
    # Windows face outward from each wall.
    window(c, "x", -D / 2 - 0.5, 9.5, 5.9, outward=-1, shutter=shutter)
    if variant == "A":
        window(c, "x", -D / 2 - 0.5, -9.5, 5.9, outward=-1, shutter=shutter)
    else:
        window(c, "x", -D / 2 - 0.5, -9.5, 5.75, size=(6.6, 5.0), outward=-1, shutter=shutter)
        box(c, "BayRoof", "Slate", "RoofRed", (9, 2.6, 0.5), pos=(-9.5, -D / 2 - 1.6, 9.2), rot=(-25, 0, 0), bevel=0.1)
    window(c, "x", D / 2 + 0.5, -7, 5.9, outward=1, shutter=shutter, boarded=(variant == "A"))
    window(c, "x", D / 2 + 0.5, 7, 5.9, outward=1, shutter=shutter)
    for wx in (-W / 2 - 0.5, W / 2 + 0.5):
        out = -1 if wx < 0 else 1
        window(c, "y", wx, -5, 5.9, outward=out, shutter=shutter, boarded=(variant == "B" and out > 0))
        window(c, "y", wx, 6, 5.9, outward=out, shutter=shutter)
    trim(c)
    gable_roof(c, ridge_h=7.0 if variant == "A" else 6.0)
    if variant == "A":
        # Dormer on the front slope
        box(c, "Dormer", "Smooth", "Plaster", (6, 4, 4), pos=(6, -4.5, H + 4.2), bevel=0.1)
        box(c, "DormerRoof", "Slate", "RoofRed", (7, 5, 0.5), pos=(6, -4.8, H + 6.5), rot=(-20, 0, 0), bevel=0.1)
        box(c, "DormerGlass", "Glass", "WindowWarm", (3, 0.3, 2.2), pos=(6, -6.6, H + 4.3), bevel=0.0)
        box(c, "DormerFrame", "Smooth", "Cream", (3.8, 0.4, 3.0), pos=(6, -6.5, H + 4.3), bevel=0.1)
        porch(c, 16)
        box(c, "Chimney", "Brick", "Terracotta", (2.8, 2.8, 9), pos=(-9, 4, H + 4.5), bevel=0.15)
        box(c, "ChimneyCap", "Concrete", "Stone", (3.4, 3.4, 0.6), pos=(-9, 4, H + 9.2), bevel=0.1)
        vines(c, -W / 2 - 0.7, -D / 2 + 1, 9)
        box(c, "Patch", "Planks", "Bark", (5, 0.4, 3), pos=(-6, D / 4 + 2, H + 4.2), rot=(25, 0, 8), bevel=0.08)
    else:
        porch(c, W + 1)
        box(c, "Chimney", "Brick", "Terracotta", (3.2, 2.6, H + 9), pos=(W / 2 + 1.6, 3, (H + 9) / 2), bevel=0.15)
        box(c, "ChimneyCap", "Concrete", "Stone", (3.8, 3.2, 0.6), pos=(W / 2 + 1.6, 3, H + 9.3), bevel=0.1)
        vines(c, W / 2 + 0.7, D / 2 - 1, 10)
        box(c, "Antenna", "Metal", "Steel", (0.2, 0.2, 5), pos=(-8, 2, H + 8), rot=(0, 8, 0), bevel=0.0)
        box(c, "AntennaBar", "Metal", "Steel", (3, 0.2, 0.2), pos=(-8, 2, H + 9.6), bevel=0.0)
    # Gutter downpipe
    cyl(c, "Downpipe", "Metal", "Steel", 0.25, H, pos=(W / 2 + 0.6, -D / 2 + 0.8, H / 2), verts=8, bevel=0.0)


def house_a(c):
    house(c, "A")


def house_b(c):
    house(c, "B")


# --------------------------------------------------------------------------- interiors (≤ 2.5 deep, against walls)

def sofa(c):
    box(c, "Base", "Fabric", "Coral", (6, 2.4, 1.4), pos=(0, 0, 0.9), bevel=0.3)
    box(c, "Back", "Fabric", "Coral", (6, 0.8, 2.2), pos=(0, 0.9, 2.0), bevel=0.3)
    for sx in (-1, 1):
        box(c, "Arm", "Fabric", "Coral", (0.8, 2.4, 1.6), pos=(sx * 3.0, 0, 1.6), bevel=0.3)
    for sx in (-1.5, 1.5):
        box(c, "Cushion", "Fabric", "Mustard", (2.6, 1.6, 0.5), pos=(sx, -0.2, 1.8), bevel=0.2)
    for sx in (-2.6, 2.6):
        box(c, "Leg", "Wood", "Bark", (0.3, 0.3, 0.3), pos=(sx, -0.9, 0.15), bevel=0.05)


def bed(c):
    box(c, "Frame", "Wood", "Bark", (2.5, 7, 1.2), pos=(0, 0, 0.6), bevel=0.15)
    box(c, "Mattress", "Fabric", "Cream", (2.3, 6.6, 0.8), pos=(0, 0, 1.6), bevel=0.25)
    box(c, "Blanket", "Fabric", "Cobalt", (2.45, 4.5, 0.4), pos=(0, -1.1, 1.95), bevel=0.15)
    box(c, "Pillow", "Fabric", "White", (1.8, 1.0, 0.5), pos=(0, 2.7, 2.2), bevel=0.2)
    box(c, "Headboard", "Wood", "Bark", (2.5, 0.4, 3.2), pos=(0, 3.4, 1.6), bevel=0.12)


def kitchen(c):
    box(c, "Counter", "Wood", "Cream", (7, 2.4, 3.0), pos=(0, 0, 1.5), bevel=0.1)
    box(c, "Top", "Concrete", "Stone", (7.2, 2.6, 0.3), pos=(0, 0, 3.15), bevel=0.06)
    box(c, "Sink", "Metal", "Steel", (1.8, 1.4, 0.2), pos=(-1.5, 0, 3.32), bevel=0.05)
    cyl(c, "Tap", "Metal", "Steel", 0.1, 0.8, pos=(-1.5, 0.6, 3.7), verts=6)
    for i in range(3):
        box(c, "Drawer", "Smooth", "Teal", (2, 0.1, 1.2), pos=(-2.3 + i * 2.3, -1.2, 1.6), bevel=0.05)
    box(c, "Fridge", "Smooth", "White", (2.6, 2.4, 6.0), pos=(4.9, 0, 3.0), bevel=0.3)
    box(c, "Handle", "Metal", "Steel", (0.15, 0.2, 1.6), pos=(3.8, -1.25, 3.8), bevel=0.03)


def shelf(c):
    for sx in (-2.4, 2.4):
        box(c, "Side", "Wood", "Bark", (0.3, 1.8, 7), pos=(sx, 0, 3.5), bevel=0.06)
    for z in (0.3, 2.4, 4.5, 6.8):
        box(c, "Board", "Wood", "Bark", (5.0, 1.8, 0.25), pos=(0, 0, z), bevel=0.04)
    colors = ["Coral", "Cobalt", "Mustard", "Teal", "Cream", "Mint"]
    for row, z in enumerate((0.45, 2.55, 4.65)):
        x = -2.0
        while x < 1.9:
            wbook = rng.uniform(0.3, 0.6)
            hbook = rng.uniform(1.2, 1.8)
            o = box(c, "Book", "Smooth", colors[rng.randrange(len(colors))], (wbook, 1.4, hbook), pos=(x + wbook / 2, 0, z + hbook / 2), bevel=0.03)
            jitter(o, 3)
            x += wbook + 0.05


# --------------------------------------------------------------------------- street props

def street_lamp(c):
    box(c, "Base", "Metal", "HazardBlack", (1.2, 1.2, 1.2), pos=(0, 0, 0.6), bevel=0.2)
    cyl(c, "Pole", "Metal", "HazardBlack", 0.3, 12, pos=(0, 0, 6.6), verts=8)
    cyl(c, "Collar", "Metal", "HazardBlack", 0.5, 0.5, pos=(0, 0, 3), verts=8)
    box(c, "Arm", "Metal", "HazardBlack", (0.3, 2.6, 0.3), pos=(0, -1.2, 12.4), bevel=0.05)
    box(c, "Head", "Metal", "HazardBlack", (1.6, 1.6, 0.5), pos=(0, -2.4, 12.6), bevel=0.15)
    box(c, "Lantern", "Neon", "WindowWarm", (1.1, 1.1, 1.4), pos=(0, -2.4, 11.6), bevel=0.15)


def power_pole(c):
    cyl(c, "Pole", "Wood", "Bark", 0.55, 20, pos=(0, 0, 10), verts=8)
    box(c, "Crossarm", "Wood", "Bark", (6.5, 0.5, 0.5), pos=(0, 0, 18.6), bevel=0.08)
    for x in (-2.8, -1.0, 1.0, 2.8):
        cyl(c, "Insulator", "Glass", "Glass", 0.18, 0.5, pos=(x, 0, 19.1), verts=8)
    cyl(c, "Transformer", "Metal", "Steel", 0.9, 2.2, pos=(0, -0.9, 15.5), verts=10)
    box(c, "Sign", "Smooth", "SafetyYellow", (0.9, 0.1, 0.9), pos=(0, -0.58, 7), rot=(0, 45, 0), bevel=0.03)


def hydrant(c):
    cyl(c, "Body", "Metal", "Coral", 0.55, 2.2, pos=(0, 0, 1.1), verts=10)
    sphere(c, "Cap", "Metal", "Coral", 0.6, pos=(0, 0, 2.3), scale=(1, 1, 0.7))
    for rot in ((0, 90, 0), (90, 0, 0)):
        cyl(c, "Nozzle", "Metal", "Mustard", 0.25, 1.6, pos=(0, 0, 1.5), rot=rot, verts=8)
    cyl(c, "Base", "Metal", "Coral", 0.75, 0.3, pos=(0, 0, 0.15), verts=10)


def bench(c):
    for i in range(3):
        box(c, "Slat", "Planks", "Bark", (6, 0.5, 0.2), pos=(0, -0.6 + i * 0.6, 1.6), bevel=0.05)
    for i in range(2):
        box(c, "BackSlat", "Planks", "Bark", (6, 0.2, 0.5), pos=(0, 0.95, 2.4 + i * 0.7), rot=(-10, 0, 0), bevel=0.05)
    for sx in (-2.6, 2.6):
        box(c, "Leg", "Metal", "HazardBlack", (0.3, 1.8, 1.6), pos=(sx, 0, 0.8), bevel=0.06)
        box(c, "ArmRest", "Metal", "HazardBlack", (0.3, 1.6, 0.25), pos=(sx, -0.1, 2.3), bevel=0.05)


def trash_can(c):
    cyl(c, "Can", "Metal", "ContainerGreen", 1.0, 2.8, pos=(0, 0, 1.4), verts=12)
    for z in (0.6, 1.4, 2.2):
        cyl(c, "Band", "Metal", "Gunmetal", 1.05, 0.15, pos=(0, 0, z), verts=12, bevel=0.0)
    cyl(c, "Lid", "Metal", "Gunmetal", 1.15, 0.3, pos=(0.2, 0, 3.0), rot=(0, 8, 0), verts=12)
    box(c, "Bag", "Fabric", "HazardBlack", (1.2, 1.0, 0.6), pos=(0.2, 0, 3.2), rot=(0, 8, 20), bevel=0.25)


def mailbox(c):
    box(c, "Post", "Wood", "Bark", (0.4, 0.4, 3.6), pos=(0, 0, 1.8), bevel=0.06)
    box(c, "Box", "Metal", "Cobalt", (1.2, 2.2, 1.2), pos=(0, 0, 4.0), bevel=0.4)
    box(c, "Flag", "Metal", "Coral", (0.1, 0.3, 0.9), pos=(0.65, 0.5, 4.5), bevel=0.02)


def stop_sign(c):
    cyl(c, "Pole", "Metal", "Steel", 0.15, 8, pos=(0, 0, 4), verts=6, bevel=0.0)
    cyl(c, "Sign", "Smooth", "Coral", 1.4, 0.2, pos=(0, -0.2, 7.6), rot=(90, 0, 0), verts=8, bevel=0.03)
    cyl(c, "Border", "Smooth", "White", 1.5, 0.15, pos=(0, -0.1, 7.6), rot=(90, 0, 0), verts=8, bevel=0.0)


def picket_fence(c):
    for i in range(9):
        o = box(c, "Picket", "Planks", "White", (0.6, 0.25, 3.2 + (0.4 if i % 2 else 0)), pos=(-4 + i * 1.0, 0, 1.7), bevel=0.06)
        jitter(o, 2)
    for z in (1.0, 2.6):
        box(c, "Rail", "Planks", "White", (9, 0.25, 0.35), pos=(0, 0.2, z), bevel=0.05)


def tree_blocky(c):
    """Chunky cube-canopy tree like the art reference."""
    box(c, "Trunk", "Wood", "Bark", (1.6, 1.6, 9), pos=(0, 0, 4.5), rot=(0, 3, 0), bevel=0.2)
    box(c, "Branch", "Wood", "Bark", (0.9, 0.9, 4), pos=(1.4, 0, 7.5), rot=(0, 40, 0), bevel=0.15)
    spots = [(0, 0, 11, 6.5), (2.6, 1.0, 9.5, 4.5), (-2.4, -0.8, 10, 4.8), (0.6, -2.2, 12.6, 4.2), (-0.8, 2.0, 13, 3.8)]
    for x, y, z, s in spots:
        o = box(c, "Leaves", "Grass", "Leaf" if s > 4.4 else "GrassDark", (s, s, s * 0.85), pos=(x, y, z), bevel=0.35)
        jitter(o, 12)


def bush_round(c):
    for x, y, z, s in [(0, 0, 1.2, 2.2), (1.4, 0.4, 1.0, 1.6), (-1.3, -0.3, 0.9, 1.5)]:
        sphere(c, "Bush", "Grass", "GrassDark" if s < 2 else "Leaf", s, pos=(x, y, z), scale=(1, 1, 0.8), subdiv=1)


def planter(c):
    box(c, "Box", "Brick", "Terracotta", (6, 2, 1.6), pos=(0, 0, 0.8), bevel=0.15)
    box(c, "Soil", "Grass", "Bark", (5.6, 1.6, 0.2), pos=(0, 0, 1.55), bevel=0.0)
    for x in (-1.8, 0, 1.8):
        sphere(c, "Flower", "Plastic", rng.choice(["Coral", "Mustard", "NeonPink", "Cobalt"]), 0.6, pos=(x, 0, 2.2))
        sphere(c, "Leaf", "Grass", "Leaf", 0.8, pos=(x + 0.5, 0.2, 1.9), scale=(1, 1, 0.6))


def barrier(c):
    for sx in (-2.2, 2.2):
        box(c, "Leg", "Metal", "Steel", (0.3, 1.6, 3), pos=(sx, 0, 1.5), rot=(0, 0, 0), bevel=0.05)
    for z in (1.6, 2.6):
        box(c, "Plank", "Smooth", "White", (5.4, 0.3, 0.6), pos=(0, 0, z), bevel=0.06)
        for i in range(3):
            box(c, "Stripe", "Smooth", "Coral", (0.8, 0.35, 0.62), pos=(-1.8 + i * 1.8, 0, z), rot=(0, 30, 0), bevel=0.0)
    box(c, "Light", "Neon", "SafetyYellow", (0.5, 0.5, 0.5), pos=(2.2, 0, 3.2), bevel=0.12)


def cone(c):
    cyl(c, "Cone", "Plastic", "Terracotta", 0.6, 2.2, pos=(0, 0, 1.25), verts=10, radius_top=0.12, bevel=0.0)
    cyl(c, "Stripe", "Plastic", "White", 0.42, 0.35, pos=(0, 0, 1.35), verts=10, radius_top=0.34, bevel=0.0)
    box(c, "Base", "Plastic", "Terracotta", (1.6, 1.6, 0.2), pos=(0, 0, 0.1), bevel=0.06)


def debris_branch(c):
    box(c, "Branch", "Wood", "Bark", (0.8, 0.8, 7), pos=(0, 0, 0.5), rot=(0, 85, 10), bevel=0.15)
    box(c, "Twig", "Wood", "Bark", (0.5, 0.5, 3), pos=(1, 0.8, 0.8), rot=(0, 70, 50), bevel=0.1)
    for x, y in ((2.6, 0.4), (-1.8, -0.6), (0.8, 1.6)):
        o = box(c, "Leaves", "Grass", "Leaf", (2.4, 2.2, 1.4), pos=(x, y, 1.0), bevel=0.3)
        jitter(o, 20)


def debris_sheet(c):
    o = box(c, "Sheet", "Rusty", "Rust", (4, 6, 0.25), pos=(0, 0, 0.6), rot=(10, -6, 25), bevel=0.05)
    for i in range(4):
        box(c, "Rib", "Metal", "Rust", (0.3, 6, 0.4), pos=(-1.5 + i, 0, 0.75 + i * 0.12), rot=(10, -6, 25), bevel=0.04)
    box(c, "Board", "Planks", "Bark", (0.8, 5, 0.4), pos=(2.6, 1.0, 0.3), rot=(0, 0, 35), bevel=0.06)


BUILDERS = [
    ("HouseA", house_a), ("HouseB", house_b),
    ("Sofa", sofa), ("Bed", bed), ("Kitchen", kitchen), ("Shelf", shelf),
    ("StreetLamp", street_lamp), ("PowerPole", power_pole), ("Hydrant", hydrant), ("Bench", bench),
    ("TrashCan", trash_can), ("Mailbox", mailbox), ("StopSign", stop_sign), ("PicketFence", picket_fence),
    ("TreeBlocky", tree_blocky), ("BushRound", bush_round), ("Planter", planter), ("Barrier", barrier),
    ("Cone", cone), ("DebrisBranch", debris_branch), ("DebrisSheet", debris_sheet),
]

if __name__ == "__main__":
    build_set("town", BUILDERS)
