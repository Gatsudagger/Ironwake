#!/usr/bin/env python
"""
Build the 07-08 approved icons (M signed off on the _for_review candidates):
  - spr_icon_trait_blessed_thirst : badge-framed trait icon (pouring potion)
  - spr_icon_gold                 : frameless inline glyph (coin pile)
  - spr_icon_dust                 : frameless inline glyph (rune-dust pile)

Reuses gen_trait_icons.py's sprite/.yy/.yyp pipeline. Inline glyphs skip the
badge so they can sit next to gold/dust NUMBERS in reward lines (task #19).
"""
import os, sys
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_trait_icons import ROOT, SPRITES, fit_onto_badge, build_sprite, register_yyp, SZ

REVIEW = os.path.join(ROOT, "_for_review")


def fit_plain(art):
    """Trim transparent margins and fit into a 64x64 canvas, no badge."""
    bbox = art.getbbox()
    if bbox:
        art = art.crop(bbox)
    art.thumbnail((SZ, SZ), Image.LANCZOS)
    canvas = Image.new("RGBA", (SZ, SZ), (0, 0, 0, 0))
    canvas.alpha_composite(art, ((SZ - art.width) // 2, (SZ - art.height) // 2))
    return canvas


def main():
    jobs = [
        ("spr_icon_trait_blessed_thirst", "icon_blessed_thirst_candidate.png", True),
        ("spr_icon_gold",                 "icon_gold_coins_candidate.png",     False),
        ("spr_icon_dust",                 "icon_rune_dust_candidate.png",      False),
    ]
    names = []
    for spr_name, src, badged in jobs:
        art = Image.open(os.path.join(REVIEW, src)).convert("RGBA")
        img = fit_onto_badge(art) if badged else fit_plain(art)
        build_sprite(spr_name, img)
        names.append(spr_name)
        print("built", spr_name, "<-", src)
    n = register_yyp(names)
    print("registered %d new sprites in .yyp (of %d built)" % (n, len(names)))


if __name__ == "__main__":
    main()
