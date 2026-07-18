#!/usr/bin/env python
"""
Import the 5 TIERED Reforge Ingot icons (M-approved 07-17) from
_for_review/reforge_ingot/. All 64px full-bleed object-pipeline gens, imported
as-is. Tier -> rarity color:
    common    <- ingot_04.png          (plain gold)
    uncommon  <- ingot_09.png          (green)
    rare      <- ingot_10.png          (blue)
    epic      <- ingot_11.png          (purple)
    legendary <- legendary_crimson.png (crimson recolor of legendary_08)

Reuses gen_trait_icons.build_sprite/register_yyp. Idempotent (skips existing).
Run from repo root:  python tools/import_reforge_ingots.py
"""
import os, sys
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_trait_icons import ROOT, SPRITES, build_sprite, register_yyp

REVIEW = os.path.join(ROOT, "_for_review", "reforge_ingot")

JOBS = [
    ("spr_icon_reforge_ingot_common",    "ingot_04.png"),
    ("spr_icon_reforge_ingot_uncommon",  "ingot_09.png"),
    ("spr_icon_reforge_ingot_rare",      "ingot_10.png"),
    ("spr_icon_reforge_ingot_epic",      "ingot_11.png"),
    ("spr_icon_reforge_ingot_legendary", "legendary_crimson.png"),
]


def main():
    names = []
    for spr_name, src in JOBS:
        if os.path.isdir(os.path.join(SPRITES, spr_name)):
            print("skip (exists):", spr_name)
            continue
        img = Image.open(os.path.join(REVIEW, src)).convert("RGBA")
        if img.size != (64, 64):
            img = img.resize((64, 64), Image.NEAREST)
        build_sprite(spr_name, img)
        names.append(spr_name)
        print("built", spr_name, "<-", src)
    n = register_yyp(names)
    print("registered %d new sprites in .yyp (of %d built)" % (n, len(names)))


if __name__ == "__main__":
    main()
