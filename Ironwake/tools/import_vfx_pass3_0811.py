#!/usr/bin/env python
"""
VFX pass 3 (08-11): style consolidation. With the full Gigapack purchased,
11 of the round-1 Willibab picks get rebuilt IN PLACE from unTied art (same
artist as the game's shipped VFX). M deferred pick choices to Claude;
comparison sheet: _for_review/vfx_diversity_0811/PROPOSAL_PASS3.png.

Kept from round 1 (better fit than any unTied candidate):
  spr_vfx_poison2 (Willibab acid mound - unTied status_poison too sparse),
  spr_vfx_shield2 (Willibab pulse dome - spell_buff arrows read stat-up),
  spr_vfx_wardflash (Willibab lavender bloom - spell_sleep is literally Zzz).
NOT touched: fire2's explosion avoids epic_explosion_001 (already rage/boom).

All rebuilds keep their yyp registration (names unchanged). Bursts stay square
or wider-than-tall - the combat Draw normalizes scale by WIDTH only, so a
tall-narrow sprite would draw oversized (why directional_fire_burst lost to
fire_looping for Scorch).

Run from repo root with GameMaker CLOSED:
    python tools/import_vfx_pass3_0811.py
"""
import os, sys, shutil

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_trait_icons import SPRITES
from import_combat_vfx_0729 import gm_running
from import_vfx_upgrade_0811 import build_vfx_sprite_wh, load_frames_native

GIG = r"C:\Asset_Library\effects\Super Pixel Effects Gigapack v2.8.0\Super Pixel Effects Gigapack\PNG"

# sprite name -> (effect path under PNG/, frame cap)
SWAPS = {
    "spr_vfx_fire2":       ("Explosions/stylized_explosion_002/stylized_explosion_002_large_orange", 10),
    "spr_vfx_scorch":      ("Fire/fire_looping_001/fire_looping_001_large_orange", 12),
    "spr_vfx_frost2":      ("Fantasy Spells/spell_ice_001/spell_ice_001_large_blue", 14),
    "spr_vfx_shock2":      ("Lightning/lightning_burst_003/lightning_burst_003_large_yellow", 10),
    "spr_vfx_shockstrike": ("Lightning/lightning_strike_002A/lightning_strike_002A_large_yellow", 7),
    "spr_vfx_arcane2":     ("Fantasy Spells/spell_dispel_001/spell_dispel_001_large_violet", 14),
    "spr_vfx_blood2":      ("Splatters/burst_splatter_003/burst_splatter_003_large_red", 8),
    "spr_vfx_heal2":       ("Fantasy Spells/spell_heal_002/spell_heal_002_large_green", 14),
    "spr_vfx_gain2":       ("Sci-fi/scifi_charge_up_002/scifi_charge_up_002_large_violet", 12),
    "spr_vfx_buff2":       ("Fantasy Spells/spell_attack_up_001/spell_attack_up_001_large_red", 12),
    "spr_vfx_spikes":      ("Impacts/symmetrical_impact_003/symmetrical_impact_003_large_white", 7),
}


def main():
    if gm_running():
        sys.exit("ABORT: GameMaker is running - close it first.")

    print("VFX pass 3 (11 in-place rebuilds, unTied style consolidation, 0 gens):")
    for name, (rel, cap) in SWAPS.items():
        folder = os.path.join(GIG, rel.replace("/", os.sep))
        if not os.path.isdir(folder):
            print(f"  !! {name}: source missing: {rel}"); continue
        tgt = os.path.join(SPRITES, name)
        if not os.path.isdir(tgt):
            print(f"  !! {name}: sprite folder missing (expected registered) - skipped"); continue
        shutil.rmtree(tgt)
        frames = load_frames_native(folder, cap)
        n, w, h = build_vfx_sprite_wh(name, frames)
        print(f"  {name}: {n} frames {w}x{h}  <-  {os.path.basename(folder)}")
    print("Done - no yyp changes (all names already registered).")


if __name__ == "__main__":
    main()
