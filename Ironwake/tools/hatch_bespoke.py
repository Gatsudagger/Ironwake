#!/usr/bin/env python
"""Per-egg procedural hatch (M-locked 08-21). Each egg hatches in the language of its own art:
 gilded/fortune  veins   - gold veins light up top-down, shell splits into plates along them
 warding         plates  - plate seams glow, cap pops as separate plates
 ley             runes   - rune rows glow bottom->top, shell splits between rune rows
 scholar         ink     - ink-dark cracks join the freckles, standard pop
 dust            crumble - no cap; shell dissolves from the apex into drifting dust
 savage          violent - early burst, many big shards, cap flung
 tender          gentle  - slow hairline, cap lifts softly, few shards
 vital           pulse   - red vein pulse between the spikes, then burst
 keen            twist   - lid slides at the upper gold band then lifts (hatch_procedural --twist)
9 frames, same canvas as the egg. Usage: hatch_bespoke.py <type> egg.png out_dir"""
import sys, os, random
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hatch_procedural as HP

LIGHT = np.array([255, 244, 205, 255]); GOLD = np.array([255, 225, 140, 255])

def erode(m, iterations=1):
    out = m.copy()
    for _ in range(iterations):
        p = np.pad(out, 1, constant_values=False)
        out = p[1:-1,1:-1] & p[:-2,1:-1] & p[2:,1:-1] & p[1:-1,:-2] & p[1:-1,2:]
    return out

def dilate(m, iterations=1):
    out = m.copy()
    for _ in range(iterations):
        p = np.pad(out, 1, constant_values=False)
        out = p[1:-1,1:-1] | p[:-2,1:-1] | p[2:,1:-1] | p[1:-1,:-2] | p[1:-1,2:]
    return out

def components(m):
    """4-connected labelling -> list of boolean masks (largest first)."""
    H, W = m.shape; lab = np.zeros((H, W), np.int32); n = 0; out = []
    for y0 in range(H):
        for x0 in range(W):
            if m[y0, x0] and lab[y0, x0] == 0:
                n += 1; stack = [(y0, x0)]; lab[y0, x0] = n; px = []
                while stack:
                    y, x = stack.pop(); px.append((y, x))
                    for dy, dx in ((1,0),(-1,0),(0,1),(0,-1)):
                        yy, xx = y+dy, x+dx
                        if 0 <= yy < H and 0 <= xx < W and m[yy, xx] and lab[yy, xx] == 0:
                            lab[yy, xx] = n; stack.append((yy, xx))
                c = np.zeros((H, W), bool); ys, xs = zip(*px); c[list(ys), list(xs)] = True; out.append(c)
    out.sort(key=lambda c: -c.sum()); return out

def erupt(fr, a, m, lines, tt, light, W, H, push=1.0, keep_bottom=0.0, crack_rim=None):
    """Burst that grows OUT of the build-up lines: the lines bloom into light, the shell
    fragments between them separate outward along them and fade, the bloom fills the
    silhouette -> hands off to the full-screen wash. tt = 0..3 (hatch frames 5..8)."""
    grow  = [1, 3, 5, 8][tt]; disp = [2, 6, 11, 17][tt] * push; al = [1.0, 0.9, 0.7, 0.45][tt]
    if crack_rim is not None:
        glow = (dilate(lines & ~crack_rim, grow + 1) | dilate(crack_rim, 1 if tt < 2 else 2)) & m
    else:
        glow = dilate(lines, grow) & m
    frags = components(m & ~dilate(lines, 1))
    ys, xs = np.where(m); cy, cx = ys.mean(), xs.mean(); floor_y = ys.min() + (ys.max() - ys.min()) * (1 - keep_bottom)
    fr[m] = 0
    # interior bloom (stronger each frame), then fragments on top, then the hot lines
    bloom = [0.25, 0.5, 0.75, 0.92][tt]
    base = a.copy(); bm = m.copy()
    if crack_rim is not None:            # bloom only above (and a little below) the rim
        ry = int(np.where(crack_rim)[0].mean()); bm = m & (np.arange(m.shape[0])[:, None] < ry + [2, 5, 9, 14][tt])
    base[bm] = (a[bm] * (1 - bloom) + light * bloom).astype(np.int32); fr[m] = base[m]
    for c in frags:
        fys, fxs = np.where(c); fcy, fcx = fys.mean(), fxs.mean()
        if keep_bottom > 0 and fcy > floor_y:      # lower shell stays put (gentle eggs)
            fr[c] = a[c]; continue
        vx, vy = fcx - cx, fcy - cy; n = max(1.0, (vx*vx + vy*vy) ** 0.5); vx, vy = vx / n, vy / n
        dx, dy = int(round(vx * disp)), int(round(vy * disp - disp * (0.9 if crack_rim is not None else 0.4)))
        for y, x in zip(fys, fxs):
            ny, nx = y + dy, x + dx
            if 0 <= ny < H and 0 <= nx < W:
                px = a[y, x].copy(); px[3] = int(px[3] * al); fr[ny, nx] = px
    k = [1.0, 0.95, 0.9, 0.85][tt]
    fr[glow] = (fr[glow] * (1 - k) + light * k).astype(np.int32); fr[glow, 3] = 255

def feature(t, a, m):
    r, g, b = a[:, :, 0], a[:, :, 1], a[:, :, 2]; mx = a[:, :, :3].max(2)
    inner = erode(m, iterations=2)
    f = {"gilded":  (r > 150) & (g > 110) & (b < 140) & (r - b > 40),
         "fortune": (r > 110) & (r > g) & (g > b) & (r - b > 45),
         "warding": mx < 18, "ley": mx > 140, "scholar": mx < 80, "dust": mx < 55,
         "vital":   (r > 90) & (r - g > 60)}.get(t, np.zeros_like(m))
    return f & inner

def blend(dst, mask, col, k):
    if mask.any(): dst[mask] = (dst[mask] * (1 - k) + col * k).astype(np.int32)

def save(out, frames, W, H):
    os.makedirs(out, exist_ok=True)
    for i, fr in enumerate(frames):
        Image.fromarray(fr.clip(0, 255).astype(np.uint8)).save(os.path.join(out, "f%d.png" % i))
    strip = Image.new("RGBA", (W * 9, H), (30, 28, 34, 255))
    for i in range(9): strip.alpha_composite(Image.open(os.path.join(out, "f%d.png" % i)), (W * i, 0))
    strip.save(os.path.join(out, "strip.png"))

def make_shards(a, top, zig, n, sizes, seed=3, spread=2.6, up=(-4.5, -1.5)):
    rnd = random.Random(seed); tys, txs = np.where(top)
    src = [(x, y) for (y, x) in zip(tys, txs) if y >= zig[x] - 5] or list(zip(txs, tys))
    out = []
    for i in range(n):
        x, y = rnd.choice(src)
        out.append(dict(x=x, y=y, vx=rnd.uniform(-spread, spread), vy=rnd.uniform(*up), c=a[y, x].copy(), sz=rnd.choice(sizes)))
    return out

def draw_shards(fr, shards, t, fade, W, H):
    for s in shards:
        sx = int(round(s["x"] + s["vx"] * t * 3)); sy = int(round(s["y"] + s["vy"] * t * 3 + 1.6 * t * t))
        al = max(0.0, 1.0 - t * fade)
        for dy in range(s["sz"]):
            for dx in range(s["sz"]):
                xx, yy = sx + dx, sy + dy
                if 0 <= xx < W and 0 <= yy < H and al > 0 and fr[yy, xx, 3] == 0:
                    px = s["c"].copy(); px[3] = int(255 * al); fr[yy, xx] = px

def cap_chunks(top, k=3):
    ys, xs = np.where(top); lo, hi = xs.min(), xs.max(); out = []
    for i in range(k):
        c = np.zeros_like(top); a_ = lo + (hi - lo + 1) * i // k; b_ = lo + (hi - lo + 1) * (i + 1) // k
        c[:, a_:b_] = top[:, a_:b_]; out.append(c)
    return out

def lift_cap(fr, a, chunks, lifts, alphas, dxs, H, W):
    for c, lift, al, dx in zip(chunks, lifts, alphas, dxs):
        ys, xs = np.where(c)
        for y, x in zip(ys, xs):
            ny, nx = y - lift, x + dx
            if 0 <= ny < H and 0 <= nx < W:
                px = a[y, x].copy(); px[3] = int(px[3] * al); fr[ny, nx] = px

def rim_light(fr, rim, bot, H, depth=3):
    for (x, y) in rim:
        for dy in range(depth):
            yy = y + dy
            if 0 <= yy < H and bot[yy, x]:
                fr[yy, x] = LIGHT if dy == 0 else (fr[yy, x] * 0.5 + LIGHT * 0.5).astype(np.int32)

def main(t, src, out):
    a = HP.load(src); H, W = a.shape[:2]; m, x0, x1, y0, y1 = HP.egg_mask(a); eggh = y1 - y0
    feat = feature(t, a, m); dark = HP.crack_color(a, m)
    rowidx = np.arange(H)[:, None]
    if t == "ley":
        rows = feat.sum(1)
        gaps = [(int(rows[y:y + 3].sum()), y) for y in range(int(y0 + eggh * 0.25), int(y0 + eggh * 0.55))]
        ys = min(gaps)[1] + 1
        zig = {x: ys for x in range(x0, x1 + 1)}
    else:
        zig = HP.zig_line(x0, x1, int(y0 + eggh * (0.38 if t == "savage" else 0.42)), 7, amp=(6 if t == "savage" else 4))
    top = np.zeros_like(m)
    for x in range(x0, x1 + 1): top[:zig[x], x] = m[:zig[x], x]
    bot = m & ~top
    rim = [(x, zig[x]) for x in range(x0, x1 + 1) if 0 <= zig[x] < H and m[zig[x], x]]
    paths = HP.crack_paths(x0, x1, y0, int(np.mean([y for _, y in rim])), 7)
    ink = np.array([30, 24, 20, 255]); red = np.array([255, 60, 70, 255])
    frames = []
    for f in range(9):
        fr = a.copy()
        if 1 <= f <= 4:
            if t in ("gilded", "fortune"):
                lim = y0 + eggh * [0, 0.3, 0.55, 0.8, 1.0][f]
                blend(fr, feat & (rowidx < lim), GOLD if f < 4 else LIGHT, 0.75)
                if f >= 3:
                    for (x, y) in rim: fr[y, x] = dark
            elif t == "warding":
                lim = y0 + eggh * [0, 0.35, 0.6, 0.85, 1.0][f]
                blend(fr, feat & (rowidx < lim), LIGHT, [0, 0.35, 0.55, 0.8, 1.0][f])
            elif t == "ley":
                lo = y1 - eggh * [0, 0.35, 0.7, 1.0, 1.0][f]
                blend(fr, feat & (rowidx > lo), LIGHT, 0.85)
                if f == 4:
                    for (x, y) in rim: fr[y, x] = LIGHT
            elif t == "savage":
                n = [1, 3, 3, 3][f - 1]
                for p in paths[:n]:
                    for (x, y) in p:
                        if m[y, x]: fr[y, x] = dark
                        if f >= 2 and x + 1 < W and m[y, x + 1]: fr[y, x + 1] = dark
                if f >= 3:
                    for (x, y) in rim: fr[y, x] = LIGHT if f == 4 else dark
                if f == 4:
                    fr[top] = 0; lift_cap(fr, a, [top], [5], [1.0], [0], H, W); rim_light(fr, rim, bot, H, 2)
            elif t == "tender":
                p = paths[0]; n = int(len(p) * [0.3, 0.55, 0.8, 1.0][f - 1])
                for (x, y) in p[:n]:
                    if m[y, x]: fr[y, x] = dark
                if f == 4:
                    for (x, y) in rim: fr[y, x] = (a[y, x] * 0.4 + LIGHT * 0.6).astype(np.int32)
            elif t == "vital":
                k = [0, 0.35, 0.15, 0.55, 0.8][f]
                blend(fr, erode(m, iterations=3), red, k * 0.35)
                blend(fr, feat, LIGHT, k)
                if f >= 2:
                    for p in paths[:f - 1]:
                        for (x, y) in p:
                            if m[y, x]: fr[y, x] = LIGHT if f == 4 else dark
            elif t == "scholar":
                n = [1, 2, 3, 3][f - 1]; frac = [0.6, 1, 1, 1][f - 1]
                for p in paths[:n]:
                    for (x, y) in p[:int(len(p) * frac)]:
                        if m[y, x]: fr[y, x] = ink
                        for dx in (-2, -1, 1, 2):
                            if 0 <= x + dx < W and feat[y, x + dx]: fr[y, x + dx] = ink
                if f >= 3:
                    for (x, y) in rim: fr[y, x] = LIGHT if f == 4 else ink
            elif t == "dust":
                blend(fr, feat, LIGHT, [0, 0.3, 0.5, 0.7, 0.9][f])
                lim = y0 + eggh * [0, 0.06, 0.14, 0.24, 0.36][f]
                rnd = np.random.RandomState(f)
                gone = m & (rowidx < lim) & (rnd.rand(H, W) < [0, 0.5, 0.7, 0.85, 0.95][f])
                fr[gone] = 0
        if f >= 5:
            tt = f - 5
            if t == "dust":
                lim = y0 + eggh * [0.5, 0.62, 0.7, 0.74][tt]
                rnd = np.random.RandomState(10 + f)
                gone = m & (rowidx < lim) & (rnd.rand(H, W) < [0.9, 0.97, 1.0, 1.0][tt])
                fr[gone] = 0
                src_y = min(H - 1, int(lim)); r2 = random.Random(f); pool = a[m]
                for i in range(40):
                    x = r2.randint(x0, x1); y = src_y - r2.randint(0, 14 + tt * 8)
                    if 0 <= y < H and 0 <= x < W and fr[y, x, 3] == 0:
                        c = a[src_y, x] if m[src_y, x] else pool[r2.randrange(len(pool))]
                        px = c.copy(); px[3] = int(255 * max(0.0, 0.9 - tt * 0.25)); fr[y, x] = px
                rim2 = [(x, src_y) for x in range(x0, x1 + 1) if m[src_y, x]]
                rim_light(fr, rim2, m, H, 2 if tt < 3 else 1)
            else:
                # lines the build-up lit = where the light erupts from
                if t in ("gilded", "fortune", "warding"): lines = feat.copy()
                elif t == "ley": lines = feat.copy(); lines[[y for _, y in rim], :] = m[[y for _, y in rim], :]
                else:
                    lines = np.zeros_like(m)
                    for p in paths:
                        for (x, y) in p:
                            if m[y, x]: lines[y, x] = True
                    for (x, y) in rim: lines[y, x] = True
                col = {"vital": np.array([255, 120, 100, 255]), "savage": np.array([255, 205, 160, 255])}.get(t, LIGHT)
                push = {"savage": 1.6, "tender": 0.6, "vital": 1.2}.get(t, 1.0)
                crack_eggs = t in ("savage", "tender", "vital", "scholar")
                rimm = None
                if crack_eggs:
                    rimm = np.zeros_like(m)
                    for (x, y) in rim: rimm[y, x] = True
                erupt(fr, a, m, lines, tt, col, W, H, push=push, keep_bottom=(0.5 if crack_eggs else 0.0), crack_rim=rimm)
                if t == "savage":
                    shards = make_shards(a, top, zig, 26, [2, 3, 3, 4, 4], spread=3.4)
                    draw_shards(fr, shards, tt, 0.22, W, H)
        frames.append(fr)
    save(out, frames, W, H); print("ok", t)

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3])
