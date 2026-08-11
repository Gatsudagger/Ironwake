#!/usr/bin/env python
"""
08-09 combat VFX batch - ANIMATION AUDIT Gap 1 + the unused-pack sweep.

M: "if youre saying we have a lot of gigapack thats unused then lets use and
wire as many as it provides where appropriate".

Gap 1: all 24 physical (dtype 0) abilities shared ONE burst (spr_vfx_impact).
This adds four physical motion archetypes, resolved by ability_phys_shape()
in scr_abilities.gml:

    slash   Cleave, Throat Slit, Gore Strike, Winter's Bite ...
    pierce  Snipe, Assassinate, Poison Dart, Frost Shot ...
    crush   Bonebreaker, Marrow Crush, Bulwark Slam ...
    snap    the trap springs

Plus four event bursts the packs already had and nothing was using - most
importantly RAGE, which shipped 08-08 as a text popup with no visual at all.

All frames come from the OWNED unTied Games Gigapack (attribution already in
CREDITS.md), luminance-tinted to fit Ironwake's palette. ZERO generations.

spr_vfx_slash already existed as a 1-frame ORPHAN referenced nowhere (flagged
in SYSTEMS_ANIMATION_AUDIT.md). This REPLACES it with the real animation, which
is why it is the one entry allowed to overwrite.

Run from repo root with GameMaker CLOSED:
    python tools/import_phys_vfx_0809.py
"""
import os, sys, shutil
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_trait_icons import SPRITES, register_yyp
from import_combat_vfx_0729 import GIG, gm_running, load_frames, build_vfx_sprite

SZ = 96   # matches spr_vfx_impact, the sprite these replace for physical hits

# name -> (pack subpath, frame cap, RGB tint or None to keep source colour, overwrite?)
PICKS = {
    # ---- Gap 1: physical motion archetypes -------------------------------
    # A fan of blade streaks raking across the target -> a cut.
    "spr_vfx_slash":  ("Impacts/directional_impact_001/directional_impact_001_large_blue",
                       7,  (216, 226, 242), True),
    # A tight crown of thin spikes driven up through the target -> a thrust.
    "spr_vfx_pierce": ("Impacts/directional_impact_004/directional_impact_004_large_yellow",
                       5,  (228, 220, 206), False),
    # Thick chunky ring + heavy debris -> blunt shockwave. Dusty, not bright.
    "spr_vfx_crush":  ("Impacts/symmetrical_impact_004/symmetrical_impact_004_large_yellow",
                       8,  (176, 158, 136), False),
    # Sharp four-point starburst, fast in and out -> jaws closing.
    "spr_vfx_snap":   ("Impacts/symmetrical_impact_001/symmetrical_impact_001_large_yellow",
                       7,  (206, 212, 224), False),
    # ---- event bursts the packs already had, nothing was using -----------
    # RAGE (08-08 boss combo-breaker) had NO visual - only a text popup.
    # symmetrical_explosion_001 was tried first and read as an expanding ORB,
    # not fury - epic_explosion has the debris and heft the moment needs.
    "spr_vfx_rage":   ("Explosions/epic_explosion_001/epic_explosion_001_large_orange",
                       14, (238,  96,  70), True),
    # Big finish: boss death / floor clear. Keeps the pack's warm orange.
    "spr_vfx_boom":   ("Explosions/epic_explosion_001/epic_explosion_001_large_orange",
                       16, None, False),
}

# REJECTED on style review 08-09, do not re-add without M:
#   spell_death_001   -> a red Japanese kanji + skull. Hard clash with the
#                        gothic Western set; nothing else in Ironwake uses
#                        glyph-language VFX.
#   spell_attack_up_001 -> crossed-swords "+" symbol; duplicates the shipped
#                        spr_vfx_buff, which is already the sword+ burst.


def tint(frames, rgb):
    """Luminance-tint: keeps the animation's shading and alpha, restyles hue."""
    if rgb is None:
        return frames
    out = []
    for im in frames:
        a = im.split()[3]
        lum = im.convert("L")
        px = lum.load()
        w, h = im.size
        new = Image.new("RGBA", (w, h))
        np_ = new.load()
        for y in range(h):
            for x in range(w):
                v = px[x, y] / 255.0
                np_[x, y] = (min(255, int(rgb[0] * v)),
                             min(255, int(rgb[1] * v)),
                             min(255, int(rgb[2] * v)), 0)
        new.putalpha(a)
        out.append(new)
    return out


def main():
    if gm_running():
        sys.exit("ABORT: GameMaker is running - close it first (yyp write).")

    new = []
    for name, (sub, cap, rgb, overwrite) in PICKS.items():
        root = os.path.join(SPRITES, name)
        exists = os.path.isdir(root)
        if exists and not overwrite:
            print("  skip (exists):", name)
            continue
        folder = os.path.join(GIG, *sub.split("/"))
        assert os.path.isdir(folder), "missing pack folder: " + folder
        frames = tint(load_frames(folder, cap, SZ), rgb)
        if exists:
            shutil.rmtree(root)          # orphan replace (spr_vfx_slash)
            print("  REPLACED orphan:", name)
        n = build_vfx_sprite(name, frames, SZ)
        print("  %-20s %2d frames %dpx  <-  %s" % (name, n, SZ, sub.split("/")[-1]))
        if not exists:
            new.append(name)
    if new:
        register_yyp(new)
        print("registered %d new sprites (bare-identifier refs, no __sprite_includes)" % len(new))
    print("Done. 0 generations.")


if __name__ == "__main__":
    main()
