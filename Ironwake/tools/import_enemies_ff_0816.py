#!/usr/bin/env python
"""08-16 GM-CLOSED import: FF-style (tactics-density) re-authors of the six Ashen Vault
base enemies, M-picked from _for_review/enemies_hd_0816 (pilot_ff_raw + ff_raw).
64x64 single 3/4-front frame each; PRIMARY pick + 2 ALTERNATES per enemy so combat
can vary the model per combatant (M 08-16: "multiple sprites for the same enemy...
random model every fight / different models when several of the same mob show up").

Sprites: spr_<enemy>_ff (primary), spr_<enemy>_ff2, spr_<enemy>_ff3 - cloned from the
spr_bone_sovereign_hd .yy template with fresh uuids + full-canvas bbox, then
registered in Ironwake.yyp. Originals untouched. Wire-up lives in scr_enemies
(enemy_sprite_map -> _ff, enemy_sprite_variants) + __sprite_includes.

Run from repo root with GameMaker CLOSED:  python tools/import_enemies_ff_0816.py
"""
import os, shutil, uuid

ROOT     = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES  = os.path.join(ROOT, "sprites")
YYP      = os.path.join(ROOT, "Ironwake.yyp")
REVIEW   = os.path.join(ROOT, "_for_review", "enemies_hd_0816")
TEMPLATE = os.path.join(SPRITES, "spr_bone_sovereign_hd", "spr_bone_sovereign_hd.yy")

# enemy -> (raw folder, filename pattern, [primary, alt2, alt3] indexes)
# Idempotent: build_sprite overwrites, register skips names already in the .yyp -
# so re-running after adding rows only imports the new ones.
PICKS = {
    # round 2 (imported 08-16 pm)
    "skeleton_archer":  ("pilot_ff_raw", "archer_ff_{}.png",          [2, 3, 7]),
    "skeleton_soldier": ("ff_raw",       "skeleton_soldier_ff_{}.png", [3, 10, 1]),
    "vault_crawler":    ("ff_raw",       "vault_crawler_ff_{}.png",    [0, 9, 12]),
    "dungeon_wraith":   ("ff_raw",       "dungeon_wraith_ff_{}.png",   [6, 1, 15]),
    "stone_golem":      ("ff_raw",       "stone_golem_ff_{}.png",      [1, 3, 8]),
    "vault_guardian":   ("ff_raw",       "vault_guardian_ff_{}.png",   [3, 7, 9]),
    # round 3 (M-picked 08-16 eve): Ashen four + six Scorched/Tundra
    "vault_wraith":     ("ff3_raw",      "vault_wraith_ff_{}.png",     [3, 2, 1]),
    "vault_sentinel":   ("ff3_raw",      "vault_sentinel_ff_{}.png",   [0, 3, 7]),
    "malgrath_warden":  ("ff3_raw",      "malgrath_warden_ff_{}.png",  [0, 10, 12]),
    "bone_colossus":    ("ff3_raw",      "bone_colossus_ff_{}.png",    [0, 9, 12]),
    "cinder_imp":       ("ff3_raw",      "cinder_imp_ff_{}.png",       [0, 7, 10]),
    "lava_spitter":     ("ff3_raw",      "lava_spitter_ff_{}.png",     [0, 8, 14]),
    "glacial_lurker":   ("ff3_raw",      "glacial_lurker_ff_{}.png",   [13, 9, 10]),
    "snowbound_wraith": ("ff3_raw",      "snowbound_wraith_ff_{}.png", [0, 9, 1]),
    "frost_shard":      ("ff3_raw",      "frost_shard_ff_{}.png",      [1, 0, 13]),
    "magma_slug":       ("ff3_raw",      "magma_slug_ff_{}.png",       [0, 4, 13]),
}

def build_sprite(name, src):
    from PIL import Image
    im  = Image.open(src)
    w, h = im.size
    frame_id = str(uuid.uuid4())
    layer_id = str(uuid.uuid4())
    d = os.path.join(SPRITES, name)
    os.makedirs(os.path.join(d, "layers", frame_id), exist_ok=True)
    shutil.copyfile(src, os.path.join(d, frame_id + ".png"))
    shutil.copyfile(src, os.path.join(d, "layers", frame_id, layer_id + ".png"))
    with open(TEMPLATE, "r", encoding="utf-8") as f:
        yy = f.read()
    yy = yy.replace("spr_bone_sovereign_hd", name)
    yy = yy.replace("5de2be9b-2f1f-4635-9a39-0859aec9efa2", frame_id)
    yy = yy.replace("6a3748e5-b659-4b1f-bbde-c1d95ccc5345", layer_id)
    yy = yy.replace('"id":"f61ab8f3-66c1-4ebb-a0fc-0019e78d9ce0"', '"id":"%s"' % str(uuid.uuid4()))
    yy = yy.replace('"bbox_bottom":167', '"bbox_bottom":%d' % (h - 1))
    yy = yy.replace('"bbox_right":109',  '"bbox_right":%d' % (w - 1))
    yy = yy.replace('"height":168', '"height":%d' % h)
    yy = yy.replace('"width":110',  '"width":%d' % w)
    with open(os.path.join(d, name + ".yy"), "w", encoding="utf-8", newline="\n") as f:
        f.write(yy)
    print("built %s (%dx%d) from %s" % (name, w, h, os.path.basename(src)))

def register(entries):
    with open(YYP, "r", encoding="utf-8") as f:
        text = f.read()
    new_lines = []
    for n, p in entries:
        if ('"name":"%s"' % n) in text:
            print("already registered:", n)
            continue
        new_lines.append('    {"id":{"name":"%s","path":"%s",},},' % (n, p))
    if new_lines:
        marker = '  "resources":[\n'
        idx = text.index(marker) + len(marker)
        text = text[:idx] + "\n".join(new_lines) + "\n" + text[idx:]
        with open(YYP, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
    print("registered %d new .yyp entries" % len(new_lines))

if __name__ == "__main__":
    names = []
    for enemy, (folder, pat, idxs) in PICKS.items():
        for k, i in enumerate(idxs):
            sname = "spr_%s_ff%s" % (enemy, "" if k == 0 else str(k + 1))
            if os.path.exists(os.path.join(SPRITES, sname, sname + ".yy")):
                print("exists, skipping:", sname)   # never re-uuid a built sprite (orphan PNGs)
            else:
                build_sprite(sname, os.path.join(REVIEW, folder, pat.format(i)))
            names.append(sname)
    register([(n, "sprites/%s/%s.yy" % (n, n)) for n in names])
    print("\n".join(names))
