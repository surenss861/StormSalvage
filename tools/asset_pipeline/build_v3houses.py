# @file V3 Milestone C1: the Houses district. Front faces Blender -Y; origin at the base centre
# @domain world
# @status stable
"""V3 Milestone C1: the Houses district. Front faces Blender -Y; origin at the base centre.

The two house shells keep the V2 gameplay contract from build_town.py exactly, because
MapBuilder.building() owns collision, shelter and loot:
  30 x 28 footprint, 12-stud walls, an 8 x 9 door centred on the front wall,
  ridge 7 (A) / 6 (B) over invisible RoofSlope wedges, porch roof at 10.4 with widths 16 (A)
  and 31 (B) matching the invisible porch-shelter parts.
Walls use the "Plaster" swatch and roofs "RoofRed" so MapBuilder recolours each house.

The rest is the yard kit (fence, shed, ladder, clothesline, sedan) and the district
landmark: an uprooted oak lying across the west end of the lane.

blender -b --python tools/asset_pipeline/build_v3houses.py
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from kit import box, build_set, cyl, jitter, rng, sphere, wedge  # noqa: E402
from build_town import D, DOOR_W, H, W, gable_roof, porch, trim, vines, wall_with_openings  # noqa: E402


# --------------------------------------------------------------------------- house detail layers

def window(c, axis, offset, along, z, size=(4.0, 4.0), outward=1, shutter="Cobalt", boarded=False):
    """Same read as build_town.window at about a fifth of the triangles: one frame slab behind
    the glass instead of four bevelled pieces, unbevelled mullion, sill and shutters."""
    w, h = size

    def at(a, depth, zz):
        return (a, offset + depth * outward, zz) if axis == "x" else (offset + depth * outward, a, zz)

    def sz(a, depth, zz):
        return (a, depth, zz) if axis == "x" else (depth, a, zz)

    box(c, "Frame", "Smooth", "Cream", sz(w + 1.0, 0.3, h + 1.0), pos=at(along, 0.1, z), bevel=0.0)
    box(c, "Glass", "Glass", "WindowWarm", sz(w, 0.3, h), pos=at(along, 0.2, z), bevel=0.0)
    box(c, "Mullion", "Smooth", "Cream", sz(0.25, 0.4, h), pos=at(along, 0.3, z), bevel=0.0)
    box(c, "Sill", "Smooth", "Cream", sz(w + 1.4, 1.0, 0.35), pos=at(along, 0.5, z - h / 2 - 0.55), bevel=0.0)
    for side in (-1, 1):
        box(c, "Shutter", "Planks", shutter, sz(1.6, 0.3, h + 0.6), pos=at(along + side * (w / 2 + 1.3), 0.35, z), bevel=0.0)
    if boarded:
        for i, tilt in enumerate((-12, 10)):
            o = box(c, "Board", "Planks", "Bark", sz(w + 0.8, 0.3, 0.6), pos=at(along, 0.6, z - 0.6 + i * 1.2), bevel=0.0)
            if axis == "x":
                o.rotation_euler.y += math.radians(tilt)
            else:
                o.rotation_euler.x += math.radians(tilt)


def siding(c, skip_front_door=True):
    """Lap siding: thin horizontal boards proud of every wall, broken around the front door.
    Wall swatch, so the per-house recolour applies."""
    for z in [1.9 + i * 1.25 for i in range(8)]:
        for sy in (-1, 1):
            y = sy * (D / 2 + 0.55)
            if sy < 0 and skip_front_door and z < 9.2:
                for sx in (-1, 1):
                    seg = (W - DOOR_W - 2.6) / 2
                    box(c, "Siding", "Smooth", "Plaster", (seg, 0.18, 0.35),
                        pos=(sx * (DOOR_W / 2 + 1.3 + seg / 2), y, z), bevel=0.0)
            else:
                box(c, "Siding", "Smooth", "Plaster", (W - 1.0, 0.18, 0.35), pos=(0, y, z), bevel=0.0)
        for sx in (-1, 1):
            box(c, "Siding", "Smooth", "Plaster", (0.18, D - 1.0, 0.35), pos=(sx * (W / 2 + 0.55), 0, z), bevel=0.0)


def foundation(c):
    """Raised stone skirt with crawlspace vents, over the V2 base ring."""
    for sy in (-1, 1):
        box(c, "Skirt", "Brick", "Stone", (W + 1.6, 0.5, 1.5), pos=(0, sy * (D / 2 + 0.75), 0.75), bevel=0.08)
        for x in (-10, 10):
            box(c, "Vent", "Metal", "Gunmetal", (1.6, 0.2, 0.6), pos=(x, sy * (D / 2 + 1.05), 0.8), bevel=0.04)
    for sx in (-1, 1):
        box(c, "Skirt", "Brick", "Stone", (0.5, D + 1.6, 1.5), pos=(sx * (W / 2 + 0.75), 0, 0.75), bevel=0.08)


def gutters(c, ridge_h, overhang=1.5):
    half = D / 2 + overhang
    for sy in (-1, 1):
        box(c, "Gutter", "Metal", "Steel", (W + overhang * 2, 0.5, 0.45), pos=(0, sy * (half + 0.15), H - 0.1), bevel=0.06)
    for sx, sy in ((-1, -1), (1, 1)):
        cyl(c, "Downpipe", "Metal", "Steel", 0.22, H - 0.5, pos=(sx * (W / 2 + 1.0), sy * (D / 2 + 1.2), (H - 0.5) / 2),
            verts=8, bevel=0.0)


def porch_detail(c, width):
    """Balusters, a porch light and a swing/chair on the V2 porch deck (depth 5)."""
    depth = 5.0
    yfront = -D / 2 - depth + 0.6
    span = (width - DOOR_W) / 2 - 1.5
    for sx in (-1, 1):
        x0 = sx * (DOOR_W / 2 + 0.8)
        n = max(2, int(span / 0.8))
        for i in range(n):
            x = x0 + sx * (i + 0.5) * span / n
            box(c, "Baluster", "Smooth", "Cream", (0.22, 0.22, 2.0), pos=(x, yfront, 2.0), bevel=0.0)
        box(c, "Handrail", "Smooth", "Cream", (span, 0.5, 0.3), pos=(x0 + sx * span / 2, yfront, 3.15), bevel=0.06)
    # Two steps down from the deck.
    box(c, "Step", "Concrete", "Stone", (6.4, 1.2, 0.5), pos=(0, -D / 2 - depth - 1.2, 0.25), bevel=0.06)


def chair(c, x, y, swatch="Teal"):
    box(c, "ChairSeat", "Planks", swatch, (1.8, 1.8, 0.3), pos=(x, y, 1.9), bevel=0.06)
    box(c, "ChairBack", "Planks", swatch, (1.8, 0.3, 1.8), pos=(x, y + 0.9, 2.8), rot=(-12, 0, 0), bevel=0.06)
    for dx in (-0.75, 0.75):
        for dy in (-0.75, 0.75):
            box(c, "ChairLeg", "Planks", swatch, (0.2, 0.2, 0.9), pos=(x + dx, y + dy, 1.45), bevel=0.0)


def tarp(c, x, y, ridge_h, slope_side=1):
    """Blue tarp over a damaged roof section, weighted with sandbags and a tyre."""
    half = D / 2 + 1.5
    angle = math.degrees(math.atan2(ridge_h, half))
    t = 0.55
    z = H + ridge_h * (1 - t) + 1.05
    box(c, "Tarp", "Fabric", "ContainerBlue", (9.0, 7.0, 0.15), pos=(x, slope_side * half * t, z),
        rot=(-slope_side * angle, 0, 4), bevel=0.04)
    for dx, dy in ((-4, -2.6), (4, -2.6), (-4, 2.6), (4, 2.6)):
        yy = slope_side * half * t + dy * math.cos(math.radians(angle))
        zz = z - slope_side * dy * math.sin(math.radians(angle)) + 0.35
        jitter(box(c, "Sandbag", "Fabric", "Sand", (1.3, 0.8, 0.55), pos=(x + dx, yy, zz),
                   rot=(-slope_side * angle, 0, 0), bevel=0.22, segments=2), 6)


def missing_shingles(c, x, y_t, ridge_h, slope_side=-1):
    """A torn patch: bare sheathing boards where shingles blew off."""
    half = D / 2 + 1.5
    angle = math.degrees(math.atan2(ridge_h, half))
    z = H + ridge_h * (1 - y_t) + 0.95
    for i in range(3):
        box(c, "Sheathing", "Planks", "Bark", (2.2, 3.8, 0.2), pos=(x - 2.4 + i * 2.4, slope_side * half * y_t, z),
            rot=(-slope_side * angle, 0, rng.uniform(-6, 6)), bevel=0.03)


def house_v3(c, variant):
    a = variant == "A"
    shutter = "Teal" if a else "Mustard"
    # V2 shell structure (walls with openings, windows, base ring, door frame, roof).
    front_open = [(0.0, DOOR_W, 0.0, 9.0), (-9.5, 4.4, 3.5, 8.3), (9.5, 4.4, 3.5, 8.3)]
    if not a:
        front_open[1] = (-9.5, 7.0, 3.0, 8.5)
    wall_with_openings(c, "x", -D / 2, W, front_open)
    wall_with_openings(c, "x", D / 2, W, [(-7, 4.4, 3.5, 8.3), (7, 4.4, 3.5, 8.3)])
    wall_with_openings(c, "y", -W / 2, D, [(-5, 4.4, 3.5, 8.3), (6, 4.4, 3.5, 8.3)])
    wall_with_openings(c, "y", W / 2, D, [(-5, 4.4, 3.5, 8.3), (6, 4.4, 3.5, 8.3)])
    window(c, "x", -D / 2 - 0.7, 9.5, 5.9, outward=-1, shutter=shutter)
    if a:
        window(c, "x", -D / 2 - 0.7, -9.5, 5.9, outward=-1, shutter=shutter)
    else:
        window(c, "x", -D / 2 - 0.7, -9.5, 5.75, size=(6.6, 5.0), outward=-1, shutter=shutter)
        box(c, "BayRoof", "Slate", "RoofRed", (9, 2.6, 0.5), pos=(-9.5, -D / 2 - 1.8, 9.2), rot=(-25, 0, 0), bevel=0.1)
    window(c, "x", D / 2 + 0.7, -7, 5.9, outward=1, shutter=shutter, boarded=a)
    window(c, "x", D / 2 + 0.7, 7, 5.9, outward=1, shutter=shutter)
    for wx in (-W / 2 - 0.7, W / 2 + 0.7):
        out = -1 if wx < 0 else 1
        window(c, "y", wx, -5, 5.9, outward=out, shutter=shutter, boarded=(not a and out > 0))
        window(c, "y", wx, 6, 5.9, outward=out, shutter=shutter)
    trim(c)
    ridge = 7.0 if a else 6.0
    gable_roof(c, ridge_h=ridge)
    # V3 layers.
    siding(c)
    foundation(c)
    gutters(c, ridge)
    # Front door itself, ajar (players walk through the gameplay doorway).
    box(c, "Door", "Planks", "Coral" if a else "Teal", (3.8, 0.3, 8.6), pos=(-DOOR_W / 2 + 0.3, -D / 2 - 0.4 + 1.6, 4.4),
        rot=(0, 0, -62), bevel=0.06)
    box(c, "DoorKnob", "Metal", "Mustard", (0.3, 0.3, 0.3), pos=(-DOOR_W / 2 + 1.9, -D / 2 + 3.0, 4.2), bevel=0.0)
    if a:
        # Dormer and front-gable porch with a pediment.
        box(c, "Dormer", "Smooth", "Plaster", (6, 4, 4), pos=(6, -4.5, H + 4.2), bevel=0.1)
        box(c, "DormerRoof", "Slate", "RoofRed", (7, 5, 0.5), pos=(6, -4.8, H + 6.5), rot=(-20, 0, 0), bevel=0.1)
        box(c, "DormerGlass", "Glass", "WindowWarm", (3, 0.3, 2.2), pos=(6, -6.6, H + 4.3), bevel=0.0)
        box(c, "DormerFrame", "Smooth", "Cream", (3.8, 0.4, 3.0), pos=(6, -6.5, H + 4.3), bevel=0.1)
        porch(c, 16)
        porch_detail(c, 16)
        wedge(c, "Pediment", "Smooth", "Cream", (17.2, 0.5, 2.4), pos=(0, -D / 2 - 4.7, 11.9), rot=(90, 0, 0), bevel=0.05)
        chair(c, -5.5, -D / 2 - 2.6)
        box(c, "Chimney", "Brick", "Terracotta", (2.8, 2.8, 9), pos=(-9, 4, H + 4.5), bevel=0.15)
        box(c, "ChimneyCap", "Concrete", "Stone", (3.4, 3.4, 0.6), pos=(-9, 4, H + 9.2), bevel=0.1)
        vines(c, -W / 2 - 0.9, -D / 2 + 1, 9)
        tarp(c, 5, 0, ridge, slope_side=1)
        missing_shingles(c, -4, 0.4, ridge, slope_side=-1)
        # Window boxes with flowers under the front windows.
        for x in (-9.5, 9.5):
            box(c, "WindowBox", "Planks", "Bark", (4.6, 1.0, 0.9), pos=(x, -D / 2 - 1.5, 2.6), bevel=0.06)
            for i in range(4):
                sphere(c, "Flower", "Grass", "Coral" if i % 2 else "Mustard", 0.45,
                       pos=(x - 1.6 + i * 1.05, -D / 2 - 1.5, 3.25), subdiv=1)
    else:
        porch(c, W + 1)
        porch_detail(c, W + 1)
        chair(c, -11.5, -D / 2 - 2.6, "Coral")
        chair(c, 11.5, -D / 2 - 2.6, "Coral")
        box(c, "Chimney", "Brick", "Terracotta", (3.2, 2.6, H + 9), pos=(W / 2 + 1.6, 3, (H + 9) / 2), bevel=0.15)
        box(c, "ChimneyCap", "Concrete", "Stone", (3.8, 3.2, 0.6), pos=(W / 2 + 1.6, 3, H + 9.3), bevel=0.1)
        vines(c, W / 2 + 0.9, D / 2 - 1, 10)
        # Storm damage: a bent satellite dish, a gutter hanging loose, shingles torn off.
        cyl(c, "Dish", "Metal", "White", 1.4, 0.3, pos=(-9, 6, H + 5.4), rot=(55, 20, 30), verts=12, radius_top=0.4, bevel=0.0)
        box(c, "DishArm", "Metal", "Steel", (0.2, 0.2, 2.2), pos=(-9, 6.6, H + 4.4), rot=(30, 0, 0), bevel=0.0)
        box(c, "LooseGutter", "Metal", "Steel", (9, 0.5, 0.45), pos=(10, D / 2 + 1.8, H - 3.2),
            rot=(0, 28, 0), bevel=0.05)
        missing_shingles(c, 2, 0.45, ridge, slope_side=1)
        # Sandbags at the front step: this family stayed for the flood.
        for i, x in enumerate((-4.4, -3.1, 3.1, 4.4)):
            jitter(box(c, "Sandbag", "Fabric", "Sand", (1.3, 0.8, 0.6), pos=(x, -D / 2 - 6.6, 0.3 + (i % 2) * 0.05),
                       bevel=0.22, segments=2), 5)
    box(c, "HouseNumber", "Smooth", "HazardBlack", (1.6, 0.15, 0.8), pos=(DOOR_W / 2 + 1.4, -D / 2 - 0.65, 9.6), bevel=0.0)


def house_v3a(c):
    house_v3(c, "A")


def house_v3b(c):
    house_v3(c, "B")


# --------------------------------------------------------------------------- yard kit

def roof_ladder(c):
    """Galvanised ladder over the flood-escape TrussPart (16 tall). Brackets reach 2.5 studs
    toward the wall at Blender -Y, so it is placed with the default orientation."""
    for sx in (-0.9, 0.9):
        box(c, "Rail", "Metal", "SafetyYellow", (0.25, 0.25, 16.0), pos=(sx, 0, 8.0), bevel=0.04)
    for i in range(15):
        cyl(c, "Rung", "Metal", "Steel", 0.1, 1.8, pos=(0, 0, 0.8 + i * 1.0), rot=(0, 90, 0), verts=6, bevel=0.0)
    for z in (4, 11.5):
        for sx in (-0.9, 0.9):
            box(c, "Bracket", "Metal", "Gunmetal", (0.2, 2.6, 0.2), pos=(sx, -1.3, z), bevel=0.0)
    # Hand loops past the roof edge.
    for sx in (-0.9, 0.9):
        box(c, "Grab", "Metal", "SafetyYellow", (0.25, 1.4, 0.25), pos=(sx, -0.7, 15.9), bevel=0.04)
    box(c, "Foot", "Concrete", "Stone", (2.6, 1.4, 0.3), pos=(0, 0, 0.15), bevel=0.05)


def privacy_fence(c):
    """8-stud wooden board fence section, 5 tall, posts at the ends. Repeated 16 times, so the
    boards are unbevelled (a bevel on a 0.15-stud board can't be seen); posts and rails keep
    theirs. 660 -> ~310 triangles with the same silhouette."""
    for x in (-3.8, 3.8):
        box(c, "Post", "Planks", "Bark", (0.5, 0.5, 5.4), pos=(x, 0, 2.7), bevel=0.06)
    for i in range(11):
        o = box(c, "Board", "Planks", "Sand" if i % 4 else "Bark", (0.68, 0.15, 4.6 + (i % 3) * 0.15),
                pos=(-3.4 + i * 0.68, -0.25, 2.5), bevel=0.0)
        jitter(o, 0.6)
    for z in (1.2, 4.0):
        box(c, "Rail", "Planks", "Bark", (8.0, 0.3, 0.4), pos=(0, 0.1, z), bevel=0.04)


def garden_shed(c):
    """Closed backyard shed (no interior, so it never reads as shelter)."""
    box(c, "Walls", "Planks", "ContainerGreen", (6.0, 5.0, 6.0), pos=(0, 0, 3.0), bevel=0.1)
    for side in (-1, 1):
        box(c, "Roof", "Rusty", "Rust", (7.0, 3.3, 0.3), pos=(0, side * 1.35, 6.9), rot=(-side * 28, 0, 0), bevel=0.04)
    # Gable ends at +/-X: two half-triangles each, tall at the ridge (y = 0).
    for x in (-2.85, 2.85):
        wedge(c, "Gable", "Planks", "ContainerGreen", (0.3, 2.5, 1.3), pos=(x, 1.25, 6.65), bevel=0.0)
        wedge(c, "Gable", "Planks", "ContainerGreen", (0.3, 2.5, 1.3), pos=(x, -1.25, 6.65), rot=(0, 0, 180), bevel=0.0)
    box(c, "Door", "Planks", "Cream", (2.6, 0.25, 4.6), pos=(0, -2.55, 2.4), bevel=0.05)
    box(c, "DoorZ", "Planks", "Cream", (0.4, 0.2, 5.0), pos=(0, -2.7, 2.4), rot=(0, 30, 0), bevel=0.0)
    box(c, "Hasp", "Metal", "Steel", (0.3, 0.2, 0.5), pos=(1.0, -2.75, 2.6), bevel=0.0)
    box(c, "Base", "Concrete", "Concrete", (6.6, 5.6, 0.3), pos=(0, 0, 0.15), bevel=0.05)
    for i, (x, z) in enumerate(((3.6, 0.6), (3.6, 1.6))):
        cyl(c, "Pot", "Plastic", "Terracotta", 0.5, 0.8, pos=(x, -1.5 + i, 0.4), verts=8, bevel=0.0)


def clothesline(c):
    """Two T-posts and a sagging line with laundry the wind is pulling at."""
    for x in (-5.0, 5.0):
        box(c, "Post", "Metal", "Steel", (0.3, 0.3, 6.0), pos=(x, 0, 3.0), bevel=0.0)
        box(c, "Cross", "Metal", "Steel", (0.3, 2.0, 0.3), pos=(x, 0, 5.9), bevel=0.0)
    for y in (-0.8, 0.8):
        for i in range(5):
            x0, x1 = -5 + i * 2, -3 + i * 2
            sag = lambda x: 5.8 - 0.6 * (1 - (x / 5) ** 2)  # noqa: E731
            mid = (x0 + x1) / 2
            ang = math.degrees(math.atan2(sag(x1) - sag(x0), 2))
            box(c, "Line", "Smooth", "White", (2.05, 0.06, 0.06), pos=(mid, y, (sag(x0) + sag(x1)) / 2), rot=(0, -ang, 0), bevel=0.0)
    for i, (x, sw, w, h) in enumerate(((-3.4, "Coral", 1.6, 2.0), (-1.2, "Cobalt", 2.2, 1.4), (1.0, "Mustard", 1.4, 1.8),
                                        (3.2, "White", 2.0, 2.4))):
        y = -0.8 if i % 2 else 0.8
        o = box(c, "Laundry", "Fabric", sw, (w, 0.1, h), pos=(x, y + 0.25, 5.3 - h / 2), rot=(18, 0, 0), bevel=0.02)
        jitter(o, 4)


def sedan(c):
    """Family car in the driveway, a branch from the storm across the bonnet. Length along Y."""
    box(c, "Body", "Metal", "Coral", (5.6, 12.0, 2.0), pos=(0, 0, 1.9), bevel=0.45, segments=2)
    box(c, "Cabin", "Metal", "Coral", (5.0, 6.2, 1.9), pos=(0, 0.8, 3.75), bevel=0.45, segments=2)
    box(c, "Windows", "Glass", "Glass", (5.1, 5.8, 1.3), pos=(0, 0.8, 3.85), bevel=0.3)
    box(c, "Bumper", "Smooth", "Gunmetal", (5.8, 0.6, 0.7), pos=(0, -6.1, 1.2), bevel=0.2)
    box(c, "Bumper", "Smooth", "Gunmetal", (5.8, 0.6, 0.7), pos=(0, 6.1, 1.2), bevel=0.2)
    for sx in (-1, 1):
        box(c, "Headlight", "Neon", "WindowWarm", (1.2, 0.2, 0.5), pos=(sx * 1.9, -6.05, 2.2), bevel=0.05)
        box(c, "Taillight", "Neon", "Coral", (1.2, 0.2, 0.5), pos=(sx * 1.9, 6.05, 2.2), bevel=0.05)
        for y in (-3.8, 3.8):
            cyl(c, "Wheel", "Rubber", "Rubber", 1.15, 0.9, pos=(sx * 2.7, y, 1.15), rot=(0, 90, 0), verts=12, bevel=0.1)
            cyl(c, "Hub", "Metal", "Steel", 0.5, 0.95, pos=(sx * 2.75, y, 1.15), rot=(0, 90, 0), verts=8, bevel=0.0)
    box(c, "Branch", "Wood", "Bark", (0.7, 0.7, 9.0), pos=(0.4, -3.5, 3.4), rot=(0, 78, 25), bevel=0.15)
    for x, y in ((3.6, -4.6), (-2.4, -2.4)):
        jitter(box(c, "Leaves", "Grass", "Leaf", (2.4, 2.2, 1.4), pos=(x, y, 3.5), bevel=0.3), 20)


def fallen_oak(c):
    """District landmark: an old oak the storm tore out, lying across the lane's west end.
    Trunk along X (~36 long), root plate standing up at +X, canopy crushed at -X."""
    # Trunk in overlapping, tapering segments.
    for i, (x, r) in enumerate(((10, 2.7), (2.5, 2.3), (-4.5, 1.9), (-11, 1.5))):
        cyl(c, "Trunk", "Wood", "Bark", r, 9.6, pos=(x, 0, r + 0.1), rot=(0, 90, rng.uniform(-2, 2)), verts=10, bevel=0.1)
    # A broken limb stub pointing at the sky.
    box(c, "Stub", "Wood", "Bark", (1.2, 1.2, 5.5), pos=(1.0, 0.8, 6.0), rot=(-15, 20, 0), bevel=0.15)
    box(c, "Splinter", "Wood", "Sand", (0.9, 0.9, 0.8), pos=(1.9, 1.4, 8.6), rot=(-15, 20, 0), bevel=0.05)
    # Root plate: torn-up earth standing on end, ragged with clumps and roots.
    cyl(c, "RootPlate", "Rock", "Bark", 6.5, 2.4, pos=(15.5, 0, 5.6), rot=(0, 80, 0), verts=12, bevel=0.3)
    sphere(c, "Earth", "Rock", "RustDark", 4.6, pos=(16.6, 0, 5.4), scale=(0.5, 1.25, 1.15), subdiv=1)
    for a in range(0, 360, 30):
        r = math.radians(a)
        o = box(c, "Root", "Wood", "Bark", (0.7, 0.7, 5.5), pos=(17.0, math.cos(r) * 4.4, 5.6 + math.sin(r) * 4.2),
                rot=(0, 70 + rng.uniform(-15, 15), a), bevel=0.12)
        jitter(o, 12)
    # The hole it came out of.
    cyl(c, "Crater", "Rock", "RustDark", 5.5, 0.3, pos=(20.5, 0, 0.12), verts=12, bevel=0.0)
    # Main limbs and a crushed, still-green canopy.
    for y, z, ang in ((-4, 3.2, 35), (3.5, 3.6, -40), (0.5, 5.4, 10), (-1.5, 2.2, 60)):
        box(c, "Limb", "Wood", "Bark", (1.0, 1.0, 9.0), pos=(-18, y, z), rot=(ang, 70, 0), bevel=0.15)
    for _ in range(18):
        o = sphere(c, "Canopy", "Grass", "Leaf" if rng.random() < 0.7 else "GrassDark", rng.uniform(2.6, 4.2),
                   pos=(rng.uniform(-28, -13), rng.uniform(-8, 8), rng.uniform(1.6, 8.0)), scale=(1.2, 1.0, 0.85), subdiv=1)
        jitter(o, 15)
    # The road crew left a cut round and the stump of a sawn limb.
    cyl(c, "CutRound", "Wood", "Sand", 1.8, 1.4, pos=(-8, 5.2, 0.7), verts=10, bevel=0.1)
    cyl(c, "Rings", "Wood", "Bark", 1.82, 0.08, pos=(-8, 5.2, 1.42), verts=10, bevel=0.0)


BUILDERS = [
    ("HouseV3A", house_v3a),
    ("HouseV3B", house_v3b),
    ("RoofLadder", roof_ladder),
    ("PrivacyFence", privacy_fence),
    ("GardenShed", garden_shed),
    ("Clothesline", clothesline),
    ("Sedan", sedan),
    ("FallenOak", fallen_oak),
]

if __name__ == "__main__":
    build_set("v3houses", BUILDERS, layout_spacing=6)
