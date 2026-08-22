#!/usr/bin/env python
"""Procedural 9-frame egg hatch from ONE static egg png (bottom-origin, no stand).
Shared beat script (M-approved 08-21):
  f0 intact | f1-2 hairline cracks | f3-4 cracks spread, light at seams
  | f5-6 top bursts off (lift + fade), shards fly | f7-8 open lower shell, shards settle/fade.
mode="twist" (Keen): the lid TWISTS at the golden horizontal seam (texture slides sideways
inside the silhouette, seam glows) then lifts off - no cracks.
Usage: hatch_procedural.py egg.png out_dir [--twist] [--split 0.42]"""
import sys, os, random
import numpy as np
from PIL import Image

LIGHT = np.array([255, 244, 205, 255])

def load(p): return np.array(Image.open(p).convert("RGBA")).astype(np.int32)

def egg_mask(a):
    m = a[:, :, 3] > 0; ys, xs = np.where(m); return m, xs.min(), xs.max(), ys.min(), ys.max()

def crack_color(a, m):
    px = a[m][:, :3]; lum = px.mean()
    return np.array([18, 12, 22, 255]) if lum > 110 else np.array([235, 225, 200, 255])

def zig_line(x0, x1, y_split, seed, amp=4, period=6):
    rnd = random.Random(seed); xs = list(range(x0, x1 + 1, period)) + [x1 + 1]
    pts = {xx: y_split + rnd.randint(-amp, amp) for xx in xs}; keys = sorted(pts); out = {}
    for x in range(x0, x1 + 1):
        for i in range(len(keys) - 1):
            if keys[i] <= x <= keys[i + 1]:
                t = (x - keys[i]) / max(1, keys[i + 1] - keys[i])
                out[x] = int(round(pts[keys[i]] * (1 - t) + pts[keys[i + 1]] * t)); break
    return out

def crack_paths(x0, x1, y0, y_split, seed):
    rnd = random.Random(seed); paths = []; cx = (x0 + x1) // 2
    for k in range(3):
        x = cx + rnd.randint(-7, 7); y = y0 + 5 + rnd.randint(0, 5); pts = []
        while y < y_split + 6:
            pts.append((x, y)); y += 1
            if rnd.random() < 0.5: x += rnd.choice([-1, 1])
        paths.append(pts)
    return paths

def seam_row(a, m, y0, y1):
    """Keen: find the strongest gold/yellow row band (the seam) in the middle 60% of the egg."""
    best, by = -1, None
    for y in range(int(y0 + (y1 - y0) * 0.2), int(y0 + (y1 - y0) * 0.8)):
        row = a[y][m[y]]
        if len(row) == 0: continue
        r, g, b = row[:, 0], row[:, 1], row[:, 2]
        gold = ((r > 150) & (g > 110) & (b < 110) & (r > b + 60)).mean()
        if gold > best: best, by = gold, y
    return by

def main(src, out, split_frac=0.42, twist=False, seam=None):
    a = load(src); H, W = a.shape[:2]
    m, x0, x1, y0, y1 = egg_mask(a); eggh = y1 - y0; cx = (x0 + x1) / 2
    dark = crack_color(a, m)
    if twist:
        sy = seam if seam is not None else (seam_row(a, m, y0, y1) or int(y0 + eggh * split_frac))
        zig = {x: sy for x in range(x0, x1 + 1)}
    else:
        y_split = int(y0 + eggh * split_frac); zig = zig_line(x0, x1, y_split, 7)
    top = np.zeros_like(m)
    for x in range(x0, x1 + 1): top[:zig[x], x] = m[:zig[x], x]
    bot = m & ~top
    rim = [(x, zig[x]) for x in range(x0, x1 + 1) if 0 <= zig[x] < H and m[zig[x], x]]
    paths = crack_paths(x0, x1, y0, int(np.mean([y for _, y in rim])), 7)
    rnd = random.Random(3)
    tys, txs = np.where(top); rim_src = [(x, y) for (y, x) in zip(tys, txs) if y >= zig[x] - 4]
    shards = []
    for i in range(16):
        x, y = rnd.choice(rim_src)
        shards.append(dict(x=x, y=y, vx=rnd.uniform(-2.6, 2.6), vy=rnd.uniform(-4.5, -1.5),
                           c=a[y, x].copy(), sz=rnd.choice([2, 2, 3, 3, 4])))
    os.makedirs(out, exist_ok=True)
    for f in range(9):
        fr = a.copy()
        if twist and 1 <= f <= 4:
            # lid twist: texture slides sideways inside the top silhouette, seam lights up
            dx = [0, 4, 8, 13, 18][f]
            for y, x in zip(tys, txs):
                sx = x - dx
                # wrap inside the row's own span so the silhouette is unchanged
                row = np.where(top[y])[0]; lo, hi = row.min(), row.max()
                if sx < lo: sx = hi - (lo - sx - 1)
                fr[y, x] = a[y, sx] if top[y, sx] else a[y, x]
            for (x, y) in rim:
                fr[y, x] = LIGHT if f >= 2 else (a[y, x] * 0.5 + LIGHT * 0.5).astype(np.int32)
        elif not twist and 1 <= f <= 4:
            n = [1, 2, 3, 3][f - 1]; frac = [0.5, 1.0, 1.0, 1.0][f - 1]
            for p in paths[:n]:
                for (x, y) in p[:int(len(p) * frac)]:
                    if 0 <= y < H and 0 <= x < W and m[y, x]: fr[y, x] = dark
            if f >= 3:
                for (x, y) in rim:
                    fr[y, x] = LIGHT if f == 4 else dark
                    if f == 4 and y + 1 < H and m[y + 1, x]: fr[y + 1, x] = dark
        if f >= 5:
            fr[top] = 0
            for (x, y) in rim:
                for dy in range(0, 3 if f < 7 else 1):
                    yy = y + dy
                    if 0 <= yy < H and bot[yy, x]:
                        fr[yy, x] = LIGHT if dy == 0 else (fr[yy, x] * 0.5 + LIGHT * 0.5).astype(np.int32)
            if f in (5, 6):
                lift = 10 if f == 5 else 24; alpha = 1.0 if f == 5 else 0.5
                side = (14 if f == 5 else 22) if twist else 0
                for y, x in zip(tys, txs):
                    nx = x + side; ny = y - lift
                    if 0 <= ny < H and 0 <= nx < W:
                        px = a[y, x].copy(); px[3] = int(px[3] * alpha); fr[ny, nx] = px
            t = f - 5
            for s in shards:
                sx = int(round(s['x'] + s['vx'] * t * 3)); sy = int(round(s['y'] + s['vy'] * t * 3 + 1.6 * t * t))
                al = max(0.0, 1.0 - t * 0.22)
                for ddy in range(s['sz']):
                    for ddx in range(s['sz']):
                        xx, yy = sx + ddx, sy + ddy
                        if 0 <= xx < W and 0 <= yy < H and al > 0 and fr[yy, xx, 3] == 0:
                            px = s['c'].copy(); px[3] = int(255 * al); fr[yy, xx] = px
        Image.fromarray(fr.clip(0, 255).astype(np.uint8)).save(os.path.join(out, f"f{f}.png"))
    strip = Image.new("RGBA", (W * 9, H), (30, 28, 34, 255))
    for f in range(9): strip.alpha_composite(Image.open(os.path.join(out, f"f{f}.png")), (W * f, 0))
    strip.save(os.path.join(out, "strip.png"))

if __name__ == "__main__":
    args = sys.argv[1:]; tw = "--twist" in args
    sp = float(args[args.index("--split") + 1]) if "--split" in args else 0.42
    sm = int(args[args.index("--seam") + 1]) if "--seam" in args else None
    main(args[0], args[1], sp, tw, sm)
