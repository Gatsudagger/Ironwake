#!/usr/bin/env python
"""08-21 egg re-author driver (plain eggs, no stands). Uses ffgen's HTTP JSON-RPC bridge so
style anchors never pass through chat. Recipe: create_1_direction_object, sidescroller view,
style_images = 2 shipped 124px pet adults (ironshell beetle + lockjaw turtle), 4 candidates.
Usage:
  python tools/egggen.py submit <type>      # queue one egg type
  python tools/egggen.py poll               # download finished candidates -> sheet
Jobs in _for_review/eggs_0821/JOBS.json
"""
import os, sys, json, io, base64, urllib.request
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ffgen import call_tool, b64file
from PIL import Image, ImageDraw
ROOT   = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REVIEW = os.path.join(ROOT, "_for_review", "eggs_0821"); os.makedirs(REVIEW, exist_ok=True)
JOBS   = os.path.join(REVIEW, "JOBS.json")
SPR    = os.path.join(ROOT, "sprites")
ANCHORS = ["spr_pet_ironshell_beetle_adult_s", "spr_pet_lockjaw_turtle_adult_s"]

BASE = ("a single plain bird-like egg standing upright, alone, on NOTHING - no stand, no nest, no base, "
        "no cradle, no ground, transparent background. Believable egg proportions: rounded bottom, gently "
        "narrower top. {shell} Dark fantasy gothic pixel art, clean dark outline, soft top-left light, "
        "3-4 tone shading, no glow effects. Centered, fills most of the canvas.")
EGGS = {
 "gilded":  "Smooth cream-white shell with thin delicate gold veining and a few tiny gold flecks, subtle warm sheen.",
 "fortune": "Smooth deep moss-green shell with a faint pale-green clover-leaf dapple of soft spots.",
 "savage":  "Deep blood-red shell, slightly narrower sharper top, dark crimson mottling like dried blood.",
 "tender":  "Soft peach-cream shell with fine downy pale speckles, warm and gentle.",
 "vital":   "Dark crimson-black shell with faint thin pulsing red veins beneath the surface.",
 "ley":     "Deep indigo-blue shell with thin pale rune-like rings circling it.",
 "scholar": "Parchment-tan shell with small ink-black freckles scattered like writing.",
 "dust":    "Dusty violet-grey shell with a gritty mineral speckle texture.",
 "warding": "Slate-grey shell with a faintly faceted plated surface like riveted iron.",
 "keen":    "Pale steel-blue shell with a slightly pointed apex and a cold sharp highlight.",
}

def anchors():
    out = []
    for a in ANCHORS:
        d = os.path.join(SPR, a); f = sorted(x for x in os.listdir(d) if x.endswith(".png"))[0]
        out.append({"base64": b64file(os.path.join(d, f)), "format": "png", "type": "base64"})
    return out

def load(): return json.load(open(JOBS)) if os.path.exists(JOBS) else []
def save(j): json.dump(j, open(JOBS, "w"), indent=1)

def submit(t):
    txt, _ = call_tool("create_1_direction_object", {"description": BASE.format(shell=EGGS[t]),
                        "view": "sidescroller", "style_images": anchors()})
    print(txt)
    oid = None
    for tok in txt.replace('"', ' ').replace(':', ' ').split():
        if len(tok) == 36 and tok.count("-") == 4: oid = tok; break
    j = load(); j.append({"type": t, "object_id": oid, "done": False}); save(j)
    print("queued", t, oid)

def poll():
    j = load()
    for job in j:
        if job["done"]: continue
        txt, res = call_tool("get_object", {"object_id": job["object_id"], "include_preview": False})
        urls = [w.strip("(),") for w in txt.split() if w.startswith("http") and ".png" in w]
        if "review" not in txt and "completed" not in txt:
            print(job["type"], "still processing"); continue
        if not urls: print(job["type"], "no urls yet\n", txt[:500]); continue
        d = os.path.join(REVIEW, job["type"]); os.makedirs(d, exist_ok=True)
        ims = []
        for i, u in enumerate(dict.fromkeys(urls)):
            p = os.path.join(d, f"cand_{i}.png")
            open(p, "wb").write(urllib.request.urlopen(urllib.request.Request(u, headers={"User-Agent": "ironwake"}), timeout=60).read()); ims.append(Image.open(p).convert("RGBA"))
        W = max(im.width for im in ims); H = max(im.height for im in ims)
        sheet = Image.new("RGBA", (len(ims)*(W+8)+8, H+28), (30, 28, 34, 255)); dr = ImageDraw.Draw(sheet)
        for i, im in enumerate(ims):
            sheet.alpha_composite(im, (8+i*(W+8), 24)); dr.text((8+i*(W+8), 6), f"{job['type']} #{i}", fill=(230,220,200))
        sp = os.path.join(REVIEW, f"{job['type']}_candidates.png"); sheet.save(sp)
        job["done"] = True; job["urls"] = urls; print("sheet ->", sp, f"({len(ims)} candidates)")
    save(j)

if __name__ == "__main__":
    if sys.argv[1] == "submit": submit(sys.argv[2])
    elif sys.argv[1] == "poll": poll()
