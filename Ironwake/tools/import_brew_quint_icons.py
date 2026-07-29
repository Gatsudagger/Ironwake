#!/usr/bin/env python
"""
Import the 07-28 Sable cauldron icon picks (M-approved: brew_15 + quint_15).

    _for_review/brew_quint_icons/brew_15.png  -> spr_icon_consumable_chaotic_brew
                                                 (EXISTING sprite: PNG-only overwrite,
                                                 composite + layer, no .yy changes)
    _for_review/brew_quint_icons/quint_15.png -> spr_icon_consumable_quintessence
                                                 (NEW resource: .yy + .yyp register.
                                                 GM MUST BE CLOSED for this one.)

Run from repo root:  python tools/import_brew_quint_icons.py
"""
import os, sys
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_trait_icons import ROOT, SPRITES, build_sprite, register_yyp

SRC = os.path.join(ROOT, "_for_review", "brew_quint_icons")


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


def load64(name):
    im = Image.open(os.path.join(SRC, name)).convert("RGBA")
    if im.size != (64, 64):
        im = im.resize((64, 64), Image.NEAREST)
    return im


print("Chaotic Brew (existing sprite, PNG swap):")
overwrite_existing("spr_icon_consumable_chaotic_brew", load64("brew_15.png"))

print("Quintessence (new sprite + yyp register - GM must be closed):")
qname = "spr_icon_consumable_quintessence"
if os.path.isdir(os.path.join(SPRITES, qname)):
    print(f"  {qname} already exists - skipped")
else:
    build_sprite(qname, load64("quint_15.png"))
    register_yyp([qname])
    print(f"  built + registered {qname}")

print("Done.")
