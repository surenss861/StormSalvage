"""Shared building-shell helpers (walls with real openings, windows, parapets, rooftop clutter).

Shells are visual only: MapBuilder keeps invisible gameplay walls (1 stud thick, centered on the
footprint edges) and roofs. Front faces Blender -Y; walls are centered on x = ±W/2 and y = ±D/2.
"""

import math

from kit import box, cyl, rng, sphere  # noqa: F401


def wall(c, axis, offset, length, height, openings, material="Concrete", swatch="Plaster", thickness=1.0):
    """Wall along X (axis 'x', at y=offset) or Y (axis 'y', at x=offset) with rectangular openings
    given as (center, width, bottom, top)."""
    cuts = sorted(openings)
    edges = [-length / 2]
    for center, width, _, _ in cuts:
        edges += [center - width / 2, center + width / 2]
    edges.append(length / 2)

    def piece(a0, a1, z0, z1):
        if a1 - a0 < 0.05 or z1 - z0 < 0.05:
            return
        mid, size = (a0 + a1) / 2, a1 - a0
        if axis == "x":
            box(c, "Wall", material, swatch, (size, thickness, z1 - z0), pos=(mid, offset, (z0 + z1) / 2), bevel=0.05)
        else:
            box(c, "Wall", material, swatch, (thickness, size, z1 - z0), pos=(offset, mid, (z0 + z1) / 2), bevel=0.05)

    for i in range(0, len(edges), 2):
        piece(edges[i], edges[i + 1], 0, height)
    for center, width, bottom, top in cuts:
        piece(center - width / 2, center + width / 2, 0, bottom)
        piece(center - width / 2, center + width / 2, top, height)


def glazing(c, axis, offset, along, bottom, top, width, outward, frame="Cream", glass="Glass", mullions=1):
    """Glass + frame filling an opening (center `along`, from `bottom` to `top`)."""
    h = top - bottom
    z = (bottom + top) / 2

    def at(a, depth, zz):
        return (a, offset + depth * outward, zz) if axis == "x" else (offset + depth * outward, a, zz)

    def sz(a, depth, zz):
        return (a, depth, zz) if axis == "x" else (depth, a, zz)

    box(c, "Glass", "Glass", glass, sz(width, 0.25, h), pos=at(along, 0.0, z), bevel=0.0)
    for dz in (bottom + 0.2, top - 0.2):
        box(c, "Frame", "Smooth", frame, sz(width + 0.6, 0.6, 0.4), pos=at(along, 0.2, dz), bevel=0.08)
    for da in (-width / 2, width / 2):
        box(c, "Frame", "Smooth", frame, sz(0.4, 0.6, h), pos=at(along + da, 0.2, z), bevel=0.08)
    for i in range(1, mullions + 1):
        a = along - width / 2 + width * i / (mullions + 1)
        box(c, "Mullion", "Smooth", frame, sz(0.25, 0.4, h), pos=at(a, 0.15, z), bevel=0.03)


def parapet(c, w, d, h, swatch="Cream", height=1.6, material="Concrete"):
    for s in (-1, 1):
        box(c, "Parapet", material, swatch, (w + 1.6, 0.9, height), pos=(0, s * (d / 2 + 0.3), h + height / 2), bevel=0.12)
        box(c, "Parapet", material, swatch, (0.9, d + 1.6, height), pos=(s * (w / 2 + 0.3), 0, h + height / 2), bevel=0.12)


def roof_deck(c, w, d, h, swatch="Concrete"):
    """Visible ceiling/roof slab at the gameplay roof height (h .. h+1)."""
    box(c, "Deck", "Concrete", swatch, (w + 0.8, d + 0.8, 1.0), pos=(0, 0, h + 0.5), bevel=0.05)


def rooftop_clutter(c, w, d, h, count=3):
    for i in range(count):
        x = rng.uniform(-w / 2 + 6, w / 2 - 6)
        y = rng.uniform(-d / 2 + 5, d / 2 - 5)
        box(c, "ACUnit", "Metal", "Steel", (4, 3, 2.4), pos=(x, y, h + 2.2), bevel=0.2)
        cyl(c, "Fan", "Metal", "Gunmetal", 1.1, 0.3, pos=(x, y, h + 3.5), verts=10)
    for i in range(2):
        cyl(c, "Vent", "Metal", "Steel", 0.5, 2, pos=(rng.uniform(-w / 3, w / 3), rng.uniform(-d / 3, d / 3), h + 2), verts=8)


def pilasters(c, w, d, h, swatch="Cream", every=None):
    """Vertical trim strips on the front and back walls (corners only, or every `every` studs)."""
    n = max(1, int(w // every)) if every else 1
    for i in range(n + 1):
        x = -w / 2 + i * w / n
        for y in (-d / 2 - 0.1, d / 2 + 0.1):
            box(c, "Pilaster", "Smooth", swatch, (1.4, 1.6, h), pos=(x, y, h / 2), bevel=0.15)


def base_band(c, w, d, height=1.2, swatch="Stone"):
    for s in (-1, 1):
        box(c, "Base", "Concrete", swatch, (w + 1.2, 1.4, height), pos=(0, s * d / 2, height / 2), bevel=0.12)
        box(c, "Base", "Concrete", swatch, (1.4, d + 1.2, height), pos=(s * w / 2, 0, height / 2), bevel=0.12)


def sign_board(c, width, height, z, front_y, swatch="Signboard", trim="Cream"):
    """The single labeled board on a building (code adds the text to the Signboard mesh)."""
    box(c, "SignBoard", "Smooth", swatch, (width, 0.6, height), pos=(0, front_y - 0.6, z), bevel=0.15)
    box(c, "SignTrim", "Smooth", trim, (width + 0.8, 0.5, height + 0.8), pos=(0, front_y - 0.35, z), bevel=0.15)


def door_frame(c, front_y, width=8.0, height=9.0, swatch="Cream", outward=-1):
    for s in (-1, 1):
        box(c, "DoorFrame", "Smooth", swatch, (0.8, 1.2, height + 0.4), pos=(s * (width / 2 + 0.4), front_y + 0.2 * outward, (height + 0.4) / 2), bevel=0.12)
    box(c, "DoorFrame", "Smooth", swatch, (width + 2.4, 1.2, 0.9), pos=(0, front_y + 0.2 * outward, height + 0.45), bevel=0.12)
