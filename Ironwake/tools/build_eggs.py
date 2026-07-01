#!/usr/bin/env python
# Build GameMaker sprites for the 4 themed hatch eggs:
#   spr_pet_egg_<type>        - 1-frame static egg (rotations/unknown.png)
#   spr_pet_egg_<type>_hatch  - 9-frame crack/hatch animation
# Bottom-center origin, matching the pet sprite convention. Run from the Ironwake root.
import os, uuid, urllib.request, io
from PIL import Image

PROJECT = "c50e1365-1a8c-44be-a773-5ee635581147"
STATIC = "https://backblaze.pixellab.ai/file/pixellab-characters/objects/{proj}/{id}/rotations/unknown.png"
ANIM   = "https://backblaze.pixellab.ai/file/pixellab-characters/objects/{proj}/{id}/animations/{grp}/unknown/{i}.png"

# (type, object_id, hatch_subgroup)
EGGS = [
 ("gilded",  "626f9d87-ccff-4eb4-8f16-a26b52b17389", "d6c421de-a358-46a2-8f73-ab813dfa7209"),
 ("fortune", "30c71294-f198-4c19-be33-ff3e9193740e", "ccd5d3b0-a30f-4e09-bf96-7cd32f18ce22"),
 ("savage",  "c3d00d12-6a45-4443-839c-34dc4065ccd9", "f24d2faf-df13-40f9-b6b9-b97affbdbec9"),
 ("tender",  "b9ade0f8-cf69-4026-8f6b-d7e18cef132d", "736aa94a-a18b-4081-a496-89b11ca21696"),
]
HATCH_FRAMES = 9

def dl(url):
    req = urllib.request.Request(url, headers={"User-Agent":"Mozilla/5.0"})
    return Image.open(io.BytesIO(urllib.request.urlopen(req, timeout=60).read())).convert("RGBA")

def build(name, urls):
    root = os.path.join("sprites", name)
    os.makedirs(root, exist_ok=True)
    layer_guid = str(uuid.uuid4())
    frame_guids, kf_guids = [], []
    W = H = None
    for url in urls:
        im = dl(url)
        if W is None: W,H = im.size
        fg = str(uuid.uuid4()); frame_guids.append(fg); kf_guids.append(str(uuid.uuid4()))
        im.save(os.path.join(root, fg+".png"))
        ld = os.path.join(root,"layers",fg); os.makedirs(ld, exist_ok=True)
        im.save(os.path.join(ld, layer_guid+".png"))
    n = len(urls)
    frames = ",\n".join(
        f'    {{"$GMSpriteFrame":"v1","%Name":"{g}","name":"{g}","resourceType":"GMSpriteFrame","resourceVersion":"2.0",}}'
        for g in frame_guids) + ","
    kfs=[]
    for i,(fg,kg) in enumerate(zip(frame_guids,kf_guids)):
        kfs.append('            {"$Keyframe<SpriteFrameKeyframe>":"","Channels":{\n'
            f'                "0":{{"$SpriteFrameKeyframe":"","Id":{{"name":"{fg}","path":"sprites/{name}/{name}.yy",}},"resourceType":"SpriteFrameKeyframe","resourceVersion":"2.0",}},\n'
            f'              }},"Disabled":false,"id":"{kg}","IsCreationKey":false,"Key":{float(i)},"Length":1.0,"resourceType":"Keyframe<SpriteFrameKeyframe>","resourceVersion":"2.0","Stretch":false,}}')
    kfs = ",\n".join(kfs)+","
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
{frames}
  ],
  "gridX":0,
  "gridY":0,
  "height":{H},
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
    "xorigin":{W//2},
    "yorigin":{H-1},
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
    with open(os.path.join(root, name+".yy"),"w",newline="\n") as f:
        f.write(yy)
    print(f"OK {name}: {W}x{H} x{n}f")

if __name__ == "__main__":
    for etype, oid, grp in EGGS:
        build(f"spr_pet_egg_{etype}", [STATIC.format(proj=PROJECT, id=oid)])
        build(f"spr_pet_egg_{etype}_hatch",
              [ANIM.format(proj=PROJECT, id=oid, grp=grp, i=i) for i in range(HATCH_FRAMES)])
