"""Salvage items: the loot players pick up. Sizes roughly match Config.Loot (studs).

blender -b --python tools/asset_pipeline/build_salvage.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from kit import box, build_set, cyl, sphere, torus  # noqa: E402


def can(c):
    cyl(c, "Body", "Metal", "Steel", 0.42, 1.2, pos=(0, 0, 0.6), verts=14)
    cyl(c, "Rim", "Metal", "Gunmetal", 0.44, 0.08, pos=(0, 0, 1.17), verts=14, bevel=0.02)
    cyl(c, "Label", "Smooth", "Coral", 0.435, 0.5, pos=(0, 0, 0.6), verts=14, bevel=0.0)
    cyl(c, "Rim", "Metal", "Gunmetal", 0.44, 0.08, pos=(0, 0, 0.04), verts=14, bevel=0.02)
    box(c, "Tab", "Metal", "Steel", (0.3, 0.14, 0.04), pos=(0.12, 0, 1.23), rot=(0, 0, 20), bevel=0.02)


def pipe(c):
    cyl(c, "Pipe", "Metal", "Rust", 0.22, 3.0, pos=(0, 0, 0.25), rot=(0, 90, 0), verts=10)
    for x in (-1.4, 1.4):
        cyl(c, "Joint", "Metal", "RustDark", 0.3, 0.3, pos=(x, 0, 0.25), rot=(0, 90, 0), verts=10)
    cyl(c, "Elbow", "Metal", "Rust", 0.22, 0.7, pos=(1.55, 0, 0.55), verts=10)


def toaster(c):
    box(c, "Shell", "Metal", "Steel", (1.5, 0.95, 1.0), pos=(0, 0, 0.55), bevel=0.25, segments=2)
    for y in (-0.18, 0.18):
        box(c, "Slot", "Smooth", "HazardBlack", (1.0, 0.14, 0.2), pos=(0, y, 1.02), bevel=0.04)
    box(c, "Lever", "Smooth", "HazardBlack", (0.12, 0.3, 0.12), pos=(0.79, 0, 0.75), bevel=0.03)
    box(c, "Base", "Smooth", "HazardBlack", (1.55, 1.0, 0.12), pos=(0, 0, 0.06), bevel=0.04)
    box(c, "Toast", "Fabric", "Mustard", (0.8, 0.12, 0.4), pos=(0, -0.18, 1.15), rot=(0, 0, 0), bevel=0.05)


def tv(c):
    box(c, "Cabinet", "Planks", "Bark", (2.0, 1.5, 1.6), pos=(0, 0, 0.9), bevel=0.15, segments=2)
    box(c, "Bezel", "Smooth", "HazardBlack", (1.5, 0.12, 1.15), pos=(-0.15, -0.76, 0.95), bevel=0.08)
    box(c, "Screen", "Glass", "Teal", (1.25, 0.1, 0.95), pos=(-0.15, -0.8, 0.95), bevel=0.15, segments=2)
    for z in (1.25, 0.95):
        cyl(c, "Knob", "Metal", "Steel", 0.08, 0.1, pos=(0.78, -0.8, z), rot=(90, 0, 0), verts=8)
    for x in (-0.15, 0.15):
        cyl(c, "Antenna", "Metal", "Steel", 0.03, 1.1, pos=(x * 2, 0.2, 2.15), rot=(0, x * 160, 0), verts=6, bevel=0)
    for x in (-0.8, 0.8):
        box(c, "Foot", "Smooth", "HazardBlack", (0.2, 0.2, 0.12), pos=(x, -0.5, 0.06), bevel=0.03)


def tire(c):
    cyl(c, "Tire", "Rubber", "Rubber", 1.1, 0.8, pos=(0, 0, 1.1), rot=(0, 90, 0), verts=16, bevel=0.2)
    cyl(c, "Rim", "Metal", "Steel", 0.55, 0.84, pos=(0, 0, 1.1), rot=(0, 90, 0), verts=10, bevel=0.05)
    cyl(c, "Hub", "Metal", "Gunmetal", 0.2, 0.9, pos=(0, 0, 1.1), rot=(0, 90, 0), verts=8, bevel=0.03)


def battery(c):
    box(c, "Case", "Plastic", "ContainerGreen", (1.6, 1.1, 1.0), pos=(0, 0, 0.5), bevel=0.1)
    box(c, "Lid", "Plastic", "HazardBlack", (1.65, 1.15, 0.15), pos=(0, 0, 1.05), bevel=0.05)
    cyl(c, "Plus", "Metal", "Coral", 0.12, 0.2, pos=(-0.5, 0, 1.2), verts=8)
    cyl(c, "Minus", "Metal", "Steel", 0.12, 0.2, pos=(0.5, 0, 1.2), verts=8)
    box(c, "Sticker", "Smooth", "Mustard", (0.8, 0.05, 0.4), pos=(0, -0.57, 0.5), bevel=0.02)


def engine(c):
    box(c, "Block", "Metal", "Gunmetal", (2.4, 1.6, 1.4), pos=(0, 0, 0.8), bevel=0.15)
    box(c, "Head", "Metal", "Steel", (2.2, 1.2, 0.5), pos=(0, 0, 1.75), bevel=0.12)
    box(c, "Cover", "Smooth", "Coral", (1.9, 0.9, 0.25), pos=(0, 0, 2.1), bevel=0.1)
    for x in (-0.7, 0, 0.7):
        cyl(c, "Plug", "Metal", "HazardBlack", 0.09, 0.4, pos=(x, 0.5, 2.1), verts=6)
    cyl(c, "Pulley", "Metal", "Steel", 0.45, 0.2, pos=(1.3, -0.2, 1.0), rot=(0, 90, 0), verts=12)
    cyl(c, "Belt", "Rubber", "Rubber", 0.5, 0.12, pos=(1.32, -0.2, 1.0), rot=(0, 90, 0), verts=12, bevel=0.02)
    for x in (-0.6, 0.0, 0.6):
        cyl(c, "Exhaust", "Rusty", "Rust", 0.14, 0.6, pos=(x, -0.9, 1.4), rot=(90, 0, 0), verts=8)


def register(c):
    box(c, "Base", "Metal", "Mustard", (1.6, 1.4, 0.7), pos=(0, 0, 0.35), bevel=0.12)
    box(c, "Keys", "Metal", "Mustard", (1.6, 0.8, 0.4), pos=(0, -0.25, 0.85), rot=(-25, 0, 0), bevel=0.1)
    for i in range(3):
        for j in range(4):
            box(c, "Key", "Smooth", "Cream", (0.22, 0.18, 0.1), pos=(-0.5 + j * 0.33, -0.45 + i * 0.22, 1.02 + i * 0.1),
                rot=(-25, 0, 0), bevel=0.03)
    box(c, "Display", "Smooth", "HazardBlack", (0.9, 0.2, 0.45), pos=(0, 0.45, 1.25), bevel=0.06)
    box(c, "Digits", "Neon", "NeonGreen", (0.7, 0.05, 0.2), pos=(0, 0.33, 1.27), bevel=0.0)
    box(c, "Drawer", "Metal", "Steel", (1.3, 0.1, 0.35), pos=(0, -0.72, 0.35), bevel=0.04)


def safe(c):
    box(c, "Body", "Plate", "Gunmetal", (1.9, 1.9, 1.9), pos=(0, 0, 0.95), bevel=0.15, segments=2)
    box(c, "Door", "Metal", "Steel", (1.5, 0.1, 1.5), pos=(0, -0.97, 0.95), bevel=0.08)
    cyl(c, "Dial", "Metal", "Mustard", 0.3, 0.15, pos=(0.15, -1.07, 1.15), rot=(90, 0, 0), verts=12)
    box(c, "Handle", "Metal", "Mustard", (0.08, 0.1, 0.55), pos=(-0.45, -1.07, 0.95), bevel=0.03)
    for x in (-0.7, 0.7):
        for y in (-0.7, 0.7):
            box(c, "Foot", "Metal", "HazardBlack", (0.3, 0.3, 0.15), pos=(x, y, 0.07), bevel=0.04)


def jukebox(c):
    box(c, "Body", "Smooth", "Coral", (2.0, 1.4, 2.4), pos=(0, 0, 1.2), bevel=0.2, segments=2)
    cyl(c, "Arch", "Smooth", "Coral", 1.0, 1.4, pos=(0, 0, 2.4), rot=(90, 0, 0), verts=16, bevel=0.15)
    cyl(c, "Glow", "Neon", "NeonPink", 0.8, 1.45, pos=(0, 0, 2.4), rot=(90, 0, 0), verts=16, bevel=0.0)
    box(c, "Window", "Glass", "WindowWarm", (1.3, 0.1, 0.8), pos=(0, -0.72, 1.7), bevel=0.08)
    box(c, "Grille", "Metal", "Mustard", (1.4, 0.1, 0.9), pos=(0, -0.72, 0.6), bevel=0.06)
    for x in (-1.0, 1.0):
        box(c, "Tube", "Neon", "StormCyan", (0.12, 0.12, 2.2), pos=(x, -0.6, 1.2), bevel=0.0)


def storm_core(c):
    sphere(c, "Core", "Neon", "StormCyan", 0.75, pos=(0, 0, 1.2), subdiv=1)
    for i, rot in enumerate([(0, 0, 0), (60, 0, 0), (0, 60, 0)]):
        torus(c, "Ring", "Metal", "Gunmetal", 1.0, 0.09, pos=(0, 0, 1.2), rot=rot)
    cyl(c, "Clamp", "Metal", "SafetyYellow", 0.55, 0.3, pos=(0, 0, 0.15), verts=10)


BUILDERS = [
    ("Can", can), ("Pipe", pipe), ("Toaster", toaster), ("Tv", tv), ("Tire", tire), ("Battery", battery),
    ("Engine", engine), ("Register", register), ("Safe", safe), ("Jukebox", jukebox), ("StormCore", storm_core),
]

if __name__ == "__main__":
    build_set("salvage", BUILDERS)
