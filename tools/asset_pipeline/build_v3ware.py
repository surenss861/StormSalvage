"""V3 Milestone C4: Warehouse 7. Front faces Blender -Y; origin at the base centre.

The warehouse keeps MapBuilder's 70 x 60 x 22 gameplay box (door -Z, back truss) and its 9 x 8
loot grid. Rack-row pieces share the V2 PalletRack footprint (24 long, <= 2.4 deep) so they stand
in the same rows between loot rows. DistrictWarehouse gives each one a single solid collider:
tall racks get one that reaches just under the ceiling, so nothing becomes a climbable ledge or a
new flood refuge. Overhead pieces hang above 12 studs. Signs carry a "Signboard" mesh.

blender -b --python tools/asset_pipeline/build_v3ware.py
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from kit import box, build_set, cyl, jitter, rng, sphere, torus, wedge  # noqa: E402,F401

LOADS = ["Bark", "Sand", "ContainerBlue", "Coral", "Plaster", "ContainerGreen"]


# --------------------------------------------------------------------------- rack row pieces (24 x 2.4)

def _rack_frame(c, height, levels):
    for x in (-12, -4, 4, 12):
        for sy in (-1.1, 1.1):
            box(c, "Upright", "Metal", "Cobalt", (0.35, 0.35, height), pos=(x, sy, height / 2), bevel=0.0)
        # X-bracing on the end frames only (cheap, reads from the aisles).
        if abs(x) == 12:
            for z0 in range(0, int(height) - 2, 4):
                box(c, "Brace", "Metal", "Cobalt", (0.12, 2.6, 0.12), pos=(x, 0, z0 + 2), rot=(55, 0, 0), bevel=0.0)
    for z in levels:
        for sy in (-1.1, 1.1):
            box(c, "Beam", "Metal", "Coral", (24, 0.25, 0.45), pos=(0, sy, z), bevel=0.0)
        box(c, "Deck", "Metal", "Gunmetal", (23.6, 2.2, 0.08), pos=(0, 0, z + 0.25), bevel=0.0)


def tall_rack_a(c):
    """14-stud selective pallet rack, four levels of wrapped cartons, a few bays empty."""
    levels = (0.5, 4.0, 7.5, 11.0)
    _rack_frame(c, 14.0, levels)
    for z in levels:
        for x in (-8, 0, 8):
            if rng.random() < 0.8:
                box(c, "Pallet", "Planks", "Bark", (6.6, 2.0, 0.35), pos=(x, 0, z + 0.45), bevel=0.0)
                h = rng.uniform(1.6, 2.8)
                o = box(c, "Load", "Planks", LOADS[rng.randrange(len(LOADS))], (rng.uniform(5.0, 6.4), 1.8, h),
                        pos=(x, 0, z + 0.63 + h / 2), bevel=0.08)
                jitter(o, 0.8)
    box(c, "BaySign", "Smooth", "Signboard", (3.0, 0.1, 1.0), pos=(-10.5, -1.25, 13.3), bevel=0.0)


def tall_rack_b(c):
    """14-stud rack of drums and sacks: heavier, darker freight for variety."""
    levels = (0.5, 4.5, 9.0)
    _rack_frame(c, 14.0, levels)
    for li, z in enumerate(levels):
        for x in (-8, 0, 8):
            if rng.random() < 0.85:
                box(c, "Pallet", "Planks", "Bark", (6.6, 2.0, 0.35), pos=(x, 0, z + 0.45), bevel=0.0)
                if (li + int(x)) % 2 == 0:
                    for dx in (-2.2, 0, 2.2):
                        cyl(c, "Drum", "Metal", "ContainerBlue" if dx else "Coral", 0.95, 2.8,
                            pos=(x + dx, 0, z + 2.05), verts=8, bevel=0.0)
                else:
                    for k in range(5):
                        o = box(c, "Sack", "Fabric", "Sand", (2.0, 1.6, 0.9),
                                pos=(x - 2.0 + (k % 3) * 2.0, 0, z + 1.1 + (k // 3) * 0.85), bevel=0.15)
                        jitter(o, 6)
    box(c, "BaySign", "Smooth", "Signboard", (3.0, 0.1, 1.0), pos=(-10.5, -1.25, 13.3), bevel=0.0)


def freight_stack(c):
    """Receiving-zone floor freight: three wrapped pallet stacks of different heights and a crate
    on skids, with banding straps. 24 long, 2.4 deep, up to ~6.5 tall."""
    for i, (x, w, h) in enumerate(((-8.5, 6.2, 4.2), (0.0, 6.6, 6.0), (8.5, 6.0, 3.0))):
        box(c, "Pallet", "Planks", "Bark", (w + 0.4, 2.3, 0.4), pos=(x, 0, 0.2), bevel=0.0)
        box(c, "Cartons", "Planks", LOADS[(i * 2) % len(LOADS)], (w, 2.1, h), pos=(x, 0, 0.4 + h / 2), bevel=0.1)
        box(c, "Wrap", "Glass", "Glass", (w + 0.1, 2.2, h * 0.8), pos=(x, 0, 0.4 + h * 0.45), bevel=0.0)
        for z in (0.4 + h * 0.3, 0.4 + h * 0.7):
            box(c, "Strap", "Smooth", "HazardBlack", (w + 0.15, 2.25, 0.12), pos=(x, 0, z), bevel=0.0)
    box(c, "Label", "Smooth", "Signboard", (2.4, 0.08, 1.0), pos=(0, -1.12, 3.0), bevel=0.0)


def mesh_cage(c):
    """High-value storage cage: welded mesh walls on a steel frame, padlocked door, tagged crates
    inside. 24 long x 2.4 deep x 8 tall. Visual only (code gives it one solid collider)."""
    for x in (-12, -6, 0, 6, 12):
        for sy in (-1.15, 1.15):
            box(c, "Post", "Metal", "Gunmetal", (0.25, 0.25, 8.0), pos=(x, sy, 4.0), bevel=0.0)
    for sy in (-1.15, 1.15):
        for z in (0.2, 7.9):
            box(c, "Rail", "Metal", "Gunmetal", (24, 0.25, 0.25), pos=(0, sy, z), bevel=0.0)
        # Mesh panels: a few thin bars per panel rather than real mesh (cheap, reads as cage).
        for i in range(25):
            box(c, "Bar", "Metal", "Steel", (0.06, 0.06, 7.6), pos=(-12 + i, sy, 4.0), bevel=0.0)
        for z in (2.0, 4.0, 6.0):
            box(c, "Bar", "Metal", "Steel", (24, 0.06, 0.06), pos=(0, sy, z), bevel=0.0)
    box(c, "Top", "Metal", "Gunmetal", (24, 2.3, 0.1), pos=(0, 0, 8.0), bevel=0.0)
    box(c, "Lock", "Metal", "Mustard", (0.4, 0.2, 0.5), pos=(3, -1.3, 3.8), bevel=0.0)
    for x in (-8, -2, 5, 9):
        box(c, "Crate", "Planks", "Sand", (3.0, 1.8, 2.2), pos=(x, 0, 1.3), bevel=0.08)
        box(c, "Tag", "Smooth", "Coral", (0.8, 0.05, 0.5), pos=(x, -0.93, 1.6), bevel=0.0)
    box(c, "CageSign", "Smooth", "Signboard", (6.0, 0.08, 1.2), pos=(0, -1.25, 7.0), bevel=0.0)


# --------------------------------------------------------------------------- overhead and walls

def overhead_crane(c):
    """Bridge crane spanning the hall (68 long): box girder on end trucks riding wall rails, a
    hoist trolley and hook block hanging to about 7 studs below the girder. Origin = girder
    underside centre (place at y ~18)."""
    box(c, "Girder", "Metal", "SafetyYellow", (68, 1.6, 1.8), pos=(0, 0, 0.9), bevel=0.1)
    for x in range(-32, 33, 4):
        box(c, "Stripe", "Smooth", "HazardBlack", (1.0, 1.62, 0.3), pos=(x, 0, 1.6), rot=(0, 30, 0), bevel=0.0)
    for sx in (-33.5, 33.5):
        box(c, "EndTruck", "Metal", "Gunmetal", (1.6, 6.0, 1.4), pos=(sx, 0, 1.6), bevel=0.08)
        for sy in (-2.3, 2.3):
            cyl(c, "Wheel", "Metal", "Steel", 0.45, 0.4, pos=(sx, sy, 2.4), rot=(0, 90, 0), verts=8, bevel=0.0)
        box(c, "Rail", "Metal", "Gunmetal", (0.8, 60, 0.6), pos=(sx, 0, 2.8), bevel=0.0)
    box(c, "Trolley", "Metal", "Coral", (3.2, 2.6, 1.4), pos=(6, 0, -0.5), bevel=0.1)
    cyl(c, "Drum", "Metal", "Gunmetal", 0.6, 2.4, pos=(6, 0, -1.4), rot=(0, 90, 0), verts=10, bevel=0.0)
    for sx in (-0.4, 0.4):
        box(c, "Cable", "Metal", "Steel", (0.08, 0.08, 4.6), pos=(6 + sx, 0, -4.1), bevel=0.0)
    box(c, "HookBlock", "Metal", "SafetyYellow", (1.4, 0.9, 1.2), pos=(6, 0, -6.8), bevel=0.15)
    torus(c, "Hook", "Metal", "Gunmetal", 0.5, 0.18, pos=(6, 0, -7.9), rot=(90, 0, 0), segments=10)
    box(c, "Pendant", "Smooth", "HazardBlack", (0.4, 0.3, 0.8), pos=(4.4, 0, -6.2), bevel=0.05)
    box(c, "PendantCord", "Rubber", "Rubber", (0.06, 0.06, 5.2), pos=(4.4, 0, -3.2), bevel=0.0)
    box(c, "CapacitySign", "Smooth", "Signboard", (6.0, 0.1, 1.0), pos=(-14, -0.92, 0.9), bevel=0.0)


def breaker_panel(c):
    """Wall electrical panel: two cabinets, conduit up the wall, a danger placard, a fire
    extinguisher. Local -Y faces out; 1.2 deep."""
    for x, h in ((-1.4, 4.0), (1.4, 3.2)):
        box(c, "Cabinet", "Metal", "Steel", (2.4, 1.0, h), pos=(x, 0, 2.0 + h / 2), bevel=0.06)
        box(c, "Door", "Metal", "Gunmetal", (2.2, 0.08, h - 0.3), pos=(x, -0.52, 2.0 + h / 2), bevel=0.0)
        box(c, "Handle", "Metal", "Mustard", (0.15, 0.1, 0.5), pos=(x + 0.8, -0.58, 2.2 + h / 2), bevel=0.0)
    for x in (-1.8, -1.0, 1.0):
        box(c, "Conduit", "Metal", "Steel", (0.25, 0.25, 12.0), pos=(x, 0.3, 12.0), bevel=0.0)
    box(c, "Placard", "Smooth", "SafetyYellow", (1.6, 0.06, 1.0), pos=(-1.4, -0.58, 5.1), bevel=0.0)
    box(c, "PlacardText", "Smooth", "Signboard", (1.4, 0.04, 0.5), pos=(-1.4, -0.62, 5.0), bevel=0.0)
    cyl(c, "Extinguisher", "Smooth", "Coral", 0.3, 1.4, pos=(3.4, -0.2, 1.2), verts=8, bevel=0.0)
    box(c, "ExtBracket", "Metal", "Gunmetal", (0.7, 0.3, 0.2), pos=(3.4, 0.1, 1.9), bevel=0.0)


def siding_patch(c):
    """Storm repair on corrugated siding: a mismatched green panel riveted over a tear, with a
    bent flap of the old skin showing at one edge. Local -Y faces out. 7 x 8."""
    box(c, "Patch", "Metal", "ContainerGreen", (6.0, 0.15, 7.0), pos=(0, 0, 3.5), bevel=0.0)
    for i in range(7):
        box(c, "Rib", "Metal", "ContainerGreen", (0.35, 0.3, 7.0), pos=(-2.7 + i * 0.9, -0.1, 3.5), bevel=0.0)
    for z in (0.3, 6.7):
        for i in range(7):
            sphere(c, "Rivet", "Metal", "Steel", 0.12, pos=(-2.7 + i * 0.9, -0.2, z), subdiv=1)
    box(c, "Flap", "Metal", "Steel", (1.6, 0.1, 2.4), pos=(3.6, -0.5, 1.6), rot=(0, 0, 35), bevel=0.0)


def dock_light(c):
    """Swing-arm dock light over a bay door; the head is Neon (code tags it as a work lamp)."""
    box(c, "Mount", "Metal", "Gunmetal", (0.8, 0.3, 0.8), pos=(0, 0.15, 0), bevel=0.04)
    box(c, "Arm", "Metal", "SafetyYellow", (0.2, 2.6, 0.2), pos=(0, -1.3, 0), rot=(-15, 0, 0), bevel=0.0)
    box(c, "Head", "Metal", "SafetyYellow", (1.2, 0.9, 0.8), pos=(0, -2.6, -0.4), rot=(25, 0, 0), bevel=0.08)
    box(c, "Lens", "Neon", "WindowWarm", (1.0, 0.1, 0.6), pos=(0, -2.85, -0.75), rot=(25, 0, 0), bevel=0.0)


def roof_fan(c):
    """Rooftop extractor fan housing with a rain cap. ~3 across."""
    cyl(c, "Curb", "Metal", "Gunmetal", 1.6, 0.6, pos=(0, 0, 0.3), verts=10, bevel=0.0)
    cyl(c, "Housing", "Metal", "Steel", 1.3, 1.8, pos=(0, 0, 1.5), verts=10, bevel=0.06)
    cyl(c, "Cap", "Metal", "Steel", 1.7, 0.6, pos=(0, 0, 2.8), verts=10, radius_top=0.4, bevel=0.0)
    for k in range(4):
        box(c, "Vane", "Metal", "Gunmetal", (0.1, 2.5, 0.5), pos=(0, 0, 2.2), rot=(0, 0, k * 45), bevel=0.0)


def box_truck(c):
    """Freight truck backed up to a dock: cab at -Y, box trailer at +Y with roll door open and
    freight inside. 8 wide, ~25 long, 10 tall."""
    # Cab
    box(c, "Cab", "Metal", "Coral", (7.6, 6.0, 6.4), pos=(0, -9.0, 4.0), bevel=0.4, segments=2)
    box(c, "Windshield", "Glass", "Glass", (6.8, 0.3, 2.4), pos=(0, -12.05, 5.4), rot=(-8, 0, 0), bevel=0.0)
    box(c, "Grille", "Metal", "Gunmetal", (6.0, 0.3, 2.0), pos=(0, -12.1, 2.4), bevel=0.05)
    for sx in (-2.8, 2.8):
        box(c, "Headlight", "Neon", "WindowWarm", (1.2, 0.2, 0.7), pos=(sx, -12.15, 2.6), bevel=0.0)
    box(c, "Bumper", "Metal", "Gunmetal", (8.0, 0.8, 0.9), pos=(0, -12.3, 1.2), bevel=0.1)
    # Trailer box
    box(c, "Chassis", "Metal", "HazardBlack", (7.0, 24.0, 0.8), pos=(0, 0.5, 1.6), bevel=0.0)
    box(c, "Box", "Metal", "White", (8.0, 17.0, 8.0), pos=(0, 4.0, 6.0), bevel=0.15)
    box(c, "Stripe", "Smooth", "Mustard", (8.05, 17.0, 0.9), pos=(0, 4.0, 3.2), bevel=0.0)
    box(c, "SideSign", "Smooth", "Signboard", (0.1, 10.0, 2.4), pos=(-4.05, 4.0, 7.0), bevel=0.0)
    box(c, "SideSign2", "Smooth", "Signboard", (0.1, 10.0, 2.4), pos=(4.05, 4.0, 7.0), bevel=0.0)
    box(c, "RollDoor", "Metal", "Steel", (7.2, 0.3, 1.6), pos=(0, 12.4, 9.0), bevel=0.0)
    for sx in (-1, 1):
        box(c, "Jamb", "Metal", "Gunmetal", (0.5, 0.4, 8.0), pos=(sx * 3.75, 12.4, 6.0), bevel=0.0)
    for x in (-2.0, 1.8):
        box(c, "Freight", "Planks", "Sand", (3.0, 3.0, 2.6), pos=(x, 10.4, 3.3), bevel=0.08)
    for sx in (-3.3, 3.3):
        for y in (-9.0, 5.5, 9.2):
            cyl(c, "Wheel", "Rubber", "Rubber", 1.3, 1.0, pos=(sx, y, 1.3), rot=(0, 90, 0), verts=12, bevel=0.1)
            cyl(c, "Hub", "Metal", "Steel", 0.55, 1.05, pos=(sx, y, 1.3), rot=(0, 90, 0), verts=8, bevel=0.0)


BUILDERS = [
    ("TallRackA", tall_rack_a),
    ("TallRackB", tall_rack_b),
    ("FreightStack", freight_stack),
    ("MeshCage", mesh_cage),
    ("OverheadCrane", overhead_crane),
    ("BreakerPanel", breaker_panel),
    ("SidingPatch", siding_patch),
    ("DockLight", dock_light),
    ("RoofFan", roof_fan),
    ("BoxTruck", box_truck),
]

if __name__ == "__main__":
    build_set("v3ware", BUILDERS, layout_spacing=4)
