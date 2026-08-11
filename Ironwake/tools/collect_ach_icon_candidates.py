# collect_ach_icon_candidates.py - download every queued PixelLab candidate set
# listed in ach_icon_queue.json and build one labelled contact sheet per
# achievement, so M can pick indices in his own icon pass.
#
# Queue file format (tools\ach_icon_queue.json):
#   { "ACH_NAME": "pixellab-object-uuid", ... }
#
# Output: _for_review\ach_icon_alt\<ACH_NAME>\frame_N.png + _<ACH_NAME>_SHEET.png
import json
import os
import urllib.request
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
QUEUE = os.path.join(ROOT, "tools", "ach_icon_queue.json")
OUT = os.path.join(ROOT, "_for_review", "ach_icon_alt")
BASE = ("https://backblaze.pixellab.ai/file/pixellab-characters/objects/"
        "c50e1365-1a8c-44be-a773-5ee635581147/{oid}/rotations/frame_{i}.png")


def fetch(api, oid):
    d = os.path.join(OUT, api)
    os.makedirs(d, exist_ok=True)
    frames = []
    for i in range(4):
        p = os.path.join(d, f"frame_{i}.png")
        if not os.path.exists(p):
            try:
                # The CDN rejects urllib's default UA with a 403 - send a real one.
                req = urllib.request.Request(
                    BASE.format(oid=oid, i=i),
                    headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"})
                with urllib.request.urlopen(req, timeout=60) as r, open(p, "wb") as f:
                    f.write(r.read())
            except Exception as e:
                if os.path.exists(p):
                    os.remove(p)
                print(f"  {api}[{i}] not ready: {e}")
                return None
        frames.append(p)
    return frames


def sheet(api, frames):
    s = Image.new("RGBA", (4 * 180, 220), (10, 8, 14, 255))
    d = ImageDraw.Draw(s)
    for i, f in enumerate(frames):
        im = Image.open(f).convert("RGBA").resize((160, 160), Image.NEAREST)
        s.alpha_composite(im, (i * 180 + 10, 20))
        d.text((i * 180 + 75, 190), f"[{i}]", fill=(240, 220, 150))
    d.text((10, 4), api, fill=(220, 215, 230))
    out = os.path.join(OUT, f"_{api}_SHEET.png")
    s.save(out)
    return out


def main():
    if not os.path.exists(QUEUE):
        print("no queue file:", QUEUE)
        return
    q = json.load(open(QUEUE, encoding="utf-8"))
    ok, pending = 0, []
    for api, oid in q.items():
        frames = fetch(api, oid)
        if frames:
            sheet(api, frames)
            ok += 1
        else:
            pending.append(api)
    print(f"sheets built: {ok}")
    if pending:
        print("still rendering:", ", ".join(pending))


if __name__ == "__main__":
    main()
