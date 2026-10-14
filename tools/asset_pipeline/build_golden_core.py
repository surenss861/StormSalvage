# @file Golden Storm Core: the V4 jackpot salvage, built from Roblox parts
# @domain world
# @status wip
"""Golden Storm Core model, written as a Rojo model file (no mesh upload needed).

    python3 tools/asset_pipeline/build_golden_core.py

Writes assets/roblox/salvage/GoldenCore.model.json. The ordinary Storm Core is a cyan orb in three
gunmetal gyroscope rings on a yellow clamp (build_salvage.py). The jackpot must read differently
at a glance and from far away, not as a recoloured copy, so it has its own silhouette: a tall
gold reliquary cage on a dark plinth, a faceted crystal star around a molten-gold core, and a
crown of four spikes with a diamond on top. About 2.1 x 3.4 x 2.1 studs (the Storm Core is
2.2 x 2.1 x 2.2). Pivot is the base centre (y = 0), like every other salvage model.
"""

import json
import math
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "roblox", "salvage", "GoldenCore.model.json")

GOLD = (0.90, 0.69, 0.20)
GOLD_TRIM = (0.80, 0.58, 0.14)
MOLTEN = (1.0, 0.78, 0.24)
CRYSTAL = (1.0, 0.87, 0.52)
PLINTH = (0.20, 0.19, 0.23)


def rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return [[1, 0, 0], [0, c, -s], [0, s, c]]


def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]


def rot_z(a):
    c, s = math.cos(a), math.sin(a)
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


IDENTITY = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
UPRIGHT = rot_z(math.pi / 2)  # Roblox cylinders run along X; this stands one on its end


def r(v):
    return round(v, 4)


def part(name, size, pos, color, material, shape="Block", rot=IDENTITY, transparency=0.0):
    return {
        "name": name,
        "className": "Part",
        "properties": {
            "Size": [r(v) for v in size],
            "CFrame": {"CFrame": {"position": [r(v) for v in pos], "orientation": [[r(v) for v in row] for row in rot]}},
            "Color": [r(v) for v in color],
            "Material": material,
            "Shape": shape,
            "Transparency": transparency,
            "Anchored": True,
            "CanCollide": False,
            "CanQuery": False,
            "CanTouch": False,
            "CastShadow": material != "Neon",
            "TopSurface": "Smooth",
            "BottomSurface": "Smooth",
        },
    }


def build():
    parts = []
    # Plinth with a gold trim band.
    parts.append(part("Plinth", (0.36, 1.9, 1.9), (0, 0.18, 0), PLINTH, "Metal", "Cylinder", UPRIGHT))
    parts.append(part("Trim", (0.12, 2.06, 2.06), (0, 0.42, 0), GOLD_TRIM, "Metal", "Cylinder", UPRIGHT))
    # Reliquary cage: four bars from the trim to the crown.
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        x, z = math.cos(a) * 0.86, math.sin(a) * 0.86
        parts.append(part("Bar", (2.2, 0.16, 0.16), (x, 1.58, z), GOLD, "Metal", "Cylinder", UPRIGHT))
    # Crown plate.
    parts.append(part("Crown", (0.14, 2.06, 2.06), (0, 2.72, 0), GOLD_TRIM, "Metal", "Cylinder", UPRIGHT))
    # Molten core in a faceted crystal star (two cubes turned against each other).
    parts.append(part("Core", (1.2, 1.2, 1.2), (0, 1.58, 0), MOLTEN, "Neon", "Ball"))
    parts.append(
        part(
            "Facet",
            (1.3, 1.3, 1.3),
            (0, 1.58, 0),
            CRYSTAL,
            "Glass",
            rot=mul(rot_y(math.pi / 4), rot_x(math.pi / 4)),
            transparency=0.45,
        )
    )
    parts.append(
        part(
            "Facet",
            (1.3, 1.3, 1.3),
            (0, 1.58, 0),
            CRYSTAL,
            "Glass",
            rot=mul(rot_y(-math.pi / 4), rot_z(math.pi / 4)),
            transparency=0.45,
        )
    )
    # Crown spikes over the bars, leaning out, each tipped with a gold bead.
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        out = 0.35  # lean, radians
        dx, dz = math.cos(a), math.sin(a)
        base = (dx * 0.7, 2.79, dz * 0.7)
        h = 0.62
        tip = (base[0] + dx * math.sin(out) * h, base[1] + math.cos(out) * h, base[2] + dz * math.sin(out) * h)
        mid = tuple((base[k] + tip[k]) / 2 for k in range(3))
        # Tilt about the horizontal axis perpendicular to (dx, dz): yaw to face out, then lean.
        lean = mul(rot_y(-a), rot_z(-out))
        parts.append(part("Spike", (0.16, h, 0.16), mid, GOLD, "Metal", rot=lean))
        parts.append(part("Bead", (0.26, 0.26, 0.26), tip, MOLTEN, "Neon", "Ball"))
    # Diamond on top.
    parts.append(
        part(
            "Diamond",
            (0.42, 0.42, 0.42),
            (0, 3.12, 0),
            MOLTEN,
            "Neon",
            rot=mul(rot_y(math.pi / 4), rot_x(math.atan(1 / math.sqrt(2)))),
        )
    )
    return {
        "className": "Model",
        "properties": {"WorldPivotData": {"OptionalCFrame": {"position": [0, 0, 0], "orientation": IDENTITY}}},
        "children": parts,
    }


if __name__ == "__main__":
    with open(OUT, "w") as f:
        json.dump(build(), f, indent=1)
        f.write("\n")
    print("wrote", os.path.normpath(OUT))
