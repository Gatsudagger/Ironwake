"""Facing review sheet (09-09): every FF enemy model drawn EXACTLY as combat draws
it - the enemy_model_faces_east mirror applied - numbered, so M can mark the wrong
ones by number instead of Claude guessing facing from a 3/4-front frame.

Output: _for_review/facing_asdrawn_0909/page_N.png (+ index.txt: number -> sprite).
Enemies stand on the RIGHT of the arena, so the correct facing is toward the
viewer's LEFT (toward the player). 'M' after the name = currently mirrored.
"""
import os, re, glob
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "_for_review", "facing_asdrawn_0909")
os.makedirs(OUT, exist_ok=True)

gml = open(os.path.join(ROOT, "scripts", "scr_enemies", "scr_enemies.gml"), encoding="utf-8").read()
blk = gml[gml.index("function enemy_model_faces_east"):]
blk = blk[:blk.index("};")]
east = set(re.findall(r"(spr_[a-z0-9_]+)\s*:\s*1", blk))

dirs = sorted(d for d in glob.glob(os.path.join(ROOT, "sprites", "spr_*_ff*"))
              if re.search(r"_ff[23]?$", d))
models = []
for d in dirs:
    name = os.path.basename(d)
    pngs = [p for p in glob.glob(os.path.join(d, "*.png"))]
    if not pngs:
        continue
    models.append((name, pngs[0]))

SCALE, COLS, PER = 3, 6, 30
CELL_W, CELL_H = 300, 330
try:
    font = ImageFont.truetype("arial.ttf", 18)
    font_b = ImageFont.truetype("arialbd.ttf", 26)
except Exception:
    font = font_b = ImageFont.load_default()

index = []
for p in range(0, len(models), PER):
    chunk = models[p:p + PER]
    rows = (len(chunk) + COLS - 1) // COLS
    sheet = Image.new("RGBA", (COLS * CELL_W, rows * CELL_H + 40), (24, 26, 34, 255))
    dr = ImageDraw.Draw(sheet)
    dr.text((10, 8), f"FACING AS DRAWN IN COMBAT - page {p // PER + 1}. Enemies should face LEFT (toward the player). M = mirrored by the flag list.", fill=(230, 230, 230), font=font)
    for i, (name, png) in enumerate(chunk):
        n = p + i + 1
        index.append(f"{n}\t{name}\t{'MIRRORED' if name in east else ''}")
        im = Image.open(png).convert("RGBA")
        if name in east:
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
        w, h = im.size
        s = min(SCALE, (CELL_W - 20) / w, (CELL_H - 70) / h)
        im = im.resize((max(1, int(w * s)), max(1, int(h * s))), Image.NEAREST)
        cx = (i % COLS) * CELL_W
        cy = 40 + (i // COLS) * CELL_H
        dr.rectangle((cx + 2, cy + 2, cx + CELL_W - 2, cy + CELL_H - 2), outline=(70, 75, 90))
        # ground line + a player-side marker so "left" is unambiguous
        dr.line((cx + 10, cy + CELL_H - 60, cx + CELL_W - 10, cy + CELL_H - 60), fill=(90, 95, 110))
        dr.text((cx + 8, cy + CELL_H - 56), "<- player", fill=(120, 200, 140), font=font)
        sheet.alpha_composite(im, (cx + (CELL_W - im.width) // 2, cy + CELL_H - 60 - im.height))
        dr.text((cx + 8, cy + 6), f"#{n}", fill=(255, 225, 120), font=font_b)
        label = name.replace("spr_", "") + ("  M" if name in east else "")
        dr.text((cx + 8, cy + 36), label, fill=(210, 215, 225), font=font)
    sheet.convert("RGB").save(os.path.join(OUT, f"page_{p // PER + 1}.png"))

open(os.path.join(OUT, "index.txt"), "w", encoding="utf-8").write("\n".join(index))
print(f"{len(models)} models, {(len(models) + PER - 1) // PER} pages -> {OUT}")
