"""V3 hero assets (Milestone B2): the buildings and machines that define the Scrapyard and
Town Square. Front of each asset faces Blender -Y (the side players approach).

blender -b --python tools/asset_pipeline/build_v3hero.py

Counters keep the old shacks' contract: the service counter's front edge sits 4.4 studs in front
of the asset origin, so the existing invisible prompt parts and placement code still line up.
Signs: each building has exactly one Signboard mesh; the game paints its text at runtime.
Budgets (docs/production/V3-PERFORMANCE-BUDGETS.md): hero assets <= 10,000 triangles.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from kit import box, build_set, cyl, gable, jitter, rng, sphere, torus, wedge  # noqa: E402,F401
from build_scrapyard import lattice_mast  # noqa: E402


# --------------------------------------------------------------------------- helpers

def corrugated(c, piece, material, swatch, width, height, pos, axis="x", ribs=None, depth=0.25):
    """Corrugated sheet: a flat panel plus raised ribs, along X (or Y) at pos (center)."""
    x, y, z = pos
    if axis == "x":
        box(c, piece, material, swatch, (width, depth, height), pos=pos, bevel=0.04)
        n = ribs or max(3, int(width / 1.1))
        for i in range(n):
            rx = x - width / 2 + (i + 0.5) * width / n
            box(c, piece, material, swatch, (0.35, depth + 0.25, height), pos=(rx, y, z), bevel=0)
    else:
        box(c, piece, material, swatch, (depth, width, height), pos=pos, bevel=0.04)
        n = ribs or max(3, int(width / 1.1))
        for i in range(n):
            ry = y - width / 2 + (i + 0.5) * width / n
            box(c, piece, material, swatch, (depth + 0.25, 0.35, height), pos=(x, ry, z), bevel=0)


def hazard_band(c, width, height, pos, axis="x", stripes=6):
    """Yellow and black diagonal-looking band (alternating blocks)."""
    x, y, z = pos
    for i in range(stripes):
        sw = "SafetyYellow" if i % 2 == 0 else "HazardBlack"
        if axis == "x":
            box(c, "Hazard", "Smooth", sw, (width / stripes, 0.3, height),
                pos=(x - width / 2 + (i + 0.5) * width / stripes, y, z), bevel=0.02)
        else:
            box(c, "Hazard", "Smooth", sw, (0.3, width / stripes, height),
                pos=(x, y - width / 2 + (i + 0.5) * width / stripes, z), bevel=0.02)


def cog(c, radius, pos, rot=(90, 0, 0), teeth=10, swatch="Mustard", material="Metal"):
    """Gear wheel: ring + hub + teeth, facing along local Z (rot 90 on X faces -Y)."""
    x, y, z = pos
    torus(c, "Cog", material, swatch, radius, radius * 0.22, pos=pos, rot=rot, segments=20)
    cyl(c, "Cog", material, swatch, radius * 0.35, 0.6, pos=pos, rot=rot, verts=10)
    for i in range(teeth):
        a = 2 * math.pi * i / teeth
        tx, tz = math.cos(a) * radius * 1.25, math.sin(a) * radius * 1.25
        box(c, "Cog", material, swatch, (radius * 0.35, 0.55, radius * 0.35),
            pos=(x + tx, y, z + tz), rot=(0, -math.degrees(a), 0), bevel=0.04)
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        box(c, "Cog", material, swatch, (radius * 1.6, 0.4, radius * 0.18),
            pos=(x, y, z), rot=(0, -math.degrees(a), 0), bevel=0.03)


def chain(c, top, bottom, links=8, swatch="Gunmetal"):
    tx, ty, tz = top
    bz = bottom[2]
    for i in range(links):
        z = tz - (tz - bz) * (i + 0.5) / links
        torus(c, "Chain", "Metal", swatch, 0.22, 0.07, pos=(tx, ty, z), rot=(0, 90 if i % 2 else 0, 0), segments=8)


def lamp(c, pos, swatch="WindowWarm"):
    x, y, z = pos
    cyl(c, "Lamp", "Metal", "HazardBlack", 0.7, 0.5, pos=(x, y, z), radius_top=0.25, verts=10)
    sphere(c, "Bulb", "Neon", swatch, 0.32, pos=(x, y, z - 0.35))


# --------------------------------------------------------------------------- Gear workshop

def gear_workshop(c):
    """Mechanic's workshop: corrugated hall, gable roof, service bay with counter at y=-4.4."""
    W, D, H = 22.0, 13.0, 10.0  # hall width, depth, eave height
    y0 = -2.0  # front wall plane
    yc = y0 + D / 2
    box(c, "Slab", "Concrete", "Concrete", (W + 3, D + 5, 0.6), pos=(0, yc - 1.5, 0.3), bevel=0.15)
    # Walls: corrugated blue on the sides and back, front split around the service bay.
    corrugated(c, "Wall", "Metal", "ContainerBlue", D, H, pos=(-W / 2, yc, H / 2), axis="y")
    corrugated(c, "Wall", "Metal", "ContainerBlue", D, H, pos=(W / 2, yc, H / 2), axis="y")
    corrugated(c, "Wall", "Metal", "ContainerBlue", W, H, pos=(0, y0 + D, H / 2))
    bay_w, bay_h = 11.0, 6.5
    side = (W - bay_w) / 2
    for sx in (-1, 1):
        corrugated(c, "Wall", "Metal", "ContainerBlue", side, H, pos=(sx * (bay_w / 2 + side / 2), y0, H / 2))
    corrugated(c, "Wall", "Metal", "ContainerBlue", bay_w, H - bay_h, pos=(0, y0, bay_h + (H - bay_h) / 2))
    # Painted steel frame: corner columns and a header beam over the bay.
    for sx in (-W / 2, W / 2):
        for sy in (y0, y0 + D):
            box(c, "Frame", "Metal", "SafetyYellow", (0.9, 0.9, H + 0.4), pos=(sx, sy, H / 2), bevel=0.1)
    box(c, "Frame", "Metal", "SafetyYellow", (bay_w + 1.2, 1.0, 0.9), pos=(0, y0 - 0.1, bay_h + 0.45), bevel=0.1)
    for sx in (-1, 1):
        box(c, "Frame", "Metal", "SafetyYellow", (0.9, 1.0, bay_h), pos=(sx * (bay_w / 2 + 0.45), y0 - 0.1, bay_h / 2), bevel=0.1)
    # Roll-up door, half open: ribbed slats bunched under the header.
    for i in range(5):
        box(c, "Door", "Metal", "Steel", (bay_w - 0.2, 0.35, 0.42), pos=(0, y0 + 0.4, bay_h - 0.3 - i * 0.44), bevel=0.05)
    cyl(c, "Door", "Metal", "Gunmetal", 0.5, bay_w, pos=(0, y0 + 0.6, bay_h + 0.1), rot=(0, 90, 0), verts=10)
    # Service counter: front edge at y=-4.4.
    box(c, "Counter", "Planks", "Bark", (bay_w - 1, 2.6, 0.45), pos=(0, -3.1, 3.4), bevel=0.08)
    box(c, "Counter", "Metal", "Gunmetal", (bay_w - 1.4, 1.6, 3.2), pos=(0, -2.6, 1.6), bevel=0.08)
    for sx in (-4, 0, 4):
        box(c, "Counter", "Metal", "SafetyYellow", (0.3, 0.3, 3.2), pos=(sx, -3.4, 1.6), bevel=0.04)
    box(c, "Counter", "Metal", "Steel", (bay_w - 1, 0.25, 0.25), pos=(0, -4.3, 3.45), bevel=0.04)
    # Interior: dark back, tool pegboard, engine on a stand, tyre rack.
    box(c, "Interior", "Smooth", "HazardBlack", (W - 1.4, 0.3, H - 0.5), pos=(0, y0 + D - 0.5, H / 2), bevel=0.02)
    box(c, "Pegboard", "Planks", "Plaster", (9, 0.3, 4.2), pos=(-1, y0 + D - 0.9, 4.8), bevel=0.05)
    for i, (dx, dz, sw) in enumerate([(-4.5, 6, "Coral"), (-3, 5.2, "Steel"), (-1.5, 6.1, "Mustard"),
                                      (0, 5.4, "Steel"), (1.6, 6.2, "Coral"), (3, 5, "Steel"), (-3.6, 3.6, "Gunmetal"),
                                      (-0.6, 3.5, "Teal"), (2.4, 3.7, "Gunmetal")]):
        box(c, "Tool", "Metal", sw, (0.3, 0.25, 1.4 if i % 2 else 0.9), pos=(-1 + dx, y0 + D - 1.15, dz), rot=(0, 15 * (i % 3 - 1), 0), bevel=0.03)
    box(c, "Stand", "Metal", "Coral", (2.2, 2.2, 2.4), pos=(-6.5, y0 + 6, 1.2), bevel=0.15)
    box(c, "Engine", "Plate", "Gunmetal", (2.6, 2.4, 1.8), pos=(-6.5, y0 + 6, 3.3), bevel=0.25)
    for i in range(3):
        cyl(c, "Engine", "Metal", "Steel", 0.35, 0.8, pos=(-7.4 + i * 0.9, y0 + 6, 4.5), verts=8)
    for i in range(4):
        cyl(c, "TyreRack", "Rubber", "Rubber", 1.1, 0.7, pos=(7.5, y0 + 4 + i * 0.9, 1.3), rot=(90, 0, 0), verts=14, bevel=0.15)
    box(c, "TyreRack", "Metal", "Gunmetal", (0.3, 4.4, 0.3), pos=(6.4, y0 + 5.3, 2.5), bevel=0.04)
    # Roof: gable along X, rust-red sheet, with a darker patch panel (storm repair).
    # Ridge along X; each slab rises from its eave to the ridge.
    rise, over = 3.4, 1.0
    half = D / 2 + over
    slope = math.hypot(half, rise)
    ang = math.degrees(math.atan2(rise, half))
    for side in (-1, 1):
        box(c, "Roof", "Rusty", "Rust", (W + 2 * over, slope, 0.45),
            pos=(0, yc + side * half / 2, H + rise / 2), rot=(-side * ang, 0, 0), bevel=0.08)
        for i in range(5):  # standing seams
            box(c, "Roof", "Rusty", "Rust", (0.3, slope, 0.7),
                pos=(-W / 2 + (i + 0.5) * W / 5, yc + side * half / 2, H + rise / 2 + 0.1), rot=(-side * ang, 0, 0), bevel=0.04)
        # Gable-end triangles (the wedge's tall end faces -Y, so the back half is turned round).
        for sx in (-1, 1):
            wedge(c, "Gable", "Metal", "ContainerBlue", (0.4, D / 2, rise), pos=(sx * W / 2, yc + side * D / 4, H + rise / 2),
                  rot=(0, 0, 0 if side > 0 else 180))
    box(c, "Ridge", "Metal", "Gunmetal", (W + 2 * over, 0.7, 0.5), pos=(0, yc, H + rise + 0.1), bevel=0.08)
    box(c, "Patch", "Metal", "Teal", (5, 3.2, 0.3), pos=(5.5, yc - 2.6, H + 1.95), rot=(ang, 0, 0), bevel=0.05)
    cyl(c, "Vent", "Metal", "Steel", 0.8, 2.4, pos=(-6, yc + 2, H + 3.2), verts=10)
    cyl(c, "Vent", "Metal", "Steel", 1.1, 0.5, pos=(-6, yc + 2, H + 4.5), verts=10, radius_top=0.4)
    cyl(c, "Stack", "Metal", "Gunmetal", 0.55, 7, pos=(8, yc + 3.5, H + 4), verts=10)
    for z in (H + 5, H + 6.6):
        cyl(c, "Stack", "Smooth", "SafetyYellow", 0.6, 0.35, pos=(8, yc + 3.5, z), verts=10)
    # Striped awning over the bay on two brackets.
    stripes = 8
    for i in range(stripes):
        sw = "Mustard" if i % 2 == 0 else "Cream"
        box(c, "Awning", "Fabric", sw, ((bay_w + 2) / stripes, 3.2, 0.2),
            pos=(-(bay_w + 2) / 2 + (i + 0.5) * (bay_w + 2) / stripes, y0 - 1.5, bay_h + 1.6), rot=(22, 0, 0), bevel=0.02)
    for sx in (-1, 1):
        box(c, "Bracket", "Metal", "HazardBlack", (0.25, 3.4, 0.25), pos=(sx * (bay_w / 2 + 0.6), y0 - 1.5, bay_h + 1.3), rot=(22, 0, 0), bevel=0.03)
    # Roof sign with a big cog beside it.
    box(c, "Sign", "Smooth", "Signboard", (11, 0.6, 3), pos=(-1.5, y0 - 0.2, H + 2.4), bevel=0.15)
    box(c, "SignFrame", "Metal", "SafetyYellow", (11.8, 0.4, 3.8), pos=(-1.5, y0 + 0.15, H + 2.4), bevel=0.1)
    for sx in (-4.5, 1.5):
        box(c, "SignFrame", "Metal", "HazardBlack", (0.3, 0.3, 2.4), pos=(sx, y0 + 0.4, H + 0.6), bevel=0.03)
    cog(c, 1.9, pos=(6.8, y0 - 0.3, H + 2.6), swatch="Mustard")
    # Engine hoist beside the building with a hanging block.
    hx, hy = W / 2 + 3.2, y0 + 3
    for sy in (-1.8, 1.8):
        box(c, "Hoist", "Metal", "SafetyYellow", (0.5, 0.5, 9.4), pos=(hx, hy + sy * 0.55, 4.5), rot=(sy * 6, 0, 0), bevel=0.06)
    box(c, "Hoist", "Metal", "SafetyYellow", (0.5, 4.6, 0.5), pos=(hx, hy, 9.2), bevel=0.06)
    box(c, "Hoist", "Metal", "SafetyYellow", (3.2, 0.5, 0.5), pos=(hx - 1.2, hy, 9.2), bevel=0.06)
    chain(c, (hx - 2.4, hy, 9.0), (hx - 2.4, hy, 5.2), links=7)
    box(c, "Hung", "Plate", "Gunmetal", (2, 1.8, 1.5), pos=(hx - 2.4, hy, 4.4), rot=(0, 0, 8), bevel=0.2)
    for sy in (-1.8, 1.8):
        box(c, "Hoist", "Metal", "HazardBlack", (3.2, 0.5, 0.4), pos=(hx, hy + sy, 0.3), bevel=0.05)
    # Hanging work lamps under the awning.
    for sx in (-3.5, 3.5):
        lamp(c, (sx, y0 - 1.2, bay_h + 0.2))
    # Oil drums and a parts crate at the corner.
    for i, (dx, dy) in enumerate([(-W / 2 - 1.4, -0.6), (-W / 2 - 1.4, 0.9), (-W / 2 - 2.6, 0.2)]):
        cyl(c, "Drum", "Metal", ["Coral", "ContainerBlue", "SafetyYellow"][i], 0.75, 2.2, pos=(dx, dy, 1.1), verts=12)
    box(c, "Crate", "Planks", "Bark", (2, 2, 1.6), pos=(-W / 2 - 1.8, y0 + 4, 0.8), rot=(0, 0, 14), bevel=0.1)


# --------------------------------------------------------------------------- Weigh station

def weigh_station(c):
    """Scrap Buyer: receiving booth with a cash window (counter front at y=-4.4), a canopy over
    the counter, a tall scale dial, sorting bins and a hanging scale hook."""
    W, D, H = 15.0, 10.0, 9.0
    y0 = -2.0
    yc = y0 + D / 2
    box(c, "Slab", "Concrete", "Concrete", (W + 6, D + 3, 0.6), pos=(1.5, yc, 0.3), bevel=0.15)
    corrugated(c, "Wall", "Metal", "ContainerGreen", D, H, pos=(-W / 2, yc, H / 2), axis="y")
    corrugated(c, "Wall", "Metal", "ContainerGreen", D, H, pos=(W / 2, yc, H / 2), axis="y")
    corrugated(c, "Wall", "Metal", "ContainerGreen", W, H, pos=(0, y0 + D, H / 2))
    win_w = 9.0
    side = (W - win_w) / 2
    for sx in (-1, 1):
        corrugated(c, "Wall", "Metal", "ContainerGreen", side, H, pos=(sx * (win_w / 2 + side / 2), y0, H / 2))
    corrugated(c, "Wall", "Metal", "ContainerGreen", win_w, 3.0, pos=(0, y0, 1.5))
    corrugated(c, "Wall", "Metal", "ContainerGreen", win_w, 1.8, pos=(0, y0, H - 0.9))
    # Cash window bars and the interior.
    for i in range(7):
        box(c, "Bars", "Metal", "Steel", (0.18, 0.18, 4.2), pos=(-4 + i * 1.33, y0 - 0.1, 5.1), bevel=0.02)
    box(c, "Interior", "Smooth", "HazardBlack", (W - 1, 0.3, H - 0.5), pos=(0, y0 + D - 0.5, H / 2), bevel=0.02)
    box(c, "Till", "Metal", "Mustard", (1.6, 1.2, 1.1), pos=(-2.5, y0 + 1.6, 3.95), bevel=0.15)
    box(c, "Ledger", "Smooth", "Cream", (1.4, 1.0, 0.15), pos=(1.5, y0 + 1.4, 3.5), rot=(0, 0, 10), bevel=0.02)
    # Counter: front edge at y=-4.4.
    box(c, "Counter", "Plate", "Steel", (win_w + 0.6, 2.6, 0.4), pos=(0, -3.1, 3.2), bevel=0.08)
    for sx in (-4, 4):
        box(c, "Counter", "Metal", "Gunmetal", (0.35, 1.8, 0.35), pos=(sx, -3.0, 2.6), rot=(40, 0, 0), bevel=0.04)
    # Frame and parapet.
    for sx in (-W / 2, W / 2):
        for sy in (y0, y0 + D):
            box(c, "Frame", "Metal", "Gunmetal", (0.8, 0.8, H + 1.2), pos=(sx, sy, (H + 1.2) / 2), bevel=0.1)
    box(c, "Roof", "Metal", "Gunmetal", (W + 0.6, D + 0.6, 0.5), pos=(0, yc, H + 0.25), bevel=0.1)
    for sy in (y0, y0 + D):
        box(c, "Parapet", "Metal", "SafetyYellow", (W + 0.8, 0.5, 1.1), pos=(0, sy, H + 0.9), bevel=0.08)
    # Canopy over the counter on two posts (corrugated rust).
    for sx in (-5.6, 5.6):
        box(c, "CanopyPost", "Metal", "Gunmetal", (0.5, 0.5, 8.6), pos=(sx, -7.4, 4.3), bevel=0.06)
    # Corrugated rust canopy sloping down toward the customer; ribs run front to back.
    box(c, "Canopy", "Rusty", "Rust", (12.8, 6.4, 0.2), pos=(0, -4.6, 8.4), rot=(-8, 0, 0), bevel=0.03)
    for i in range(12):
        box(c, "Canopy", "Rusty", "Rust", (0.35, 6.4, 0.4), pos=(-6.4 + (i + 0.5) * 12.8 / 12, -4.6, 8.5), rot=(-8, 0, 0), bevel=0.04)
    hazard_band(c, 12.8, 0.5, pos=(0, -7.7, 7.9), stripes=10)
    # Roof sign.
    box(c, "Sign", "Smooth", "Signboard", (10, 0.6, 2.6), pos=(0, y0 - 0.3, H + 2.6), bevel=0.15)
    box(c, "SignFrame", "Metal", "SafetyYellow", (10.8, 0.4, 3.4), pos=(0, y0 + 0.05, H + 2.6), bevel=0.1)
    for sx in (-4, 4):
        box(c, "SignFrame", "Metal", "HazardBlack", (0.3, 0.3, 2), pos=(sx, y0 + 0.3, H + 1.2), bevel=0.03)
    # Scale tower on the counter side: a tall pylon with a big dial facing the customer.
    px, py = W / 2 + 2.2, -4.0
    box(c, "Pylon", "Metal", "Gunmetal", (1.2, 1.2, 9), pos=(px, py, 4.5), bevel=0.12)
    box(c, "Pylon", "Concrete", "Concrete", (2.4, 2.4, 0.8), pos=(px, py, 0.4), bevel=0.12)
    cyl(c, "Dial", "Metal", "SafetyYellow", 2.6, 0.7, pos=(px, py - 0.3, 10.5), rot=(90, 0, 0), verts=20)
    cyl(c, "DialFace", "Smooth", "Cream", 2.2, 0.8, pos=(px, py - 0.4, 10.5), rot=(90, 0, 0), verts=20)
    for i in range(12):
        a = 2 * math.pi * i / 12
        box(c, "Tick", "Smooth", "HazardBlack", (0.12, 0.2, 0.5 if i % 3 else 0.8),
            pos=(px + math.cos(a) * 1.8, py - 0.85, 10.5 + math.sin(a) * 1.8), rot=(0, -math.degrees(a) + 90, 0), bevel=0.0)
    box(c, "Needle", "Neon", "Coral", (0.18, 0.2, 1.9), pos=(px + 0.55, py - 0.95, 11.2), rot=(0, -35, 0), bevel=0.0)
    cyl(c, "Needle", "Metal", "HazardBlack", 0.25, 0.4, pos=(px, py - 0.95, 10.5), rot=(90, 0, 0), verts=8)
    # Hanging scale hook from the canopy.
    chain(c, (-3.5, -6.6, 8.0), (-3.5, -6.6, 5.4), links=6)
    torus(c, "Hook", "Metal", "Steel", 0.45, 0.12, pos=(-3.5, -6.6, 5.0), rot=(90, 0, 0), segments=10)
    # Sorting bins along the side wall.
    for i, sw in enumerate(["Teal", "Mustard", "Coral"]):
        bx = -W / 2 - 1.8
        by = y0 + 1.5 + i * 2.8
        box(c, "Bin", "Metal", sw, (2.6, 2.4, 1.8), pos=(bx, by, 0.9 + 0.6), bevel=0.12)
        box(c, "Bin", "Metal", "Gunmetal", (2.8, 2.6, 0.3), pos=(bx, by, 0.75), bevel=0.05)
        for j in range(3):
            jitter(box(c, "Scrap", "Rusty", "Rust" if j % 2 else "RustDark", (0.8, 0.6, 0.5),
                       pos=(bx + rng.uniform(-0.6, 0.6), by + rng.uniform(-0.6, 0.6), 2.5), bevel=0.05), 25)
    # Gas cylinders chained at the back corner.
    for i in range(3):
        cyl(c, "Gas", "Metal", ["Coral", "Steel", "Teal"][i], 0.45, 3, pos=(W / 2 + 0.9, y0 + D - 1 - i * 1.0, 1.5), verts=10)


# --------------------------------------------------------------------------- Shredder

def shredder(c):
    """The yard's working machine: an inclined conveyor feeding a hopper over a shredder box,
    an output chute with a shred pile, a control cab and exhaust stacks. ~26 x 11 x 22."""
    box(c, "Plinth", "Concrete", "Concrete", (26, 11, 1.2), pos=(0, 0, 0.6), bevel=0.2)
    # Shredder body on four legs.
    for sx in (-3.6, 3.6):
        for sy in (-3, 3):
            box(c, "Leg", "Metal", "SafetyYellow", (1.2, 1.2, 6), pos=(sx, sy, 4.2), bevel=0.12)
    box(c, "Body", "Plate", "Gunmetal", (9, 7.4, 6), pos=(0, 0, 10.2), bevel=0.3)
    box(c, "BodyFrame", "Metal", "SafetyYellow", (9.6, 8, 0.8), pos=(0, 0, 7.4), bevel=0.12)
    box(c, "BodyFrame", "Metal", "SafetyYellow", (9.6, 8, 0.8), pos=(0, 0, 13.0), bevel=0.12)
    hazard_band(c, 9.2, 0.9, pos=(0, -3.85, 8.6), stripes=8)
    for sx in (-3.2, 0, 3.2):
        box(c, "Rib", "Metal", "Steel", (0.5, 7.8, 5.2), pos=(sx, 0, 10.2), bevel=0.06)
    # Hopper: inverted frustum on top, with shredder teeth showing.
    cyl(c, "Hopper", "Metal", "SafetyYellow", 4.2, 4.2, pos=(0, 0, 15.2), rot=(0, 0, 45), verts=4, radius_top=6.6, bevel=0.15)
    for sx, sy, w, d in ((0, -4.7, 9.7, 0.5), (0, 4.7, 9.7, 0.5), (-4.7, 0, 0.5, 9.7), (4.7, 0, 0.5, 9.7)):
        box(c, "HopperRim", "Metal", "HazardBlack", (w, d, 0.5), pos=(sx, sy, 17.4), bevel=0.08)
    for i in range(7):
        for row in (-1, 1):
            box(c, "Teeth", "Metal", "Steel", (0.7, 0.9, 1.1), pos=(-3 + i, row * 0.9, 14.0), rot=(0, 30 * row, 0), bevel=0.05)
    for i in range(6):
        jitter(box(c, "Scrap", "Rusty", "Rust" if i % 2 else "RustDark", (rng.uniform(0.8, 1.8), rng.uniform(0.5, 1.2), 0.6),
                   pos=(rng.uniform(-2.5, 2.5), rng.uniform(-2.5, 2.5), 16.3), bevel=0.05), 35)
    jitter(box(c, "Scrap", "Metal", "Coral", (2.2, 1.2, 1.0), pos=(-1, 1.2, 16.9), bevel=0.2), 20)
    # Conveyor: from the ground at +X up to the hopper lip.
    x0, z0, x1, z1 = 12.5, 1.5, 4.8, 16.5
    length = math.hypot(x1 - x0, z1 - z0)
    ang = math.degrees(math.atan2(z1 - z0, x0 - x1))
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    box(c, "Belt", "Rubber", "Rubber", (length, 3, 0.4), pos=(cx, 0, cz), rot=(0, ang, 0), bevel=0.1)
    for sy in (-1.7, 1.7):
        box(c, "BeltRail", "Metal", "SafetyYellow", (length, 0.4, 0.9), pos=(cx, sy, cz + 0.2), rot=(0, ang, 0), bevel=0.08)
    for i in range(1, 4):
        t = i / 4
        lx, lz = x0 + (x1 - x0) * t, z0 + (z1 - z0) * t
        for sy in (-1.4, 1.4):
            box(c, "BeltLeg", "Metal", "Gunmetal", (0.5, 0.5, lz - 1.2), pos=(lx, sy, (lz + 1.2) / 2), bevel=0.05)
    for i in range(5):
        t = (i + 0.5) / 5
        jitter(box(c, "Scrap", "Metal", ["Steel", "Coral", "Teal", "Mustard", "Steel"][i], (1.0, 1.0, 0.7),
                   pos=(x0 + (x1 - x0) * t, rng.uniform(-0.8, 0.8), z0 + (z1 - z0) * t + 0.6), bevel=0.1), 20)
    # Output chute and shred pile at -X.
    box(c, "Chute", "Metal", "Gunmetal", (6, 3.4, 0.4), pos=(-6.6, 0, 6.2), rot=(0, -32, 0), bevel=0.06)
    for sy in (-1.8, 1.8):
        box(c, "Chute", "Metal", "SafetyYellow", (6, 0.3, 1), pos=(-6.6, sy, 6.6), rot=(0, -32, 0), bevel=0.04)
    for i in range(22):
        jitter(box(c, "Shred", "Rusty", rng.choice(["Rust", "RustDark", "Gunmetal"]),
                   (rng.uniform(0.6, 1.4), rng.uniform(0.4, 1.0), rng.uniform(0.3, 0.7)),
                   pos=(-10.5 + rng.uniform(-2.2, 2.2), rng.uniform(-2.5, 2.5), 1.4 + rng.uniform(0, 1.8)), bevel=0.04), 40)
    # Control cab on a platform with stairs and a railing.
    box(c, "Platform", "Plate", "Steel", (5, 5, 0.4), pos=(7.8, 3.2, 8), bevel=0.06)
    for sx in (5.6, 10):
        for sy in (1, 5.4):
            box(c, "PlatformLeg", "Metal", "Gunmetal", (0.4, 0.4, 7.4), pos=(sx, sy, 4.4), bevel=0.04)
    box(c, "Cab", "Metal", "SafetyYellow", (3.4, 3.4, 3.4), pos=(8.2, 3.6, 9.9), bevel=0.3)
    box(c, "CabGlass", "Glass", "Glass", (3.5, 2.6, 1.6), pos=(8.2, 3.2, 10.4), bevel=0.1)
    box(c, "CabRoof", "Metal", "HazardBlack", (4, 4, 0.4), pos=(8.2, 3.6, 11.8), bevel=0.08)
    sphere(c, "Beacon", "Neon", "Coral", 0.45, pos=(8.2, 3.6, 12.4))
    for i in range(9):  # stairs climb along -X to the platform edge
        box(c, "Stair", "Plate", "Steel", (0.9, 2.0, 0.3), pos=(15.6 - i * 0.6, 4.6, 1.0 + i * 0.85), bevel=0.04)
    for sy in (3.5, 5.7):
        box(c, "StairRail", "Metal", "SafetyYellow", (6.4, 0.15, 0.15), pos=(13.2, sy, 6.2), rot=(0, 55, 0), bevel=0.02)
    box(c, "Rail", "Metal", "SafetyYellow", (5, 0.15, 0.15), pos=(7.8, 5.6, 9.2), bevel=0.02)
    # Exhaust stacks with hazard bands.
    for i, sx in enumerate((-2.8, -0.6)):
        h = 9 + i * 2
        cyl(c, "Stack", "Metal", "Gunmetal", 0.6, h, pos=(sx, 3.2, 13 + h / 2), verts=10)
        cyl(c, "StackBand", "Smooth", "SafetyYellow", 0.66, 0.4, pos=(sx, 3.2, 13 + h - 0.6), verts=10)
        cyl(c, "StackBand", "Smooth", "HazardBlack", 0.66, 0.4, pos=(sx, 3.2, 13 + h - 1.2), verts=10)
    # Big sign on the shredder body.
    box(c, "Sign", "Smooth", "Signboard", (7.2, 0.4, 2.4), pos=(0, -3.9, 10.6), bevel=0.1)


# --------------------------------------------------------------------------- Clock tower

def clock_tower(c):
    """Town Square landmark. Stone base with an arched door, brick shaft with pilasters, a
    clock stage with four framed faces, an open belfry, a steep slate spire and weathervane,
    and a few storm repairs. Footprint 13 x 13, ~52 tall."""
    # Plinth and steps.
    box(c, "Plinth", "Concrete", "Stone", (14, 14, 1.2), pos=(0, 0, 0.6), bevel=0.2)
    for i in range(3):
        box(c, "Step", "Concrete", "Stone", (6 - i * 0.8, 1.2, 0.4), pos=(0, -7.6 + i * 0.6, 0.2 + i * 0.4), bevel=0.06)
    # Base stage: stone with quoins.
    box(c, "Base", "Concrete", "Stone", (11, 11, 9), pos=(0, 0, 5.7), bevel=0.15)
    for sx in (-5.5, 5.5):
        for sy in (-5.5, 5.5):
            for k in range(4):
                box(c, "Quoin", "Concrete", "Concrete", (1.4 if k % 2 else 1.0, 1.4 if k % 2 == 0 else 1.0, 1.9),
                    pos=(sx, sy, 2.4 + k * 2.2), bevel=0.1)
    # Arched door on the front (-Y): recess, arch ring, keystone.
    box(c, "Door", "Planks", "Bark", (3.2, 0.6, 5), pos=(0, -5.4, 3.9), bevel=0.06)
    torus(c, "Arch", "Concrete", "Cream", 1.75, 0.35, pos=(0, -5.6, 6.4), rot=(90, 0, 0), segments=16)
    for sx in (-1.75, 1.75):
        box(c, "Jamb", "Concrete", "Cream", (0.7, 0.7, 5), pos=(sx, -5.6, 3.9), bevel=0.06)
    box(c, "Keystone", "Concrete", "Cream", (0.8, 0.8, 1.0), pos=(0, -5.7, 8.3), bevel=0.06)
    box(c, "Cornice", "Concrete", "Cream", (12, 12, 0.8), pos=(0, 0, 10.4), bevel=0.15)
    # Brick shaft with pilasters and string courses.
    sh = 17.0
    box(c, "Shaft", "Brick", "Terracotta", (9, 9, sh), pos=(0, 0, 10.8 + sh / 2), bevel=0.1)
    for sx in (-4.5, 4.5):
        for sy in (-4.5, 4.5):
            box(c, "Pilaster", "Brick", "RoofRed", (1.4, 1.4, sh), pos=(sx, sy, 10.8 + sh / 2), bevel=0.1)
    for z in (17, 23.5):
        box(c, "Course", "Concrete", "Cream", (9.8, 9.8, 0.5), pos=(0, 0, z), bevel=0.08)
    # Tall narrow windows on each face; one boarded up after a storm.
    faces = [((0, -4.6), 0), ((4.6, 0), 90), ((0, 4.6), 180), ((-4.6, 0), 270)]
    for i, ((fx, fy), yaw) in enumerate(faces):
        if i == 1:
            for k in range(3):
                box(c, "Boards", "Planks", "Bark", (1.9, 0.3, 0.6), pos=(fx, fy, 19 + k * 0.9), rot=(0, 8 * (k - 1), yaw), bevel=0.04)
        else:
            box(c, "Window", "Glass", "WindowWarm", (1.4, 0.4, 3.4), pos=(fx, fy, 20), rot=(0, 0, yaw), bevel=0.05)
        box(c, "Sill", "Concrete", "Cream", (2.2, 0.6, 0.35), pos=(fx * 1.04, fy * 1.04, 18.2), rot=(0, 0, yaw), bevel=0.05)
    # Clock stage: cream, slightly wider, four framed faces.
    box(c, "ClockStage", "Smooth", "Cream", (10.6, 10.6, 8), pos=(0, 0, 32), bevel=0.2)
    box(c, "Cornice", "Concrete", "Stone", (11.6, 11.6, 0.7), pos=(0, 0, 28.2), bevel=0.12)
    box(c, "Cornice", "Concrete", "Stone", (11.8, 11.8, 0.9), pos=(0, 0, 36.3), bevel=0.15)
    for (fx, fy), yaw in faces:
        nx, ny = fx / 4.6, fy / 4.6
        cx, cy = nx * 5.35, ny * 5.35
        rot_face = (90, 0, yaw)
        torus(c, "ClockFrame", "Metal", "Mustard", 3.1, 0.35, pos=(cx, cy, 32), rot=rot_face, segments=24)
        cyl(c, "ClockFace", "Smooth", "White", 2.95, 0.3, pos=(cx, cy, 32), rot=rot_face, verts=24)
        for k in range(12):
            a = 2 * math.pi * k / 12
            lx = math.cos(a) * 2.45
            tx, ty = cx + nx * 0.2 + (-ny) * lx, cy + ny * 0.2 + nx * lx
            box(c, "ClockTick", "Smooth", "HazardBlack", (0.18, 0.12, 0.55 if k % 3 else 0.85),
                pos=(tx, ty, 32 + math.sin(a) * 2.45), rot=(0, -math.degrees(a) + 90, yaw), bevel=0.0)
        # Hands at ten past two, as on the old tower.
        hx, hy = cx + nx * 0.3, cy + ny * 0.3
        box(c, "ClockHand", "Smooth", "HazardBlack", (0.28, 0.14, 1.8), pos=(hx + (-ny) * 0.55, hy + nx * 0.55, 32.6), rot=(0, 55, yaw), bevel=0.0)
        box(c, "ClockHand", "Smooth", "HazardBlack", (0.2, 0.14, 2.4), pos=(hx + (-ny) * 0.2, hy + nx * 0.2, 33.1), rot=(0, 10, yaw), bevel=0.0)
    # Belfry: four corner piers, open arches, a bell.
    for sx in (-4.4, 4.4):
        for sy in (-4.4, 4.4):
            box(c, "Pier", "Smooth", "Cream", (1.6, 1.6, 6), pos=(sx, sy, 39.8), bevel=0.15)
    for (fx, fy), yaw in faces:
        nx, ny = fx / 4.6, fy / 4.6
        torus(c, "BelfryArch", "Smooth", "Cream", 2.6, 0.45, pos=(nx * 4.4, ny * 4.4, 41.2), rot=(90, 0, yaw), segments=14)
        box(c, "Rail", "Metal", "HazardBlack", (7.2, 0.2, 0.2), pos=(nx * 4.5, ny * 4.5, 37.9), rot=(0, 0, yaw), bevel=0.02)
    cyl(c, "Bell", "Metal", "Mustard", 1.6, 2.6, pos=(0, 0, 39.6), verts=14, radius_top=0.8)
    box(c, "Bell", "Metal", "Gunmetal", (3.6, 0.4, 0.4), pos=(0, 0, 41.4), bevel=0.05)
    box(c, "BelfryTop", "Concrete", "Stone", (11, 11, 0.9), pos=(0, 0, 43.2), bevel=0.15)
    # Spire: steep slate pyramid, flared eaves, with a tarp patch and a lantern finial.
    cyl(c, "Spire", "Slate", "RoofSlate", 7.6, 8.5, pos=(0, 0, 47.9), rot=(0, 0, 45), verts=4, radius_top=0.6, bevel=0.1)
    box(c, "Tarp", "Fabric", "Coral", (2.8, 0.25, 2.4), pos=(1.2, -2.6, 46.3), rot=(-36, 0, 6), bevel=0.04)
    for k in range(3):
        box(c, "TarpRope", "Fabric", "Cream", (0.08, 0.08, 2.6), pos=(0.2 + k * 1.0, -2.5, 46.3), rot=(-36, 0, 6), bevel=0.0)
    cyl(c, "Finial", "Metal", "Mustard", 0.5, 1.6, pos=(0, 0, 52.8), verts=8)
    sphere(c, "Finial", "Metal", "Mustard", 0.6, pos=(0, 0, 53.9))
    box(c, "Vane", "Metal", "Gunmetal", (0.12, 0.12, 2.4), pos=(0, 0, 55.3), bevel=0.0)
    box(c, "Vane", "Metal", "Gunmetal", (3.2, 0.12, 0.25), pos=(0, 0, 56.2), rot=(0, 0, 25), bevel=0.0)
    wedge(c, "Vane", "Metal", "Gunmetal", (0.12, 0.9, 0.9), pos=(1.5, 0.7, 56.2), rot=(0, 0, 115), bevel=0.0)
    # Lightning rod (slightly bent, it's been hit) and its cable down the back.
    box(c, "Rod", "Metal", "Steel", (0.15, 0.15, 4), pos=(3.6, 3.6, 46), rot=(8, -6, 0), bevel=0.0)
    box(c, "RodCable", "Metal", "Gunmetal", (0.12, 0.12, 44), pos=(5.4, 5.4, 22.5), bevel=0.0)
    # Notice board and planters at the base.
    box(c, "Notice", "Planks", "Bark", (3, 0.3, 2), pos=(3.6, -5.8, 3.2), bevel=0.05)
    box(c, "Notice", "Smooth", "Cream", (2.4, 0.15, 1.4), pos=(3.6, -6.0, 3.2), bevel=0.02)
    for sx in (-4.8, 4.8):
        box(c, "Planter", "Concrete", "Stone", (2.2, 2.2, 1.4), pos=(sx, -6.6, 1.9), bevel=0.15)
        sphere(c, "Shrub", "Grass", "Leaf", 1.3, pos=(sx, -6.6, 3.0), scale=(1, 1, 0.8))


# --------------------------------------------------------------------------- Arrival gantry

def arrival_gantry(c):
    """Truss gantry over the yard road: two lattice towers, a truss beam, the company sign and a
    row of bulbs. Clear span 26 studs, clearance 13. Front (-Y) faces the spawn."""
    for sx in (-14, 14):
        lattice_mast(c, sx, 0, 1.0, 17, 2.2, seg=3.4)
        box(c, "Foot", "Concrete", "Concrete", (3.4, 3.4, 1.0), pos=(sx, 0, 0.5), bevel=0.15)
        hazard_band(c, 3.0, 0.7, pos=(sx, -1.75, 1.6), stripes=4)
    # Truss beam: two chords and diagonal webs.
    for z in (16.4, 19.0):
        for sy in (-0.9, 0.9):
            box(c, "Chord", "Metal", "SafetyYellow", (31, 0.4, 0.4), pos=(0, sy, z), bevel=0.06)
    for i in range(14):
        x = -13 + i * 2
        for sy in (-0.9, 0.9):
            box(c, "Web", "Metal", "SafetyYellow", (0.25, 0.25, 3.1), pos=(x + 1, sy, 17.7), rot=(0, 38 if i % 2 else -38, 0), bevel=0.03)
    box(c, "Sign", "Smooth", "Signboard", (22, 0.6, 3.6), pos=(0, -1.2, 14.0), bevel=0.15)
    box(c, "SignFrame", "Metal", "Gunmetal", (22.8, 0.4, 4.4), pos=(0, -0.8, 14.0), bevel=0.1)
    for sx in (-8, 8):
        box(c, "Hanger", "Metal", "Gunmetal", (0.25, 0.25, 1.4), pos=(sx, -1.0, 16.3), bevel=0.02)
    for i in range(9):
        sphere(c, "Bulb", "Neon", "WindowWarm", 0.32, pos=(-10 + i * 2.5, -1.5, 11.8))
        cyl(c, "BulbCap", "Metal", "HazardBlack", 0.2, 0.3, pos=(-10 + i * 2.5, -1.5, 12.15), verts=8)
    # Warning beacons on top of each tower.
    for sx in (-14, 14):
        cyl(c, "BeaconBase", "Metal", "HazardBlack", 0.6, 0.6, pos=(sx, 0, 18.4), verts=10)
        sphere(c, "Beacon", "Neon", "Coral", 0.55, pos=(sx, 0, 19.1))


# --------------------------------------------------------------------------- Storefronts

def storefront(c, wall, trim, awning, door):
    """Two-storey corner shop for the square: shop window and door, striped awning, upper windows
    with shutters, stepped false-front parapet. 16 x 9 x ~18."""
    W, D = 16.0, 9.0
    box(c, "Base", "Concrete", "Stone", (W + 0.6, D + 0.6, 0.8), pos=(0, D / 2 - 0.3, 0.4), bevel=0.1)
    box(c, "Walls", "Brick", wall, (W, D, 13), pos=(0, D / 2, 7.3), bevel=0.12)
    # False front (taller, stepped) on the street face.
    box(c, "FalseFront", "Brick", wall, (W, 0.8, 16.5), pos=(0, -0.4, 9.05), bevel=0.1)
    box(c, "FalseFrontTop", "Smooth", trim, (W * 0.5, 0.9, 1.6), pos=(0, -0.4, 17.9), bevel=0.12)
    box(c, "Cornice", "Smooth", trim, (W + 0.8, 1.4, 0.7), pos=(0, -0.5, 13.6), bevel=0.12)
    box(c, "Cornice", "Smooth", trim, (W + 0.4, 1.2, 0.5), pos=(0, -0.5, 17.1), bevel=0.1)
    # Ground floor: big shop window, door, pilasters, sign band.
    box(c, "ShopWindow", "Glass", "WindowWarm", (8.4, 0.3, 4.2), pos=(-2.4, -0.9, 3.5), bevel=0.05)
    box(c, "Mullion", "Smooth", trim, (0.3, 0.4, 4.2), pos=(-2.4, -1.0, 3.5), bevel=0.03)
    box(c, "Sill", "Smooth", trim, (9, 0.8, 0.4), pos=(-2.4, -1.0, 1.25), bevel=0.05)
    box(c, "Door", "Planks", door, (2.6, 0.4, 5.4), pos=(4.8, -0.9, 3.5), bevel=0.06)
    box(c, "DoorGlass", "Glass", "Glass", (1.4, 0.45, 1.8), pos=(4.8, -0.95, 4.6), bevel=0.03)
    for sx in (-7.6, 7.6):
        box(c, "Pilaster", "Smooth", trim, (0.9, 1.2, 12.8), pos=(sx, -0.6, 7.2), bevel=0.08)
    box(c, "Sign", "Smooth", "Signboard", (12, 0.5, 1.5), pos=(0, -1.0, 7.75), bevel=0.1)
    # Striped awning over the ground floor.
    stripes = 10
    for i in range(stripes):
        sw = awning if i % 2 == 0 else "Cream"
        box(c, "Awning", "Fabric", sw, (W / stripes, 3.6, 0.25),
            pos=(-W / 2 + (i + 0.5) * W / stripes, -2.6, 6.3), rot=(18, 0, 0), bevel=0.02)
    box(c, "AwningValance", "Fabric", awning, (W, 0.15, 0.6), pos=(0, -4.35, 5.5), bevel=0.02)
    # Upper floor: two windows with shutters; one shutter hangs loose (storm).
    for i, sx in enumerate((-4, 4)):
        box(c, "UpperWindow", "Glass", "Glass", (2.6, 0.3, 3.0), pos=(sx, -0.9, 11.0), bevel=0.04)
        box(c, "WindowFrame", "Smooth", trim, (3.2, 0.4, 3.6), pos=(sx, -0.8, 11.0), bevel=0.05)
        for side in (-1, 1):
            loose = (i == 1 and side == 1)
            box(c, "Shutter", "Planks", door, (1.3, 0.3, 3.4),
                pos=(sx + side * 2.3 + (0.3 if loose else 0), -1.1 - (0.3 if loose else 0), 11.0 - (0.4 if loose else 0)),
                rot=(0, 18 if loose else 0, 0), bevel=0.04)
        box(c, "Planter", "Planks", "Bark", (2.8, 0.8, 0.6), pos=(sx, -1.4, 9.0), bevel=0.05)
        sphere(c, "Flowers", "Grass", "Leaf", 0.5, pos=(sx - 0.7, -1.4, 9.5), scale=(1.4, 1, 0.7))
    # Roof: flat with an AC unit and a satellite dish (bent).
    box(c, "Roof", "Concrete", "Concrete", (W, D, 0.5), pos=(0, D / 2, 13.9), bevel=0.05)
    box(c, "AC", "Metal", "Steel", (2.4, 2, 1.4), pos=(4, D - 2.5, 14.8), bevel=0.15)
    cyl(c, "Dish", "Metal", "White", 1.2, 0.3, pos=(-4, D - 2.5, 15.6), rot=(50, 0, 20), verts=12, radius_top=0.4)
    # Drainpipe.
    box(c, "Drain", "Metal", "Gunmetal", (0.35, 0.35, 13.4), pos=(W / 2 - 0.3, -0.2, 6.9), bevel=0.04)


def storefront_a(c):
    storefront(c, "Mustard", "Cream", "Coral", "Teal")


def storefront_b(c):
    storefront(c, "Teal", "Cream", "Mustard", "Coral")


if __name__ == "__main__":
    build_set("v3hero", [
        ("GearWorkshop", gear_workshop),
        ("WeighStation", weigh_station),
        ("Shredder", shredder),
        ("ClockTowerV3", clock_tower),
        ("ArrivalGantry", arrival_gantry),
        ("StorefrontA", storefront_a),
        ("StorefrontB", storefront_b),
    ], layout_spacing=6)
