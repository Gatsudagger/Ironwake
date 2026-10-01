#!/usr/bin/env python
"""09-30 PET HEADSTONES (M: a lost creature leaves its headstone as a placeable garden ornament;
variants by species kind - small fitting indicators, not arbitrary variety; the pet's NAME is
drawn over the blank face in code). Same recipe as the grounds ornaments
(tools/gen_garden_plate_0917.py): create_map_object, lineless, detailed shading, x4 NEAREST,
origin top-left, imported as spr_garden_grave_<motif>.
  python tools/gen_graves_0930.py submit [key ...]
  python tools/gen_graves_0930.py poll
  python tools/gen_graves_0930.py sheet            # labelled review sheet
  python tools/gen_graves_0930.py import [key ...] # GM CLOSED
Output: _for_review/graves_0930/
"""
import os, sys, json, re, urllib.request
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ffgen, gm_import
from PIL import Image, ImageDraw

ROOT = ffgen.ROOT
REVIEW = os.path.join(ROOT, "_for_review", "graves_0930")
JOBS = os.path.join(REVIEW, "JOBS.json")
os.makedirs(REVIEW, exist_ok=True)
CREATE0 = os.path.join(ROOT, "objects", "obj_game_controller", "Create_0.gml")

# Grounds-ornament style, verbatim (gen_garden_plate_0917.py OBJ_STYLE).
OBJ_STYLE = ("Dark gothic fantasy pixel art, painterly 16-bit, lineless, detailed shading, muted desaturated "
             "night palette (deep green-black, slate grey, a little cold gold light), transparent background, "
             "no text, no ground plane, the object alone. ")
# Every stone keeps a SMOOTH BLANK FACE (the game engraves the name there) - the motif lives on
# the top, the edges and the foot.
GRAVE = ("A small weathered grey slate HEADSTONE for a beloved animal companion, upright, rounded top, "
         "front view facing the viewer, with a smooth flat blank face in the middle with NO writing and NO "
         "carving on the face, a little moss at its foot. ")
OBJECTS = {
 # re-roll 1 (09-30): the first came back with a vague round mark and no collar.
 "spr_garden_grave_hound":   (OBJ_STYLE + GRAVE + "On the rounded top of the stone sits a clearly visible red-brown LEATHER DOG COLLAR with a round brass tag, looped over the top edge and hanging down one side. A small old dog bone lies on the moss at the foot. The collar is the obvious feature.", 36, 48, "low top-down"),
 # re-roll 1 (09-30): the first came back as a plain gothic arch with no wings.
 "spr_garden_grave_wing":    (OBJ_STYLE + GRAVE + "Two large carved stone BIRD WINGS spread out from the left and right sides of the headstone, clearly visible, feathered, wider than the stone itself, like an angel memorial but with no figure. Two black feathers lie at its foot.", 48, 48, "low top-down"),
 "spr_garden_grave_serpent": (OBJ_STYLE + GRAVE + "A slim carved stone serpent coiled around the top of the headstone, its head resting on the rounded top, and a shed scaly skin at its foot.", 36, 48, "low top-down"),
 "spr_garden_grave_moth":    (OBJ_STYLE + GRAVE + "A pale moth with open wings carved in relief at the top of the stone, and a few pale white night-blossoms growing at its foot.", 36, 48, "low top-down"),
 # 09-30 batch 2 (M: "samples look good") - the other six motifs.
 "spr_garden_grave_horn":   (OBJ_STYLE + GRAVE + "A pair of curved pale bone ANTLERS or horns rising from the top of the stone like a crown, clearly visible, and a sprig of heather at its foot.", 40, 48, "low top-down"),
 "spr_garden_grave_shell":  (OBJ_STYLE + GRAVE + "A small round spiral SNAIL SHELL and a tortoise-shell fragment resting on top of the stone, clearly visible, and smooth river pebbles at its foot.", 36, 48, "low top-down"),
 # re-roll 1: first had only the yarn, no cat.
 "spr_garden_grave_feline": (OBJ_STYLE + GRAVE + "On TOP of the headstone lies a small black CAT, sleeping, curled into a ball, its tail hanging down over the front edge - a real cat shape with two pointed ears, clearly the main feature. A ball of yarn at the foot.", 36, 52, "low top-down"),
 "spr_garden_grave_mire":   (OBJ_STYLE + GRAVE + "Two small pale TOADSTOOL mushrooms growing from the top edge of the stone and a tiny carved frog sitting at its foot beside a little puddle, clearly visible.", 36, 48, "low top-down"),
 # re-roll 1: first came back as a plain arch.
 "spr_garden_grave_tide":   (OBJ_STYLE + GRAVE + "Grey slate stone. A big pale SCALLOP SEASHELL fixed on top of the stone as its crown, clearly visible and fan-shaped, and a pile of small seashells and a strand of dark green kelp at its foot.", 36, 52, "low top-down"),
 # re-roll 1: first showed no ears.
 "spr_garden_grave_burrow": (OBJ_STYLE + GRAVE + "Grey slate stone. A small brown FIELD MOUSE sits on top of the stone, clearly visible with round ears and a long tail, and a little mound of dug earth with an ACORN at its foot.", 36, 52, "low top-down"),
}

UUID = r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"

def _jobs():
    return json.load(open(JOBS)) if os.path.exists(JOBS) else {}

def submit(keys):
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
        print(k, "landed", Image.open(raw).size)

def sheet():
    """Labelled review sheet: each stone x4 on the grass tone, beside two shipped ornaments
    (ward, lantern) for density/style comparison."""
    tiles = []
    for ref in ["spr_garden_orn_ward", "spr_garden_orn_lantern"]:
        d = os.path.join(ROOT, "sprites", ref)
        png = [f for f in os.listdir(d) if f.endswith(".png")][0]
        tiles.append(("SHIPPED " + ref.replace("spr_garden_orn_", ""), Image.open(os.path.join(d, png)).convert("RGBA")))
    for k in OBJECTS:
        raw = os.path.join(REVIEW, k + "_raw.png")
        if not os.path.exists(raw): continue
        im = Image.open(raw).convert("RGBA")
        im = im.crop(im.getbbox())
        tiles.append((k.replace("spr_garden_grave_", "NEW "), im.resize((im.width * 4, im.height * 4), Image.NEAREST)))
    pad, lab = 24, 30
    W = sum(t.width for _, t in tiles) + pad * (len(tiles) + 1)
    H = max(t.height for _, t in tiles) + pad * 2 + lab
    out = Image.new("RGBA", (W, H), (24, 34, 26, 255))
    dr = ImageDraw.Draw(out)
    x = pad
    for name, t in tiles:
        out.alpha_composite(t, (x, H - pad - t.height))
        dr.text((x, 8), name, fill=(230, 230, 210, 255))
        x += t.width + pad
    p = os.path.join(REVIEW, "_sheet_graves.png")
    out.save(p); print("sheet", p)

def do_import(keys):
    built = []
    for k in OBJECTS:
        if keys and k not in keys: continue
        raw = os.path.join(REVIEW, k + "_raw.png")
        if not os.path.exists(raw): print("no raw for", k); continue
        im = Image.open(raw).convert("RGBA")
        out = os.path.join(REVIEW, k + "_x4.png")
        im.resize((im.width * 4, im.height * 4), Image.NEAREST).save(out)
        if gm_import.build_sprite(k, out, "spr_combatbg_scorched_1"): built.append(k)
    gm_import.register(built)
    c0 = open(CREATE0, "rb").read().decode("utf-8")
    nl = "\r\n" if "\r\n" in c0 else "\n"
    add = [n for n in OBJECTS if n + "," not in c0 and os.path.exists(os.path.join(ROOT, "sprites", n, n + ".yy"))]
    if add:
        c0 = c0.replace("    spr_hub_background," + nl, "    spr_hub_background," + nl + "".join("    %s,%s" % (n, nl) for n in add), 1)
        open(CREATE0, "wb").write(c0.encode("utf-8"))
        print("Create_0: force-included", add)
    print("built", built)

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "poll"
    keys = sys.argv[2:]
    if cmd == "submit": submit(keys or list(OBJECTS))
    elif cmd == "poll": poll()
    elif cmd == "sheet": sheet()
    elif cmd == "import": do_import(keys)
