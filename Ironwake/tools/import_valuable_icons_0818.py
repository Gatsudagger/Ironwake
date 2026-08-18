"""Import the 08-18 M-picked VALUABLE icons as GameMaker sprites (GM must be CLOSED, or
reopen the project after). 5 sprites: spr_icon_valuable_<id> from _for_review/valuables_0818,
same .yy clone + yyp registration as import_icons_0815. __sprite_includes refs are added
in obj_game_controller Create_0 (string-ref strip gotcha).
"""
import os
import re
import uuid

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REV = os.path.join(ROOT, "_for_review", "valuables_0818")
SPRITES = os.path.join(ROOT, "sprites")
YYP = os.path.join(ROOT, "Ironwake.yyp")

IMPORTS = [
    ("spr_icon_valuable_tarnished_locket",  "tarnished_locket_00.png"),
    ("spr_icon_valuable_silver_reliquary",  "silver_reliquary_12.png"),
    ("spr_icon_valuable_sovereigns_signet", "sovereigns_signet_01.png"),
    ("spr_icon_valuable_star_iron_idol",    "star_iron_idol_03.png"),
    ("spr_icon_valuable_crown_shard",       "crown_shard_04.png"),
]

YY_TEMPLATE = """{{
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
    {{"$GMSpriteFrame":"v1","%Name":"{frame}","name":"{frame}","resourceType":"GMSpriteFrame","resourceVersion":"2.0",}},
  ],
  "gridX":0,
  "gridY":0,
  "height":64,
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
                "0":{{"$SpriteFrameKeyframe":"","Id":{{"name":"{frame}","path":"sprites/{name}/{name}.yy",}},"resourceType":"SpriteFrameKeyframe","resourceVersion":"2.0",}},
              }},"Disabled":false,"id":"{keyid}","IsCreationKey":false,"Key":0.0,"Length":1.0,"resourceType":"Keyframe<SpriteFrameKeyframe>","resourceVersion":"2.0","Stretch":false,}},
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
}}"""


def make_sprite(name, src_png):
    src = os.path.join(REV, src_png)
    im = Image.open(src).convert("RGBA")
    if im.size != (64, 64):
        im = im.resize((64, 64), Image.NEAREST)
    frame, layer, keyid = str(uuid.uuid4()), str(uuid.uuid4()), str(uuid.uuid4())
    d = os.path.join(SPRITES, name)
    if os.path.exists(os.path.join(d, name + ".yy")):
        print(f"SKIP (exists): {name}")
        return False
    os.makedirs(os.path.join(d, "layers", frame), exist_ok=True)
    im.save(os.path.join(d, frame + ".png"))
    im.save(os.path.join(d, "layers", frame, layer + ".png"))
    with open(os.path.join(d, name + ".yy"), "w", encoding="utf-8", newline="\n") as f:
        f.write(YY_TEMPLATE.format(name=name, frame=frame, layer=layer, keyid=keyid))
    return True


def register_yyp(names):
    with open(YYP, encoding="utf-8") as f:
        lines = f.readlines()
    entry_re = re.compile(r'^    \{"id":\{"name":"([^"]+)","path":"')
    for name in names:
        new_line = f'    {{"id":{{"name":"{name}","path":"sprites/{name}/{name}.yy",}},}},\n'
        if any(f'"name":"{name}"' in ln for ln in lines):
            print(f"SKIP yyp (exists): {name}")
            continue
        ins = None
        for i, ln in enumerate(lines):
            m = entry_re.match(ln)
            if m and m.group(1) > name:
                ins = i
                break
        if ins is None:  # append after the last entry line
            last = max(i for i, ln in enumerate(lines) if entry_re.match(ln))
            ins = last + 1
        lines.insert(ins, new_line)
    with open(YYP, "w", encoding="utf-8", newline="\n") as f:
        f.writelines(lines)


made = []
for name, png in IMPORTS:
    if make_sprite(name, png):
        made.append(name)
        print("imported", name)
register_yyp([n for n, _ in IMPORTS])
print(f"{len(made)} sprites created + registered in yyp")
