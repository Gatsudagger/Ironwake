#!/usr/bin/env python
"""
Import the 07-31 hub-carousel NPC chip icons (M-approved picks):

    _for_review/npc_chip_icons/dorn_2.png  -> spr_icon_npc_dorn
    _for_review/npc_chip_icons/sable_2.png -> spr_icon_npc_sable
    _for_review/npc_chip_icons/maren_1.png -> spr_icon_npc_maren
    _for_review/npc_chip_icons/vex_1.png   -> spr_icon_npc_vex
    _for_review/npc_chip_icons/petra_1.png -> spr_icon_npc_petra
    _for_review/npc_chip_icons/vael_1.png  -> spr_icon_npc_vael
    _for_review/npc_chip_icons/bairc_1.png -> spr_icon_npc_bairc
    _for_review/npc_chip_icons/board_1.png -> spr_icon_npc_board

All 8 are NEW resources (.yy + .yyp register). GM MUST BE CLOSED.
Run from repo root:  python tools/import_npc_chip_icons.py
"""
import os, sys
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_trait_icons import ROOT, SPRITES, build_sprite, register_yyp

SRC = os.path.join(ROOT, "_for_review", "npc_chip_icons")

PICKS = {
    "spr_icon_npc_dorn":  "dorn_2.png",
    "spr_icon_npc_sable": "sable_2.png",
    "spr_icon_npc_maren": "maren_1.png",
    "spr_icon_npc_vex":   "vex_1.png",
    "spr_icon_npc_petra": "petra_1.png",
    "spr_icon_npc_vael":  "vael_1.png",
    "spr_icon_npc_bairc": "bairc_1.png",
    "spr_icon_npc_board": "board_1.png",
}


def load64(name):
    im = Image.open(os.path.join(SRC, name)).convert("RGBA")
    if im.size != (64, 64):
        im = im.resize((64, 64), Image.NEAREST)
    return im


names = []
for spr_name, png in PICKS.items():
    if os.path.isdir(os.path.join(SPRITES, spr_name)):
        print(f"  {spr_name} already exists - skipped")
        continue
    build_sprite(spr_name, load64(png))
    names.append(spr_name)
    print(f"  built {spr_name} <- {png}")

n = register_yyp(names)
print(f"registered {n} new sprites in the .yyp")
print("Done.")
