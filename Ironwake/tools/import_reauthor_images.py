#!/usr/bin/env python
# Batch-1 re-author import (08-12): image-pipeline sprites for null_hound /
# pyre_bison / stormkirin (the object-pipeline stages go through
# build_pets_expansion.py CFG instead). Fetches each animate_image job's
# frames (0..8, frame 0 = the M-approved re-render), pads 84->85 for babies,
# rebuilds the existing sprite folder in place (no .yyp change needed).
# GM MUST BE CLOSED.
import os, io, sys, uuid, shutil, urllib.request
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
URL = "https://api.pixellab.ai/mcp/images/{}/download?index={}"

# sprite name -> (anim job id, pad_to or None)
SPRITES = {
    "spr_pet_null_hound_baby_e":  ("9533026a-ec42-4d57-998e-82d7ac2b61ee", 85),
    "spr_pet_null_hound_baby_s":  ("4321abb4-d771-4ccc-adbc-6d63e029a508", 85),
    "spr_pet_null_hound_adult_e": ("e288a95b-a42a-4db2-b35d-56b20f35e35e", None),
    "spr_pet_null_hound_adult_s": ("a78afa3b-7569-4593-9f04-89d4f70ee061", None),
    "spr_pet_pyre_bison_baby_e":  ("5134cacc-25a1-4504-a9c7-03e4f02756a6", 85),
    "spr_pet_pyre_bison_baby_s":  ("b4e4f6d6-15b2-49bb-a339-a0b0da13b317", 85),
    "spr_pet_pyre_bison_youngadult_e": ("a92c6722-3234-4c67-956e-162afeac174e", None),
    "spr_pet_pyre_bison_youngadult_s": ("2383d3fd-b289-4417-8f6f-68d33728a677", None),
    "spr_pet_stormkirin_baby_e":  ("f02cae1c-984b-4ca4-8db4-b0a433207e23", 85),
    "spr_pet_stormkirin_baby_s":  ("599eed93-f83e-4069-9038-50da5adc0ff7", 85),
    "spr_pet_stormkirin_youngadult_e": ("4517c710-a99f-4ac5-9d9b-de79c2da914b", None),
    "spr_pet_stormkirin_youngadult_s": ("963223dc-7596-4b72-9855-44e976bf8504", None),
    "spr_pet_stormkirin_adult_e": ("0fc8ee74-1262-43c0-ab2f-e9aeeee986b7", None),
    "spr_pet_stormkirin_adult_s": ("cb3f3b40-67ac-46a5-abe8-49ce5b9962c2", None),
}

def fetch_frame(job, i, pad_to):
    req = urllib.request.Request(URL.format(job, i), headers={"User-Agent": "Mozilla/5.0"})
    im = Image.open(io.BytesIO(urllib.request.urlopen(req, timeout=120).read())).convert("RGBA")
    if pad_to and im.size != (pad_to, pad_to):
        c = Image.new("RGBA", (pad_to, pad_to), (0, 0, 0, 0))
        c.alpha_composite(im, ((pad_to - im.width) // 2, pad_to - im.height))
        im = c
    return im

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
    with open(os.path.join(root, name + ".yy"), "w", newline="\n") as f:
        f.write(yy)
    print(f"OK {name}: {W}x{H} x{n}f")
    return True

if __name__ == "__main__":
    only = set(sys.argv[1:]) if len(sys.argv) > 1 else None
    ok = total = 0
    for name, (job, pad) in SPRITES.items():
        if only and name not in only: continue
        total += 1
        if "TBD" in job:
            print(f"SKIP {name}: job id not set"); continue
        frames = [fetch_frame(job, i, pad) for i in range(9)]
        if build(name, frames): ok += 1
    print(f"built {ok}/{total}")
