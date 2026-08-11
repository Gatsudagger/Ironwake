# gen_achievement_icons.py — 63 Steam achievement icons composited from
# existing in-game art (zero gen credits). 256x256, shipped gothic frame style
# (beveled dark border + thin gold inner line, per the icon rules). Each icon
# gets a color (unlocked) and a grayscale _locked variant, plus one contact
# sheet for M's batch review. Output: _for_review\achievement_icons\
#
# Run:  python tools\gen_achievement_icons.py
import os
import glob
from PIL import Image, ImageOps, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES = os.path.join(ROOT, "sprites")
OUT = os.path.join(ROOT, "_for_review", "achievement_icons")

# API name -> source sprite folder (semantic match per the icon rules).
MAPPING = {
    # Onboarding
    "ACH_FIRST_BLOOD":   "spr_ability_strike",
    "ACH_GRAVEBREAKER":  "spr_dungeon_gate",
    "ACH_ITS_ALIVE":     "spr_pet_egg_vital_hatch",
    "ACH_FIRST_LEGEND":  "spr_item_art_crown_hollow_king",
    "ACH_ACQUAINTED":    "spr_pet_bonehound_baby",
    "ACH_REFORGED":      "spr_icon_reforge_ingot_rare",
    # Progression
    "ACH_KILLS_100":     "spr_ability_cleave",
    "ACH_SLAYER":        "spr_ability_killing_spree",
    "ACH_KILLS_1000":    "spr_ability_flurry",
    "ACH_SURVIVOR":      "spr_ability_second_wind",
    "ACH_GOLDHAND":      "spr_icon_gold",
    "ACH_LEGEND":        "spr_item_art_crownfire_diadem",
    "ACH_COLLECTOR":     "spr_icon_trinket_appraisal_lens",
    "ACH_CURATOR":       "spr_icon_trinket_grimoire_page",
    "ACH_FC_DEPTHS":     "spr_dungeon_scorched_depths",
    "ACH_FC_TOMB":       "spr_dungeon_tundra_tomb",
    "ACH_FC_VAULT":      "spr_dungeon_ashen_vault",
    # Combat skill
    "ACH_BOSSES_10":     "spr_bone_colossus",
    "ACH_DUELIST_5":     "spr_item_art_duelists_rebuke",
    "ACH_NO_DAMAGE":     "spr_ability_evasive_roll",
    "ACH_ABSORB_500":    "spr_ability_iron_skin",
    "ACH_CRITS_50":      "spr_ability_snipe",
    "ACH_CRITS_500":     "spr_ability_assassinate",
    "ACH_DETONATE_25":   "spr_ability_rupture",
    # Class mastery
    "ACH_CLR_ARCANIST":  "spr_ability_soulfire",
    "ACH_CLR_BLOOD":     "spr_bloodwarden",
    "ACH_CLR_SHADOW":    "spr_shadowstrider",
    # Dungeon mastery (A5)
    "ACH_FLAMEWALKER":   "spr_infernal_revenant",
    "ACH_TOMBWARDEN":    "spr_eternal_frost",
    "ACH_VAULTBREAKER":  "spr_ashen_colossus",
    # Companions
    "ACH_SPECIES_5":     "spr_pet_egg_gilded",
    "ACH_SPECIES_10":    "spr_pet_egg_ley",
    "ACH_SCION_1":       "spr_pet_crypt_bat_adult_s",
    "ACH_SCION_2":       "spr_pet_cinder_newt_adult_s",
    "ACH_SCION_ADULT":   "spr_pet_bone_stag_adult_s",
    "ACH_SOULBOUND":     "spr_ability_soulbind",
    "ACH_AWAKENER":      "spr_pet_bonehound_adult_e",
    "ACH_CORRUPTED":     "spr_ability_curse",
    "ACH_CORRUPT_ADULT": "spr_ability_plague_touch",
    "ACH_PET_CURE":      "spr_icon_consumable_purification_draught",
    # Town
    "ACH_BELOVED":       "spr_icon_ring_pact",
    "ACH_REMEMBERS":     "spr_ability_throat_slit",
    "ACH_KEPT_WORD":     "spr_icon_amulet_medallion",
    "ACH_PILLAR":        "spr_hub_background",
    "ACH_BOARD_25":      "spr_icon_npc_board",
    # Endgame
    "ACH_ASCENDING":     "spr_floormap_scorched",
    "ACH_AWAKENING_3":   "spr_floormap_tundra",
    "ACH_DEEP_END":      "spr_floormap_ashen",
    "ACH_DESCENT_OPEN":  "spr_dungeon_wraith",
    "ACH_DESCENT_10":    "spr_grave_stalker",
    "ACH_DESCENT_25":    "spr_ice_specter",
    "ACH_DESCENT_50":    "spr_ash_wraith",
    "ACH_DEATHLESS":     "spr_ability_undying",
    "ACH_STANDS":        "spr_item_art_lantern_last_door",
    # Risk
    "ACH_PACT_BOUND":    "spr_ability_sanguine_pact",
    "ACH_CURSES_3":      "spr_event_splash_cursed_idol",
    "ACH_MEGA_CURSE":    "spr_item_art_oathbreakers_shard",
    "ACH_IRON_VOW":      "spr_icon_trait_iron_will",
    # Elaborate / fun
    "ACH_HIGH_ROLLER":   "spr_ability_devils_flip",
    "ACH_BONES":         "spr_item_art_bone_talisman",
    "ACH_BREW":          "spr_icon_consumable_chaotic_brew",
    "ACH_REBIRTH":       "spr_scene_cursed_ritual",
    "ACH_FORGE_LEGEND":  "spr_icon_reforge_ingot_legendary",
    "ACH_WEB_COMPLETE":  "spr_ability_arcane_echo_rings",
    "ACH_BANSHEE":       "spr_icon_banshee_bottle",
    "ACH_SONGS_5":       "spr_banshee_release",
    "ACH_SONGS_ALL":     "spr_icon_trinket_singing_rune",
}

SIZE = 256
ART = 208          # art box inside the frame
BG = (18, 15, 26)  # dark violet-black backing
GOLD = (138, 113, 58)


def sprite_png(folder):
    """First composite png at the sprite folder root (not layers/)."""
    hits = sorted(glob.glob(os.path.join(SPRITES, folder, "*.png")))
    return hits[0] if hits else None


def build_frame():
    """Beveled dark gothic frame matching the shipped Pass-2 icon style."""
    img = Image.new("RGBA", (SIZE, SIZE), BG + (255,))
    px = img.load()
    hi = (58, 52, 40, 255)     # bevel highlight
    lo = (8, 6, 12, 255)       # bevel shadow
    edge = (30, 26, 38, 255)   # frame body
    for i in range(8):
        for x in range(i, SIZE - i):
            px[x, i] = hi if i < 2 else edge
            px[x, SIZE - 1 - i] = lo if i < 2 else edge
        for y in range(i, SIZE - i):
            px[i, y] = hi if i < 2 else edge
            px[SIZE - 1 - i, y] = lo if i < 2 else edge
    # thin gold inner line
    g = GOLD + (255,)
    for x in range(10, SIZE - 10):
        px[x, 10] = g
        px[x, SIZE - 11] = g
    for y in range(10, SIZE - 10):
        px[10, y] = g
        px[SIZE - 11, y] = g
    return img


def compose(src_path):
    icon = build_frame()
    art = Image.open(src_path).convert("RGBA")
    # Trim fully transparent padding so the subject fills the box.
    bbox = art.getbbox()
    if bbox:
        art = art.crop(bbox)
    # Wide scene art (hub bg, floormaps, dungeon cards): center-crop to square
    # first so the subject isn't letterboxed into a sliver.
    w, h = art.size
    if w > h * 1.6 or h > w * 1.6:
        side = min(w, h)
        art = art.crop(((w - side) // 2, (h - side) // 2,
                        (w + side) // 2, (h + side) // 2))
        w, h = art.size
    scale = min(ART / w, ART / h)
    # Pixel art upscales nearest; downsizing large scene art uses LANCZOS.
    resample = Image.NEAREST if scale >= 1 else Image.LANCZOS
    art = art.resize((max(1, int(w * scale)), max(1, int(h * scale))), resample)
    ox = (SIZE - art.width) // 2
    oy = (SIZE - art.height) // 2
    icon.alpha_composite(art, (ox, oy))
    return icon


def locked_variant(icon):
    g = ImageOps.grayscale(icon.convert("RGB"))
    g = ImageEnhance.Brightness(g).enhance(0.55)
    return g.convert("RGBA")


def main():
    os.makedirs(OUT, exist_ok=True)
    made, missing = [], []
    for api, folder in MAPPING.items():
        src = sprite_png(folder)
        if src is None:
            missing.append((api, folder))
            continue
        icon = compose(src)
        icon.save(os.path.join(OUT, api + ".png"))
        locked_variant(icon).save(os.path.join(OUT, api + "_locked.png"))
        made.append(api)

    # Contact sheet (9 columns) for M's one-look batch review.
    if made:
        cols = 9
        rows = (len(made) + cols - 1) // cols
        cell = 140
        sheet = Image.new("RGBA", (cols * cell, rows * (cell + 22)), (10, 8, 14, 255))
        from PIL import ImageDraw
        d = ImageDraw.Draw(sheet)
        for i, api in enumerate(made):
            tile = Image.open(os.path.join(OUT, api + ".png")).resize((128, 128), Image.LANCZOS)
            cx = (i % cols) * cell + 6
            cy = (i // cols) * (cell + 22) + 6
            sheet.alpha_composite(tile, (cx, cy))
            d.text((cx, cy + 130), api.replace("ACH_", ""), fill=(200, 195, 210))
        sheet.save(os.path.join(OUT, "_CONTACT_SHEET.png"))

    print(f"made {len(made)} icons (x2 variants) -> {OUT}")
    if missing:
        print("MISSING sources:")
        for api, folder in missing:
            print(f"  {api}: {folder}")


if __name__ == "__main__":
    main()
