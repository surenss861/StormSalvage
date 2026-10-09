"""District props merged from the five-district source pack (contrib/five_district_pack.py, kept
verbatim for provenance). Only props that add something the main districts kit
(build_districts.py) doesn't have, and that fit beside the loot grids, are built here.

blender -b --python tools/asset_pipeline/build_district_props.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "contrib"))
from kit import box, build_set, cyl, sphere  # noqa: E402
import five_district_pack as pack  # noqa: E402


def clock_tower(c):
    """Replaces pack.clock_tower, whose clock faces stuck out sideways and whose gable roof
    splayed open in the preview render."""
    box(c, "Foundation", "Concrete", "Stone", (12, 12, 2), pos=(0, 0, 1), bevel=0.25)
    box(c, "Shaft", "Brick", "Terracotta", (9, 9, 26), pos=(0, 0, 15), bevel=0.2)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(c, "Quoin", "Smooth", "Cream", (1.2, 1.2, 26), pos=(sx * 4.4, sy * 4.4, 15), bevel=0.12)
    box(c, "Belt", "Smooth", "Cream", (10, 10, 1), pos=(0, 0, 20), bevel=0.15)
    box(c, "Top", "Smooth", "Cream", (11, 11, 3), pos=(0, 0, 29.5), bevel=0.25)
    # Four clock faces, each a disc facing straight out of one side of the shaft.
    for rot, offset in (((90, 0, 0), (0, -4.6, 24)), ((90, 0, 0), (0, 4.6, 24)), ((0, 90, 0), (-4.6, 0, 24)), ((0, 90, 0), (4.6, 0, 24))):
        cyl(c, "ClockFace", "Smooth", "Cream", 3.0, 0.4, pos=offset, rot=rot, verts=16, bevel=0.05)
        cyl(c, "ClockRim", "Metal", "Mustard", 3.3, 0.3, pos=offset, rot=rot, verts=16, bevel=0.0)
    for offset, rot in (((0, -4.95, 24), (0, 0, 0)), ((0, 4.95, 24), (0, 0, 0)), ((-4.95, 0, 24), (0, 0, 90)), ((4.95, 0, 24), (0, 0, 90))):
        box(c, "Hand", "Smooth", "HazardBlack", (0.3, 0.2, 2.2), pos=(offset[0], offset[1], offset[2] + 0.9), rot=rot, bevel=0.0)
        box(c, "Hand", "Smooth", "HazardBlack", (1.6, 0.2, 0.3), pos=(offset[0], offset[1], offset[2]), rot=rot, bevel=0.0)
    # Pyramid roof (4-sided cone) and a weather vane
    cyl(c, "Roof", "Slate", "RoofSlate", 8.4, 6, pos=(0, 0, 34), rot=(0, 0, 45), verts=4, radius_top=0.4, bevel=0.0)
    cyl(c, "Vane", "Metal", "Gunmetal", 0.15, 3, pos=(0, 0, 38.5), verts=6, bevel=0.0)
    box(c, "VaneArrow", "Metal", "Mustard", (2.4, 0.2, 0.5), pos=(0, 0, 39.4), bevel=0.0)
    for x, y, z in ((2.5, -4.6, 9), (-2.5, -4.6, 13)):
        box(c, "Window", "Glass", "WindowWarm", (1.6, 0.3, 3), pos=(x, y, z), bevel=0.05)
    box(c, "Door", "Planks", "Bark", (3.4, 0.4, 5.4), pos=(0, -4.6, 4.7), bevel=0.1)

BUILDERS = [
    # Supermarket exterior (the interior is aisles from build_districts.py)
    ("CartCorral", pack.cart_corral),
    ("ProduceStand", pack.produce_stand),
    ("FoodPallet", pack.food_pallet),
    # Gas station: an open-air repair bay beside the store
    ("GarageLift", pack.garage_lift),
    ("ToolCabinet", pack.tool_cabinet),
    ("OilRack", pack.oil_rack),
    ("Extinguisher", pack.extinguisher),
    # Warehouse
    ("LoadingDock", pack.loading_dock),
    ("CargoStack", pack.cargo_stack),
    ("IndustryLamp", pack.industry_lamp),
    ("VentDuct", pack.vent_duct),
    ("PalletJack", pack.pallet_jack),
    # Motel
    ("MotelDresser", pack.motel_dresser),
    ("BathroomSink", pack.bathroom_sink),
    ("LuggageCart", pack.luggage_cart),
    ("OutdoorAC", pack.outdoor_ac),
    # Town square
    ("ClockTower", clock_tower),
    ("BusStop", pack.bus_stop),
    ("NoticeBoard", pack.notice_board),
    ("RoundPlanter", pack.round_planter),
]

if __name__ == "__main__":
    build_set("districtprops", BUILDERS)
