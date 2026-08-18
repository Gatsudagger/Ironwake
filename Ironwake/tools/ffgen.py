#!/usr/bin/env python
"""08-17 FF-style (tactics-density) species art driver - talks to the PixelLab MCP server over
plain HTTP (JSON-RPC, stateless) so batches can be scripted without pasting base64 through chat.
Recipe (M-locked 08-16/17): create_image_pro, 64x64 canvas, style ref = single-figure crop of
"REFERENCE SPRITE ART/pixel sprites best match.webp" (_refs/style_ff_single.png), 16 candidates
per call (~20 gens). Adult _s (3/4-front) first -> M picks -> that pick becomes the "character
base" for adult _e (right profile) + youngadult/baby s+e so the maturation ladder is ONE creature.
Usage:
  python tools/ffgen.py submit  <species> <stage> <dir> [--base PNG]   # queue a job
  python tools/ffgen.py poll                                            # download finished jobs + sheets
  python tools/ffgen.py sheet   <species>                               # rebuild sheet(s) for a species
Jobs are recorded in _for_review/species_ff_0817/JOBS.json.
"""
import os, sys, json, base64, time, urllib.request, io
ROOT   = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REVIEW = os.path.join(ROOT, "_for_review", "species_ff_0817")
JOBS   = os.path.join(REVIEW, "JOBS.json")
STYLE  = os.path.join(REVIEW, "_style_ff_creatures_ingame.png")   # 08-17 late: the game's own approved FF creatures = the anchor
os.makedirs(REVIEW, exist_ok=True)

def _cfg():
    d = json.load(open(os.path.expanduser("~/.claude.json"), encoding="utf-8"))
    p = d["mcpServers"]["pixellab"]
    return p["url"], p["headers"]["Authorization"]

def rpc(method, params, _id=1):
    url, auth = _cfg()
    H = {"Authorization": auth, "Content-Type": "application/json",
         "Accept": "application/json, text/event-stream"}
    req = urllib.request.Request(url, data=json.dumps({"jsonrpc": "2.0", "id": _id, "method": method,
                                 "params": params}).encode(), headers=H, method="POST")
    r = urllib.request.urlopen(req, timeout=120)
    body = r.read().decode()
    if "data:" in body:
        body = [l[5:].strip() for l in body.splitlines() if l.startswith("data:")][-1]
    j = json.loads(body)
    if "error" in j:
        raise RuntimeError(j["error"])
    return j["result"]

def call_tool(name, args):
    res = rpc("tools/call", {"name": name, "arguments": args}, 7)
    txt = "\n".join(c.get("text", "") for c in res.get("content", []) if c.get("type") == "text")
    return txt, res

def b64file(p):
    return base64.b64encode(open(p, "rb").read()).decode()

def load_jobs():
    return json.load(open(JOBS)) if os.path.exists(JOBS) else []

def save_jobs(j):
    json.dump(j, open(JOBS, "w"), indent=1)

# ---- species visuals (fantasy identity from the codex lore; creatures, never humanoid) ----
SPECIES = {
 "cairn_bear":    ("Cairn Bear",    "a hulking bear whose whole back and shoulders are armoured in dark grey cairn stones grown into pale bone-cream fur, cream muzzle and face, dark legs, small fierce eyes"),
 "ember_ram":     ("Ember Ram",     "a shaggy soot-black ram whose curled hollow horns glow orange like banked coals, embers drifting from the horn tips"),
 "salt_hare":     ("Salt Hare",     "a lean long-legged hare with jagged WHITE SALT CRYSTALS growing along its spine and ear tips like a crystal ridge, cracked pale-grey hide, wide black eyes, faintly glowing white salt dust around its feet"),
 "mire_heron":    ("Mire Heron",    "a tall gaunt grey-green heron standing in mud, silt and moss settled on its back, long dagger beak, one dull yellow eye"),
 "gravel_tick":   ("Gravel Tick",   "a fat round tick whose back is a rough grey boulder shell carved with faint glowing rune cracks, six stubby chitin legs, small mandibles, one baleful red eye"),
 "glass_eel":     ("Glass Eel",     "a coiled transparent eel showing only a thread of bright silver spine and faint fins, glassy pale outline"),
 "chapel_bat":    ("Chapel Bat",    "a bat hanging in mid-air with wide wings spread, wing membranes patterned like glowing STAINED-GLASS windows in deep red blue and gold with dark leading, dark furred body, small glowing eyes"),
 "barrow_mole":   ("Barrow Mole",   "a grave-digging mole crouched ON ALL FOURS, its fur black as a burial shroud with pale bone plates along the spine, ENORMOUS yellowed bone claws like grave-shovels, a faint sickly green glow in its blind eyes, a small skull-shaped marking on its brow"),
 "tallow_moth":   ("Tallow Moth",   "a moth whose whole BODY IS A MELTING CREAM TALLOW CANDLE - the thorax and abdomen are a soft slumping candle with wax drips running down and pooling, a single small flame burning where the head would be, dusty pale-cream moth wings growing from the candle body, six thin legs, drooping antennae; simple chunky pixel sprite"),
 "gravemask":     ("Gravemask",     "a raccoon-like scavenger ON ALL FOURS like a real raccoon, bone-white skull mask face, grey striped fur, ringed tail, a small gold ring held in its mouth"),
 "bristleback":   ("Bristleback",   "a small scarred boar-like beast with WILD BRISTLING WHISKERS fanning from its snout and jagged spiky fur standing up in iron-grey ridges along its back, notched ears, small tusks, stubborn planted stance, glowing ember-orange eyes"),
 "crypt_gryphon": ("Crypt Gryphon", "a stone-grey gryphon with dulled eagle plumage and a lion body, perched rigid like a statue, folded wings, hollow eyes"),
 "threehunger":   ("Threehunger",   "a small chimera with THREE LION HEADS on one tawny lion body, each head different: one with a great dark mane, one with a short ragged mane and notched ears, one gaunt and grey-muzzled with a pale face - all three snarling at each other, dark tufted tail"),
 "wing_hare":     ("Wing Hare",     "a brown hare with a small rack of true bone antlers between its ears, calm posture, feathered hind legs"),
 "drowned_lamp":  ("Drowned Lamp",  "a ghostly deep-water fish, half-skeletal with translucent pale flesh showing dark bones and ribs, needle teeth, hollow glowing eye sockets, a caged amber LANTERN organ hanging from a bone stalk on its brow, tattered fins veined with faint light"),
 "honeymaw":      ("Honeymaw",      "a stout hulking badger-bear beast with TWO SUBTLE ROUNDED BEEHIVE LUMPS on its shoulders like pauldrons, each slightly dripping golden honey with a few small bees on them, dark fur with a pale back stripe, glowing amber eyes, a broad honey-wet jaw"),
 "bark_hound":    ("Bark Hound",    "a hound whose body is living BARK AND WOOD - shoulders and back armoured in cracked bark plates with moss and small pale fungi growing on them, twig-like ears, glowing amber sap veins in the cracks, knot-hole eyes that glow softly green, gentle stance"),
 "canopy_shrew":  ("Canopy Shrew",  "a tiny furious tree shrew whose fur is LEAF CAMOUFLAGE - green and brown leaf-shaped tufts growing over its back like foliage, a curling vine tail, small twig-like claws, bright angry eyes, crouched on all fours"),
 "pressure_snail":("Pressure Snail","a snail with an impossibly thick dense armoured shell of iridescent NACRE - swirling purple, teal and gold sheen with faint glowing arcane runes etched in the ridges, small crystals growing from the shell spiral, pale luminous slug body, eye stalks tipped with tiny glowing orbs"),
 "flicker_finch": ("Flicker Finch", "a small finch whose wing and tail edges dissolve into scattered pixels and faint afterimages, dusky purple-grey plumage"),
 "rust_vole":     ("Rust Vole",     "a plump vole with rust-orange fur flecked with glinting iron filings, oversized iron-grey chisel teeth, small rusted metal plates growing along its spine like scales, bright coppery eyes"),
 "paleswimmer":   ("Paleswimmer",   "an eyeless bone-white deep-cave fish with smooth featureless head, translucent fins, drifting motionless"),
 "doorling":      ("Doorling",      "a grey cat whose BACK IS A STONE ARCHWAY - a small arched stone door frame sits ON TOP of the cat like a tortoise shell, its base fused into the fur of the shoulders and hips, a tiny wooden door hanging open inside the arch on its back, calm half-closed eyes; the archway is mounted on the cat, nothing stands beside the cat"),
 "tallykeep":     ("Tallykeep",     "a hunched grey scaled lizard-beast whose hide is covered in scratched tally marks, long claws, watchful eyes"),
 "sum_moth":      ("Sum Moth",      "a large dark moth whose wing patterns form faint glowing numerals, dusty violet wings, feathered antennae"),
 "mimicling":     ("Mimicling",     "a small featureless grey blob-creature mid-shapeshift, its body half-formed into a blurry copy of a hound, faint eyes"),
 "chorister_fry": ("Chorister Fry", "a small deep-sea fish with a rounded open mouth as if singing, blue-black scales, faint bioluminescent throat glow"),
 "leviathan_calf":("Leviathan Calf","a small whale-like sea beast already scarred and barnacled, heavy grey hide, tiny for its bulk, deep-set eye"),
}
STAGE_TXT = {
 "adult":      "adult, full grown, about 44 pixels tall, ONE creature only",
 "youngadult": "adolescent of the same creature, leaner and slightly smaller, about 38 pixels tall, keeping the exact same colours and markings as the reference",
 "baby":       "a SINGLE newborn cub or hatchling of the same creature, ALONE with no adult in the picture, small and round with big eyes, about 28 pixels tall, keeping the exact same colours and markings as the reference",
}
DIR_TXT = {"s": "3/4 front view facing the viewer", "e": "side profile facing RIGHT"}

def prompt(species, stage, d):
    name, vis = SPECIES[species]
    # 08-17 M feedback on batch 1: "not adhering to the FF reference" + "no terrain or
    # objects" -> SNES-era phrasing, bold outline, saturated limited palette, dither
    # shading, and an explicit NOTHING-BUT-THE-CREATURE clause.
    # 08-17 late (M: "we have completely lost the visual style"): the style anchor is now the
    # game's OWN approved FF-style creature sprites (_style_ff_creatures_ingame.png = magma slug /
    # cinder imp / glacial lurker / vault crawler) and the prompt says so explicitly.
    return ("Pixel art creature sprite in EXACTLY the same style as the four reference creatures (same game): "
            "bold black outline, flat limited colours, chunky pixels, simple readable shapes. Subject: a %s - %s. %s, %s. "
            "ONLY the creature on a fully transparent background - no ground, no shadow, no terrain, no props, no objects, "
            "no text. Dark gothic fantasy, natural animal posture - never standing upright on two legs, never humanoid."
            % (name, vis, STAGE_TXT[stage], DIR_TXT[d]))

def submit(species, stage, d, base=None):
    # FFGEN_STYLE (path) / FFGEN_STYLE_COPY (comma list) let a batch swap the style ref
    # without editing the recipe (08-17 style-adherence tests for M).
    style_path = os.environ.get("FFGEN_STYLE", STYLE)
    args = {"description": prompt(species, stage, d), "width": 64, "height": 64,
            "no_background": True, "style_image_base64": b64file(style_path)}
    if os.environ.get("FFGEN_STYLE_COPY"):
        args["style_copy"] = os.environ["FFGEN_STYLE_COPY"].split(",")
    if base:
        args["reference_images"] = json.dumps([{"base64": b64file(base), "usage": "character base - the exact same creature and colours"}])
    txt, res = call_tool("create_image_pro", args)
    jid = None
    for tok in txt.replace('"', ' ').replace(',', ' ').split():
        if len(tok) == 36 and tok.count('-') == 4:
            jid = tok; break
    jobs = load_jobs()
    if jid is None:
        # PixelLab caps concurrent jobs at 20 - the submit is rejected (no gens spent).
        # Keep a FAILED row so `resubmit` can retry once slots free up.
        jobs.append({"species": species, "stage": stage, "dir": d, "job": None, "base": base, "done": False, "failed": True, "raw": txt[:300]})
        save_jobs(jobs)
        print("FAILED", species, stage, d, txt[:80].replace(chr(10), " "))
        return None
    jobs.append({"species": species, "stage": stage, "dir": d, "job": jid, "base": base, "done": False, "raw": txt[:300]})
    save_jobs(jobs)
    print("queued", species, stage, d, jid)
    return jid

def resubmit():
    """Retry every FAILED row (rate-limited submits), honoring the 20-job cap."""
    jobs = load_jobs()
    failed = [j for j in jobs if j.get("job") is None]
    if not failed:
        print("nothing to resubmit"); return
    inflight = sum(1 for j in jobs if j.get("job") and not j["done"])
    keep = [j for j in jobs if j.get("job") is not None]
    save_jobs(keep)
    for j in failed:
        if inflight >= 19:
            # keep the remainder as failed rows for the next call
            keep = load_jobs(); keep.append(j); save_jobs(keep); print("deferred", j["species"], j["stage"], j["dir"]); continue
        if submit(j["species"], j["stage"], j["dir"], j.get("base")): inflight += 1

def poll():
    jobs = load_jobs()
    changed = False
    for j in jobs:
        if j["done"] or not j["job"]:
            continue
        txt, res = call_tool("get_image", {"job_id": j["job"]})
        if "status: failed" in txt.lower():
            j["done"] = True; j["count"] = 0; j["failed"] = True; changed = True
            print("FAILED", j["species"], j["stage"], j["dir"], txt[:120].replace(chr(10), " "))
            _mark_done(j)
            continue
        if "completed" not in txt.lower() and "download" not in txt.lower():
            print("pending", j["species"], j["stage"], j["dir"], txt[:80].replace("\n", " "))
            continue
        # download indexes until 404
        outdir = os.path.join(REVIEW, j["species"])
        os.makedirs(outdir, exist_ok=True)
        # round number = how many earlier jobs share this species/stage/dir (rerolls never overwrite)
        rnd = sum(1 for k in jobs if k is not j and k["species"] == j["species"] and k["stage"] == j["stage"]
                  and k["dir"] == j["dir"] and jobs.index(k) < jobs.index(j))
        j["round"] = rnd
        n = 0
        for i in range(64):
            url = "https://api.pixellab.ai/mcp/images/%s/download?index=%d" % (j["job"], i)
            try:
                data = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "ironwake"}), timeout=60).read()
            except Exception:
                break
            open(os.path.join(outdir, "%s_%s_r%d_%d.png" % (j["stage"], j["dir"], rnd, i)), "wb").write(data)
            n += 1
        j["done"] = True; j["count"] = n; changed = True
        print("downloaded", j["species"], j["stage"], j["dir"], n)
        _mark_done(j)
        sheet(j["species"])

def _mark_done(j):
    """Re-load + patch + save so a concurrent submit can't be clobbered (08-17 lost 23 rows
    to a poll that saved its stale in-memory list over freshly queued jobs)."""
    cur = load_jobs()
    for k in cur:
        if k.get("job") == j["job"]:
            k.update({"done": j["done"], "count": j.get("count", 0), "round": j.get("round", 0), "failed": j.get("failed", False)})
            break
    save_jobs(cur)

def sheet(species):
    from PIL import Image, ImageDraw
    outdir = os.path.join(REVIEW, species)
    files = sorted(f for f in os.listdir(outdir) if f.endswith(".png") and not f.startswith("SHEET"))
    groups = {}
    # CURATED.json (optional): {species: {"<stage>_<dir>_r<n>": [idx,...]}} - M asked for
    # fewer candidates per stage (08-17), so the sheet shows only my shortlist when one exists.
    cur_path = os.path.join(REVIEW, "CURATED.json")
    cur = json.load(open(cur_path)).get(species, {}) if os.path.exists(cur_path) else {}
    for f in files:
        stage, d, rnd, idx = f[:-4].rsplit("_", 3)
        key = "%s_%s_%s" % (stage, d, rnd)
        if key in cur and int(idx) not in cur[key]:
            continue
        groups.setdefault((stage, d + rnd[1:]), []).append((int(idx), f))
    order = ["adult_s", "adult_e", "youngadult_s", "youngadult_e", "baby_s", "baby_e"]
    keys = sorted(groups, key=lambda k: (order.index(k[0] + "_" + k[1][0]) if (k[0] + "_" + k[1][0]) in order else 99, k[1]))
    SC = 3; CELL = 64 * SC + 8; COLS = 8
    rows = sum((len(groups[k]) + COLS - 1) // COLS for k in keys)
    W = COLS * CELL + 8; H = rows * (CELL + 22) + 30
    im = Image.new("RGBA", (W, H), (30, 30, 34, 255)); dr = ImageDraw.Draw(im)
    dr.text((8, 6), "%s - FF-style 64px pro candidates (3x view). Pick by INDEX." % species, fill=(230, 230, 230))
    y = 30
    for k in keys:
        items = sorted(groups[k])
        for r in range((len(items) + COLS - 1) // COLS):
            dr.text((8, y), "%s_%s  round %s  idx %d-%d" % (k[0], k[1][0], k[1][1:], items[r * COLS][0], items[min(len(items), (r + 1) * COLS) - 1][0]), fill=(255, 210, 120))
            for c, (idx, f) in enumerate(items[r * COLS:(r + 1) * COLS]):
                x = 8 + c * CELL
                cand = Image.open(os.path.join(outdir, f)).convert("RGBA")
                bg = Image.new("RGBA", (64 * SC, 64 * SC), (60, 60, 68, 255))
                bg.alpha_composite(cand.resize((64 * SC, 64 * SC), Image.NEAREST))
                im.paste(bg, (x, y + 18)); dr.text((x + 2, y + 18 + 64 * SC - 12), str(idx), fill=(255, 255, 255))
            y += CELL + 22
    im.save(os.path.join(REVIEW, "SHEET_%s.png" % species))
    print("sheet", species)



# ---------------------------------------------------------------------------
# IDLE ANIMATION (08-17 late, M: "anything going into the game needs an idle animation"):
# animate_image on the picked still, last frame PINNED to the first so the loop is
# seamless (feedback_seamless_anim_loops). 64x64 x 8 frames = 1 gen. Frames land as
# <species>/<stage>_<dir>_ANIM_<i>.png (i=0 is the still) + a GIF preview.
# ---------------------------------------------------------------------------
ANIMS = os.path.join(REVIEW, "ANIMS.json")
IDLE_ACTION = ("gentle idle loop in place: slow breathing, subtle weight shift, small head or tail sway, "
               "feet planted, same size and colours every frame; ends exactly on the starting pose")

def anim_submit(species, stage, d, still_path, action=IDLE_ACTION, frames=8):
    b = b64file(still_path)
    txt, res = call_tool("animate_image", {"first_frame_base64": b, "last_frame_base64": b, "action": action, "frame_count": frames})
    jid = None
    for tok in txt.replace('"', ' ').replace(',', ' ').split():
        if len(tok) == 36 and tok.count('-') == 4: jid = tok; break
    rows = json.load(open(ANIMS)) if os.path.exists(ANIMS) else []
    rows.append({"species": species, "stage": stage, "dir": d, "still": still_path, "job": jid, "done": False, "raw": txt[:200]})
    json.dump(rows, open(ANIMS, "w"), indent=1)
    print("anim queued" if jid else "anim FAILED", species, stage, d, jid or txt[:120].replace(chr(10), " "))
    return jid

def anim_poll():
    from PIL import Image
    rows = json.load(open(ANIMS)) if os.path.exists(ANIMS) else []
    for r in rows:
        if r["done"] or not r["job"]: continue
        txt, res = call_tool("get_image", {"job_id": r["job"]})
        if "status: failed" in txt.lower():
            r["done"] = True; r["failed"] = True; print("anim FAILED", r["species"], r["stage"], r["dir"]); continue
        if "completed" not in txt.lower(): print("anim pending", r["species"], r["stage"], r["dir"]); continue
        outdir = os.path.join(REVIEW, r["species"]); os.makedirs(outdir, exist_ok=True)
        frames = []
        for i in range(32):
            url = "https://api.pixellab.ai/mcp/images/%s/download?index=%d" % (r["job"], i)
            try: data = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "ironwake"}), timeout=60).read()
            except Exception: break
            fp = os.path.join(outdir, "%s_%s_ANIM_%d.png" % (r["stage"], r["dir"], i)); open(fp, "wb").write(data); frames.append(fp)
        r["done"] = True; r["count"] = len(frames)
        if frames:
            ims = [Image.open(f).convert("RGBA").resize((192, 192), Image.NEAREST) for f in frames]
            bg = [Image.new("RGBA", (192, 192), (60, 60, 68, 255)) for _ in ims]
            for b_, im in zip(bg, ims): b_.alpha_composite(im)
            bg[0].save(os.path.join(REVIEW, "ANIM_%s_%s_%s.gif" % (r["species"], r["stage"], r["dir"])), save_all=True, append_images=bg[1:], duration=120, loop=0, disposal=2)
        print("anim downloaded", r["species"], r["stage"], r["dir"], len(frames))
    json.dump(rows, open(ANIMS, "w"), indent=1)

if __name__ == "__main__":
    a = sys.argv[1:]
    if a[0] == "submit":
        base = a[a.index("--base") + 1] if "--base" in a else None
        submit(a[1], a[2], a[3], base)
    elif a[0] == "poll":
        poll()
    elif a[0] == "resubmit":
        resubmit()
    elif a[0] == "anim":
        anim_submit(a[1], a[2], a[3], a[4])
    elif a[0] == "animpoll":
        anim_poll()
    elif a[0] == "sheet":
        sheet(a[1])
    elif a[0] == "prompt":
        print(prompt(a[1], a[2], a[3]))
