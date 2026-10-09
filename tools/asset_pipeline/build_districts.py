"""Commercial districts: supermarket, gas station, warehouse, motel, town square.

Each *Shell matches the gameplay footprint MapBuilder.building() creates for it (width x depth x
wall height, door 8 x 9 centered on the front wall). Front faces Blender -Y; MapBuilder rotates the
shell to the building's door side. Shells are visual only; every building has exactly one
"Signboard" mesh that code labels.

blender -b --python tools/asset_pipeline/build_districts.py
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from building_kit import base_band, door_frame, glazing, parapet, pilasters, roof_deck, rooftop_clutter, sign_board, wall  # noqa: E402
from kit import box, build_set, cyl, jitter, rng, sphere, torus, wedge  # noqa: E402,F401

DOOR = (0.0, 8.0, 0.0, 9.0)


def openings_and_glass(c, axis, offset, length, height, windows, outward, material, swatch, frame="Cream", glass="Glass"):
    """Wall with the door/window openings, then glass in each window opening."""
    wall(c, axis, offset, length, height, windows, material=material, swatch=swatch)
    for center, width, bottom, top in windows:
        if bottom > 0.5:  # not a doorway
            glazing(c, axis, offset, center, bottom, top, width, outward, frame=frame, glass=glass,
                    mullions=max(1, int(width // 5)))


# --------------------------------------------------------------------------- supermarket (70 x 50 x 18)

def supermarket_shell(c):
    W, D, H = 70.0, 50.0, 18.0
    front = [DOOR, (-19, 18, 2.5, 11.5), (19, 18, 2.5, 11.5)]
    openings_and_glass(c, "x", -D / 2, W, H, front, -1, "Brick", "Plaster", glass="Glass")
    side = [(-12, 10, 11, 15), (12, 10, 11, 15)]
    openings_and_glass(c, "y", -W / 2, D, H, side, -1, "Brick", "Plaster")
    openings_and_glass(c, "y", W / 2, D, H, side, 1, "Brick", "Plaster")
    wall(c, "x", D / 2, W, H, [(20, 10, 0.0, 10.0)], material="Brick", swatch="Plaster")  # loading door (closed below)
    box(c, "RollDoor", "Metal", "Steel", (10, 0.4, 10), pos=(20, D / 2 + 0.4, 5), bevel=0.05)
    for i in range(8):
        box(c, "RollRib", "Metal", "Steel", (10, 0.6, 0.2), pos=(20, D / 2 + 0.6, 0.8 + i * 1.2), bevel=0.02)
    door_frame(c, -D / 2)
    base_band(c, W, D, swatch="Stone")
    pilasters(c, W, D, H, swatch="Cream", every=17.5)
    parapet(c, W, D, H, swatch="ContainerGreen", height=2.2, material="Smooth")
    roof_deck(c, W, D, H)
    rooftop_clutter(c, W, D, H + 1, count=4)
    # Green fascia band and the big sign tower over the entrance
    box(c, "Band", "Smooth", "ContainerGreen", (W + 1.4, 1.2, 2.2), pos=(0, -D / 2 - 0.4, 14.2), bevel=0.15)
    box(c, "SignTower", "Smooth", "ContainerGreen", (30, 1.4, 8), pos=(0, -D / 2 - 0.5, H + 3), bevel=0.25)
    sign_board(c, 26, 5, H + 3, -D / 2 - 0.6)
    # Entrance canopy with columns
    box(c, "Canopy", "Metal", "Cream", (16, 6, 0.8), pos=(0, -D / 2 - 3, 10.2), bevel=0.15)
    for sx in (-7, 7):
        cyl(c, "Column", "Smooth", "Cream", 0.45, 10, pos=(sx, -D / 2 - 5.5, 5), verts=10)
    # Posters in the windows tell the story: "STORM SALE"
    for x in (-24, 14):
        box(c, "Poster", "Smooth", "Mustard", (4, 0.1, 3), pos=(x, -D / 2 - 0.25, 7.5), rot=(0, rng.uniform(-6, 6), 0), bevel=0.0)
    box(c, "Cart", "Metal", "Steel", (2.5, 4, 2.5), pos=(30, -D / 2 - 3, 1.6), rot=(0, 0, 20), bevel=0.3)


def aisle_shelf(c):
    """12-stud grocery shelf unit, 2 deep, placed in rows between the supermarket's loot rows."""
    box(c, "Base", "Metal", "Steel", (12, 2, 0.6), pos=(0, 0, 0.3), bevel=0.06)
    box(c, "Back", "Metal", "Steel", (12, 0.3, 6), pos=(0, 0, 3.3), bevel=0.04)
    for z in (1.6, 3.1, 4.6):
        box(c, "Shelf", "Metal", "White", (12, 2, 0.2), pos=(0, 0, z), bevel=0.03)
    for sx in (-6, 6):
        box(c, "End", "Metal", "ContainerGreen", (0.3, 2.1, 6.4), pos=(sx, 0, 3.2), bevel=0.05)
    colors = ["Coral", "Mustard", "Cobalt", "Teal", "Cream", "Mint", "Terracotta"]
    for z in (1.7, 3.2, 4.7):
        x = -5.6
        while x < 5.4:
            wbox = rng.uniform(0.6, 1.1)
            hbox = rng.uniform(0.6, 1.2)
            for side in (-1, 1):
                if rng.random() < 0.82:  # gaps: the shelves have been raided
                    box(c, "Goods", "Smooth", colors[rng.randrange(len(colors))], (wbox, 0.8, hbox),
                        pos=(x + wbox / 2, side * 0.55, z + 0.1 + hbox / 2), bevel=0.05)
            x += wbox + 0.15
    box(c, "Header", "Smooth", "ContainerGreen", (12, 0.4, 1.0), pos=(0, 0, 6.8), bevel=0.08)


def shopping_cart(c):
    box(c, "Basket", "Metal", "Steel", (2.4, 4, 2.0), pos=(0, 0, 2.4), bevel=0.15)
    box(c, "Inside", "Smooth", "Gunmetal", (2.0, 3.6, 1.8), pos=(0, 0, 2.6), bevel=0.1)
    box(c, "Handle", "Plastic", "Coral", (2.6, 0.3, 0.3), pos=(0, 2.35, 3.7), bevel=0.08)
    for sx in (-1.1, 1.1):
        box(c, "HandleArm", "Metal", "Steel", (0.15, 0.6, 0.6), pos=(sx, 2.15, 3.45), rot=(30, 0, 0), bevel=0.03)
    box(c, "Frame", "Metal", "Steel", (2.0, 3.6, 0.2), pos=(0, 0, 0.9), bevel=0.05)
    for sx in (-0.9, 0.9):
        for sy in (-1.6, 1.6):
            cyl(c, "Wheel", "Rubber", "Rubber", 0.3, 0.2, pos=(sx, sy, 0.3), rot=(0, 90, 0), verts=8, bevel=0.0)


# --------------------------------------------------------------------------- gas station (40 x 30 x 14)

def gas_station_shell(c):
    W, D, H = 40.0, 30.0, 14.0
    front = [DOOR, (-12, 10, 2.5, 9.5), (12, 10, 2.5, 9.5)]
    openings_and_glass(c, "x", -D / 2, W, H, front, -1, "Concrete", "White")
    openings_and_glass(c, "y", -W / 2, D, H, [(0, 8, 4, 9)], -1, "Concrete", "White")
    openings_and_glass(c, "y", W / 2, D, H, [(4, 5, 4, 9)], 1, "Concrete", "White")
    wall(c, "x", D / 2, W, H, [], material="Concrete", swatch="White")
    door_frame(c, -D / 2, swatch="Coral")
    base_band(c, W, D, swatch="Gunmetal")
    for z in (10.6, 12.2):
        box(c, "Stripe", "Smooth", "Coral" if z < 11 else "Mustard", (W + 1.4, 1.2, 1.2), pos=(0, -D / 2 - 0.4, z), bevel=0.12)
    parapet(c, W, D, H, swatch="Coral", height=1.8, material="Smooth")
    roof_deck(c, W, D, H)
    rooftop_clutter(c, W, D, H + 1, count=2)
    sign_board(c, 20, 3.4, H + 2.6, -D / 2 - 0.6, trim="Coral")
    # Ice chest, newspaper box, propane cage by the door
    box(c, "IceChest", "Smooth", "Cobalt", (4, 2.2, 3.2), pos=(-7, -D / 2 - 1.6, 1.6), bevel=0.2)
    box(c, "Propane", "Metal", "Steel", (3, 2.2, 4), pos=(9, -D / 2 - 1.6, 2), bevel=0.1)
    for i in range(3):
        cyl(c, "Tank", "Metal", "White", 0.5, 1.6, pos=(8 + i, -D / 2 - 1.6, 1.0), verts=8)


def fuel_canopy(c):
    """36 x 20 canopy, top at 12.5, columns at x = ±15 (matches MapBuilder's shelter part)."""
    box(c, "Roof", "Metal", "White", (36, 20, 1.2), pos=(0, 0, 11.9), bevel=0.2)
    box(c, "Fascia", "Smooth", "Coral", (36.6, 20.6, 1.6), pos=(0, 0, 11.0), bevel=0.2)
    box(c, "Underside", "Neon", "White", (30, 14, 0.2), pos=(0, 0, 10.15), bevel=0.0)
    for sx in (-15, 15):
        box(c, "Column", "Smooth", "White", (1.4, 1.4, 10.2), pos=(sx, 0, 5.1), bevel=0.2)
        box(c, "ColumnBase", "Concrete", "Gunmetal", (2.6, 2.6, 0.8), pos=(sx, 0, 0.4), bevel=0.15)
        box(c, "Island", "Concrete", "Concrete", (4, 9, 0.6), pos=(sx + 7, 0, 0.3), bevel=0.15)


def fuel_pump(c):
    box(c, "Body", "Smooth", "White", (2.2, 1.6, 4.6), pos=(0, 0, 2.3), bevel=0.25)
    box(c, "Top", "Smooth", "Coral", (2.4, 1.8, 0.9), pos=(0, 0, 4.9), bevel=0.2)
    box(c, "Screen", "Neon", "NeonGreen", (1.2, 0.1, 0.6), pos=(0, -0.85, 3.8), bevel=0.0)
    box(c, "Panel", "Smooth", "HazardBlack", (1.6, 0.1, 1.4), pos=(0, -0.85, 2.6), bevel=0.05)
    for sx in (-1.15, 1.15):
        box(c, "Holster", "Metal", "Gunmetal", (0.3, 0.6, 0.9), pos=(sx, 0, 2.8), bevel=0.06)
        cyl(c, "Hose", "Rubber", "Rubber", 0.1, 2.6, pos=(sx * 1.08, 0.2, 1.7), rot=(15, 0, 0), verts=6, bevel=0.0)


def price_sign(c):
    box(c, "Pole", "Metal", "Gunmetal", (1.2, 1.2, 16), pos=(0, 0, 8), bevel=0.15)
    box(c, "Panel", "Smooth", "Coral", (8, 1.2, 7), pos=(0, 0, 19), bevel=0.3)
    box(c, "Signboard", "Smooth", "Signboard", (6.6, 1.4, 4.6), pos=(0, 0, 18.6), bevel=0.15)
    box(c, "Cap", "Smooth", "Mustard", (8.4, 1.4, 0.8), pos=(0, 0, 22.8), bevel=0.15)


# --------------------------------------------------------------------------- warehouse (70 x 60 x 22)

def warehouse_shell(c):
    W, D, H = 70.0, 60.0, 22.0
    front = [DOOR]
    wall(c, "x", -D / 2, W, H, front, material="Metal", swatch="Steel")
    for side_x, out in ((-W / 2, -1), (W / 2, 1)):
        openings_and_glass(c, "y", side_x, D, H, [(-18, 10, 15, 19), (0, 10, 15, 19), (18, 10, 15, 19)], out, "Metal", "Steel", frame="Gunmetal")
    wall(c, "x", D / 2, W, H, [], material="Metal", swatch="Steel")
    # Corrugation ribs on the long walls
    for i in range(int(W // 2.5)):
        x = -W / 2 + 1.25 + i * 2.5
        if abs(x) > 5:
            box(c, "Rib", "Metal", "Steel", (0.4, 0.6, H - 4.2), pos=(x, -D / 2 - 0.5, 4.2 + (H - 4.2) / 2), bevel=0.04)
        box(c, "Rib", "Metal", "Steel", (0.4, 0.6, H - 4.2), pos=(x, D / 2 + 0.5, 4.2 + (H - 4.2) / 2), bevel=0.04)
    for s in (-1, 1):
        box(c, "Plinth", "Concrete", "Concrete", (W + 1.2, 1.6, 4.2), pos=(0, s * D / 2, 2.1), bevel=0.15)
        box(c, "Plinth", "Concrete", "Concrete", (1.6, D + 1.2, 4.2), pos=(s * W / 2, 0, 2.1), bevel=0.15)
    # Two closed roll-up bays either side of the personnel door, with hazard-striped bumpers
    for x in (-22, 22):
        box(c, "BayDoor", "Metal", "ContainerBlue", (14, 0.5, 14), pos=(x, -D / 2 - 0.6, 7.2), bevel=0.08)
        for i in range(12):
            box(c, "BayRib", "Metal", "ContainerBlue", (14, 0.7, 0.2), pos=(x, -D / 2 - 0.8, 0.8 + i * 1.15), bevel=0.02)
        box(c, "BayFrame", "Smooth", "SafetyYellow", (15.4, 0.8, 0.8), pos=(x, -D / 2 - 0.7, 14.6), bevel=0.1)
        for sx in (-7.3, 7.3):
            box(c, "Bumper", "Rubber", "HazardBlack", (0.8, 1.2, 2), pos=(x + sx, -D / 2 - 1.0, 2.6), bevel=0.15)
    door_frame(c, -D / 2, swatch="SafetyYellow")
    # Sawtooth roof teeth above the deck (silhouette)
    roof_deck(c, W, D, H, swatch="Gunmetal")
    for i in range(5):
        y = -D / 2 + 6 + i * 12
        box(c, "Tooth", "Metal", "Gunmetal", (W, 0.8, 7.5), pos=(0, y + 4.2, H + 3.7), rot=(-55, 0, 0), bevel=0.1)
        box(c, "ToothGlass", "Glass", "Glass", (W - 2, 0.4, 3.6), pos=(0, y + 8.3, H + 2.6), bevel=0.0)
    parapet(c, W, D, H, swatch="Gunmetal", height=1.2, material="Metal")
    sign_board(c, 30, 4, 17.5, -D / 2 - 0.6, trim="SafetyYellow")
    # Painted bay numbers / hazard band
    for i in range(10):
        box(c, "Hazard", "Smooth", "SafetyYellow" if i % 2 else "HazardBlack", (W / 10, 1.0, 0.8),
            pos=(-W / 2 + W / 20 + i * W / 10, -D / 2 - 0.55, 4.6), bevel=0.0)


def pallet_rack(c):
    """24-stud pallet rack, 2 deep, placed between the warehouse's loot rows."""
    for x in (-12, -4, 4, 12):
        box(c, "Upright", "Metal", "Cobalt", (0.4, 2, 9), pos=(x, 0, 4.5), bevel=0.05)
    for z in (0.4, 3.4, 6.4):
        for sy in (-0.85, 0.85):
            box(c, "Beam", "Metal", "SafetyYellow", (24, 0.3, 0.4), pos=(0, sy, z), bevel=0.04)
    swatches = ["Bark", "RoofBrown", "Plaster", "ContainerBlue", "Coral"]
    for z in (0.6, 3.6, 6.6):
        for x in (-8, 0, 8):
            if rng.random() < 0.75:
                box(c, "Pallet", "Planks", "Bark", (6.8, 1.8, 0.4), pos=(x, 0, z + 0.2), bevel=0.04)
                box(c, "Load", "Fabric" if rng.random() < 0.5 else "Planks", swatches[rng.randrange(len(swatches))],
                    (rng.uniform(4.5, 6.4), 1.6, rng.uniform(1.4, 2.4)), pos=(x, 0, z + 1.6), bevel=0.2)


def forklift(c):
    box(c, "Body", "Metal", "SafetyYellow", (4, 6, 2.6), pos=(0, 1, 1.9), bevel=0.35)
    box(c, "Counterweight", "Metal", "HazardBlack", (4.2, 1.6, 2.4), pos=(0, 4.1, 1.8), bevel=0.3)
    box(c, "Seat", "Fabric", "HazardBlack", (1.6, 1.4, 1.2), pos=(0, 1.8, 3.8), bevel=0.25)
    for sx in (-1.8, 1.8):
        box(c, "Cage", "Metal", "HazardBlack", (0.25, 0.25, 4.5), pos=(sx, -0.4, 5.3), bevel=0.04)
        box(c, "Cage", "Metal", "HazardBlack", (0.25, 0.25, 4.5), pos=(sx, 3.2, 5.3), bevel=0.04)
    box(c, "CageTop", "Metal", "HazardBlack", (3.9, 4, 0.3), pos=(0, 1.4, 7.6), bevel=0.05)
    for sx in (-0.9, 0.9):
        box(c, "Mast", "Metal", "Gunmetal", (0.4, 0.4, 7), pos=(sx, -2.2, 3.5), bevel=0.05)
        box(c, "Fork", "Metal", "Gunmetal", (0.4, 3.6, 0.25), pos=(sx, -4.0, 0.6), bevel=0.04)
    for sx in (-1.9, 1.9):
        for sy in (-1.0, 3.4):
            cyl(c, "Wheel", "Rubber", "Rubber", 0.9, 0.8, pos=(sx, sy, 0.9), rot=(0, 90, 0), verts=12, bevel=0.15)


# --------------------------------------------------------------------------- motel (110 x 30 x 14)

def motel_shell(c):
    W, D, H = 110.0, 30.0, 14.0
    rooms = [-48, -36, -24, -12, 12, 24, 36, 48]
    front = [DOOR] + [(x + 3.2, 3.6, 3.5, 7.5) for x in rooms]
    openings_and_glass(c, "x", -D / 2, W, H, front, -1, "Brick", "Plaster", frame="Cream", glass="WindowWarm")
    back = [(x, 3.6, 4, 8) for x in rooms]
    openings_and_glass(c, "x", D / 2, W, H, back, 1, "Brick", "Plaster", frame="Cream", glass="Glass")
    wall(c, "y", -W / 2, D, H, [], material="Brick", swatch="Plaster")
    wall(c, "y", W / 2, D, H, [], material="Brick", swatch="Plaster")
    # Room doors (closed, on the facade) with number plates and AC units under the windows
    for i, x in enumerate(rooms):
        box(c, "RoomDoor", "Planks", "Teal" if i % 2 else "Coral", (3.4, 0.4, 7.8), pos=(x - 2.4, -D / 2 - 0.6, 3.9), bevel=0.1)
        box(c, "Knob", "Metal", "Mustard", (0.3, 0.3, 0.3), pos=(x - 1.1, -D / 2 - 0.9, 3.9), bevel=0.05)
        box(c, "Plate", "Smooth", "Cream", (0.9, 0.2, 0.6), pos=(x - 2.4, -D / 2 - 0.85, 8.4), bevel=0.04)
        box(c, "AC", "Metal", "Steel", (2.6, 1.6, 1.6), pos=(x + 3.2, -D / 2 - 1.0, 2.2), bevel=0.15)
    door_frame(c, -D / 2, swatch="Cream")
    base_band(c, W, D, swatch="Stone")
    # Two-tone band, the walkway awning (code keeps an invisible shelter part under it), and posts
    box(c, "Band", "Smooth", "Cream", (W + 1.2, 1.0, 1.0), pos=(0, -D / 2 - 0.3, 9.6), bevel=0.1)
    box(c, "Awning", "Metal", "RoofSlate", (W, 6.4, 0.6), pos=(0, -D / 2 - 3, 10.6), rot=(-4, 0, 0), bevel=0.12)
    box(c, "AwningEdge", "Smooth", "Cream", (W, 0.5, 0.8), pos=(0, -D / 2 - 6.1, 10.3), bevel=0.08)
    for x in range(-53, 54, 15):
        if abs(x) > 6:
            box(c, "Post", "Smooth", "Cream", (0.6, 0.6, 10), pos=(x, -D / 2 - 5.6, 5), bevel=0.1)
    parapet(c, W, D, H, swatch="RoofSlate", height=1.4, material="Smooth")
    roof_deck(c, W, D, H)
    rooftop_clutter(c, W, D, H + 1, count=5)
    sign_board(c, 30, 3.0, 12.4, -D / 2 - 0.4, trim="NeonPink")
    # Walkway floor
    box(c, "Walkway", "Concrete", "Concrete", (W, 6, 0.4), pos=(0, -D / 2 - 3, 0.2), bevel=0.05)


def motel_sign(c):
    box(c, "Pole", "Metal", "Gunmetal", (1.2, 1.2, 24), pos=(0, 0, 12), bevel=0.15)
    box(c, "Panel", "Smooth", "RoofSlate", (12, 1.2, 6.5), pos=(0, 0, 26), bevel=0.4)
    box(c, "Signboard", "Smooth", "Signboard", (10.6, 1.4, 5.0), pos=(0, 0, 26), bevel=0.2)
    box(c, "Glow", "Neon", "NeonPink", (12.6, 0.6, 7.1), pos=(0, 0, 26), bevel=0.3)
    # Arrow pointing at the office, with a star on top
    box(c, "Arrow", "Neon", "Mustard", (6, 0.8, 1.2), pos=(-5, 0, 21.4), rot=(0, 20, 0), bevel=0.2)
    sphere(c, "Star", "Neon", "Mustard", 1.2, pos=(0, 0, 30.6), subdiv=1)


def vending_machine(c):
    box(c, "Body", "Smooth", "Coral", (3, 2.4, 6), pos=(0, 0, 3), bevel=0.25)
    box(c, "Window", "Glass", "WindowWarm", (1.8, 0.2, 3.6), pos=(-0.4, -1.2, 3.6), bevel=0.05)
    box(c, "Panel", "Smooth", "HazardBlack", (0.6, 0.2, 2.4), pos=(1.0, -1.2, 3.8), bevel=0.05)
    box(c, "Slot", "Smooth", "HazardBlack", (1.8, 0.3, 0.6), pos=(-0.4, -1.2, 0.9), bevel=0.05)


def ice_machine(c):
    box(c, "Body", "Metal", "Steel", (3.4, 2.4, 5), pos=(0, 0, 2.5), bevel=0.2)
    box(c, "Label", "Smooth", "Cobalt", (2.8, 0.15, 1.4), pos=(0, -1.2, 3.8), bevel=0.05)
    box(c, "Door", "Smooth", "White", (2.6, 0.2, 1.6), pos=(0, -1.2, 1.6), bevel=0.06)


# --------------------------------------------------------------------------- town square

def fountain(c):
    """Three-tier fountain, 14 studs across (matches the gameplay cylinder MapBuilder keeps)."""
    cyl(c, "Basin", "Concrete", "Stone", 7, 2.2, pos=(0, 0, 1.1), verts=20, bevel=0.3)
    cyl(c, "Water", "Glass", "Glass", 6.2, 0.4, pos=(0, 0, 2.0), verts=20, bevel=0.0)
    cyl(c, "Rim", "Concrete", "Cream", 7.2, 0.5, pos=(0, 0, 2.4), verts=20, bevel=0.15)
    cyl(c, "Column", "Concrete", "Stone", 1.2, 4.5, pos=(0, 0, 4.4), verts=12, bevel=0.15)
    cyl(c, "Bowl", "Concrete", "Cream", 3.4, 0.9, pos=(0, 0, 6.6), verts=16, radius_top=4.0, bevel=0.15)
    cyl(c, "Water2", "Glass", "Glass", 3.4, 0.3, pos=(0, 0, 7.0), verts=16, bevel=0.0)
    cyl(c, "Column2", "Concrete", "Stone", 0.7, 2.6, pos=(0, 0, 8.3), verts=10, bevel=0.1)
    cyl(c, "Bowl2", "Concrete", "Cream", 1.6, 0.6, pos=(0, 0, 9.7), verts=12, radius_top=2.0, bevel=0.1)
    sphere(c, "Finial", "Metal", "Mustard", 0.7, pos=(0, 0, 10.7), subdiv=1)
    for i in range(8):
        a = i / 8 * math.tau
        box(c, "Lion", "Concrete", "Stone", (1.2, 1.2, 1.2), pos=(math.cos(a) * 6.9, math.sin(a) * 6.9, 2.9), rot=(0, 0, math.degrees(a)), bevel=0.2)


def siren_tower(c):
    box(c, "Base", "Concrete", "Concrete", (4, 4, 1.2), pos=(0, 0, 0.6), bevel=0.2)
    cyl(c, "Pole", "Metal", "Steel", 0.7, 30, pos=(0, 0, 16.2), verts=10)
    for z in (8, 16, 24):
        box(c, "Band", "Smooth", "SafetyYellow", (1.7, 1.7, 0.8), pos=(0, 0, z), bevel=0.1)
    box(c, "Housing", "Metal", "Coral", (3, 3, 3), pos=(0, 0, 32.5), bevel=0.4)
    for sx in (-1, 1):
        cyl(c, "Horn", "Metal", "Steel", 1.3, 3.0, pos=(sx * 2.6, 0, 32.5), rot=(0, 90, 0), verts=12, radius_top=0.7, bevel=0.1)
    box(c, "Ladder", "Metal", "SafetyYellow", (0.9, 0.4, 28), pos=(0, -0.9, 15), bevel=0.05)
    box(c, "Box", "Metal", "Gunmetal", (1.6, 1.0, 2.4), pos=(0, 0.9, 4), bevel=0.15)
    cyl(c, "Beacon", "Neon", "Coral", 0.5, 0.6, pos=(0, 0, 34.4), verts=10)


def statue(c):
    """Memorial: a salvager holding a Storm Core aloft, on a plinth."""
    box(c, "Plinth", "Concrete", "Stone", (5, 5, 3), pos=(0, 0, 1.5), bevel=0.3)
    box(c, "Plaque", "Metal", "Mustard", (3, 0.2, 1.4), pos=(0, -2.55, 1.8), bevel=0.05)
    bronze = "Teal"
    box(c, "Legs", "Metal", bronze, (1.6, 1.0, 2.6), pos=(0, 0, 4.3), bevel=0.2)
    box(c, "Body", "Metal", bronze, (2.0, 1.2, 2.6), pos=(0, 0, 6.8), bevel=0.3)
    sphere(c, "Head", "Metal", bronze, 0.8, pos=(0, 0, 8.7), subdiv=1)
    box(c, "Arm", "Metal", bronze, (0.6, 0.6, 2.6), pos=(1.1, 0, 8.6), rot=(0, -20, 0), bevel=0.15)
    box(c, "Bag", "Metal", bronze, (1.4, 1.0, 1.6), pos=(-1.4, 0.3, 6.4), bevel=0.3)
    sphere(c, "Core", "Neon", "StormCyan", 0.8, pos=(1.6, 0, 10.2), subdiv=1)


def dumpster(c):
    box(c, "Bin", "Metal", "ContainerGreen", (7, 4, 4), pos=(0, 0, 2.2), bevel=0.25)
    for sy in (-1, 1):
        box(c, "Lid", "Plastic", "HazardBlack", (3.4, 4.2, 0.3), pos=(sy * 1.75, 0, 4.4), rot=(0, 0, 0), bevel=0.08)
    box(c, "Open", "Plastic", "HazardBlack", (3.4, 0.3, 3.0), pos=(1.75, 2.2, 5.6), rot=(-15, 0, 0), bevel=0.08)
    box(c, "Trash", "Fabric", "HazardBlack", (2.4, 2, 1.0), pos=(1.6, 0.2, 4.6), bevel=0.4)
    for sx in (-3, 3):
        for sy in (-1.6, 1.6):
            cyl(c, "Wheel", "Rubber", "Rubber", 0.3, 0.3, pos=(sx, sy, 0.3), rot=(0, 90, 0), verts=8, bevel=0.0)


BUILDERS = [
    ("SupermarketShell", supermarket_shell), ("AisleShelf", aisle_shelf), ("ShoppingCart", shopping_cart),
    ("GasStationShell", gas_station_shell), ("FuelCanopy", fuel_canopy), ("FuelPump", fuel_pump), ("PriceSign", price_sign),
    ("WarehouseShell", warehouse_shell), ("PalletRack", pallet_rack), ("Forklift", forklift),
    ("MotelShell", motel_shell), ("MotelSign", motel_sign), ("VendingMachine", vending_machine), ("IceMachine", ice_machine),
    ("Fountain", fountain), ("SirenTower", siren_tower), ("Statue", statue), ("Dumpster", dumpster),
]

if __name__ == "__main__":
    build_set("districts", BUILDERS)
