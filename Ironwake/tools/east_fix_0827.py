#!/usr/bin/env python
"""08-27 EAST-FACING FIX (M: "a few pet creatures still face south in combat... utilize the
direction generation so we don't keep getting mismatched sprites, conserve credits").

RECIPE (locked after test-gen; pixflux img2img turn FAILED twice - kept frontal pose or lost
identity - and was dropped per the 2-strikes rule):
  shipped _s frame 0 (approved identity) -> create_character mode=v3 reference_image
  (PixelLab's DIRECTION GENERATION: rotates the exact sprite into 8 directions, 1 GEN) ->
  M approves the east rotations on sheets -> animate_character v3 east idle 8f (1 gen/dir)
  -> import east anim frames as spr_pet_<sp>_<st>_e (frame swap, names already in .yyp).
lantern_wyrm extra: ya/adult _s are STATIC 43/44px stills - their rebuilt _s uses the SAME
character's south direction (s/e guaranteed-matched) with its own south idle anim.

Usage (in order):
  python tools/east_fix_0827.py chars [species ...]  # 1 gen/stage: queue v3 reference rotations
  python tools/east_fix_0827.py chpoll               # download east(+lantern south) rotations
  python tools/east_fix_0827.py sheet                # per-species review sheets for M
  python tools/east_fix_0827.py anims                # 1 gen/dir: idle anims for APPROVED.json stages
  python tools/east_fix_0827.py animpoll             # download anim frames + gif previews
  python tools/east_fix_0827.py import               # GM CLOSED: rebuild _e (+ lantern _s) sprites
APPROVED.json: ["<species>_<stage>", ...] - written after M's sheet review ("all" = everything).
"""
import os, sys, json, glob, io, zipfile, urllib.request
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ffgen, gm_import
from PIL import Image

ROOT   = ffgen.ROOT
REVIEW = os.path.join(ROOT, "_for_review", "east_fix_0827")
os.makedirs(REVIEW, exist_ok=True)
CHARS    = os.path.join(REVIEW, "CHARS.json")
APPROVED = os.path.join(REVIEW, "APPROVED.json")

SPECIES = ["ashjaw_lynx", "wispfox", "gravefox", "frostmarten", "snowmaw", "permafrost_toad",
           "icewing_skua", "witchwood_fawn", "sluice_otter", "hollow_pup", "griefwisp",
           "fathom_squid", "golemite", "deepclaw", "lantern_wyrm"]
STAGES = ["baby", "youngadult", "adult"]

# Short identity line per species so the rotation prompt knows what it is looking at.
DESC = {
 "ashjaw_lynx":     "small dark lynx cub creature with ember-orange chest glow",
 "wispfox":         "pale grey fox creature with blue wisp flames at its tail",
 "gravefox":        "pale-cream fennec fox creature with oversized ears",
 "frostmarten":     "slender white marten creature",
 "snowmaw":         "stocky brown-and-cream wolverine beast",
 "permafrost_toad": "pale ice-blue toad creature",
 "icewing_skua":    "white seabird creature with spread ice wings",
 "witchwood_fawn":  "pale fawn creature with budding antlers",
 "sluice_otter":    "brown otter creature with a glowing horn",
 "hollow_pup":      "gaunt shadowy hound pup creature",
 "griefwisp":       "small violet ghost wisp creature",
 "fathom_squid":    "small dark deep-sea squid creature",
 "golemite":        "small animate stone golem creature",
 "deepclaw":        "armoured crab creature",
 "lantern_wyrm":    "small green serpent creature with a glowing lantern lure",
}

IDLE = ("gentle idle loop in place: slow breathing, subtle weight shift, small head and tail "
        "sway, feet planted, same size and colours every frame; ends exactly on the starting pose")

# Re-roll descriptions for M-rejected rotations (08-27 review round 1): tuned to pin the
# identity the first roll lost. Keyed (species, stage).
REROLL_DESC = {
 ("griefwisp", "youngadult"): "a floating hooded violet GHOST wisp creature with a pale flame atop its head and a tattered trailing hem, no legs, hovering - a spirit, not an object",
 ("griefwisp", "adult"):      "a floating hooded violet GHOST wisp creature with a pale flame atop its head and a tattered trailing hem, no legs, hovering - a spirit, not an object",
 ("golemite", "adult"):       "an animate stone GOLEM creature standing on two rocky legs with two rocky arms and a glowing orange ember core burning in its chest",
 ("icewing_skua", "baby"):    "a round white owl-faced seabird chick with pale ice-blue wing edges and dark watchful eyes",
 ("wispfox", "adult"):        "a pale grey fox creature with dusty red-brown ear tips and paws and blue wisp flames at its tail tip, cool grey fur",
}

CHAR_DL = "https://api.pixellab.ai/mcp/characters/{id}/download"


def south_frame0(sp, st):
    d = os.path.join(ROOT, "sprites", "spr_pet_%s_%s_s" % (sp, st))
    fs = sorted(glob.glob(os.path.join(d, "*.png")))
    return Image.open(fs[0]).convert("RGBA")


def base_still(sp, st):
    """Rotation input: _s frame 0; static lantern ya/adult stills padded onto 64."""
    p = os.path.join(REVIEW, "%s_%s_base.png" % (sp, st))
    if os.path.exists(p):
        return p
    im = south_frame0(sp, st)
    if sp == "lantern_wyrm" and st in ("youngadult", "adult"):
        im = im.crop(im.getbbox())
        out = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        out.paste(im, ((64 - im.width) // 2, 60 - im.height), im)
        im = out
    im.save(p)
    return p


def _chars():
    return json.load(open(CHARS)) if os.path.exists(CHARS) else []


def chars(only=None):
    rows = _chars()
    have = {(r["species"], r["stage"]) for r in rows if r.get("char")}
    for sp in (only or SPECIES):
        for st in STAGES:
            if (sp, st) in have:
                print("skip", sp, st); continue
            desc = REROLL_DESC.get((sp, st), DESC[sp])
            txt, _ = ffgen.call_tool("create_character", {
                "description": desc + ", pixel art game sprite",
                "mode": "v3",
                "reference_image_base64": ffgen.b64file(base_still(sp, st)),
                "name": "eastfix %s %s" % (sp, st)})
            cid = None
            for line in txt.splitlines():
                if line.startswith("id:"):
                    cid = line.split(":", 1)[1].strip(); break
            rows.append({"species": sp, "stage": st, "char": cid, "rot_done": False, "raw": txt[:150]})
            json.dump(rows, open(CHARS, "w"), indent=1)
            print("queued" if cid else "FAILED", sp, st, cid or txt[:100])


def _fetch(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "ironwake"}), timeout=120).read()


def chpoll():
    rows = _chars()
    for r in rows:
        if r["rot_done"] or not r["char"]:
            continue
        txt, _ = ffgen.call_tool("get_character", {"character_id": r["char"], "include_preview": False})
        if "status: completed" not in txt and "rotations:" not in txt:
            print("pending", r["species"], r["stage"]); continue
        # Parse ONLY the rotations: block - animation entries also print
        # "east: https..." lines (comma-joined frame lists) further down.
        urls = {}
        in_rot = False
        for line in txt.splitlines():
            s = line.strip()
            if s.startswith("rotations:"):
                in_rot = True; continue
            if in_rot and (s == "" or s.endswith(":") or ":" not in s):
                break
            if in_rot:
                for d in ("south", "east"):
                    if s.startswith(d + ": https"):
                        urls[d] = s.split(": ", 1)[1].split(",")[0].strip()
        if "east" not in urls:
            print("no east yet", r["species"], r["stage"]); continue
        open(os.path.join(REVIEW, "%s_%s_east.png" % (r["species"], r["stage"])), "wb").write(_fetch(urls["east"]))
        if "south" in urls:
            open(os.path.join(REVIEW, "%s_%s_charsouth.png" % (r["species"], r["stage"])), "wb").write(_fetch(urls["south"]))
        r["rot_done"] = True
        print("rotations", r["species"], r["stage"])
    json.dump(rows, open(CHARS, "w"), indent=1)
    print("%d/%d rotated" % (sum(1 for r in rows if r["rot_done"]), len(rows)))


def sheet():
    from PIL import ImageDraw
    for sp in SPECIES:
        rows = []
        for st in STAGES:
            e = os.path.join(REVIEW, "%s_%s_east.png" % (sp, st))
            if os.path.exists(e):
                rows.append((st, [("shipped south", os.path.join(REVIEW, "%s_%s_base.png" % (sp, st))),
                                  ("EAST rotation", e)]))
        if not rows:
            continue
        S = 3; CELL = 64 * S
        im = Image.new("RGBA", (2 * (CELL + 12) + 20, len(rows) * (CELL + 40) + 40), (30, 30, 36, 255))
        d = ImageDraw.Draw(im)
        d.text((10, 8), sp + " - east from direction-rotation (approve per stage)", fill=(255, 220, 140))
        for i, (st, cells) in enumerate(rows):
            y = 34 + i * (CELL + 40)
            for j, (lbl, p) in enumerate(cells):
                x = 10 + j * (CELL + 12)
                c = Image.open(p).convert("RGBA")
                sc = min(CELL / c.width, CELL / c.height)
                c = c.resize((max(1, round(c.width * sc)), max(1, round(c.height * sc))), Image.NEAREST)
                bg = Image.new("RGBA", (CELL, CELL), (58, 58, 66, 255))
                bg.alpha_composite(c, ((CELL - c.width) // 2, CELL - c.height))
                im.paste(bg, (x, y))
                d.text((x, y + CELL + 4), "%s %s" % (st, lbl), fill=(220, 220, 230))
        im.save(os.path.join(REVIEW, "SHEET_%s.png" % sp))
        print("sheet", sp)


def _approved():
    a = json.load(open(APPROVED))
    if a == "all":
        return [(sp, st) for sp in SPECIES for st in STAGES]
    return [tuple(k.rsplit("_", 1)) for k in a]


def anims():
    """Queue idle anims for approved stages. Success tracked PER (stage, dir) so the
    10-concurrent-job cap (429s) can be pumped - re-run until everything reports queued."""
    rows = _chars()
    pending = 0
    for sp, st in _approved():
        r = next((x for x in rows if x["species"] == sp and x["stage"] == st and x.get("char")), None)
        if not r:
            print("NO CHAR", sp, st); continue
        dirs = ["east"]
        if sp == "lantern_wyrm" and st in ("youngadult", "adult"):
            dirs = ["east", "south"]
        for d in dirs:
            key = "anim_ok_" + d
            if r.get(key):
                continue
            txt, _ = ffgen.call_tool("animate_character", {
                "character_id": r["char"], "mode": "v3", "directions": [d],
                "action_description": IDLE, "frame_count": 8,
                "animation_name": "eastfix_idle_" + d})
            if txt.lstrip().lower().startswith("error"):
                pending += 1
                print("DEFERRED", sp, st, d, txt[:90].replace("\n", " "))
            else:
                r[key] = True
                print("anim queued", sp, st, d)
            json.dump(rows, open(CHARS, "w"), indent=1)
    print("still pending:", pending)
    return pending


def animpoll():
    rows = _chars()
    for r in rows:
        if not (r.get("anim_ok_east") or r.get("anim_ok_south")) or r.get("frames_done"):
            continue
        sp, st = r["species"], r["stage"]
        try:
            z = zipfile.ZipFile(io.BytesIO(_fetch(CHAR_DL.format(id=r["char"]))))
        except Exception as e:
            print("zip pending/fail", sp, st, e); continue
        got = 0
        for d in ("east", "south"):
            names = sorted(n for n in z.namelist()
                           if "animations/" in n and ("/%s/" % d) in n and n.endswith(".png"))
            if not names:
                continue
            outdir = os.path.join(REVIEW, sp)
            os.makedirs(outdir, exist_ok=True)
            frames = []
            for i, n in enumerate(names):
                fp = os.path.join(outdir, "%s_%s_ANIM_%d.png" % (st, d[0], i))
                open(fp, "wb").write(z.read(n))
                frames.append(fp)
            got += len(frames)
            ims = [Image.open(f).convert("RGBA").resize((192, 192), Image.NEAREST) for f in frames]
            bgs = [Image.new("RGBA", (192, 192), (60, 60, 68, 255)) for _ in ims]
            for b_, im_ in zip(bgs, ims):
                b_.alpha_composite(im_)
            bgs[0].save(os.path.join(REVIEW, "ANIM_%s_%s_%s.gif" % (sp, st, d[0])),
                        save_all=True, append_images=bgs[1:], duration=120, loop=0, disposal=2)
        if got:
            r["frames_done"] = True
            print("frames", sp, st, got)
        else:
            print("no frames yet", sp, st)
    json.dump(rows, open(CHARS, "w"), indent=1)


def do_import(only=None):
    """GM CLOSED. _e from east anim frames (8f @8fps); lantern ya/adult _s rebuilt from the
    same character's south anim. Frame swaps only - names already in Ironwake.yyp."""
    n = 0
    for sp, st in _approved():
        if only and sp not in only:
            continue
        fs = sorted(glob.glob(os.path.join(REVIEW, sp, "%s_e_ANIM_*.png" % st)),
                    key=lambda p: int(p.rsplit("_", 1)[1][:-4]))
        fr = [Image.open(f).convert("RGBA") for f in fs]
        if len(fr) < 4:
            print("NO FRAMES", sp, st, len(fr)); continue
        if len(fr) == 9:
            fr = fr[:8]
        gm_import.build_anim_sprite("spr_pet_%s_%s_e" % (sp, st), fr, fps=8.0)
        n += 1
        if sp == "lantern_wyrm" and st in ("youngadult", "adult"):
            ss = sorted(glob.glob(os.path.join(REVIEW, sp, "%s_s_ANIM_*.png" % st)),
                        key=lambda p: int(p.rsplit("_", 1)[1][:-4]))
            sfr = [Image.open(f).convert("RGBA") for f in ss]
            if len(sfr) >= 4:
                if len(sfr) == 9:
                    sfr = sfr[:8]
                gm_import.build_anim_sprite("spr_pet_%s_%s_s" % (sp, st), sfr, fps=8.0)
                n += 1
    print("done", n, "sprites rebuilt")


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[0] == "chars":      chars(a[1:] or None)
    elif a[0] == "chpoll":   chpoll()
    elif a[0] == "sheet":    sheet()
    elif a[0] == "anims":    anims()
    elif a[0] == "animpoll": animpoll()
    elif a[0] == "import":   do_import(a[1:] or None)
