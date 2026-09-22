#!/usr/bin/env python
"""09-15 two-job art driver (M-approved, ~20 gens): (1) a NEW Crypt Gryphon BABY that
matches the shipped young adult / adult (the old baby was a horned black cub that never
read as a gryphon); (2) a NEW species "Barrowhorn" (horned ox-drake) whose BABY stage IS
the old gryphon baby (character 3d617d22 + its finished south/south-east idles, reused at
zero gens) and whose young adult + adult are generated from it.
Locked recipe = tools/missgen.py phases C-F (palette-locked pixflux 64x64 stills ->
create_character v3 -> animate_character v3 south + combat dir -> gm_import). Review path
is ONE stable folder, overwritten in place: _for_review/gryphon_barrowhorn_0915/.
Usage: python tools/gryphon_barrowhorn_0915.py stills|poll|pick <job> <file>|ya|chars|chpoll|anims|animpoll|import
"""
import os, sys, json, io, time, zipfile, urllib.request
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ffgen, missgen
from PIL import Image, ImageDraw

ROOT   = ffgen.ROOT
REVIEW = os.path.join(ROOT, "_for_review", "gryphon_barrowhorn_0915")
os.makedirs(REVIEW, exist_ok=True)
STATE  = os.path.join(REVIEW, "STATE.json")
OLD    = os.path.join(ROOT, "_for_review", "missing_art_0827", "crypt_gryphon")
GRY_YA = os.path.join(OLD, "youngadult_s_pixen_r0.png")     # shipped young adult still (the anchor)
GRY_AD = os.path.join(OLD, "adult_s_pixen_r1.png")
OLDBABY = os.path.join(OLD, "baby_s_fresh_r0.png")          # the horned cub -> Barrowhorn baby
OLD_BABY_CHAR = "3d617d22-0c87-4e4b-a83f-d642843e02e7"      # its finished character (south + south-east idles)
CHAR_DL = "https://api.pixellab.ai/mcp/characters/{id}/download"

GRYPHON_VIS = missgen.REDIRECT["crypt_gryphon"]
BARROW_VIS  = ("a Barrowhorn: a stocky heavy-shouldered horned OX-DRAKE, slab-scaled black hide, "
               "a bull's thick neck, curled ram-like horns, short thick tail, four sturdy hoofed-claw legs, "
               "small amber eyes, a crypt beast of burden - dark gothic fantasy, natural animal posture")
BASE_DESC = ("Pixel art creature sprite, bold black outline, flat limited colours, chunky pixels. %s "
             "ONLY the creature on a fully transparent background - no props, no text. Dark gothic fantasy, "
             "natural animal posture - never humanoid." + missgen.NOGROUND)

def _load(): return json.load(open(STATE)) if os.path.exists(STATE) else {"jobs": [], "picks": {}, "chars": []}
def _save(s): json.dump(s, open(STATE, "w"), indent=1)
def _fetch(u): return urllib.request.urlopen(urllib.request.Request(u, headers={"User-Agent": "ironwake"}), timeout=90).read()

def _submit(s, key, desc, ref=None, mode="fresh"):
    args = {"description": desc, "width": 64, "height": 64, "no_background": True,
            "direction": "south", "view": "low top-down", "outline": "single color black outline"}
    if ref:
        if mode == "fresh": args["color_image_base64"] = ffgen.b64file(ref)
        else:
            args["init_image_base64"] = ffgen.b64file(ref); args["init_image_strength"] = 100
    txt, _ = ffgen.call_tool("create_image_pixflux", args)
    jid = missgen._jid(txt)
    s["jobs"].append({"key": key, "job": jid, "done": False, "raw": txt[:160]})
    print(("queued" if jid else "FAILED"), key, jid or txt[:120].replace("\n", " "), flush=True)

def stills():
    s = _load()
    # (1) gryphon baby from the young adult (palette-locked fresh gen = locked recipe)
    _submit(s, "gryphon_baby",
            BASE_DESC % (missgen.STAGE_PROMPT["baby"] + " (Crypt Gryphon - " + GRYPHON_VIS + ")."), GRY_YA, "fresh")
    # (2) Barrowhorn adult, two takes from the old cub: palette-locked fresh + img2img
    ad = ("the same creature as the reference grown to a full ADULT: about 52 of the 64 pixels tall, "
          "heavy and broad, horns fully grown and curled, same black hide and markings, same 3/4 front view facing the viewer")
    _submit(s, "barrow_adult_A", BASE_DESC % (ad + " (" + BARROW_VIS + ")."), OLDBABY, "fresh")
    _submit(s, "barrow_adult_B", BASE_DESC % (ad + " (" + BARROW_VIS + ")."), OLDBABY, "img2img")
    _save(s)

def ya():
    s = _load()
    pick = s["picks"].get("barrow_adult")
    if not pick: print("pick the adult first: pick barrow_adult <file>"); return
    d = BASE_DESC % (missgen.STAGE_PROMPT["youngadult"] + " (" + BARROW_VIS + ").")
    _submit(s, "barrow_ya", d, os.path.join(REVIEW, pick), "fresh")
    _save(s)

def poll(wait=240):
    s = _load(); t0 = time.time()
    while True:
        pending = 0
        for r in s["jobs"]:
            if r["done"] or not r["job"]: continue
            txt, _ = ffgen.call_tool("get_image", {"job_id": r["job"]})
            low = txt.lower()
            if "status: failed" in low:
                r["done"] = True; r["failed"] = True; print("FAILED", r["key"], flush=True); continue
            if "completed" not in low and "download" not in low: pending += 1; continue
            n = sum(1 for k in s["jobs"] if k["key"] == r["key"] and k.get("file"))
            fp = os.path.join(REVIEW, "%s_r%d.png" % (r["key"], n))
            missgen._dl(r["job"], fp); r["done"] = True; r["file"] = os.path.basename(fp)
            print("got", r["key"], r["file"], flush=True)
        _save(s)
        if pending == 0 or time.time() - t0 > wait: break
        time.sleep(15)
    print("pending", pending); sheet()

def sheet():
    """Labelled review sheet, overwritten in place: SHEET.png."""
    s = _load(); S = 4; cell = 64 * S
    cols = [("gryphon YA (shipped)", GRY_YA), ("gryphon adult (shipped)", GRY_AD), ("old cub = Barrowhorn baby", OLDBABY)]
    for r in s["jobs"]:
        if r.get("file"): cols.append((r["file"][:-4], os.path.join(REVIEW, r["file"])))
    im = Image.new("RGBA", (len(cols) * (cell + 12) + 12, cell + 44), (34, 34, 42, 255))
    dr = ImageDraw.Draw(im)
    for i, (lab, p) in enumerate(cols):
        x = 12 + i * (cell + 12)
        bg = Image.new("RGBA", (cell, cell), (60, 60, 68, 255))
        if os.path.exists(p): bg.alpha_composite(Image.open(p).convert("RGBA").resize((cell, cell), Image.NEAREST))
        im.alpha_composite(bg, (x, 12)); dr.text((x + 2, cell + 18), lab, fill=(255, 255, 255))
    out = os.path.join(REVIEW, "SHEET.png"); im.save(out); print("sheet", out)

def pick(key, fn):
    s = _load(); s["picks"][key] = fn; _save(s); print("picked", key, fn)

def chars():
    """create_character v3 from each picked still (gryphon_baby, barrow_ya, barrow_adult); the
    Barrowhorn baby reuses the old gryphon-baby character outright."""
    s = _load()
    have = {c["stage_key"] for c in s["chars"]}
    if "barrow_baby" not in have:
        s["chars"].append({"stage_key": "barrow_baby", "sprite": "barrowhorn_baby", "char": OLD_BABY_CHAR,
                           "rot_done": True, "anim_ok_south": True, "anim_ok_south-east": True, "combat": "south-east"})
    for key, sprite, vis, combat in (("gryphon_baby", "crypt_gryphon_baby", GRYPHON_VIS, "south-east"),
                                     ("barrow_ya", "barrowhorn_youngadult", BARROW_VIS, "east"),
                                     ("barrow_adult", "barrowhorn_adult", BARROW_VIS, "east")):
        if key in have: continue
        fn = s["picks"].get(key)
        if not fn: print("NO PICK", key); continue
        txt, _ = ffgen.call_tool("create_character", {"description": vis + ", pixel art game sprite", "mode": "v3",
                                                     "reference_image_base64": ffgen.b64file(os.path.join(REVIEW, fn)),
                                                     "name": "iw0915 " + key})
        cid = None
        for line in txt.splitlines():
            if line.startswith("id:"): cid = line.split(":", 1)[1].strip(); break
        s["chars"].append({"stage_key": key, "sprite": sprite, "char": cid, "rot_done": False, "combat": combat, "raw": txt[:150]})
        print(("queued" if cid else "FAILED"), key, cid or txt[:120].replace("\n", " "), flush=True)
    _save(s)

def chpoll():
    s = _load()
    for r in s["chars"]:
        if r["rot_done"] or not r["char"]: continue
        txt, _ = ffgen.call_tool("get_character", {"character_id": r["char"], "include_preview": False})
        if "rotations:" not in txt: print("pending", r["stage_key"]); continue
        urls = {}; in_rot = False
        for line in txt.splitlines():
            t = line.strip()
            if t.startswith("rotations:"): in_rot = True; continue
            if in_rot and (t == "" or t.endswith(":") or ":" not in t): break
            if in_rot:
                for d in ("south", "east", "south-east"):
                    if t.startswith(d + ": https"): urls[d] = t.split(": ", 1)[1].split(",")[0].strip()
        if "east" not in urls: print("no east yet", r["stage_key"]); continue
        for d, u in urls.items(): open(os.path.join(REVIEW, "%s_rot_%s.png" % (r["stage_key"], d)), "wb").write(_fetch(u))
        r["rot_done"] = True; print("rotations", r["stage_key"], flush=True)
    _save(s); rotsheet()

def rotsheet():
    s = _load(); S = 3; cell = 64 * S; rows = [r for r in s["chars"] if r["rot_done"] and r["stage_key"] != "barrow_baby"]
    if not rows: return
    im = Image.new("RGBA", (3 * (cell + 10) + 10, len(rows) * (cell + 30) + 10), (34, 34, 42, 255)); dr = ImageDraw.Draw(im)
    for j, r in enumerate(rows):
        for i, d in enumerate(("south", "east", "south-east")):
            p = os.path.join(REVIEW, "%s_rot_%s.png" % (r["stage_key"], d)); x = 10 + i * (cell + 10); y = 10 + j * (cell + 30)
            bg = Image.new("RGBA", (cell, cell), (60, 60, 68, 255))
            if os.path.exists(p):
                c = Image.open(p).convert("RGBA"); sc = min(cell / c.width, cell / c.height)
                c = c.resize((max(1, round(c.width * sc)), max(1, round(c.height * sc))), Image.NEAREST); bg.alpha_composite(c, (0, 0))
            im.alpha_composite(bg, (x, y)); dr.text((x + 2, y + cell + 4), r["stage_key"] + " " + d, fill=(255, 255, 255))
    im.save(os.path.join(REVIEW, "ROTATIONS.png")); print("rotsheet")

def anims():
    s = _load()
    for r in s["chars"]:
        if not r["rot_done"]: continue
        for d in ("south", r["combat"]):
            if r.get("anim_ok_" + d): continue
            txt, _ = ffgen.call_tool("animate_character", {"character_id": r["char"], "mode": "v3", "directions": [d],
                                                          "action_description": missgen.IDLE, "frame_count": 8,
                                                          "animation_name": "iw0915_idle_" + d})
            if txt.lstrip().lower().startswith("error"): print("DEFERRED", r["stage_key"], d, txt[:100])
            else: r["anim_ok_" + d] = True; print("anim queued", r["stage_key"], d, flush=True)
    _save(s)

def animpoll():
    s = _load(); waiting = 0
    for r in s["chars"]:
        need = ["south", r["combat"]]
        if not all(r.get("anim_ok_" + d) for d in need) or r.get("frames_done"): continue
        try: z = zipfile.ZipFile(io.BytesIO(_fetch(CHAR_DL.format(id=r["char"]))))
        except Exception as e: waiting += 1; print("zip pending", r["stage_key"], e); continue
        got = {}
        for d in need:
            names = sorted(n for n in z.namelist() if "animations/" in n and ("/%s/" % d) in n and n.endswith(".png"))
            if not names: continue
            suffix = "s" if d == "south" else "e"; frames = []
            for i, n in enumerate(names):
                fp = os.path.join(REVIEW, "%s_%s_ANIM_%d.png" % (r["stage_key"], suffix, i)); open(fp, "wb").write(z.read(n)); frames.append(fp)
            got[d] = len(frames)
            ims = [Image.open(f).convert("RGBA").resize((192, 192), Image.NEAREST) for f in frames]
            bgs = [Image.new("RGBA", (192, 192), (60, 60, 68, 255)) for _ in ims]
            for b_, i_ in zip(bgs, ims): b_.alpha_composite(i_)
            bgs[0].save(os.path.join(REVIEW, "ANIM_%s_%s.gif" % (r["stage_key"], suffix)), save_all=True, append_images=bgs[1:], duration=120, loop=0, disposal=2)
        if len(got) == len(need): r["frames_done"] = True; print("frames", r["stage_key"], got)
        else: waiting += 1; print("partial", r["stage_key"], got)
    _save(s); print("waiting", waiting)

def do_import():
    """GM CLOSED. Gryphon baby = frame swap of existing sprites; Barrowhorn = 6 NEW sprites (register)."""
    import glob as _glob, gm_import
    from PIL import ImageChops, ImageStat
    s = _load(); built = []; new = []
    for r in s["chars"]:
        if not r.get("frames_done"): continue
        for suffix in ("s", "e"):
            fs = sorted(_glob.glob(os.path.join(REVIEW, "%s_%s_ANIM_*.png" % (r["stage_key"], suffix))), key=lambda p: int(p.rsplit("_", 1)[1][:-4]))
            fr = [Image.open(f).convert("RGBA") for f in fs]
            if len(fr) < 4: print("NO FRAMES", r["stage_key"], suffix); continue
            if len(fr) == 9:
                def _md(a, b): st = ImageStat.Stat(ImageChops.difference(a, b)); return sum(st.mean) / len(st.mean)
                fr = fr[:8] if _md(fr[7], fr[0]) <= _md(fr[8], fr[1]) else fr[1:9]
            name = "spr_pet_%s_%s" % (r["sprite"], suffix)
            is_new = not os.path.isdir(os.path.join(ROOT, "sprites", name))
            gm_import.build_anim_sprite(name, fr, fps=8.0); built.append(name)
            if is_new: new.append(name)
    if new: gm_import.register(new)
    print("built", built); print("registered NEW", new)
    print("REMEMBER __sprite_includes (obj_game_controller/Create_0.gml) for NEW sprites.")

if __name__ == "__main__":
    a = sys.argv[1:]
    {"stills": stills, "poll": poll, "sheet": sheet, "ya": ya, "chars": chars, "chpoll": chpoll,
     "anims": anims, "animpoll": animpoll, "import": do_import}[a[0]](*a[1:]) if a[0] != "pick" else pick(a[1], a[2])
