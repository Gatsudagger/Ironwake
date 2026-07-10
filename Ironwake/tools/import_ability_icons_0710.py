#!/usr/bin/env python
"""
Import the 07-10 M-approved icon set from _for_review (style-audit re-roll round):

  7 ability icons (D SS4 abilities):
    - 192px ui_asset gens (white/transparent margins outside the drawn frame) go
      through recrop_ability_icons.crop_full_bleed + 64px nearest, same as the
      arcanist melee kit: hoarfrost_lance, glacial_ward, soul_engine, galvanize.
    - 64px object-pipeline gens (style_images route, already final size + full
      bleed) import as-is: static_arc, winters_bite, devils_flip.
  2 rune gem icons (64px, transparent bg like the shipped 18): cascade, bastion.
    NOTE: gems resolve by string (rune_icon_sprite) - they must also be added to
    global.__sprite_includes in obj_game_controller Create_0 (done by hand).

  Splash: shrine_splash_ancient_altar_v2_candidate.png (400x224 centered rune
  tablet) PNG-swaps in place over spr_shrine_splash_ancient_altar (frame +
  layer PNGs, no .yy churn - same idiom as recrop_ability_icons.swap).

Reuses gen_trait_icons.build_sprite/register_yyp. Idempotent: skips sprites
whose folder already exists. Run from repo root:
    python tools/import_ability_icons_0710.py
"""
import os, sys
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_trait_icons import ROOT, SPRITES, build_sprite, register_yyp
from recrop_ability_icons import crop_full_bleed

REVIEW = os.path.join(ROOT, "_for_review")

# (sprite name, candidate file, needs full-bleed recrop from 192px)
JOBS = [
    ("spr_ability_hoarfrost_lance", "ability_hoarfrost_lance_candidate2.png", True),
    ("spr_ability_glacial_ward",    "ability_glacial_ward_candidate2.png",    True),
    ("spr_ability_soul_engine",     "ability_soul_engine_candidate2.png",     True),
    ("spr_ability_galvanize",       "ability_galvanize_candidate2.png",       True),
    ("spr_ability_static_arc",      "ability_static_arc_candidate2.png",      False),
    ("spr_ability_winters_bite",    "ability_winters_bite_candidate2.png",    False),
    ("spr_ability_devils_flip",     "ability_devils_flip_candidate2.png",     False),
    ("spr_icon_rune_cascade",       "icon_rune_cascade_candidate.png",        False),
    ("spr_icon_rune_bastion",       "icon_rune_bastion_candidate.png",        False),
]

SPLASH_SRC = "shrine_splash_ancient_altar_v2_candidate.png"
SPLASH_SPRITE = "spr_shrine_splash_ancient_altar"


def load_64(src_path, recrop):
    if recrop:
        return crop_full_bleed(src_path).resize((64, 64), Image.NEAREST)
    img = Image.open(src_path).convert("RGBA")
    if img.size != (64, 64):
        img = img.resize((64, 64), Image.NEAREST)
    return img


def main():
    names = []
    for spr_name, src, recrop in JOBS:
        if os.path.isdir(os.path.join(SPRITES, spr_name)):
            print("skip (exists):", spr_name)
            continue
        img = load_64(os.path.join(REVIEW, src), recrop)
        build_sprite(spr_name, img)
        names.append(spr_name)
        print("built", spr_name, "<-", src)
    n = register_yyp(names)
    print("registered %d new sprites in .yyp (of %d built)" % (n, len(names)))

    # Splash swap-in-place (keeps the existing .yy / GUIDs).
    splash = Image.open(os.path.join(REVIEW, SPLASH_SRC)).convert("RGBA")
    assert splash.size == (400, 224), splash.size
    sdir = os.path.join(SPRITES, SPLASH_SPRITE)
    targets = [os.path.join(dp, f) for dp, _, fs in os.walk(sdir) for f in fs if f.endswith(".png")]
    for t in targets:
        splash.save(t)
    print("%s: swapped %d png(s)" % (SPLASH_SPRITE, len(targets)))


if __name__ == "__main__":
    main()
