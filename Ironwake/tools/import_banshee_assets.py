#!/usr/bin/env python3
"""Banshee in a Bottle asset import (BANSHEE_BOTTLE_SPEC.md, 07-15).

Sounds (_for_review/*.mp3, ElevenLabs):
- 3 jukebox tracks (music_v2, ~2min, composed to resolve back to their opening
  bars) -> loudnorm -14 LUFS (music level; atmo beds use -16) -> OGG. NO loop
  restructure - unlike the ambience beds these are composed music, the wrap
  point is authored. F5 audition should listen for the seam anyway.
- snd_banshee_scream (release-ceremony stinger) -> loudnorm -16 like the other
  stingers. Register by hand in audio_sfx_assets() (done in the same batch).

Sprites (_for_review/banshee/, PixelLab object e3e9b9d5, M picked candidate [1]):
- spr_icon_banshee_bottle: 64px single frame (gen_trait_icons template).
- spr_banshee_release: 17 frames 128px (v3 animate_object, custom 128 start
  frame). Multi-frame .yy built to the spr_vfx_impact structure; the release
  popup indexes frames manually so playbackSpeed is nominal (12).
Both are referenced by identifier in code - no __sprite_includes entry needed.

Idempotent: skips sounds/sprites whose folder already exists.
Run from repo root:  python tools/import_banshee_assets.py
"""
import os, shutil, struct, subprocess, sys, uuid
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_trait_icons import ROOT, SPRITES, YY_TEMPLATE, register_yyp

REVIEW = os.path.join(ROOT, "_for_review")

# name -> (source mp3 basename, LUFS target)
SOUNDS = {
    "snd_music_hub_1":     ("music__20260715_000511.mp3",   -14),  # "Rainlight" (hub, M-approved 07-15)
    "snd_music_hub_2":     ("music__20260715_010001.mp3",   -14),  # "Emberside" (hub)
    "snd_music_dungeon_1": ("music__20260715_010033.mp3",   -14),  # "The Long Dark" (dungeon)
    "snd_banshee_scream":  ("sfx_A_gho_20260715_010058.mp3", -16),  # release ceremony wail
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

ANIM_FRAME = ('    {{"$GMSpriteFrame":"v1","%Name":"{fid}","name":"{fid}",'
              '"resourceType":"GMSpriteFrame","resourceVersion":"2.0",}},')

ANIM_KEYFRAME = ('            {{"$Keyframe<SpriteFrameKeyframe>":"","Channels":{{\n'
                 '                "0":{{"$SpriteFrameKeyframe":"","Id":{{"name":"{fid}",'
                 '"path":"sprites/{name}/{name}.yy",}},"resourceType":"SpriteFrameKeyframe",'
                 '"resourceVersion":"2.0",}},\n'
                 '              }},"Disabled":false,"id":"{kid}","IsCreationKey":false,'
                 '"Key":{key:.1f},"Length":1.0,"resourceType":"Keyframe<SpriteFrameKeyframe>",'
                 '"resourceVersion":"2.0","Stretch":false,}},')

ANIM_YY = """{{
  "$GMSprite":"v2",
  "%Name":"{name}",
  "bboxMode":0,
  "bbox_bottom":{bb},
  "bbox_left":0,
  "bbox_right":{br},
  "bbox_top":0,
  "collisionKind":1,
  "collisionTolerance":0,
  "DynamicTexturePage":false,
  "edgeFiltering":false,
  "For3D":false,
  "frames":[
{frames}
  ],
  "gridX":0,
  "gridY":0,
  "height":{h},
  "HTile":false,
  "layers":[
    {{"$GMImageLayer":"","%Name":"{layer}","blendMode":0,"displayName":"default","isLocked":false,"name":"{layer}","opacity":100.0,"resourceType":"GMImageLayer","resourceVersion":"2.0","visible":true,}},
  ],
  "name":"{name}",
  "nineSlice":null,
  "origin":0,
  "parent":{{
    "name":"Ironwake",
    "path":"Ironwake.yyp",
  }},
  "preMultiplyAlpha":false,
  "resourceType":"GMSprite",
  "resourceVersion":"2.0",
  "sequence":{{
    "$GMSequence":"v1",
    "%Name":"{name}",
    "autoRecord":true,
    "backdropHeight":768,
    "backdropImageOpacity":0.5,
    "backdropImagePath":"",
    "backdropWidth":1366,
    "backdropXOffset":0.0,
    "backdropYOffset":0.0,
    "events":{{
      "$KeyframeStore<MessageEventKeyframe>":"",
      "Keyframes":[],
      "resourceType":"KeyframeStore<MessageEventKeyframe>",
      "resourceVersion":"2.0",
    }},
    "eventStubScript":null,
    "eventToFunction":{{}},
    "length":{count}.0,
    "lockOrigin":false,
    "moments":{{
      "$KeyframeStore<MomentsEventKeyframe>":"",
      "Keyframes":[],
      "resourceType":"KeyframeStore<MomentsEventKeyframe>",
      "resourceVersion":"2.0",
    }},
    "name":"{name}",
    "playback":1,
    "playbackSpeed":12.0,
    "playbackSpeedType":0,
    "resourceType":"GMSequence",
    "resourceVersion":"2.0",
    "showBackdrop":true,
    "showBackdropImage":false,
    "timeUnits":1,
    "tracks":[
      {{"$GMSpriteFramesTrack":"","builtinName":0,"events":[],"inheritsTrackColour":true,"interpolation":1,"isCreationTrack":false,"keyframes":{{"$KeyframeStore<SpriteFrameKeyframe>":"","Keyframes":[
{keyframes}
          ],"resourceType":"KeyframeStore<SpriteFrameKeyframe>","resourceVersion":"2.0",}},"modifiers":[],"name":"frames","resourceType":"GMSpriteFramesTrack","resourceVersion":"2.0","spriteId":null,"trackColour":0,"tracks":[],"traits":0,}},
    ],
    "visibleRange":null,
    "volume":1.0,
    "xorigin":0,
    "yorigin":0,
  }},
  "swatchColours":null,
  "swfPrecision":0.5,
  "textureGroupId":{{
    "name":"Default",
    "path":"texturegroups/Default",
  }},
  "type":0,
  "VTile":false,
  "width":{w},
}}
"""


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


def import_sounds():
    ff = ffmpeg_exe()
    tmp = os.path.join(REVIEW, "_proc_banshee")
    os.makedirs(tmp, exist_ok=True)
    created = []
    for name, (src_base, lufs) in SOUNDS.items():
        folder = os.path.join(ROOT, "sounds", name)
        if os.path.isfile(os.path.join(folder, name + ".yy")):
            print("skip (exists):", name)
            continue
        mp3 = os.path.join(REVIEW, src_base)
        if not os.path.isfile(mp3):
            print("MISSING SOURCE:", mp3)
            sys.exit(1)
        ogg = os.path.join(tmp, name + ".ogg")
        if not os.path.isfile(ogg):
            norm = os.path.join(tmp, name + "_norm.wav")
            subprocess.run([ff, "-y", "-loglevel", "error", "-i", mp3,
                            "-af", "loudnorm=I=%d:TP=-1.5:LRA=11" % lufs,
                            "-ar", "44100", norm], check=True)
            subprocess.run([ff, "-y", "-loglevel", "error", "-i", norm,
                            "-c:a", "libvorbis", "-q:a", "5", ogg], check=True)
        os.makedirs(folder, exist_ok=True)
        shutil.copyfile(ogg, os.path.join(folder, name + ".ogg"))
        dur, rate, chans = ogg_params(ogg)
        with open(os.path.join(folder, name + ".yy"), "w", encoding="utf-8") as f:
            f.write(SND_YY.format(name=name, duration=dur, samplerate=rate,
                                  channels=chans, ext="ogg") + "\n")
        print("imported %s (%ss)" % (name, dur))
        created.append(name)
    return created


def build_icon():
    name = "spr_icon_banshee_bottle"
    if os.path.isdir(os.path.join(SPRITES, name)):
        print("skip (exists):", name)
        return []
    img = Image.open(os.path.join(REVIEW, "banshee", "icon_bottle.png")).convert("RGBA")
    assert img.size == (64, 64), img.size
    sdir = os.path.join(SPRITES, name)
    frame = str(uuid.uuid4()); layer = str(uuid.uuid4()); kfid = str(uuid.uuid4())
    os.makedirs(os.path.join(sdir, "layers", frame), exist_ok=True)
    img.save(os.path.join(sdir, frame + ".png"))
    img.save(os.path.join(sdir, "layers", frame, layer + ".png"))
    yy = YY_TEMPLATE.format(name=name, frame=frame, layer=layer, kfid=kfid,
                            w=64, h=64, br=63, bb=63)
    with open(os.path.join(sdir, name + ".yy"), "w", newline="\n") as f:
        f.write(yy)
    print("built", name)
    return [name]


def build_release_anim():
    name = "spr_banshee_release"
    if os.path.isdir(os.path.join(SPRITES, name)):
        print("skip (exists):", name)
        return []
    src_dir = os.path.join(REVIEW, "banshee", "anim")
    count = 17
    sdir = os.path.join(SPRITES, name)
    layer = str(uuid.uuid4())
    frame_lines, kf_lines = [], []
    for i in range(count):
        img = Image.open(os.path.join(src_dir, "%d.png" % i)).convert("RGBA")
        assert img.size == (128, 128), (i, img.size)
        fid = str(uuid.uuid4())
        os.makedirs(os.path.join(sdir, "layers", fid), exist_ok=True)
        img.save(os.path.join(sdir, fid + ".png"))
        img.save(os.path.join(sdir, "layers", fid, layer + ".png"))
        frame_lines.append(ANIM_FRAME.format(fid=fid))
        kf_lines.append(ANIM_KEYFRAME.format(fid=fid, name=name,
                                             kid=str(uuid.uuid4()), key=float(i)))
    yy = ANIM_YY.format(name=name, frames="\n".join(frame_lines),
                        keyframes="\n".join(kf_lines), layer=layer,
                        count=count, w=128, h=128, br=127, bb=127)
    with open(os.path.join(sdir, name + ".yy"), "w", newline="\n") as f:
        f.write(yy)
    print("built %s (%d frames)" % (name, count))
    return [name]


def register_sounds_yyp(created):
    if not created:
        return 0
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
    return len(new)


def main():
    snd = import_sounds()
    n_snd = register_sounds_yyp(snd)
    spr = build_icon() + build_release_anim()
    n_spr = register_yyp(spr)
    print("sounds: %d imported (+%d yyp)   sprites: %d built (+%d yyp)"
          % (len(snd), n_snd, len(spr), n_spr))


if __name__ == "__main__":
    main()
