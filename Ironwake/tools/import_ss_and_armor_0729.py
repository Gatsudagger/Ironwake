#!/usr/bin/env python
"""
Import the 07-29 art round after M's picks:

  1. SS ability icons (EXISTING sprites - PNG-only overwrites, safe anytime):
       _for_review/ss_icons/{vanish,evasive_roll,death_snare,assassinate}_<pick>.png
       -> spr_ability_<name>, with the standard ring border transplanted from
          spr_ability_soul_shield (icon border rule: crop alpha bbox, resize to
          52, paste at (6,6), copy donor pixels where dist-to-edge < 6).

  2. Armor variant icons (NEW sprites - .yy + .yyp register, GM MUST BE CLOSED):
       _for_review/loot_variants/{robe,plate,leather,hood}_<pick>.png
       -> spr_icon_chest_robe_b/_c/_d..., spr_icon_chest_plate_b...,
          spr_icon_chest_leather_b..., spr_icon_helm_hood_b...
       ui_armor_icon_variant (scr_ui) hash-picks among base + _b.._f, so the
       resolvers need no further edits. AFTER running this, add the new sprite
       identifiers to global.__sprite_includes (obj_game_controller Create_0)
       or the compiler strips the string-referenced assets.

Edit PICKS below to M's chosen candidate numbers, then run from repo root:
    python tools/import_ss_and_armor_0729.py
"""
import os, sys
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_trait_icons import ROOT, SPRITES, build_sprite, register_yyp

# ---- M'S PICKS (candidate indices) -----------------------------------------
SS_PICKS = {          # ability sprite  ->  _for_review/ss_icons/<key>_<idx>.png
    "vanish":       14,   # M-approved 07-29
    "evasive_roll": 15,
    "death_snare":  7,
    "assassinate":  15,
}
# M 07-29: use ALL usable candidates (robe 0 is broken/noise - excluded),
# organized by RARITY BAND - plain art low, intricate/exotic high. Sprites are
# named <key>_<band>[n] (bands c/u/r/e/l); ui_armor_icon_variant (scr_ui)
# resolves by the item's rarity with fall-down to common.
ARMOR_PICKS = {       # family -> band -> candidate indices (import order = n)
    "robe":    { "c": [4, 7, 12],     "u": [1, 9, 11],    "r": [3, 5, 8, 13],
                 "e": [6, 10, 14],    "l": [2, 15] },
    "plate":   { "c": [1, 3, 10, 14], "u": [2, 9, 13],    "r": [7, 8, 11],
                 "e": [4, 5, 12],     "l": [0, 6, 15] },
    "leather": { "c": [2, 4, 10, 11], "u": [0, 1, 5, 9],  "r": [3, 8, 13],
                 "e": [7, 12, 15],    "l": [6, 14] },
    "hood":    { "c": [0, 2, 5, 10],  "u": [1, 4, 9, 12], "r": [6, 7, 8],
                 "e": [3, 11, 13],    "l": [14, 15] },
}
ARMOR_KEY = {"robe": "spr_icon_chest_robe", "plate": "spr_icon_chest_plate",
             "leather": "spr_icon_chest_leather", "hood": "spr_icon_helm_hood"}
# ----------------------------------------------------------------------------

SS_SRC    = os.path.join(ROOT, "_for_review", "ss_icons")
ARMOR_SRC = os.path.join(ROOT, "_for_review", "loot_variants")


def overwrite_existing(spr_name, img):
    """PNG-only frame swap for a sprite already registered in the .yyp."""
    sdir = os.path.join(SPRITES, spr_name)
    frames = [f for f in os.listdir(sdir) if f.endswith(".png")]
    assert len(frames) == 1, f"{spr_name}: expected 1 composite frame, got {frames}"
    comp = os.path.join(sdir, frames[0])
    img.save(comp)
    layers_root = os.path.join(sdir, "layers", frames[0][:-4])
    for lf in os.listdir(layers_root):
        if lf.endswith(".png"):
            img.save(os.path.join(layers_root, lf))
    print(f"  overwrote {spr_name} ({frames[0]})")


def load64(path):
    im = Image.open(path).convert("RGBA")
    if im.size != (64, 64):
        im = im.resize((64, 64), Image.NEAREST)
    return im


def donor_border():
    sdir = os.path.join(SPRITES, "spr_ability_soul_shield")
    p = [f for f in os.listdir(sdir) if f.endswith(".png")][0]
    return load64(os.path.join(sdir, p))


def apply_ring_border(img, donor):
    """Standard shipped frame: art inset to 52px, donor's 6px ring on top."""
    bbox = img.getbbox()
    art = img.crop(bbox) if bbox else img
    # shave any baked border the gen drew (inset 4px on the cropped art)
    w, h = art.size
    if w > 20 and h > 20:
        art = art.crop((4, 4, w - 4, h - 4))
    art = art.resize((52, 52), Image.NEAREST)
    out = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    out.paste(art, (6, 6))
    px_out, px_don = out.load(), donor.load()
    for y in range(64):
        for x in range(64):
            if min(x, y, 63 - x, 63 - y) < 6:
                px_out[x, y] = px_don[x, y]
    return out


# Two halves, run independently:
#   python tools/import_ss_and_armor_0729.py ss      (PNG swaps - safe anytime)
#   python tools/import_ss_and_armor_0729.py armor   (.yyp writes - GM CLOSED)
_mode = sys.argv[1] if len(sys.argv) > 1 else "ss"

if _mode == "ss":
    print("SS ability icons (existing sprites, PNG swap + ring border):")
    _donor = donor_border()
    for key, pick in SS_PICKS.items():
        if pick is None:
            print(f"  {key}: no pick - skipped")
            continue
        src = os.path.join(SS_SRC, f"{key}_{pick}.png")
        overwrite_existing(f"spr_ability_{key}", apply_ring_border(load64(src), _donor))
    print("Done.")
    sys.exit(0)

print("Armor variants (new sprites + yyp register - GM must be closed):")
_new = []
for fam, bands in ARMOR_PICKS.items():
    for band, idxs in bands.items():
        for j, idx in enumerate(idxs):
            name = f"{ARMOR_KEY[fam]}_{band}" + ("" if j == 0 else str(j + 1))
            if os.path.isdir(os.path.join(SPRITES, name)):
                print(f"  {name} already exists - skipped")
                continue
            build_sprite(name, load64(os.path.join(ARMOR_SRC, f"{fam}_{idx}.png")))
            _new.append(name)
if _new:
    register_yyp(_new)
    print(f"  built + registered {len(_new)} sprites")
    print("  REMINDER: add these to global.__sprite_includes (gc Create_0):")
    for n in _new:
        print(f"    {n},")

print("Done.")
