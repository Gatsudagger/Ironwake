#!/usr/bin/env python
"""09-22 BAIRC'S HUT interior (DESIGN_HUT_INTERIOR_0922.md). Same recipe as the garden plate
(tools/gen_garden_plate_0917.py): create_map_object 400x224 native, lineless, detailed shading,
cropped to painted content and edge-tiled to 480x160 native -> 1920x640 @ x4 NEAREST. Indoor
ornaments + keepsakes = transparent objects at plate density, x4, origin top-left.
  python tools/gen_hut_interior_0922.py submit [key ...]      # plate(s)
  python tools/gen_hut_interior_0922.py submit_obj [key ...]  # ornaments / keepsakes
  python tools/gen_hut_interior_0922.py poll
  python tools/gen_hut_interior_0922.py build_plate <key>     # crop + tile -> spr_hut_plate_x4.png
  python tools/gen_hut_interior_0922.py import [key ...]      # GM CLOSED
Output: _for_review/hut_0922/
"""
import os, sys, json, re, urllib.request
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ffgen, gm_import
from PIL import Image

ROOT = ffgen.ROOT
REVIEW = os.path.join(ROOT, "_for_review", "hut_0922")
JOBS = os.path.join(REVIEW, "JOBS.json")
os.makedirs(REVIEW, exist_ok=True)
CREATE0 = os.path.join(ROOT, "objects", "obj_game_controller", "Create_0.gml")

STYLE = ("Dark gothic fantasy pixel art interior scene at night, three-quarter view from slightly above, "
         "painterly 16-bit pixel art, moody, muted desaturated palette, very dark, deep shadow, lit only by "
         "warm hearth firelight and one cold shaft of blue moonlight from a small window, no characters, "
         "no creatures, no text. The lower HALF of the frame is an open flat walkable floor of worn dark "
         "flagstones and packed earth seen from above, clear of obstacles, so figures can walk across it; "
         "furniture and walls only in the upper half and at the far left and right edges. ")

SCENES = {
 "spr_hut_plate_a": STYLE + "The inside of Bairc the creature keeper's small crooked stone hut: rough dark "
     "stone walls with heavy timber beams, a big stone hearth with a low orange fire at the back-centre, a "
     "cluttered wooden ledger desk with candles and stacked books at the back-left, a long wooden shelf "
     "on the back wall at the back-right with a few empty spaces on it, a small shuttered window leaking "
     "moonlight, bundles of dried herbs hanging from the beams, a straw creature bed in a corner, feed "
     "sacks. Cosy, worn, lived-in, very dark except the fire glow.",
}

OBJ_STYLE = ("Dark gothic fantasy pixel art, painterly 16-bit, lineless, detailed shading, muted desaturated "
             "palette (dark timber, slate, straw, a little warm firelight), transparent background, no text, "
             "no floor, the object alone. ")
OBJECTS = {
 # indoor ornaments (DESIGN_HUT_INTERIOR_0922.md table): key: (description, w, h, view)
 "spr_garden_orn_rug":     (OBJ_STYLE + "A FLAT rectangular grey wolf-pelt RUG spread out flat on the floor, seen from above, a wide thin shape with ragged fur edges and a small wolf-head end, NOT a heap, NOT folded, no thickness.", 64, 32, "low top-down"),
 "spr_garden_orn_shelf2":  (OBJ_STYLE + "A short dark wooden ledger shelf, two boards on iron brackets, stacked leather ledgers and a candle stub, front three-quarter view.", 48, 56, "low top-down"),
 "spr_garden_orn_herbs":   (OBJ_STYLE + "A wooden drying rack hung with bundles of dried herbs and a string of garlic, front three-quarter view.", 40, 60, "low top-down"),
 "spr_garden_orn_cot":     (OBJ_STYLE + "A low straw creature cot in a rough wooden frame with a folded grey blanket, front three-quarter view.", 64, 40, "low top-down"),
 "spr_garden_orn_kettle":  (OBJ_STYLE + "A black iron kettle hanging from an iron tripod hook stand over a few embers, a wisp of steam, front three-quarter view.", 36, 48, "low top-down"),
 "spr_garden_orn_crate":   (OBJ_STYLE + "Two stacked wooden feed crates with a burlap sack of grain slumped against them, front three-quarter view.", 48, 48, "low top-down"),
 "spr_garden_orn_candles": (OBJ_STYLE + "A cluster of five dripping tallow candles of different heights on a flat stone, small warm flames, front three-quarter view.", 32, 36, "low top-down"),
 "spr_garden_orn_perch":   (OBJ_STYLE + "A wooden BIRD PERCH stand: one vertical post on a round three-legged base, a single short horizontal roosting bar at the top with a small feed cup on one end. A plain T-shaped bird stand, NOT a cross, NOT a crucifix, no second crossbar.", 36, 64, "low top-down"),
 "spr_garden_cart":        (OBJ_STYLE + "A small two-wheeled wooden peddler's handcart parked and tipped back on its legs, piled with wrapped bundles, a rolled rug, a hanging lantern and a few small ornaments, a canvas awning on two poles, weathered, front three-quarter view.", 96, 72, "low top-down"),
 # keepsakes (shelf trinkets, small)
 "spr_keep_first_egg":  (OBJ_STYLE + "A single cracked pale eggshell half, kept as a keepsake, front three-quarter view.", 32, 32, "low top-down"),
 "spr_keep_full_cairn": (OBJ_STYLE + "Five small smooth grey river stones stacked in a tiny cairn, front three-quarter view.", 32, 32, "low top-down"),
 "spr_keep_awakened":   (OBJ_STYLE + "A small glass vial holding a faint swirling violet light, corked, front three-quarter view.", 32, 32, "low top-down"),
 "spr_keep_ten_kinds":  (OBJ_STYLE + "A small leather-bound field journal with ten tiny coloured tabs along its page edge, standing upright, front three-quarter view.", 32, 32, "low top-down"),
 "spr_keep_board25":    (OBJ_STYLE + "A bundle of old finished job notices tied with twine, a wax seal on top, front three-quarter view.", 32, 32, "low top-down"),
 "spr_keep_remembered": (OBJ_STYLE + "A tiny pale headstone carving with a single bone-white blossom laid against it, front three-quarter view.", 32, 32, "low top-down"),
 "spr_keep_his_word":   (OBJ_STYLE + "A small carved wooden creature figure, worn smooth from handling, front three-quarter view.", 32, 32, "low top-down"),
 "spr_keep_deep_runs":  (OBJ_STYLE + "A dented iron lantern with a chipped blue glass pane, kept as a trophy, front three-quarter view.", 32, 32, "low top-down"),
}

UUID = r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"

def _jobs():
    return json.load(open(JOBS)) if os.path.exists(JOBS) else {}

def submit(keys):
    jobs = _jobs()
    for k in keys:
        if jobs.get(k): print("skip", k, jobs[k]); continue
        txt, _ = ffgen.call_tool("create_map_object", {"description": SCENES[k], "width": 400, "height": 224,
                                                      "view": "low top-down", "detail": "medium detail",
                                                      "outline": "lineless", "shading": "detailed shading"})
        m = re.search(UUID, txt)
        jobs[k] = m.group(0) if m else None
        print(k, jobs[k] or txt[:300])
        json.dump(jobs, open(JOBS, "w"), indent=1)

def submit_obj(keys):
    jobs = _jobs()
    for k in keys:
        if jobs.get(k): print("skip", k, jobs[k]); continue
        d, w, h, v = OBJECTS[k]
        txt, _ = ffgen.call_tool("create_map_object", {"description": d, "width": w, "height": h, "view": v,
                                                      "detail": "medium detail", "outline": "lineless",
                                                      "shading": "detailed shading"})
        m = re.search(UUID, txt)
        jobs[k] = m.group(0) if m else None
        print(k, jobs[k] or txt[:300])
        json.dump(jobs, open(JOBS, "w"), indent=1)

def poll():
    jobs = _jobs()
    for k, oid in jobs.items():
        if not oid: continue
        raw = os.path.join(REVIEW, k + "_raw.png")
        if os.path.exists(raw): print(k, "downloaded"); continue
        txt, _ = ffgen.call_tool("get_map_object", {"object_id": oid})
        if "completed" not in txt.lower():
            print(k, "status:", txt[:100].replace("\n", " | ")); continue
        url = "https://api.pixellab.ai/mcp/map-objects/%s/download" % oid
        data = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "ironwake"}), timeout=60).read()
        open(raw, "wb").write(data)
        im = Image.open(raw).convert("RGBA")
        bg = (18, 18, 28, 255) if k in SCENES else (34, 28, 24, 255)   # objects previewed on a floor tone
        base = Image.new("RGBA", im.size, bg); base.alpha_composite(im)
        base.resize((im.width * 4, im.height * 4), Image.NEAREST).save(os.path.join(REVIEW, k + "_preview_x4.png"))
        print(k, "landed", im.size)

def build_plate(key):
    """Crop the approved room to its painted content and edge-extend to 480x160 native (the
    garden plate's exact frame) -> spr_hut_plate_x4.png (1920x640). Walls: the left/right
    columns are repeated outward so the room reads as continuing wall, not a floating card."""
    raw = os.path.join(REVIEW, key + "_raw.png")
    im = Image.open(raw).convert("RGBA")
    bb = im.getbbox(); im = im.crop(bb)
    print("content", im.size)
    # scale-fit height to 160 keeping pixels crisp only when the ratio is exact; otherwise crop.
    if im.height > 160: im = im.crop((0, im.height - 160, im.width, im.height))
    W, H = 480, 160
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ox = (W - im.width) // 2
    oy = H - im.height
    out.alpha_composite(im, (ox, oy))
    lcol = im.crop((0, 0, 1, im.height)); rcol = im.crop((im.width - 1, 0, im.width, im.height))
    for x in range(0, ox): out.alpha_composite(lcol, (x, oy))
    for x in range(ox + im.width, W): out.alpha_composite(rcol, (x, oy))
    if oy > 0:
        top = out.crop((0, oy, W, oy + 1))
        for y in range(0, oy): out.alpha_composite(top, (0, y))
    out.save(os.path.join(REVIEW, "spr_hut_plate_native.png"))
    out.resize((W * 4, H * 4), Image.NEAREST).save(os.path.join(REVIEW, "spr_hut_plate_x4.png"))
    print("built spr_hut_plate_x4.png")

def do_import(keys):
    built = []
    plate = os.path.join(REVIEW, "spr_hut_plate_x4.png")
    if (not keys or "spr_hut_plate" in keys) and os.path.exists(plate):
        if gm_import.build_sprite("spr_hut_plate", plate, "spr_combatbg_scorched_1"): built.append("spr_hut_plate")
    for k in OBJECTS:
        if keys and k not in keys: continue
        raw = os.path.join(REVIEW, k + "_raw.png")
        if not os.path.exists(raw): print("no raw for", k); continue
        im = Image.open(raw).convert("RGBA")
        out = os.path.join(REVIEW, k + "_x4.png")
        if k.startswith("spr_keep_"):
            # API floor is 32px; shelf trinkets want ~16px at plate density -> crop bbox, halve NEAREST.
            im = im.crop(im.getbbox())
            sc = 12 / max(im.width, im.height)   # fits the bookshelf's top board (HUT_SHELF_DX 42 @ x4)
            im = im.resize((max(1, round(im.width * sc)), max(1, round(im.height * sc))), Image.NEAREST)
        im.resize((im.width * 4, im.height * 4), Image.NEAREST).save(out)
        if gm_import.build_sprite(k, out, "spr_combatbg_scorched_1"): built.append(k)
    gm_import.register(built)
    c0 = open(CREATE0, "rb").read().decode("utf-8")
    nl = "\r\n" if "\r\n" in c0 else "\n"
    add = [n for n in ["spr_hut_plate"] + list(OBJECTS)
           if n + "," not in c0 and os.path.exists(os.path.join(ROOT, "sprites", n, n + ".yy"))]
    if add:
        c0 = c0.replace("    spr_hub_background," + nl, "    spr_hub_background," + nl + "".join("    %s,%s" % (n, nl) for n in add), 1)
        open(CREATE0, "wb").write(c0.encode("utf-8"))
        print("Create_0: force-included", add)
    print("built", built)

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "poll"
    keys = sys.argv[2:]
    if cmd == "submit": submit(keys or ["spr_hut_plate_a"])
    elif cmd == "submit_obj": submit_obj(keys or list(OBJECTS))
    elif cmd == "poll": poll()
    elif cmd == "build_plate": build_plate(keys[0] if keys else "spr_hut_plate_a")
    elif cmd == "import": do_import(keys)
