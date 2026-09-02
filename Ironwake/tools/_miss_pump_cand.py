#!/usr/bin/env python
"""Pump phase A (identity candidates) for the 25 remaining species under the Tier-2
10-concurrent-job cap. pixen/pixflux jobs run 10-40s, so short rounds: submit what fits,
poll to free slots, repeat until every (species, variant) has a downloaded file."""
import os, sys, json, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import missgen

TODO = [sp for sp in missgen.SPECIES if sp != "ember_ram"]

for rnd in range(120):
    rows = missgen._load(missgen.CANDS)
    # drop failed-submit rows (job None) so cand() retries them
    rows = [r for r in rows if r.get("job")]
    missgen._save(missgen.CANDS, rows)
    have = {(r["species"], r["variant"]) for r in rows}
    missing = [(sp, v) for sp in TODO for v in ("pixen", "pixflux") if (sp, v) not in have]
    inflight = sum(1 for r in rows if r.get("job") and not r["done"])
    print("round", rnd, "have", len(have), "missing", len(missing), "inflight", inflight, flush=True)
    if not missing and inflight == 0:
        break
    # submit a few if there's headroom
    if missing and inflight < 8:
        batch = sorted({sp for sp, v in missing})[:4]
        try:
            missgen.cand(batch)
        except Exception as e:
            print("cand error:", e, flush=True)
    time.sleep(25)
    try:
        missgen.candpoll()
    except Exception as e:
        print("poll error:", e, flush=True)
print("pump done", flush=True)
