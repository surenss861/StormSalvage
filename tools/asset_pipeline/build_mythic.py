# @file Mythic Cores (V4 band 5, the Storm Titan's prize), built from Roblox parts
# @domain world
# @status wip
"""Band 5 salvage models, written as Rojo model files (no mesh upload needed).

    python3 tools/asset_pipeline/build_mythic.py

Writes assets/roblox/salvage/{TitanCore,PrismCore,SingularityCore}.model.json.
Each is the storm's eye made solid, one above the Storm Heart and readable apart at a glance:
  Titan Core        a pale-blue storm sphere in a spinning cage of three rings (60%)
  Prism Core        a magenta crystal cluster around a white heart (30%)
  Singularity Core  a black sphere with a gold accretion disc and a violet halo (10%)
Pivot is the base centre (y = 0). Non-colliding.
"""

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from build_golden_core import IDENTITY, UPRIGHT, mul, part, rot_x, rot_y, rot_z  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "roblox", "salvage")


def rgb(r, g, b):
    return (r / 255, g / 255, b / 255)


def model(children):
    return {
        "className": "Model",
        "properties": {"WorldPivotData": {"OptionalCFrame": {"position": [0, 0, 0], "orientation": IDENTITY}}},
        "children": children,
    }


DARK = rgb(36, 34, 46)
STEEL = rgb(120, 124, 138)
WHITE = rgb(245, 245, 255)


def plinth():
    return [
        part("Plinth", (0.4, 1.8, 1.8), (0, 0.2, 0), DARK, "Metal", "Cylinder", UPRIGHT),
        part("Trim", (0.12, 1.9, 1.9), (0, 0.42, 0), STEEL, "Metal", "Cylinder", UPRIGHT),
    ]


def titan_core():
    p = plinth()
    c = (0, 2.0, 0)
    p.append(part("Core", (1.7, 1.7, 1.7), c, rgb(120, 200, 255), "Neon", "Ball"))
    p.append(part("Shell", (2.3, 2.3, 2.3), c, rgb(200, 235, 255), "Glass", "Ball", transparency=0.55))
    for i, tilt in enumerate((0.0, 1.05, 2.1)):
        rot = mul(rot_y(tilt), rot_x(math.pi / 2 + 0.5 * (i - 1)))
        p.append(part("Ring", (0.12, 2.9, 2.9), c, STEEL, "Metal", "Cylinder", rot, transparency=0.0))
    return model(p)


def prism_core():
    p = plinth()
    p.append(part("Heart", (0.9, 0.9, 0.9), (0, 1.5, 0), WHITE, "Neon", "Ball"))
    crystals = [  # height, lean, yaw, width
        (2.6, 0.0, 0.0, 0.55),
        (1.9, 0.45, 0.4, 0.42),
        (1.7, 0.5, 2.5, 0.4),
        (1.5, 0.55, 4.4, 0.38),
        (1.2, 0.7, 1.4, 0.32),
        (1.1, 0.65, 3.4, 0.3),
    ]
    for h, lean, yaw, w in crystals:
        rot = mul(rot_y(yaw), rot_z(lean))
        dx = -math.sin(lean) * h / 2
        mid = (dx * math.cos(yaw), 0.45 + math.cos(lean) * h / 2, -dx * math.sin(yaw))
        p.append(part("Crystal", (w, h, w), mid, rgb(255, 120, 230), "Glass", rot=mul(rot, rot_y(math.pi / 4)), transparency=0.2))
    return model(p)


def singularity_core():
    p = plinth()
    c = (0, 2.0, 0)
    p.append(part("Void", (1.5, 1.5, 1.5), c, rgb(10, 6, 18), "SmoothPlastic", "Ball"))
    p.append(part("Halo", (2.2, 2.2, 2.2), c, rgb(150, 80, 255), "ForceField", "Ball", transparency=0.3))
    p.append(part("Disc", (0.08, 3.4, 3.4), c, rgb(255, 190, 70), "Neon", "Cylinder", mul(rot_z(math.pi / 2), rot_x(0.35)), transparency=0.25))
    p.append(part("DiscInner", (0.1, 2.3, 2.3), c, rgb(255, 240, 200), "Neon", "Cylinder", mul(rot_z(math.pi / 2), rot_x(0.35)), transparency=0.4))
    return model(p)


BUILDERS = {
    "TitanCore": titan_core,
    "PrismCore": prism_core,
    "SingularityCore": singularity_core,
}

if __name__ == "__main__":
    for name, build in BUILDERS.items():
        path = os.path.join(OUT, name + ".model.json")
        with open(path, "w") as f:
            json.dump(build(), f, indent=1)
            f.write("\n")
        print("wrote", os.path.normpath(path))
