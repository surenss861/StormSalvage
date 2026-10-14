# @file Storm artifacts and the Storm Heart (V4 band 3), built from Roblox parts
# @domain world
# @status wip
"""Band 3 salvage models, written as Rojo model files (no mesh upload needed).

    python3 tools/asset_pipeline/build_artifacts.py

Writes assets/roblox/salvage/{GaleShard,TideRelic,Fulgurite,StormHeart}.model.json.
Artifacts are the storm made solid, so they read as natural, glowing and strange next to town
junk and industrial machinery: a wind crystal, a sea relic, lightning glass, and the Storm Heart
(the Eye's jackpot) as a caged violet storm. Pivot is the base centre (y = 0). Non-colliding.
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


STONE = rgb(96, 100, 108)
ICE = rgb(190, 235, 255)
WIND = rgb(130, 220, 255)
BRONZE = rgb(150, 110, 60)
VERDIGRIS = rgb(70, 160, 140)
SEA = rgb(60, 220, 210)
SAND = rgb(214, 190, 140)
GLASS_GOLD = rgb(255, 225, 140)
BOLT = rgb(255, 245, 160)
VIOLET = rgb(190, 120, 255)
WHITE = rgb(240, 236, 255)
DARK = rgb(46, 42, 58)


def gale_shard():
    p = [part("Stone", (1.6, 0.4, 1.4), (0, 0.2, 0), STONE, "Slate")]
    shards = [  # (height, x, z, lean x, lean z, width)
        (2.3, 0.0, 0.0, 0.0, 0.0, 0.42),
        (1.6, 0.35, 0.15, 0.0, -0.35, 0.32),
        (1.4, -0.32, 0.2, 0.3, 0.3, 0.3),
        (1.2, 0.1, -0.38, -0.35, 0.1, 0.28),
        (1.0, -0.3, -0.25, -0.2, 0.35, 0.26),
    ]
    for h, x, z, lx, lz, w in shards:
        rot = mul(rot_x(lx), rot_z(lz))
        up = (math.sin(lz) * -1, math.cos(lx) * math.cos(lz), math.sin(lx))
        mid = (x + up[0] * h / 2, 0.4 + up[1] * h / 2, z + up[2] * h / 2)
        p.append(part("Shard", (w, h, w), mid, ICE, "Glass", rot=mul(rot, rot_y(math.pi / 4)), transparency=0.25))
    p.append(part("Core", (0.14, 1.9, 0.14), (0, 1.35, 0), WIND, "Neon", rot=rot_y(math.pi / 4)))
    return model(p)


def tide_relic():
    p = [part("Reef", (2.0, 0.35, 1.6), (0, 0.17, 0), rgb(120, 90, 80), "Rock")]
    # an upright ancient disc, like a ship's compass face
    p.append(part("Disc", (0.3, 1.7, 1.7), (0, 1.2, 0), BRONZE, "Metal", "Cylinder", rot_y(math.pi / 2)))
    p.append(part("Rim", (0.36, 1.82, 1.82), (0, 1.2, -0.02), VERDIGRIS, "Metal", "Cylinder", rot_y(math.pi / 2)))
    p.append(part("Glow", (0.34, 0.8, 0.8), (0, 1.2, 0.02), SEA, "Neon", "Cylinder", rot_y(math.pi / 2)))
    for a in range(4):  # compass points
        ang = a * math.pi / 2
        p.append(part("Point", (0.18, 0.18, 0.34), (math.cos(ang) * 0.62, 1.2 + math.sin(ang) * 0.62, 0.2), BRONZE, "Metal", rot=rot_z(ang)))
    for bx, by in ((0.55, 0.55), (-0.6, 0.8), (0.45, 1.85), (-0.35, 1.9)):  # barnacles
        p.append(part("Barnacle", (0.2, 0.2, 0.2), (bx, by, 0.18), rgb(220, 215, 200), "Pebble", "Ball"))
    return model(p)


def fulgurite():
    p = [part("FusedSand", (0.35, 1.5, 1.5), (0, 0.17, 0), SAND, "Sand", "Cylinder", UPRIGHT)]
    p.append(part("Trunk", (0.34, 2.3, 0.34), (0, 1.45, 0), GLASS_GOLD, "Glass", transparency=0.15))
    p.append(part("Vein", (0.1, 2.2, 0.1), (0, 1.45, 0), BOLT, "Neon"))
    branches = [(0.9, 0.7, 0.0), (1.5, -0.6, 0.6), (1.9, 0.5, -1.2), (1.2, -0.8, 2.2)]
    for y, lean, yaw in branches:
        rot = mul(rot_y(yaw), rot_z(lean))
        dx = -math.sin(lean) * 0.45
        mid = (dx * math.cos(yaw), y + 0.35, -dx * math.sin(yaw))
        p.append(part("Branch", (0.18, 0.8, 0.18), mid, GLASS_GOLD, "Glass", rot=rot, transparency=0.15))
        p.append(part("BranchVein", (0.06, 0.75, 0.06), mid, BOLT, "Neon", rot=rot))
    return model(p)


def storm_heart():
    p = []
    # the claw it rests in
    p.append(part("Base", (0.3, 1.4, 1.4), (0, 0.15, 0), DARK, "Metal", "Cylinder", UPRIGHT))
    for a in range(3):
        ang = a * 2 * math.pi / 3
        x, z = math.cos(ang) * 0.75, math.sin(ang) * 0.75
        p.append(part("Prong", (0.2, 1.3, 0.2), (x, 0.85, z), DARK, "Metal", rot=mul(rot_y(-ang), rot_z(0.35))))
    # the storm itself: a violet core in a glass shell, crossed by lightning arcs
    p.append(part("Core", (1.5, 1.5, 1.5), (0, 1.75, 0), VIOLET, "Neon", "Ball"))
    p.append(part("Shell", (2.3, 2.3, 2.3), (0, 1.75, 0), rgb(220, 200, 255), "Glass", "Ball", transparency=0.6))
    for a in range(6):
        ang = a * math.pi / 3
        rot = mul(rot_y(ang), rot_x(0.6 if a % 2 == 0 else -0.6))
        p.append(part("Arc", (0.08, 2.0, 0.08), (math.cos(ang) * 0.85, 1.75, math.sin(ang) * 0.85), WHITE, "Neon", rot=rot))
    p.append(part("Crown", (0.3, 0.3, 0.3), (0, 3.05, 0), WHITE, "Neon", "Ball"))
    return model(p)


BUILDERS = {
    "GaleShard": gale_shard,
    "TideRelic": tide_relic,
    "Fulgurite": fulgurite,
    "StormHeart": storm_heart,
}

if __name__ == "__main__":
    for name, build in BUILDERS.items():
        path = os.path.join(OUT, name + ".model.json")
        with open(path, "w") as f:
            json.dump(build(), f, indent=1)
            f.write("\n")
        print("wrote", os.path.normpath(path))
