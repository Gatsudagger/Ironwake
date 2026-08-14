# Task #16 (2026-07-09): pet creature sprites carry big transparent canvas
# padding (bonehound youngadult = 20x43 art on a 144px canvas), and every draw
# site fit-scaled by CANVAS size, so padded species drew tiny. The GML fix
# scales by the sprite's bbox (pet_sprite_fit in scr_stats) - but the build
# scripts wrote FULL-CANVAS bboxes into every .yy. This pass rewrites each pet
# sprite's bbox to its true visible bounds (union over all frames, so animation
# never jitters). bboxMode stays 0 (automatic) - these are the values the IDE
# itself would compute. Feed icons (spr_pet_feed_*) are left alone.
#
# 08-15 (M shot: bonehound off-center at Bairc): only union frames the .yy
# actually REFERENCES. Re-imports had left stale small-canvas PNGs beside the
# live frames; globbing *.png folded their content into the bbox, which shifted
# pet_sprite_fit's centering (~20px right) and halved its scale for bonehound
# adult/baby south. Orphans are reported so import passes can clean them up.
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
    txt = yy.read_text(encoding="utf-8")
    # Frame GUIDs referenced by the sprite ("frames":[{... "name":"<guid>" ...}]).
    live = set(re.findall(r'"%Name":"([0-9a-f-]{36})"', txt))
    if not live:  # older .yy format fallback
        live = set(re.findall(r'"name":"([0-9a-f-]{36})"', txt))
    frames = []
    orphans = []
    for f in sdir.glob("*.png"):
        (frames if f.stem in live else orphans).append(f)
    if orphans:
        print(f"{sdir.name}: {len(orphans)} ORPHAN png(s) not in .yy: "
              + ", ".join(o.name for o in orphans))
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
