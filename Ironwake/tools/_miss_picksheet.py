#!/usr/bin/env python
"""Master identity pick-sheet: every candidate per species, GOLD border on the proposed
pick (PROPOSED.json). M approves-except-overrides."""
import os, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import missgen
from PIL import Image, ImageDraw

prop = json.load(open(os.path.join(missgen.REVIEW, "PROPOSED.json")))
rows = [r for r in missgen._load(missgen.CANDS) if r.get("file") and os.path.exists(r["file"])]
by_sp = {}
for r in rows: by_sp.setdefault(r["species"], []).append(r["file"])
sps = [s for s in missgen.SPECIES if s in prop and s in by_sp]
SC = 3; CELL = 64 * SC + 14
maxc = max(len(v) for v in by_sp.values())
W = 250 + maxc * CELL; H = 40 + len(sps) * (CELL + 6)
im = Image.new("RGBA", (W, H), (30, 30, 34, 255)); dr = ImageDraw.Draw(im)
dr.text((8, 8), "IDENTITY PICKS - GOLD BORDER = my proposed pick. Say 'approved' or list overrides (species + label).", fill=(230, 230, 230))
y = 40
for sp in sps:
    dr.text((8, y + 80), sp, fill=(255, 210, 120))
    for c, f in enumerate(sorted(by_sp[sp])):
        x = 250 + c * CELL
        cand = Image.open(f).convert("RGBA")
        bg = Image.new("RGBA", (64 * SC, 64 * SC), (60, 60, 68, 255))
        bg.alpha_composite(cand.resize((64 * SC, 64 * SC), Image.NEAREST))
        im.paste(bg, (x, y))
        lab = os.path.basename(f)[8:-4]
        picked = os.path.basename(f) == prop[sp]
        if picked:
            for k in range(3):
                dr.rectangle([x - 1 - k, y - 1 - k, x + 64 * SC + k, y + 64 * SC + k], outline=(255, 200, 60))
        dr.text((x + 2, y + 64 * SC + 2), lab + ("  <-- PICK" if picked else ""),
                fill=(255, 200, 60) if picked else (200, 200, 210))
    y += CELL + 6
out = os.path.join(missgen.REVIEW, "SHEET_PICKS_ALL25.png")
im.save(out); print("saved", out)
