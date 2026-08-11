# frame_achievement_icon.py - wrap a loose art PNG in the shipped achievement
# frame and emit the Steam upload set (color + grayscale locked, 256 jpg/png).
# Same frame as gen_achievement_icons.py so hand-picked PixelLab art drops into
# the batch seamlessly.
#
# Usage: python tools\frame_achievement_icon.py <src.png> <ACH_API_NAME>
import os
import sys
from PIL import Image, ImageOps, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "_for_review", "achievement_icons")
SIZE = 256
ART = 208
BG = (18, 15, 26)
GOLD = (138, 113, 58)


def build_frame():
    img = Image.new("RGBA", (SIZE, SIZE), BG + (255,))
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
    src, api = sys.argv[1], sys.argv[2]
    os.makedirs(OUT, exist_ok=True)
    icon = build_frame()
    art = Image.open(src).convert("RGBA")
    bbox = art.getbbox()
    if bbox:
        art = art.crop(bbox)
    w, h = art.size
    scale = min(ART / w, ART / h)
    resample = Image.NEAREST if scale >= 1 else Image.LANCZOS
    art = art.resize((max(1, int(w * scale)), max(1, int(h * scale))), resample)
    icon.alpha_composite(art, ((SIZE - art.width) // 2, (SIZE - art.height) // 2))

    icon.save(os.path.join(OUT, api + ".png"))
    gray = ImageEnhance.Brightness(
        ImageOps.grayscale(icon.convert("RGB"))).enhance(0.55).convert("RGBA")
    gray.save(os.path.join(OUT, api + "_locked.png"))

    for folder, px in (("steam_upload_256", 256), ("steam_upload_64", 64)):
        d = os.path.join(OUT, folder)
        os.makedirs(d, exist_ok=True)
        icon.convert("RGB").resize((px, px), Image.LANCZOS).save(
            os.path.join(d, api + ".jpg"), quality=95)
        gray.convert("RGB").resize((px, px), Image.LANCZOS).save(
            os.path.join(d, api + "_locked.jpg"), quality=95)
    print("framed + exported:", api)


if __name__ == "__main__":
    main()
