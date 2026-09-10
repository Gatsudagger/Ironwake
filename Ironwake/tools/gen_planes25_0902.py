#!/usr/bin/env python
"""09-02 2.5D plane pairs for Drowned Reach / Hollow Canopy (M YES 09-02).
Recipe = 08-13 planes run: create_image_pixflux, wall 400x192 side view + floor 256x256
high top-down, palette FORCED from that scene's flat combat painting (24-colour 32px PNG).
Import clones spr_wall25_ashen_1 / spr_floor25_ashen_1 .yy templates (GM CLOSED).
  python tools/gen_planes25_0902.py submit [key ...]
  python tools/gen_planes25_0902.py poll            # downloads + tiled previews + SHEET
  python tools/gen_planes25_0902.py import [key ...]
Output: _for_review/planes25_0902/
"""
import os, sys, json, re, io, base64, time, urllib.request
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ffgen, gm_import
from PIL import Image, ImageDraw

ROOT = ffgen.ROOT
REVIEW = os.path.join(ROOT, "_for_review", "planes25_0902")
BGS = os.path.join(ROOT, "_for_review", "biome_bgs_0902")
JOBS = os.path.join(REVIEW, "JOBS.json")
CREATE0 = os.path.join(ROOT, "objects", "obj_game_controller", "Create_0.gml")
os.makedirs(REVIEW, exist_ok=True)

WALL = ("Dark gothic fantasy pixel art, painterly 16-bit, flat frontal view of the BACK WALL of a combat arena "
        "seen straight on, the wall fills the whole canvas edge to edge with no floor and no sky visible, "
        "horizontally repeating architecture, no characters, no creatures, no text. ")
FLOOR = ("Dark gothic fantasy pixel art, painterly 16-bit, seamless tileable ground texture seen straight down "
         "from above (top-down), fills the whole canvas edge to edge, repeats without visible seams, "
         "no characters, no creatures, no text. ")

SCENES = {
 "spr_wall25_drowned_1":  ("drowned_1", WALL + "Flooded cathedral nave: a row of drowned stone pillars and gothic arches, wet dark stone streaked with algae, a black-green waterline lapping along the base, hanging iron lanterns burning lantern-gold, drips. Green-black palette with gold light."),
 "spr_floor25_drowned_1": ("drowned_1", FLOOR + "Still black-green floodwater over sunken cathedral flagstones, faint ripples and a few drowned leaves, dim gold lantern reflections."),
 "spr_wall25_drowned_2":  ("drowned_2", WALL + "Sunken bell tower crossing: barnacled stone arches, great verdigris bronze bells half sunk into black-green water, rotting rope and chains, one gold lantern glow. Green-black and verdigris palette."),
 "spr_floor25_drowned_2": ("drowned_2", FLOOR + "Submerged stone tiles under shallow black-green water, barnacles and green algae in the cracks, a drowned rope, verdigris flecks."),
 "spr_wall25_drowned_3":  ("drowned_3", WALL + "Deep lock-works: colossal rusted iron sluice gates and huge gear wheels set into wet stone, water pouring through the bars, caged lamps burning lantern-gold, rust and green-black."),
 "spr_floor25_drowned_3": ("drowned_3", FLOOR + "Rusted iron grating and riveted plates over black flooded water, chains, rust streaks, faint gold lamp glints."),
 "spr_wall25_canopy_1":   ("canopy_1",  WALL + "Ruined stone hall swallowed by a dark forest: broken mossy walls with thick black roots bursting through, bone-white blossoms on hanging vines, a dense dark canopy above with narrow gold light shafts. Deep green and bone palette."),
 "spr_floor25_canopy_1":  ("canopy_1",  FLOOR + "Mossy cracked flagstones with black roots pushing between them, fallen bone-white petals, dark green and bone."),
 "spr_wall25_canopy_2":   ("canopy_2",  WALL + "Inside a colossal hollow witchwood tree: curved dark bark walls, root steps, faintly glowing pale mushrooms, drifting spore mist, a gold light shaft from above. Deep green and bone palette."),
 "spr_floor25_canopy_2":  ("canopy_2",  FLOOR + "Hollow-tree floor of dark bark and knotted roots, pale glowing mushrooms, drifts of spore dust, deep green and bone."),
 "spr_wall25_canopy_3":   ("canopy_3",  WALL + "Thorn heart of the canopy: a towering wall of interwoven black bramble and thorn, pale roses and bones tangled in the hedge, a soft gold light shaft. Deep green and bone palette."),
 "spr_floor25_canopy_3":  ("canopy_3",  FLOOR + "Tangled black bramble and thorn creeping over dark earth, pale rose petals and scattered bone, deep green and bone."),
}


def palette_b64(scene):
    src = Image.open(os.path.join(BGS, "spr_combatbg_%s_raw.png" % scene)).convert("RGBA")
    base = Image.new("RGBA", src.size, (18, 18, 28, 255)); base.alpha_composite(src)
    q = base.convert("RGB").quantize(colors=24, method=Image.MEDIANCUT)
    pal = q.getpalette()[:24 * 3]
    im = Image.new("RGB", (32, 32))
    px = im.load()
    for i in range(32 * 32):
        c = (i * 24) // (32 * 32)
        px[i % 32, i // 32] = tuple(pal[c * 3:c * 3 + 3])
    b = io.BytesIO(); im.save(b, "PNG")
    return base64.b64encode(b.getvalue()).decode()


def _jid(txt):
    m = re.search(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", txt)
    return m.group(0) if m else None


def submit(keys):
    jobs = json.load(open(JOBS)) if os.path.exists(JOBS) else {}
    todo = [k for k in (keys or list(SCENES)) if not jobs.get(k)]
    for rnd in range(30):
        left = []
        for k in todo:
            scene, desc = SCENES[k]
            wall = k.startswith("spr_wall25")
            args = {"description": desc, "no_background": False, "outline": "lineless",
                    "shading": "detailed shading", "detail": "medium detail",
                    "width": 400 if wall else 256, "height": 192 if wall else 256,
                    "view": "side" if wall else "high top-down",
                    "color_image_base64": palette_b64(scene)}
            try:
                txt, _ = ffgen.call_tool("create_image_pixflux", args)
            except Exception as e:
                txt = str(e)
            j = _jid(txt)
            if j:
                jobs[k] = j; json.dump(jobs, open(JOBS, "w"), indent=1); print("queued", k, j, flush=True)
            else:
                left.append(k); print("defer", k, txt[:120].replace("\n", " "), flush=True)
        todo = left
        if not todo: break
        time.sleep(25)


def poll():
    jobs = json.load(open(JOBS))
    pending = 0
    for k, jid in jobs.items():
        raw = os.path.join(REVIEW, k + "_raw.png")
        if os.path.exists(raw): continue
        txt, res = ffgen.call_tool("get_image", {"job_id": jid})
        url = re.search(r"https://\S+", txt)
        if "completed" not in txt.lower() or not url:
            pending += 1; print(k, "status:", txt[:90].replace("\n", " | ")); continue
        data = urllib.request.urlopen(urllib.request.Request(url.group(0).rstrip(")"), headers={"User-Agent": "ironwake"}), timeout=60).read()
        open(raw, "wb").write(data); print(k, "landed", Image.open(raw).size)
    sheet()
    return pending


def sheet():
    rows = []
    for biome in ("drowned", "canopy"):
        for fl in (1, 2, 3):
            w = os.path.join(REVIEW, "spr_wall25_%s_%d_raw.png" % (biome, fl))
            f = os.path.join(REVIEW, "spr_floor25_%s_%d_raw.png" % (biome, fl))
            if os.path.exists(w) or os.path.exists(f): rows.append((biome, fl, w, f))
    if not rows: return
    S = Image.new("RGB", (640, 40 + len(rows) * 232), (14, 14, 20)); d = ImageDraw.Draw(S)
    y = 10
    for biome, fl, w, f in rows:
        d.text((10, y), "%s fl%d  (wall | floor tiled 2x2)" % (biome, fl), fill=(200, 200, 210)); y += 16
        if os.path.exists(w): S.paste(Image.open(w).convert("RGB"), (10, y))
        if os.path.exists(f):
            fi = Image.open(f).convert("RGB").resize((96, 96), Image.NEAREST)
            for a in (0, 1):
                for b in (0, 1): S.paste(fi, (430 + a * 96, y + b * 96))
        y += 216
    S.save(os.path.join(REVIEW, "SHEET_planes25_0902.png"))


def do_import(keys):
    built = []
    for k in (keys or list(SCENES)):
        raw = os.path.join(REVIEW, k + "_raw.png")
        if not os.path.exists(raw): print("missing", k); continue
        tpl = "spr_wall25_ashen_1" if k.startswith("spr_wall25") else "spr_floor25_ashen_1"
        if gm_import.build_sprite(k, raw, tpl): built.append(k)
    gm_import.register(built)
    txt = open(CREATE0, encoding="utf-8").read()
    add = [k for k in (keys or list(SCENES)) if k not in txt]
    if add:
        anchor = "    spr_wall25_ashen_1, spr_floor25_ashen_1,\n"
        assert anchor in txt
        txt = txt.replace(anchor, anchor + "    // 09-02 Drowned / Canopy plane pairs (string-looked-up in dungeon_bg_draw)\n    " + ", ".join(add) + ",\n")
        open(CREATE0, "w", encoding="utf-8", newline="").write(txt)
        print("includes +", len(add))


if __name__ == "__main__":
    cmd = sys.argv[1]; keys = sys.argv[2:]
    if cmd == "submit": submit(keys)
    elif cmd == "poll": sys.exit(1 if poll() else 0)
    elif cmd == "sheet": sheet()
    elif cmd == "import": do_import(keys)
