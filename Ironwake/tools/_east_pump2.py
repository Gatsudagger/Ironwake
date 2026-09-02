#!/usr/bin/env python
"""Pump phase 2: (a) re-roll the 5 flagged rotation characters (REROLL_DESC), (b) queue all
approved idle anims - both under the 10-concurrent-job cap. Re-runs until everything queued."""
import os, sys, json, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import east_fix_0827 as ef

def clean():
    rows = [r for r in ef._chars() if r.get("char")]
    json.dump(rows, open(ef.CHARS, "w"), indent=1)
    return rows

for rnd in range(60):
    rows = clean()
    have = {(r["species"], r["stage"]) for r in rows}
    missing = [(sp, st) for sp in ef.SPECIES for st in ef.STAGES if (sp, st) not in have]
    pending_anims = 0
    try:
        pending_anims = ef.anims()
    except Exception as e:
        print("anims error:", e, flush=True)
        pending_anims = 1
    if missing:
        try:
            ef.chars()
        except Exception as e:
            print("chars error:", e, flush=True)
    rows = clean()
    have = {(r["species"], r["stage"]) for r in rows}
    missing = [(sp, st) for sp in ef.SPECIES for st in ef.STAGES if (sp, st) not in have]
    print("round", rnd, "chars missing", len(missing), "anims pending", pending_anims, flush=True)
    if not missing and pending_anims == 0:
        break
    time.sleep(70)
print("pump2 done", flush=True)
