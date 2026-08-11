#!/usr/bin/env python
"""
Cursed Rebirth ceremony scene (08-04, M picked candidate A of 4 PixelLab gens):
the spectral hand rising from Sable's dark cauldron. One 160x160 frame,
origin 0 (top-left - the hub Draw crops it with draw_sprite_part_ext for the
hand-reveal). String-referenced (asset_get_index) from obj_hub_controller
Draw_64, so it ALSO needs a global.__sprite_includes entry (done in .gml).

Run from repo root with GameMaker CLOSED:
    python tools/import_cursed_ritual_scene.py
"""
import os, sys, uuid, subprocess
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_trait_icons import ROOT, SPRITES, register_yyp

NAME = "spr_scene_cursed_ritual"
SRC  = os.path.join(ROOT, "_for_review", "cursed_ritual_scene_A.png")
SIZE = 160


def gm_running():
    out = subprocess.run(["tasklist"], capture_output=True, text=True).stdout.lower()
    return any(("gamemaker" in ln and "link-proxy" not in ln) for ln in out.splitlines())


def build_scene_sprite(name, im):
    root = os.path.join(SPRITES, name)
    os.makedirs(root, exist_ok=True)
    layer_guid = str(uuid.uuid4())
    fg = str(uuid.uuid4())
    kg = str(uuid.uuid4())
    im.save(os.path.join(root, fg + ".png"))
    ld = os.path.join(root, "layers", fg)
    os.makedirs(ld, exist_ok=True)
    im.save(os.path.join(ld, layer_guid + ".png"))
    mx = SIZE - 1
    yy = f'''{{
  "$GMSprite":"v2",
  "%Name":"{name}",
  "bboxMode":0,
  "bbox_bottom":{mx},
  "bbox_left":0,
  "bbox_right":{mx},
  "bbox_top":0,
  "collisionKind":1,
  "collisionTolerance":0,
  "DynamicTexturePage":false,
  "edgeFiltering":false,
  "For3D":false,
  "frames":[
    {{"$GMSpriteFrame":"v1","%Name":"{fg}","name":"{fg}","resourceType":"GMSpriteFrame","resourceVersion":"2.0",}},
  ],
  "gridX":0,
  "gridY":0,
  "height":{SIZE},
  "HTile":false,
  "layers":[
    {{"$GMImageLayer":"","%Name":"{layer_guid}","blendMode":0,"displayName":"default","isLocked":false,"name":"{layer_guid}","opacity":100.0,"resourceType":"GMImageLayer","resourceVersion":"2.0","visible":true,}},
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
    "length":1.0,
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
            {{"$Keyframe<SpriteFrameKeyframe>":"","Channels":{{
                "0":{{"$SpriteFrameKeyframe":"","Id":{{"name":"{fg}","path":"sprites/{name}/{name}.yy",}},"resourceType":"SpriteFrameKeyframe","resourceVersion":"2.0",}},
              }},"Disabled":false,"id":"{kg}","IsCreationKey":false,"Key":0.0,"Length":1.0,"resourceType":"Keyframe<SpriteFrameKeyframe>","resourceVersion":"2.0","Stretch":false,}},
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
  "width":{SIZE},
}}'''
    with open(os.path.join(root, name + ".yy"), "w", newline="\n") as f:
        f.write(yy)


if gm_running():
    sys.exit("ABORT: GameMaker is running - close it first (yyp write).")

if os.path.isdir(os.path.join(SPRITES, NAME)):
    sys.exit(f"{NAME} already exists - nothing to do.")

im = Image.open(SRC).convert("RGBA")
if im.size != (SIZE, SIZE):
    im = im.resize((SIZE, SIZE), Image.NEAREST)
build_scene_sprite(NAME, im)
register_yyp([NAME])
print(f"built + registered {NAME} (1 frame, {SIZE}x{SIZE}, origin top-left)")
print("REMINDER: global.__sprite_includes entry is added in gc Create (string-ref).")
