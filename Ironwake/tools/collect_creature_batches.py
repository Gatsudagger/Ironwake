# collect_creature_batches.py - download the 08-06 creature expansion batches.
#
# Each queued object is a 4-frame pack where every frame is a DIFFERENT creature
# (item_descriptions), not four drafts of one. So a sheet here shows 4 species.
#
# Queue: tools\creature_batch_queue.json  { "BATCH_LABEL": "object-uuid", ... }
# Output: _for_review\creatures_0806\<LABEL>\frame_N.png + _<LABEL>_SHEET.png
import json
import os
import urllib.request
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
QUEUE = os.path.join(ROOT, "tools", "creature_batch_queue.json")
OUT = os.path.join(ROOT, "_for_review", "creatures_0806")
BASE = ("https://backblaze.pixellab.ai/file/pixellab-characters/objects/"
        "c50e1365-1a8c-44be-a773-5ee635581147/{oid}/rotations/frame_{i}.png")
UA = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}


def fetch(label, oid):
    d = os.path.join(OUT, label)
    os.makedirs(d, exist_ok=True)
    frames = []
    for i in range(4):
        p = os.path.join(d, f"frame_{i}.png")
        if not os.path.exists(p):
            try:
                req = urllib.request.Request(BASE.format(oid=oid, i=i), headers=UA)
                with urllib.request.urlopen(req, timeout=60) as r, open(p, "wb") as f:
                    f.write(r.read())
            except Exception as e:
                if os.path.exists(p):
                    os.remove(p)
                print(f"  {label}[{i}] not ready: {e}")
                return None
        frames.append(p)
    return frames


def sheet(label, frames):
    names = label.split("_")[1:]
    s = Image.new("RGBA", (4 * 190, 236), (10, 8, 14, 255))
    d = ImageDraw.Draw(s)
    for i, f in enumerate(frames):
        im = Image.open(f).convert("RGBA").resize((170, 170), Image.NEAREST)
        s.alpha_composite(im, (i * 190 + 10, 24))
        d.text((i * 190 + 12, 200), f"[{i}] {names[i] if i < len(names) else ''}",
               fill=(240, 220, 150))
    d.text((10, 6), label, fill=(220, 215, 230))
    out = os.path.join(OUT, f"_{label}_SHEET.png")
    s.save(out)
    return out


def main():
    q = json.load(open(QUEUE, encoding="utf-8"))
    ok, pending = 0, []
    for label, oid in q.items():
        frames = fetch(label, oid)
        if frames:
            sheet(label, frames)
            ok += 1
        else:
            pending.append(label)
    print(f"sheets built: {ok}/{len(q)}")
    if pending:
        print("still rendering:", ", ".join(pending))


if __name__ == "__main__":
    main()
