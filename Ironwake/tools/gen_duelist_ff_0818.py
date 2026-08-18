#!/usr/bin/env python
"""08-18 (M: "ashen duelist looked very low resolution"): FF-style re-author of the four
Ashen Duelist tier sprites at the shipped enemy density - the exact 08-16 enemy recipe
(create_image_pro, 64x64, style = _refs/style_ff_single.png, character base = the current
tier sprite tight-cropped 3x nearest, 16 candidates / ~20 gens per call).
  python tools/gen_duelist_ff_0818.py submit
  python tools/gen_duelist_ff_0818.py poll      # download + SHEET_<tier>.png
Output: _for_review/duelist_ff_0818/  (JOBS.json, <tier>_ff_<i>.png, SHEET_<tier>.png)
"""
import os, sys, json, glob, io, urllib.request
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ffgen
from PIL import Image, ImageDraw

ROOT = ffgen.ROOT
REVIEW = os.path.join(ROOT, "_for_review", "duelist_ff_0818")
JOBS = os.path.join(REVIEW, "JOBS.json")
STYLE = os.path.join(ROOT, "_for_review", "enemies_hd_0816", "_refs", "style_ff_single.png")
os.makedirs(REVIEW, exist_ok=True)

TIERS = {
    "t0": ("spr_ashen_duelist",    "the Ashen Duelist - a lean gothic fencer in black plate and a plumed wide hat, long rapier held low, cold teal soul-glow at the face and hands, tattered dark cloak"),
    "t1": ("spr_ashen_duelist_t1", "the Ashen Duelist, scarred veteran - the same fencer, cloak notched and torn, blade nicked, teal glow, dark plate"),
    "t2": ("spr_ashen_duelist_t2", "the Ashen Duelist, trophy-taker - the same fencer with a great grey cloak, gold and red trophy trim on his guard, teal glow, dark plate"),
    "t3": ("spr_ashen_duelist_t3", "the Ashen Duelist, ash-wreathed - the same fencer barely a man any more, embers and ash drifting off him, brighter teal glow, blackened plate"),
}


def base_png(spr):
    f = sorted(glob.glob(os.path.join(ROOT, "sprites", spr, "*.png")))[0]
    im = Image.open(f).convert("RGBA")
    im = im.crop(im.getbbox())
    im = im.resize((im.width * 3, im.height * 3), Image.NEAREST)
    out = os.path.join(REVIEW, "_base_%s.png" % spr)
    im.save(out)
    return out


def prompt(desc):
    return ("Pixel art enemy sprite in EXACTLY the same style as the reference sprite (same game): "
            "16-bit tactics RPG density, bold black outline, flat limited colours, chunky pixels, simple readable shapes. "
            "Subject: %s. Single figure, 3/4-FRONT view facing slightly LEFT toward the viewer, whole body visible, "
            "about 54 pixels tall on the canvas. ONLY the figure on a fully transparent background - no ground, no shadow, "
            "no props, no text. Dark medieval gothic fantasy." % desc)


def submit():
    jobs = json.load(open(JOBS)) if os.path.exists(JOBS) else {}
    for tier, (spr, desc) in TIERS.items():
        if tier in jobs and jobs[tier]:
            print("skip", tier, jobs[tier]); continue
        base = base_png(spr)
        args = {"description": prompt(desc), "width": 64, "height": 64, "no_background": True,
                "style_image_base64": ffgen.b64file(STYLE),
                "reference_images": json.dumps([{"base64": ffgen.b64file(base),
                                                 "usage": "character base - the exact same character, outfit and colours"}])}
        txt, _ = ffgen.call_tool("create_image_pro", args)
        jid = None
        for tok in txt.replace('"', ' ').replace(',', ' ').split():
            if len(tok) == 36 and tok.count('-') == 4: jid = tok; break
        jobs[tier] = jid
        print(tier, jid or txt[:200])
        json.dump(jobs, open(JOBS, "w"), indent=1)


def poll():
    jobs = json.load(open(JOBS))
    for tier, jid in jobs.items():
        if not jid: continue
        if glob.glob(os.path.join(REVIEW, "%s_ff_*.png" % tier)):
            print(tier, "already downloaded"); continue
        txt, _ = ffgen.call_tool("get_image", {"job_id": jid})
        if "completed" not in txt.lower():
            print(tier, "status:", txt[:120].replace("\n", " | ")); continue
        imgs = []
        for i in range(32):
            url = "https://api.pixellab.ai/mcp/images/%s/download?index=%d" % (jid, i)
            try:
                data = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "ironwake"}), timeout=60).read()
            except Exception:
                break
            fp = os.path.join(REVIEW, "%s_ff_%d.png" % (tier, i)); open(fp, "wb").write(data)
            imgs.append(Image.open(fp).convert("RGBA"))
        if not imgs: print(tier, "no images"); continue
        S = 3; cols = 8; rows = (len(imgs) + cols - 1) // cols; cell = 64 * S + 12
        sheet = Image.new("RGBA", (cols * cell + 12, rows * (cell + 18) + 12), (28, 30, 40, 255))
        d = ImageDraw.Draw(sheet)
        for i, im in enumerate(imgs):
            x = 12 + (i % cols) * cell; y = 12 + (i // cols) * (cell + 18)
            big = im.resize((64 * S, 64 * S), Image.NEAREST)
            sheet.paste(big, (x, y), big)
            d.text((x + 2, y + 64 * S + 2), "%s #%d" % (tier, i), fill=(230, 230, 230, 255))
        sheet.save(os.path.join(REVIEW, "SHEET_%s.png" % tier))
        print(tier, len(imgs), "candidates -> SHEET_%s.png" % tier)


if __name__ == "__main__":
    {"submit": submit, "poll": poll}[sys.argv[1]]()
