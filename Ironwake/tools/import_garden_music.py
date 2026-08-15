#!/usr/bin/env python3
"""Bairc's Garden music import (08-15, M-approved candidate 2).

_for_review/garden_music_0815/garden_aquatic_candidate_2.mp3 (ElevenLabs
music_v2, 110s, DKC Aquatic Ambience brief) -> loudnorm -14 LUFS (music
level, matches the jukebox tracks) -> OGG -> sounds/mus_garden_zen/ + .yy
+ Ironwake.yyp registration. The garden scene code already listens for the
asset by name (asset_get_index("mus_garden_zen")) - importing it turns the
music hook on, nothing else to wire besides the Music-volume assets list
(done by hand in scr_stats the same batch).

GameMaker MUST be closed when this runs (yyp rewrite rule, 07-18 lesson).
Idempotent: skips if the sound folder already exists.
Run from anywhere:  python tools/import_garden_music.py
"""
import os, shutil, struct, subprocess, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_trait_icons import ROOT

REVIEW = os.path.join(ROOT, "_for_review", "garden_music_0815")
YYP    = os.path.join(ROOT, "Ironwake.yyp")

# name -> source mp3 (all music-level loudnorm -14). Idempotent per entry.
TRACKS = {
    "mus_garden_zen":   "garden_aquatic_candidate_2.mp3",   # "Stillwater" (garden DEFAULT)
    "mus_garden_shire": "garden_shire_FULL.mp3",            # "Greenhollow"
    "mus_garden_hook":  "garden_mitsuda_hook_FULL.mp3",     # "Tidesong"
    "mus_garden_retro": "garden_retro_jrpg_FULL.mp3",       # "Garden of Ages"
    "mus_dungeon_opera": "dungeon_battle_operatic_FULL.mp3",  # "The Black Aria" (dungeon pool)
}

SND_YY = """{{
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


def import_one(name, src_base, ff, tmp):
    folder = os.path.join(ROOT, "sounds", name)
    if os.path.isfile(os.path.join(folder, name + ".yy")):
        print("skip (exists):", name)
        return False
    src = os.path.join(REVIEW, src_base)
    if not os.path.isfile(src):
        print("MISSING SOURCE:", src)
        sys.exit(1)
    norm = os.path.join(tmp, name + "_norm.wav")
    ogg  = os.path.join(tmp, name + ".ogg")
    subprocess.run([ff, "-y", "-loglevel", "error", "-i", src,
                    "-af", "loudnorm=I=-14:TP=-1.5:LRA=11",
                    "-ar", "44100", norm], check=True)
    subprocess.run([ff, "-y", "-loglevel", "error", "-i", norm,
                    "-c:a", "libvorbis", "-q:a", "5", ogg], check=True)
    os.makedirs(folder, exist_ok=True)
    shutil.copyfile(ogg, os.path.join(folder, name + ".ogg"))
    dur, rate, chans = ogg_params(ogg)
    with open(os.path.join(folder, name + ".yy"), "w", encoding="utf-8") as f:
        f.write(SND_YY.format(name=name, duration=dur, samplerate=rate,
                              channels=chans, ext="ogg") + "\n")
    print("imported %s (%ss, %dHz)" % (name, dur, rate))
    return True


def main():
    ff  = ffmpeg_exe()
    tmp = os.path.join(REVIEW, "_proc")
    os.makedirs(tmp, exist_ok=True)
    created = [n for n, src in TRACKS.items() if import_one(n, src, ff, tmp)]

    # yyp registration, anchored next to the other sounds (banshee idiom).
    with open(YYP, "r", encoding="utf-8") as f:
        text = f.read()
    lines  = text.split("\n")
    anchor = next(i for i, l in enumerate(lines)
                  if '"path":"sounds/snd_miss/snd_miss.yy"' in l)
    new = ['    {{"id":{{"name":"{0}","path":"sounds/{0}/{0}.yy",}},}},'.format(n)
           for n in sorted(created)
           if '"name":"{}","path":"sounds/'.format(n) not in text]
    lines[anchor:anchor] = new
    if new:
        with open(YYP, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lines))
    print("yyp: +%d registered" % len(new))


if __name__ == "__main__":
    main()
