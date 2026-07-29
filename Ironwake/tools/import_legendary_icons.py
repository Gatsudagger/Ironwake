#!/usr/bin/env python
"""
Import the 07-28 legendary-icon set (M-approved) + the 3 Sable verb badges.

Sources (finalized picks only):
    _for_review/legendary_icons_v2/  - 15 bare item icons (Batareya pack picks,
                                       themed accessories incl. 2 ember hue-shifts,
                                       and 7 generated bare-art pieces)
    _for_review/sable_badges/        - salvage_sword_15 / scrap_rune_3 /
                                       transmute_gem_2

Images are centered on a 64x64 canvas WITHOUT scaling when they fit (pixel art
stays crisp; runtime draw_sprite_stretched handles display size); larger art is
thumbnailed NEAREST. Reuses gen_trait_icons.build_sprite/register_yyp.
Idempotent (skips existing). GM MUST BE CLOSED. Run from repo root:
    python tools/import_legendary_icons.py
"""
import os, sys
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import uuid
from gen_trait_icons import ROOT, SPRITES, build_sprite, register_yyp, YY_TEMPLATE


def build_sprite_sized(spr_name, img, size):
    """gen_trait_icons.build_sprite clone with a parameterized canvas (splash = 128)."""
    sdir = os.path.join(SPRITES, spr_name)
    frame = str(uuid.uuid4()); layer = str(uuid.uuid4()); kfid = str(uuid.uuid4())
    os.makedirs(os.path.join(sdir, "layers", frame), exist_ok=True)
    img.save(os.path.join(sdir, frame + ".png"))
    img.save(os.path.join(sdir, "layers", frame, layer + ".png"))
    yy = YY_TEMPLATE.format(name=spr_name, frame=frame, layer=layer, kfid=kfid,
                            w=size, h=size, br=size - 1, bb=size - 1)
    with open(os.path.join(sdir, spr_name + ".yy"), "w", newline="\n") as f:
        f.write(yy)

V2     = os.path.join(ROOT, "_for_review", "legendary_icons_v2")
BADGES = os.path.join(ROOT, "_for_review", "sable_badges")

JOBS = [
    # --- legendary item icons (bare art; runtime adds panel + rarity border) ---
    ("spr_icon_legendary_duelists_rebuke",     V2, "01_duelists_rebuke.png"),
    ("spr_icon_legendary_gravewalker_treads",  V2, "02_gravewalker_treads.png"),
    ("spr_icon_legendary_sanguine_chalice",    V2, "03_sanguine_chalice.png"),
    ("spr_icon_legendary_stormcallers_loop",   V2, "04_stormcallers_loop.png"),
    ("spr_icon_legendary_misers_blade",        V2, "05_misers_blade.png"),
    ("spr_icon_legendary_veil_patient_dark",   V2, "06_veil_patient_dark.png"),
    ("spr_icon_legendary_longshots_memory",    V2, "07_longshots_memory.png"),
    ("spr_icon_legendary_aegis_unbroken_line", V2, "08_aegis_unbroken_line.png"),
    ("spr_icon_legendary_hollow_kings_signet", V2, "09_hollow_kings_signet.png"),
    ("spr_icon_legendary_ember_saints_censer", V2, "10_ember_saints_censer.png"),
    ("spr_icon_legendary_oathbreakers_shard",  V2, "11_oathbreakers_shard.png"),
    ("spr_icon_legendary_lantern_last_door",   V2, "12_lantern_last_door.png"),
    ("spr_icon_legendary_crownfire_diadem",    V2, "13_crownfire_diadem.png"),
    ("spr_icon_legendary_beggars_fortune",     V2, "14_beggars_fortune.png"),
    ("spr_icon_legendary_kindled_reliquary",   V2, "15_kindled_reliquary.png"),
    # --- Sable salvage-menu verb badges (drawn ~44px in the phase-0 menu rows) ---
    ("spr_badge_salvage_gear",   BADGES, "salvage_sword_15.png"),
    ("spr_badge_scrap_rune",     BADGES, "scrap_rune_3.png"),
    ("spr_badge_transmute",      BADGES, "transmute_gem_2.png"),
]

SPLASH = os.path.join(ROOT, "_for_review", "legendary_splash")
# 128x128 codex splash art (M-approved 07-28; bow was a 1-gen regen).
SPLASH_JOBS = [
    ("spr_item_art_duelists_rebuke",     "01_duelists_rebuke.png"),
    ("spr_item_art_gravewalker_treads",  "02_gravewalker_treads.png"),
    ("spr_item_art_sanguine_chalice",    "03_sanguine_chalice.png"),
    ("spr_item_art_stormcallers_loop",   "04_stormcallers_loop.png"),
    ("spr_item_art_misers_blade",        "05_misers_blade.png"),
    ("spr_item_art_veil_patient_dark",   "06_veil_patient_dark.png"),
    ("spr_item_art_longshots_memory",    "07_longshots_memory.png"),
    ("spr_item_art_aegis_unbroken_line", "08_aegis_unbroken_line.png"),
    ("spr_item_art_hollow_kings_signet", "09_hollow_kings_signet.png"),
    ("spr_item_art_ember_saints_censer", "10_ember_saints_censer.png"),
    ("spr_item_art_oathbreakers_shard",  "11_oathbreakers_shard.png"),
    ("spr_item_art_lantern_last_door",   "12_lantern_last_door.png"),
    ("spr_item_art_crownfire_diadem",    "13_crownfire_diadem.png"),
    ("spr_item_art_beggars_fortune",     "14_beggars_fortune.png"),
    ("spr_item_art_kindled_reliquary",   "15_kindled_reliquary.png"),
]


def to_canvas(img):
    """Center on a 64x64 canvas; shrink NEAREST only when the art exceeds it."""
    if img.width > 64 or img.height > 64:
        img.thumbnail((64, 64), Image.NEAREST)
    canvas = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    canvas.paste(img, ((64 - img.width) // 2, (64 - img.height) // 2), img)
    return canvas


def main():
    names = []
    for spr_name, folder, src in JOBS:
        if os.path.isdir(os.path.join(SPRITES, spr_name)):
            print("skip (exists):", spr_name)
            continue
        img = Image.open(os.path.join(folder, src)).convert("RGBA")
        build_sprite(spr_name, to_canvas(img))
        names.append(spr_name)
        print("built", spr_name, "<-", src)
    # Codex splash art (128x128, no padding needed - generated at size).
    for spr_name, src in SPLASH_JOBS:
        if os.path.isdir(os.path.join(SPRITES, spr_name)):
            print("skip (exists):", spr_name)
            continue
        img = Image.open(os.path.join(SPLASH, src)).convert("RGBA")
        if img.size != (128, 128):
            img = img.resize((128, 128), Image.NEAREST)
        build_sprite_sized(spr_name, img, 128)
        names.append(spr_name)
        print("built", spr_name, "<-", src)
    n = register_yyp(names)
    print("registered %d new sprites in .yyp (of %d built)" % (n, len(names)))


if __name__ == "__main__":
    main()
