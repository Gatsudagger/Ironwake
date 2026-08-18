#!/usr/bin/env python
"""08-17 late - PRO CHARACTER route for species art (M-approved via the canopy_shrew test):
create_character(mode="pro", quadruped/humanoid template, size 48) -> 8 rotations, then
create_character_state for youngadult / baby, then animate_character v3 idle (south + east),
then import south/east rotations + idle frames as spr_pet_<species>_<stage>_<s|e>.
Review folder: _for_review/species_pro_0817/<species>/  (SHEET_<species>.png + ANIM gifs).
  python tools/progen.py char   <species> [template] [--style <char_id>]   # PRO adult (20-40 gens)
  python tools/progen.py state  <species> <stage> <char_id> "<edit>"       # baby / youngadult state
  python tools/progen.py idle   <char_id> "<action>"                        # south+east idle (2 gens)
  python tools/progen.py fetch  <species>                                   # download rotations/anims + sheet + gifs
  python tools/progen.py open   <species>                                   # open the sheet for M
State lives in _for_review/species_pro_0817/CHARS.json: {species: {stage: {id, ...}}}.
"""
import os, sys, re, json, urllib.request, subprocess
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ffgen
ROOT   = ffgen.ROOT
REVIEW = os.path.join(ROOT, "_for_review", "species_pro_0817")
CHARS  = os.path.join(REVIEW, "CHARS.json")
os.makedirs(REVIEW, exist_ok=True)
DIRS8 = ["south", "south-east", "east", "north-east", "north", "north-west", "west", "south-west"]

def load():  return json.load(open(CHARS)) if os.path.exists(CHARS) else {}
def save(d): json.dump(d, open(CHARS, "w"), indent=1)

def _id(txt):
    for tok in txt.replace('"', ' ').replace(',', ' ').split():
        if len(tok) == 36 and tok.count('-') == 4: return tok
    return None

def char(species, template="cat", style=None, body="quadruped", desc=None):
    d = load()
    if desc is None:
        name, vis = ffgen.SPECIES[species]
        desc = ("a %s - %s; dark gothic fantasy creature, classic 16-bit tactics RPG creature sprite, "
                "bold black outline, flat colours, low detail" % (name, vis))
    args = {"description": desc, "name": species + "_pro", "mode": "pro", "size": 48, "view": "low top-down",
            "body_type": body}
    if body == "quadruped": args["template"] = template
    if style: args["style_character_id"] = style
    txt, _ = ffgen.call_tool("create_character", args)
    cid = _id(txt)
    d.setdefault(species, {})["adult"] = {"id": cid, "desc": desc, "raw": txt[:200]}
    save(d); print("char", species, "adult", cid or txt[:200]); return cid

def state(species, stage, src_id, edit):
    d = load()
    txt, _ = ffgen.call_tool("create_character_state", {"character_id": src_id, "edit_description": edit,
                             "state_name": stage, "use_color_palette_from_reference": True})
    cid = _id(txt)
    d.setdefault(species, {})[stage] = {"id": cid, "edit": edit, "raw": txt[:200]}
    save(d); print("state", species, stage, cid or txt[:200]); return cid

def idle(char_id, action):
    txt, _ = ffgen.call_tool("animate_character", {"character_id": char_id, "mode": "v3", "action_description": action,
                             "directions": ["south", "east"], "frame_count": 8, "animation_name": "idle"})
    print("idle", char_id, txt[:160].replace(chr(10), " | ")); return txt

def _get(url, out):
    data = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=60).read()
    open(out, "wb").write(data)

def fetch(species):
    from PIL import Image, ImageDraw
    d = load(); sp = d.get(species, {})
    outdir = os.path.join(REVIEW, species); os.makedirs(outdir, exist_ok=True)
    rows = []
    for stage in ["adult", "youngadult", "baby"]:
        if stage not in sp or not sp[stage].get("id"): continue
        cid = sp[stage]["id"]
        txt, _ = ffgen.call_tool("get_character", {"character_id": cid, "include_preview": False})
        if "status: completed" not in txt.lower():
            print(stage, "not ready:", txt[:120].replace(chr(10), " | ")); continue
        urls = dict(re.findall(r'  (south|east|north|west|south-east|north-east|north-west|south-west): (https://\S+)', txt))
        for dname in DIRS8:
            if dname in urls: _get(urls[dname], os.path.join(outdir, "%s_rot_%s.png" % (stage, dname)))
        # idle frames: "    east: url1, url2, ..." lines under the animations block
        for dname in ["south", "east"]:
            m = re.search(r'\n    %s: (https://[^\n]+)' % dname, txt)
            if not m: continue
            us = [u.strip() for u in m.group(1).split(",") if u.strip().startswith("http")]
            for i, u in enumerate(us): _get(u, os.path.join(outdir, "%s_idle_%s_%d.png" % (stage, dname, i)))
            frames = [Image.open(os.path.join(outdir, "%s_idle_%s_%d.png" % (stage, dname, i))).convert("RGBA") for i in range(len(us))]
            if frames:
                big = []
                for f in frames:
                    bg = Image.new("RGBA", (f.size[0] * 4, f.size[1] * 4), (60, 60, 68, 255)); bg.alpha_composite(f.resize((f.size[0] * 4, f.size[1] * 4), Image.NEAREST)); big.append(bg)
                big[0].save(os.path.join(outdir, "ANIM_%s_%s.gif" % (stage, dname)), save_all=True, append_images=big[1:], duration=120, loop=0, disposal=2)
        rows.append(stage)
        sp[stage]["fetched"] = True
    save(d)
    # sheet: one row per stage x 8 rotations, 3x
    if rows:
        S = 3; W = 72; C = W * S + 8   # fixed cell (rotations vary 48-72px)
        img = Image.new("RGBA", (8 * C + 8, len(rows) * (C + 22) + 30), (30, 30, 34, 255)); dr = ImageDraw.Draw(img)
        dr.text((6, 6), "%s - PRO character rotations (3x). Idle GIFs beside this sheet." % species, fill=(230, 230, 230))
        y = 28
        for stage in rows:
            dr.text((6, y), stage, fill=(255, 210, 120))
            for i, dname in enumerate(DIRS8):
                p = os.path.join(outdir, "%s_rot_%s.png" % (stage, dname))
                if not os.path.exists(p): continue
                im = Image.open(p).convert("RGBA"); W2 = im.size[0]
                bg = Image.new("RGBA", (W * S, W * S), (60, 60, 68, 255))
                bg.alpha_composite(im.resize((W2 * S, W2 * S), Image.NEAREST), ((W - W2) * S // 2, (W - W2) * S))
                img.paste(bg, (6 + i * C, y + 16)); dr.text((8 + i * C, y + 16 + W * S - 12), dname, fill="white")
            y += C + 22
        img.save(os.path.join(outdir, "SHEET_%s.png" % species)); print("sheet", species, rows)

def open_for_m(species):
    p = os.path.join(REVIEW, species)
    subprocess.Popen(["explorer", p.replace("/", "\\")])
    sh = os.path.join(p, "SHEET_%s.png" % species)
    if os.path.exists(sh): os.startfile(sh)

def do_import(species):
    """GM CLOSED: build spr_pet_<species>_<stage>_<s|e> ANIMATED sprites from the fetched idle
    frames (south -> _s, east -> _e; frame 0 = rotation still, then 8 idle frames), register in
    the yyp, add anti-strip refs. Stages without idle frames fall back to the rotation still."""
    from PIL import Image
    import glob as _g
    import gm_import, import_species_ff_0817 as isf
    outdir = os.path.join(REVIEW, species); names = []
    for stage in ["baby", "youngadult", "adult"]:
        for dname, suf in [("south", "s"), ("east", "e")]:
            fs = sorted(_g.glob(os.path.join(outdir, "%s_idle_%s_*.png" % (stage, dname))), key=lambda f: int(f.rsplit("_", 1)[1][:-4]))
            still = os.path.join(outdir, "%s_rot_%s.png" % (stage, dname))
            if not fs and not os.path.exists(still): continue
            name = "spr_pet_%s_%s_%s" % (species, stage, suf)
            frames = [Image.open(f).convert("RGBA") for f in fs] if fs else [Image.open(still).convert("RGBA")]
            # normalise canvas (idle frames can be a few px larger than the still)
            W = max(f.size[0] for f in frames); H = max(f.size[1] for f in frames)
            norm = []
            for f in frames:
                c = Image.new("RGBA", (W, H), (0, 0, 0, 0)); c.alpha_composite(f, ((W - f.size[0]) // 2, H - f.size[1])); norm.append(c)
            gm_import.build_anim_sprite(name, norm); names.append(name)
    gm_import.register(names); isf.include_names(names)
    print("imported", names)

if __name__ == "__main__":
    a = sys.argv[1:]
    if a[0] == "char":
        style = a[a.index("--style") + 1] if "--style" in a else None
        tpl = a[2] if len(a) > 2 and not a[2].startswith("--") else "cat"
        char(a[1], tpl, style)
    elif a[0] == "state": state(a[1], a[2], a[3], a[4])
    elif a[0] == "idle":  idle(a[1], a[2])
    elif a[0] == "fetch": fetch(a[1])
    elif a[0] == "open":  open_for_m(a[1])
    elif a[0] == "import": do_import(a[1])
