#!/usr/bin/env python
"""09-02 combat backgrounds + floor maps for Drowned Reach / Hollow Canopy.
Recipe that shipped scorched/tundra/ashen (06-24): create_map_object, view side, 400x224,
medium detail, lineless, detailed shading; imported by cloning spr_combatbg_scorched_1.yy.
Since the 1080p re-base the shipped bgs are the SAME art x4 nearest (1600x896), so import
composites the transparent map-object onto the flat fill (18,18,28) and upscales x4 nearest.
  python tools/gen_biome_bgs_0902.py submit [key ...]
  python tools/gen_biome_bgs_0902.py poll            # downloads + previews (2x) for review
  python tools/gen_biome_bgs_0902.py import [key ...] # GM CLOSED: sprites + yyp + includes
Output: _for_review/biome_bgs_0902/
"""
import os, sys, json, re, urllib.request
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ffgen, gm_import
from PIL import Image

ROOT = ffgen.ROOT
REVIEW = os.path.join(ROOT, "_for_review", "biome_bgs_0902")
JOBS = os.path.join(REVIEW, "JOBS.json")
CREATE0 = os.path.join(ROOT, "objects", "obj_game_controller", "Create_0.gml")
os.makedirs(REVIEW, exist_ok=True)

STYLE = ("Dark gothic fantasy pixel art combat arena backdrop, wide side view, the scene framed as a rounded "
         "arena vignette fading to black at the edges, an open flat floor area across the bottom third for "
         "combatants to stand on, painterly 16-bit pixel art, moody, no characters, no creatures, no text. ")

SCENES = {
 "spr_combatbg_drowned_1": STYLE + "A flooded cathedral nave: still black-green water covering the floor, rows of drowned stone pillars receding into dark, a few hanging iron lanterns burning lantern-gold, drips and ripples, green-black palette with gold light.",
 "spr_combatbg_drowned_2": STYLE + "A sunken bell tower crossing of the drowned undercity: great verdigris bronze bells half-submerged in black-green water, rotting rope, barnacled stone arches, one gold lantern glow, drips from above.",
 "spr_combatbg_drowned_3": STYLE + "The deep lock-works of the drowned reach: colossal rusted iron sluice gates and gear wheels, water pouring through the bars into a black-green flooded floor, lantern-gold light from a few caged lamps, wet stone.",
 "spr_floormap_drowned":   STYLE + "A long DROWNED avenue of a sunken undercity seen straight down its length: the street is black-green floodwater up to the doorways, ruined and rotting gothic facades either side, collapsed sunken bell towers, thick fog, a few guttering gold lanterns reflected in the water, everything wet and abandoned. NIGHT scene, very dark, deep shadow everywhere, only a few cold gold light sources, grim and gothic, muted desaturated palette, no daylight, no bright sky.",
 "spr_combatbg_canopy_1":  STYLE + "A ruined stone hall swallowed by a dark forest: thick black roots bursting through broken walls, a mossy cracked flagstone floor, a dense dark canopy overhead with two or three narrow gold light shafts cutting the gloom, bone-white blossoms on hanging vines, deep green and bone palette. NIGHT scene, very dark, deep shadow everywhere, only a few cold gold light sources, grim and gothic, muted desaturated palette, no daylight, no bright sky.",
 "spr_combatbg_canopy_2":  STYLE + "Inside a colossal hollow witchwood tree: curved bark walls, root steps, drifting pale spore mist, gold light shafts from a gap far above, mushrooms glowing faintly, deep green and bone.",
 "spr_combatbg_canopy_3":  STYLE + "The thorn heart of the canopy: towering walls of interwoven bramble and thorn closing round the arena, pale roses and bone tangled in the hedge, a soft gold light shaft from above, deep green and bone.",
 "spr_floormap_canopy":    STYLE + "An overgrown ruin road seen straight down its length under giant black trees: gnarled root arches spanning the path, fallen columns under moss, a dense dark canopy with a few thin gold light shafts, bone-white blossoms along the verge, deep green and bone palette. NIGHT scene, very dark, deep shadow everywhere, only a few cold gold light sources, grim and gothic, muted desaturated palette, no daylight, no bright sky.",
}


def submit(keys):
    jobs = json.load(open(JOBS)) if os.path.exists(JOBS) else {}
    for k in keys:
        if jobs.get(k): print("skip", k, jobs[k]); continue
        txt, _ = ffgen.call_tool("create_map_object", {"description": SCENES[k], "width": 400, "height": 224,
                                                      "view": "side", "detail": "medium detail",
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
        base.resize((im.width * 2, im.height * 2), Image.NEAREST).save(os.path.join(REVIEW, k + "_preview.png"))
        print(k, "landed", im.size)


def do_import(keys):
    keys = keys or list(SCENES)
    built = []
    for k in keys:
        raw = os.path.join(REVIEW, k + "_raw.png")
        im = Image.open(raw).convert("RGBA")
        base = Image.new("RGBA", im.size, (18, 18, 28, 255)); base.alpha_composite(im)
        big = base.resize((im.width * 4, im.height * 4), Image.NEAREST)
        out = os.path.join(REVIEW, k + "_x4.png"); big.save(out)
        if gm_import.build_sprite(k, out, "spr_combatbg_scorched_1"): built.append(k)
    gm_import.register(built)
    txt = open(CREATE0, "r", encoding="utf-8", newline="").read()
    missing = [n for n in built if re.search(r"\b%s\b" % n, txt) is None]
    if missing:
        marker = "global.__sprite_includes = [\n"
        i = txt.index(marker) + len(marker)
        txt = txt[:i] + "    // 09-02 biome backgrounds (dungeon_bg_sprite resolves by string)\n" + \
              "".join("    %s,\n" % n for n in missing) + txt[i:]
        open(CREATE0, "w", encoding="utf-8", newline="").write(txt)
    print("built", built, "includes added", len(missing))


if __name__ == "__main__":
    c = sys.argv[1]
    if c == "submit": submit(sys.argv[2:] or list(SCENES))
    elif c == "poll": poll()
    elif c == "import": do_import(sys.argv[2:])
