#!/usr/bin/env python
"""
Import the 12 RPG-origin staging stills (M-approved 08-11, style locked to the
Legion Deserter gothic-vista look) as spr_origin_<id> sprites + register them
in Ironwake.yyp. Sources: _for_review/origin_stills_0811/NN_<id>.png (384x112).
Scholar defaults to take A (dark library) - pass B as argv[1] to use take B.

Run from repo root with GameMaker CLOSED:
    python tools/import_origin_stills_0811.py [B]
"""
import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_trait_icons import register_yyp
from import_combat_vfx_0729 import gm_running
from import_vfx_upgrade_0811 import build_vfx_sprite_wh

from PIL import Image

SRC = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "_for_review", "origin_stills_0811")

ORIGINS = [
    ("merchant",    "01_merchant.png"),
    ("forester",    "02_forester.png"),
    ("deserter",    "03_deserter.png"),
    ("gravekeeper", "04_gravekeeper.png"),
    ("survivor",    "05_survivor.png"),
    ("orphan",      "06_orphan.png"),
    ("scholar",     "07_scholar_A.png"),   # A default; argv[1]=B switches
    ("shrinesworn", "08_shrinesworn.png"),
    ("campaigner",  "09_campaigner.png"),
    ("banshee",     "10_banshee.png"),
    ("whisperer",   "11_whisperer.png"),
    ("debtor",      "12_debtor.png"),
]


def main():
    if gm_running():
        sys.exit("ABORT: GameMaker is running - close it first.")
    if len(sys.argv) > 1 and sys.argv[1].upper() == "B":
        ORIGINS[6] = ("scholar", "07_scholar_B.png")

    print("Importing 12 origin stills as spr_origin_* (384x112 single-frame):")
    new_names = []
    for oid, fn in ORIGINS:
        path = os.path.join(SRC, fn)
        if not os.path.isfile(path):
            print(f"  !! spr_origin_{oid}: missing {fn} - SKIPPED"); continue
        frame = Image.open(path).convert("RGBA")
        name  = f"spr_origin_{oid}"
        n, w, h = build_vfx_sprite_wh(name, [frame])
        new_names.append(name)
        print(f"  {name}: {w}x{h}  <-  {fn}")
    register_yyp(new_names)
    print(f"Registered {len(new_names)} sprites in Ironwake.yyp. F5 to verify the picker cards.")


if __name__ == "__main__":
    main()
