#!/usr/bin/env python
# Exit once at least <need> of the given PixelLab char_ids have finished (south.png
# ready), i.e. that many of the 8 concurrent job slots have freed up. Lets the
# orchestrator know when it can fire the next batch. Usage:
#   python tools/wait_slots.py <need> <char_id> [char_id ...]
import sys, time, urllib.request
PROJECT = "c50e1365-1a8c-44be-a773-5ee635581147"
need = int(sys.argv[1]); ids = sys.argv[2:]

def ready(c):
    u = f"https://backblaze.pixellab.ai/file/pixellab-characters/{PROJECT}/{c}/rotations/south.png"
    r = urllib.request.Request(u, method="HEAD", headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(r, timeout=30) as x:
            return x.status == 200
    except Exception:
        return False

deadline = time.time() + 1000
while time.time() < deadline:
    n = sum(ready(c) for c in ids)
    print("ready", n, "/", len(ids), flush=True)
    if n >= need:
        print("SLOTS FREE"); break
    time.sleep(20)
