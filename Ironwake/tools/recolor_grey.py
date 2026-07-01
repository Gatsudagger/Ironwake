#!/usr/bin/env python
# Recolor the greyish (low-saturation) pixels of a sprite toward a target hue,
# preserving each pixel's brightness so shading/detail survive. Saturated pixels
# (e.g. a glowing rune) are left alone. Usage:
#   python recolor_grey.py <src.png> <dst.png> <rmul> <gmul> <bmul> [sat_thresh]
import sys, colorsys
from PIL import Image

src, dst = sys.argv[1], sys.argv[2]
rmul, gmul, bmul = float(sys.argv[3]), float(sys.argv[4]), float(sys.argv[5])
sat = float(sys.argv[6]) if len(sys.argv) > 6 else 0.28

im = Image.open(src).convert("RGBA")
px = im.load()
W, H = im.size
for y in range(H):
    for x in range(W):
        r, g, b, a = px[x, y]
        if a == 0:
            continue
        h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        if s < sat:                      # greyish -> tint toward the target ramp
            px[x, y] = (int(min(255, v * rmul * 255)),
                        int(min(255, v * gmul * 255)),
                        int(min(255, v * bmul * 255)), a)
im.save(dst)
print("OK", dst)
