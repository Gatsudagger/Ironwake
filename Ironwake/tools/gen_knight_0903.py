#!/usr/bin/env python
"""09-03 THE SEAHORSE KNIGHT art run (M YES ~195 gens, two rounds). Every call rides the
shipped recipe for its category, over ffgen's REST bridge (base64 never through chat):
  knight   create_image_pro 64x64, style_ff_single.png, refs = M's shirt logo (character base)
           + spr_skeleton_soldier_ff (pixel-density only)      -> spr_seahorse_knight
  scene    create_map_object 400x224 side / medium / lineless / detailed (combat-bg recipe)
                                                               -> spr_event_splash_seahorse_knight
  idle     image_to_pixelart(logo, 160px, faithful) then animate_image 8f  -> spr_npc_seahorse_knight_idle
  pet      ffgen.submit("hippocamp", stage, dir)  (species recipe; adult_s first, M picks)
  egg      egggen.submit("tidal")                  (egg recipe, 4 candidates)
  python tools/gen_knight_0903.py round1 | poll | idle_anim <pixelart.png> | sheet
Output: _for_review/knight_0903/
"""
import os, sys, json, re, io, base64, urllib.request
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ffgen, egggen
from PIL import Image, ImageDraw

ROOT   = ffgen.ROOT
REVIEW = os.path.join(ROOT, "_for_review", "knight_0903"); os.makedirs(REVIEW, exist_ok=True)
JOBS   = os.path.join(REVIEW, "JOBS.json")
LOGO   = r"C:\Users\miles\Documents\Seahorse Games (Logos Merch)\Seahorse Game Co\colorful seahorse knight 3 upscale-nobg.png"
STYLE  = os.path.join(ROOT, "_for_review", "enemies_hd_0816", "_refs", "style_ff_single.png")
DENS   = os.path.join(ROOT, "sprites", "spr_skeleton_soldier_ff")

ffgen.SPECIES["hippocamp"] = ("Hippocamp",
    "a fantastical armoured SEAHORSE war-steed: blue-green scaled seahorse body with a tightly curled tail, "
    "a horse-like head with a flowing dark kelp mane, an orange-red leather bridle, ridged fins down the back, "
    "pale belly, one bright eye, coral-red accents, a little sea-spray at the tail")
egggen.EGGS["tidal"] = ("Deep sea-green shell with pearlescent blue-teal swirls like wave-foam wrapping around it "
                        "and a few tiny coral-red flecks, a faint cool sheen.")

KNIGHT_DESC = ("Pixel art enemy-style character sprite in EXACTLY the same style as the reference sprite (same game): "
               "bold black outline, flat limited colours, chunky pixels, simple readable shapes. Subject: THE SEAHORSE KNIGHT "
               "from the character-base reference - an armoured knight in blue steel plate with a closed helm and a long "
               "orange-red plume and cape, longsword raised, riding a rearing blue-green SEAHORSE mount with a curled tail, "
               "dark kelp mane and orange-red bridle. Full body, 3/4-front view facing RIGHT, about 54 pixels tall on a 64x64 "
               "canvas. ONLY the rider and mount on a fully transparent background - no ground, no water, no props, no text.")
SCENE_DESC = ("Dark gothic fantasy pixel art scene, wide side view, painterly 16-bit pixel art, moody, no characters, no creatures, "
              "no text. The drowned reach shoreline where a flooded cathedral's broken stone steps meet still black-green sea water; "
              "low surf foaming over the lowest step, drowned pillars receding into dark on the left, a couple of hanging iron "
              "lanterns burning lantern-gold, a pale moon-glow on the water far right, drips and ripples. Open floor space on the "
              "right third where a rider could stand.")

def b64(p): return base64.b64encode(open(p, "rb").read()).decode()
def dens_png():
    d = DENS; f = sorted(x for x in os.listdir(d) if x.endswith(".png"))[0]; return os.path.join(d, f)
def logo_at(px):
    p = os.path.join(REVIEW, "_logo_%d.png" % px)
    if not os.path.exists(p):
        im = Image.open(LOGO).convert("RGBA"); im.thumbnail((px, px), Image.LANCZOS); im.save(p)
    return p
def jobs(): return json.load(open(JOBS)) if os.path.exists(JOBS) else {}
def savej(j): json.dump(j, open(JOBS, "w"), indent=1)
def jid(txt):
    m = re.search(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", txt); return m.group(0) if m else None

def round1():
    J = jobs()
    if not J.get("knight"):
        txt, _ = ffgen.call_tool("create_image_pro", {
            "description": KNIGHT_DESC, "width": 64, "height": 64, "no_background": True,
            "style_image_base64": b64(STYLE),
            "reference_images": json.dumps([
                {"base64": b64(logo_at(256)), "usage": "character base - the exact same rider, mount, armour and colours"},
                {"base64": b64(dens_png()),   "usage": "pixel density and scale reference only - NOT the subject"}])})
        J["knight"] = jid(txt); print("knight", J["knight"] or txt[:200]); savej(J)
    for k in ("scene_a", "scene_b"):
        if not J.get(k):
            txt, _ = ffgen.call_tool("create_map_object", {"description": SCENE_DESC, "width": 400, "height": 224,
                "view": "side", "detail": "medium detail", "outline": "lineless", "shading": "detailed shading"})
            J[k] = jid(txt); print(k, J[k] or txt[:200]); savej(J)
    if not J.get("idle_px"):
        txt, _ = ffgen.call_tool("image_to_pixelart", {"image_base64": b64(logo_at(1024)), "output_width": 160,
            "output_height": 160, "faithful": True, "init_image_strength": 200})
        J["idle_px"] = jid(txt); print("idle_px", J["idle_px"] or txt[:200]); savej(J)
    if not J.get("pet_adult_s"):
        J["pet_adult_s"] = ffgen.submit("hippocamp", "adult", "s"); savej(J)
    if not J.get("egg"):
        egggen.submit("tidal"); J["egg"] = "egggen"; savej(J)

def dl(url, p):
    open(p, "wb").write(urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "ironwake"}), timeout=90).read())

def poll():
    J = jobs()
    # knight (create_image_pro -> get_image, 16 candidates)
    if J.get("knight") and not os.path.exists(os.path.join(REVIEW, "SHEET_knight.png")):
        txt, res = ffgen.call_tool("get_image", {"job_id": J["knight"]})
        urls = [w.strip("(),") for w in txt.split() if w.startswith("http")]
        if "completed" in txt.lower() and urls:
            ims = []
            for i, u in enumerate(dict.fromkeys(urls)):
                p = os.path.join(REVIEW, "knight_%02d.png" % i); dl(u, p); ims.append(Image.open(p).convert("RGBA"))
            sheet(ims, "knight", 4)
            print("knight LANDED", len(ims))
        else: print("knight:", txt[:120].replace("\n", " | "))
    for k in ("scene_a", "scene_b"):
        if J.get(k) and not os.path.exists(os.path.join(REVIEW, k + ".png")):
            txt, _ = ffgen.call_tool("get_map_object", {"object_id": J[k]})
            urls = [w.strip("(),") for w in txt.split() if w.startswith("http")]
            if "completed" in txt.lower() and urls:
                dl(urls[0], os.path.join(REVIEW, k + ".png"))
                im = Image.open(os.path.join(REVIEW, k + ".png")).convert("RGBA")
                bg = Image.new("RGBA", im.size, (18, 18, 28, 255)); bg.alpha_composite(im)
                bg.resize((800, 448), Image.NEAREST).save(os.path.join(REVIEW, k + "_preview2x.png"))
                print(k, "LANDED")
            else: print(k + ":", txt[:120].replace("\n", " | "))
    if J.get("idle_px") and not os.path.exists(os.path.join(REVIEW, "idle_pixelart.png")):
        txt, _ = ffgen.call_tool("get_image", {"job_id": J["idle_px"]})
        urls = [w.strip("(),") for w in txt.split() if w.startswith("http")]
        if "completed" in txt.lower() and urls:
            dl(urls[0], os.path.join(REVIEW, "idle_pixelart.png"))
            Image.open(os.path.join(REVIEW, "idle_pixelart.png")).convert("RGBA").resize((480, 480), Image.NEAREST).save(os.path.join(REVIEW, "idle_pixelart_preview3x.png"))
            print("idle_px LANDED")
        else: print("idle_px:", txt[:120].replace("\n", " | "))
    if J.get("idle_anim") and not os.path.exists(os.path.join(REVIEW, "idle_anim_strip.png")):
        txt, _ = ffgen.call_tool("get_image", {"job_id": J["idle_anim"]})
        urls = [w.strip("(),") for w in txt.split() if w.startswith("http")]
        if "completed" in txt.lower() and urls:
            frames = []
            for i, u in enumerate(dict.fromkeys(urls)):
                p = os.path.join(REVIEW, "idle_frame_%02d.png" % i); dl(u, p); frames.append(Image.open(p).convert("RGBA"))
            W, H = frames[0].size
            strip = Image.new("RGBA", (W * len(frames), H), (30, 28, 34, 255))
            for i, f in enumerate(frames): strip.alpha_composite(f, (i * W, 0))
            strip.save(os.path.join(REVIEW, "idle_anim_strip.png")); print("idle_anim LANDED", len(frames))
        else: print("idle_anim:", txt[:120].replace("\n", " | "))
    ffgen.poll()      # pet stages (species recipe sheets land in ffgen.REVIEW)
    egggen.poll()     # egg candidates

def sheet(ims, tag, scale):
    W = max(i.width for i in ims); H = max(i.height for i in ims); cols = 8
    rows = (len(ims) + cols - 1) // cols
    out = Image.new("RGBA", (cols * (W * scale + 10) + 10, rows * (H * scale + 30) + 10), (30, 28, 34, 255)); dr = ImageDraw.Draw(out)
    for i, im in enumerate(ims):
        x = 10 + (i % cols) * (W * scale + 10); y = 10 + (i // cols) * (H * scale + 30)
        out.alpha_composite(im.resize((W * scale, H * scale), Image.NEAREST), (x, y + 20)); dr.text((x, y + 4), "%s #%d" % (tag, i), fill=(230, 220, 200))
    out.save(os.path.join(REVIEW, "SHEET_%s.png" % tag))

def idle_anim(png):
    J = jobs()
    txt, _ = ffgen.call_tool("animate_image", {"first_frame_base64": b64(png), "frame_count": 8,
        "action": "gentle idle loop: the seahorse mount sways and bobs slowly as if floating in surf, the knight's plume and cape ripple in a sea breeze, the raised sword holds steady; ends in the starting pose"})
    J["idle_anim"] = jid(txt); print("idle_anim", J["idle_anim"] or txt[:200]); savej(J)

if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "round1": round1()
    elif cmd == "poll": poll()
    elif cmd == "idle_anim": idle_anim(sys.argv[2])

# ---------------------------------------------------------------------------
# HIPPOCAMP ladder v2 (M 09-03 late): TWO visual lines chosen by the hatched archetype -
# guardian = teal/navy, warrior = navy/pink. Built ONE STAGE AT A TIME, each stage's
# base = M's pick of the previous stage (baby -> youngadult -> adult) so the ladder
# MUST match. Horse forelegs are mandatory (the wild reroll lost them); no tack.
#   python tools/gen_knight_0903.py pet <variant> <stage> [base_png]
# variant: g | w.  Rows land in ffgen's JOBS as species "hippocamp" / "hippocamp_w".
# ---------------------------------------------------------------------------
BODY = ("a HIPPOCAMP - a sea-horse of legend whose FRONT HALF IS A REAL HORSE: horse head, arched neck, deep "
        "horse chest and TWO STRONG HORSE FORELEGS WITH HOOVES raised in a rearing stance - joined at the hips to a "
        "long scaled SEAHORSE TAIL that curls under it, with a ridged fin down the back and fanned fins at the tail. "
        "A big flowing mane of kelp. NO bridle, NO reins, NO harness, NO saddle - a wild creature. {pal}")
PAL = {"g": "Palette: TEAL scaled body with a NAVY-blue mane, fins and tail markings, pale cream belly, one bright eye.",
       "w": "Palette: deep NAVY-blue scaled body with a PINK-coral mane, pink fin edges and tail markings, pale belly, one bright eye."}
VKEY = {"g": "hippocamp", "w": "hippocamp_w"}
def pet(variant, stage, base=None):
    ffgen.SPECIES[VKEY[variant]] = ("Hippocamp", BODY.format(pal=PAL[variant]))
    ffgen.STAGE_TXT["baby"] = ("a SINGLE newborn foal-hatchling of the same creature, ALONE with no adult in the picture, "
                               "small and round with a big head and big eyes but STILL with the two horse forelegs and the curled tail, "
                               "about 28 pixels tall")
    return ffgen.submit(VKEY[variant], stage, "s", base=base)

if __name__ == "__main__" and sys.argv[1] == "pet":
    pet(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else None)
