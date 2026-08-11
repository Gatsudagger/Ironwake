#!/usr/bin/env python
"""
Import the 08-09 M-approved trap ability icons + the Ashen Duelist tier-0 sprite.

Sources = M's picked candidates in _for_review/trap_icons_0809/raw (PixelLab
create_1_direction_object, style_images = the 3 shipped trap icons for the
64px icons / spr_infernal_revenant for the 97px enemy sprite).

Icons are 64x64 and referenced by direct identifier in ability_icon_sprite()
(scr_ui.gml, edited by hand) so no __sprite_includes entry is needed.
The duelist is 97x97 single-frame, matching the 07-14 boss batch. It needs NO
__sprite_includes entry: although duelist_sprite_for() resolves the TIER art by
asset_get_index (string ref), the tier-0 base is also named directly in
enemy_sprite_map(), which keeps the compiler from stripping it. When tiers t1-t3
are authored, THOSE will each need a __sprite_includes entry.

Reuses gen_trait_icons YY_TEMPLATE/register_yyp. Idempotent: skips existing
folders. GameMaker MUST BE CLOSED - this edits Ironwake.yyp.

Run from repo root:  python tools/import_trap_icons_0809.py
"""
import os, sys, uuid
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_trait_icons import ROOT, SPRITES, YY_TEMPLATE, register_yyp

RAW = os.path.join(ROOT, "_for_review", "trap_icons_0809", "raw")

# (sprite name, candidate file, native size)
JOBS = [
    ("spr_ability_tripline",      "tripline_03.png",      64),
    ("spr_ability_warding_chime", "warding_chime_00.png", 64),
    ("spr_ability_wire_snare",    "wire_snare_05.png",    64),
    ("spr_ability_caltrops",      "caltrops_05.png",      64),
    ("spr_ashen_duelist",         "duelist_03.png",       97),
]


def build_sprite(spr_name, img, sz):
    sdir = os.path.join(SPRITES, spr_name)
    frame = str(uuid.uuid4()); layer = str(uuid.uuid4()); kfid = str(uuid.uuid4())
    os.makedirs(os.path.join(sdir, "layers", frame), exist_ok=True)
    img.save(os.path.join(sdir, frame + ".png"))
    img.save(os.path.join(sdir, "layers", frame, layer + ".png"))
    yy = YY_TEMPLATE.format(name=spr_name, frame=frame, layer=layer, kfid=kfid,
                            w=sz, h=sz, br=sz - 1, bb=sz - 1)
    with open(os.path.join(sdir, spr_name + ".yy"), "w", newline="\n") as f:
        f.write(yy)


def main():
    names = []
    for spr_name, src, sz in JOBS:
        if os.path.isdir(os.path.join(SPRITES, spr_name)):
            print("skip (exists):", spr_name)
            continue
        p = os.path.join(RAW, src)
        assert os.path.exists(p), "missing candidate: " + p
        img = Image.open(p).convert("RGBA")
        assert img.size == (sz, sz), (src, img.size, "expected", sz)
        build_sprite(spr_name, img, sz)
        names.append(spr_name)
        print("built", spr_name, "<-", src, img.size)
    if names:
        register_yyp(names)
        print("registered in Ironwake.yyp:", len(names))
    else:
        print("nothing to do")


if __name__ == "__main__":
    main()
