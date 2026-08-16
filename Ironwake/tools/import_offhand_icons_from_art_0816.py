#!/usr/bin/env python
"""08-16 GM-CLOSED import: offhand ICONS derived from the codex SPLASH ART (0 gens).
Root cause (M: "my offhand is Runed Soulbound Orb which shows a book"): the shipped
offhand icon sprites are mislabeled - spr_icon_offhand_orb is a blue BOOK,
spr_icon_offhand_totem a red BOOK, spr_icon_offhand_stone another book, focus_b a
staff. The 128px codex art for these items is clean 2x pixel art, so a BOX 2:1
downscale gives correct 64px icons. Originals stay untouched (new _b/_c names).

  spr_icon_offhand_orb_b    <- spr_item_art_soulbound_orb  (orb / sphere)
  spr_icon_offhand_totem_b  <- spr_item_art_ash_totem      (totem / idol)
  spr_icon_offhand_focus_c  <- spr_item_art_runic_focus    (focus / runic)

Wire-up: ui_offhand_icon_sprite (scr_ui) + __sprite_includes (gc Create) - done in gml.
Run from repo root with GameMaker CLOSED:  python tools/import_offhand_icons_from_art_0816.py
"""
import os, shutil, uuid, glob
from PIL import Image

ROOT     = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES  = os.path.join(ROOT, "sprites")
YYP      = os.path.join(ROOT, "Ironwake.yyp")
TEMPLATE = os.path.join(SPRITES, "spr_icon_offhand_focus_b", "spr_icon_offhand_focus_b.yy")

PICKS = [
    ("spr_icon_offhand_orb_b",   "spr_item_art_soulbound_orb"),
    ("spr_icon_offhand_totem_b", "spr_item_art_ash_totem"),
    ("spr_icon_offhand_focus_c", "spr_item_art_runic_focus"),
]

def template_ids(path):
    import re
    yy = open(path, encoding="utf-8").read()
    frame = re.search(r'"frames":\[\s*\{[^}]*?"name":"([0-9a-f-]{36})"', yy)
    ids = re.findall(r'"([0-9a-f-]{36})"', yy)
    return yy, ids

def build(name, art):
    src = glob.glob(os.path.join(SPRITES, art, "*.png"))[0]
    im  = Image.open(src).convert("RGBA")
    if im.size != (64, 64):
        im = im.resize((64, 64), Image.BOX)
    d = os.path.join(SPRITES, name)
    if os.path.exists(os.path.join(d, name + ".yy")):
        print("exists, skipping:", name); return
    frame_id, layer_id = str(uuid.uuid4()), str(uuid.uuid4())
    os.makedirs(os.path.join(d, "layers", frame_id), exist_ok=True)
    im.save(os.path.join(d, frame_id + ".png"))
    im.save(os.path.join(d, "layers", frame_id, layer_id + ".png"))
    yy = open(TEMPLATE, encoding="utf-8").read()
    import re
    # template frame/layer ids: first frame name + first layer name in the file
    t_frame = re.search(r'"frames":\[\s*\{"\$GMSpriteFrame":"","%Name":"([0-9a-f-]{36})"', yy)
    if not t_frame:
        t_frame = re.search(r'"frames":\[.*?"name":"([0-9a-f-]{36})"', yy, re.S)
    t_layer = re.search(r'"layers":\[\s*\{"\$GMImageLayer":"","%Name":"([0-9a-f-]{36})"', yy)
    if not t_layer:
        t_layer = re.search(r'"layers":\[.*?"name":"([0-9a-f-]{36})"', yy, re.S)
    yy = yy.replace("spr_icon_offhand_focus_b", name)
    yy = yy.replace(t_frame.group(1), frame_id).replace(t_layer.group(1), layer_id)
    yy = yy.replace("85237a2d-dd13-46fd-951b-5a973ea73944", str(uuid.uuid4()))   # keyframe id
    open(os.path.join(d, name + ".yy"), "w", encoding="utf-8", newline="\n").write(yy)
    print("built", name, "from", art)

def register(names):
    text = open(YYP, encoding="utf-8").read()
    new = ['    {"id":{"name":"%s","path":"sprites/%s/%s.yy",},},' % (n, n, n) for n in names if ('"name":"%s"' % n) not in text]
    if new:
        marker = '  "resources":[\n'; i = text.index(marker) + len(marker)
        text = text[:i] + "\n".join(new) + "\n" + text[i:]
        open(YYP, "w", encoding="utf-8", newline="\n").write(text)
    print("registered", len(new))

if __name__ == "__main__":
    for n, a in PICKS: build(n, a)
    register([n for n, _ in PICKS])
