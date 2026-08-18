#!/usr/bin/env python
"""08-17 GM-CLOSED import of FF-style (64px, tactics-density) species sprites, M-picked from
_for_review/species_ff_0817/<species>/<stage>_<dir>_r<round>_<idx>.png sheets.
Builds spr_pet_<species>_<stage>_<dir> (single frame, alpha bbox, top-left origin) from the
spr_skeleton_soldier_ff template, registers them in Ironwake.yyp, and appends the bare refs to
the __sprite_includes anti-strip block in obj_game_controller/Create_0.gml (pet_sprite resolves
by STRING). Idempotent - re-run after adding rows. Run from repo root with GameMaker CLOSED.
"""
import os, sys, re, glob
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gm_import
ROOT   = gm_import.ROOT
REVIEW = os.path.join(ROOT, "_for_review", "species_ff_0817")
CREATE = os.path.join(ROOT, "objects", "obj_game_controller", "Create_0.gml")
TEMPLATE = "spr_skeleton_soldier_ff"
STAGES = ["baby", "youngadult", "adult"]
DIRS   = ["s", "e"]

# species -> { "<stage>_<dir>": "<file in the species folder>" }   (M's picks; east = mine unless noted)
PICKS = {
    # M-final 08-17: adult_e = the SAME still as adult_s (r1 15 already faces right; M: "use it
    # since it's facing right anyway" - a separate east roll read as a different bear).
    "cairn_bear": {
    # M 08-17 late: ONE still per stage feeds BOTH s and e (the pro stills are all ~3/4
    # right-facing anyway; separate rolls per facing gave "two entirely different bears").
        "adult_s": "adult_s_r1_15.png",      "adult_e": "adult_s_r1_15.png",
        "youngadult_s": "youngadult_s_r0_0.png", "youngadult_e": "youngadult_s_r0_0.png",
        "baby_s": "baby_s_r2_4.png",         "baby_e": "baby_s_r2_4.png",
    },
}

def include_names(names):
    text = open(CREATE, "r", encoding="utf-8").read()
    missing = [n for n in names if re.search(r'\b%s\b' % re.escape(n), text) is None]
    if not missing:
        print("includes: nothing new"); return
    marker = "    // 08-17 FF-style species (tools/import_species_ff_0817.py) - string-resolved by pet_sprite.\n"
    if marker not in text:
        # insert the marker block right before the closing of the includes array
        idx = text.index("\n];", text.index("global.__sprite_includes = ["))
        text = text[:idx] + "\n" + marker + text[idx:]
    lines = "".join("    %s,\n" % n for n in missing)
    idx = text.index(marker) + len(marker)
    text = text[:idx] + lines + text[idx:]
    open(CREATE, "w", encoding="utf-8", newline="\n").write(text)
    print("includes: +%d" % len(missing))

if __name__ == "__main__":
    names = []
    for sp, picks in PICKS.items():
        for st in STAGES:
            for d in DIRS:
                key = "%s_%s" % (st, d)
                if key not in picks:
                    continue
                name = "spr_pet_%s_%s_%s" % (sp, st, d)
                # Idle animation (08-17 late, M: everything that ships needs one): if
                # ffgen `anim` frames exist for this stage/dir, build the ANIMATED sprite
                # (frame 0 = the still, then the 8 generated frames; last == first so the
                # loop is seamless) - else the single still.
                anim = sorted(glob.glob(os.path.join(REVIEW, sp, "%s_%s_ANIM_*.png" % (st, d))),
                              key=lambda f: int(f.rsplit("_", 1)[1][:-4]))
                if anim:
                    from PIL import Image
                    frames = [Image.open(f).convert("RGBA") for f in anim[:-1]]   # drop the pinned duplicate last frame
                    gm_import.build_anim_sprite(name, frames)
                else:
                    gm_import.build_sprite(name, os.path.join(REVIEW, sp, picks[key]), TEMPLATE)
                names.append(name)
    gm_import.register(names)
    include_names(names)
    print("\n".join(names))
