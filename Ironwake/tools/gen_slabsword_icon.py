# gen_slabsword_icon.py - ORIGINAL "black swordsman" achievement icon for
# ACH_KILLS_100. Hand-drawn slab greatsword silhouette against ember light:
# the archetype (huge blunt-tipped iron slab, wrapped grip) with no borrowed
# character or IP. Zero gen credits - pure PIL. Frame matches
# gen_achievement_icons.py so it drops into the set seamlessly.
import os
from PIL import Image, ImageDraw, ImageFilter, ImageOps, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "_for_review", "ach_icon_alt")
SIZE = 256
GOLD = (138, 113, 58)
BG = (18, 15, 26)


def ember_backdrop():
    """Dark field with a hot ember glow behind the blade."""
    img = Image.new("RGBA", (SIZE, SIZE), BG + (255,))
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    g = ImageDraw.Draw(glow)
    # layered radial embers, hottest at the core
    for r, col in ((96, (120, 30, 12, 170)), (66, (190, 62, 18, 190)),
                   (40, (240, 120, 40, 200)), (22, (255, 190, 110, 210))):
        g.ellipse((SIZE // 2 - r, SIZE // 2 - r + 8,
                   SIZE // 2 + r, SIZE // 2 + r + 8), fill=col)
    glow = glow.filter(ImageFilter.GaussianBlur(18))
    img.alpha_composite(glow)
    return img


def draw_slab_sword(img):
    """A massive slab greatsword, near-black silhouette with a cold rim light."""
    d = ImageDraw.Draw(img)
    cx = SIZE // 2
    dark = (12, 11, 16, 255)
    rim = (150, 158, 178, 255)

    # BLADE: a long iron slab - barely tapered, blunt chisel tip. Kept narrow
    # relative to its length so it reads as a SWORD first, slab second.
    blade = [(cx - 21, 186), (cx - 23, 60), (cx - 17, 32), (cx + 17, 32),
             (cx + 23, 60), (cx + 21, 186)]
    d.polygon(blade, fill=dark)
    # cold rim light down the leading edge, over the tip, and a short return
    d.line([(cx - 22, 184), (cx - 24, 60), (cx - 18, 33)], fill=rim, width=3)
    d.line([(cx - 18, 34), (cx + 18, 34)], fill=rim, width=3)
    d.line([(cx + 22, 40), (cx + 22, 96)], fill=(96, 102, 118, 255), width=2)
    # forge-line down the spine
    d.line([(cx + 4, 46), (cx + 4, 180)], fill=(58, 56, 68, 255), width=2)

    # CROSSGUARD: heavy swept iron bar, wider than the blade by a good margin.
    d.polygon([(cx - 58, 186), (cx + 58, 186), (cx + 50, 202), (cx - 50, 202)],
              fill=dark)
    d.line([(cx - 58, 187), (cx + 58, 187)], fill=rim, width=2)

    # GRIP: wrapped leather with binding ticks.
    d.rectangle([cx - 8, 202, cx + 8, 236], fill=dark)
    for y in range(206, 236, 7):
        d.line([(cx - 8, y), (cx + 8, y - 3)], fill=(58, 50, 44, 255), width=2)
    # POMMEL
    d.ellipse([cx - 13, 232, cx + 13, 248], fill=dark)
    d.arc([cx - 13, 232, cx + 13, 248], 180, 360, fill=rim, width=2)
    return img


def frame(img):
    px = img.load()
    hi, lo, edge = (58, 52, 40, 255), (8, 6, 12, 255), (30, 26, 38, 255)
    for i in range(8):
        for x in range(i, SIZE - i):
            px[x, i] = hi if i < 2 else edge
            px[x, SIZE - 1 - i] = lo if i < 2 else edge
        for y in range(i, SIZE - i):
            px[i, y] = hi if i < 2 else edge
            px[SIZE - 1 - i, y] = lo if i < 2 else edge
    g = GOLD + (255,)
    for x in range(10, SIZE - 10):
        px[x, 10] = g
        px[x, SIZE - 11] = g
    for y in range(10, SIZE - 10):
        px[10, y] = g
        px[SIZE - 11, y] = g
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    icon = frame(draw_slab_sword(ember_backdrop()))
    icon.save(os.path.join(OUT, "ACH_KILLS_100.png"))
    icon.convert("RGB").save(os.path.join(OUT, "ACH_KILLS_100.jpg"), quality=95)
    gray = ImageEnhance.Brightness(ImageOps.grayscale(icon.convert("RGB"))).enhance(0.55)
    gray.convert("RGBA").save(os.path.join(OUT, "ACH_KILLS_100_locked.png"))
    gray.convert("RGB").save(os.path.join(OUT, "ACH_KILLS_100_locked.jpg"), quality=95)
    print("wrote ACH_KILLS_100 (color + locked, png + jpg) ->", OUT)


if __name__ == "__main__":
    main()
