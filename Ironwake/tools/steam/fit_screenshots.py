# Fit store screenshots to Steam's screenshot spec: 16:9, exactly 1920x1080.
# Steamworks rejects uploads below 1920x1080 ("Dimensions provided do not match any known assets").
# Method: center-crop to 16:9, then Lanczos resize to 1920x1080. Source captures are
# windowed grabs at ~1902-1916 wide, so the upscale is ~1% and visually lossless.
#
# Usage: python tools/steam/fit_screenshots.py
# Input:  "Steam Page Images"/*.png  (skips the MidJourney "title thumbnail" gens - not screenshots)
# Output: _for_review/steam_screenshots_1920/<same name>.png

import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "Steam Page Images")
OUT = os.path.join(ROOT, "_for_review", "steam_screenshots_1920")
TARGET_W, TARGET_H = 1920, 1080
RATIO = TARGET_W / TARGET_H

SKIP_PREFIXES = ("title thumbnail",)  # MidJourney art, not gameplay screenshots

os.makedirs(OUT, exist_ok=True)

for name in sorted(os.listdir(SRC)):
    if not name.lower().endswith(".png"):
        continue
    if name.lower().startswith(SKIP_PREFIXES):
        print(f"SKIP (not a screenshot): {name}")
        continue

    img = Image.open(os.path.join(SRC, name)).convert("RGB")
    w, h = img.size

    # Center-crop to 16:9
    if w / h > RATIO:
        crop_w = round(h * RATIO)
        x0 = (w - crop_w) // 2
        box = (x0, 0, x0 + crop_w, h)
        lost = f"{w - crop_w}px width"
    else:
        crop_h = round(w / RATIO)
        y0 = (h - crop_h) // 2
        box = (0, y0, 0 + w, y0 + crop_h)
        lost = f"{h - crop_h}px height"
    img = img.crop(box)

    scale = TARGET_W / img.size[0]
    img = img.resize((TARGET_W, TARGET_H), Image.LANCZOS)

    out_path = os.path.join(OUT, name)
    img.save(out_path, "PNG")
    print(f"OK {name}: {w}x{h} -> crop {lost} -> upscale x{scale:.3f} -> 1920x1080")

print(f"\nDone. Output: {OUT}")
