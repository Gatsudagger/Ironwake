#!/usr/bin/env python
# 08-12 icon batch (M approved all 10): 3 dueling relics + 4 mutator
# legendaries (spr_icon_legendary_<unique_effect>) + 3 mutator ability icons
# (names pre-wired in ability_icon_sprite). GM MUST BE CLOSED for --register.
import os, io, sys, uuid, shutil, urllib.request
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
YYP = os.path.join(ROOT, "Ironwake.yyp")
URL = "https://backblaze.pixellab.ai/file/pixellab-characters/objects/c50e1365-1a8c-44be-a773-5ee635581147/{}/rotations/unknown.png"

ICONS = [
    ("spr_icon_legendary_duel_pin",       "8eb3e426-31fe-43af-90e7-624eb35caa6a"),
    ("spr_icon_legendary_duel_parry",     "154f11fd-8a1d-463e-a553-1254ecb86c39"),
    ("spr_icon_legendary_duel_widow",     "f0d0efa1-79e6-4414-b5ec-985026ae8915"),
    ("spr_icon_legendary_stormskip_band", "f53f7bdd-cdc6-4f42-95b6-ad32105243f6"),
    ("spr_icon_legendary_twinned_prism",  "e4d48242-504f-4596-b8a6-93b9d6668396"),
    ("spr_icon_legendary_second_toll",    "03df1dc1-b45e-4a64-b986-f2564ea696d7"),
    ("spr_icon_legendary_smolderbrand",   "0c5e31ab-2432-4ce8-ba55-6ed781152157"),
    ("spr_ability_ricochet_shot",         "7d81457d-a3e4-4cbc-9f85-84a6e28f7968"),
    ("spr_ability_bouncing_bomb",         "298b322a-0ecb-4a19-91b8-f79c54491f77"),
    ("spr_ability_gout_of_rot",           "2a2af7ca-e10c-44de-835b-e06d9da815f0"),
]

def fetch(oid):
    req = urllib.request.Request(URL.format(oid), headers={"User-Agent": "Mozilla/5.0"})
    return Image.open(io.BytesIO(urllib.request.urlopen(req, timeout=120).read())).convert("RGBA")

def build(name, im):
    root = os.path.join(ROOT, "sprites", name)
    if os.path.isdir(root): shutil.rmtree(root)
    os.makedirs(root)
    W, H = im.size
    layer = str(uuid.uuid4()); fg = str(uuid.uuid4()); kg = str(uuid.uuid4())
    im.save(os.path.join(root, fg + ".png"))
    ld = os.path.join(root, "layers", fg); os.makedirs(ld)
    im.save(os.path.join(ld, layer + ".png"))
    yy = f'''{{
  "$GMSprite":"v2",
  "%Name":"{name}",
  "bboxMode":0,
  "bbox_bottom":{H-1},
  "bbox_left":0,
  "bbox_right":{W-1},
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
  "height":{H},
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
  "width":{W},
}}'''
    with open(os.path.join(root, name + ".yy"), "w", newline="\n") as f:
        f.write(yy)
    print(f"OK {name}: {W}x{H}")
    return True

def register_yyp(names):
    with open(YYP, "r", encoding="utf-8") as f:
        text = f.read()
    new_lines = []
    for n in names:
        if ('"name":"%s"' % n) in text:
            continue
        new_lines.append('    {"id":{"name":"%s","path":"sprites/%s/%s.yy",},},' % (n, n, n))
    if not new_lines:
        return 0
    marker = '  "resources":[\n'
    idx = text.index(marker) + len(marker)
    text = text[:idx] + "\n".join(new_lines) + "\n" + text[idx:]
    with open(YYP, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    return len(new_lines)

if __name__ == "__main__":
    ok = 0
    for name, oid in ICONS:
        if build(name, fetch(oid)): ok += 1
    print(f"built {ok}/{len(ICONS)}")
    if "--register" in sys.argv and ok == len(ICONS):
        print(f"yyp: +{register_yyp([n for n, _ in ICONS])} registered")
