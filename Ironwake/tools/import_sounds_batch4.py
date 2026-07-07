#!/usr/bin/env python3
"""Sound pass Batch 4 (epilogue) - retire the UNIDENTIFIED legacy sound set.

License epilogue (2026-07-07, CREDITS.md): the pre-sound-pass library sounds have
no traceable source, so every remaining live use gets a cleared-pack replacement
and the assets are deleted from the project. MusicBox1 is kept (M identified it:
standalone free itch download, risk accepted).

Imports (400 Sounds Pack, Chequered Ink - license cleared):
  snd_player_grunt/_2  <- Human/man_2 + man_8 (Bloodwarden effort bark, variation)
  snd_move_whoosh      <- Other/whoosh_2 (Blink/Shadow Step movement cue;
                          NOTE shares the source wav with snd_attack_wraith -
                          different context, flag to M if it reads as samey)

Retires 15 assets: utility2, Check_1, Chimes__Ascending_, Success_1__subtle_,
Success_2, spell1, Magic, attack1, grunt, teleport, die5, hurt, Obscure,
Strings_1, Harp_2__Descending_. All code references were rewired first
(scr_combat fallbacks -> -1, live sites -> snd_* equivalents).
"""
import os
import shutil
import struct
import sys
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P400 = os.path.join(r"C:\Asset_Library\Sounds", "400 Sounds Pack")

MANIFEST = {
    "snd_player_grunt":   r"Human\man_2.wav",
    "snd_player_grunt_2": r"Human\man_8.wav",
    "snd_move_whoosh":    r"Other\whoosh_2.wav",
}

RETIRE = ["utility2", "Check_1", "Chimes__Ascending_", "Success_1__subtle_",
          "Success_2", "spell1", "Magic", "attack1", "grunt", "teleport",
          "die5", "hurt", "Obscure", "Strings_1", "Harp_2__Descending_"]

YY_TEMPLATE = """{{
  "$GMSound":"v2",
  "%Name":"{name}",
  "audioGroupId":{{
    "name":"audiogroup_default",
    "path":"audiogroups/audiogroup_default",
  }},
  "bitDepth":{bitdepth},
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
  "soundFile":"{name}.wav",
  "volume":1.0,
}}"""


def wav_params(path):
    try:
        with wave.open(path, "rb") as w:
            frames, rate = w.getnframes(), w.getframerate()
            return (round(frames / float(rate), 6), rate,
                    1 if w.getnchannels() >= 2 else 0,
                    0 if w.getsampwidth() == 1 else 1)
    except Exception:
        return (1.0, 44100, 0, 1)


def main():
    yyp_path = os.path.join(ROOT, "Ironwake.yyp")
    with open(yyp_path, "r", encoding="utf-8") as f:
        yyp = f.read()

    created, skipped, missing = [], [], []
    for name in sorted(MANIFEST):
        src = os.path.join(P400, MANIFEST[name])
        if not os.path.isfile(src):
            missing.append(f"{name} <- {src}")
            continue
        folder = os.path.join(ROOT, "sounds", name)
        if os.path.isfile(os.path.join(folder, name + ".yy")):
            skipped.append(name)
            continue
        os.makedirs(folder, exist_ok=True)
        shutil.copyfile(src, os.path.join(folder, name + ".wav"))
        dur, rate, chans, bits = wav_params(src)
        with open(os.path.join(folder, name + ".yy"), "w", encoding="utf-8") as f:
            f.write(YY_TEMPLATE.format(name=name, duration=dur, samplerate=rate,
                                       channels=chans, bitdepth=bits) + "\n")
        created.append(name)

    lines = yyp.split("\n")
    new_entries = [
        '    {{"id":{{"name":"{0}","path":"sounds/{0}/{0}.yy",}},}},'.format(n)
        for n in sorted(MANIFEST) if '"name":"{}","path":"sounds/'.format(n) not in yyp
    ]
    if new_entries:
        anchor = next(i for i, l in enumerate(lines)
                      if '"path":"sounds/snd_npc_confirm/snd_npc_confirm.yy"' in l)
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
