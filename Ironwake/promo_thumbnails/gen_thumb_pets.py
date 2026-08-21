# Thumbnail for the Ironwake pets Short - composited from game assets only.
# 1080x1920 vertical. Pixel sprites upscaled NEAREST to stay crisp.
import glob, os
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

SP = r"C:\Users\miles\AppData\Local\Temp\claude\C--Users-miles-GameMakerProjects-Ironwake\c8dd4b1c-6604-4837-abbd-59a4714d5d90\scratchpad"
SPRITES = r"C:\Users\miles\GameMakerProjects\Ironwake\sprites"
FONTS = os.path.expandvars(r"%LOCALAPPDATA%\Microsoft\Windows\Fonts")
OUT = r"D:\Ironwake Videos\Ironwake Pets Short v2 - thumbnail.png"

W, H = 1080, 1920
GOLD = (233, 217, 168, 255)

def sprite_frame(folder):
    """First animation frame of a GM sprite (UUID pngs at folder root)."""
    files = sorted(glob.glob(os.path.join(SPRITES, folder, "*.png")))
    img = Image.open(files[0]).convert("RGBA")
    return img.crop(img.getbbox())  # trim padded canvas to visible content

def scale_px(img, target_h):
    """Nearest-neighbor upscale, integer factor where possible, pixel-crisp."""
    f = max(1, round(target_h / img.height))
    return img.resize((img.width * f, img.height * f), Image.NEAREST)

def glow(canvas, cx, cy, rx, ry, color, alpha=110):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=color + (alpha,))
    layer = layer.filter(ImageFilter.GaussianBlur(60))
    canvas.alpha_composite(layer)

def stroked_text(canvas, xy, text, font, fill, stroke=8, anchor="ma"):
    d = ImageDraw.Draw(canvas)
    d.text(xy, text, font=font, fill=fill, stroke_width=stroke,
           stroke_fill=(10, 8, 6, 255), anchor=anchor)

# --- background: title screen, chrome-stripped, center 9:16 crop -------------
bg = Image.open(os.path.join(SP, "title_bg.png")).convert("RGB")
bg = bg.crop((32, 36, 32 + 1856, 36 + 1044))          # window chrome + letterbox
cw = int(1044 * W / H)                                  # 9:16 slice width (587)
cx0 = (1856 - cw) // 2
bg = bg.crop((cx0, 0, cx0 + cw, 1044)).resize((W, H), Image.LANCZOS)
# soft-focus the backdrop so the title screen's own text/menu dissolves into
# atmosphere (moon + skyline still read), then darken toward the bottom
bg = bg.filter(ImageFilter.GaussianBlur(11))
canvas = bg.convert("RGBA")
shade = Image.new("L", (W, H), 40)
sd = ImageDraw.Draw(shade)
for y in range(H):
    a = 40 + int(max(0, (y - 450) / (H - 450)) * 150)   # gradient down
    sd.line([(0, y), (W, y)], fill=a)
canvas.alpha_composite(Image.merge("RGBA", [Image.new("L", (W, H), 0)] * 3 + [shade]))

# --- creatures ----------------------------------------------------------------
voidkit = sprite_frame("spr_pet_voidkit_baby_s")
wyrm    = sprite_frame("spr_pet_wyrmling_adult_s")
egg     = sprite_frame("spr_pet_egg_dust")

wyrm_big = scale_px(wyrm, 760)
void_big = scale_px(voidkit, 480)
egg_big  = scale_px(egg, 300)

# glows first (behind sprites): cold blue for the awakened, warm for the kit,
# violet for the egg - the game's own palette language
glow(canvas, 700, 1010, 340, 340, (90, 140, 255), alpha=165)
glow(canvas, 300, 1260, 270, 250, (255, 180, 90), alpha=150)
glow(canvas, 540, 1560, 210, 180, (170, 110, 255), alpha=165)

canvas.alpha_composite(wyrm_big, (700 - wyrm_big.width // 2, 1010 - wyrm_big.height // 2))
canvas.alpha_composite(void_big, (300 - void_big.width // 2, 1265 - void_big.height // 2))
canvas.alpha_composite(egg_big,  (540 - egg_big.width // 2, 1560 - egg_big.height // 2))

# --- text ---------------------------------------------------------------------
cinzel = os.path.join(FONTS, "CinzelDecorative-Bold.ttf")
gara   = os.path.join(FONTS, "EBGaramond-VariableFont.ttf")
f_top  = ImageFont.truetype(cinzel, 148)
f_pets = ImageFont.truetype(cinzel, 220)
f_sub  = ImageFont.truetype(gara, 66)

stroked_text(canvas, (W // 2, 130), "DUNGEON", f_top, GOLD, stroke=10)
stroked_text(canvas, (W // 2, 300), "PETS", f_pets, (255, 244, 200, 255), stroke=12)
stroked_text(canvas, (W // 2, 1770), "HATCH  \u2022  RAISE  \u2022  CORRUPT", f_sub, GOLD, stroke=6)

canvas.convert("RGB").save(OUT, "PNG")
print("saved", OUT, canvas.size)
print("sprite sizes:", voidkit.size, wyrm.size, egg.size)
