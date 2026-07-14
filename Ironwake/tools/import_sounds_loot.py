#!/usr/bin/env python3
"""Loot dopamine suite import (SOUND_ATMOSPHERE_SPEC.md section 1, M-approved
v2 candidates 07-14).

- 6 ElevenLabs jingles (_for_review/sounds/loot_v2/*.mp3) -> OGG via the pip
  imageio-ffmpeg binary (no system ffmpeg on this box) -> sounds/snd_loot_*.
- Reveal tick missed twice (2-strike rule) -> owned 400 Pack UI pops instead:
  pop_2 -> snd_loot_reveal, pop_3 -> snd_loot_reveal_2 (play_sfx_var variation).
- .yy from the batch3 template; .yyp lines inserted before snd_miss.

AFTER RUNNING (by hand, .gml): add the 8 names to audio_sfx_assets() or they
ignore the SFX slider; wire the loot screen (reveal tick per row + ONE stinger
for the highest rarity in the haul - M's haul rule).

Idempotent: skips sounds whose folder already exists.
Run from repo root:  python tools/import_sounds_loot.py
"""
import os, shutil, struct, subprocess, sys, wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
V2 = os.path.join(ROOT, "_for_review", "sounds", "loot_v2")
UI400 = r"C:\Asset_Library\Sounds\400 Sounds Pack\UI"

JINGLES = ["snd_loot_common", "snd_loot_uncommon", "snd_loot_rare",
           "snd_loot_epic", "snd_loot_legendary", "snd_loot_unique"]
POPS = {"snd_loot_reveal": "pop_2.wav", "snd_loot_reveal_2": "pop_3.wav"}

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


def wav_params(path):
    with wave.open(path, "rb") as w:
        rate = w.getframerate()
        dur = round(w.getnframes() / float(rate), 6)
        return (dur, rate, 1 if w.getnchannels() >= 2 else 0)


def emit(name, src_file, ext, params):
    folder = os.path.join(ROOT, "sounds", name)
    if os.path.isfile(os.path.join(folder, name + ".yy")):
        print("skip (exists):", name)
        return None
    os.makedirs(folder, exist_ok=True)
    shutil.copyfile(src_file, os.path.join(folder, name + "." + ext))
    dur, rate, chans = params
    with open(os.path.join(folder, name + ".yy"), "w", encoding="utf-8") as f:
        f.write(YY.format(name=name, duration=dur, samplerate=rate,
                          channels=chans, ext=ext) + "\n")
    print("imported", name, "(%ss)" % dur)
    return name


def main():
    ff = ffmpeg_exe()
    tmp = os.path.join(V2, "_ogg")
    os.makedirs(tmp, exist_ok=True)
    created = []

    for name in JINGLES:
        mp3 = os.path.join(V2, name + ".mp3")
        ogg = os.path.join(tmp, name + ".ogg")
        if not os.path.isfile(ogg):
            subprocess.run([ff, "-y", "-loglevel", "error", "-i", mp3,
                            "-c:a", "libvorbis", "-q:a", "5", ogg], check=True)
        n = emit(name, ogg, "ogg", ogg_params(ogg))
        if n: created.append(n)

    for name, pop in POPS.items():
        src = os.path.join(UI400, pop)
        n = emit(name, src, "wav", wav_params(src))
        if n: created.append(n)

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
    print("created %d, yyp +%d" % (len(created), len(new)))


if __name__ == "__main__":
    main()
