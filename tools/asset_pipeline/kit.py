"""Shared Blender modeling kit for Storm Salvage assets.

Run generators with:  blender -b --python tools/asset_pipeline/build_<set>.py

Conventions (see docs/art/ART-DIRECTION.md):
- 1 Blender unit = 1 stud; import into Studio with Scale Unit: Studs.
- Every asset is built at the world origin with its base at z = 0 (Blender is Z-up; the FBX
  exporter converts to Roblox's Y-up).
- Pieces are named "Piece__Material__Swatch". Before export, pieces sharing a Material+Swatch
  are joined, so each asset imports as a handful of MeshParts (one per look), not dozens.
"""

import math
import os
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BLEND_DIR = os.path.join(ROOT, "assets", "blender")
EXPORT_DIR = os.path.join(ROOT, "assets", "exports")
PREVIEW_DIR = os.path.join(ROOT, "docs", "art", "previews")

# Preview colors only (Roblox colors come from src/shared/Palette.luau at import time).
SWATCHES = {
    "Terracotta": (214, 106, 64), "Mustard": (232, 178, 62), "Coral": (222, 96, 104),
    "Cobalt": (62, 112, 196), "Teal": (52, 156, 150), "Mint": (150, 210, 170),
    "Cream": (242, 230, 205), "Plaster": (226, 208, 176), "RoofRed": (168, 62, 48),
    "RoofBrown": (122, 74, 52), "RoofSlate": (70, 82, 104), "Grass": (104, 168, 76),
    "GrassDark": (70, 128, 58), "Leaf": (84, 150, 70), "Bark": (110, 76, 52),
    "Sand": (226, 204, 158), "Stone": (150, 146, 140), "Asphalt": (56, 56, 64),
    "Concrete": (176, 172, 164), "SafetyYellow": (246, 190, 40), "Rust": (150, 78, 46),
    "RustDark": (96, 56, 40), "Gunmetal": (70, 74, 82), "Steel": (150, 156, 164),
    "HazardBlack": (34, 34, 38), "ContainerBlue": (40, 96, 150), "ContainerGreen": (58, 122, 82),
    "Glass": (150, 200, 230), "WindowWarm": (255, 214, 140), "NeonPink": (255, 110, 160),
    "NeonGreen": (120, 255, 140), "StormCyan": (120, 220, 255), "Rubber": (32, 32, 34),
    "White": (240, 240, 240),
}
MATERIALS = {"Plastic", "Smooth", "Wood", "Planks", "Brick", "Concrete", "Metal", "Rusty", "Plate",
             "Slate", "Glass", "Neon", "Fabric", "Rubber", "Grass", "Rock", "Cobble"}

rng = random.Random(1234)


# --------------------------------------------------------------------------- scene

def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "NONE"
    return scene


def _material(swatch, roblox_material):
    name = f"{roblox_material}__{swatch}"
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
        r, g, b = (c / 255 for c in SWATCHES[swatch])
        mat.diffuse_color = (r ** 2.2, g ** 2.2, b ** 2.2, 1.0)
        mat.roughness = 0.2 if roblox_material in ("Metal", "Glass", "Neon") else 0.8
    return mat


def _finish(obj, piece, material, swatch, collection):
    assert material in MATERIALS, material
    assert swatch in SWATCHES, swatch
    obj.name = f"{piece}__{material}__{swatch}"
    obj.data.materials.clear()
    obj.data.materials.append(_material(swatch, material))
    for c in obj.users_collection:
        c.objects.unlink(obj)
    collection.objects.link(obj)
    return obj


def _bevel(obj, width, segments=1):
    if width <= 0:
        return
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=width, segments=segments, affect="EDGES",
                    clamp_overlap=True, profile=0.5)
    bm.to_mesh(obj.data)
    bm.free()


# --------------------------------------------------------------------------- primitives

def box(col, piece, material, swatch, size, pos=(0, 0, 0), rot=(0, 0, 0), bevel=0.12, segments=1):
    """Box with its center at pos. size/pos in studs, rot in degrees (X, Y, Z; Z is up)."""
    bpy.ops.mesh.primitive_cube_add(size=1)
    obj = bpy.context.active_object
    obj.scale = size
    bpy.ops.object.transform_apply(scale=True)
    _bevel(obj, min(bevel, min(size) * 0.45), segments)
    obj.rotation_euler = [math.radians(a) for a in rot]
    obj.location = pos
    return _finish(obj, piece, material, swatch, col)


def cyl(col, piece, material, swatch, radius, depth, pos=(0, 0, 0), rot=(0, 0, 0), verts=12,
        bevel=0.08, radius_top=None):
    """Cylinder (or cone when radius_top is given) along local Z, centered at pos."""
    if radius_top is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=radius_top, depth=depth)
    obj = bpy.context.active_object
    _bevel(obj, min(bevel, radius * 0.3, depth * 0.3))
    obj.rotation_euler = [math.radians(a) for a in rot]
    obj.location = pos
    return _finish(obj, piece, material, swatch, col)


def torus(col, piece, material, swatch, radius, thickness, pos=(0, 0, 0), rot=(0, 0, 0), segments=16):
    bpy.ops.mesh.primitive_torus_add(major_radius=radius, minor_radius=thickness, major_segments=segments,
                                     minor_segments=6)
    obj = bpy.context.active_object
    obj.rotation_euler = [math.radians(a) for a in rot]
    obj.location = pos
    return _finish(obj, piece, material, swatch, col)


def sphere(col, piece, material, swatch, radius, pos=(0, 0, 0), scale=(1, 1, 1), subdiv=1):
    """Low-poly faceted blob (icosphere) for foliage, rocks and Storm Cores."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=radius)
    obj = bpy.context.active_object
    obj.scale = scale
    obj.location = pos
    bpy.ops.object.transform_apply(scale=True)
    return _finish(obj, piece, material, swatch, col)


def wedge(col, piece, material, swatch, size, pos=(0, 0, 0), rot=(0, 0, 0), bevel=0.08):
    """Triangular prism: full height at -Y, zero height at +Y (a roof slope or ramp)."""
    sx, sy, sz = (s / 2 for s in size)
    verts = [(-sx, -sy, -sz), (sx, -sy, -sz), (sx, sy, -sz), (-sx, sy, -sz), (-sx, -sy, sz), (sx, -sy, sz)]
    faces = [(0, 1, 2, 3), (0, 4, 5, 1), (1, 5, 2), (0, 3, 4), (3, 2, 5, 4)]
    mesh = bpy.data.meshes.new("wedge")
    mesh.from_pydata(verts, [], faces)
    obj = bpy.data.objects.new("wedge", mesh)
    bpy.context.scene.collection.objects.link(obj)
    _bevel(obj, bevel)
    obj.rotation_euler = [math.radians(a) for a in rot]
    obj.location = pos
    return _finish(obj, piece, material, swatch, col)


def gable(col, piece, material, swatch, width, depth, height, pos=(0, 0, 0), overhang=0.6, rot=0,
          thickness=0.5):
    """Pitched roof: two thick slabs meeting at a ridge along X. pos is the eave-level center."""
    half = depth / 2 + overhang
    slope_len = math.hypot(half, height)
    angle = math.degrees(math.atan2(height, half))
    x, y, z = pos
    objs = []
    for side in (-1, 1):
        slab_center = Vector((0, side * half / 2, height / 2))
        o = box(col, piece, material, swatch, (width + overhang * 2, slope_len, thickness),
                pos=slab_center, rot=(side * angle, 0, 0), bevel=0.1)
        objs.append(o)
    # Gable-end triangles (walls) are added by the caller in the wall swatch.
    for o in objs:
        o.location = Matrix.Rotation(math.radians(rot), 4, "Z") @ o.location + Vector((x, y, z))
        o.rotation_euler.z += math.radians(rot)
    return objs


def jitter(obj, amount):
    """Small random tilt so repeated props don't look stamped."""
    obj.rotation_euler.x += math.radians(rng.uniform(-amount, amount))
    obj.rotation_euler.y += math.radians(rng.uniform(-amount, amount))
    obj.rotation_euler.z += math.radians(rng.uniform(-amount * 2, amount * 2))
    return obj


# --------------------------------------------------------------------------- assets

def new_asset(name):
    col = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(col)
    return col


def finalize(col):
    """Apply transforms and join pieces that share Material+Swatch. Returns the joined objects."""
    groups = {}
    for obj in list(col.objects):
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        obj.select_set(False)
        _, material, swatch = obj.name.split(".")[0].split("__")
        groups.setdefault((material, swatch), []).append(obj)
    joined = []
    for (material, swatch), objs in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        if len(objs) > 1:
            bpy.ops.object.join()
        obj = bpy.context.active_object
        # Origin at the asset origin (0,0,0) so all pieces of one asset line up on import.
        bpy.context.scene.cursor.location = (0, 0, 0)
        bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
        piece = f"{col.name}{len(joined) + 1}"
        obj.name = f"{piece}__{material}__{swatch}"
        obj.data.name = obj.name
        joined.append(obj)
    bpy.ops.object.select_all(action="DESELECT")
    return joined


def tri_count(objs):
    total = 0
    for o in objs:
        for p in o.data.polygons:
            total += len(p.vertices) - 2
    return total


def export_fbx(col, objs, set_name):
    out_dir = os.path.join(EXPORT_DIR, set_name)
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, f"{col.name}.fbx")
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        apply_scale_options="FBX_SCALE_UNITS",
        object_types={"MESH"},
        use_mesh_modifiers=True,
        mesh_smooth_type="FACE",
        add_leaf_bones=False,
        bake_anim=False,
        path_mode="COPY",
        embed_textures=True,
        axis_forward="-Z",
        axis_up="Y",
    )
    bpy.ops.object.select_all(action="DESELECT")
    return path


def bounds(objs):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        for corner in o.bound_box:
            w = o.matrix_world @ Vector(corner)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


def render_preview(objs, path, angle=35):
    """Workbench render of the given objects for visual inspection."""
    scene = bpy.context.scene
    for o in bpy.data.objects:
        o.hide_render = o not in objs
    lo, hi = bounds(objs)
    center = (lo + hi) / 2
    radius = max((hi - lo).length / 2, 1.0)
    cam_data = bpy.data.cameras.get("PreviewCam") or bpy.data.cameras.new("PreviewCam")
    cam = bpy.data.objects.get("PreviewCam") or bpy.data.objects.new("PreviewCam", cam_data)
    if cam.name not in scene.collection.objects:
        scene.collection.objects.link(cam)
    cam_data.lens = 50
    yaw = math.radians(angle)
    dist = radius * 3.1
    cam.location = center + Vector((math.sin(yaw) * dist, -math.cos(yaw) * dist, radius * 1.3))
    direction = center - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_cavity = True
    scene.display.shading.show_shadows = True
    scene.display.shading.show_object_outline = True
    scene.render.resolution_x = 640
    scene.render.resolution_y = 480
    scene.render.film_transparent = False
    world = scene.world or bpy.data.worlds.new("World")
    scene.world = world
    world.color = (0.55, 0.62, 0.7)
    scene.render.filepath = path
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.render.render(write_still=True)
    for o in bpy.data.objects:
        o.hide_render = False


def build_set(set_name, builders, layout_spacing=None):
    """Build every asset, export FBX + preview, lay them out in a grid, save the .blend."""
    reset_scene()
    report = []
    placed = []
    for name, fn in builders:
        col = new_asset(name)
        fn(col)
        objs = finalize(col)
        tris = tri_count(objs)
        lo, hi = bounds(objs)
        fbx = export_fbx(col, objs, set_name)
        render_preview(objs, os.path.join(PREVIEW_DIR, set_name, f"{name}.png"))
        report.append((name, len(objs), tris, tuple(round(v, 1) for v in (hi - lo)), os.path.relpath(fbx, ROOT)))
        placed.append((objs, hi - lo))
    # Grid layout for the saved .blend (exports above were made at the origin).
    x = 0.0
    for objs, size in placed:
        step = (layout_spacing or 0) + size.x
        for o in objs:
            o.location.x += x + size.x / 2
        x += step + 4
    os.makedirs(BLEND_DIR, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BLEND_DIR, f"{set_name}.blend"))
    print("ASSET_REPORT_BEGIN")
    for name, meshes, tris, size, fbx in report:
        print(f"{name}\tmeshes={meshes}\ttris={tris}\tsize={size}\t{fbx}")
    print("ASSET_REPORT_END")
    return report
