#!/usr/bin/env python
"""08-27 missing-creature-art campaign driver (26 species). Cost-locked recipe (M directive:
single-output tools only, no candidate packs):
  Phase A  cand    : 2 adult-south identity candidates/species (1x pixen + 1x pixflux, 1 gen each)
  Phase B  (M picks winner per species from SHEET_CANDIDATES)
  Phase C  stages  : youngadult + baby souths derived from the pick (pixflux img2img A/B'd
                     against palette-locked fresh gen in the ember_ram test; winner batches)
  Phase D  chars   : create_character v3 reference per stage (~2 gens = all 8 rotations)
  Phase E  anims   : animate_character v3 south+east (~1 gen/dir; winged/spread species use
                     the SOUTH-EAST rotation as combat east - see project_east_fix_0827)
  Phase F  import  : gm_import.build_anim_sprite spr_pet_<sp>_<stage>_<s|e>
Reuses ffgen.py plumbing (rpc/call_tool/SPECIES/prompt) - same JSON-RPC REST route so base64
never rides through chat. State in _for_review/missing_art_0827/*.json. Safe to re-run phases.
"""
import os, sys, json, base64, time, urllib.request, io
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ffgen

ROOT   = ffgen.ROOT
REVIEW = os.path.join(ROOT, "_for_review", "missing_art_0827")
os.makedirs(REVIEW, exist_ok=True)
CANDS  = os.path.join(REVIEW, "CANDS.json")    # candidate jobs
PICKS  = os.path.join(REVIEW, "PICKS.json")    # {species: filename of picked adult south}
STAGEJ = os.path.join(REVIEW, "STAGES.json")   # stage-still jobs
CHARS  = os.path.join(REVIEW, "CHARS.json")    # character rows
ANIMS  = os.path.join(REVIEW, "ANIMS.json")    # anim rows

# All 26 missing species (base 20 + signature 6); identity lines live in ffgen.SPECIES
BASE20 = ["ember_ram","salt_hare","mire_heron","gravel_tick","glass_eel","chapel_bat",
          "barrow_mole","tallow_moth","gravemask","bristleback","crypt_gryphon","threehunger",
          "wing_hare","drowned_lamp","honeymaw","bark_hound","pressure_snail","flicker_finch",
          "rust_vole","paleswimmer"]
SIG6   = ["doorling","tallykeep","sum_moth","mimicling","chorister_fry","leviathan_calf"]
SPECIES = BASE20 + SIG6
STAGES  = ["adult", "youngadult", "baby"]

# Winged/spread/frontal-symmetric species whose true east renders edge-on: ship the
# character's SOUTH-EAST rotation as combat east (locked rule from the east-fix campaign).
USE_SE = {"chapel_bat","tallow_moth","sum_moth","flicker_finch","mire_heron",
          "crypt_gryphon","wing_hare","doorling"}

IDLE = ("gentle idle loop in place: slow breathing, subtle weight shift, small head or tail "
        "sway, feet planted, same size and colours every frame; ends exactly on the starting pose")

# M 08-27: "NONE with floors" - every still ships with NOTHING under the creature.
NOGROUND = (" The creature floats on the fully transparent background - ABSOLUTELY NO ground, "
            "no floor, no mound, no grass, no base, no shadow, nothing under or behind it.")

# M's 08-17 design redirects (project_notes_batch_0817) - these species' ffgen.SPECIES
# lines predate the rejects and MUST NOT be used as-is.
REDIRECT = {
 "doorling":       "a grey mystical cat that IS a living dimensional VOID GATE: its chest and belly open into a swirling violet-black portal edged with glowing arcane runes, star-flecked darkness inside, wisps of void mist curling off its fur, calm half-closed eyes - a dimensional nomad cat, NOT a door or archway object",
 "sum_moth":       "a large dark moth with intricate glowing arcane geometric patterns across its dusty violet wings, feathered antennae, faint magical shimmer - abstract patterns only, NO letters, NO numbers, NO numerals",
 "chorister_fry":  "a SCHOOL of many small multicoloured magical fish swimming in tight formation so together they form the SHAPE of one large fish, bioluminescent glints, deep-sea gloom palette",
 "leviathan_calf": "a small cosmic SPACE WHALE calf floating in the air, heavy grey-blue hide flecked with tiny glowing stars like a night sky, barnacles and old scars, small fins, deep-set gentle eye, faint stardust trailing off it",
 "threehunger":    "a fierce lion whose body and mane are streaked with THREE elemental colours woven together - burning FIRE orange-red, glacial ICE blue-white, crackling LIGHTNING violet-gold - one single lion head, the tri-coloured mane flowing like three merging energies, glowing tri-coloured eyes, dark gothic menace (M 08-27 redesign: cerberus angle abandoned)",
 "crypt_gryphon":  "a NECROMANTIC grave gryphon: an undead gryphon with dull grey-black feathers rotting to expose pale bone, skeletal wing tips, hollow glowing sockets, a lion body wrapped in tattered burial shrouds, grave-cold green light seeping between its ribs",
 "tallow_moth":    "a candle-moth: one coherent creature whose thorax and abdomen form a single melting cream tallow candle with wax drips, a small steady flame where the head would be, dusty pale-cream moth wings, six thin legs - clean readable silhouette",
}

def _load(p): return json.load(open(p)) if os.path.exists(p) else []
def _save(p, v): json.dump(v, open(p, "w"), indent=1)

def _jid(txt):
    for tok in txt.replace('"', ' ').replace(',', ' ').split():
        if len(tok) == 36 and tok.count('-') == 4: return tok
    return None

def _dl(job, outpath, index=0):
    url = "https://api.pixellab.ai/mcp/images/%s/download?index=%d" % (job, index)
    data = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "ironwake"}), timeout=60).read()
    open(outpath, "wb").write(data)

# ---------- Phase A: identity candidates (2/species, 1 gen each) ----------
def cand(species_list=None):
    rows = _load(CANDS)
    done = {(r["species"], r["variant"]) for r in rows if r.get("job")}
    for sp in (species_list or SPECIES):
        desc = ffgen.prompt(sp, "adult", "s")
        for variant, tool, extra in [
            ("pixen",   "create_image_pixen",   {"outline": "single color black outline", "detail": "medium detail"}),
            ("pixflux", "create_image_pixflux", {"outline": "single color black outline", "text_guidance_scale": 9}),
        ]:
            if (sp, variant) in done: continue
            args = {"description": desc, "width": 64, "height": 64, "no_background": True,
                    "direction": "south", "view": "low top-down"}
            args.update(extra)
            txt, _ = ffgen.call_tool(tool, args)
            jid = _jid(txt)
            rows.append({"species": sp, "variant": variant, "job": jid, "done": False, "raw": txt[:200]})
            _save(CANDS, rows)
            print(("queued" if jid else "FAILED"), sp, variant, jid or txt[:90].replace(chr(10), " "), flush=True)

def candpoll():
    rows = _load(CANDS); pending = 0
    for r in rows:
        if r["done"] or not r["job"]: continue
        txt, _ = ffgen.call_tool("get_image", {"job_id": r["job"]})
        low = txt.lower()
        if "status: failed" in low:
            r["done"] = True; r["failed"] = True; print("FAILED", r["species"], r["variant"], flush=True); continue
        if "completed" not in low and "download" not in low:
            pending += 1; continue
        outdir = os.path.join(REVIEW, r["species"]); os.makedirs(outdir, exist_ok=True)
        rnd = sum(1 for k in rows if k is not r and k["species"] == r["species"]
                  and k["variant"] == r["variant"] and rows.index(k) < rows.index(r))
        fp = os.path.join(outdir, "adult_s_%s_r%d.png" % (r["variant"], rnd))
        _dl(r["job"], fp)
        r["done"] = True; r["file"] = fp
        print("got", r["species"], r["variant"], "r%d" % rnd, flush=True)
    _save(CANDS, rows)
    print("pending", pending, flush=True)
    return pending

def sheet_cands(name="SHEET_CANDIDATES"):
    from PIL import Image, ImageDraw
    rows = [r for r in _load(CANDS) if r.get("file") and os.path.exists(r["file"])]
    by_sp = {}
    for r in rows: by_sp.setdefault(r["species"], []).append(r)
    sps = [s for s in SPECIES if s in by_sp]
    SC = 3; CELL = 64 * SC + 10; COLS = max(len(v) for v in by_sp.values()) if by_sp else 2
    W = 260 + COLS * CELL; H = 34 + len(sps) * (CELL + 6)
    im = Image.new("RGBA", (W, H), (30, 30, 34, 255)); dr = ImageDraw.Draw(im)
    dr.text((8, 8), "Missing-art campaign: adult SOUTH identity candidates. Pick per species by label.", fill=(230, 230, 230))
    y = 34
    for sp in sps:
        dr.text((8, y + 80), sp, fill=(255, 210, 120))
        for c, r in enumerate(sorted(by_sp[sp], key=lambda k: k["variant"])):
            x = 260 + c * CELL
            cand_im = Image.open(r["file"]).convert("RGBA")
            bg = Image.new("RGBA", (64 * SC, 64 * SC), (60, 60, 68, 255))
            bg.alpha_composite(cand_im.resize((64 * SC, 64 * SC), Image.NEAREST))
            im.paste(bg, (x, y))
            lab = os.path.basename(r["file"])[8:-4]  # e.g. pixen_r0
            dr.text((x + 2, y + 64 * SC - 12), lab, fill=(255, 255, 255))
        y += CELL + 6
    fp = os.path.join(REVIEW, name + ".png"); im.save(fp)
    print("sheet", fp, flush=True)

# ---------- Phase C: stage stills from the picked adult ----------
STAGE_PROMPT = {
 "youngadult": "the same creature as the reference but an ADOLESCENT: leaner, slightly smaller (about 38 of the 64 pixels tall), same colours and markings, same 3/4 front view facing the viewer",
 "baby":       "the same creature as the reference but a SINGLE NEWBORN cub or hatchling: TINY and chubby, round body, stubby short legs, oversized head with big eyes, only small nubs where the adult's features (horns, spines, crest) would grow - about 28 of the 64 pixels tall with empty space around it, same colours and markings, same 3/4 front view facing the viewer",
}

def stages(species_list=None, mode="img2img"):
    """mode: img2img (init=pick, strength 120) | fresh (color_image palette lock). Test A/B on
    ember_ram decided the batch mode. PICKS.json: {species: {stage: filename}} - only stages
    NOT already picked are generated, based on the nearest younger-adjacent picked still."""
    picks = json.load(open(PICKS)) if os.path.exists(PICKS) else {}
    rows = _load(STAGEJ)
    done = {(r["species"], r["stage"], r["mode"]) for r in rows if r.get("job")}
    for sp in (species_list or SPECIES):
        if sp not in picks: continue
        sp_picks = picks[sp]
        for st in ["youngadult", "baby"]:
            if st in sp_picks: continue
            base_name = sp_picks.get("youngadult", sp_picks.get("adult"))
            base = base_name if os.path.isabs(base_name) else os.path.join(REVIEW, sp, base_name)
            if (sp, st, mode) in done: continue
            name, vis = ffgen.SPECIES[sp]
            vis = REDIRECT.get(sp, vis)   # M's 08-17 design redirects supersede the old lines
            desc = "Pixel art creature sprite, bold black outline, flat limited colours, chunky pixels. %s (%s - %s). ONLY the creature on a fully transparent background - no props, no text. Dark gothic fantasy, natural animal posture - never humanoid.%s" % (STAGE_PROMPT[st], name, vis, NOGROUND)
            args = {"description": desc, "width": 64, "height": 64, "no_background": True,
                    "direction": "south", "view": "low top-down", "outline": "single color black outline"}
            if mode == "img2img":
                args["init_image_base64"] = ffgen.b64file(base)
                args["init_image_strength"] = 120
            else:
                args["color_image_base64"] = ffgen.b64file(base)
            txt, _ = ffgen.call_tool("create_image_pixflux", args)
            jid = _jid(txt)
            rows.append({"species": sp, "stage": st, "mode": mode, "job": jid, "done": False, "raw": txt[:200]})
            _save(STAGEJ, rows)
            print(("queued" if jid else "FAILED"), sp, st, mode, jid or txt[:90].replace(chr(10), " "), flush=True)

def stagepoll():
    rows = _load(STAGEJ); pending = 0
    for r in rows:
        if r["done"] or not r["job"]: continue
        txt, _ = ffgen.call_tool("get_image", {"job_id": r["job"]})
        low = txt.lower()
        if "status: failed" in low:
            r["done"] = True; r["failed"] = True; print("FAILED", r["species"], r["stage"], r["mode"], flush=True); continue
        if "completed" not in low and "download" not in low:
            pending += 1; continue
        outdir = os.path.join(REVIEW, r["species"]); os.makedirs(outdir, exist_ok=True)
        rnd = sum(1 for k in rows if k is not r and k["species"] == r["species"] and k["stage"] == r["stage"]
                  and k["mode"] == r["mode"] and rows.index(k) < rows.index(r))
        fp = os.path.join(outdir, "%s_s_%s_r%d.png" % (r["stage"], r["mode"], rnd))
        _dl(r["job"], fp)
        r["done"] = True; r["file"] = fp
        print("got", r["species"], r["stage"], r["mode"], "r%d" % rnd, flush=True)
    _save(STAGEJ, rows)
    print("pending", pending, flush=True)
    return pending

# ---------- Phase D: characters (v3 reference rotation, ~2 gens = all 8 dirs) ----------
CHAR_DL = "https://api.pixellab.ai/mcp/characters/{id}/download"

def _fetch(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "ironwake"}), timeout=120).read()

def _pick_path(sp, st):
    picks = json.load(open(PICKS)) if os.path.exists(PICKS) else {}
    fn = picks.get(sp, {}).get(st)
    if not fn: return None
    return fn if os.path.isabs(fn) else os.path.join(REVIEW, sp, fn)

def chars(only=None):
    rows = _load(CHARS)
    have = {(r["species"], r["stage"]) for r in rows if r.get("char")}
    for sp in (only or SPECIES):
        for st in STAGES:
            if (sp, st) in have: continue
            base = _pick_path(sp, st)
            if not base or not os.path.exists(base):
                print("NO PICK", sp, st); continue
            desc = REDIRECT.get(sp, ffgen.SPECIES[sp][1]) + ", pixel art game sprite"
            txt, _ = ffgen.call_tool("create_character", {
                "description": desc, "mode": "v3",
                "reference_image_base64": ffgen.b64file(base),
                "name": "missart %s %s" % (sp, st)})
            cid = None
            for line in txt.splitlines():
                if line.startswith("id:"):
                    cid = line.split(":", 1)[1].strip(); break
            rows.append({"species": sp, "stage": st, "char": cid, "rot_done": False, "raw": txt[:150]})
            _save(CHARS, rows)
            print(("queued" if cid else "FAILED"), sp, st, cid or txt[:100].replace(chr(10), " "), flush=True)

def chpoll():
    rows = _load(CHARS)
    for r in rows:
        if r["rot_done"] or not r["char"]: continue
        sp, st = r["species"], r["stage"]
        txt, _ = ffgen.call_tool("get_character", {"character_id": r["char"], "include_preview": False})
        if "status: completed" not in txt and "rotations:" not in txt:
            print("pending", sp, st, flush=True); continue
        # parse ONLY the rotations: block (animation lines also print "<dir>: https")
        want = ("south", "east", "south-east")
        urls = {}; in_rot = False
        for line in txt.splitlines():
            s = line.strip()
            if s.startswith("rotations:"): in_rot = True; continue
            if in_rot and (s == "" or s.endswith(":") or ":" not in s): break
            if in_rot:
                for d in want:
                    if s.startswith(d + ": https"):
                        urls[d] = s.split(": ", 1)[1].split(",")[0].strip()
        if "east" not in urls:
            print("no east yet", sp, st, flush=True); continue
        outdir = os.path.join(REVIEW, sp); os.makedirs(outdir, exist_ok=True)
        for d, u in urls.items():
            open(os.path.join(outdir, "%s_rot_%s.png" % (st, d)), "wb").write(_fetch(u))
        r["rot_done"] = True
        print("rotations", sp, st, flush=True)
    _save(CHARS, rows)
    print("%d/%d rotated" % (sum(1 for r in rows if r.get("rot_done")), len(rows)), flush=True)

def sheet_rot(only=None):
    """Per-species approval sheet: picked still + char south + combat-east rotation per stage."""
    from PIL import Image, ImageDraw
    for sp in (only or SPECIES):
        combat = "south-east" if sp in USE_SE else "east"
        rows = []
        for st in STAGES:
            e = os.path.join(REVIEW, sp, "%s_rot_%s.png" % (st, combat))
            s = os.path.join(REVIEW, sp, "%s_rot_south.png" % st)
            b = _pick_path(sp, st)
            if os.path.exists(e) and b:
                rows.append((st, [("picked still", b), ("char south", s), ("combat " + combat, e)]))
        if not rows: continue
        S = 3; CELL = 64 * S
        im = Image.new("RGBA", (3 * (CELL + 12) + 20, len(rows) * (CELL + 40) + 40), (30, 30, 36, 255))
        dr = ImageDraw.Draw(im)
        dr.text((10, 8), sp + " - rotations (approve per stage)", fill=(255, 220, 140))
        for i, (st, cells) in enumerate(rows):
            y = 34 + i * (CELL + 40)
            for j, (lbl, p) in enumerate(cells):
                if not os.path.exists(p): continue
                x = 10 + j * (CELL + 12)
                c = Image.open(p).convert("RGBA")
                sc = min(CELL / c.width, CELL / c.height)
                c = c.resize((max(1, round(c.width * sc)), max(1, round(c.height * sc))), Image.NEAREST)
                bg = Image.new("RGBA", (CELL, CELL), (58, 58, 66, 255))
                bg.alpha_composite(c, ((CELL - c.width) // 2, CELL - c.height))
                im.paste(bg, (x, y))
                dr.text((x, y + CELL + 4), "%s %s" % (st, lbl), fill=(220, 220, 230))
        im.save(os.path.join(REVIEW, "SHEET_ROT_%s.png" % sp))
        print("sheet", sp, flush=True)

# ---------- Phase E: idle anims, south + combat-east (~1 gen/dir) ----------
def anims(only=None):
    """Per-(stage,dir) success flags so the 10-concurrent-job cap can be pumped."""
    rows = _load(CHARS)
    pending = 0
    for r in rows:
        if not r.get("rot_done"): continue
        sp, st = r["species"], r["stage"]
        if only and sp not in only: continue
        combat = "south-east" if sp in USE_SE else "east"
        for d in ("south", combat):
            key = "anim_ok_" + d
            if r.get(key): continue
            txt, _ = ffgen.call_tool("animate_character", {
                "character_id": r["char"], "mode": "v3", "directions": [d],
                "action_description": IDLE, "frame_count": 8,
                "animation_name": "missart_idle_" + d})
            if txt.lstrip().lower().startswith("error"):
                pending += 1
                print("DEFERRED", sp, st, d, txt[:90].replace("\n", " "), flush=True)
            else:
                r[key] = True
                print("anim queued", sp, st, d, flush=True)
            _save(CHARS, rows)
    print("still pending:", pending, flush=True)
    return pending

def animpoll():
    from PIL import Image
    rows = _load(CHARS)
    waiting = 0
    for r in rows:
        sp, st = r["species"], r["stage"]
        combat = "south-east" if sp in USE_SE else "east"
        # require BOTH dirs queued AND downloaded - a cap-deferred south used to let an
        # east-only zip read mark the stage frames_done (08-27 bug: 32 souths stranded).
        need = ["south", combat]
        if not all(r.get("anim_ok_" + d) for d in need) or r.get("frames_done"): continue
        try:
            import zipfile
            z = zipfile.ZipFile(io.BytesIO(_fetch(CHAR_DL.format(id=r["char"]))))
        except Exception as e:
            waiting += 1; print("zip pending/fail", sp, st, e, flush=True); continue
        got = {}
        for d in need:
            names = sorted(n for n in z.namelist()
                           if "animations/" in n and ("/%s/" % d) in n and n.endswith(".png"))
            if not names: continue
            outdir = os.path.join(REVIEW, sp); os.makedirs(outdir, exist_ok=True)
            suffix = "s" if d == "south" else "e"
            frames = []
            for i, n in enumerate(names):
                fp = os.path.join(outdir, "%s_%s_ANIM_%d.png" % (st, suffix, i))
                open(fp, "wb").write(z.read(n)); frames.append(fp)
            got[d] = len(frames)
            ims = [Image.open(f).convert("RGBA").resize((192, 192), Image.NEAREST) for f in frames]
            bgs = [Image.new("RGBA", (192, 192), (60, 60, 68, 255)) for _ in ims]
            for b_, im_ in zip(bgs, ims): b_.alpha_composite(im_)
            bgs[0].save(os.path.join(REVIEW, "ANIM_%s_%s_%s.gif" % (sp, st, suffix)),
                        save_all=True, append_images=bgs[1:], duration=120, loop=0, disposal=2)
        if len(got) == len(need):
            r["frames_done"] = True
            print("frames", sp, st, got, flush=True)
        else:
            waiting += 1
            print("partial", sp, st, got, flush=True)
    _save(CHARS, rows)
    print("waiting:", waiting, flush=True)
    return waiting

# ---------- Phase F: import (GM CLOSED; NEW sprites -> build + register in yyp) ----------
def do_import(only=None):
    from PIL import Image
    import glob as _glob
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import gm_import
    built = []
    rows = _load(CHARS)
    for r in rows:
        if not r.get("frames_done"): continue
        sp, st = r["species"], r["stage"]
        if only and sp not in only: continue
        for suffix in ("s", "e"):
            fs = sorted(_glob.glob(os.path.join(REVIEW, sp, "%s_%s_ANIM_*.png" % (st, suffix))),
                        key=lambda p: int(p.rsplit("_", 1)[1][:-4]))
            fr = [Image.open(f).convert("RGBA") for f in fs]
            if len(fr) < 4:
                print("NO FRAMES", sp, st, suffix, len(fr)); continue
            if len(fr) == 9:
                # 9 frames back (frame 0 = reference). Two 8-frame windows are possible;
                # pick the one whose wrap-around jump is smallest (seamless-loop QC).
                from PIL import ImageChops, ImageStat
                def _md(a, b):
                    s = ImageStat.Stat(ImageChops.difference(a, b))
                    return sum(s.mean) / len(s.mean)
                fr = fr[:8] if _md(fr[7], fr[0]) <= _md(fr[8], fr[1]) else fr[1:9]
            name = "spr_pet_%s_%s_%s" % (sp, st, suffix)
            gm_import.build_anim_sprite(name, fr, fps=8.0)
            built.append(name)
    gm_import.register(built)
    print("done: %d sprites built+registered" % len(built))
    print("REMEMBER: add these to global.__sprite_includes (obj_game_controller/Create_0.gml):")
    for n in built: print("    " + n + ",")
    return built

if __name__ == "__main__":
    a = sys.argv[1:]
    if   a[0] == "cand":      cand(a[1:] or None)
    elif a[0] == "candpoll":  candpoll()
    elif a[0] == "sheet":     sheet_cands()
    elif a[0] == "stages":    stages(a[2:] or None, mode=a[1])
    elif a[0] == "stagepoll": stagepoll()
    elif a[0] == "chars":     chars(a[1:] or None)
    elif a[0] == "chpoll":    chpoll()
    elif a[0] == "sheetrot":  sheet_rot(a[1:] or None)
    elif a[0] == "anims":     anims(a[1:] or None)
    elif a[0] == "animpoll":  animpoll()
    elif a[0] == "import":    do_import(a[1:] or None)
