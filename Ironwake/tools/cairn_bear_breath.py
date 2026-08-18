"""Cairn bear ADULT idle v4 (08-17): "slow exhale of body heat" at 20 fps - 0 gens.
Body = PixelLab v1 roll: the approved still (rest) and its frame 5 (a real whole-body heave,
mouth closed); in-betweens = short pixel dissolves so the heave tweens instead of popping
(M rejected my row-shift rise: "top half stretched away"). Exhale = procedural pale cloud
rendered PER FRAME (1 px drift/frame, growth, stable holes that thin out, alpha fade).
Same frames feed _s and _e (M rule). Writes _v3_breath/adult_s_ANIM_i.png + PREVIEW.gif +
STRIP.png; --import rebuilds both sprites at FPS (pet_anim_frame honours fps > 8)."""
import os, sys, math
from PIL import Image, ImageDraw
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SP = os.path.join(ROOT, "_for_review", "species_ff_0817", "cairn_bear")
STILL = os.path.join(SP, "adult_s_r1_15.png")
RAISED = os.path.join(SP, "_v1_breath", "adult_s_ANIM_5.png")   # PixelLab heave, mouth closed
OUT = os.path.join(SP, "_v3_breath")
FIN = os.path.join(SP, "_FINAL_ANIMS")
FPS = 20
NOSE = (56.0, 29.5)      # just right of the nose tip in the still
RAISED_NOSE_DY = -2.0    # the heave lifts the head ~2px
CORE = (236, 241, 244); EDGE = (196, 208, 218)

# timeline in frames @ FPS
REST_A, INHALE, HOLD, EXHALE, REST_B = 12, 5, 9, 22, 8
DISSOLVE_OUT = 5          # raised -> rest during the first exhale frames

def ease(t): return t * t * (3 - 2 * t)

def dissolve(a, b, t):
    """Cross-fade a->b (t 0..1). Alpha-blended in-betweens: at 20 fps the 4-5 blended frames
    read as motion, not as a pop. (An ordered-dither dissolve was tried: screen-door glitch.)"""
    return Image.blend(a, b, t)

def h01(i, j):
    v = math.sin(i * 12.9898 + j * 78.233) * 43758.5453
    return v - math.floor(v)

def cloud(im, t, ndy=0.0):
    """t in [0,1): puff at the nose -> swells -> drifts up/right -> thins to wisps -> gone."""
    e = ease(t)
    cx = NOSE[0] + 0.5 + 4.2 * e            # drift right (canvas ends at x=63)
    cy = NOSE[1] + ndy - 1.0 - 12.5 * e      # drift up
    grow = min(1.0, t / 0.45)
    rx = 1.1 + 2.5 * math.sin(grow * math.pi / 2)          # 1.1 -> 3.6
    ry = 0.9 + 2.2 * math.sin(grow * math.pi / 2)          # 0.9 -> 3.1
    if t > 0.6: rx += 0.6 * (t - 0.6); ry += 0.4 * (t - 0.6)   # loosens as it disperses
    alpha = 250 if t < 0.35 else int(250 - 200 * ((t - 0.35) / 0.65) ** 1.1)
    thin = 0.0 if t < 0.4 else 0.9 * ((t - 0.4) / 0.6) ** 1.3   # fraction of pixels dropped
    out = im.copy(); px = out.load(); W, H = out.size
    icx, icy = int(round(cx)), int(round(cy))
    for y in range(int(cy - ry - 1), int(cy + ry + 2)):
        for x in range(int(cx - rx - 1), int(cx + rx + 2)):
            if not (0 <= x < W and 0 <= y < H): continue
            d = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
            if d >= 1.0: continue
            if h01(x - icx, y - icy) < thin: continue          # holes stable relative to the cloud
            core = d < 0.5
            col = CORE if core else EDGE
            al = alpha if core else int(alpha * 0.7)
            r, g, b, a0 = px[x, y]
            if a0 == 0: px[x, y] = col + (al,)
            else:
                k = al / 255.0
                px[x, y] = (int(r + (col[0] - r) * k), int(g + (col[1] - g) * k), int(b + (col[2] - b) * k), 255)
    return out

def build():
    still = Image.open(STILL).convert("RGBA"); raised = Image.open(RAISED).convert("RGBA")
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT): os.remove(os.path.join(OUT, f))
    frames, labels = [], []
    for _ in range(REST_A): frames.append(still.copy()); labels.append("rest")
    for i in range(INHALE):
        frames.append(dissolve(still, raised, ease((i + 1) / (INHALE + 1)))); labels.append("in")
    for _ in range(HOLD): frames.append(raised.copy()); labels.append("hold")
    for i in range(EXHALE):
        if i < DISSOLVE_OUT:
            tb = ease((i + 1) / (DISSOLVE_OUT + 1)); body = dissolve(raised, still, tb); ndy = RAISED_NOSE_DY * (1 - tb)
        else:
            body = still.copy(); ndy = 0.0
        frames.append(cloud(body, i / EXHALE, ndy)); labels.append("ex%d" % i)
    for _ in range(REST_B): frames.append(still.copy()); labels.append("rest")
    for i, im in enumerate(frames): im.save(os.path.join(OUT, "adult_s_ANIM_%d.png" % i))
    S = 4; W = 64 * S
    big = [Image.new("RGBA", (W, W), (60, 60, 68, 255)) for _ in frames]
    for b, im in zip(big, frames): b.alpha_composite(im.resize((W, W), Image.NEAREST))
    big[0].save(os.path.join(OUT, "PREVIEW.gif"), save_all=True, append_images=big[1:], duration=int(1000 / FPS), loop=0, disposal=2)
    n = len(frames); cols = 8; rows = (n + cols - 1) // cols
    strip = Image.new("RGBA", (W * cols, (W + 14) * rows), (60, 60, 68, 255)); dr = ImageDraw.Draw(strip)
    for i, b in enumerate(big):
        x, y = (i % cols) * W, (i // cols) * (W + 14)
        strip.alpha_composite(b, (x, y + 14)); dr.text((x + 2, y), "%d %s" % (i, labels[i]), fill=(255, 255, 0, 255))
    strip.save(os.path.join(OUT, "STRIP.png"))
    print("built", n, "frames @", FPS, "fps =", round(n / FPS, 2), "s ->", OUT)
    return frames

def do_import(frames):
    import shutil
    sys.path.insert(0, os.path.join(ROOT, "tools")); import gm_import
    for d in ("s", "e"):
        gm_import.build_anim_sprite("spr_pet_cairn_bear_adult_%s" % d, frames, fps=FPS)
        print("rebuilt spr_pet_cairn_bear_adult_%s (%d frames @ %d fps)" % (d, len(frames), FPS))
    os.makedirs(FIN, exist_ok=True)
    for d in ("s", "e"):
        shutil.copy(os.path.join(OUT, "PREVIEW.gif"), os.path.join(FIN, "cairn_bear_adult_%s.gif" % d))
        shutil.copy(os.path.join(OUT, "STRIP.png"), os.path.join(FIN, "cairn_bear_adult_%s_frames.png" % d))
    # species-folder frames (what import_species_ff_0817.py would rebuild from) + pinned dup
    import glob
    for f in glob.glob(os.path.join(SP, "adult_[se]_ANIM_*.png")): os.remove(f)
    for d in ("s", "e"):
        for i, im in enumerate(frames): im.save(os.path.join(SP, "adult_%s_ANIM_%d.png" % (d, i)))
        frames[0].save(os.path.join(SP, "adult_%s_ANIM_%d.png" % (d, len(frames))))

if __name__ == "__main__":
    fr = build()
    if "--import" in sys.argv: do_import(fr)
