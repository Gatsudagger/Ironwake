#!/usr/bin/env python
"""
Grayscale twins of the 4 combat impact-VFX sprites (Vael spell tints, 07-14).

Problem: the cast VFX is tinted via image_blend, which MULTIPLIES the tint into
Gigapack art that is already strongly colored (yellow-orange bursts) - the tint
barely reads and the yellow baseline stays visible (M report). Multiplicative
tinting only works over white/grayscale art.

Fix: clone each VFX sprite as spr_<name>_grey with every frame desaturated to
luminance (alpha preserved, luminance normalized per sprite so tints stay
vivid). Combat draw picks the grey twin whenever a non-default tint is equipped
(school_vfx_sprite in scr_stats); default tint keeps the authored art.

Method: wholesale folder copy of the original sprite, then remap every frame
uuid + the layer uuid to fresh uuids (files, dirs, and .yy references) and swap
the sprite name in the .yy - no .yy authoring from scratch, so multi-frame
sequence data survives untouched. Registers the new sprites in the .yyp via
gen_trait_icons.register_yyp. Idempotent: skips twins that already exist.

Run from repo root:  python tools/make_vfx_grey_twins.py
"""
import os, shutil, sys, uuid
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_trait_icons import SPRITES, register_yyp

SOURCES = ["spr_vfx_impact", "spr_vfx_fire", "spr_vfx_void", "spr_vfx_arcane"]


def grayscale_normalized(path, peak):
    img = Image.open(path).convert("RGBA")
    r, g, b, a = img.split()
    lum = Image.merge("RGB", (r, g, b)).convert("L")
    if peak > 0:
        lum = lum.point(lambda v: min(255, int(v * 255 / peak)))
    out = Image.merge("RGBA", (lum, lum, lum, a))
    out.save(path)


def sprite_peak_luminance(folder):
    peak = 1
    for dp, _, fs in os.walk(folder):
        for f in fs:
            if not f.endswith(".png"):
                continue
            img = Image.open(os.path.join(dp, f)).convert("RGBA")
            lum = img.convert("L")
            # Only count pixels that are actually visible
            alpha = img.split()[3]
            hist_src = Image.composite(lum, Image.new("L", img.size, 0), alpha.point(lambda v: 255 if v > 32 else 0))
            peak = max(peak, hist_src.getextrema()[1])
    return peak


def make_twin(src_name):
    dst_name = src_name + "_grey"
    src = os.path.join(SPRITES, src_name)
    dst = os.path.join(SPRITES, dst_name)
    if os.path.isdir(dst):
        print("skip (exists):", dst_name)
        return None
    shutil.copytree(src, dst)

    # Old frame uuids = root png basenames; the shared layer uuid = any file
    # inside a layers/<frame>/ dir.
    frames = [f[:-4] for f in os.listdir(dst) if f.endswith(".png")]
    layers_root = os.path.join(dst, "layers")
    first_frame_dir = os.path.join(layers_root, frames[0])
    layer_old = [f[:-4] for f in os.listdir(first_frame_dir) if f.endswith(".png")][0]

    yy_path_old = os.path.join(dst, src_name + ".yy")
    with open(yy_path_old, "r", encoding="utf-8") as f:
        yy = f.read()

    mapping = {src_name: dst_name, layer_old: str(uuid.uuid4())}
    for fr in frames:
        mapping[fr] = str(uuid.uuid4())

    # Rename files/dirs to the new uuids
    for fr in frames:
        os.rename(os.path.join(dst, fr + ".png"), os.path.join(dst, mapping[fr] + ".png"))
        frame_dir_old = os.path.join(layers_root, fr)
        for lf in os.listdir(frame_dir_old):
            if lf == layer_old + ".png":
                os.rename(os.path.join(frame_dir_old, lf),
                          os.path.join(frame_dir_old, mapping[layer_old] + ".png"))
        os.rename(frame_dir_old, os.path.join(layers_root, mapping[fr]))

    for old, new in mapping.items():
        yy = yy.replace(old, new)
    os.remove(yy_path_old)
    with open(os.path.join(dst, dst_name + ".yy"), "w", encoding="utf-8", newline="\n") as f:
        f.write(yy)

    # Desaturate every png (composites + layer copies), normalized per sprite
    peak = sprite_peak_luminance(dst)
    n = 0
    for dp, _, fs in os.walk(dst):
        for fname in fs:
            if fname.endswith(".png"):
                grayscale_normalized(os.path.join(dp, fname), peak)
                n += 1
    print("built %s (%d frames, %d pngs, peak %d)" % (dst_name, len(frames), n, peak))
    return dst_name


def main():
    built = [n for n in (make_twin(s) for s in SOURCES) if n]
    reg = register_yyp(built)
    print("registered %d new sprites in .yyp (of %d built)" % (reg, len(built)))


if __name__ == "__main__":
    main()
