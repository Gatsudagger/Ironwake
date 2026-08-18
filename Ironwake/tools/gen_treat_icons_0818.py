#!/usr/bin/env python
"""08-18 (M): unique icons for the six FAVORED TREATS (Ember Chestnut, Grave-Lily Sugar, Moonpetal
Wafer, Brine Jerky, Frost-Root Chew, Iron Grub) - "the name of the food should match its visual".
Recipe = the feed-icon recipe: create_1_direction_object, style_images = shipped pet feed icons
(85px pref icons), 16 candidates (~20 gens) per treat. Sheets -> _for_review/treat_icons_0818/.
  python tools/gen_treat_icons_0818.py submit | poll
"""
import os, sys, json, glob, io, re, urllib.request
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ffgen
from PIL import Image, ImageDraw

ROOT = ffgen.ROOT
REVIEW = os.path.join(ROOT, "_for_review", "treat_icons_0818")
JOBS = os.path.join(REVIEW, "JOBS.json")
os.makedirs(REVIEW, exist_ok=True)

STYLE_REFS = ["spr_pet_feed_pref_luna_moth", "spr_pet_feed_pref_saber_hound", "spr_pet_feed_pref_bone_stag",
              "spr_pet_feed_pref_gloomtoad", "spr_pet_feed_treat_honey", "spr_pet_feed_hearty_roast"]

ITEMS = {
    "treat_ember_nut":   "a roasted chestnut cracked open, its shell glowing orange-red like a forge coal with tiny embers; pet food item icon, dark fantasy",
    "treat_grave_lily":  "a small twist of parchment spilling pale sugared lily petals dusted with white sugar; pet treat item icon, dark fantasy",
    "treat_moon_moth":   "a thin round wafer with a faint silvery-blue moon-petal shimmer, a crescent pressed into it; pet treat item icon, dark fantasy",
    "treat_brine_jerky": "a strip of dark salt-cured eel jerky, glistening, tied with twine, a few salt crystals; pet treat item icon, dark fantasy",
    "treat_frost_root":  "a gnarled pale-blue tundra root chew, frost-rimed, knobbly and hard; pet treat item icon, dark fantasy",
    "treat_iron_grub":   "a fat plump grub with a metallic iron-grey banded body and a coppery sheen, curled up; pet treat item icon, dark fantasy",
}


def _refs():
    out = []
    for r in STYLE_REFS:
        d = os.path.join(ROOT, "sprites", r)
        png = [f for f in os.listdir(d) if f.endswith(".png")][0]
        im = Image.open(os.path.join(d, png)).convert("RGBA")
        if im.size != (85, 85):
            im = im.resize((85, 85), Image.NEAREST)
        buf = io.BytesIO(); im.save(buf, "PNG")
        import base64
        out.append({"base64": base64.b64encode(buf.getvalue()).decode(), "format": "png"})
    return out


def submit():
    jobs = json.load(open(JOBS)) if os.path.exists(JOBS) else {}
    refs = _refs()
    for key, desc in ITEMS.items():
        if key in jobs and jobs[key]:
            print("skip", key); continue
        txt, _ = ffgen.call_tool("create_1_direction_object", {"description": desc, "view": "top-down", "style_images": refs})
        oid = None
        for tok in txt.replace('"', ' ').replace(',', ' ').split():
            if len(tok) == 36 and tok.count('-') == 4: oid = tok; break
        jobs[key] = oid
        print(key, oid or txt[:200])
        json.dump(jobs, open(JOBS, "w"), indent=1)


def _get(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=60).read()


def poll():
    jobs = json.load(open(JOBS))
    done = 0
    for key, oid in jobs.items():
        if not oid: continue
        if os.path.exists(os.path.join(REVIEW, "SHEET_%s.png" % key)):
            done += 1; print(key, "done"); continue
        txt, _ = ffgen.call_tool("get_object", {"object_id": oid, "include_preview": False})
        urls = [u for u in re.findall(r'https://[^\s"\)\]]+', txt) if "download" in u or u.endswith(".png")]
        if not urls:
            print(key, "status:", txt[:120].replace("\n", " | ")); continue
        imgs = []
        for i, u in enumerate(urls):
            try:
                im = Image.open(io.BytesIO(_get(u))).convert("RGBA")
            except Exception as e:
                print("  dl fail", e); continue
            im.save(os.path.join(REVIEW, "%s_%02d.png" % (key, i))); imgs.append(im)
        if not imgs: continue
        S = 3; cols = 8; rows = (len(imgs) + cols - 1) // cols; cell = 85 * S + 12
        sheet = Image.new("RGBA", (cols * cell + 12, rows * (cell + 18) + 12), (28, 30, 40, 255))
        d = ImageDraw.Draw(sheet)
        for i, im in enumerate(imgs):
            x = 12 + (i % cols) * cell; y = 12 + (i // cols) * (cell + 18)
            big = im.resize((85 * S, 85 * S), Image.NEAREST); sheet.paste(big, (x, y), big)
            d.text((x + 2, y + 85 * S + 2), "%s #%d" % (key, i), fill=(230, 230, 230, 255))
        sheet.save(os.path.join(REVIEW, "SHEET_%s.png" % key)); done += 1
        print(key, len(imgs), "candidates")
    print("DONE" if done == len([j for j in jobs.values() if j]) else "PENDING")


if __name__ == "__main__":
    {"submit": submit, "poll": poll}[sys.argv[1]]()
