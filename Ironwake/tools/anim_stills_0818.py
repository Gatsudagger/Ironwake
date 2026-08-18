#!/usr/bin/env python
"""08-18 (M YES: "animate all 15 as is"): idle animations for the 15 static species that
ship as stills (mirror_e_from_s SPECIES minus wispfox, already animated). Same pipeline as
wispfox: pad the shipped _s still to a 64x64 canvas (feet on the same baseline), animate_image
8 frames pinned first==last (seamless), 1 gen each -> 45 gens. Import rebuilds spr_pet_<sp>_<st>_s
as an 8-frame @8fps sprite (bottom-center origin, alpha bbox) and clones it to _e.
  python tools/anim_stills_0818.py submit | poll | import [species ...] | sheet
GameMaker must be REOPENED after import (frames/.yy change under it).
"""
import os, sys, json, glob
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ffgen, gm_import
from PIL import Image

ROOT = ffgen.ROOT
REVIEW = os.path.join(ROOT, "_for_review", "stills_anim_0818")
os.makedirs(REVIEW, exist_ok=True)
ffgen.REVIEW = REVIEW
ffgen.ANIMS = os.path.join(REVIEW, "ANIMS.json")

SPECIES = ["ashjaw_lynx", "gravefox", "frostmarten", "snowmaw", "permafrost_toad", "icewing_skua",
           "witchwood_fawn", "fathom_squid", "lantern_wyrm", "deepclaw", "griefwisp", "sluice_otter",
           "graftling", "thornlet", "whispervine"]
STAGES = ["baby", "youngadult", "adult"]
CANVAS = 64


def still64(sp, st):
    """Shipped _s still padded onto a 64x64 canvas, bottom-centred (feet at y=60)."""
    d = os.path.join(ROOT, "sprites", "spr_pet_%s_%s_s" % (sp, st))
    f = sorted(glob.glob(os.path.join(d, "*.png")))[0]
    im = Image.open(f).convert("RGBA")
    im = im.crop(im.getbbox())
    if im.width > CANVAS - 4 or im.height > CANVAS - 4:
        sc = min((CANVAS - 4) / im.width, (CANVAS - 4) / im.height)
        im = im.resize((max(1, round(im.width * sc)), max(1, round(im.height * sc))), Image.NEAREST)
    out = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    out.paste(im, ((CANVAS - im.width) // 2, CANVAS - 4 - im.height), im)
    p = os.path.join(REVIEW, "%s_%s_still64.png" % (sp, st))
    out.save(p)
    return p


def submit():
    rows = json.load(open(ffgen.ANIMS)) if os.path.exists(ffgen.ANIMS) else []
    have = {(r["species"], r["stage"]) for r in rows if r.get("job")}
    for sp in SPECIES:
        for st in STAGES:
            if (sp, st) in have:
                print("skip", sp, st); continue
            ffgen.anim_submit(sp, st, "s", still64(sp, st))


def poll():
    ffgen.anim_poll()
    rows = json.load(open(ffgen.ANIMS))
    done = sum(1 for r in rows if r["done"])
    print("%d/%d done" % (done, len(rows)))


def frames_for(sp, st):
    fs = sorted(glob.glob(os.path.join(REVIEW, sp, "%s_s_ANIM_*.png" % st)),
                key=lambda p: int(p.rsplit("_", 1)[1][:-4]))
    return [Image.open(f).convert("RGBA") for f in fs]


def do_import(only=None):
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    import mirror_e_from_s
    n = 0
    for sp in SPECIES:
        if only and sp not in only: continue
        for st in STAGES:
            fr = frames_for(sp, st)
            if len(fr) < 4:
                print("NO FRAMES", sp, st, len(fr)); continue
            # frame 0 is the still itself; drop a duplicated closing frame if the API returned 9
            if len(fr) == 9: fr = fr[:8]
            name_s = "spr_pet_%s_%s_s" % (sp, st)
            gm_import.build_anim_sprite(name_s, fr, fps=8.0)
            mirror_e_from_s.clone(name_s, "spr_pet_%s_%s_e" % (sp, st))
            n += 1
            print("imported", name_s, len(fr), "frames (+ _e clone)")
    print("done", n, "sprites")


def sheet():
    """One contact sheet: every species x stage strip, 8 frames, for the seamless-loop QC."""
    from PIL import ImageDraw
    rows = []
    for sp in SPECIES:
        for st in STAGES:
            fr = frames_for(sp, st)
            if fr: rows.append((sp + " " + st, fr[:8]))
    S = 2
    W = 8 * (CANVAS * S + 4) + 220
    H = len(rows) * (CANVAS * S + 6)
    im = Image.new("RGBA", (W, H), (40, 40, 48, 255)); d = ImageDraw.Draw(im)
    for i, (lbl, fr) in enumerate(rows):
        y = i * (CANVAS * S + 6)
        d.text((4, y + 4), lbl, fill=(230, 230, 230))
        for j, f in enumerate(fr):
            im.alpha_composite(f.resize((CANVAS * S, CANVAS * S), Image.NEAREST), (220 + j * (CANVAS * S + 4), y))
    im.save(os.path.join(REVIEW, "SHEET_ALL.png")); print("sheet", im.size)


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[0] == "submit": submit()
    elif a[0] == "poll": poll()
    elif a[0] == "import": do_import(a[1:] or None)
    elif a[0] == "sheet": sheet()
