#!/usr/bin/env python3
"""Sound pass Batch 1 import (see SOUND_PASS_SPEC.md).

Copies picked .wav files from C:\\Asset_Library\\Sounds into sounds/<snd_name>/,
writes each GMSound .yy (duration/sampleRate/channels read from the wav header),
and inserts the resource lines into Ironwake.yyp in sort order. Idempotent:
re-running skips assets that already exist.

After running, the new names must also be bare-listed in audio_sfx_assets()
(scr_stats) or they bypass the SFX volume slider.
"""
import os
import shutil
import struct
import sys
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = r"C:\Asset_Library\Sounds"
P400 = os.path.join(LIB, "400 Sounds Pack")
TOM = os.path.join(LIB, "Free Fantasy SFX Pack By TomMusic",
                   "Free Fantasy SFX Pack By TomMusic", "WAV Files", "SFX")

# asset name -> source wav (relative to the pack roots above)
MANIFEST = {
    # A. UI core
    # ONE file only - random variation reads as inconsistent on a UI tick (M, 07-07).
    # glass ping (M's audition pick) - the select_* UI sounds read "too digital".
    "snd_ui_move":        (P400, r"Materials\glass_ping_small.wav"),
    # Confirm hierarchy (M, 2026-07-07): wood tap = general confirm, harpsichord
    # chime = major commitments (embark, rebirth), book close = NPC interactions,
    # wood drop = selling/salvaging.
    "snd_ui_confirm":     (P400, r"Materials\wood_small_hollow.wav"),
    "snd_confirm_major":  (P400, r"Musical Effects\harpsichord_chime_quick.wav"),
    "snd_npc_confirm":    (P400, r"Items\book_close.wav"),
    "snd_sell":           (P400, r"Card and Board\dice_grab.wav"),   # M: same rattle for sell + salvage
    "snd_ui_cancel":      (P400, r"UI\cancel.wav"),
    "snd_ui_error":       (P400, r"Musical Effects\harpsichord_negative_quick.wav"),
    "snd_ui_toggle_on":   (P400, r"UI\toggle_on.wav"),
    "snd_ui_toggle_off":  (P400, r"UI\toggle_off.wav"),
    # B. Knucklebones / High Table dice
    "snd_dice_roll":      (P400, r"Card and Board\dice_roll_1.wav"),
    "snd_dice_roll_2":    (P400, r"Card and Board\dice_roll_2.wav"),
    "snd_dice_roll_3":    (P400, r"Card and Board\dice_roll_3.wav"),
    "snd_dice_shake":     (P400, r"Card and Board\dice_shake_2.wav"),
    "snd_dice_place":     (P400, r"Card and Board\chips_place_1.wav"),
    "snd_dice_place_2":   (P400, r"Card and Board\chips_place_2.wav"),
    "snd_kb_capture":     (P400, r"Combat and Gore\crunch_quick.wav"),
    "snd_kb_payout":      (P400, r"Items\coins_gather_medium.wav"),
    "snd_kb_payout_2":    (P400, r"Card and Board\chips_gather_2.wav"),
    # C. Combat - player
    "snd_player_atk":     (TOM,  r"Attacks\Sword Attacks Hits and Blocks\Sword Attack 1.wav"),
    "snd_player_atk_2":   (TOM,  r"Attacks\Sword Attacks Hits and Blocks\Sword Attack 2.wav"),
    "snd_player_atk_3":   (TOM,  r"Attacks\Sword Attacks Hits and Blocks\Sword Attack 3.wav"),
    "snd_miss":           (P400, r"Combat and Gore\swipe.wav"),
    "snd_miss_2":         (P400, r"Other\whoosh_1.wav"),
    "snd_player_hurt":    (P400, r"Combat and Gore\punch_2.wav"),
    "snd_player_hurt_2":  (P400, r"Combat and Gore\slap.wav"),
    # C. Combat - enemy families (feed existing snd_attack_/snd_death_ slots)
    "snd_attack_undead":     (P400, r"Combat and Gore\bone_snap.wav"),
    "snd_death_undead":      (P400, r"Combat and Gore\crunch_splat.wav"),
    "snd_attack_wraith":     (P400, r"Other\whoosh_2.wav"),
    "snd_death_wraith":      (P400, r"Other\ghost_long.wav"),
    "snd_attack_construct":  (P400, r"Materials\metal_clang.wav"),
    "snd_death_construct":   (P400, r"Materials\stone_push_short.wav"),
    "snd_attack_beast":      (P400, r"Combat and Gore\crunch.wav"),
    "snd_attack_beast_2":    (P400, r"Combat and Gore\kick.wav"),
    "snd_death_beast":       (P400, r"Combat and Gore\squelching_2.wav"),
    "snd_attack_fire":       (TOM,  r"Spells\Fireball 2.wav"),
    "snd_death_fire":        (TOM,  r"Spells\Firespray 1.wav"),
    "snd_attack_ice":        (TOM,  r"Spells\Ice Throw 1.wav"),
    "snd_death_ice":         (TOM,  r"Spells\Ice Freeze 2.wav"),
    "snd_attack_boss":       (TOM,  r"Attacks\Sword Attacks Hits and Blocks\Sword Impact Hit 3.wav"),
    "snd_attack_boss_2":     (P400, r"Weapons\harsh_thud.wav"),
    "snd_death_boss":        (P400, r"Combat and Gore\crunch_splat_2.wav"),
    # D. Casts (feed existing snd_cast_* slots)
    "snd_cast_elem":      (TOM,  r"Spells\Fireball 1.wav"),
    "snd_cast_elem_2":    (TOM,  r"Spells\Fireball 3.wav"),
    "snd_cast_void":      (P400, r"Other\ghost_long.wav"),
    "snd_cast_blood":     (P400, r"Combat and Gore\squelching_1.wav"),
    "snd_cast_blood_2":   (P400, r"Combat and Gore\squelching_3.wav"),
    "snd_cast_arcane":    (TOM,  r"Spells\Spell Impact 1.wav"),
    "snd_cast_arcane_2":  (TOM,  r"Spells\Spell Impact 2.wav"),
    "snd_cast_heal":      (P400, r"Musical Effects\music_box_chime_positive.wav"),
    "snd_cast_shield":    (TOM,  r"Spells\Rock Wall 1.wav"),
    "snd_cast_buff":      (TOM,  r"Spells\Firebuff 1.wav"),
    "snd_cast_buff_2":    (TOM,  r"Spells\Firebuff 2.wav"),
    "snd_cast_debuff":    (P400, r"Musical Effects\harpsichord_negative.wav"),
    # F. Musical stings (harpsichord = dungeon voice, music box = bond voice)
    "snd_sting_levelup":    (P400, r"Musical Effects\harpsichord_level_complete.wav"),
    "snd_sting_floor":      (P400, r"Musical Effects\music_box_chime_quick.wav"),
    "snd_sting_victory":    (P400, r"Musical Effects\harpsichord_positive_long.wav"),
    "snd_sting_defeat":     (P400, r"Musical Effects\harpsichord_defeated.wav"),
    "snd_sting_quest":      (P400, r"Musical Effects\harpsichord_chime_positive.wav"),
    "snd_sting_mystery":    (P400, r"Musical Effects\harpsichord_mystery.wav"),
    "snd_sting_heartbreak": (P400, r"Musical Effects\music_box_defeated.wav"),
    # E (pulled forward): equip + shop-buy feedback to break up Check_1/utility2
    "snd_equip":          (P400, r"Weapons\weapon_equip.wav"),
    "snd_buy":            (P400, r"Card and Board\dice_grab.wav"),   # M: dice rattle = great buy/sell noise
    "snd_pet_hatch":      (P400, r"Musical Effects\music_box_chime_positive.wav"),
    # Batch 2 - economy/items (SOUND_PASS_SPEC.md section E; imported 2026-07-07)
    "snd_gold":           (P400, r"Items\coins_gather_quick.wav"),        # treasure-room / chest gold
    "snd_potion":         (P400, r"Other\drink_slurp.wav"),               # combat consumable
    "snd_forge":          (P400, r"Weapons\weapon_upgrade.wav"),          # Dorn chit reforge
    "snd_rune_socket":    (P400, r"Items\gem_collect.wav"),               # Maren socketing
    "snd_page":           (P400, r"Items\page_turn.wav"),                 # journal/codex/tab switches
    "snd_chest":          (TOM,  r"Doors Gates and Chests\Chest Open 1.wav"),  # treasure reveal
    "snd_gate":           (TOM,  r"Doors Gates and Chests\Portcullis Gate.wav"),  # run start, floor 1
}

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
    """(duration_s, samplerate, channelFormat, bitDepth) with safe fallbacks."""
    try:
        with wave.open(path, "rb") as w:
            frames, rate = w.getnframes(), w.getframerate()
            return (round(frames / float(rate), 6), rate,
                    1 if w.getnchannels() >= 2 else 0,
                    0 if w.getsampwidth() == 1 else 1)
    except Exception:
        # Non-standard chunk layout: parse just the fmt chunk.
        try:
            with open(path, "rb") as f:
                data = f.read()
            i = data.find(b"fmt ")
            _, ch, rate, _, _, bits = struct.unpack("<HHIIHH", data[i + 8:i + 24])
            d = data.find(b"data")
            dur = struct.unpack("<I", data[d + 4:d + 8])[0] / float(rate * ch * (bits // 8))
            return (round(dur, 6), rate, 1 if ch >= 2 else 0, 0 if bits == 8 else 1)
        except Exception:
            return (1.0, 44100, 0, 1)


def main():
    yyp_path = os.path.join(ROOT, "Ironwake.yyp")
    with open(yyp_path, "r", encoding="utf-8") as f:
        yyp = f.read()

    created, skipped, missing = [], [], []
    for name in sorted(MANIFEST):
        pack, rel = MANIFEST[name]
        src = os.path.join(pack, rel)
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

    # Register in Ironwake.yyp: sounds are listed sorted case-insensitively, and
    # every snd_* name lands between "Selection" and "spell1".
    added = 0
    lines = yyp.split("\n")
    anchor = next(i for i, l in enumerate(lines)
                  if '"path":"sounds/Selection/Selection.yy"' in l)
    new_entries = [
        '    {{"id":{{"name":"{0}","path":"sounds/{0}/{0}.yy",}},}},'.format(n)
        for n in sorted(MANIFEST) if '"name":"{}","path":"sounds/'.format(n) not in yyp
    ]
    lines[anchor + 1:anchor + 1] = new_entries
    added = len(new_entries)
    if added:
        with open(yyp_path, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lines))

    print(f"created {len(created)}  skipped {len(skipped)}  yyp+{added}")
    if missing:
        print("MISSING SOURCES:")
        print("\n".join(missing))
        sys.exit(1)


if __name__ == "__main__":
    main()
