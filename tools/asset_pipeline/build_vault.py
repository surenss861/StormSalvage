# @file The Armored Wreck and vault salvage (V4 band 4), built from Roblox parts
# @domain world
# @status wip
"""Band 4 models, written as Rojo model files (no mesh upload needed).

    python3 tools/asset_pipeline/build_vault.py

Writes assets/roblox/salvage/{Strongbox,BullionBar,CrownJewels}.model.json and
assets/roblox/events/ArmoredWreck.model.json.

The wreck is an armored bank truck the storm rolled onto its side. Its three locks are parts
named Lock1..Lock3 (WreckService puts the cutting prompt and progress bar on each):
  Lock1  the rear doors, at standing height
  Lock2  the side hatch, now facing the sky: climb the toppled crates to reach it
  Lock3  the roof hatch, now facing sideways, round the back of the truck
The body collides (you can climb it); the trim doesn't. Pivot is the ground centre (y = 0).
"""

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from build_golden_core import IDENTITY, UPRIGHT, mul, part, rot_x, rot_y, rot_z  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "roblox")


def rgb(r, g, b):
    return (r / 255, g / 255, b / 255)


def model(children):
    return {
        "className": "Model",
        "properties": {"WorldPivotData": {"OptionalCFrame": {"position": [0, 0, 0], "orientation": IDENTITY}}},
        "children": children,
    }


def solid(p):
    p["properties"]["CanCollide"] = True
    p["properties"]["CanQuery"] = True
    return p


ARMOR = rgb(78, 86, 80)
ARMOR_DARK = rgb(52, 58, 54)
STRIPE = rgb(214, 170, 50)
GLASS = rgb(120, 150, 170)
TYRE = rgb(30, 30, 32)
HUB = rgb(150, 150, 150)
LOCK = rgb(60, 60, 66)
RED = rgb(255, 60, 50)
MONEY = rgb(120, 170, 110)
GOLD = rgb(255, 200, 60)
GOLD_DARK = rgb(200, 150, 40)
STEEL = rgb(70, 74, 82)
VELVET = rgb(120, 20, 40)
RUBY = rgb(230, 40, 70)
SAPPHIRE = rgb(60, 110, 255)
EMERALD = rgb(40, 200, 110)
CRATE = rgb(150, 110, 70)


def lock(name, pos, facing):
    """A heavy lock plate with a red armed light. `facing` turns the plate to its face."""
    return part(name, (1.6, 1.6, 0.6), pos, LOCK, "DiamondPlate", rot=facing)


def armored_wreck():
    p = []
    # Lying on its side: length along X (cab at +X), the chassis faces +Z, the roof faces -Z.
    tilt = rot_x(0.04)
    p.append(solid(part("Cargo", (12, 7, 8), (-2, 3.5, 0), ARMOR, "Metal", rot=tilt)))
    p.append(solid(part("Cab", (5, 6, 7.4), (6.5, 3, 0.3), ARMOR_DARK, "Metal", rot=tilt)))
    p.append(part("Windshield", (0.2, 3.6, 4.8), (9.05, 3.2, -0.6), GLASS, "Glass", transparency=0.35))
    p.append(part("Bumper", (0.6, 6.4, 1.2), (9.3, 3.2, 3.2), HUB, "Metal"))
    for y in (2.2, 4.8):  # the company stripe, both sides of the toppled body
        p.append(part("Stripe", (11.8, 0.6, 0.12), (-2, y, -4.08), STRIPE, "SmoothPlastic"))
    p.append(part("Stripe", (11.8, 0.12, 0.6), (-2, 7.08, -2.6), STRIPE, "SmoothPlastic"))
    # Wheels stick out sideways (the chassis faces +Z).
    for x in (-6, -1.5, 7):
        for y in (1.2, 5.8):
            p.append(part("Tyre", (1.4, 2.4, 2.4), (x, y, 4.7), TYRE, "Rubber", "Cylinder", rot_y(math.pi / 2)))
            p.append(part("Hub", (1.5, 1.1, 1.1), (x, y, 4.75), HUB, "Metal", "Cylinder", rot_y(math.pi / 2)))
    p.append(part("Axle", (14, 0.5, 0.5), (0.5, 3.5, 4.3), ARMOR_DARK, "Metal"))
    # Rear doors (Lock1, standing height), side hatch on top (Lock2), roof hatch (Lock3).
    p.append(part("RearDoors", (0.3, 6.4, 7.2), (-8.1, 3.5, 0), ARMOR_DARK, "DiamondPlate"))
    p.append(part("DoorSeam", (0.35, 6.4, 0.12), (-8.15, 3.5, 0), LOCK, "Metal"))
    p.append(lock("Lock1", (-8.45, 3.2, 0), rot_y(math.pi / 2)))
    p.append(part("SideHatch", (4, 0.25, 3.6), (-2.5, 7.15, 0.4), ARMOR_DARK, "DiamondPlate"))
    p.append(lock("Lock2", (-2.5, 7.45, 0.4), rot_x(math.pi / 2)))
    p.append(part("RoofHatch", (4, 3.6, 0.25), (-2.5, 3.5, -4.15), ARMOR_DARK, "DiamondPlate"))
    p.append(lock("Lock3", (-2.5, 3.5, -4.45), IDENTITY))
    for name, pos in (("Light1", (-8.8, 3.95, 0)), ("Light2", (-2.5, 7.9, 0.4)), ("Light3", (-2.5, 3.95, -4.9))):
        p.append(part(name, (0.35, 0.35, 0.35), pos, RED, "Neon", "Ball"))
    # Emergency beacon (cab), crumpled cab corner, toppled crates as the step up to the side hatch.
    p.append(part("Beacon", (0.8, 0.8, 0.8), (6.5, 6.3, 0.3), rgb(255, 140, 40), "Neon", "Ball"))
    p.append(part("Dent", (2.2, 1.6, 0.5), (8, 1.2, -3.6), ARMOR_DARK, "CorrodedMetal", rot=rot_z(0.4)))
    p.append(solid(part("Crate", (3, 3, 3), (-4, 1.5, 6.6), CRATE, "WoodPlanks", rot=rot_y(0.3))))
    p.append(solid(part("Crate", (2.6, 2.6, 2.6), (-1.2, 4.3, 6.2), CRATE, "WoodPlanks", rot=rot_y(-0.2))))
    # Banknotes blown out of a split seam.
    for i in range(9):
        a = i * 1.9
        x = -9.5 - (i % 3) * 1.1
        z = math.sin(a) * 3.2
        p.append(part("Notes", (0.9, 0.08, 0.5), (x, 0.06 + (i % 2) * 0.05, z), MONEY, "SmoothPlastic", rot=rot_y(a)))
    return model(p)


def strongbox():
    p = [part("Box", (2.0, 1.3, 1.4), (0, 0.65, 0), STEEL, "DiamondPlate")]
    p.append(part("Lid", (2.06, 0.18, 1.46), (0, 1.36, 0), rgb(54, 58, 64), "Metal"))
    p.append(part("Dial", (0.12, 0.6, 0.6), (0, 0.7, 0.72), HUB, "Metal", "Cylinder", rot_y(math.pi / 2)))
    p.append(part("DialMark", (0.14, 0.08, 0.3), (0, 0.85, 0.74), RED, "Neon"))
    for x in (-0.95, 0.95):
        p.append(part("Band", (0.12, 1.32, 1.44), (x * 0.8, 0.65, 0), GOLD_DARK, "Metal"))
    p.append(part("Handle", (0.9, 0.12, 0.12), (0, 1.55, 0), HUB, "Metal"))
    return model(p)


def bullion_bar():
    p = [part("Bar", (1.7, 0.45, 0.85), (0, 0.23, 0), GOLD, "Foil")]
    p.append(part("Top", (1.4, 0.2, 0.6), (0, 0.55, 0), GOLD, "Foil"))
    p.append(part("Stamp", (0.6, 0.05, 0.3), (0, 0.66, 0), GOLD_DARK, "Metal"))
    p.append(part("Glint", (0.12, 0.05, 0.5), (-0.45, 0.67, 0), rgb(255, 245, 200), "Neon"))
    return model(p)


def crown_jewels():
    p = [part("Cushion", (1.7, 0.4, 1.7), (0, 0.2, 0), VELVET, "Fabric")]
    p.append(part("Band", (0.45, 1.3, 1.3), (0, 0.65, 0), GOLD, "Foil", "Cylinder", UPRIGHT))
    for i in range(6):
        a = i * math.pi / 3
        x, z = math.cos(a) * 0.6, math.sin(a) * 0.6
        p.append(part("Point", (0.22, 0.6, 0.22), (x, 1.15, z), GOLD, "Foil", rot=rot_y(-a)))
        p.append(part("Pearl", (0.2, 0.2, 0.2), (x, 1.5, z), rgb(245, 240, 230), "SmoothPlastic", "Ball"))
    for color, a in ((RUBY, 0), (SAPPHIRE, 2.1), (EMERALD, 4.2)):
        p.append(part("Gem", (0.26, 0.26, 0.26), (math.cos(a) * 0.66, 0.66, math.sin(a) * 0.66), color, "Neon", "Ball"))
    p.append(part("Cap", (0.9, 0.9, 0.9), (0, 0.95, 0), VELVET, "Fabric", "Ball"))
    p.append(part("Cross", (0.12, 0.45, 0.12), (0, 1.55, 0), GOLD, "Foil"))
    return model(p)


BUILDERS = {
    ("salvage", "Strongbox"): strongbox,
    ("salvage", "BullionBar"): bullion_bar,
    ("salvage", "CrownJewels"): crown_jewels,
    ("events", "ArmoredWreck"): armored_wreck,
}

if __name__ == "__main__":
    for (folder, name), build in BUILDERS.items():
        os.makedirs(os.path.join(ROOT, folder), exist_ok=True)
        path = os.path.join(ROOT, folder, name + ".model.json")
        with open(path, "w") as f:
            json.dump(build(), f, indent=1)
            f.write("\n")
        print("wrote", os.path.normpath(path))
