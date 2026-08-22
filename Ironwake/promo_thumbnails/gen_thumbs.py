# NPC + dungeon thumbnail series, same template as the pets Short thumbnail.
# All composited from shipped game assets. 1080x1920 each.
import glob, os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SP = r"C:\Users\miles\AppData\Local\Temp\claude\C--Users-miles-GameMakerProjects-Ironwake\c8dd4b1c-6604-4837-abbd-59a4714d5d90\scratchpad"
SPRITES = r"C:\Users\miles\GameMakerProjects\Ironwake\sprites"
FONTS = os.path.expandvars(r"%LOCALAPPDATA%\Microsoft\Windows\Fonts")
OUTDIR = r"D:\Ironwake Videos\Thumbnails"
os.makedirs(OUTDIR, exist_ok=True)

W, H = 1080, 1920
GOLD = (233, 217, 168, 255)
GOLD_BRIGHT = (255, 244, 200, 255)
cinzel = os.path.join(FONTS, "CinzelDecorative-Bold.ttf")
gara = os.path.join(FONTS, "EBGaramond-VariableFont.ttf")

def frame0(folder):
    files = sorted(glob.glob(os.path.join(SPRITES, folder, "*.png")))
    if not files:
        raise SystemExit("missing sprite: " + folder)
    img = Image.open(files[0]).convert("RGBA")
    bbox = img.getbbox()
    return img.crop(bbox) if bbox else img

def scale_px(img, target_h):
    f = max(1, round(target_h / img.height))
    return img.resize((img.width * f, img.height * f), Image.NEAREST)

def glow(canvas, cx, cy, rx, ry, color, alpha=160):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=color + (alpha,))
    canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(60)))

def stroked(canvas, xy, text, font, fill, stroke=10):
    ImageDraw.Draw(canvas).text(xy, text, font=font, fill=fill, stroke_width=stroke,
                                stroke_fill=(10, 8, 6, 255), anchor="ma")

def backdrop(path_or_sprite, is_sprite=False, blur=11):
    if is_sprite:
        img = frame0(path_or_sprite).convert("RGB")
    else:
        img = Image.open(path_or_sprite).convert("RGB")
        img = img.crop((32, 36, 32 + 1856, 36 + 1044))      # window chrome
    # cover-fill 1080x1920 from center
    scale = max(W / img.width, H / img.height)
    img = img.resize((int(img.width * scale), int(img.height * scale)), Image.LANCZOS)
    x0 = (img.width - W) // 2
    img = img.crop((x0, 0, x0 + W, H)).filter(ImageFilter.GaussianBlur(blur))
    canvas = img.convert("RGBA")
    # top band darkened too, so screen chrome (camp header, carousel arrows)
    # can't read through behind the title text
    shade = Image.new("L", (W, H), 60)
    sd = ImageDraw.Draw(shade)
    for y in range(H):
        a = 60 + int(max(0, (y - 450) / (H - 450)) * 140)
        if y < 450:
            a = 60 + int((450 - y) / 450 * 120)
        sd.line([(0, y), (W, y)], fill=a)
    canvas.alpha_composite(Image.merge("RGBA", [Image.new("L", (W, H), 0)] * 3 + [shade]))
    return canvas

def portrait_panel(canvas, sprite_name, box):
    """Contain-fit painted portrait in box, double gold frame around it."""
    x0, y0, x1, y1 = box
    art = frame0(sprite_name)
    bw, bh = x1 - x0, y1 - y0
    s = min(bw / art.width, bh / art.height)
    art = art.resize((int(art.width * s), int(art.height * s)), Image.LANCZOS)
    px = x0 + (bw - art.width) // 2
    py = y0 + (bh - art.height) // 2
    d = ImageDraw.Draw(canvas)
    d.rectangle([px - 6, py - 6, px + art.width + 6, py + art.height + 6], fill=(12, 14, 24, 255))
    canvas.alpha_composite(art, (px, py))
    d.rectangle([px - 6, py - 6, px + art.width + 6, py + art.height + 6],
                outline=(180, 150, 90, 255), width=6)
    d.rectangle([px - 14, py - 14, px + art.width + 14, py + art.height + 14],
                outline=(90, 70, 40, 255), width=4)

def make_npc(cfg):
    canvas = backdrop(os.path.join(SP, "camp_bg.png"), blur=18)
    portrait_panel(canvas, cfg["portrait"], (210, 470, 870, 1230))
    # NPC pixel sprite, bottom-left, over its glow
    npc = scale_px(frame0(cfg["npc"]), 460)
    glow(canvas, 300, 1420, 260, 250, cfg["glow_npc"])
    canvas.alpha_composite(npc, (300 - npc.width // 2, 1430 - npc.height // 2))
    # thematic icons, bottom-right cluster
    n = len(cfg["icons"])
    glow(canvas, 760, 1440, 280, 240, cfg["glow_icon"])
    # fanned cluster positions per icon count - measured, no overlap crush
    spots = {1: [(760, 1440)], 2: [(670, 1370), (860, 1530)],
             3: [(620, 1340), (900, 1430), (730, 1595)]}[n]
    for (icon, size), (cx, cy) in zip(cfg["icons"], spots):
        ic = scale_px(frame0(icon), size)
        canvas.alpha_composite(ic, (cx - ic.width // 2, cy - ic.height // 2))
    stroked(canvas, (W // 2, 90), cfg["name"], ImageFont.truetype(cinzel, 200), GOLD_BRIGHT, 12)
    stroked(canvas, (W // 2, 330), cfg["role"], ImageFont.truetype(cinzel, 76), GOLD, 8)
    stroked(canvas, (W // 2, 1770), cfg["tag"], ImageFont.truetype(gara, 64), GOLD, 6)
    out = os.path.join(OUTDIR, cfg["file"])
    canvas.convert("RGB").save(out, "PNG")
    print("saved", out)

NPCS = [
    dict(file="thumb_dorn.png", name="DORN", role="THE BLACKSMITH",
         portrait="Blacksmith_1__Dark_Gritty_", npc="spr_npc_dorn_idle",
         icons=[("spr_icon_sword_fire_a", 300)],
         glow_npc=(255, 140, 60), glow_icon=(255, 120, 40),
         tag="TEMPER  \u2022  REFORGE  \u2022  CRAFT"),
    dict(file="thumb_maren.png", name="MAREN", role="THE RUNESMITH",
         portrait="Runesmith_3__Facewrap_", npc="spr_npc_maren_idle",
         icons=[("spr_icon_rune_abyss", 220), ("spr_icon_rune_aether", 220), ("spr_icon_rune_avatar", 220)],
         glow_npc=(140, 110, 255), glow_icon=(120, 150, 255),
         tag="SOCKET  \u2022  COMBINE  \u2022  AWAKEN"),
    dict(file="thumb_sable.png", name="SABLE", role="THE ALCHEMIST",
         portrait="Alcehmist_2__Flirty_", npc="spr_npc_sable_idle",
         icons=[("spr_icon_consumable_master_healing_draught", 225), ("spr_icon_consumable_phoenix_tonic", 225), ("spr_icon_consumable_faeries_tear", 225)],
         glow_npc=(110, 230, 140), glow_icon=(120, 255, 150),
         tag="BREW  \u2022  BOTTLE  \u2022  EMPOWER"),
    dict(file="thumb_petra.png", name="PETRA", role="THE MERCHANT",
         portrait="Merchant_7__Voluptuous_", npc="spr_npc_petra_idle",
         icons=[("spr_icon_gold", 260), ("spr_icon_valuable_sovereigns_signet", 210)],
         glow_npc=(255, 210, 90), glow_icon=(255, 215, 80),
         tag="BUY  \u2022  SELL  \u2022  TRADE"),
    dict(file="thumb_vex.png", name="VEX", role="THE TRAINER",
         portrait="Trainer_2__Sullen_", npc="spr_npc_vex_idle",
         icons=[("spr_ability_arcane_burst", 230), ("spr_ability_assassinate", 230), ("spr_ability_blazing_palm", 230)],
         glow_npc=(220, 90, 90), glow_icon=(255, 110, 110),
         tag="LEARN  \u2022  TRAIN  \u2022  MASTER"),
    dict(file="thumb_vael.png", name="VAEL", role="THE AESTHETE",
         portrait="Aesthete_2__Gothic_", npc="spr_npc_vael_idle",
         icons=[("spr_event_splash_whispering_mirror", 300)],
         glow_npc=(200, 120, 255), glow_icon=(220, 140, 255),
         tag="SKINS  \u2022  PORTRAITS  \u2022  FLAIR"),
]

for cfg in NPCS:
    make_npc(cfg)

# --- combat basics (companion thumb to the combat Short) ----------------------
canvas = backdrop("spr_combatbg_ashen_2", is_sprite=True, blur=6)
arc = scale_px(frame0("spr_arcanist_f"), 560)
skel = scale_px(frame0("spr_skeleton_soldier"), 560)
glow(canvas, 320, 1130, 300, 320, (150, 90, 255), alpha=160)     # caster: arcane violet
glow(canvas, 790, 1130, 300, 320, (170, 210, 160), alpha=130)    # undead: bone pale
canvas.alpha_composite(arc, (320 - arc.width // 2, 1130 - arc.height // 2))
canvas.alpha_composite(skel, (790 - skel.width // 2, 1130 - skel.height // 2))
row = ["spr_ability_soulfire", "spr_ability_void_drain", "spr_ability_arcane_burst", "spr_ability_blink"]
glow(canvas, 540, 1560, 420, 150, (255, 150, 60), alpha=120)
xs = 190
for name in row:
    try:
        ic = scale_px(frame0(name), 190)
        canvas.alpha_composite(ic, (xs - ic.width // 2, 1560 - ic.height // 2))
    except SystemExit:
        pass
    xs += 235
stroked(canvas, (W // 2, 90), "COMBAT", ImageFont.truetype(cinzel, 200), GOLD_BRIGHT, 12)
stroked(canvas, (W // 2, 330), "BASICS", ImageFont.truetype(cinzel, 120), GOLD, 10)
stroked(canvas, (W // 2, 1770), "PREPARE  •  READ  •  STRIKE", ImageFont.truetype(gara, 64), GOLD, 6)
out = os.path.join(OUTDIR, "thumb_combat.png")
canvas.convert("RGB").save(out, "PNG")
print("saved", out)

# --- dungeon / abilities ------------------------------------------------------
canvas = backdrop("spr_combatbg_ashen_1", is_sprite=True, blur=6)
boss = frame0("spr_bone_sovereign_hd")
s = 900 / boss.height
boss = boss.resize((int(boss.width * s), 900), Image.LANCZOS)
glow(canvas, 540, 980, 380, 400, (150, 90, 255), alpha=150)
canvas.alpha_composite(boss, (540 - boss.width // 2, 980 - boss.height // 2))
row = ["spr_ability_arcane_burst", "spr_ability_bear_trap", "spr_ability_bloodfeast", "spr_ability_blink"]
glow(canvas, 540, 1560, 420, 160, (255, 150, 60), alpha=130)
xs = 190
for name in row:
    ic = scale_px(frame0(name), 200)
    canvas.alpha_composite(ic, (xs - ic.width // 2, 1560 - ic.height // 2))
    xs += 235
stroked(canvas, (W // 2, 90), "DUNGEON", ImageFont.truetype(cinzel, 190), GOLD_BRIGHT, 12)
stroked(canvas, (W // 2, 320), "COMBAT", ImageFont.truetype(cinzel, 120), GOLD, 10)
stroked(canvas, (W // 2, 1770), "FIGHT  \u2022  CAST  \u2022  DESCEND", ImageFont.truetype(gara, 64), GOLD, 6)
out = os.path.join(OUTDIR, "thumb_dungeon.png")
canvas.convert("RGB").save(out, "PNG")
print("saved", out)
