#!/usr/bin/env python
"""09-17 BAIRC'S GARDEN diorama plate (M-locked 09-17: 3/4 painted plate, free 2-axis walk).
Recipe = the shipped backdrop recipe (hub camp + every combat bg): create_map_object,
400x224 native, lineless, detailed shading, composited on (18,18,28) and upscaled x4 NEAREST
to 1600x896 (shipped backdrop density). The 3-screen plate is 3 panels (west / centre / east);
seams are hidden by a hedge/arch map-object at each join. Walk mask is AUTHORED in GML, not
generated.
  python tools/gen_garden_plate_0917.py submit [key ...]
  python tools/gen_garden_plate_0917.py poll
  python tools/gen_garden_plate_0917.py import [key ...]   # GM CLOSED
Output: _for_review/garden_0917/
"""
import os, sys, json, re, urllib.request
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ffgen, gm_import
from PIL import Image

ROOT = ffgen.ROOT
REVIEW = os.path.join(ROOT, "_for_review", "garden_0917")
JOBS = os.path.join(REVIEW, "JOBS.json")
os.makedirs(REVIEW, exist_ok=True)

STYLE = ("Dark gothic fantasy pixel art night scene, three-quarter view from slightly above, painterly 16-bit "
         "pixel art, moody, muted desaturated palette, NIGHT, very dark, deep shadow, a few cold gold lantern "
         "lights and pale blue moonlight, no characters, no creatures, no text. The lower HALF of the frame is "
         "an open flat walkable ground plane of mossy earth and worn flagstone paths seen from above, clear "
         "of obstacles, so figures can walk across it; scenery and walls only in the upper half and at the far edges. ")

SCENES = {
 # PILOT: the centre panel (pond + Bairc's hut). West/east panels wait for M's verdict.
 "spr_garden_plate_c": STYLE + "Bairc's night garden: a still black-green pond with moon glint at centre-left of the ground, "
     "a small crooked stone hut with one warm lit window at the back, a low mossy dry-stone wall along the top edge, "
     "gnarled black trees behind it, a stone lantern glowing gold, nightbloom flowers, fireflies, starry sky above the treeline.",
 # 09-17 re-roll (first W/E came back as enclosed courtyards + lighter palette): the flanks
 # must CONTINUE the centre panel - one long field, wall only across the top, ground bleeding
 # off both sides, same very dark green-black night palette, bare black treeline + stars above.
 "spr_garden_plate_w": STYLE + "A wide continuous section of the same night garden field, NOT a courtyard: NO walls on the "
     "left, right or bottom edges, the mossy grass ground runs off the left and right edges of the frame and off the "
     "bottom. Only ONE low mossy dry-stone wall runs straight across the upper part of the frame, with bare gnarled "
     "black leafless trees and a starry night sky above it. Set into that back wall: a weathered iron gate lit by two "
     "gold lanterns. On the grass: a worn flagstone path from the gate, an old stone bench, a few nightbloom flowers. "
     "Very dark, desaturated deep green-black grass, no bright colours.",
 "spr_garden_plate_e": STYLE + "A wide continuous section of the same night garden field, NOT a courtyard: NO walls on the "
     "left, right or bottom edges, the mossy grass ground runs off the left and right edges of the frame and off the "
     "bottom. Only ONE low mossy dry-stone wall runs straight across the upper part of the frame, with bare gnarled "
     "black leafless trees and a starry night sky above it. On the grass near the back wall: a small quiet memorial "
     "grove of five pale weathered headstones, a cairn of stacked grey stones, pale bone-white blossoms, thin low mist. "
     "Very dark, desaturated deep green-black grass, no purple, no bright colours.",
}


# ---- 09-17 late: transparent OBJECTS at plate density (canopy strip + real ornaments) ----
OBJ_STYLE = ("Dark gothic fantasy pixel art, painterly 16-bit, lineless, detailed shading, muted desaturated "
             "night palette (deep green-black, slate grey, a little cold gold light), transparent background, "
             "no text, no ground plane, the object alone. ")
OBJECTS = {
 # key: (description, w, h, view)
 "spr_garden_canopy": (OBJ_STYLE + "A wide horizontal strip of the TOP of a dark forest: bare gnarled black leafless "
     "branch crowns seen front-on, dense tangled twigs along the bottom edge thinning to nothing at the top edge "
     "(the top third is mostly empty/transparent), no trunks, no sky, no ground. Tileable left-to-right.", 400, 112, "low top-down"),
 "spr_garden_orn_lantern": (OBJ_STYLE + "A small carved slate stone lantern (toro) on a mossy stone base, a warm gold "
     "ember glowing behind its window slats, weathered, front three-quarter view.", 40, 56, "low top-down"),
 "spr_garden_orn_gate":    (OBJ_STYLE + "A weathered spirit gate: two dark wooden posts and a double lintel, the space between them faintly lit violet, moss on the feet.", 72, 64, "low top-down"),
 "spr_garden_orn_basin":   (OBJ_STYLE + "A shallow stone moon basin on a short pedestal, still dark water inside reflecting a small pale moon.", 44, 40, "low top-down"),
 "spr_garden_orn_bloom":   (OBJ_STYLE + "A patch of nightbloom flowers: seven slender dark stems with small violet and pale-blue glowing blossoms.", 48, 32, "low top-down"),
 "spr_garden_orn_ward":    (OBJ_STYLE + "A small squat mossy stone spirit statue, round head, two faint green glowing eyes, ancient and kind.", 36, 52, "low top-down"),
 "spr_garden_orn_chimes":  (OBJ_STYLE + "Bone wind chimes: a crooked dark wooden post and crossbar with four pale bone tubes hanging on cord.", 44, 64, "low top-down"),
 # wheel re-roll 09-17 (first came back as a hutch): explicit spoked wheel, no roof/walls.
 "spr_garden_orn_wheel":   (OBJ_STYLE + "A large old wooden WATER WHEEL: a round spoked mill wheel with paddles, seen from the side, mounted on a short dark post and axle, worn and slick with moss. It is a WHEEL, a circle with spokes - NOT a house, no roof, no walls, no windows.", 48, 48, "low top-down"),
 # SEASONAL CANOPIES (M-locked 09-17 late, layered seasons on one plate): same recipe as the
 # approved bare canopy; keyed on the grey-green background and tinted per theme at import.
 "spr_garden_canopy_autumn":    (OBJ_STYLE + "A wide horizontal strip of the TOP of an autumn forest: gnarled branch crowns thick with amber, rust and dark-red leaves, dense along the bottom edge thinning to nothing at the top edge (top third empty), no trunks, no sky, no ground. Tileable left-to-right.", 400, 112, "low top-down"),
 "spr_garden_canopy_winter":    (OBJ_STYLE + "A wide horizontal strip of the TOP of a winter forest: bare black gnarled branch crowns laden with white snow and rime, dense along the bottom edge thinning to nothing at the top edge (top third empty), no trunks, no sky, no ground. Tileable left-to-right.", 400, 112, "low top-down"),
 "spr_garden_canopy_spring":    (OBJ_STYLE + "A wide horizontal strip of the TOP of a spring forest at night: gnarled branch crowns covered in pale pink and bone-white blossom, dense along the bottom edge thinning to nothing at the top edge (top third empty), no trunks, no sky, no ground. Tileable left-to-right.", 400, 112, "low top-down"),
 "spr_garden_canopy_bloodmoon": (OBJ_STYLE + "A wide horizontal strip of the TOP of a dead forest under a blood moon: jagged black thorny branch crowns with a faint dark-crimson rim light, dense along the bottom edge thinning to nothing at the top edge (top third empty), no trunks, no sky, no ground. Tileable left-to-right.", 400, 112, "low top-down"),
 "spr_garden_koi_a":      (OBJ_STYLE + "A single small koi fish seen directly from above, swimming, body pointing RIGHT: orange-red back with two bone-white patches, a soft translucent tail fin. Just the fish, nothing else, filling the frame left to right.", 32, 32, "high top-down"),
 "spr_garden_koi_b":      (OBJ_STYLE + "A single small koi fish seen directly from above, swimming, body pointing RIGHT: pale cream-white back with a few slate-grey and dull gold speckles, a soft translucent tail fin. Just the fish, nothing else, filling the frame left to right.", 32, 32, "high top-down"),
 "spr_garden_orn_jar":     (OBJ_STYLE + "A glass firefly jar with its lid ajar, three yellow-green fireflies glowing inside, set on the grass.", 32, 36, "low top-down"),
}

def submit_obj(keys):
    jobs = json.load(open(JOBS)) if os.path.exists(JOBS) else {}
    for k in keys:
        if jobs.get(k): print("skip", k, jobs[k]); continue
        d, w, h, v = OBJECTS[k]
        txt, _ = ffgen.call_tool("create_map_object", {"description": d, "width": w, "height": h, "view": v,
                                                      "detail": "medium detail", "outline": "lineless",
                                                      "shading": "detailed shading"})
        m = re.search(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", txt)
        jobs[k] = m.group(0) if m else None
        print(k, jobs[k] or txt[:300])
        json.dump(jobs, open(JOBS, "w"), indent=1)

def poll_obj():
    """Objects stay TRANSPARENT: raw + a x4 preview on the plate's grass tone."""
    jobs = json.load(open(JOBS))
    for k, oid in jobs.items():
        if not oid or k not in OBJECTS: continue
        raw = os.path.join(REVIEW, k + "_raw.png")
        if os.path.exists(raw): print(k, "downloaded"); continue
        txt, _ = ffgen.call_tool("get_map_object", {"object_id": oid})
        if "completed" not in txt.lower():
            print(k, "status:", txt[:100].replace("\n", " | ")); continue
        url = "https://api.pixellab.ai/mcp/map-objects/%s/download" % oid
        data = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "ironwake"}), timeout=60).read()
        open(raw, "wb").write(data)
        im = Image.open(raw).convert("RGBA")
        base = Image.new("RGBA", im.size, (24, 33, 26, 255)); base.alpha_composite(im)
        base.resize((im.width * 4, im.height * 4), Image.NEAREST).save(os.path.join(REVIEW, k + "_preview_x4.png"))
        print(k, "landed", im.size)


def submit(keys):
    jobs = json.load(open(JOBS)) if os.path.exists(JOBS) else {}
    for k in keys:
        if jobs.get(k): print("skip", k, jobs[k]); continue
        txt, _ = ffgen.call_tool("create_map_object", {"description": SCENES[k], "width": 400, "height": 224,
                                                      "view": "low top-down", "detail": "medium detail",
                                                      "outline": "lineless", "shading": "detailed shading"})
        m = re.search(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", txt)
        jobs[k] = m.group(0) if m else None
        print(k, jobs[k] or txt[:300])
        json.dump(jobs, open(JOBS, "w"), indent=1)


def poll():
    jobs = json.load(open(JOBS))
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
        base = Image.new("RGBA", im.size, (18, 18, 28, 255)); base.alpha_composite(im)
        base.resize((im.width * 4, im.height * 4), Image.NEAREST).save(os.path.join(REVIEW, k + "_preview_x4.png"))
        print(k, "landed", im.size)


CREATE0 = os.path.join(ROOT, "objects", "obj_game_controller", "Create_0.gml")

def do_import(keys):
    """09-17 OUTCOME: W/E flanks missed twice (enclosed courtyards, palette drift) -> STOP rule.
    Shipped plate = the approved CENTRE panel cropped to its painted content and edge-tiled to
    480x160 native (1920x640 @ x4) by the scratch build_plate.py -> _for_review/garden_0917/
    spr_garden_plate_x4.png. Imports that ONE sprite (spr_garden_plate) and force-includes it
    (asset_get_index lookup, see project_hub_atmosphere tree-shake lesson). GM must be CLOSED."""
    src = os.path.join(REVIEW, "spr_garden_plate_x4.png")
    if not os.path.exists(src):
        raise SystemExit("missing " + src + " - run the build_plate step first")
    built = []
    if gm_import.build_sprite("spr_garden_plate", src, "spr_combatbg_scorched_1"): built.append("spr_garden_plate")
    # 09-17 late: canopy (keyed + tinted by the scratch mock_canopy.py -> _tinted.png) + the 8
    # ornaments, all TRANSPARENT, x4 nearest, origin top-left (draw code centres on width and
    # stands the opaque bbox bottom on the baseline).
    # Canopy strips (bare + any seasonal strip that landed; winter/spring/bloodmoon MISSED 09-17
    # and their themes tint the bare strip in code instead - see garden_theme_catalog canopy_tint).
    for k in OBJECTS:
        if not k.startswith("spr_garden_canopy"): continue
        can = os.path.join(REVIEW, k + "_tinted.png")
        if not os.path.exists(can): continue
        im = Image.open(can).convert("RGBA")
        out = os.path.join(REVIEW, k + "_x4.png")
        im.resize((im.width * 4, im.height * 4), Image.NEAREST).save(out)
        if gm_import.build_sprite(k, out, "spr_combatbg_scorched_1"): built.append(k)
    for k in OBJECTS:
        if k.startswith("spr_garden_canopy"): continue
        raw = os.path.join(REVIEW, k + "_raw.png")
        if not os.path.exists(raw): print("no raw for", k); continue
        im = Image.open(raw).convert("RGBA")
        out = os.path.join(REVIEW, k + "_x4.png")
        if k.startswith("spr_garden_koi"):
            # 09-19 koi: API floor is 32px, the pond wants ~16px fish at plate density -> crop the
            # alpha bbox, halve NEAREST, mirror koi_a (landed pointing LEFT) so both point RIGHT,
            # x4, CENTRE origin (draw code rotates them along the orbit).
            im = im.crop(im.getbbox())
            im = im.resize((max(1, im.width // 2), max(1, im.height // 2)), Image.NEAREST)
            if k == "spr_garden_koi_a": im = im.transpose(Image.FLIP_LEFT_RIGHT)
            W, H = im.width * 4, im.height * 4
            im.resize((W, H), Image.NEAREST).save(out)
            if gm_import.build_sprite(k, out, "spr_combatbg_scorched_1"):
                yyp = os.path.join(ROOT, "sprites", k, k + ".yy")
                yy = open(yyp, encoding="utf-8").read()
                yy = re.sub(r'"origin":\d+', '"origin":4', yy)
                yy = re.sub(r'"xorigin":\d+', '"xorigin":%d' % (W // 2), yy)
                yy = re.sub(r'"yorigin":\d+', '"yorigin":%d' % (H // 2), yy)
                open(yyp, "w", encoding="utf-8").write(yy)
                built.append(k)
            continue
        im.resize((im.width * 4, im.height * 4), Image.NEAREST).save(out)
        if gm_import.build_sprite(k, out, "spr_combatbg_scorched_1"): built.append(k)
    gm_import.register(built)
    c0 = open(CREATE0, "rb").read().decode("utf-8")
    nl = "\r\n" if "\r\n" in c0 else "\n"
    add = [n for n in ["spr_garden_plate"] + list(OBJECTS)
           if n + "," not in c0 and os.path.exists(os.path.join(ROOT, "sprites", n, n + ".yy"))]
    if add:
        c0 = c0.replace("    spr_hub_background," + nl, "    spr_hub_background," + nl + "".join("    %s,%s" % (n, nl) for n in add), 1)
        open(CREATE0, "wb").write(c0.encode("utf-8"))
        print("Create_0: force-included", add)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "poll"
    keys = sys.argv[2:]
    if cmd == "submit": submit(keys or ["spr_garden_plate_c"])
    elif cmd == "poll": poll(); poll_obj()
    elif cmd == "submit_obj": submit_obj(keys)
    elif cmd == "import": do_import(keys)
