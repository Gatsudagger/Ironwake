# Task #16 (2026-07-09): pet creature sprites carry big transparent canvas
# padding (bonehound youngadult = 20x43 art on a 144px canvas), and every draw
# site fit-scaled by CANVAS size, so padded species drew tiny. The GML fix
# scales by the sprite's bbox (pet_sprite_fit in scr_stats) - but the build
# scripts wrote FULL-CANVAS bboxes into every .yy. This pass rewrites each pet
# sprite's bbox to its true visible bounds (union over all frames, so animation
# never jitters). bboxMode stays 0 (automatic) - these are the values the IDE
# itself would compute. Feed icons (spr_pet_feed_*) are left alone.
import re
from pathlib import Path
from PIL import Image

SPRITES = Path(__file__).resolve().parent.parent / "sprites"

changed = 0
for sdir in sorted(SPRITES.glob("spr_pet_*")):
    if sdir.name.startswith("spr_pet_feed_"):
        continue
    yy = sdir / (sdir.name + ".yy")
    if not yy.exists():
        continue
    # Top-level PNGs = one per frame (layer copies live under layers/).
    frames = list(sdir.glob("*.png"))
    if not frames:
        continue
    box = None
    size = None
    for f in frames:
        img = Image.open(f).convert("RGBA")
        size = img.size
        b = img.getbbox()
        if b is None:
            continue
        box = b if box is None else (
            min(box[0], b[0]), min(box[1], b[1]),
            max(box[2], b[2]), max(box[3], b[3]))
    if box is None:
        continue
    l, t, r, b = box[0], box[1], box[2] - 1, box[3] - 1
    txt = yy.read_text(encoding="utf-8")
    new = txt
    new = re.sub(r'"bbox_bottom":\d+,', f'"bbox_bottom":{b},', new)
    new = re.sub(r'"bbox_left":\d+,',   f'"bbox_left":{l},',   new)
    new = re.sub(r'"bbox_right":\d+,',  f'"bbox_right":{r},',  new)
    new = re.sub(r'"bbox_top":\d+,',    f'"bbox_top":{t},',    new)
    if new != txt:
        yy.write_text(new, encoding="utf-8", newline="\n")
        changed += 1
        print(f"{sdir.name}: canvas {size[0]}x{size[1]} -> bbox ({l},{t})-({r},{b})")
print(f"{changed} .yy files updated")
