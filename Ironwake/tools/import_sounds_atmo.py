#!/usr/bin/env python3
"""Atmosphere/flavor import (SOUND_ATMOSPHERE_SPEC.md sections 2-4, M-approved
candidates 07-14 evening; curse whisper = v2 re-roll, v1 read sci-fi).

- 18 ElevenLabs candidates (_for_review/sounds_atmo/*.mp3) -> loudness-normalized
  (M: "many are barely audible" -> loudnorm to -16 LUFS, in-game trims set the
  quiet) -> the 8 loops get a seamless loop edit (second half + crossfaded first
  half, so the wrap point is mid-material continuity, and the mp3 edge padding
  lands inside the crossfade) -> OGG via the pip imageio-ffmpeg binary
  (no system ffmpeg on this box) -> sounds/<name>/.
- .yy from the batch3 template; .yyp lines inserted before snd_miss.

AFTER RUNNING (by hand, .gml): register beds+loops in audio_music_assets() +
ambience_all_assets() + trims, stingers in audio_sfx_assets(); wire per spec.

Idempotent: skips sounds whose folder already exists.
Run from repo root:  python tools/import_sounds_atmo.py
"""
import os, shutil, struct, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "_for_review", "sounds_atmo")

# name -> (source mp3 basename, loop crossfade seconds; 0 = one-shot stinger)
SOUNDS = {
    "snd_amb_ashen":      ("snd_amb_ashen.mp3",       1.5),
    "snd_amb_scorched":   ("snd_amb_scorched.mp3",    1.5),
    "snd_amb_tundra":     ("snd_amb_tundra.mp3",      1.5),
    "snd_amb_title":      ("snd_amb_title.mp3",       1.5),
    "snd_amb_forge":      ("snd_amb_forge.mp3",       1.0),
    "snd_amb_cauldron":   ("snd_amb_cauldron.mp3",    1.0),
    "snd_amb_garden":     ("snd_amb_garden.mp3",      1.0),
    "snd_amb_tavern":     ("snd_amb_tavern.mp3",      1.0),
    "snd_shrine_hum":     ("snd_shrine_hum.mp3",      0),
    "snd_curse_whisper":  ("snd_curse_whisper_v2.mp3", 0),
    "snd_egg_stir":       ("snd_egg_stir.mp3",        0),
    "snd_hatch_burst":    ("snd_hatch_burst.mp3",     0),
    "snd_awakened_cross": ("snd_awakened_cross.mp3",  0),
    "snd_bond_up":        ("snd_bond_up.mp3",         0),
    "snd_extract":        ("snd_extract.mp3",         0),
    "snd_boss_door":      ("snd_boss_door.mp3",       0),
    "snd_betrayal":       ("snd_betrayal.mp3",        0),
    "snd_quest_ready":    ("snd_quest_ready.mp3",     0),
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


def wav_duration(ff, path):
    out = subprocess.run([ff, "-i", path, "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    import re
    m = re.findall(r"time=(\d+):(\d+):(\d+\.\d+)", out)
    h, mn, s = m[-1]
    return int(h) * 3600 + int(mn) * 60 + float(s)


def emit(name, ogg):
    folder = os.path.join(ROOT, "sounds", name)
    if os.path.isfile(os.path.join(folder, name + ".yy")):
        print("skip (exists):", name)
        return None
    os.makedirs(folder, exist_ok=True)
    shutil.copyfile(ogg, os.path.join(folder, name + ".ogg"))
    dur, rate, chans = ogg_params(ogg)
    with open(os.path.join(folder, name + ".yy"), "w", encoding="utf-8") as f:
        f.write(YY.format(name=name, duration=dur, samplerate=rate,
                          channels=chans, ext="ogg") + "\n")
    print("imported %s (%ss)" % (name, dur))
    return name


def main():
    ff = ffmpeg_exe()
    tmp = os.path.join(SRC, "_proc")
    os.makedirs(tmp, exist_ok=True)
    created = []

    for name, (src_base, xf) in SOUNDS.items():
        mp3 = os.path.join(SRC, src_base)
        if not os.path.isfile(mp3):
            print("MISSING SOURCE:", mp3)
            sys.exit(1)
        norm = os.path.join(tmp, name + "_norm.wav")
        ogg = os.path.join(tmp, name + ".ogg")
        if not os.path.isfile(ogg):
            # 1) decode + loudness-normalize to a consistent -16 LUFS
            subprocess.run([ff, "-y", "-loglevel", "error", "-i", mp3,
                            "-af", "loudnorm=I=-16:TP=-1.5:LRA=11",
                            "-ar", "44100", norm], check=True)
            if xf > 0:
                # 2) loop edit: output = second half, crossfade into first half.
                #    The wrap point is the original midpoint (continuous material);
                #    the one hard seam (file end -> file start) hides in the xfade.
                #    Three separate passes: a single-input filter_complex (even via
                #    asplit) truncated to ~0.1s - two real file inputs work.
                dur = wav_duration(ff, norm)
                half = dur / 2.0
                a_wav = os.path.join(tmp, name + "_a.wav")
                b_wav = os.path.join(tmp, name + "_b.wav")
                looped = os.path.join(tmp, name + "_loop.wav")
                subprocess.run([ff, "-y", "-loglevel", "error", "-i", norm,
                                "-af", "atrim=0:%s,asetpts=PTS-STARTPTS" % (half + xf),
                                a_wav], check=True)
                subprocess.run([ff, "-y", "-loglevel", "error", "-i", norm,
                                "-af", "atrim=%s,asetpts=PTS-STARTPTS" % half,
                                b_wav], check=True)
                subprocess.run([ff, "-y", "-loglevel", "error",
                                "-i", b_wav, "-i", a_wav,
                                "-filter_complex", "[0:a][1:a]acrossfade=d=%s" % xf,
                                looped], check=True)
                src_final = looped
            else:
                src_final = norm
            subprocess.run([ff, "-y", "-loglevel", "error", "-i", src_final,
                            "-c:a", "libvorbis", "-q:a", "5", ogg], check=True)
        n = emit(name, ogg)
        if n:
            created.append(n)

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
