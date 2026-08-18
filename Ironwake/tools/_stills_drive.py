import os, sys, json, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import anim_stills_0818 as A
import ffgen

def state():
    rows = json.load(open(ffgen.ANIMS)) if os.path.exists(ffgen.ANIMS) else []
    live = [r for r in rows if r.get("job")]
    done = {(r["species"], r["stage"]) for r in live if r["done"] and not r.get("failed")}
    pending = [r for r in live if not r["done"]]
    queued = {(r["species"], r["stage"]) for r in live if not r.get("failed")}
    return rows, done, pending, queued

for it in range(80):
    ffgen.anim_poll()
    rows, done, pending, queued = state()
    todo = [(sp, st) for sp in A.SPECIES for st in A.STAGES if (sp, st) not in queued]
    free = max(0, 18 - len(pending))
    for sp, st in todo[:free]:
        A.still64(sp, st)
        ffgen.anim_submit(sp, st, "s", os.path.join(A.REVIEW, "%s_%s_still64.png" % (sp, st)))
    print("iter", it, "done", len(done), "pending", len(pending), "todo", len(todo) - min(free, len(todo)), flush=True)
    if len(done) >= len(A.SPECIES) * len(A.STAGES):
        print("ALL DONE"); break
    time.sleep(30)
