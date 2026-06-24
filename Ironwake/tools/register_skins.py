#!/usr/bin/env python
# Register every built spr_skin_* / female-class sprite from the manifest into
# Ironwake.yyp (idempotent — skips already-registered). Inserts after the
# spr_hub_background anchor. Preserves LF line endings.
import os
YYP = "Ironwake.yyp"
ANCHOR = '    {"id":{"name":"spr_hub_background","path":"sprites/spr_hub_background/spr_hub_background.yy",},},\n'
s = open(YYP, encoding="utf-8", newline="").read()
add = []
for line in open("tools/skin_manifest.txt", encoding="utf-8"):
    p = line.split()
    if len(p) < 2:
        continue
    name = p[1]
    if not os.path.exists(f"sprites/{name}/{name}.yy"):
        continue
    if f'"name":"{name}"' in s:
        continue
    add.append(f'    {{"id":{{"name":"{name}","path":"sprites/{name}/{name}.yy",}},}},\n')
if not add:
    print("nothing new to register")
elif ANCHOR not in s:
    print("ERROR: anchor not found")
else:
    s = s.replace(ANCHOR, ANCHOR + "".join(add))
    open(YYP, "w", encoding="utf-8", newline="").write(s)
    print(f"registered {len(add)} sprites")
