#!/usr/bin/env python
# Ashen Duelist redesign import (08-12, M approved base + all 3 tiers):
# spectral fencer 5-frame south idles, 244px chars downscaled exactly /2 to
# 122px (NPC band). Replaces spr_ashen_duelist; adds _t1/_t2/_t3 (registered
# in .yyp; string-resolved by duelist_sprite_for -> also added to
# global.__sprite_includes). GM MUST BE CLOSED.
import os, io, sys, uuid, shutil, urllib.request
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
YYP = os.path.join(ROOT, "Ironwake.yyp")
CH = ("https://backblaze.pixellab.ai/file/pixellab-characters/"
      "c50e1365-1a8c-44be-a773-5ee635581147/{}/animations/{}/south/{}.png")

SPRITES = [
    ("spr_ashen_duelist",    "77b28522-59db-49b7-a95a-5862a4ce51d2", "9641496e-e1c3-4ac5-93fc-38c6d29e6fc8"),
    ("spr_ashen_duelist_t1", "f84dd918-0080-41f8-a304-707a7936a468", "ba2b3352-a95a-457b-9053-2c0d591b5363"),
    ("spr_ashen_duelist_t2", "4963082f-f40b-419e-be53-bf19a49f10ae", "97f68833-c8aa-49df-88c2-5cdf7db38ce0"),
    ("spr_ashen_duelist_t3", "2bcbd382-311b-4f24-bd72-f75c086692e4", "797d2109-a784-4189-9eed-ff5a977e7d3d"),
]

def fetch_frame(cid, aid, i):
    req = urllib.request.Request(CH.format(cid, aid, i), headers={"User-Agent": "Mozilla/5.0"})
    im = Image.open(io.BytesIO(urllib.request.urlopen(req, timeout=120).read())).convert("RGBA")
    return im.resize((im.width // 2, im.height // 2), Image.NEAREST)

def build(name, frames):
    root = os.path.join(ROOT, "sprites", name)
    if os.path.isdir(root): shutil.rmtree(root)
    os.makedirs(root)
    layer = str(uuid.uuid4())
    fgs, kgs = [], []
    W, H = frames[0].size
    for im in frames:
        fg = str(uuid.uuid4()); fgs.append(fg); kgs.append(str(uuid.uuid4()))
        im.save(os.path.join(root, fg + ".png"))
        ld = os.path.join(root, "layers", fg); os.makedirs(ld)
        im.save(os.path.join(ld, layer + ".png"))
    n = len(fgs)
    fr = ",\n".join(
        f'    {{"$GMSpriteFrame":"v1","%Name":"{g}","name":"{g}","resourceType":"GMSpriteFrame","resourceVersion":"2.0",}}'
        for g in fgs) + ","
    kfs = []
    for i, (fg, kg) in enumerate(zip(fgs, kgs)):
        kfs.append('            {"$Keyframe<SpriteFrameKeyframe>":"","Channels":{\n'
            f'                "0":{{"$SpriteFrameKeyframe":"","Id":{{"name":"{fg}","path":"sprites/{name}/{name}.yy",}},"resourceType":"SpriteFrameKeyframe","resourceVersion":"2.0",}},\n'
            f'              }},"Disabled":false,"id":"{kg}","IsCreationKey":false,"Key":{float(i)},"Length":1.0,"resourceType":"Keyframe<SpriteFrameKeyframe>","resourceVersion":"2.0","Stretch":false,}}')
    kfs = ",\n".join(kfs) + ","
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
{fr}
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
    "playbackSpeed":8.0,
    "playbackSpeedType":0,
    "resourceType":"GMSequence",
    "resourceVersion":"2.0",
    "showBackdrop":true,
    "showBackdropImage":false,
    "timeUnits":1,
    "tracks":[
      {{"$GMSpriteFramesTrack":"","builtinName":0,"events":[],"inheritsTrackColour":true,"interpolation":1,"isCreationTrack":false,"keyframes":{{"$KeyframeStore<SpriteFrameKeyframe>":"","Keyframes":[
{kfs}
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
    print(f"OK {name}: {W}x{H} x{n}f")
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
    for name, cid, aid in SPRITES:
        frames = [fetch_frame(cid, aid, i) for i in range(5)]
        if build(name, frames): ok += 1
    print(f"built {ok}/{len(SPRITES)}")
    if "--register" in sys.argv and ok == len(SPRITES):
        print(f"yyp: +{register_yyp([n for n, _, _ in SPRITES])} registered")
