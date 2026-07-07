#!/usr/bin/env python3
"""Sound pass Batch 3 import (see SOUND_PASS_SPEC.md section G).

Two jobs, both idempotent:
1. Import the 3 TomMusic ambience loops as OGG (streamed-length beds - wav
   would triple the repo weight for identical audio). Registered under the
   MUSIC slider (M's routing call, 07-07): add to audio_music_assets().
2. Retire the 6 unused legacy sound assets (zero .gml references, audited
   07-07): delete sounds/<name>/ and strip their Ironwake.yyp lines.

After running, the snd_amb_* names must be listed in audio_music_assets()
(scr_stats) and each room controller's Create declares its layer via
ambience_set() - see SOUND_PASS_SPEC.md.
"""
import os
import shutil
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOM_OGG = os.path.join(r"C:\Asset_Library\Sounds",
                       "Free Fantasy SFX Pack By TomMusic",
                       "Free Fantasy SFX Pack By TomMusic", "OGG Files")

# asset name -> source ogg (relative to the TomMusic OGG root)
MANIFEST = {
    "snd_amb_rain":  r"BGS Loops\Forest Night\Forest Night Rain.ogg",  # hub (matches Rainy_Memories)
    "snd_amb_cave":  r"BGS Loops\Cave\Cave.ogg",                       # dungeon floors
    "snd_amb_torch": r"SFX\Torch\Torch Loop.ogg",                      # brazier layer, hub + floors
}

# Unused legacy assets - audited 2026-07-07: no .gml references, not in either
# audio_*_assets() registry.
RETIRE = ["Check_2", "Harp_1__Ascending_", "Miscellaneous_1__Atmospheric_",
          "Selection", "Strings_2", "Success_3"]

# Mirrors the existing ogg music assets (_2_dungeon_LOOP et al): compression 0
# with an .ogg soundFile is how this project ships its long loops.
YY_TEMPLATE = """{{
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
  "soundFile":"{name}.ogg",
  "volume":1.0,
}}"""


def ogg_params(path):
    """(duration_s, samplerate, channelFormat) from the vorbis headers; the
    duration is last-page granule position / sample rate."""
    try:
        with open(path, "rb") as f:
            data = f.read()
        i = data.find(b"\x01vorbis")          # identification header
        channels = data[i + 11]
        rate = struct.unpack("<I", data[i + 12:i + 16])[0]
        last = data.rfind(b"OggS")            # granule of the final page
        granule = struct.unpack("<q", data[last + 6:last + 14])[0]
        return (round(granule / float(rate), 6), rate, 1 if channels >= 2 else 0)
    except Exception:
        return (60.0, 44100, 1)


def main():
    yyp_path = os.path.join(ROOT, "Ironwake.yyp")
    with open(yyp_path, "r", encoding="utf-8") as f:
        yyp = f.read()

    created, skipped, missing = [], [], []
    for name in sorted(MANIFEST):
        src = os.path.join(TOM_OGG, MANIFEST[name])
        if not os.path.isfile(src):
            missing.append(f"{name} <- {src}")
            continue
        folder = os.path.join(ROOT, "sounds", name)
        if os.path.isfile(os.path.join(folder, name + ".yy")):
            skipped.append(name)
            continue
        os.makedirs(folder, exist_ok=True)
        shutil.copyfile(src, os.path.join(folder, name + ".ogg"))
        dur, rate, chans = ogg_params(src)
        with open(os.path.join(folder, name + ".yy"), "w", encoding="utf-8") as f:
            f.write(YY_TEMPLATE.format(name=name, duration=dur,
                                       samplerate=rate, channels=chans) + "\n")
        created.append(name)

    # Patch Ironwake.yyp: snd_amb_* sorts (case-insensitively) right before
    # snd_attack_beast; retired assets just lose their line.
    lines = yyp.split("\n")
    anchor = next(i for i, l in enumerate(lines)
                  if '"path":"sounds/snd_attack_beast/snd_attack_beast.yy"' in l)
    new_entries = [
        '    {{"id":{{"name":"{0}","path":"sounds/{0}/{0}.yy",}},}},'.format(n)
        for n in sorted(MANIFEST) if '"name":"{}","path":"sounds/'.format(n) not in yyp
    ]
    lines[anchor:anchor] = new_entries

    removed = 0
    for name in RETIRE:
        needle = '"path":"sounds/{0}/{0}.yy"'.format(name)
        keep = [l for l in lines if needle not in l]
        removed += len(lines) - len(keep)
        lines = keep
        folder = os.path.join(ROOT, "sounds", name)
        if os.path.isdir(folder):
            shutil.rmtree(folder)

    if new_entries or removed:
        with open(yyp_path, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lines))

    print(f"created {len(created)}  skipped {len(skipped)}  "
          f"yyp+{len(new_entries)}  retired-{removed}")
    if missing:
        print("MISSING SOURCES:")
        print("\n".join(missing))
        sys.exit(1)


if __name__ == "__main__":
    main()
