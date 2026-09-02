#!/usr/bin/env python
"""Drip-feed east_fix_0827 character creation under the 10-concurrent-job cap (Tier 2).
Cleans FAILED (char=None) rows, requeues missing stages, sleeps, repeats until all 45
stages have a character queued. Safe to re-run."""
import os, sys, json, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import east_fix_0827 as ef

def clean():
    rows = [r for r in ef._chars() if r.get("char")]
    json.dump(rows, open(ef.CHARS, "w"), indent=1)
    return rows

for rnd in range(45):
    rows = clean()
    have = {(r["species"], r["stage"]) for r in rows}
    missing = [(sp, st) for sp in ef.SPECIES for st in ef.STAGES if (sp, st) not in have]
    print("round", rnd, "queued", len(have), "missing", len(missing), flush=True)
    if not missing:
        break
    try:
        ef.chars()
    except Exception as e:
        print("chars error:", e, flush=True)
    rows = clean()
    if len(rows) >= 45:
        break
    time.sleep(75)
print("pump done:", len(clean()), "characters queued", flush=True)
