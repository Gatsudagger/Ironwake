#!/usr/bin/env python
"""
VFX upgrade batch round 2 (08-11): unTied full Gigapack v2.8.0 + Super Pixel
Projectiles Pack 1, both PURCHASED by M 08-11. Picks per PROPOSAL_ROUND2.png -
M deferred to Claude's choices (S2 shadow smoke; darker blob_red for blood and
energy_violet for void per the flagged color quibbles; fireball REPLACES the
FXpack13 bolt art under the same sprite name).

Non-square frames are kept at native WxH (build_vfx_sprite_wh below) - the
square 0729 builder would have distorted the 96x48 fireball and 48x32 missiles.
Projectile/beam sprites face RIGHT (verified frame0000) - the combat Draw
rotates by point_direction with 0 degrees = right.

Run from repo root with GameMaker CLOSED (yyp write):
    python tools/import_vfx_upgrade_0811.py
"""
import os, sys, uuid
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_trait_icons import SPRITES, register_yyp
from import_combat_vfx_0729 import gm_running

GIG = r"C:\Asset_Library\effects\Super Pixel Effects Gigapack v2.8.0\Super Pixel Effects Gigapack\PNG"
PJ  = r"C:\Asset_Library\effects\Super Pixel Projectiles Pack 1\Super Pixel Projectiles Pack 1\PNG"

# sprite name -> (frame folder, frame cap). REBUILD names get their folder
# replaced in place (already yyp-registered); the rest are new registrations.
PICKS = {
    "spr_vfx_shadow2":    (os.path.join(GIG, "Smoke Bursts", "symmetrical_smoke_burst_002", "symmetrical_smoke_burst_002_large_violet"), 13),
    "spr_vfx_bolt_fire":  (os.path.join(PJ, "pj1_fireball_large_orange"), 12),   # REBUILD (was FXpack13)
    "spr_vfx_bolt_frost": (os.path.join(PJ, "pj1_magic_missile_large_blue"), 8),
    "spr_vfx_bolt_shock": (os.path.join(PJ, "pj1_electricity_large_yellow"), 16),
    "spr_vfx_bolt_arcane":(os.path.join(PJ, "pj1_magic_missile_large_violet"), 8),
    "spr_vfx_bolt_blood": (os.path.join(PJ, "pj1_blob_large_red"), 14),
    "spr_vfx_bolt_void":  (os.path.join(PJ, "pj1_energy_large_violet"), 8),
    "spr_vfx_bolt_shadow":(os.path.join(PJ, "pj1_blob_large_black"), 14),
    "spr_vfx_bolt_poison":(os.path.join(PJ, "pj1_energy_large_green"), 8),
    "spr_vfx_beam_violet":(os.path.join(PJ, "pj1_laser_large_violet"), 8),
    "spr_vfx_beam_green": (os.path.join(PJ, "pj1_laser_large_green"), 8),
}
REBUILD = {"spr_vfx_bolt_fire"}


def load_frames_native(folder, cap):
    files = sorted(f for f in os.listdir(folder) if f.endswith(".png"))
    n = len(files)
    if n > cap:
        files = [files[round(i * (n - 1) / (cap - 1))] for i in range(cap)]
    return [Image.open(os.path.join(folder, f)).convert("RGBA") for f in files]


def build_vfx_sprite_wh(name, frames):
    """import_combat_vfx_0729.build_vfx_sprite generalized to native WxH."""
    w, h = frames[0].size
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
  "bbox_bottom":{h-1},
  "bbox_left":0,
  "bbox_right":{w-1},
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
  "height":{h},
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
  "width":{w},
}}'''
    with open(os.path.join(root, name + ".yy"), "w", newline="\n") as f:
        f.write(yy)
    return n, w, h


def main():
    if gm_running():
        sys.exit("ABORT: GameMaker is running - close it first (yyp write).")

    import shutil
    print("VFX upgrade round 2 (11 sprites from purchased unTied packs, 0 gens):")
    new = []
    for name, (folder, cap) in PICKS.items():
        exists = os.path.isdir(os.path.join(SPRITES, name))
        if exists and name not in REBUILD:
            print(f"  {name} already exists - skipped")
            continue
        if exists and name in REBUILD:
            shutil.rmtree(os.path.join(SPRITES, name))
        frames = load_frames_native(folder, cap)
        n, w, h = build_vfx_sprite_wh(name, frames)
        print(f"  {name}: {n} frames {w}x{h}  <-  {os.path.basename(folder)}"
              + ("  (REBUILT in place)" if name in REBUILD else ""))
        if not exists:
            new.append(name)
    if new:
        register_yyp(new)
        print(f"registered {len(new)} new sprites (rebuilds keep their yyp entry)")
    print("Done.")


if __name__ == "__main__":
    main()
