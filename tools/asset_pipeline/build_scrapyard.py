"""Scrapyard hub kit. Front of each asset faces Blender -Y (the side players approach).

blender -b --python tools/asset_pipeline/build_scrapyard.py
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from kit import box, build_set, cyl, jitter, rng, sphere, torus, wedge  # noqa: E402,F401


# --------------------------------------------------------------------------- helpers

def lattice_mast(c, x, y, z0, height, width, swatch="SafetyYellow", seg=4.0):
    """Square lattice tower: four corner posts with zigzag bracing on every face."""
    h = width / 2
    for sx in (-h, h):
        for sy in (-h, h):
            box(c, "Post", "Metal", swatch, (0.45, 0.45, height), pos=(x + sx, y + sy, z0 + height / 2), bevel=0.06)
    n = int(height // seg)
    diag = math.hypot(width, seg)
    ang = math.degrees(math.atan2(seg, width))
    for i in range(n):
        zc = z0 + seg * i + seg / 2
        flip = 1 if i % 2 == 0 else -1
        # faces at y = ±h (brace runs along X) and x = ±h (brace runs along Y)
        for sy in (-h, h):
            box(c, "Brace", "Metal", swatch, (diag, 0.25, 0.25), pos=(x, y + sy, zc), rot=(0, flip * ang, 0), bevel=0.04)
        for sx in (-h, h):
            box(c, "Brace", "Metal", swatch, (0.25, diag, 0.25), pos=(x + sx, y, zc), rot=(-flip * ang, 0, 0), bevel=0.04)
        box(c, "Ring", "Metal", swatch, (width + 0.4, 0.3, 0.3), pos=(x, y - h, z0 + seg * (i + 1)), bevel=0.04)
        box(c, "Ring", "Metal", swatch, (width + 0.4, 0.3, 0.3), pos=(x, y + h, z0 + seg * (i + 1)), bevel=0.04)


def car_body(c, color, crushed=0.0, pos=(0, 0, 0), yaw=0):
    """Boxy sedan. crushed in [0,1] flattens the cabin for the crushed-car stack."""
    x, y, z = pos
    cos, sin = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))

    def p(dx, dy, dz):
        return (x + dx * cos - dy * sin, y + dx * sin + dy * cos, z + dz)

    body_h = 1.6 - crushed * 0.6
    box(c, "Body", "Rusty" if crushed else "Metal", color, (5.2, 10.5, body_h), pos=p(0, 0, 0.9 + body_h / 2), rot=(0, 0, yaw), bevel=0.35)
    cab_h = 1.6 * (1 - crushed * 0.8)
    if cab_h > 0.3:
        box(c, "Cabin", "Rusty" if crushed else "Metal", color, (4.6, 5.2, cab_h), pos=p(0, 0.6, 0.9 + body_h + cab_h / 2), rot=(0, 0, yaw), bevel=0.3)
        box(c, "Windows", "Glass", "Glass", (4.7, 4.6, cab_h * 0.6), pos=p(0, 0.6, 0.9 + body_h + cab_h * 0.5), rot=(0, 0, yaw), bevel=0.15)
    for dx in (-2.5, 2.5):
        for dy in (-3.4, 3.4):
            cyl(c, "Wheel", "Rubber", "Rubber", 0.95, 0.8, pos=p(dx, dy, 0.95), rot=(0, 90, yaw), verts=12, bevel=0.15)
    if not crushed:
        for dx in (-1.7, 1.7):
            box(c, "Headlight", "Neon", "WindowWarm", (0.9, 0.2, 0.5), pos=p(dx, -5.25, 1.7), rot=(0, 0, yaw), bevel=0.08)
        box(c, "Bumper", "Metal", "Steel", (5.4, 0.4, 0.5), pos=p(0, -5.35, 1.1), rot=(0, 0, yaw), bevel=0.15)


# --------------------------------------------------------------------------- assets

def crane(c):
    lattice_mast(c, 0, 0, 0, 56, 4)
    box(c, "Base", "Concrete", "Concrete", (8, 8, 1.5), pos=(0, 0, 0.75), bevel=0.2)
    box(c, "Slew", "Plate", "Gunmetal", (6, 6, 1.2), pos=(0, 0, 56.6), bevel=0.15)
    box(c, "Cab", "Metal", "SafetyYellow", (4.5, 4.5, 4), pos=(2.6, -2.6, 59.2), bevel=0.3)
    box(c, "CabGlass", "Glass", "Glass", (4.6, 3.0, 2.0), pos=(2.6, -3.0, 59.8), bevel=0.15)
    # Jib reaching out along -X, counter-jib along +X
    for length, direction in ((40, -1), (14, 1)):
        cx = direction * (length / 2 + 1)
        for sy in (-1, 1):
            box(c, "Chord", "Metal", "SafetyYellow", (length, 0.4, 0.4), pos=(cx, sy * 1.2, 58.0), bevel=0.06)
        box(c, "Chord", "Metal", "SafetyYellow", (length, 0.4, 0.4), pos=(cx, 0, 60.2), bevel=0.06)
        for i in range(int(length // 3)):
            bx = direction * (2 + i * 3)
            for sy in (-1, 1):
                box(c, "Web", "Metal", "SafetyYellow", (0.22, 0.22, 2.7), pos=(bx, sy * 0.6, 59.1), rot=(sy * 28, 35 if i % 2 else -35, 0), bevel=0.03)
    box(c, "Counterweight", "Concrete", "Concrete", (4, 3.2, 3), pos=(13, 0, 56.8), bevel=0.25)
    for sx in (-1, 1):
        box(c, "Stripe", "Smooth", "HazardBlack", (0.6, 3.3, 3.1), pos=(13 + sx * 1.1, 0, 56.8), bevel=0.05)
    # Peak and pendant lines
    box(c, "Peak", "Metal", "SafetyYellow", (1.2, 1.2, 7), pos=(0, 0, 64), bevel=0.1)
    cyl(c, "Pendant", "Metal", "HazardBlack", 0.08, 41, pos=(-19.5, 0, 63.5), rot=(0, -80, 0), verts=6, bevel=0)
    cyl(c, "Pendant", "Metal", "HazardBlack", 0.08, 14.5, pos=(6.5, 0, 63.5), rot=(0, 70, 0), verts=6, bevel=0)
    # Trolley, cable and magnet hanging near the tip
    box(c, "Trolley", "Metal", "Gunmetal", (2, 2.8, 0.8), pos=(-30, 0, 57.4), bevel=0.15)
    cyl(c, "Cable", "Metal", "HazardBlack", 0.1, 24, pos=(-30, 0, 45), verts=6, bevel=0)
    cyl(c, "Magnet", "Plate", "Gunmetal", 3.2, 1.4, pos=(-30, 0, 32.4), verts=16, bevel=0.2)
    cyl(c, "MagnetRim", "Metal", "SafetyYellow", 3.3, 0.4, pos=(-30, 0, 33.0), verts=16, bevel=0.08)
    # A car hanging from the magnet sells the "working yard" story
    car_body(c, "Coral", crushed=0.3, pos=(-30, 0, 27.2), yaw=15)
    box(c, "Warning", "Neon", "Coral", (0.6, 0.6, 0.6), pos=(0, 0, 67.7), bevel=0.1)


def crusher(c):
    box(c, "Base", "Concrete", "Concrete", (14, 9, 1.2), pos=(0, 0, 0.6), bevel=0.2)
    for sx in (-1, 1):
        box(c, "Wall", "Plate", "Gunmetal", (1.2, 8, 6), pos=(sx * 5.6, 0, 4.2), bevel=0.2)
        box(c, "Ram", "Metal", "SafetyYellow", (2.4, 6.5, 5), pos=(sx * 4.2, 0, 4.0), bevel=0.25)
        cyl(c, "Piston", "Metal", "Steel", 0.6, 3.5, pos=(sx * 7.5, 0, 4.0), rot=(0, 90, 0), verts=10)
        cyl(c, "Cylinder", "Metal", "SafetyYellow", 1.1, 2.5, pos=(sx * 9.3, 0, 4.0), rot=(0, 90, 0), verts=12)
    box(c, "Pit", "Smooth", "HazardBlack", (6, 6.5, 0.3), pos=(0, 0, 1.3), bevel=0.05)
    car_body(c, "Cobalt", crushed=0.8, pos=(0, 0, 1.0), yaw=90)
    for i in range(7):
        box(c, "HazardStripe", "Smooth", "HazardBlack" if i % 2 else "SafetyYellow", (2, 0.3, 0.8),
            pos=(-6 + i * 2, -4.6, 1.5), bevel=0.05)
    box(c, "ControlBox", "Metal", "Gunmetal", (1.6, 1.2, 2.4), pos=(6.5, -5.4, 2.4), bevel=0.15)
    cyl(c, "Button", "Neon", "Coral", 0.3, 0.2, pos=(6.5, -6.05, 2.9), rot=(90, 0, 0), verts=10)
    box(c, "Chute", "Rusty", "Rust", (4, 3, 0.4), pos=(0, 6, 2.0), rot=(25, 0, 0), bevel=0.1)


def car_stack(c):
    colors = ["Coral", "Cobalt", "Mustard", "Teal"]
    for level in range(4):
        jitter_yaw = (level * 13) % 20 - 10
        car_body(c, colors[level], crushed=0.7, pos=(rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), level * 2.1),
                 yaw=jitter_yaw)


def wreck(c):
    car_body(c, "Teal", crushed=0.0, pos=(0, 0, 0), yaw=0)
    box(c, "Hood", "Rusty", "Rust", (4.8, 3, 0.25), pos=(0, -5.5, 2.6), rot=(-35, 0, 0), bevel=0.08)


def container(c):
    box(c, "Box", "Rusty", "ContainerBlue", (8, 20, 8.5), pos=(0, 0, 4.25), bevel=0.25)
    for i in range(9):
        box(c, "Rib", "Metal", "ContainerBlue", (8.2, 0.35, 8.0), pos=(0, -8.8 + i * 2.2, 4.25), bevel=0.06)
    for sx in (-1, 1):
        box(c, "Door", "Metal", "ContainerBlue", (3.8, 0.3, 8.0), pos=(sx * 1.95, -10.05, 4.25), bevel=0.08)
        for z in (2, 6.5):
            box(c, "Bar", "Metal", "Steel", (0.15, 0.2, 7.5), pos=(sx * 1.2, -10.25, 4.25), bevel=0.03)
    for sx in (-3.9, 3.9):
        for sy in (-9.9, 9.9):
            for sz in (0.3, 8.2):
                box(c, "Corner", "Metal", "Gunmetal", (0.7, 0.7, 0.6), pos=(sx, sy, sz), bevel=0.08)


def scrap_pile(c):
    swatches = ["Rust", "RustDark", "Gunmetal", "Steel", "ContainerBlue", "Mustard"]
    box(c, "Mound", "Rusty", "RustDark", (12, 9, 3), pos=(0, 0, 1.0), rot=(0, 0, 10), bevel=0.8)
    for i in range(16):
        s = rng.uniform(1.5, 4.0)
        r = rng.uniform(0, 4.5)
        a = rng.uniform(0, math.tau)
        zbase = 2.6 - r * 0.35
        o = box(c, "Scrap", "Rusty" if i % 3 else "Plate", swatches[i % len(swatches)],
                (s, s * rng.uniform(0.4, 1.0), s * rng.uniform(0.25, 0.7)),
                pos=(math.cos(a) * r, math.sin(a) * r * 0.75, zbase + s * 0.2), bevel=0.15)
        jitter(o, 25)
    for i in range(3):
        a = rng.uniform(0, math.tau)
        cyl(c, "Tire", "Rubber", "Rubber", 1.0, 0.7, pos=(math.cos(a) * 4, math.sin(a) * 3, 2.2), rot=(rng.uniform(40, 90), 0, math.degrees(a)), verts=12, bevel=0.15)
    cyl(c, "Pipe", "Metal", "Rust", 0.3, 7, pos=(0.5, 0.5, 4.2), rot=(70, 20, 30), verts=8)
    box(c, "Door", "Metal", "Coral", (2.4, 0.2, 4), pos=(-2, 1, 4.0), rot=(20, -30, 15), bevel=0.15)


def workbench(c):
    box(c, "Top", "Planks", "Bark", (8, 3, 0.5), pos=(0, 0, 3.3), bevel=0.1)
    for sx in (-3.6, 3.6):
        for sy in (-1.2, 1.2):
            box(c, "Leg", "Metal", "Gunmetal", (0.4, 0.4, 3.1), pos=(sx, sy, 1.55), bevel=0.06)
    box(c, "Shelf", "Planks", "Bark", (7.6, 2.6, 0.3), pos=(0, 0, 1.0), bevel=0.06)
    box(c, "Board", "Planks", "Plaster", (8, 0.3, 4), pos=(0, 1.5, 5.6), bevel=0.08)
    for i, sw in enumerate(["Coral", "Cobalt", "SafetyYellow", "Steel"]):
        box(c, "Tool", "Metal", sw, (0.3, 0.2, 1.6 + i * 0.3), pos=(-2.5 + i * 1.6, 1.3, 5.6), rot=(0, 10 * (i - 1.5), 0), bevel=0.05)
    box(c, "Vise", "Metal", "Cobalt", (1, 1.2, 0.9), pos=(3, -0.6, 4.0), bevel=0.12)
    box(c, "Toolbox", "Metal", "Coral", (2, 1, 1.1), pos=(-2.4, 0, 4.1), bevel=0.15)
    cyl(c, "Lamp", "Neon", "WindowWarm", 0.4, 0.3, pos=(0, 1.0, 7.9), verts=10)


def shack(c, sign_swatch, wall_swatch):
    """Corrugated shop shack. Open front (-Y) with a counter; awning overhangs the front."""
    w, d, h = 18, 10, 9
    box(c, "Floor", "Concrete", "Concrete", (w + 1, d + 3, 0.4), pos=(0, -1, 0.2), bevel=0.1)
    box(c, "Back", "Rusty", wall_swatch, (w, 0.6, h), pos=(0, d / 2, h / 2), bevel=0.12)
    for sx in (-1, 1):
        box(c, "Side", "Rusty", wall_swatch, (0.6, d, h), pos=(sx * w / 2, 0, h / 2), bevel=0.12)
    for i in range(10):
        box(c, "Rib", "Metal", wall_swatch, (0.3, 0.8, h - 0.4), pos=(-w / 2 + 1 + i * 1.8, d / 2 - 0.3, h / 2), bevel=0.05)
    # Sloped roof running down to an awning over the counter
    box(c, "Roof", "Rusty", "Gunmetal", (w + 2, d + 6, 0.5), pos=(0, -2, h + 0.6), rot=(-6, 0, 0), bevel=0.15)
    for sx in (-w / 2 + 0.6, w / 2 - 0.6):
        box(c, "Post", "Metal", "Gunmetal", (0.5, 0.5, h), pos=(sx, -d / 2 - 2.6, h / 2), bevel=0.08)
    box(c, "Counter", "Plate", sign_swatch, (w - 4, 2.4, 3.4), pos=(0, -d / 2 + 0.6, 1.7), bevel=0.2)
    box(c, "CounterTop", "Planks", "Bark", (w - 3.6, 2.8, 0.35), pos=(0, -d / 2 + 0.6, 3.55), bevel=0.08)
    box(c, "SignBoard", "Smooth", "HazardBlack", (14, 0.5, 3), pos=(0, -d / 2 - 3.4, h + 2.3), bevel=0.15)
    box(c, "SignTrim", "Neon", sign_swatch, (14.4, 0.3, 0.3), pos=(0, -d / 2 - 3.6, h + 0.75), bevel=0.0)
    for sx in (-5, 5):
        cyl(c, "Lamp", "Neon", "WindowWarm", 0.5, 0.4, pos=(sx, -d / 2 - 1, h - 0.3), verts=10)
    # Clutter behind the counter
    for i in range(3):
        box(c, "Crate", "Planks", "Bark", (1.8, 1.8, 1.8), pos=(-6 + i * 2.2, d / 2 - 1.6, 0.9 + (i % 2) * 1.8), bevel=0.12)
    cyl(c, "Drum", "Metal", "ContainerBlue", 1.1, 3, pos=(6.5, d / 2 - 1.8, 1.5), verts=12)


def sell_shack(c):
    shack(c, "NeonGreen", "ContainerGreen")
    cyl(c, "Scale", "Plate", "Steel", 1.4, 0.3, pos=(4, -d_front(), 3.9), verts=12)
    box(c, "CashBox", "Metal", "Mustard", (1.6, 1.2, 1), pos=(-4, -d_front(), 4.2), bevel=0.12)


def gear_shack(c):
    shack(c, "StormCyan", "ContainerBlue")
    for i in range(3):
        box(c, "Boots", "Rubber", "Coral", (0.8, 1.4, 1.0), pos=(-4 + i * 1.2, -d_front(), 4.2), bevel=0.15)
    box(c, "Pack", "Fabric", "Mustard", (1.6, 1.0, 2.0), pos=(3.5, -d_front(), 4.7), bevel=0.3)


def d_front():
    return 10 / 2 - 0.6


def fence_panel(c):
    """10-stud corrugated fence panel with posts; tile along the yard edge."""
    for i in range(5):
        sw = ["Rust", "Steel", "RustDark", "Gunmetal", "Rust"][i]
        o = box(c, "Sheet", "Rusty", sw, (2.1, 0.3, 9 + rng.uniform(-0.6, 0.6)), pos=(-4 + i * 2, 0, 4.6), bevel=0.06)
        jitter(o, 2)
    for x in (-5, 5):
        box(c, "Post", "Metal", "Gunmetal", (0.5, 0.5, 10), pos=(x, -0.3, 5), bevel=0.08)
    for z in (2, 8):
        box(c, "Rail", "Metal", "Gunmetal", (10, 0.3, 0.3), pos=(0, -0.3, z), bevel=0.05)


def oil_drums(c):
    spots = [(0, 0, 0, "ContainerBlue"), (2.5, 0.4, 0, "Coral"), (1.2, 2.2, 0, "ContainerBlue"), (1.2, 1.0, 3.1, "SafetyYellow")]
    for x, y, z, sw in spots:
        cyl(c, "Drum", "Metal", sw, 1.15, 3, pos=(x, y, z + 1.5), verts=14)
        cyl(c, "Hoop", "Metal", "Gunmetal", 1.2, 0.18, pos=(x, y, z + 1.0), verts=14, bevel=0.03)
        cyl(c, "Hoop", "Metal", "Gunmetal", 1.2, 0.18, pos=(x, y, z + 2.0), verts=14, bevel=0.03)


def pallet_stack(c):
    for level in range(3):
        z = level * 0.75
        for i in range(5):
            box(c, "Slat", "Planks", "Bark", (4, 0.7, 0.18), pos=(0, -1.6 + i * 0.8, z + 0.65), bevel=0.04)
        for x in (-1.7, 0, 1.7):
            box(c, "Block", "Planks", "RoofBrown", (0.6, 4, 0.5), pos=(x, 0, z + 0.3), bevel=0.04)
    box(c, "Load", "Fabric", "Plaster", (3.6, 3.6, 2.4), pos=(0, 0, 3.5), bevel=0.4)


def tire_stack(c):
    for i in range(5):
        cyl(c, "Tire", "Rubber", "Rubber", 1.2, 0.8, pos=(rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), 0.4 + i * 0.8),
            verts=14, bevel=0.2)
    cyl(c, "Tire", "Rubber", "Rubber", 1.2, 0.8, pos=(2.6, 0, 1.2), rot=(80, 0, 20), verts=14, bevel=0.2)


def gate_arch(c):
    for sx in (-14, 14):
        box(c, "Pillar", "Plate", "Gunmetal", (2, 2, 18), pos=(sx, 0, 9), bevel=0.2)
        for z in range(2, 18, 3):
            box(c, "Stripe", "Smooth", "SafetyYellow", (2.1, 2.1, 1.2), pos=(sx, 0, z), bevel=0.1)
        box(c, "Cap", "Metal", "SafetyYellow", (2.6, 2.6, 0.8), pos=(sx, 0, 18.4), bevel=0.15)
    box(c, "Beam", "Metal", "HazardBlack", (30, 1.4, 5), pos=(0, 0, 17), bevel=0.25)
    box(c, "Trim", "Metal", "SafetyYellow", (30.4, 1.6, 0.5), pos=(0, 0, 14.6), bevel=0.1)
    box(c, "Trim", "Metal", "SafetyYellow", (30.4, 1.6, 0.5), pos=(0, 0, 19.4), bevel=0.1)
    for sx in (-10, 0, 10):
        cyl(c, "Bulb", "Neon", "WindowWarm", 0.4, 0.4, pos=(sx, -0.8, 14.2), rot=(90, 0, 0), verts=10)
    # Hanging hubcap and chain for character
    cyl(c, "Chain", "Metal", "Steel", 0.08, 3, pos=(9, -0.9, 13), verts=6, bevel=0)
    cyl(c, "Hubcap", "Metal", "Steel", 1.0, 0.25, pos=(9, -1.0, 11.2), rot=(90, 0, 0), verts=12)


def floodlight(c):
    cyl(c, "Pole", "Metal", "Gunmetal", 0.3, 16, pos=(0, 0, 8), verts=8)
    box(c, "Bar", "Metal", "Gunmetal", (4, 0.4, 0.4), pos=(0, 0, 16), bevel=0.06)
    for sx in (-1.4, 1.4):
        box(c, "Lamp", "Metal", "Gunmetal", (1.2, 1.0, 1.0), pos=(sx, -0.5, 15.6), rot=(-30, 0, 0), bevel=0.15)
        box(c, "Lens", "Neon", "WindowWarm", (1.0, 0.1, 0.8), pos=(sx, -1.05, 15.3), rot=(-30, 0, 0), bevel=0.0)
    box(c, "Base", "Concrete", "Concrete", (1.6, 1.6, 0.8), pos=(0, 0, 0.4), bevel=0.15)


BUILDERS = [
    ("Crane", crane), ("Crusher", crusher), ("CarStack", car_stack), ("Wreck", wreck), ("Container", container),
    ("ScrapPile", scrap_pile), ("Workbench", workbench), ("SellShack", sell_shack), ("GearShack", gear_shack),
    ("FencePanel", fence_panel), ("OilDrums", oil_drums), ("PalletStack", pallet_stack), ("TireStack", tire_stack),
    ("GateArch", gate_arch), ("Floodlight", floodlight),
]

if __name__ == "__main__":
    build_set("scrapyard", BUILDERS)
