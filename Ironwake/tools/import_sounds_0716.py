#!/usr/bin/env python3
"""M 07-16 notes batch - sound import.

- snd_hatch_build / snd_hatch_fanfare: NEW assets (Zelda-chest egg-hatch
  crescendo, wired in scr_stats hatch_cutscene_* + audio_sfx_assets).
- snd_amb_cauldron: REPLACE audio in place (v1 "sounded like a toilet" - M);
  same asset name so scr_stats wiring/volume lines are untouched.

Sources: %CLAUDE_JOB_DIR% tmp sfx mp3s -> OGG via pip imageio-ffmpeg.
Idempotent for the new assets (skips existing folders); the cauldron replace
always runs (that's the point).
Run from repo root:  python tools/import_sounds_0716.py <src_dir>
"""
import os, shutil, struct, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = sys.argv[1] if len(sys.argv) > 1 else r"C:\Users\miles\.claude\jobs\0e25f4fe\tmp\sfx"

NEW = ["snd_hatch_build", "snd_hatch_fanfare"]
REPLACE = ["snd_amb_cauldron"]

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


def to_ogg(ff, name, tmp):
    mp3 = os.path.join(SRC, name + ".mp3")
    ogg = os.path.join(tmp, name + ".ogg")
    subprocess.run([ff, "-y", "-loglevel", "error", "-i", mp3,
                    "-c:a", "libvorbis", "-q:a", "5", ogg], check=True)
    return ogg


def write_asset(name, ogg, force):
    folder = os.path.join(ROOT, "sounds", name)
    if not force and os.path.isfile(os.path.join(folder, name + ".yy")):
        print("skip (exists):", name)
        return False
    os.makedirs(folder, exist_ok=True)
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
    for name in NEW:
        if write_asset(name, to_ogg(ff, name, tmp), force=False):
            created.append(name)
    for name in REPLACE:
        write_asset(name, to_ogg(ff, name, tmp), force=True)

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
