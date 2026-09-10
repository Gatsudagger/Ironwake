#!/usr/bin/env python
"""Drip-feed gen_biome_enemies_0902 jobs past the Tier-2 10-concurrent cap. Submits up to
MAXQ at once, polls, downloads finished sheets, tops the queue back up. Prints one line per event."""
import os, sys, json, glob, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_biome_enemies_0902 as G
import ffgen

MAXQ = int(os.environ.get("MAXQ", "10"))
keys = sys.argv[1:] or [k for k in G.ENEMIES]

def done(k):
    return bool(glob.glob(os.path.join(G.REVIEW, "%s_[0-9]*.png" % k)))

def jobs():
    return json.load(open(G.JOBS)) if os.path.exists(G.JOBS) else {}

while True:
    J = jobs()
    pending = [k for k in keys if not done(k)]
    if not pending:
        print("ALL DONE"); break
    active = [k for k in pending if J.get(k)]
    # download finished
    for k in active:
        txt, _ = ffgen.call_tool("get_image", {"job_id": J[k]})
        low = txt.lower()
        if "completed" in low:
            G.poll(); print("LANDED", k); sys.stdout.flush()
        elif "failed" in low or "error" in low:
            print("FAILED", k, txt[:160].replace("\n", " | ")); sys.stdout.flush()
            J = jobs(); J[k] = None; json.dump(J, open(G.JOBS, "w"), indent=1)
    J = jobs()
    active = [k for k in pending if J.get(k) and not done(k)]
    todo = [k for k in pending if not J.get(k)]
    room = MAXQ - len(active)
    if room > 0 and todo:
        for k in todo[:room]:
            try:
                G.submit([k]); print("SUBMITTED", k)
            except Exception as e:
                print("SUBMIT-ERR", k, str(e)[:160])
            sys.stdout.flush()
    time.sleep(30)
