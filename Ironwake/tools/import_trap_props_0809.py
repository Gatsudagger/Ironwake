#!/usr/bin/env python
"""
08-09 deployed TRAP PROPS (SYSTEMS_TRAPS.md §8, ANIMATION_AUDIT Gap 2, first half).

M, after F5'ing the 08-08 build: "the trap looks awful ... it looks like literal
line drawings from paint so use pixellabs to generate the traps they should all
look different given their roles."

Seven 64x64 side-on props, one per trap, PixelLab create_1_direction_object
(sidescroller view, styled from the shipped spr_ability_bear_trap so the palette
matches). Drawn at 2x on the diagonal trap field by ui_draw_trap_field(), which
falls back to the old procedural jaw glyph for any trap whose prop is missing.

BOTTOM-ALIGNMENT: the raw generations float their content anywhere inside the
64px box. ui_draw_trap_field anchors bottom-centre (y = ground - height), so a
prop with transparent padding under it would hover above the floor. Each frame
is therefore cropped to its alpha bbox and re-pasted bottom-centred. This is the
whole reason the import is not a straight copy.

Referenced by direct identifier in trap_prop_sprite() (scr_ui.gml), so no
global.__sprite_includes entry is needed.

Run from repo root with GameMaker CLOSED:
    python tools/import_trap_props_0809.py
"""
import os, sys, uuid
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_trait_icons import ROOT, SPRITES, YY_TEMPLATE, register_yyp
from import_combat_vfx_0729 import gm_running

RAW = os.path.join(ROOT, "_for_review", "trap_props_0809", "raw")
SZ = 64

# sprite name -> M-reviewed candidate file
JOBS = [
    ("spr_trap_prop_bear",     "bear_trap_10.png"),      # rusted open jaws + chain
    ("spr_trap_prop_spike",    "spike_trap_00.png"),     # stone plate, bloodied spikes
    # M 08-09: "if snare is death snare (we made the icon plan tendrils holding the
    # limbs of an enemy remember)". The first batch's rope-and-hooks read was wrong
    # for the ability - this is a bespoke re-gen: a nest of black tendrils with
    # verdigris highlights, coiled open, clawed tips raised. Matches the shipped
    # spr_ability_death_snare icon (black roots + claws) instead of fighting it.
    ("spr_trap_prop_snare",    "snare_tendril_04.png"),
    ("spr_trap_prop_tripline", "tripline_04.png"),       # two iron stakes, taut wire
    # M re-pick: a chime AT REST. The tilted mid-ring frame implied motion the
    # prop never has - it just sits there until something trips it.
    ("spr_trap_prop_chime",    "warding_chime_09.png"),
    ("spr_trap_prop_wire",     "wire_snare_05.png"),     # M re-pick: loop + coil + peg
    ("spr_trap_prop_caltrops", "caltrops_03.png"),       # scattered bloodied caltrops
]


def bottom_align(im):
    """Crop to visible content, then re-pad bottom-centred in a SZ x SZ box."""
    bb = im.getbbox()
    if bb is None:
        return im
    c = im.crop(bb)
    if c.width > SZ or c.height > SZ:
        c.thumbnail((SZ, SZ), Image.NEAREST)
    out = Image.new("RGBA", (SZ, SZ), (0, 0, 0, 0))
    out.paste(c, ((SZ - c.width) // 2, SZ - c.height))
    return out


def build_sprite(spr_name, img):
    sdir = os.path.join(SPRITES, spr_name)
    frame = str(uuid.uuid4()); layer = str(uuid.uuid4()); kfid = str(uuid.uuid4())
    os.makedirs(os.path.join(sdir, "layers", frame), exist_ok=True)
    img.save(os.path.join(sdir, frame + ".png"))
    img.save(os.path.join(sdir, "layers", frame, layer + ".png"))
    yy = YY_TEMPLATE.format(name=spr_name, frame=frame, layer=layer, kfid=kfid,
                            w=SZ, h=SZ, br=SZ - 1, bb=SZ - 1)
    with open(os.path.join(sdir, spr_name + ".yy"), "w", newline="\n") as f:
        f.write(yy)


def main():
    if gm_running():
        sys.exit("ABORT: GameMaker is running - close it first (yyp write).")
    names = []
    for spr_name, src in JOBS:
        if os.path.isdir(os.path.join(SPRITES, spr_name)):
            print("  skip (exists):", spr_name)
            continue
        p = os.path.join(RAW, src)
        assert os.path.exists(p), "missing candidate: " + p
        im = Image.open(p).convert("RGBA")
        assert im.size == (SZ, SZ), (src, im.size)
        before = im.getbbox()
        out = bottom_align(im)
        build_sprite(spr_name, out)
        names.append(spr_name)
        print("  %-26s <- %-22s bbox %s -> bottom-aligned" % (spr_name, src, before))
    if names:
        register_yyp(names)
        print("registered %d props in Ironwake.yyp" % len(names))
    else:
        print("nothing to do")


if __name__ == "__main__":
    main()
