#!/usr/bin/env python
"""Full-campaign pump for the 25-species batch under the Tier-2 10-concurrent-job cap.
Two phases so the stage stills get VETTED before characters derive from them:
  python tools/_miss_pump_all.py stills      # ya+baby stills for every picked species
  python tools/_miss_pump_all.py charsanims  # after PICKS.json holds vetted stage stills
Safe to re-run / resume after a kill."""
import os, sys, json, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import missgen

BATCH = [sp for sp in missgen.SPECIES if sp != "ember_ram"]
PHASE = sys.argv[1] if len(sys.argv) > 1 else "stills"

if PHASE == "stills":
    for rnd in range(60):
        srows = [r for r in missgen._load(missgen.STAGEJ) if r.get("job")]
        missgen._save(missgen.STAGEJ, srows)
        try:
            missgen.stages(BATCH, mode="fresh")   # queues only missing (skips picked stages)
        except Exception as e:
            print("stages err", e, flush=True)
        time.sleep(30)
        try:
            pending = missgen.stagepoll()
        except Exception as e:
            print("stagepoll err", e, flush=True); pending = 99
        picks = json.load(open(missgen.PICKS)) if os.path.exists(missgen.PICKS) else {}
        srows = missgen._load(missgen.STAGEJ)
        have = {(r["species"], r["stage"]) for r in srows if r.get("file")}
        need = [(sp, st) for sp in BATCH for st in ("youngadult", "baby")
                if sp in picks and st not in picks.get(sp, {}) and (sp, st) not in have]
        print("ROUND %d: stills still needed %d, jobs pending %d" % (rnd, len(need), pending), flush=True)
        if not need and pending == 0:
            break
    print("STILLS PUMP DONE", flush=True)

elif PHASE == "charsanims":
    for rnd in range(360):
        crows = missgen._load(missgen.CHARS)
        crows2 = [r for r in crows if r.get("char")]
        if len(crows2) != len(crows):
            missgen._save(missgen.CHARS, crows2)
        try:
            missgen.chars(BATCH)
        except Exception as e:
            print("chars err", e, flush=True)
        try:
            missgen.chpoll()
        except Exception as e:
            print("chpoll err", e, flush=True)
        try:
            missgen.anims(BATCH)
        except Exception as e:
            print("anims err", e, flush=True)
        try:
            missgen.animpoll()
        except Exception as e:
            print("animpoll err", e, flush=True)
        crows = missgen._load(missgen.CHARS)
        ch_have = {(r["species"], r["stage"]) for r in crows if r.get("rot_done")}
        an_done = {(r["species"], r["stage"]) for r in crows if r.get("frames_done")}
        need_ch = [(sp, st) for sp in BATCH for st in missgen.STAGES if (sp, st) not in ch_have]
        need_an = [(sp, st) for sp in BATCH for st in missgen.STAGES if (sp, st) not in an_done]
        print("ROUND %d: chars-missing %d, anims-missing %d" % (rnd, len(need_ch), len(need_an)), flush=True)
        if not need_ch and not need_an:
            break
        time.sleep(70)
    print("CHARSANIMS PUMP DONE", flush=True)
