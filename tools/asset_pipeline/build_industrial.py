# @file Industrial salvage (V4 band 2): four machines built from Roblox parts
# @domain world
# @status wip
"""Industrial salvage models, written as Rojo model files (no mesh upload needed).

    python3 tools/asset_pipeline/build_industrial.py

Writes assets/roblox/salvage/{CopperSpool,HydraulicPump,DieselGenerator,TurbineRotor}.model.json.
Band 2 salvage has to look like a step up from town junk at a glance: heavy industrial machinery
in factory colours (copper, hydraulic blue, generator yellow, turbine steel with a cyan glow on
the Legendary rotor), each with its own silhouette. Pivot is the base centre (y = 0), like every
other salvage model. Parts are non-colliding: the loot root part handles the prompt.
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


COPPER = rgb(200, 116, 60)
COPPER_DARK = rgb(150, 82, 40)
WOOD = rgb(150, 104, 62)
STEEL = rgb(170, 178, 186)
STEEL_DARK = rgb(78, 82, 90)
HYD_BLUE = rgb(56, 104, 170)
HYD_BLUE_DARK = rgb(36, 70, 120)
GEN_YELLOW = rgb(222, 170, 40)
BLACK = rgb(30, 30, 34)
WHITE = rgb(236, 236, 230)
RED = rgb(204, 40, 36)
GREEN = rgb(80, 220, 110)
CYAN = rgb(120, 220, 255)
ALONG_Z = rot_y(math.pi / 2)  # a cylinder lying along Z


def model(children):
    return {
        "className": "Model",
        "properties": {"WorldPivotData": {"OptionalCFrame": {"position": [0, 0, 0], "orientation": IDENTITY}}},
        "children": children,
    }


def copper_spool():
    p = []
    p.append(part("Flange", (0.16, 1.7, 1.7), (0, 0.08, 0), WOOD, "WoodPlanks", "Cylinder", UPRIGHT))
    p.append(part("Wire", (1.1, 1.36, 1.36), (0, 0.71, 0), COPPER, "Metal", "Cylinder", UPRIGHT))
    for y in (0.35, 0.71, 1.07):  # winding bands catch the light
        p.append(part("Winding", (0.06, 1.38, 1.38), (0, y, 0), COPPER_DARK, "Metal", "Cylinder", UPRIGHT))
    p.append(part("Flange", (0.16, 1.7, 1.7), (0, 1.34, 0), WOOD, "WoodPlanks", "Cylinder", UPRIGHT))
    p.append(part("Hub", (0.2, 0.42, 0.42), (0, 1.5, 0), STEEL, "Metal", "Cylinder", UPRIGHT))
    # the loose end of the wire, trailing off the drum
    p.append(part("Tail", (0.9, 0.08, 0.08), (0.62, 0.9, 0.55), COPPER, "Metal", "Cylinder", rot_y(-0.7)))
    return model(p)


def hydraulic_pump():
    p = []
    p.append(part("Skid", (2.2, 0.16, 1.4), (0, 0.08, 0), STEEL_DARK, "DiamondPlate"))
    p.append(part("Motor", (1.1, 0.95, 0.95), (-0.45, 0.66, 0), HYD_BLUE, "Metal", "Cylinder"))
    for x in (-0.82, -0.62, -0.42, -0.22):  # cooling fins
        p.append(part("Fin", (0.05, 1.02, 1.02), (x, 0.66, 0), HYD_BLUE_DARK, "Metal", "Cylinder"))
    p.append(part("Housing", (0.8, 0.9, 0.9), (0.5, 0.61, 0), HYD_BLUE_DARK, "Metal"))
    p.append(part("Coupling", (0.25, 0.5, 0.5), (0.03, 0.66, 0), STEEL, "Metal", "Cylinder"))
    for z, h in ((-0.25, 0.7), (0.25, 0.5)):  # inlet and outlet pipes
        p.append(part("Pipe", (h, 0.22, 0.22), (0.6, 1.06 + h / 2, z), STEEL, "Metal", "Cylinder", UPRIGHT))
        p.append(part("PipeCap", (0.08, 0.32, 0.32), (0.6, 1.06 + h, z), STEEL_DARK, "Metal", "Cylinder", UPRIGHT))
    # pressure gauge on the housing face
    p.append(part("Gauge", (0.06, 0.36, 0.36), (0.92, 0.8, 0.2), WHITE, "SmoothPlastic", "Cylinder"))
    p.append(part("Needle", (0.02, 0.04, 0.16), (0.96, 0.84, 0.2), RED, "SmoothPlastic", rot=rot_x(0.6)))
    return model(p)


def diesel_generator():
    p = []
    p.append(part("FuelTank", (3.0, 0.4, 2.0), (0, 0.2, 0), STEEL_DARK, "Metal"))
    p.append(part("Housing", (2.6, 1.5, 1.8), (0, 1.15, 0), GEN_YELLOW, "Metal"))
    p.append(part("Roof", (2.7, 0.12, 1.9), (0, 1.96, 0), GEN_YELLOW, "Metal"))
    # louvred grille on the front
    for i in range(5):
        p.append(part("Louvre", (1.2, 0.08, 0.06), (-0.5, 0.75 + i * 0.2, -0.92), BLACK, "Metal"))
    # control panel with a status light
    p.append(part("Panel", (0.7, 0.6, 0.06), (0.75, 1.2, -0.92), BLACK, "SmoothPlastic"))
    p.append(part("Status", (0.12, 0.12, 0.12), (0.6, 1.32, -0.96), GREEN, "Neon", "Ball"))
    p.append(part("Dial", (0.04, 0.2, 0.2), (0.88, 1.12, -0.96), WHITE, "SmoothPlastic", "Cylinder", ALONG_Z))
    # exhaust stack with a rain cap
    p.append(part("Exhaust", (0.7, 0.2, 0.2), (1.0, 2.37, 0.5), STEEL, "Metal", "Cylinder", UPRIGHT))
    p.append(part("ExhaustCap", (0.06, 0.32, 0.32), (1.0, 2.74, 0.5), STEEL_DARK, "Metal", "Cylinder", UPRIGHT))
    # lifting eye
    p.append(part("LiftEye", (0.1, 0.36, 0.36), (-0.6, 2.12, 0), STEEL, "Metal", "Cylinder", ALONG_Z))
    # hazard stripes on the tank
    for i in range(4):
        p.append(part("Stripe", (0.18, 0.42, 0.05), (-1.2 + i * 0.36, 0.2, -1.01), BLACK, "SmoothPlastic", rot=rot_z(0.6)))
    return model(p)


def turbine_rotor():
    p = []
    p.append(part("Cradle", (2.0, 0.24, 1.4), (0, 0.12, 0), STEEL_DARK, "DiamondPlate"))
    for x in (-0.75, 0.75):
        p.append(part("Post", (0.22, 1.4, 0.3), (x, 0.94, 0), STEEL_DARK, "Metal"))
    shaft_y = 1.65
    p.append(part("Shaft", (1.9, 0.22, 0.22), (0, shaft_y, 0), STEEL, "Metal", "Cylinder"))
    p.append(part("Hub", (0.5, 0.7, 0.7), (0, shaft_y, 0), STEEL, "Metal", "Cylinder"))
    p.append(part("HubCap", (0.12, 0.4, 0.4), (-0.3, shaft_y, 0), CYAN, "Neon", "Cylinder"))
    # ten twisted blades around the shaft (in the Y-Z plane)
    n = 10
    for i in range(n):
        a = i * 2 * math.pi / n
        r = 0.85
        y, z = shaft_y + math.cos(a) * r, math.sin(a) * r
        blade = mul(rot_x(-a), rot_y(0.35))  # radial, then twisted
        p.append(part("Blade", (0.08, 1.05, 0.34), (0, y, z), STEEL, "Metal", rot=blade))
    # the Legendary tell: a glowing shroud ring segment set behind the blades
    p.append(part("Shroud", (0.08, 2.9, 2.9), (0.3, shaft_y, 0), CYAN, "Neon", "Cylinder", transparency=0.55))
    return model(p)


BUILDERS = {
    "CopperSpool": copper_spool,
    "HydraulicPump": hydraulic_pump,
    "DieselGenerator": diesel_generator,
    "TurbineRotor": turbine_rotor,
}

if __name__ == "__main__":
    for name, build in BUILDERS.items():
        path = os.path.join(OUT, name + ".model.json")
        with open(path, "w") as f:
            json.dump(build(), f, indent=1)
            f.write("\n")
        print("wrote", os.path.normpath(path))
