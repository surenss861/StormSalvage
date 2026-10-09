"""Storm Salvage V2: Blender environment kits for five districts.

Copy next to tools/asset_pipeline/kit.py in the existing repo. Run using Blender:
  blender -b --python tools/asset_pipeline/build_remaining_districts.py
  blender -b --python tools/asset_pipeline/build_remaining_districts.py -- supermarket

Uses the canonical kit.py palette, scale, naming, FBX export, previews, and .blend
sources. Generated meshes are VISUAL ONLY. Existing Luau collision/shelter
geometry remains authoritative until the Studio placement QA is complete.

Front of shells is Blender -Y -> Roblox -Z. Model pivot is ground center.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from kit import box, build_set, cyl, gable, sphere, torus, wedge  # noqa: E402


def b(c, name, mat, swatch, size, pos=(0, 0, 0), rot=(0, 0, 0), bevel=0.08):
    return box(c, name, mat, swatch, size, pos=pos, rot=rot, bevel=bevel)


def wall(c, name, w, h, d, color, door=8, side="front"):
    """Open shell with a gameplay-aligned central doorway (do not fill it)."""
    for x in (-1, 1):
        side_w = (w - door) / 2
        b(c, name, "Brick", color, (side_w, 0.7, h),
          (x * (door / 2 + side_w / 2), -d / 2, h / 2))
    b(c, "DoorHeader", "Brick", color, (door, 0.7, h - 9),
      (0, -d / 2, 9 + (h - 9) / 2))
    b(c, "RearWall", "Brick", color, (w, 0.8, h), (0, d / 2, h / 2))
    for x in (-1, 1):
        b(c, "SideWall", "Brick", color, (0.8, d, h), (x * w / 2, 0, h / 2))
    for x in (-1, 1):
        b(c, "EntrancePillar", "Smooth", "Cream", (0.9, 1.1, 10),
          (x * (door / 2 + 0.5), -d / 2 - 0.35, 5))
    for x in (-1, 1):
        b(c, "BaseSkirt", "Concrete", "Concrete", (0.65, d + 0.2, 0.65),
          (x * w / 2, 0, 0.35))


def windows(c, w, d, h, count, accent="Glass"):
    for i in range(count):
        x = -w / 2 + (i + 1) * w / (count + 1)
        if abs(x) < 5:
            continue
        b(c, "Window", "Glass", accent, (w / (count + 1) - 1.2, 0.22, 5),
          (x, -d / 2 - 0.5, h * 0.57), bevel=0)
        b(c, "WindowSill", "Smooth", "Cream", (w / (count + 1), 0.8, 0.4),
          (x, -d / 2 - 0.75, h * 0.57 - 2.8))


def roof(c, w, d, height, color="RoofSlate"):
    b(c, "RoofEdge", "Metal", color, (w + 2, d + 2, 0.7), (0, 0, height + 0.35))
    for x in (-w / 2, w / 2):
        b(c, "Parapet", "Concrete", "Cream", (1.3, d + 2, 2.2),
          (x, 0, height + 1.1))


def bolts(c, xs, z, y=-1):
    for x in xs:
        cyl(c, "Bolt", "Metal", "Steel", 0.11, 0.12, (x, y, z), rot=(90, 0, 0), verts=8)


# ------------------------------- SUPERMARKET (70 x 50 x 18)
def supermarket_shell(c):
    wall(c, "Brickwall", 70, 18, 50, "Plaster")
    roof(c, 70, 50, 18, "RoofSlate")
    windows(c, 70, 50, 18, 8, "Glass")
    b(c, "SignBand", "Metal", "ContainerGreen", (50, 1.3, 5), (0, -25.7, 15.6))
    b(c, "SignBacklit", "Neon", "WindowWarm", (34, 0.2, 1.0), (0, -26.45, 16.2))
    for x in (-26, 26):
        b(c, "OverhangSupport", "Metal", "ContainerGreen", (1, 4, 0.5), (x, -26.5, 15.5))
    b(c, "Awning", "Metal", "ContainerGreen", (46, 5.0, 0.5), (0, -27, 12.4))
    for x in (-30, 30):
        b(c, "Downspout", "Metal", "Steel", (0.8, 1.0, 17), (x, 24.8, 8.5))


def supermarket_sign(c):
    b(c, "Pole", "Metal", "Gunmetal", (2, 2, 28), (0, 0, 14))
    b(c, "TopPanel", "Metal", "ContainerGreen", (12, 1.3, 8), (0, 0, 27))
    b(c, "LogoStripe", "Neon", "WindowWarm", (10, 1.4, 1), (0, -0.8, 29.5))
    b(c, "Prices", "Smooth", "Cream", (10, 1.0, 2.5), (0, -0.8, 25))
    bolts(c, (-4.7, 4.7), 29.5)


def checkout(c):
    b(c, "Counter", "Smooth", "Cobalt", (8, 3.6, 3.2), (0, 0, 1.6))
    b(c, "Belt", "Rubber", "Rubber", (4.8, 3.0, 0.2), (-1.2, 0, 3.3))
    b(c, "RegisterHousing", "Smooth", "Gunmetal", (1.9, 1.4, 1.8), (2.7, 0.2, 4.0))
    b(c, "RegisterScreen", "Glass", "StormCyan", (1.4, 0.25, 0.8), (2.7, -0.62, 4.45))
    b(c, "Scanner", "Metal", "Steel", (1.3, 1.8, 0.2), (0.1, 0, 3.4))
    for i in range(3):
        b(c, "Cabinet", "Smooth", "Cream", (2.2, 0.15, 1.7), (-2.6 + i*2.4, -1.9, 1.1))


def market_shelf(c):
    for x in (-4.8, 4.8):
        b(c, "Rail", "Metal", "Steel", (0.25, 2.2, 8), (x, 0, 4))
    for z in (0.7, 2.7, 4.7, 6.7):
        b(c, "Shelf", "Metal", "White", (10, 2.4, 0.23), (0, 0, z))
        for j in range(7):
            color = ("Coral", "Mint", "Mustard", "Cobalt")[(j+int(z))%4]
            b(c, "Product", "Smooth", color, (0.78, 0.95, 1.5), (-4.0+j*1.25, 0, z+0.9))
    b(c, "Header", "Smooth", "ContainerGreen", (10.6, 2.5, 0.7), (0, 0, 8.0))


def freezer(c):
    b(c, "Cabinet", "Metal", "White", (12, 3.5, 8), (0, 0, 4))
    b(c, "Interior", "Smooth", "Cobalt", (11.6, 0.4, 6.5), (0, -1.8, 4.1))
    for x in (-3.5, 0, 3.5):
        b(c, "DoorGlass", "Glass", "Glass", (3.1, 0.18, 6), (x, -2.1, 4.0))
        b(c, "Handle", "Metal", "Steel", (0.17, 0.4, 2.8), (x+1.3, -2.42, 4))
    b(c, "TopGlow", "Neon", "WindowWarm", (11, 0.4, 0.4), (0, -2.0, 7.3))


def produce_stand(c):
    b(c, "Base", "Planks", "Bark", (8, 5, 3), (0, 0, 1.5))
    b(c, "CrateRim", "Wood", "Mustard", (8.6, 5.6, 0.7), (0, 0, 3.2))
    for ix in range(6):
        for iy in range(3):
            sphere(c, "Produce", "Smooth", ("Coral", "Leaf", "Mustard")[iy], 0.45,
                   (-2.9+ix*1.2, -1.4+iy*1.3, 3.65), subdiv=1)


def stock_shelf(c):
    for x in (-5, 5):
        b(c, "Post", "Metal", "Gunmetal", (0.6, 3.4, 11), (x, 0, 5.5))
    for z in (1, 4, 7, 10):
        b(c, "Platform", "Metal", "Steel", (11, 3.4, 0.4), (0, 0, z))
        for x in (-3.4, 0, 3.4):
            b(c, "StockBox", "Planks", "Plaster", (2.4, 2.5, 2.3), (x, 0, z+1.4))


def food_pallet(c):
    for x in (-2.5, 0, 2.5):
        b(c, "Pallet", "Planks", "Bark", (1.8, 6, 0.5), (x, 0, 0.3))
    for z in (1.9, 4.6):
        for x in (-1.5, 1.5):
            b(c, "BulkBox", "Smooth", "Mustard", (2.7, 4.8, 2.5), (x, 0, z+0.3))


def cart_corral(c):
    for x in (-4, 4):
        for y in (-7, 7):
            b(c, "RailPost", "Metal", "Steel", (0.4, 0.4, 5), (x, y, 2.5))
        b(c, "RailTop", "Metal", "Steel", (0.4, 15, 0.3), (x, 0, 4.7))
    b(c, "Header", "Smooth", "ContainerGreen", (8.7, 1.3, 1.4), (0, 0, 5.7))


def shopping_cart(c):
    b(c, "Basket", "Metal", "Steel", (4.5, 3.4, 2.2), (0, 0, 4.1))
    b(c, "BasketHole", "Smooth", "Cobalt", (3.8, 2.7, 0.3), (0, 0, 5.15))
    for x in (-1.6, 1.6):
        for y in (-1.2, 1.2):
            cyl(c, "Wheel", "Rubber", "Rubber", 0.5, 0.4, (x, y, 0.6), rot=(90, 0, 0))
            b(c, "Leg", "Metal", "Gunmetal", (0.25, 0.25, 3), (x, y, 2.0))
    b(c, "Handle", "Smooth", "Coral", (4.8, 0.35, 0.4), (0, 2.0, 5.2))


# ------------------------------- GAS STATION (40 x 30 x 14)
def gas_shell(c):
    wall(c, "Wall", 40, 14, 30, "White")
    roof(c, 40, 30, 14, "RoofRed")
    windows(c, 40, 30, 14, 5)
    b(c, "Stripe", "Metal", "Coral", (42, 1.5, 1.8), (0, -15.6, 11))
    for x in (-19.5, 19.5):
        b(c, "CornerStripe", "Metal", "Coral", (1.2, 30, 1.8), (x, 0, 11))


def gas_canopy(c):
    b(c, "CanopyRoof", "Metal", "Coral", (36, 20, 1.3), (0, 0, 12))
    b(c, "Trim", "Neon", "WindowWarm", (36, 20, 0.2), (0, 0, 11.3))
    for x in (-14, 14):
        b(c, "Support", "Metal", "White", (1.5, 1.5, 11.5), (x, 0, 5.75))
        b(c, "Bollard", "Metal", "SafetyYellow", (2.2, 2.2, 1.2), (x, 0, 0.6))


def fuel_pump(c):
    b(c, "Pad", "Concrete", "Concrete", (3.5, 2.5, 0.5), (0, 0, 0.25))
    b(c, "Pump", "Metal", "Coral", (2.2, 1.9, 5.2), (0, 0, 3.1))
    b(c, "Face", "Smooth", "White", (1.8, 0.25, 3), (0, -1.08, 3.6))
    b(c, "Display", "Glass", "StormCyan", (1.45, 0.15, 0.8), (0, -1.3, 4.55))
    for x in (-0.65, 0.65):
        b(c, "Nozzle", "Rubber", "Rubber", (0.4, 0.45, 1.5), (x, -1.15, 3.0))
    b(c, "Cap", "Smooth", "Cream", (2.5, 2.3, 0.4), (0, 0, 5.95))


def gas_counter(c):
    b(c, "Desk", "Planks", "Bark", (10, 2.5, 3.6), (0, 0, 1.8))
    b(c, "Top", "Smooth", "Cream", (10.5, 2.9, 0.4), (0, 0, 3.8))
    b(c, "Till", "Metal", "Gunmetal", (2, 1.5, 1.8), (-2.9, 0.1, 4.8))
    for x in (1, 3):
        b(c, "ImpulseGoods", "Smooth", "Mustard", (1.3, 1.4, 1.3), (x, 0, 4.7))


def garage_lift(c):
    for x in (-5, 5):
        b(c, "Column", "Metal", "Cobalt", (1.5, 2, 13), (x, 0, 6.5))
        b(c, "Foot", "Plate", "Gunmetal", (4, 4, 0.8), (x, 0, 0.4))
    b(c, "CrossBrace", "Metal", "SafetyYellow", (12, 1.5, 1.5), (0, 0, 11.5))
    for x in (-3.5, 3.5):
        b(c, "Arm", "Metal", "Gunmetal", (4, 2.5, 0.6), (x, -0.5, 3.0))


def tool_cabinet(c):
    b(c, "Body", "Metal", "Coral", (6, 2.5, 7), (0, 0, 3.5))
    for z in (1, 2.2, 3.4, 4.6):
        b(c, "Drawer", "Metal", "RustDark", (5.4, 0.15, 0.9), (0, -1.32, z))
        b(c, "Handle", "Metal", "Steel", (1.0, 0.25, 0.15), (0, -1.48, z))
    for x in (-2.3, 2.3):
        b(c, "Cap", "Smooth", "Gunmetal", (0.4, 2.8, 0.3), (x, 0, 7.0))


def oil_rack(c):
    for x in (-3.5, 3.5):
        b(c, "Frame", "Metal", "Gunmetal", (0.3, 2.4, 7), (x, 0, 3.5))
    for z in (1, 3.2, 5.4):
        b(c, "Shelf", "Metal", "Steel", (7.6, 2.6, 0.35), (0, 0, z))
        for x in (-2.2, 0, 2.2):
            cyl(c, "OilJug", "Plastic", "Coral", 0.65, 1.5, (x, 0, z+0.95), verts=8)


def gas_price_sign(c):
    b(c, "Pole", "Metal", "Gunmetal", (1.5, 1.5, 19), (0, 0, 9.5))
    b(c, "Panel", "Smooth", "Coral", (9, 1.4, 6), (0, 0, 20.5))
    b(c, "PriceSlots", "Neon", "WindowWarm", (7.3, 0.3, 3.1), (0, -0.9, 19.3))
    b(c, "TopBadge", "Smooth", "White", (9.5, 1.5, 1.5), (0, 0, 24.2))


def extinguisher(c):
    cyl(c, "Tank", "Metal", "Coral", 0.75, 3.5, (0, 0, 2.0), verts=12)
    cyl(c, "Neck", "Metal", "Steel", 0.25, 0.9, (0, 0, 4.15), verts=10)
    b(c, "Handle", "Metal", "HazardBlack", (1.2, 0.3, 0.25), (0.3, 0, 4.7))
    b(c, "Label", "Smooth", "White", (1.2, 0.13, 1.1), (0, -0.72, 2.5))


# ------------------------------- WAREHOUSE (70 x 60 x 22)
def warehouse_shell(c):
    wall(c, "Wall", 70, 22, 60, "Stone")
    roof(c, 70, 60, 22, "RoofSlate")
    for x in (-25, -10, 10, 25):
        b(c, "RoofTooth", "Metal", "Gunmetal", (13, 60, 1.1), (x, 0, 24))
        b(c, "Skylight", "Glass", "Glass", (5, 36, 0.25), (x, 0, 24.8))
    b(c, "DoorFrame", "Metal", "SafetyYellow", (12, 1.0, 0.7), (0, -30.7, 9.6))
    for x in (-1, 1):
        b(c, "PaintStripe", "Metal", "SafetyYellow", (0.6, 60, 3), (x*35.2, 0, 11))


def loading_dock(c):
    b(c, "Ramp", "Concrete", "Concrete", (24, 12, 3), (0, 0, 1.5))
    for x in (-12, 12):
        b(c, "DockBumper", "Rubber", "Rubber", (1.0, 2.0, 3.5), (x, -6, 1.75))
    b(c, "Guard", "Metal", "SafetyYellow", (24.5, 0.4, 1.0), (0, 6.0, 3.6))


def warehouse_rack(c):
    for x in (-6, 6):
        for y in (-2.5, 2.5):
            b(c, "Upright", "Metal", "Cobalt", (0.45, 0.45, 16), (x, y, 8))
    for z in (2, 7, 12):
        for y in (-2.4, 2.4):
            b(c, "Beam", "Metal", "SafetyYellow", (12.5, 0.5, 0.5), (0, y, z))
        for x in (-4, 0, 4):
            b(c, "Crate", "Planks", "Plaster", (3.1, 3.9, 3.0), (x, 0, z+1.7))


def cargo_stack(c):
    for i in range(3):
        for x in (-3.0, 3.0):
            b(c, "Cargo", "Planks", ("Plaster", "Bark", "Mustard")[i],
              (5.6, 5, 3), (x, 0, i*3.2+1.5))
            for y in (-2.2, 2.2):
                b(c, "Strap", "Metal", "Gunmetal", (0.3, 0.15, 3.0), (x, y, i*3.2+1.5))


def forklift(c):
    b(c, "Body", "Metal", "SafetyYellow", (6, 9, 4.2), (0, 0, 3.3))
    b(c, "Cab", "Metal", "Gunmetal", (6, 3.0, 5), (0, 2.1, 7))
    b(c, "DriverVoid", "Smooth", "HazardBlack", (4.8, 2.5, 3.6), (0, 1.7, 7.4))
    for x in (-2.4, 2.4):
        for y in (-3.6, 3.6):
            cyl(c, "Tire", "Rubber", "Rubber", 1.45, 0.9, (x, y, 1.5), rot=(0, 90, 0))
        b(c, "Mast", "Metal", "Gunmetal", (0.65, 0.9, 12), (x, -4.5, 6))
        b(c, "Fork", "Metal", "Steel", (1.2, 7, 0.5), (x, -7.2, 1.2))


def mezzanine_kit(c):
    b(c, "Platform", "Plate", "Gunmetal", (24, 9, 0.6), (0, 0, 10.5))
    for x in (-11, 11):
        for y in (-4, 4):
            b(c, "Post", "Metal", "Steel", (0.5, 0.5, 10), (x, y, 5.0))
    for x in (-10, -5, 0, 5, 10):
        b(c, "RailPost", "Metal", "SafetyYellow", (0.2, 0.2, 3), (x, -4.5, 12.3))
    b(c, "Handrail", "Metal", "SafetyYellow", (22, 0.28, 0.3), (0, -4.5, 13.7))
    # Must be accompanied by SIMPLE SERVER-SIDE platform and staircase collision.


def vent_duct(c):
    b(c, "Duct", "Metal", "Steel", (12, 3, 3), (0, 0, 3))
    for x in (-5.8, -2.0, 2.0, 5.8):
        b(c, "Brace", "Metal", "Gunmetal", (0.3, 3.4, 3.4), (x, 0, 3))
    b(c, "Grill", "Metal", "Gunmetal", (0.15, 3.5, 3.5), (6, 0, 3))


def conveyor(c):
    for x in (-6, 6):
        b(c, "Support", "Metal", "Gunmetal", (0.6, 3, 3.6), (x, 0, 1.8))
    b(c, "Conveyor", "Rubber", "Rubber", (16, 3.4, 0.7), (0, 0, 4))
    for x in range(-6, 7, 2):
        b(c, "Bar", "Metal", "Steel", (0.15, 3.6, 0.2), (x, 0, 4.45))


def pallet_jack(c):
    for x in (-1.1, 1.1):
        b(c, "Fork", "Metal", "Mustard", (0.75, 10, 0.45), (x, -2, 0.5))
    b(c, "Chassis", "Metal", "SafetyYellow", (3.1, 2, 1.5), (0, 3.0, 1.4))
    b(c, "HandlePole", "Metal", "Gunmetal", (0.4, 0.4, 5), (0, 4.4, 3.8), rot=(15, 0, 0))
    b(c, "Handle", "Rubber", "Rubber", (3.8, 0.4, 0.4), (0, 4.9, 6.1))


def industry_lamp(c):
    b(c, "Suspension", "Metal", "Gunmetal", (0.35, 0.35, 3), (0, 0, 6.2))
    cyl(c, "Housing", "Metal", "Steel", 2.0, 1.0, (0, 0, 4.6), verts=12, radius_top=1.2)
    cyl(c, "Bulb", "Neon", "WindowWarm", 1.5, 0.3, (0, 0, 3.9), verts=12)


# ------------------------------- MOTEL (110 x 30 x 14)
def motel_shell(c):
    wall(c, "Wall", 110, 14, 30, "Terracotta")
    roof(c, 110, 30, 14, "RoofSlate")
    for x in range(-48, 49, 12):
        if abs(x) < 8:
            continue
        b(c, "ClosedDoor", "Planks", "RoofBrown", (5.8, 0.45, 8.5),
          (x, -15.55, 4.5))
        b(c, "NumberPlate", "Smooth", "Mustard", (2, 0.2, 0.75),
          (x, -15.9, 9.4))
        b(c, "RoomWindow", "Glass", "WindowWarm", (4.0, 0.2, 4.4),
          (x+4, -15.6, 7.3))
    b(c, "Eave", "Metal", "Cobalt", (112, 4.5, 0.6), (0, -17.0, 14.2))
    b(c, "NeonBand", "Neon", "NeonPink", (112, 0.25, 0.3), (0, -19.2, 14.2))


def motel_sign(c):
    b(c, "Pole", "Metal", "Gunmetal", (1.6, 1.6, 26), (0, 0, 13))
    b(c, "SignPanel", "Smooth", "RoofSlate", (11, 1.0, 8.5), (0, 0, 26))
    b(c, "NeonFrame", "Neon", "NeonPink", (11.8, 1.2, 0.45), (0, 0, 30.5))
    for x in (-5.7, 5.7):
        b(c, "EdgeGlow", "Neon", "NeonPink", (0.4, 1.2, 9), (x, 0, 26))
    b(c, "VacancyBar", "Neon", "NeonGreen", (9, 0.35, 0.6), (0, -0.75, 22.6))


def reception(c):
    b(c, "Desk", "Planks", "Bark", (12, 3, 4), (0, 0, 2))
    b(c, "Countertop", "Smooth", "Cream", (12.5, 3.5, 0.5), (0, 0, 4.2))
    b(c, "BellBase", "Metal", "Steel", (1.1, 0.8, 0.22), (-3, -1.3, 4.58))
    sphere(c, "Bell", "Metal", "Mustard", 0.6, (-3, -1.3, 4.9), scale=(1, 1, 0.65))
    b(c, "KeyBoard", "Planks", "RoofBrown", (4.3, 0.7, 4), (3, 1.0, 6.3))
    for x in (1.7, 3, 4.3):
        for z in (5.4, 6.5, 7.6):
            b(c, "KeyTag", "Metal", "SafetyYellow", (0.45, 0.15, 0.6), (x, 0.6, z))


def motel_bed(c):
    b(c, "Base", "Wood", "Bark", (8, 12, 1.6), (0, 0, 1))
    b(c, "Mattress", "Fabric", "White", (7.6, 11.5, 1.4), (0, 0, 2.3))
    b(c, "Blanket", "Fabric", "Teal", (7.8, 7, 0.5), (0, 1.2, 3.25))
    for x in (-2, 2):
        b(c, "Pillow", "Fabric", "Cream", (3.4, 2.7, 0.7), (x, -4.4, 3.25))
    b(c, "Headboard", "Wood", "RoofBrown", (9.2, 0.8, 5), (0, -6.1, 2.5))


def motel_dresser(c):
    b(c, "Chest", "Planks", "Bark", (7.0, 2.8, 5), (0, 0, 2.5))
    for z in (1.3, 2.8, 4.2):
        b(c, "Drawer", "Planks", "Plaster", (6.2, 0.25, 1.0), (0, -1.5, z))
        b(c, "Pull", "Metal", "Steel", (1.1, 0.2, 0.15), (0, -1.7, z))
    b(c, "Mirror", "Glass", "Glass", (5.9, 0.18, 4), (0, 0.9, 7.2))


def bathroom_sink(c):
    b(c, "SinkCabinet", "Smooth", "White", (5.0, 2.8, 3.4), (0, 0, 1.7))
    b(c, "Basin", "Smooth", "Cream", (5.3, 3, 0.45), (0, 0, 3.7))
    b(c, "Mirror", "Glass", "Glass", (4, 0.22, 4), (0, 1.2, 6.1))
    cyl(c, "Faucet", "Metal", "Steel", 0.2, 1.2, (0, -0.6, 4.4), verts=8)


def vending_machine(c):
    b(c, "Body", "Metal", "Cobalt", (4.5, 3.5, 9), (0, 0, 4.5))
    b(c, "Window", "Glass", "WindowWarm", (3.4, 0.2, 6), (-0.1, -1.85, 5.5))
    for z in (4, 5.5, 7.0):
        for x in (-1, 0, 1):
            b(c, "Drink", "Smooth", ("Coral", "Teal", "Mustard")[int(x+z)%3],
              (0.58, 0.2, 0.8), (x, -1.99, z))
    b(c, "CoinSlot", "Smooth", "HazardBlack", (0.5, 0.2, 2.3), (1.4, -1.9, 2.7))


def walkway(c):
    b(c, "WalkwayDeck", "Concrete", "Concrete", (30, 5, 0.75), (0, 0, 0.38))
    for x in (-14, 0, 14):
        b(c, "Post", "Metal", "Cobalt", (0.45, 0.45, 5), (x, -2, 2.5))
    b(c, "Rail", "Metal", "Cobalt", (30, 0.35, 0.35), (0, -2, 4.8))
    # Collidable staircase/upper deck must be simple Luau geometry, not this mesh.


def luggage_cart(c):
    b(c, "Platform", "Metal", "Mustard", (5, 7, 0.5), (0, 0, 1))
    for x in (-2, 2):
        for y in (-2.7, 2.7):
            cyl(c, "Wheel", "Rubber", "Rubber", 0.6, 0.5, (x, y, 0.5), rot=(0, 90, 0))
    for x in (-2.4, 2.4):
        b(c, "HandlePole", "Metal", "Steel", (0.35, 0.35, 8), (x, 2.7, 4.3))
    b(c, "HandleTop", "Metal", "Steel", (5.4, 0.3, 0.35), (0, 2.7, 8.1))
    for x in (-1, 1):
        b(c, "Case", "Fabric", "Coral", (2.0, 3.8, 2.8), (x, 0, 2.7))


def outdoor_ac(c):
    b(c, "Housing", "Metal", "Cream", (4.5, 3.5, 3.5), (0, 0, 1.75))
    cyl(c, "Fan", "Metal", "Gunmetal", 1.3, 0.4, (0, -1.86, 1.9), rot=(90, 0, 0), verts=12)
    for x in range(-1, 2):
        b(c, "Grill", "Metal", "Steel", (0.17, 0.22, 2.8), (x, -2.1, 1.9))


# ------------------------------- TOWN SQUARE (60 x 60 plaza)
def clock_tower(c):
    b(c, "Foundation", "Concrete", "Stone", (12, 12, 2), (0, 0, 1))
    b(c, "Shaft", "Brick", "Terracotta", (9, 9, 26), (0, 0, 15))
    b(c, "Top", "Smooth", "Cream", (11.6, 11.6, 3), (0, 0, 29.2))
    gable(c, "Cap", "Slate", "RoofSlate", 12, 12, 6, pos=(0, 0, 30.7))
    for x,y,rot in ((0,-5.95,90),(0,5.95,90),(-5.95,0,0),(5.95,0,0)):
        cyl(c, "ClockFace", "Smooth", "Cream", 3.0, 0.3, (x,y,24),rot=(rot,0,0),verts=16)
    for x in (-3.5, 3.5):
        b(c, "Accent", "Smooth", "Cream", (0.8, 10, 26), (x, 0, 15))


def fountain(c):
    cyl(c, "Plinth", "Concrete", "Stone", 7, 1.8, (0, 0, 0.9), verts=16)
    cyl(c, "Basin", "Smooth", "Cream", 6.2, 0.5, (0, 0, 1.9), verts=16)
    cyl(c, "Water", "Glass", "Glass", 5.7, 0.2, (0, 0, 2.15), verts=16)
    cyl(c, "Pedestal", "Concrete", "Stone", 1.4, 5.5, (0, 0, 4.8), verts=12)
    cyl(c, "TopBowl", "Smooth", "Cream", 2.9, 0.7, (0, 0, 8.0), verts=12)


def kiosk(c):
    b(c, "Counter", "Wood", "Bark", (12, 8, 4), (0, 0, 2))
    for x in (-5, 5):
        for y in (-3, 3):
            b(c, "Pole", "Wood", "Bark", (0.8, 0.8, 10), (x, y, 5))
    gable(c, "Roof", "Slate", "RoofRed", 13, 9, 3, pos=(0, 0, 10))
    b(c, "SignBand", "Smooth", "Mustard", (10, 0.5, 2), (0, -4.2, 9))


def market_stall(c):
    b(c, "Counter", "Planks", "Bark", (10, 5, 3.6), (0, 0, 1.8))
    for x in (-4.7, 4.7):
        b(c, "Post", "Wood", "Bark", (0.5, 0.5, 8), (x, 1, 4))
    b(c, "Roof", "Fabric", "Teal", (12, 8, 0.4), (0, 0, 8))
    for x in (-4, 0, 4):
        b(c, "Stripe", "Fabric", "Cream", (1.1, 8.1, 0.15), (x, 0, 8.3))
    for x in (-3, 0, 3):
        b(c, "Display", "Smooth", "Coral", (2.0, 2.0, 1), (x, -1.2, 4.1))


def bus_stop(c):
    b(c, "Base", "Concrete", "Concrete", (16, 5, 0.5), (0, 0, 0.25))
    for x in (-7, 7):
        b(c, "Post", "Metal", "Cobalt", (0.5, 0.5, 10), (x, 0, 5))
    b(c, "Canopy", "Metal", "Cobalt", (17, 6.0, 0.6), (0, 0, 10.1))
    b(c, "RearWindow", "Glass", "Glass", (15, 0.2, 7.0), (0, 2.5, 5.8))
    b(c, "Bench", "Wood", "Bark", (12, 1.8, 0.5), (0, -0.4, 2.0))


def round_planter(c):
    cyl(c, "Planter", "Concrete", "Concrete", 3.3, 2.0, (0, 0, 1), verts=12)
    cyl(c, "Soil", "Rock", "Bark", 2.9, 0.3, (0, 0, 2), verts=12)
    for x,y in ((-1,0),(1,0),(0,-1),(0,1)):
        sphere(c, "Shrub", "Grass", "Leaf", 1.25, (x,y,3), subdiv=1)


def plaza_bench(c):
    for x in (-3, 3):
        b(c, "Support", "Metal", "Gunmetal", (0.4, 2, 2), (x, 0, 1.2))
    b(c, "Seat", "Planks", "Bark", (8, 2.0, 0.4), (0, 0, 2.2))
    b(c, "Back", "Planks", "Bark", (8, 0.3, 2.5), (0, 1.0, 3.25))
    for x in (-3.5, 3.5):
        b(c, "Arm", "Metal", "Gunmetal", (0.3, 2.5, 0.2), (x, 0, 2.8))


def notice_board(c):
    for x in (-4.6, 4.6):
        b(c, "Post", "Wood", "Bark", (0.7, 0.7, 9), (x, 0, 4.5))
    b(c, "Board", "Wood", "RoofBrown", (11, 0.6, 5), (0, 0, 6.2))
    b(c, "Paper", "Smooth", "Cream", (8.5, 0.2, 3.8), (0, -0.48, 6.2))
    for x in (-2.3, 2.3):
        b(c, "Poster", "Smooth", "Mustard", (2.7, 0.1, 2.4), (x, -0.65, 6.1))


def broken_statue(c):
    cyl(c, "Base", "Concrete", "Stone", 4.0, 1.8, (0, 0, 0.9), verts=12)
    b(c, "Pedestal", "Concrete", "Cream", (4.8, 4.8, 6.0), (0, 0, 4.8))
    b(c, "Fragment", "Rock", "Stone", (2.5, 2.1, 5), (0.5, 0.1, 10.2), rot=(14, 0, 20))
    for x,y in ((-3, 2), (2, -4), (4, 3)):
        sphere(c, "Rubble", "Rock", "Stone", 1.3, (x,y,0.6), subdiv=1)


def storm_siren(c):
    for x in (-3, 3):
        for y in (-3, 3):
            b(c, "Frame", "Metal", "Gunmetal", (0.6, 0.6, 24), (x,y,12))
    for z in (6, 12, 18, 23):
        b(c, "Brace", "Metal", "Steel", (7, 0.45, 0.45), (0, -3, z))
        b(c, "Brace", "Metal", "Steel", (0.45, 7, 0.45), (3, 0, z))
    b(c, "ControlBox", "Smooth", "SafetyYellow", (5, 4, 3), (0, 0, 25.5))
    for x in (-2.7, 2.7):
        cyl(c, "Speaker", "Metal", "Gunmetal", 1.3, 3, (x,0,27), rot=(0, 90, 0), verts=10)
    b(c, "Beacon", "Neon", "Coral", (2.0, 2.0, 1.2), (0, 0, 29))


SETS = {
    "supermarket": [
        ("SupermarketShell", supermarket_shell), ("SupermarketSign", supermarket_sign),
        ("Checkout", checkout), ("MarketShelf", market_shelf), ("Freezer", freezer),
        ("ProduceStand", produce_stand), ("StockShelf", stock_shelf),
        ("FoodPallet", food_pallet), ("CartCorral", cart_corral), ("ShoppingCart", shopping_cart),
    ],
    "gasstation": [
        ("GasStationShell", gas_shell), ("GasCanopy", gas_canopy),
        ("FuelPump", fuel_pump), ("GasCounter", gas_counter), ("GarageLift", garage_lift),
        ("ToolCabinet", tool_cabinet), ("OilRack", oil_rack),
        ("GasPriceSign", gas_price_sign), ("Extinguisher", extinguisher),
    ],
    "warehouse": [
        ("WarehouseShell", warehouse_shell), ("LoadingDock", loading_dock),
        ("WarehouseRack", warehouse_rack), ("CargoStack", cargo_stack),
        ("Forklift", forklift), ("MezzanineKit", mezzanine_kit),
        ("VentDuct", vent_duct), ("Conveyor", conveyor),
        ("PalletJack", pallet_jack), ("IndustryLamp", industry_lamp),
    ],
    "motel": [
        ("MotelShell", motel_shell), ("MotelSign", motel_sign),
        ("Reception", reception), ("MotelBed", motel_bed),
        ("MotelDresser", motel_dresser), ("BathroomSink", bathroom_sink),
        ("VendingMachine", vending_machine), ("MotelWalkway", walkway),
        ("LuggageCart", luggage_cart), ("OutdoorAC", outdoor_ac),
    ],
    "townsquare": [
        ("ClockTower", clock_tower), ("PlazaFountain", fountain),
        ("Kiosk", kiosk), ("MarketStall", market_stall),
        ("BusStop", bus_stop), ("RoundPlanter", round_planter),
        ("PlazaBench", plaza_bench), ("NoticeBoard", notice_board),
        ("BrokenStatue", broken_statue), ("StormSiren", storm_siren),
    ],
}

if __name__ == "__main__":
    names = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(SETS)
    for name in names:
        if name not in SETS:
            raise SystemExit(f"Unknown district '{name}'. Available: {', '.join(SETS)}")
        print(f"Generating district kit {name}: {len(SETS[name])} assets")
        build_set(name, SETS[name])
