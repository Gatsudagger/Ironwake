#!/usr/bin/env python
"""09-02 dungeon-select card art for the two new biomes (Drowned Reach, Hollow Canopy).
Recipe: create_1_direction_object, sidescroller view, style_images = 1 shipped 192px dungeon card
(size > 170 => 1 style image, 1 candidate). Uses ffgen's REST bridge (base64 never passes through chat).
Usage:
  python tools/cardgen.py submit <drowned_reach|hollow_canopy>
  python tools/cardgen.py poll
Jobs in _for_review/cards_0902/JOBS.json
"""
import os, sys, json, urllib.request
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ffgen import call_tool, b64file
from PIL import Image, ImageDraw
ROOT   = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REVIEW = os.path.join(ROOT, "_for_review", "cards_0902"); os.makedirs(REVIEW, exist_ok=True)
JOBS   = os.path.join(REVIEW, "JOBS.json")
SPR    = os.path.join(ROOT, "sprites")

BASE = ("A dungeon entrance card: {scene} Gothic dark fantasy pixel art, clean dark outlines, 3-4 tone "
        "shading, moody and grim, no text, no characters, transparent background around the stonework. "
        "Centered, fills most of the canvas.")
CARDS = {
 "drowned_reach": dict(anchor="spr_dungeon_tundra_tomb", scene=(
    "a half-sunken stone archway of a drowned cathedral, green-black flood water lapping over the "
    "threshold steps, a cracked bronze bell hanging inside the arch, wet moss and barnacle-crusted "
    "stone, a single lantern glowing warm gold in the dark interior, drips and ripples, "
    "palette green-black with lantern gold.")),
 "hollow_canopy": dict(anchor="spr_dungeon_ashen_vault", scene=(
    "a ruined stone doorway swallowed by overgrowth, thick dark roots and vines splitting the arch and "
    "prying the wall stones apart, deep green leaves, pale bone fragments in the dirt at the base, "
    "narrow shafts of gold light falling through the canopy onto the threshold, "
    "palette deep green with bone and gold light.")),
  "drowned_reach_v2": dict(anchor="spr_dungeon_scorched_depths", scene=(
    "NOT an archway, NOT a doorway: a very spooky fog-shrouded wooden pier and abandoned wharf at night, "
    "rotting planks and leaning mooring posts reaching out over still black-green water, thick grey fog "
    "rolling low, one faint lantern glowing weakly on the far end of the dock in the distance, broken "
    "crates and a snapped rope, dark silhouettes of a wrecked hull, wide open scene, "
    "palette green-black fog with one faint lantern gold.")),
 "hollow_canopy_v2": dict(anchor="spr_dungeon_scorched_depths", scene=(
    "NOT an archway, NOT a doorway: a haunted forest interior where enormous dark tree trunks rise up "
    "out of frame into the sky, thick vines strung between the trees forming climbing paths and "
    "tubular hollow plant tunnels winding upward, several human skeletons hanging by ropes from the "
    "branches, deep green leaves and pale bone, narrow shafts of gold light from above, "
    "palette deep green with bone and gold light.")),
  "drowned_reach_v3": dict(anchor="spr_dungeon_tundra_tomb", scene=(
    "NOT an archway, NOT a doorway: a haunted abandoned wharf at night, seen from the shore. Dense "
    "pale grey-green fog fills the whole scene top to bottom, dark still water in the foreground with "
    "faint ripples, a rotting wooden pier with leaning mooring posts vanishing into the fog, one faint "
    "lantern glowing dim gold at the far end of the dock, crooked pilings and a sagging warehouse "
    "silhouette behind, seaweed and rope on the planks, dread and silence, fills the canvas, "
    "palette green-black fog with one faint lantern gold.")),
  "drowned_reach_v4": dict(anchor="_for_review/cards_0902/drowned_reach/cand_0.png", scene=(
    "NOT an archway, NOT a doorway: a haunted abandoned harbor in a sheltered cove at night. A ghostly "
    "sound, a wide dark sea inlet, fills the middle of the scene with still black-green water and pale "
    "drifting fog. Several rotting abandoned fishing boats sit moored and half-sunk at a crooked wooden "
    "pier. Behind them an abandoned sea town: dark leaning cottages and a crumbling stone quay, every "
    "window black, one faint lantern glowing dim gold on the pier. Rocky cove walls close the sides. "
    "The whole canvas is filled edge to edge, dread and silence, palette green-black with faint gold.")),
 "hollow_canopy_v3": dict(anchor="_for_review/cards_0902/hollow_canopy_v2/cand_0.png", scene=(
    "NOT an archway, NOT a doorway: a haunted forest interior where enormous dark gnarled tree trunks "
    "rise up out of frame into the sky. Thick knotted vines strung between the trees form climbing "
    "paths, and hollow overgrown plant tunnels wind upward between them - the tunnels are organic, "
    "lumpy, irregular and twisted like giant roots and grown-over branches, NOT smooth cylinders or "
    "pipes. Several human skeletons hang by ropes from the branches. Deep green leaves, pale bone, "
    "narrow shafts of gold light from above, fills the canvas, palette deep green with bone and gold.")),
  "drowned_reach_v5": dict(anchor="_for_review/cards_0902/drowned_reach_v2/cand_0.png", scene=(
    "NOT an archway, NOT a doorway: a very spooky fog-shrouded wooden pier and abandoned wharf at night, "
    "seen straight on from the shore end so the rotting planks lead away from the viewer over still "
    "black-green water. Thick visible grey-green fog banks roll across the scene, dense and layered, "
    "swallowing the far end of the pier. Faintly through the fog in the background looms a ghostly "
    "tattered sailing ship, pale and translucent, torn sails hanging from its masts. One faint lantern "
    "glows weakly on a mooring post far down the dock. Broken crates, coiled rope, leaning posts. "
    "Fog and water fill the canvas edge to edge, palette green-black fog with one faint lantern gold.")),
  "drowned_reach_v6": dict(full=True, anchor="_for_review/cards_0902/drowned_reach_v5/cand_0.png", scene=(
    "a FULLY PAINTED scene with NO transparency anywhere - every pixel filled: a very spooky abandoned "
    "wooden pier and wharf at night seen from the shore end, rotting planks leading away over still "
    "black-green water that fills the bottom of the frame. The entire sky is thick grey-green fog, dense "
    "layered fog banks rolling low over the water and swallowing the far end of the pier. Faintly through "
    "the fog looms a ghostly tattered sailing ship, pale and translucent, torn sails on its masts. One "
    "faint lantern glows weakly on a mooring post far down the dock. Broken crates and coiled rope on the "
    "near planks. Palette green-black fog with one faint lantern gold.")),
}

def anchor(name):
    if name.endswith(".png"): path = os.path.join(ROOT, name)
    else:
        d = os.path.join(SPR, name); path = os.path.join(d, sorted(x for x in os.listdir(d) if x.endswith(".png"))[0])
    return [{"base64": b64file(path), "format": "png", "type": "base64"}]

def load(): return json.load(open(JOBS)) if os.path.exists(JOBS) else []
def save(j): json.dump(j, open(JOBS, "w"), indent=1)

FULL = ("A dungeon selection card: {scene} Gothic dark fantasy pixel art, clean dark outlines, 3-4 tone "
        "shading, moody and grim, no text, no characters. The scene fills the whole square canvas edge to "
        "edge like a painted panel - no transparent background, no cut-out.")

def submit(k):
    c = CARDS[k]
    tmpl = FULL if c.get("full") else BASE
    txt, _ = call_tool("create_1_direction_object", {"description": tmpl.format(scene=c["scene"]),
                        "view": "sidescroller", "style_images": anchor(c["anchor"])})
    print(txt)
    oid = None
    for tok in txt.replace('"', ' ').replace(':', ' ').split():
        if len(tok) == 36 and tok.count("-") == 4: oid = tok; break
    j = load(); j.append({"type": k, "object_id": oid, "done": False}); save(j)
    print("queued", k, oid)

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
        job["done"] = True; job["urls"] = urls; print("sheet ->", sp, f"({len(ims)} candidates, {W}x{H})")
    save(j)

if __name__ == "__main__":
    if sys.argv[1] == "submit": submit(sys.argv[2])
    elif sys.argv[1] == "poll": poll()
