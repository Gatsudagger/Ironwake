"""Big verification strip for a handful of models: RAW frame vs AS-DRAWN-NOW
(mirror flag applied). Usage: python tools/facing_verify_0909.py spr_a spr_b ...
Output: _for_review/facing_asdrawn_0909/verify_<n>.png
"""
import sys, os, re, glob
from PIL import Image, ImageDraw, ImageFont
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "_for_review", "facing_asdrawn_0909")
gml = open(os.path.join(ROOT, "scripts", "scr_enemies", "scr_enemies.gml"), encoding="utf-8").read()
blk = gml[gml.index("function enemy_model_faces_east"):]
blk = blk[:blk.index("};")]
east = set(re.findall(r"(spr_[a-z0-9_]+)\s*:\s*1", blk))
names = sys.argv[1:]
S, CW, CH = 5, 520, 420
try:
    font = ImageFont.truetype("arial.ttf", 20)
except Exception:
    font = ImageFont.load_default()
sheet = Image.new("RGB", (2 * CW, len(names) * CH + 40), (24, 26, 34))
dr = ImageDraw.Draw(sheet)
dr.text((10, 8), "LEFT column = RAW file.   RIGHT column = AS COMBAT DRAWS IT NOW (enemies must face LEFT, toward the player).", fill=(230, 230, 230), font=font)
for i, n in enumerate(names):
    d = os.path.join(ROOT, "sprites", n)
    png = glob.glob(os.path.join(d, "*.png"))[0]
    raw = Image.open(png).convert("RGBA")
    raw = raw.resize((raw.width * S, raw.height * S), Image.NEAREST)
    drawn = raw.transpose(Image.FLIP_LEFT_RIGHT) if n in east else raw
    y = 40 + i * CH
    for col, (im, tag) in enumerate([(raw, "RAW"), (drawn, "AS DRAWN" + ("  (mirrored)" if n in east else "  (not mirrored)"))]):
        x = col * CW
        dr.rectangle((x + 2, y + 2, x + CW - 2, y + CH - 2), outline=(70, 75, 90))
        dr.text((x + 8, y + 6), f"{n}  -  {tag}", fill=(255, 225, 120), font=font)
        dr.text((x + 8, y + CH - 28), "<- player", fill=(120, 200, 140), font=font)
        s = min(1.0, (CW - 20) / im.width, (CH - 70) / im.height)
        im2 = im.resize((int(im.width * s), int(im.height * s)), Image.NEAREST) if s < 1 else im
        sheet.paste(im2, (x + (CW - im2.width) // 2, y + CH - 36 - im2.height), im2)
out = os.path.join(OUT, f"verify_{len(names)}.png")
sheet.save(out)
print(out)
