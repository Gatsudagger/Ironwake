"""08-17 (M): static-still species may ship if all 3 stages exist AND east matches south (or
one still feeds both). The 08-06 static wave's _e renders carry baked 'BABY'/'ADULT' labels
and mismatched designs, so rebuild every spr_pet_<sp>_<stage>_e as an EXACT clone of its _s
sprite (same origin/size/bbox/playback; fresh GUIDs). Idempotent."""
import os, re, shutil, uuid, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPECIES = ["ashjaw_lynx", "wispfox", "gravefox", "frostmarten", "snowmaw", "permafrost_toad", "icewing_skua",
           "witchwood_fawn", "fathom_squid", "lantern_wyrm", "deepclaw", "griefwisp", "sluice_otter", "graftling",
           "thornlet", "whispervine"]
STAGES = ["baby", "youngadult", "adult"]
UUID = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")

def clone(src, dst):
    sdir, ddir = os.path.join(ROOT, "sprites", src), os.path.join(ROOT, "sprites", dst)
    text = open(os.path.join(sdir, src + ".yy"), encoding="utf-8").read()
    ids = sorted(set(UUID.findall(text)))
    m = {i: str(uuid.uuid4()) for i in ids}
    if os.path.isdir(ddir): shutil.rmtree(ddir)
    os.makedirs(ddir)
    out = text.replace(src, dst)
    for a, b in m.items(): out = out.replace(a, b)
    open(os.path.join(ddir, dst + ".yy"), "w", encoding="utf-8", newline="\n").write(out)
    for f in os.listdir(sdir):
        p = os.path.join(sdir, f)
        if f.endswith(".png"): shutil.copy(p, os.path.join(ddir, m.get(f[:-4], f[:-4]) + ".png"))
        elif f == "layers":
            for fr in os.listdir(p):
                nd = os.path.join(ddir, "layers", m.get(fr, fr)); os.makedirs(nd)
                for lf in os.listdir(os.path.join(p, fr)):
                    shutil.copy(os.path.join(p, fr, lf), os.path.join(nd, m.get(lf[:-4], lf[:-4]) + ".png"))
    return len(m)

if __name__ == "__main__":
    n = 0
    for sp in SPECIES:
        for st in STAGES:
            s, e = "spr_pet_%s_%s_s" % (sp, st), "spr_pet_%s_%s_e" % (sp, st)
            if not os.path.isdir(os.path.join(ROOT, "sprites", s)): print("MISSING", s); continue
            clone(s, e); n += 1
    print("cloned", n, "east sprites from south")
