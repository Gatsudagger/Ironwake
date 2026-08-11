#!/usr/bin/env python
"""
Import the 08-06/07 creature expansion sprites.

Sources = M-approved art in _for_review/creatures_0806:
    _FINAL_S/<species>_<stage>_s.png   -> spr_pet_<species>_<stage>_s
    _FINAL_E/<species>_<stage>_e.png   -> spr_pet_<species>_<stage>_e

Stages are baby / youngadult / adult, matching pet_sprite_key(). Adolescent
reuses the baby frame at 1.25x and Awakened reuses adult, so three authored
stages cover all five. Eggs are per egg-TYPE, not per species, so none here.

⚠ GAMEMAKER MUST BE FULLY CLOSED. GM rewrites Ironwake.yyp from memory on exit
and will silently drop anything registered behind its back.

Frames are padded to a square canvas so GM gets consistent sprite dimensions.
Idempotent: existing sprite folders are skipped.

Run from repo root:  python tools/import_creatures_0806.py
"""
import os
import sys
import uuid

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_trait_icons import ROOT, SPRITES, YY_TEMPLATE, register_yyp  # noqa: E402

REVIEW = os.path.join(ROOT, "_for_review", "creatures_0806")
SRC = {"s": os.path.join(REVIEW, "_FINAL_S"), "e": os.path.join(REVIEW, "_FINAL_E")}
STAGES = ("baby", "youngadult", "adult")


def species_of(fname, dirn):
    base = fname[:-4]
    for st in STAGES:
        suf = "_%s_%s" % (st, dirn)
        if base.endswith(suf):
            return base[: -len(suf)], st
    return None, None


def build_sprite(spr_name, img):
    """Write a single-frame GM sprite folder on a square canvas."""
    side = max(img.size)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(img, ((side - img.width) // 2, (side - img.height) // 2), img)

    sdir = os.path.join(SPRITES, spr_name)
    frame, layer, kfid = str(uuid.uuid4()), str(uuid.uuid4()), str(uuid.uuid4())
    os.makedirs(os.path.join(sdir, "layers", frame), exist_ok=True)
    canvas.save(os.path.join(sdir, frame + ".png"))
    canvas.save(os.path.join(sdir, "layers", frame, layer + ".png"))
    yy = YY_TEMPLATE.format(name=spr_name, frame=frame, layer=layer, kfid=kfid,
                            w=side, h=side, br=side - 1, bb=side - 1)
    with open(os.path.join(sdir, spr_name + ".yy"), "w", newline="\n") as f:
        f.write(yy)
    return side


def main():
    built, skipped, names = 0, 0, []
    for dirn, folder in SRC.items():
        if not os.path.isdir(folder):
            print("missing source folder:", folder)
            continue
        for fname in sorted(os.listdir(folder)):
            if not fname.endswith(".png"):
                continue
            sp, stage = species_of(fname, dirn)
            if not sp:
                print("  ?? unparsed:", fname)
                continue
            spr = "spr_pet_%s_%s_%s" % (sp, stage, dirn)
            if os.path.isdir(os.path.join(SPRITES, spr)):
                skipped += 1
                continue
            img = Image.open(os.path.join(folder, fname)).convert("RGBA")
            bbox = img.getbbox()
            if bbox:
                img = img.crop(bbox)
            build_sprite(spr, img)
            names.append(spr)
            built += 1
    added = register_yyp(names) if names else 0
    print("built %d sprites, skipped %d existing, registered %d in Ironwake.yyp"
          % (built, skipped, added))
    # Coverage report: which species will actually go live.
    live = {}
    for n in names:
        parts = n[len("spr_pet_"):].rsplit("_", 2)
        if len(parts) == 3:
            live.setdefault(parts[0], set()).add(parts[1] + "_" + parts[2])
    print("species covered:", len(live))
    for sp in sorted(live):
        if len(live[sp]) < 6:
            print("  partial:", sp, sorted(live[sp]))


if __name__ == "__main__":
    main()
