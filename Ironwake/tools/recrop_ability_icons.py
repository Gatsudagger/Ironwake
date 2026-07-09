# Re-crop the v2 ability icons full-bleed (task #14, 2026-07-09).
# The PixelLab 192px candidates carry a white/light margin OUTSIDE their drawn
# frame; the 07-08 import downscaled the whole canvas, so the white edge shows
# inside the game's icon boxes. Fix: detect the frame content bounds (non-white,
# non-transparent), crop to them, then nearest-neighbor downscale to 64px and
# PNG-swap in place (frame PNG + layer PNG, no .yy churn).
#
# Also used for the Blessed Thirst restyle candidate (crop-to-content before
# review) via --crop-only.
import sys
from pathlib import Path
from PIL import Image

PROJ = Path(__file__).resolve().parent.parent


def content_bbox(img: Image.Image, white_thresh: int = 235) -> tuple:
    """Bounding box of pixels that are neither transparent nor near-white."""
    rgba = img.convert("RGBA")
    w, h = rgba.size
    px = rgba.load()
    left, top, right, bottom = w, h, -1, -1
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 16:
                continue
            if r >= white_thresh and g >= white_thresh and b >= white_thresh:
                continue
            if x < left:
                left = x
            if x > right:
                right = x
            if y < top:
                top = y
            if y > bottom:
                bottom = y
    if right < 0:
        raise SystemExit("no content found")
    return (left, top, right + 1, bottom + 1)


def punch_out_white_border(img: Image.Image, white_thresh: int = 225) -> Image.Image:
    """Flood-fill near-white regions connected to the canvas border -> transparent.
    The icon frames have rounded corners; the white canvas peeks through the
    notches even after a rectangular crop. Transparent corners draw as the dark
    UI panel behind the icon, which is the full-bleed look M wants."""
    rgba = img.convert("RGBA")
    w, h = rgba.size
    px = rgba.load()

    def is_white(x, y):
        r, g, b, a = px[x, y]
        return a >= 16 and r >= white_thresh and g >= white_thresh and b >= white_thresh

    stack = [(x, y) for x in range(w) for y in (0, h - 1) if is_white(x, y)]
    stack += [(x, y) for y in range(h) for x in (0, w - 1) if is_white(x, y)]
    seen = set(stack)
    while stack:
        x, y = stack.pop()
        r, g, b, _ = px[x, y]
        px[x, y] = (r, g, b, 0)
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and is_white(nx, ny):
                seen.add((nx, ny))
                stack.append((nx, ny))
    return rgba


def crop_full_bleed(src: Path) -> Image.Image:
    img = Image.open(src)
    box = content_bbox(img)
    out = punch_out_white_border(img.convert("RGBA").crop(box))
    # Verify: no OPAQUE near-white pixel remains anywhere on the border.
    px = out.load()
    w, h = out.size
    bad = 0
    for x in range(w):
        for y in (0, h - 1):
            r, g, b, a = px[x, y]
            if a >= 16 and r >= 225 and g >= 225 and b >= 225:
                bad += 1
    for y in range(h):
        for x in (0, w - 1):
            r, g, b, a = px[x, y]
            if a >= 16 and r >= 225 and g >= 225 and b >= 225:
                bad += 1
    if bad:
        print(f"  WARN {src.name}: {bad} near-white border pixels survived")
    return out


def swap(candidate: Path, sprite: str):
    icon = crop_full_bleed(candidate).resize((64, 64), Image.NEAREST)
    sdir = PROJ / "sprites" / sprite
    targets = [p for p in sdir.rglob("*.png")]
    for t in targets:
        icon.save(t)
    print(f"{sprite}: cropped {candidate.name} -> 64x64 into {len(targets)} png(s)")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--crop-only":
        src, dst = Path(sys.argv[2]), Path(sys.argv[3])
        crop_full_bleed(src).save(dst)
        print(f"cropped {src} -> {dst}")
        sys.exit(0)
    rev = PROJ / "_for_review"
    swap(rev / "ability_blazing_palm_candidate2.png", "spr_ability_blazing_palm")
    swap(rev / "ability_gravewrack_grip_candidate2.png", "spr_ability_gravewrack_grip")
    swap(rev / "ability_soul_rend_candidate2.png", "spr_ability_soul_rend")
