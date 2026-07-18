#!/usr/bin/env python
"""
Import the 07-14 M-approved boss sprites (sprite-reuse audit: 6 bosses were
renamed clones sharing another enemy's model - see enemy_sprite_map comment).

Sources = M's picked candidates in _for_review/boss_sprites (PixelLab
create_1_direction_object + same-family style_images, 97x97 single frame,
same format as the existing enemy sprites; drawn at 3x by the combat draw).

Reuses gen_trait_icons YY_TEMPLATE/register_yyp but builds at native 97px
(build_sprite there hardcodes 64). Sprites are referenced directly by
identifier in enemy_sprite_map (scr_enemies.gml, edited by hand) so no
__sprite_includes entry is needed. Idempotent: skips existing folders.

Run from repo root:  python tools/import_boss_sprites.py
"""
import os, sys, uuid
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_trait_icons import ROOT, SPRITES, YY_TEMPLATE, register_yyp

REVIEW = os.path.join(ROOT, "_for_review", "boss_sprites")

# (sprite name, M's picked candidate)
JOBS = [
    ("spr_forge_tyrant",    "forge_tyrant_1.png"),
    ("spr_molten_revenant", "molten_revenant_0.png"),
    ("spr_ashen_colossus",  "ashen_colossus_3.png"),
    ("spr_glacial_warden",  "glacial_warden_1.png"),
    ("spr_tomb_archon",     "tomb_archon_2.png"),
    ("spr_eternal_frost",   "eternal_frost_0.png"),
]

SZ = 97


def build_sprite_97(spr_name, img):
    sdir = os.path.join(SPRITES, spr_name)
    frame = str(uuid.uuid4()); layer = str(uuid.uuid4()); kfid = str(uuid.uuid4())
    os.makedirs(os.path.join(sdir, "layers", frame), exist_ok=True)
    img.save(os.path.join(sdir, frame + ".png"))
    img.save(os.path.join(sdir, "layers", frame, layer + ".png"))
    yy = YY_TEMPLATE.format(name=spr_name, frame=frame, layer=layer, kfid=kfid,
                            w=SZ, h=SZ, br=SZ - 1, bb=SZ - 1)
    with open(os.path.join(sdir, spr_name + ".yy"), "w", newline="\n") as f:
        f.write(yy)


def main():
    names = []
    for spr_name, src in JOBS:
        if os.path.isdir(os.path.join(SPRITES, spr_name)):
            print("skip (exists):", spr_name)
            continue
        img = Image.open(os.path.join(REVIEW, src)).convert("RGBA")
        assert img.size == (SZ, SZ), (src, img.size)
        build_sprite_97(spr_name, img)
        names.append(spr_name)
        print("built", spr_name, "<-", src)
    n = register_yyp(names)
    print("registered %d new sprites in .yyp (of %d built)" % (n, len(names)))


if __name__ == "__main__":
    main()
