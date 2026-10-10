"""Writes storm skybox faces (assets/textures/sky/<Storm>_{Up,Side,Dn}.png).

Gradient skies so the horizon takes the storm's colour even where Roblox's Atmosphere haze
doesn't render (seen in Studio at automatic quality; low graphics levels on phones too).
Pure standard library: python3 tools/asset_pipeline/make_storm_skies.py
"""

import os
import struct
import zlib

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "textures", "sky")
SIZE = 256

# (zenith, horizon, ground) per storm, sRGB 0-255. Horizon matches each storm's haze colour
# in src/server/LookService.luau (V3 profile).
STORMS = {
    "Wind": ((150, 132, 108), (200, 172, 124), (120, 104, 80)),
    "Flood": ((70, 90, 98), (110, 136, 140), (60, 74, 76)),
    "Lightning": ((30, 24, 52), (74, 60, 108), (30, 26, 44)),
}


def png(path, rows):
    raw = b"".join(b"\x00" + bytes(c for px in row for c in px) for row in rows)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
    data += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(data)


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, (zenith, horizon, ground) in STORMS.items():
        # Side face: top row = halfway up the sky, bottom row = horizon; ease toward the
        # horizon colour in the lower third so the band under the clouds matches the haze.
        side = []
        for y in range(SIZE):
            t = y / (SIZE - 1)
            if t < 0.5:
                c = lerp(zenith, horizon, (t / 0.5) ** 1.6)
            else:
                c = lerp(horizon, ground, ((t - 0.5) / 0.5) ** 0.5)
            side.append([c] * SIZE)
        png(os.path.join(OUT, f"{name}_Side.png"), side)
        png(os.path.join(OUT, f"{name}_Up.png"), [[zenith] * SIZE for _ in range(SIZE)])
        png(os.path.join(OUT, f"{name}_Dn.png"), [[ground] * SIZE for _ in range(SIZE)])
        print("wrote", name)


if __name__ == "__main__":
    main()
