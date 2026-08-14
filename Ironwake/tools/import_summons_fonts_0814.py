#!/usr/bin/env python
"""08-14 GM-CLOSED import sitting: 3 elemental summon sprites (M's approved
picks magma_IDX0 / ward_IDX3 / storm_IDX2) cloned from the spr_bone_sovereign_hd
.yy template with fresh uuids + full-canvas bbox, plus .yyp registration for
them AND the 4 script-built font variants (fonts/<n>/<n>.yy paths).

Run from repo root with GameMaker CLOSED:  python tools/import_summons_fonts_0814.py
"""
import os, shutil, uuid

ROOT    = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES = os.path.join(ROOT, "sprites")
YYP     = os.path.join(ROOT, "Ironwake.yyp")
REVIEW  = os.path.join(ROOT, "_for_review", "sprites_hd_pro_0813")
TEMPLATE = os.path.join(SPRITES, "spr_bone_sovereign_hd", "spr_bone_sovereign_hd.yy")

SUMMONS = [
    ("spr_summon_magma", "summon_magma_IDX0.png"),
    ("spr_summon_ward",  "summon_ward_IDX3.png"),
    ("spr_summon_storm", "summon_storm_IDX2.png"),
]
FONTS = ["fnt_ui_lg", "fnt_ui_sm", "fnt_ui_small_lg", "fnt_ui_small_sm"]

def build_sprite(name, src_png):
    from PIL import Image
    src = os.path.join(REVIEW, src_png)
    im  = Image.open(src)
    w, h = im.size
    frame_id = str(uuid.uuid4())
    layer_id = str(uuid.uuid4())
    d = os.path.join(SPRITES, name)
    os.makedirs(os.path.join(d, "layers", frame_id), exist_ok=True)
    shutil.copyfile(src, os.path.join(d, frame_id + ".png"))
    shutil.copyfile(src, os.path.join(d, "layers", frame_id, layer_id + ".png"))
    with open(TEMPLATE, "r", encoding="utf-8") as f:
        yy = f.read()
    yy = yy.replace("spr_bone_sovereign_hd", name)
    yy = yy.replace("5de2be9b-2f1f-4635-9a39-0859aec9efa2", frame_id)
    yy = yy.replace("6a3748e5-b659-4b1f-bbde-c1d95ccc5345", layer_id)
    yy = yy.replace('"id":"f61ab8f3-66c1-4ebb-a0fc-0019e78d9ce0"', '"id":"%s"' % str(uuid.uuid4()))
    yy = yy.replace('"bbox_bottom":167', '"bbox_bottom":%d' % (h - 1))
    yy = yy.replace('"bbox_right":109',  '"bbox_right":%d' % (w - 1))
    yy = yy.replace('"height":168', '"height":%d' % h)
    yy = yy.replace('"width":110',  '"width":%d' % w)
    with open(os.path.join(d, name + ".yy"), "w", encoding="utf-8", newline="\n") as f:
        f.write(yy)
    print("built %s (%dx%d) from %s" % (name, w, h, src_png))

def register(entries):
    """entries: list of (name, relative .yy path). Idempotent."""
    with open(YYP, "r", encoding="utf-8") as f:
        text = f.read()
    new_lines = []
    for n, p in entries:
        if ('"name":"%s"' % n) in text:
            print("already registered:", n)
            continue
        new_lines.append('    {"id":{"name":"%s","path":"%s",},},' % (n, p))
    if new_lines:
        marker = '  "resources":[\n'
        idx = text.index(marker) + len(marker)
        text = text[:idx] + "\n".join(new_lines) + "\n" + text[idx:]
        with open(YYP, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
    print("registered %d new .yyp entries" % len(new_lines))

if __name__ == "__main__":
    for name, src in SUMMONS:
        build_sprite(name, src)
    entries  = [(n, "sprites/%s/%s.yy" % (n, n)) for n, _ in SUMMONS]
    entries += [(n, "fonts/%s/%s.yy" % (n, n)) for n in FONTS]
    register(entries)
