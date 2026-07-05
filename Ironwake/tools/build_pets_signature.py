#!/usr/bin/env python
# Build GameMaker anim sprites for the 3 BOSS-SIGNATURE pet species (Ashen Vault batch:
# vaultling / marrow_adder / gaolwyrm, 3 stages x south+east) and the v2 REPLACEMENT
# young-adults for bone_stag / saber_hound (same sprite names as the old imports - the
# folders are rebuilt in place, so no .yyp / include changes for those two).
# Unlike build_pets.py (frame URLs + fixed NFRAMES), this consumes each asset's download
# ZIP (rotations/ + animations/<name>/<dir>/frame_XXX.png), so frame counts are whatever
# the generator produced (v3 = 9, character templates = 8-9).
import os, io, uuid, shutil, urllib.request, zipfile
from PIL import Image

OBJ_DL  = "https://api.pixellab.ai/mcp/objects/{id}/download"
CHAR_DL = "https://api.pixellab.ai/mcp/characters/{id}/download"

# (species, stage, kind, asset_id)
CFG = [
 ("vaultling","baby","obj","a5d26508-8cae-4fd3-9c22-16eb399850ae"),
 ("vaultling","youngadult","obj","79ff178a-a926-4747-992c-055c8732ebac"),
 ("vaultling","adult","obj","27a41df9-9d0c-4aca-9207-3aef9bf96206"),
 ("marrow_adder","baby","obj","d6873484-abc3-4d3b-910a-afe92bd11bab"),
 ("marrow_adder","youngadult","obj","b5e4f054-2027-4db5-9941-c1249acd6f2b"),
 ("marrow_adder","adult","obj","b3db652e-a454-4b52-ae9c-6d46b7b7909e"),
 ("gaolwyrm","baby","obj","c964b31a-b778-4175-af82-a7fa77fee9da"),
 ("gaolwyrm","youngadult","obj","a945759e-2149-421c-91aa-f11ef2a7fa18"),
 ("gaolwyrm","adult","obj","b2ada4fb-78a0-4655-ba42-00677fabde24"),
 ("bone_stag","youngadult","char","35d54ada-5ca9-40f2-9ab7-63717bd11b15"),
 ("saber_hound","youngadult","char","59a7c5c6-abe3-4f1c-8798-1b8314d4d444"),
 # Scorched Depths trio (batch 2, approved 2026-07-03)
 ("cinder_newt","baby","obj","6dbb9f96-eb16-427c-afd6-4c9488a081fd"),
 ("cinder_newt","youngadult","obj","5cc708a8-7348-4a33-bfe9-7be0d66ebaa7"),
 ("cinder_newt","adult","obj","2a35e2ec-132b-45ee-8cbc-97f46a1b4885"),
 ("magma_leech","baby","obj","4738e2ae-1153-4800-947e-1c83069ece0f"),
 ("magma_leech","youngadult","obj","8fd9e04a-5fd1-4af5-a55f-d2e4e028c19f"),
 ("magma_leech","adult","obj","47f0c6ad-60d6-4ca7-81ce-0ecbf4cf1bd7"),
 ("golemite","baby","obj","98bd9339-44f4-4fa5-b708-c8dec6d9abe7"),
 ("golemite","youngadult","obj","9022ee9f-deb8-4e23-bbef-53e8a61b8473"),
 ("golemite","adult","obj","3afb6884-0612-46d3-bc47-9d5a4d07b9f1"),
 # Tundra Tomb trio (batch 3, 2026-07-04): rimefox approved + imported; crypt_bat +
 # hoarfrost_drake deferred to the next PixelLab cycle (bases alone are ~105 gens each).
 ("rimefox","baby","obj","7135cc3c-6b2d-473a-a37e-e8f2a95eff0d"),
 ("rimefox","youngadult","obj","d9ec9ac4-15a0-4419-9c2c-eaed7ece2265"),
 ("rimefox","adult","obj","0fe9d60f-b9f8-4149-9ddd-63d5cd5b6029"),
]

def fetch_zip(kind, cid):
    url = (OBJ_DL if kind=="obj" else CHAR_DL).format(id=cid)
    req = urllib.request.Request(url, headers={"User-Agent":"Mozilla/5.0"})
    return zipfile.ZipFile(io.BytesIO(urllib.request.urlopen(req, timeout=180).read()))

def anim_frames(z, direction):
    # frames of the (single) idle animation for one direction, in order. Object zips
    # start at animations/...; character zips nest under a <Character_Name>/ folder.
    names = sorted(n for n in z.namelist()
                   if "animations/" in n and f"/{direction}/" in n and n.endswith(".png"))
    return names

def build(name, z, direction):
    frames_in = anim_frames(z, direction)
    if not frames_in:
        print(f"FAIL {name}: no {direction} frames in zip"); return False
    root = os.path.join("sprites", name)
    if os.path.isdir(root): shutil.rmtree(root)   # rebuild in place (v2 replacements)
    os.makedirs(root)
    layer_guid = str(uuid.uuid4())
    frame_guids, kf_guids = [], []
    W = H = None
    for fn in frames_in:
        im = Image.open(io.BytesIO(z.read(fn))).convert("RGBA")
        if W is None: W,H = im.size
        fg = str(uuid.uuid4()); frame_guids.append(fg); kf_guids.append(str(uuid.uuid4()))
        im.save(os.path.join(root, fg+".png"))
        ld = os.path.join(root,"layers",fg); os.makedirs(ld, exist_ok=True)
        im.save(os.path.join(ld, layer_guid+".png"))
    n = len(frame_guids)
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
    return True

if __name__ == "__main__":
    import sys
    only = sys.argv[1] if len(sys.argv)>1 else None  # optional species filter
    for species,stage,kind,cid in CFG:
        if only and species!=only: continue
        z = fetch_zip(kind, cid)
        for direction,suf in (("south","s"),("east","e")):
            build(f"spr_pet_{species}_{stage}_{suf}", z, direction)
