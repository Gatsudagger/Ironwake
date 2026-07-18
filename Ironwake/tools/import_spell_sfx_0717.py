#!/usr/bin/env python3
"""Per-school ability cast SFX import (2026-07-17, M approved all 14 candidates).

Splits the single overused snd_cast_elem into per-SCHOOL cast sounds so fire /
frost / shock / arcane etc no longer sound identical. Two takes per school ->
base + _2 so play_sfx_var randomizes.

  NEW assets (folder + .yy + yyp registration):
    snd_cast_fire(_2), snd_cast_frost(_2), snd_cast_shock(_2),
    snd_cast_nature(_2), snd_cast_void_2
  REPLACE audio in place (keep name + existing registration; the old first-draft
  picks were never auditioned - M's "reroll arcane/void/blood"):
    snd_cast_void, snd_cast_arcane(_2), snd_cast_blood(_2)
    (old .wav is removed; .yy rewritten to the new .ogg)

Sources: _for_review/spell_sfx/<school>_<a|b>.mp3 -> OGG via pip imageio-ffmpeg.
Run from repo root:  python tools/import_spell_sfx_0717.py
"""
import os, shutil, struct, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC  = os.path.join(ROOT, "_for_review", "spell_sfx")

# asset_name -> source mp3 basename (in SRC)
NEW = {
    "snd_cast_fire":     "fire_a",
    "snd_cast_fire_2":   "fire_b",
    "snd_cast_frost":    "frost_a",
    "snd_cast_frost_2":  "frost_b",
    "snd_cast_shock":    "shock_a",
    "snd_cast_shock_2":  "shock_b",
    "snd_cast_nature":   "nature_a",
    "snd_cast_nature_2": "nature_b",
    "snd_cast_void_2":   "void_b",
}
REPLACE = {
    "snd_cast_void":     "void_a",
    "snd_cast_arcane":   "arcane_a",
    "snd_cast_arcane_2": "arcane_b",
    "snd_cast_blood":    "blood_a",
    "snd_cast_blood_2":  "blood_b",
}

YY = """{{
  "$GMSound":"v2",
  "%Name":"{name}",
  "audioGroupId":{{
    "name":"audiogroup_default",
    "path":"audiogroups/audiogroup_default",
  }},
  "bitDepth":1,
  "channelFormat":{channels},
  "compression":0,
  "compressionQuality":4,
  "conversionMode":0,
  "duration":{duration},
  "exportDir":"",
  "name":"{name}",
  "parent":{{
    "name":"Ironwake",
    "path":"Ironwake.yyp",
  }},
  "preload":false,
  "resourceType":"GMSound",
  "resourceVersion":"2.0",
  "sampleRate":{samplerate},
  "soundFile":"{name}.{ext}",
  "volume":1.0,
}}"""


def ffmpeg_exe():
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


def ogg_params(path):
    with open(path, "rb") as f:
        data = f.read()
    i = data.find(b"\x01vorbis")
    channels = data[i + 11]
    rate = struct.unpack("<I", data[i + 12:i + 16])[0]
    last = data.rfind(b"OggS")
    granule = struct.unpack("<q", data[last + 6:last + 14])[0]
    return (round(granule / float(rate), 6), rate, 1 if channels >= 2 else 0)


def to_ogg(ff, src_base, tmp):
    mp3 = os.path.join(SRC, src_base + ".mp3")
    ogg = os.path.join(tmp, src_base + ".ogg")
    subprocess.run([ff, "-y", "-loglevel", "error", "-i", mp3,
                    "-c:a", "libvorbis", "-q:a", "5", ogg], check=True)
    return ogg


def write_asset(name, ogg, force):
    folder = os.path.join(ROOT, "sounds", name)
    if not force and os.path.isfile(os.path.join(folder, name + ".yy")):
        print("skip (exists):", name)
        return False
    os.makedirs(folder, exist_ok=True)
    # Replacing an old .wav-backed asset: drop the stale wav so only the ogg remains.
    stale_wav = os.path.join(folder, name + ".wav")
    if os.path.isfile(stale_wav):
        os.remove(stale_wav)
    shutil.copyfile(ogg, os.path.join(folder, name + ".ogg"))
    dur, rate, chans = ogg_params(ogg)
    with open(os.path.join(folder, name + ".yy"), "w", encoding="utf-8") as f:
        f.write(YY.format(name=name, duration=dur, samplerate=rate,
                          channels=chans, ext="ogg") + "\n")
    print(("replaced" if force else "imported"), name, "(%ss)" % dur)
    return True


def main():
    ff = ffmpeg_exe()
    tmp = os.path.join(SRC, "_ogg")
    os.makedirs(tmp, exist_ok=True)

    created = []
    for name, base in NEW.items():
        if write_asset(name, to_ogg(ff, base, tmp), force=False):
            created.append(name)
    for name, base in REPLACE.items():
        write_asset(name, to_ogg(ff, base, tmp), force=True)

    yyp_path = os.path.join(ROOT, "Ironwake.yyp")
    with open(yyp_path, "r", encoding="utf-8") as f:
        text = f.read()
    lines = text.split("\n")
    anchor = next(i for i, l in enumerate(lines)
                  if '"path":"sounds/snd_miss/snd_miss.yy"' in l)
    new = ['    {{"id":{{"name":"{0}","path":"sounds/{0}/{0}.yy",}},}},'.format(n)
           for n in sorted(created) if '"name":"{}","path":"sounds/'.format(n) not in text]
    lines[anchor:anchor] = new
    if new:
        with open(yyp_path, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lines))
    print("new %d, yyp +%d" % (len(created), len(new)))


if __name__ == "__main__":
    main()
