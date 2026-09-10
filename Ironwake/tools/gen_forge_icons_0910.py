#!/usr/bin/env python
"""09-10: icons for the 3 MISC-ledger items with no art - Runeheart Core, Mythril
Frame (Legendary Forge parts) and the Seahorse Knight's Seashell Necklace.
Recipe = the shipped icon recipe (tools/gen_valuable_icons_0818.py): create_1_direction_object,
64x64 top-down, style_images = 6 shipped loot/consumable icons, 16 candidates per item
(~20 gens each, M's YES 09-10 at ~60 total). Sheets -> _for_review/forge_icons_0910/SHEET_<id>.png
  python tools/gen_forge_icons_0910.py submit
  python tools/gen_forge_icons_0910.py poll
  python tools/gen_forge_icons_0910.py import <key>=<n> ...   # copy candidate n into the sprite (yy clone)
"""
import os, sys, json, re, urllib.request, io, shutil, uuid
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ffgen
from PIL import Image, ImageDraw

ROOT = ffgen.ROOT
REVIEW = os.path.join(ROOT, "_for_review", "forge_icons_0910")
JOBS = os.path.join(REVIEW, "JOBS.json")
os.makedirs(REVIEW, exist_ok=True)

STYLE_REFS = ["spr_icon_consumable_genie_lamp", "spr_icon_amulet_medallion", "spr_icon_amulet_emberheart",
              "spr_icon_ring_signet", "spr_icon_legendary_beggars_fortune", "spr_icon_consumable_ley_battery"]

ITEMS = {
    "runeheart_core":   "a fist-sized runic heart-stone core, dark iron shell cracked open around a pulsing violet crystal heart, glowing rune lines, forge component; dark gothic fantasy loot icon",
    "mythril_frame":    "an empty ornate mythril armature frame, pale silver-blue metal lattice with gothic rivets, an item skeleton waiting to be filled, forge component; dark fantasy loot icon",
    "seashell_necklace":"a necklace of ten small pale seashells strung on a dark kelp cord, sea-worn, faint teal tide-glow, gothic dark fantasy loot icon",
}
SPRITES = {
    "runeheart_core":    "spr_icon_forge_runeheart_core",
    "mythril_frame":     "spr_icon_forge_mythril_frame",
    "seashell_necklace": "spr_icon_valuable_seashell",
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


def do_import(picks):
    """Clone spr_icon_valuable_star_iron_idol's .yy (64x64 single frame) under the new
    sprite name, drop the chosen candidate in, and register it in Ironwake.yyp."""
    tmpl = "spr_icon_valuable_star_iron_idol"
    yyp = os.path.join(ROOT, "Ironwake.yyp")
    yyp_s = open(yyp, encoding="utf-8").read()
    for kv in picks:
        key, n = kv.split("=")
        name = SPRITES[key]
        src = os.path.join(REVIEW, "%s_%02d.png" % (key, int(n)))
        d = os.path.join(ROOT, "sprites", name)
        os.makedirs(os.path.join(d, "layers"), exist_ok=True)
        tyy = open(os.path.join(ROOT, "sprites", tmpl, tmpl + ".yy"), encoding="utf-8").read()
        fid = str(uuid.uuid4()); lid = str(uuid.uuid4())
        old_fid = re.search(r'"frames":\[\s*\{[^}]*?"name":"([0-9a-f-]{36})"', tyy).group(1)
        old_lid = re.search(r'"layers":\[\s*\{[^}]*?"name":"([0-9a-f-]{36})"', tyy).group(1)
        yy = tyy.replace(tmpl, name).replace(old_fid, fid).replace(old_lid, lid)
        open(os.path.join(d, name + ".yy"), "w", encoding="utf-8").write(yy)
        shutil.copy(src, os.path.join(d, fid + ".png"))
        os.makedirs(os.path.join(d, "layers", fid), exist_ok=True)
        shutil.copy(src, os.path.join(d, "layers", fid, lid + ".png"))
        entry = '    {"id":{"name":"%s","path":"sprites/%s/%s.yy",},},\n' % (name, name, name)
        if name not in yyp_s:
            yyp_s = yyp_s.replace('  "resources":[\n', '  "resources":[\n' + entry, 1)
        print("imported", name, "<-", src)
    open(yyp, "w", encoding="utf-8").write(yyp_s)


if __name__ == "__main__":
    if sys.argv[1] == "import": do_import(sys.argv[2:])
    else: {"submit": submit, "poll": poll}[sys.argv[1]]()
