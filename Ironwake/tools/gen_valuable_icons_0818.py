#!/usr/bin/env python
"""08-18: icons for the 5 sell-only VALUABLES (M: "high quality pixel art graphics").
Recipe = the shipped icon recipe: create_1_direction_object, 64x64, style_images = 6 shipped
loot/consumable icons (genie lamp, medallion, emberheart, signet ring, beggar's fortune,
ley battery). 16 candidates per item (~20 gens). Review sheet per item lands in
_for_review/valuables_0818/SHEET_<id>.png for M's pick; then import via the usual .yy clone.
  python tools/gen_valuable_icons_0818.py submit      # queue 5 objects
  python tools/gen_valuable_icons_0818.py poll        # download candidates + build sheets
"""
import os, sys, json, re, urllib.request, io
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ffgen
from PIL import Image, ImageDraw

ROOT = ffgen.ROOT
REVIEW = os.path.join(ROOT, "_for_review", "valuables_0818")
JOBS = os.path.join(REVIEW, "JOBS.json")
os.makedirs(REVIEW, exist_ok=True)

STYLE_REFS = ["spr_icon_consumable_genie_lamp", "spr_icon_amulet_medallion", "spr_icon_amulet_emberheart",
              "spr_icon_ring_signet", "spr_icon_legendary_beggars_fortune", "spr_icon_consumable_ley_battery"]

ITEMS = {
    "tarnished_locket": "a tarnished silver oval locket on a thin chain, hinged open, the tiny portrait inside scratched out; dark gothic fantasy loot icon",
    "silver_reliquary": "a small ornate silver reliquary box with gothic filigree and a little glass window showing a finger bone inside; dark fantasy loot icon",
    "sovereigns_signet": "a heavy gold signet ring with a dark engraved royal crest, ancient worn seal; dark fantasy loot icon",
    "star_iron_idol": "a squat crude idol statuette of dark meteoric iron with a primitive face, faint blue-white star glints in the metal; dark fantasy loot icon",
    "crown_shard": "a jagged broken shard of an iron crown, one point still set with a dark red gem, faint ember glow at the broken edge; dark fantasy loot icon",
}


def _ref_b64():
    out = []
    for r in STYLE_REFS:
        d = os.path.join(ROOT, "sprites", r)
        png = [f for f in os.listdir(d) if f.endswith(".png")][0]
        out.append({"base64": ffgen.b64file(os.path.join(d, png)), "format": "png"})
    return out


def submit():
    jobs = json.load(open(JOBS)) if os.path.exists(JOBS) else {}
    refs = _ref_b64()
    for key, desc in ITEMS.items():
        if key in jobs:
            print("skip", key, jobs[key]); continue
        txt, _ = ffgen.call_tool("create_1_direction_object",
                                 {"description": desc, "view": "top-down", "style_images": refs})
        oid = None
        for tok in txt.replace('"', ' ').replace(',', ' ').split():
            if len(tok) == 36 and tok.count('-') == 4: oid = tok; break
        jobs[key] = oid or txt[:200]
        print(key, oid or txt[:200])
        json.dump(jobs, open(JOBS, "w"), indent=1)


def _get(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=60).read()


def poll():
    jobs = json.load(open(JOBS))
    for key, oid in jobs.items():
        txt, res = ffgen.call_tool("get_object", {"object_id": oid, "include_preview": False})
        urls = re.findall(r'https://[^\s"\)\]]+', txt)
        urls = [u for u in urls if "download" in u or u.endswith(".png")]
        if not urls:
            print(key, "status:", txt[:160].replace("\n", " | ")); continue
        imgs = []
        for i, u in enumerate(urls):
            try:
                im = Image.open(io.BytesIO(_get(u))).convert("RGBA")
            except Exception as e:
                print("  dl fail", u, e); continue
            im.save(os.path.join(REVIEW, "%s_%02d.png" % (key, i)))
            imgs.append(im)
        if not imgs: continue
        S = 3; cols = 8; rows = (len(imgs) + cols - 1) // cols
        cell = 64 * S + 12
        sheet = Image.new("RGBA", (cols * cell + 12, rows * (cell + 18) + 12), (28, 30, 40, 255))
        d = ImageDraw.Draw(sheet)
        for i, im in enumerate(imgs):
            x = 12 + (i % cols) * cell; y = 12 + (i // cols) * (cell + 18)
            big = im.resize((64 * S, 64 * S), Image.NEAREST)
            sheet.paste(big, (x, y), big)
            d.text((x + 2, y + 64 * S + 2), "%s #%d" % (key, i), fill=(230, 230, 230, 255))
        sheet.save(os.path.join(REVIEW, "SHEET_%s.png" % key))
        print(key, len(imgs), "candidates ->", "SHEET_%s.png" % key)


if __name__ == "__main__":
    {"submit": submit, "poll": poll}[sys.argv[1]]()
