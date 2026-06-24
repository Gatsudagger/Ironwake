#!/usr/bin/env python
# Continuously poll PixelLab for any skin in skin_regen.json that has a char_id but
# no build marker yet, wait until rotations are ready, then build the GM sprite
# resource (clearing old frames first) via build_char_sprite.py and drop a marker
# file sprites/<name>/.v2built. NEVER writes the manifest (so it can't clobber
# char_ids added concurrently); re-reads the manifest every loop to pick up newly
# fired characters. Exits when every manifest skin has a marker, or on timeout.
# Usage: python tools/poll_build_skins.py [max_wait_seconds]
import json, os, sys, time, subprocess, urllib.request

PROJECT = "c50e1365-1a8c-44be-a773-5ee635581147"
MAN = "tools/skin_regen.json"
MAX_WAIT = int(sys.argv[1]) if len(sys.argv) > 1 else 1200

def marker(name): return os.path.join("sprites", name, ".v2built")

def ready(cid):
    url = f"https://backblaze.pixellab.ai/file/pixellab-characters/{PROJECT}/{cid}/rotations/south.png"
    req = urllib.request.Request(url, method="HEAD", headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status == 200
    except Exception:
        return False

def main():
    deadline = time.time() + MAX_WAIT
    while time.time() < deadline:
        try:
            skins = json.load(open(MAN))["skins"]
        except Exception:
            time.sleep(3); continue
        pending_total = [s for s in skins if not os.path.exists(marker(s["name"]))]
        if not pending_total:
            print("ALL BUILT"); return
        buildable = [s for s in pending_total if s.get("char_id")]
        for s in buildable:
            if os.path.exists(marker(s["name"])):
                continue
            if ready(s["char_id"]):
                root = os.path.join("sprites", s["name"])
                if os.path.isdir(root):
                    subprocess.run(["rm", "-rf", root])
                r = subprocess.run(["python", "tools/build_char_sprite.py", s["char_id"], s["name"]])
                if r.returncode == 0:
                    open(marker(s["name"]), "w").close()
                    print("BUILT", s["name"], flush=True)
                else:
                    print("retry-later", s["name"], flush=True)
        remaining = [s["name"] for s in skins if not os.path.exists(marker(s["name"]))]
        print("pending:", len(remaining), remaining, flush=True)
        time.sleep(15)
    print("TIMEOUT")

main()
