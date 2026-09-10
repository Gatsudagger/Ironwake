#!/usr/bin/env python
"""09-02 GM-CLOSED import of the biome enemy art run (gen_biome_enemies_0902.py picks).
Reads _for_review/biome_enemies_0902/PICKS.json = {key: [primary, alt2, alt3]} (candidate
indexes; 1-3 entries) and builds spr_<key>_ff / _ff2 / _ff3 from the 64/80px candidates
(template = spr_skeleton_soldier_ff, fresh uuids, bbox from alpha), registers them in the
.yyp, appends the names to global.__sprite_includes (obj_game_controller Create_0, LF) and
swaps the stand-in line in enemy_sprite_map (scr_enemies, CRLF) to the new primary.
Idempotent: existing sprite folders are skipped, existing includes/map lines are left alone.
  python tools/import_biome_enemies_0902.py [key ...]
"""
import os, sys, json, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gm_import
import gen_biome_enemies_0902 as G

ROOT = gm_import.ROOT
PICKS = os.path.join(G.REVIEW, "PICKS.json")
CREATE0 = os.path.join(ROOT, "objects", "obj_game_controller", "Create_0.gml")
ENEMIES = os.path.join(ROOT, "scripts", "scr_enemies", "scr_enemies.gml")
TEMPLATE = "spr_skeleton_soldier_ff"


def main(keys):
    picks = json.load(open(PICKS))
    keys = keys or list(picks)
    built, primaries = [], {}
    for k in keys:
        idxs = picks[k]
        for n, idx in enumerate(idxs[:3]):
            name = "spr_%s_ff%s" % (k, "" if n == 0 else str(n + 1))
            src = os.path.join(G.REVIEW, "%s_%d.png" % (k, idx))
            if not os.path.exists(src):
                raise SystemExit("missing candidate " + src)
            gm_import.build_sprite(name, src, TEMPLATE)
            built.append(name)
            if n == 0: primaries[k] = name
    gm_import.register(built)

    # __sprite_includes (LF file): append after the opening line of the array
    txt = open(CREATE0, "r", encoding="utf-8", newline="").read()
    missing = [n for n in built if re.search(r"\b%s\b" % n, txt) is None]
    if missing:
        marker = "global.__sprite_includes = [\n"
        i = txt.index(marker) + len(marker)
        ins = "    // 09-02 biome enemy art run (variants resolve _ff2/_ff3 by string)\n"
        ins += "".join("    %s,\n" % n for n in missing)
        txt = txt[:i] + ins + txt[i:]
        open(CREATE0, "w", encoding="utf-8", newline="").write(txt)
    print("includes added:", len(missing))

    # enemy_sprite_map (CRLF file): swap the stand-in on the exact display-name line
    src = open(ENEMIES, "r", encoding="utf-8", newline="").read()
    swapped = 0
    for k, spr in primaries.items():
        disp = G.ENEMIES[k][0]
        pat = re.compile(r'(^[ \t]*"%s":[ \t]*)(spr_[A-Za-z0-9_]+)(,)' % re.escape(disp), re.M)
        m = pat.search(src)
        if not m:
            print("MAP LINE NOT FOUND:", disp); continue
        if m.group(2) == spr: continue
        src = src[:m.start()] + m.group(1) + spr + m.group(3) + src[m.end():]
        swapped += 1
    open(ENEMIES, "w", encoding="utf-8", newline="").write(src)
    print("map lines swapped:", swapped, "| sprites built:", len(built))


if __name__ == "__main__":
    main(sys.argv[1:])
