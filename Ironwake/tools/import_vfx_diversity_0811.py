#!/usr/bin/env python
"""
VFX diversity batch (08-11, M approved all 18 shortlist slots in
_for_review/vfx_diversity_0811/PROPOSAL_FINAL.png - all owned packs, 0 gens).

Slot 16 (shadow variant = Necromancer VFX 2) was DROPPED at import time: the
07-29 batch already shipped those exact frames as spr_vfx_shadow, so it adds
no diversity. Flagged to M for a substitute pick; 17 sprites import here.

Sources:
  - Spell Effects pack: 96px 10-frame rows cropped straight out of the sheets.
  - Necromancer pack:   128px frame folders (VFX 1 ring, VFX 4 soul wisps).
  - FXpack13:           64px fireball flight (60 frames, subsampled).

Sprites keep their native size - the combat Draw normalizes by sprite width
(target_px / sprite_get_width), so 64/96/128 all land at the same on-screen px.

Wired in .gml by ability_attack_vfx / ability_support_vfx variant tables and
trap_spring_vfx (scr_abilities). Bare-identifier refs - no __sprite_includes.

Run from repo root with GameMaker CLOSED (yyp write):
    python tools/import_vfx_diversity_0811.py
"""
import os, re, sys
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_trait_icons import SPRITES, register_yyp
from import_combat_vfx_0729 import gm_running, build_vfx_sprite


def load_frames_numeric(folder, cap, size):
    """Like import_combat_vfx_0729.load_frames but NUMERIC filename order -
    lexicographic sort scrambles unpadded names (1.png, 10.png, 2.png...)."""
    def key(f):
        m = re.findall(r"\d+", f)
        return int(m[-1]) if m else 0
    files = sorted((f for f in os.listdir(folder) if f.endswith(".png")), key=key)
    n = len(files)
    if n > cap:
        files = [files[round(i * (n - 1) / (cap - 1))] for i in range(cap)]
    out = []
    for f in files:
        im = Image.open(os.path.join(folder, f)).convert("RGBA")
        if im.size != (size, size):
            im = im.resize((size, size), Image.NEAREST)
        out.append(im)
    return out

EFF = r"C:\Asset_Library\effects"
SPELL = os.path.join(EFF, "Spell Effects", "Spell Effects")
NEC = os.path.join(EFF, "Pixel Art VFX - Necromancer - FREE Version")
FXP = os.path.join(EFF, "FXpack13", "Fireballs FXpack13")


def load_sheet_row(sheet, row, size=96):
    """10 size-px frames from a 1-based sheet row; fully-empty frames dropped."""
    im = Image.open(os.path.join(SPELL, sheet + ".png")).convert("RGBA")
    out = []
    for i in range(im.width // size):
        fr = im.crop((i * size, (row - 1) * size, (i + 1) * size, row * size))
        if fr.getbbox() is not None:
            out.append(fr)
    return out


# sprite name -> ("row", sheet, row) | ("frames", folder, cap, native_px)
PICKS = {
    "spr_vfx_fire2":       ("row", "Fire 1",    8),
    "spr_vfx_scorch":      ("row", "Fire 2",    5),
    "spr_vfx_frost2":      ("row", "Misc 1",    8),
    "spr_vfx_shock2":      ("row", "Misc 1",   18),
    "spr_vfx_shockstrike": ("row", "Extra 2",  17),
    "spr_vfx_arcane2":     ("row", "Extra",     4),
    "spr_vfx_blood2":      ("row", "Misc 2",   12),
    "spr_vfx_poison2":     ("row", "Misc 1",   13),
    "spr_vfx_heal2":       ("row", "Healing 1", 6),
    "spr_vfx_gain2":       ("row", "Healing 1", 10),
    "spr_vfx_shield2":     ("row", "Support 1", 3),
    "spr_vfx_buff2":       ("row", "Support 1", 7),
    "spr_vfx_spikes":      ("row", "Misc 2",    9),
    "spr_vfx_wardflash":   ("row", "Extra",    17),
    "spr_vfx_void2":       ("frames", os.path.join(NEC, "VFX 1", "Frames"), 9, 128),
    "spr_vfx_dark2":       ("frames", os.path.join(NEC, "VFX 4", "Frames"), 10, 128),
    "spr_vfx_bolt_fire":   ("frames", os.path.join(FXP, "Effect1"), 12, 64),
}


def main():
    if gm_running():
        sys.exit("ABORT: GameMaker is running - close it first (yyp write).")

    print("VFX diversity batch (17 sprites from owned packs, 0 gens):")
    new = []
    for name, spec in PICKS.items():
        if os.path.isdir(os.path.join(SPRITES, name)):
            print(f"  {name} already exists - skipped")
            continue
        if spec[0] == "row":
            frames = load_sheet_row(spec[1], spec[2])
            size = 96
            src = f"{spec[1]} row {spec[2]}"
        else:
            _, folder, cap, size = spec
            frames = load_frames_numeric(folder, cap, size)
            src = os.path.basename(os.path.dirname(folder)) or folder
        if not frames:
            print(f"  !! {name}: NO frames from {src} - skipped")
            continue
        n = build_vfx_sprite(name, frames, size=size)
        print(f"  {name}: {n} frames {size}px  <-  {src}")
        new.append(name)
    if new:
        register_yyp(new)
        print(f"built + registered {len(new)} sprites (bare-identifier refs)")
    print("Done.")


if __name__ == "__main__":
    main()
