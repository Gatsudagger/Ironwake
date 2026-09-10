"""Apply M's facing read (09-09) to enemy_model_faces_east in scr_enemies.gml.
Usage: python tools/facing_apply_0909.py TOGGLE_NUMBERS...  (numbers from
_for_review/facing_asdrawn_0909/index.txt). A toggled model that is flagged gets
unflagged (it was authored LEFT and the mirror turned it away); an unflagged one
gets flagged (authored RIGHT). Preserves the file's LF endings.
"""
import sys, os, re
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GML = os.path.join(ROOT, "scripts", "scr_enemies", "scr_enemies.gml")
IDX = os.path.join(ROOT, "_for_review", "facing_asdrawn_0909", "index.txt")
names = {}
for line in open(IDX, encoding="utf-8"):
    n, spr, *_ = line.rstrip("\n").split("\t")
    names[int(n)] = spr
toggle = [names[int(a)] for a in sys.argv[1:]]
s = open(GML, encoding="utf-8", newline="").read()
a = s.index("function enemy_model_faces_east")
b = s.index("};", a)
blk = s[a:b]
add = []
for spr in toggle:
    pat = re.compile(r"\b" + re.escape(spr) + r"\s*:\s*1\s*,?\s*")
    if pat.search(blk):
        blk = pat.sub("", blk, count=1)
        print("unflag", spr)
    else:
        add.append(spr)
        print("flag  ", spr)
if add:
    blk = blk.rstrip() + "\n        // 09-09 M's read of the AS-DRAWN sheet (_for_review/facing_asdrawn_0909): authored RIGHT.\n"
    for spr in add:
        blk += f"        {spr}: 1,\n"
    blk += "    "
s = s[:a] + blk + s[b:]
open(GML, "w", encoding="utf-8", newline="").write(s)
