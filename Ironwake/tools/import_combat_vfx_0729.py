#!/usr/bin/env python
"""
Combat VFX trial batch (07-29, M approved "Mix: owned + a few gens" / "Buffs +
attacks ~10 fx" - all 9 came from OWNED packs, 0 gens):

  Splits the one-sprite-for-everything self-buff (spr_vfx_buff sword+) into
  shield / haste / resource-gain / dark-status bursts, and adds school-keyed
  attack impacts (frost/shock/poison/blood/shadow). Resolved in .gml by
  ability_attack_vfx / ability_support_vfx (scr_abilities).

Builds N-frame 64x64 sprites (origin 4, same shape as spr_vfx_fire) from local
pack frames + registers them in the .yyp. GM MUST BE CLOSED (yyp write).
VFX sprites are referenced by bare identifier in .gml - no __sprite_includes
entry needed.

Run from repo root with GameMaker CLOSED:
    python tools/import_combat_vfx_0729.py
"""
import os, sys, uuid, subprocess
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_trait_icons import ROOT, SPRITES, register_yyp

EFF = r"C:\Asset_Library\effects"
GIG = os.path.join(EFF, "Super Pixel Effects Gigapack (Free Version) v2.5.0",
                   "Super Pixel Effects Gigapack (Free Version)", "PNG")
NEC = os.path.join(EFF, "Pixel Art VFX - Necromancer - FREE Version")

# sprite name -> (source frame folder, max frames after uniform subsample)
PICKS = {
    # -- support / self-cast bursts --
    "spr_vfx_shield": (os.path.join(GIG, "Fantasy Spells", "spell_defense_up_001", "spell_defense_up_001_large_blue"), 18),
    "spr_vfx_haste":  (os.path.join(GIG, "Fantasy Spells", "spell_haste_001",      "spell_haste_001_large_green"),      16),
    "spr_vfx_gain":   (os.path.join(GIG, "Fantasy Spells", "spell_absorb_001",     "spell_absorb_001_large_violet"),    16),
    "spr_vfx_dark":   (os.path.join(GIG, "Smoke Bursts",   "stylized_skull_smoke_burst_001", "stylized_skull_smoke_burst_001_large_white"), 12),
    # -- school-keyed attack impacts --
    "spr_vfx_frost":  (os.path.join(GIG, "Magic Bursts", "round_sparkle_burst_001", "round_sparkle_burst_001_large_blue"),   14),
    "spr_vfx_shock":  (os.path.join(GIG, "Lightning",    "lightning_burst_002",     "lightning_burst_002_large_violet"),      9),
    "spr_vfx_poison": (os.path.join(GIG, "Fantasy Spells", "spell_poison_001",      "spell_poison_001_large_green"),         17),
    "spr_vfx_blood":  (os.path.join(GIG, "Splatters",    "burst_splatter_001",      "burst_splatter_001_large_red"),         10),
    "spr_vfx_shadow": (os.path.join(NEC, "VFX 2", "Frames"), 7),
}


def gm_running():
    out = subprocess.run(["tasklist"], capture_output=True, text=True).stdout.lower()
    return any(("gamemaker" in ln and "link-proxy" not in ln) for ln in out.splitlines())


def load_frames(folder, cap):
    files = sorted(f for f in os.listdir(folder) if f.endswith(".png"))
    n = len(files)
    if n > cap:  # uniform subsample - Draw maps timer progress onto frames anyway
        files = [files[round(i * (n - 1) / (cap - 1))] for i in range(cap)]
    out = []
    for f in files:
        im = Image.open(os.path.join(folder, f)).convert("RGBA")
        if im.size != (64, 64):
            im = im.resize((64, 64), Image.NEAREST)
        out.append(im)
    return out


def build_vfx_sprite(name, frames):
    """spr_vfx_fire-shaped .yy: 64x64, origin 4, one keyframe per frame."""
    root = os.path.join(SPRITES, name)
    os.makedirs(root, exist_ok=True)
    layer_guid = str(uuid.uuid4())
    frame_guids, kf_guids = [], []
    for im in frames:
        fg = str(uuid.uuid4()); frame_guids.append(fg); kf_guids.append(str(uuid.uuid4()))
        im.save(os.path.join(root, fg + ".png"))
        ld = os.path.join(root, "layers", fg); os.makedirs(ld, exist_ok=True)
        im.save(os.path.join(ld, layer_guid + ".png"))
    n = len(frame_guids)
    frames_json = ",\n".join(
        f'    {{"$GMSpriteFrame":"v1","%Name":"{g}","name":"{g}","resourceType":"GMSpriteFrame","resourceVersion":"2.0",}}'
        for g in frame_guids) + ","
    kfs = []
    for i, (fg, kg) in enumerate(zip(frame_guids, kf_guids)):
        kfs.append(
            '            {"$Keyframe<SpriteFrameKeyframe>":"","Channels":{\n'
            f'                "0":{{"$SpriteFrameKeyframe":"","Id":{{"name":"{fg}","path":"sprites/{name}/{name}.yy",}},"resourceType":"SpriteFrameKeyframe","resourceVersion":"2.0",}},\n'
            f'              }},"Disabled":false,"id":"{kg}","IsCreationKey":false,"Key":{float(i)},"Length":1.0,"resourceType":"Keyframe<SpriteFrameKeyframe>","resourceVersion":"2.0","Stretch":false,}}')
    kfs_json = ",\n".join(kfs) + ","
    yy = f'''{{
  "$GMSprite":"v2",
  "%Name":"{name}",
  "bboxMode":0,
  "bbox_bottom":63,
  "bbox_left":0,
  "bbox_right":63,
  "bbox_top":0,
  "collisionKind":1,
  "collisionTolerance":0,
  "DynamicTexturePage":false,
  "edgeFiltering":false,
  "For3D":false,
  "frames":[
{frames_json}
  ],
  "gridX":0,
  "gridY":0,
  "height":64,
  "HTile":false,
  "layers":[
    {{"$GMImageLayer":"","%Name":"{layer_guid}","blendMode":0,"displayName":"default","isLocked":false,"name":"{layer_guid}","opacity":100.0,"resourceType":"GMImageLayer","resourceVersion":"2.0","visible":true,}},
  ],
  "name":"{name}",
  "nineSlice":null,
  "origin":4,
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
    "length":{float(n)},
    "lockOrigin":false,
    "moments":{{
      "$KeyframeStore<MomentsEventKeyframe>":"",
      "Keyframes":[],
      "resourceType":"KeyframeStore<MomentsEventKeyframe>",
      "resourceVersion":"2.0",
    }},
    "name":"{name}",
    "playback":1,
    "playbackSpeed":1.0,
    "playbackSpeedType":0,
    "resourceType":"GMSequence",
    "resourceVersion":"2.0",
    "showBackdrop":true,
    "showBackdropImage":false,
    "timeUnits":1,
    "tracks":[
      {{"$GMSpriteFramesTrack":"","builtinName":0,"events":[],"inheritsTrackColour":true,"interpolation":1,"isCreationTrack":false,"keyframes":{{"$KeyframeStore<SpriteFrameKeyframe>":"","Keyframes":[
{kfs_json}
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
  "width":64,
}}'''
    with open(os.path.join(root, name + ".yy"), "w", newline="\n") as f:
        f.write(yy)
    return n


if gm_running():
    sys.exit("ABORT: GameMaker is running - close it first (yyp write).")

print("Combat VFX trial batch (9 sprites from owned packs):")
new = []
for name, (folder, cap) in PICKS.items():
    if os.path.isdir(os.path.join(SPRITES, name)):
        print(f"  {name} already exists - skipped")
        continue
    frames = load_frames(folder, cap)
    n = build_vfx_sprite(name, frames)
    print(f"  {name}: {n} frames  <-  {os.path.basename(folder)}")
    new.append(name)
if new:
    register_yyp(new)
    print(f"built + registered {len(new)} sprites (bare-identifier refs, no __sprite_includes needed)")
print("Done.")
