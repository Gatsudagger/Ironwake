# Build all Steam graphical assets from the approved key-art master.
# Masters (committed): tools/steam/art/ - key_art_master.png (1456x816 MidJourney
# composite, hero + companion; companion transplanted from key_art_companion_source),
# lantern_icon_master.png (app icon). Logo: IRONWAKE in Cinzel Decorative Bold (OFL).
# Output: _for_review/steam_capsules/ (gitignored - regenerate any time).
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageEnhance
import os

IRONWAKE = r"C:\Users\miles\GameMakerProjects\Ironwake"
ART = os.path.join(IRONWAKE, r"tools\steam\art")
MASTER = os.path.join(ART, "key_art_master.png")
OUT = os.path.join(IRONWAKE, r"_for_review\steam_capsules")
FONT_BOLD = r"C:\Asset_Library\Fonts\_steam_font_swap\CinzelDecorative-Bold.ttf"
FONT_REG = r"C:\Asset_Library\Fonts\_steam_font_swap\CinzelDecorative-Regular.ttf"
os.makedirs(OUT, exist_ok=True)

master = Image.open(MASTER).convert("RGB")
MW, MH = master.size  # 1456 x 816


def render_text_layer(text, font_path, size, tracking=0.10,
                      fill=(240, 231, 216), stroke=(14, 22, 34)):
    """Render letterspaced text -> (RGBA layer, tight-cropped)."""
    font = ImageFont.truetype(font_path, size)
    track = int(size * tracking)
    stroke_w = max(2, size // 22)
    widths = [font.getlength(c) for c in text]
    total_w = int(sum(widths)) + track * (len(text) - 1) + stroke_w * 2 + 20
    total_h = int(size * 1.6)
    layer = Image.new("RGBA", (total_w, total_h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x = stroke_w + 10
    y = int(size * 0.15)
    for c, w in zip(text, widths):
        d.text((x, y), c, font=font, fill=fill + (255,),
               stroke_width=stroke_w, stroke_fill=stroke + (255,))
        x += w + track
    # vertical parchment gradient through the glyph fill (not the stroke)
    grad = Image.new("L", (1, total_h))
    for gy in range(total_h):
        grad.putpixel((0, gy), int(255 - 60 * gy / total_h))
    grad = grad.resize((total_w, total_h))
    tint = Image.new("RGBA", layer.size, fill + (255,))
    dark_tint = Image.new("RGBA", layer.size, tuple(int(v * 0.78) for v in fill) + (255,))
    graded = Image.composite(tint, dark_tint, grad)
    glyphs = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    d2 = ImageDraw.Draw(glyphs)
    x = stroke_w + 10
    for c, w in zip(text, widths):
        d2.text((x, y), c, font=font, fill=(255, 255, 255, 255))
        x += w + track
    layer.paste(graded, (0, 0), glyphs)
    return layer.crop(layer.getbbox())


def with_shadow(layer, blur=6, dy=5, alpha=180):
    """Add soft drop shadow behind an RGBA layer."""
    pad = blur * 3
    out_l = Image.new("RGBA", (layer.width + pad * 2, layer.height + pad * 2 + dy),
                      (0, 0, 0, 0))
    sh = Image.new("RGBA", out_l.size, (0, 0, 0, 0))
    a = layer.split()[3].point(lambda v: min(v, alpha))
    black = Image.new("RGBA", layer.size, (5, 8, 14, 255))
    sh.paste(black, (pad, pad + dy), a)
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    out_l.alpha_composite(sh)
    out_l.alpha_composite(layer, (pad, pad))
    return out_l


# Pre-render logo at high res, scale down per use. (Tagline removed per M 07-14.)
LOGO_BASE = with_shadow(render_text_layer("IRONWAKE", FONT_BOLD, 220), blur=10, dy=8)


def place(img, layer_base, cx, cy, width):
    """Alpha-composite a scaled layer centered at (cx, cy)."""
    s = width / layer_base.width
    lyr = layer_base.resize((int(layer_base.width * s), int(layer_base.height * s)),
                            Image.LANCZOS)
    img.alpha_composite(lyr, (int(cx - lyr.width / 2), int(cy - lyr.height / 2)))


def crop_resize(box, size, sharpen=False):
    im = master.crop(box).resize(size, Image.LANCZOS)
    if sharpen:
        im = im.filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))
    return im.convert("RGBA")


def save(img, name):
    img.convert("RGB").save(os.path.join(OUT, name), quality=95)
    print(name, img.size)


# ---- 1. Main capsule 1232x706 (store page top) ----
im = crop_resize((16, 0, 1440, 816), (1232, 706))
place(im, LOGO_BASE, 616, 340, 660)
save(im, "main_capsule_1232x706.png")

# ---- 2. Header capsule 920x430 ----
im = crop_resize((0, 90, 1456, 770), (920, 430))
place(im, LOGO_BASE, 460, 215, 520)
save(im, "header_capsule_920x430.png")

# ---- 3. Small capsule 462x174 (Steam: logo must NEARLY FILL it) ----
im = crop_resize((0, 160, 1456, 708), (462, 174))
place(im, LOGO_BASE, 231, 87, 440)
save(im, "small_capsule_462x174.png")

# ---- 4. Vertical capsule 748x896 ----
im = crop_resize((388, 0, 1069, 816), (748, 896))
place(im, LOGO_BASE, 374, 95, 620)
save(im, "vertical_capsule_748x896.png")

# ---- 5. Library capsule 600x900 (logo upper third) ----
im = crop_resize((456, 0, 1000, 816), (600, 900))
place(im, LOGO_BASE, 300, 95, 520)
save(im, "library_capsule_600x900.png")

# ---- 6. Library hero 3840x1240 (NO logo). v3: moon/hills band — Steam's
#         text/logo detector kept false-positiving on the town window
#         clusters (v1 sharp, v2 dimmed: both rejected), so no town at all.
from PIL import ImageChops
im6 = master.crop((0, 30, 1456, 500))
# kill any remaining warm specks at the valley edge
r6, g6, b6 = im6.split()
warm = ImageChops.subtract(r6, b6).point(lambda v: 255 if v > 35 else 0)
bright = r6.point(lambda v: 255 if v > 110 else 0)
lm = ImageChops.multiply(warm, bright)
# spare the moon itself (big warm disc is fine; it's not text-like)
moon_guard = Image.new("L", im6.size, 255)
ImageDraw.Draw(moon_guard).ellipse([610, 80, 870, 320], fill=0)
lm = ImageChops.multiply(lm, moon_guard)
lm = lm.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(3))
soft = ImageEnhance.Brightness(im6).enhance(0.6)
soft = ImageEnhance.Color(soft).enhance(0.6).filter(ImageFilter.GaussianBlur(1.5))
im6 = Image.composite(soft, im6, lm)
im = im6.resize((3840, 1240), Image.LANCZOS).convert("RGBA")
save(im, "library_hero_3840x1240.png")

# ---- 6b. Page background 1438x810 (ambient, no logo; Steam tints/fades it) ----
im = master.crop((9, 3, 1447, 813))
im = ImageEnhance.Contrast(im).enhance(0.92)
im = ImageEnhance.Brightness(im).enhance(0.92)
im.save(os.path.join(OUT, "page_background_1438x810.png"), quality=95)
print("page_background_1438x810.png", im.size)

# ---- 7. Library logo (transparent, ~1280w) ----
s = 1280 / LOGO_BASE.width
logo = LOGO_BASE.resize((1280, int(LOGO_BASE.height * s)), Image.LANCZOS)
logo.save(os.path.join(OUT, "library_logo_1280.png"))
print("library_logo_1280.png", logo.size)

# ---- 8. App icons: M's MidJourney lantern gen #2, tight crop + glow punch
#         (picked over hero/pet/rimefox variants, M 07-14) ----
lant = Image.open(os.path.join(ART, "lantern_icon_master.png")).convert("RGB")
lant = lant.crop((280, 60, 760, 960))
lw, lh = lant.size
side = max(lw, lh)
sq = Image.new("RGB", (side, side), (10, 14, 20))
sq.paste(lant, ((side - lw) // 2, (side - lh) // 2))
sq = ImageEnhance.Color(sq).enhance(1.18)
sq = ImageEnhance.Contrast(sq).enhance(1.10)
glow = sq.point(lambda v: max(0, v - 140) * 2)
glow = glow.filter(ImageFilter.GaussianBlur(side * 0.02))
sq = Image.blend(sq, ImageChops.screen(sq, glow), 0.55)
vig = Image.new("L", (side, side), 0)
ImageDraw.Draw(vig).ellipse([-side * 0.25, -side * 0.25,
                             side * 1.25, side * 1.25], fill=255)
vig = vig.filter(ImageFilter.GaussianBlur(side * 0.12))
sq = Image.composite(sq, ImageEnhance.Brightness(sq).enhance(0.55), vig)
# Steam Client Images spec: Shortcut Icon = PNG 256/512 (or ICO >=256);
# App Icon = 184x184 JPG (or auto-generated from the shortcut icon).
sq.resize((512, 512), Image.LANCZOS).save(os.path.join(OUT, "app_icon_512.png"))
sq.resize((184, 184), Image.LANCZOS).save(os.path.join(OUT, "app_icon_184.png"))
sq.resize((184, 184), Image.LANCZOS).save(os.path.join(OUT, "app_icon_184.jpg"),
                                          quality=95)
sq.resize((32, 32), Image.LANCZOS).save(os.path.join(OUT, "app_icon_32.png"))
sq.resize((256, 256), Image.LANCZOS).save(os.path.join(OUT, "app_icon_256.ico"),
                                          sizes=[(256, 256)])
print("app icons done")

# Contact sheet for M's review (all capsules on one image)
names = ["main_capsule_1232x706.png", "header_capsule_920x430.png",
         "small_capsule_462x174.png", "vertical_capsule_748x896.png",
         "library_capsule_600x900.png"]
thumbs = [Image.open(os.path.join(OUT, n)) for n in names]
sheet_w = 1300
ys, x_pad = 10, 10
total_h = sum(int(t.height * min(1, (sheet_w - 20) / t.width)) + 30 for t in thumbs) + 20
sheet = Image.new("RGB", (sheet_w, total_h), (24, 26, 32))
for t in thumbs:
    sc = min(1, (sheet_w - 20) / t.width)
    tt = t.resize((int(t.width * sc), int(t.height * sc)))
    sheet.paste(tt, (x_pad, ys))
    ys += tt.height + 30
sheet.save(os.path.join(OUT, "_contact_sheet.png"))
print("contact sheet done")
