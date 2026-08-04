#!/usr/bin/env python
"""
Import the 07-29 icon-collision batch after M's approval (approved 07-29,
"i like them all all i approve"):

  _for_review/icon_collision_0729/<family>_<idx>.png
    -> 34 rarity-banded armor/jewelry sprites + 2 weapon variants (NEW sprites:
       .yy + .yyp register, GM MUST BE CLOSED).

Band sprites are named <key>_<band>[n] (bands c/u/r/e/l) and resolve through
ui_armor_icon_variant with no code edits. Jewelry/weapon names match the
string-resolved hooks already in scr_ui (spr_icon_ring_pact / _venom,
spr_icon_amulet_emberheart, spr_icon_weapon_sword_f / _wand_f).

boots_plate frames 0-7/10/11 carry a baked-in caption artifact under the art
(M: "squiggle at the bottom... trim that out"). scrub_caption() erases any
bottom content block that is separated from the main art by transparent rows.

AFTER running, add the printed identifiers to global.__sprite_includes
(obj_game_controller Create_0) - string-resolved sprites are stripped without.

Run from repo root with GameMaker CLOSED:
    python tools/import_icon_collision_0729.py
"""
import os, sys
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_trait_icons import ROOT, SPRITES, build_sprite, register_yyp

SRC = os.path.join(ROOT, "_for_review", "icon_collision_0729")

# ---- M'S APPROVED PICKS (family -> sprite name -> candidate idx) ------------
PICKS = {
    # helm_plate: Bone Cap -> _c, Tarnished Visor -> _c2 (catalog seq order),
    # Iron Skullcap -> _u, Thornwarden Helm -> _r (+_e epic view), _l reforge.
    "helm_plate": {
        "spr_icon_helm_plate_c":  0,  "spr_icon_helm_plate_c2": 3,
        "spr_icon_helm_plate_u":  7,  "spr_icon_helm_plate_r": 10,
        "spr_icon_helm_plate_e": 11,  "spr_icon_helm_plate_l": 14,
    },
    "gloves_plate": {
        "spr_icon_gloves_plate_c":  2, "spr_icon_gloves_plate_u":  4,
        "spr_icon_gloves_plate_r":  6, "spr_icon_gloves_plate_e": 11,
        "spr_icon_gloves_plate_l": 13,
    },
    "gloves_cloth": {
        "spr_icon_gloves_cloth_c":  1, "spr_icon_gloves_cloth_u":  5,
        "spr_icon_gloves_cloth_r":  7, "spr_icon_gloves_cloth_e": 10,
        "spr_icon_gloves_cloth_l": 12,
    },
    "boots_plate": {
        "spr_icon_boots_plate_c":  0, "spr_icon_boots_plate_u":  5,
        "spr_icon_boots_plate_r":  8, "spr_icon_boots_plate_e":  9,
        "spr_icon_boots_plate_l": 15,
    },
    "boots_leather": {
        "spr_icon_boots_leather_c":  0, "spr_icon_boots_leather_u":  3,
        "spr_icon_boots_leather_r":  7, "spr_icon_boots_leather_e": 10,
        "spr_icon_boots_leather_l": 13,
    },
    "chest_void": {
        "spr_icon_chest_void_c":  1, "spr_icon_chest_void_u":  5,
        "spr_icon_chest_void_r":  7, "spr_icon_chest_void_e":  9,
        "spr_icon_chest_void_l": 15,
    },
    "jewelry": {
        "spr_icon_amulet_emberheart": 2,
        "spr_icon_ring_venom":        5,
        "spr_icon_ring_pact":         9,
    },
    "weapons6": {
        "spr_icon_weapon_sword_f": 9,
        "spr_icon_weapon_wand_f":  8,
    },
}
# ----------------------------------------------------------------------------


def load64(path):
    im = Image.open(path).convert("RGBA")
    if im.size != (64, 64):
        im = im.resize((64, 64), Image.NEAREST)
    return im


def scrub_caption(img):
    """Erase a caption artifact: any bottom content block separated from the
    main art by >=2 fully transparent rows. No-op on clean frames."""
    px = img.load()
    w, h = img.size
    content = [any(px[x, y][3] > 0 for x in range(w)) for y in range(h)]
    # contiguous content blocks as (top, bottom) inclusive
    blocks, start = [], None
    for y in range(h):
        if content[y] and start is None:
            start = y
        elif not content[y] and start is not None:
            blocks.append((start, y - 1)); start = None
    if start is not None:
        blocks.append((start, h - 1))
    if len(blocks) < 2:
        return img
    main = max(blocks, key=lambda b: b[1] - b[0])
    erased = 0
    for (top, bot) in blocks:
        if (top, bot) == main or bot <= main[1]:
            continue          # only blocks BELOW the main art are captions
        if top - main[1] >= 2:
            for y in range(top, bot + 1):
                for x in range(w):
                    px[x, y] = (0, 0, 0, 0)
            erased += 1
    if erased:
        print("    (caption scrubbed: %d block%s)" % (erased, "s" if erased > 1 else ""))
    return img


print("Icon-collision batch (new sprites + yyp register - GM must be closed):")
_new = []
for fam, entries in PICKS.items():
    for spr_name, idx in entries.items():
        if os.path.isdir(os.path.join(SPRITES, spr_name)):
            print(f"  {spr_name} already exists - skipped")
            continue
        img = load64(os.path.join(SRC, f"{fam}_{idx}.png"))
        print(f"  {spr_name}  <-  {fam}_{idx}.png")
        img = scrub_caption(img)
        build_sprite(spr_name, img)
        _new.append(spr_name)

if _new:
    register_yyp(_new)
    print(f"  built + registered {len(_new)} sprites")
    print("  REMINDER: add these to global.__sprite_includes (gc Create_0):")
    for n in _new:
        print(f"    {n},")
print("Done.")
