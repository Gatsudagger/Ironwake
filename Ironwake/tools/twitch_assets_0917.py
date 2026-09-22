"""Twitch assets + E_wanderer_companion fix (09-17). Source = social media posts/images/key_art.png
(1456x816 painted key art: red moon, hooded wanderer + pet, lit city). Pure PIL, no generation."""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SM = os.path.join(ROOT, "social media posts")
KEY = Image.open(os.path.join(SM, "images", "key_art.png")).convert("RGBA")
OUT = os.path.join(SM, "twitch"); os.makedirs(OUT, exist_ok=True)
GOLD = (190, 150, 80, 255)
FONT = r"C:\Users\miles\AppData\Local\Microsoft\Windows\Fonts\CinzelDecorative-Bold.ttf"

def ring(im, r_frac=0.975, width=5):
    d = ImageDraw.Draw(im); w, h = im.size; r = min(w, h) / 2 * r_frac
    d.ellipse([w/2 - r, h/2 - r, w/2 + r, h/2 + r], outline=GOLD, width=width)
    return im

def vignette(im, strength=0.35):
    w, h = im.size
    m = Image.new("L", (w, h), 0); d = ImageDraw.Draw(m)
    d.ellipse([-w*0.15, -h*0.15, w*1.15, h*1.15], fill=255)
    m = m.filter(ImageFilter.GaussianBlur(w * 0.12))
    dark = Image.new("RGBA", (w, h), (4, 12, 22, 255))
    inv = ImageChops.invert(m).point(lambda v: int(v * strength))
    return Image.alpha_composite(im, Image.merge("RGBA", (*dark.split()[:3], inv)))

# --- moon disc cut from the key art (center ~ (730,218), r ~ 82) ---
MC, MR = (730, 218), 82
moon = KEY.crop((MC[0]-MR-6, MC[1]-MR-6, MC[0]+MR+6, MC[1]+MR+6))
mm = Image.new("L", moon.size, 0); ImageDraw.Draw(mm).ellipse([6, 6, moon.size[0]-6, moon.size[1]-6], fill=255)
mm = mm.filter(ImageFilter.GaussianBlur(1.2)); moon.putalpha(mm)

def erase_moon(base):
    """Paint sky over the original moon so a relocated/enlarged one never doubles it."""
    sky = base.getpixel((600, 218))
    patch = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(patch).ellipse([MC[0]-MR-10, MC[1]-MR-10, MC[0]+MR+10, MC[1]+MR+10], fill=sky)
    patch = patch.filter(ImageFilter.GaussianBlur(3))
    base.alpha_composite(patch)
    return base

def big_moon(base, center, radius, glow=True):
    """Paste an enlarged moon (with a soft red halo) into `base` at center."""
    base = erase_moon(base)
    m = moon.resize((radius*2, radius*2), Image.LANCZOS)
    if glow:
        g = Image.new("RGBA", (radius*4, radius*4), (0, 0, 0, 0))
        ImageDraw.Draw(g).ellipse([radius*0.7, radius*0.7, radius*3.3, radius*3.3], fill=(255, 90, 60, 120))
        g = g.filter(ImageFilter.GaussianBlur(radius * 0.45))
        base.alpha_composite(g, (int(center[0]-radius*2), int(center[1]-radius*2)))
    base.alpha_composite(m, (int(center[0]-radius), int(center[1]-radius)))
    return base

# =========================================================================
# 1. E_wanderer_companion FIX - same framing (wanderer + city, no moon), rebuilt
#    from the key art so the bottom is painted ground, not a transparent band.
# =========================================================================
e = KEY.crop((380, 130, 1020, 770)).resize((800, 800), Image.LANCZOS)   # 640px square: whole moon in, feet + pet in
e = vignette(e, 0.3); ring(e)
e.save(os.path.join(SM, "profile_pics_designed", "E_wanderer_companion.png"))

# =========================================================================
# 2. TWITCH PROFILE 800x800 - red moon enlarged behind the wanderer + pet.
# =========================================================================
src = KEY.copy()
src = big_moon(src, (700, 205), 150)               # sits above the hill line (~350) over his head
p = src.crop((292, 0, 1108, 816)).resize((800, 800), Image.LANCZOS)
p = vignette(p, 0.35); ring(p)
p.save(os.path.join(OUT, "twitch_profile_800.png"))

# =========================================================================
# 3. TWITCH BANNER 1200x480 - wordmark bottom-left over the dark foreground,
#    wanderer + pet right of center under the enlarged moon (title-screen text
#    treatment: blue glow, deep shadow, ice-blue face).
# =========================================================================
b = KEY.resize((1200, 672), Image.LANCZOS)
MC, MR = (601, 180), 68                                   # original moon in the scaled frame
b = big_moon(b, (601, 180), 92)
b = b.crop((0, 110, 1200, 590))
b = vignette(b, 0.4)
txt = "IRONWAKE"; f = ImageFont.truetype(FONT, 78)
layer = Image.new("RGBA", b.size, (0, 0, 0, 0)); d = ImageDraw.Draw(layer)
bb = d.textbbox((0, 0), txt, font=f); tw, th = bb[2]-bb[0], bb[3]-bb[1]
cy = 262; x0, y0 = 36 - bb[0], cy - th/2 - bb[1]   # left-anchored, above the wanderer's head
glow = Image.new("RGBA", b.size, (0, 0, 0, 0)); ImageDraw.Draw(glow).text((x0, y0), txt, font=f, fill=(60, 120, 200, 255))
glow = glow.filter(ImageFilter.GaussianBlur(14)); glow.putalpha(glow.split()[3].point(lambda v: int(v * 0.9)))
b.alpha_composite(glow)
for dx, dy in ((5, 6), (7, 6)): d.text((x0+dx, y0+dy), txt, font=f, fill=(15, 40, 70, 255))
for dx in (0, 2):              d.text((x0+dx, y0),    txt, font=f, fill=(130, 195, 255, 255))
b.alpha_composite(layer)
b.save(os.path.join(OUT, "twitch_banner_1200x480.png"))
print("wrote", OUT)
