"""Tile preview PNGs into one contact sheet:  blender -b --python contact_sheet.py -- <dir> <out.png>"""
import math
import os
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:]
src, out = args[0], args[1]
files = sorted(f for f in os.listdir(src) if f.endswith(".png"))
imgs = [bpy.data.images.load(os.path.join(src, f)) for f in files]
w, h = imgs[0].size
cols = 4
rows = math.ceil(len(imgs) / cols)
sheet = bpy.data.images.new("sheet", w * cols, h * rows)
pixels = [0.15] * (w * cols * h * rows * 4)
for i, img in enumerate(imgs):
    px = list(img.pixels)
    cx, cy = i % cols, rows - 1 - i // cols
    for y in range(h):
        row = px[y * w * 4:(y + 1) * w * 4]
        start = ((cy * h + y) * w * cols + cx * w) * 4
        pixels[start:start + w * 4] = row
sheet.pixels = pixels
sheet.filepath_raw = out
sheet.file_format = "PNG"
sheet.save()
print("SHEET", out, files)
