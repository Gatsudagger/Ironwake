#!/usr/bin/env python
# Build GameMaker anim sprites for the 6 redesigned pet species (3 stages x 2 dirs = 36).
# Handles BOTH object frame-URLs (.../objects/...) and character frame-URLs.
# Frames 0..N-1 = animation frames; sprite plays idle directly. Bottom-center origin.
import os, uuid, urllib.request, io
from PIL import Image

PROJECT = "c50e1365-1a8c-44be-a773-5ee635581147"
OBJ  = "https://backblaze.pixellab.ai/file/pixellab-characters/objects/{proj}/{id}/animations/{grp}/{dir}/{i}.png"
CHAR = "https://backblaze.pixellab.ai/file/pixellab-characters/{proj}/{id}/animations/{grp}/{dir}/{i}.png"
NFRAMES = 5

# (species, stage, kind, id, south_group, east_group)
CFG = [
 ("luna_moth","baby","obj","c6f1d48d-03cf-4447-a3c8-dfff04fb7162","cdfbf1c3-073f-426c-9b7c-610309bf4c8d","aed2c6e7-39ad-41f2-a16f-a402c404eb37"),
 ("luna_moth","youngadult","obj","3bc6c04c-50bd-40f2-b033-1de2152e68bc","93e4cd32-e9bf-4604-8a51-033953ef9601","fa6e1f80-5a69-49ff-ab4f-111f8b03e68f"),
 ("luna_moth","adult","obj","6dedc854-a184-4c1b-84a2-2ac3c16ef31c","4018e60a-697e-4315-9167-316cfb633f2a","2fab61ec-9d8f-4fee-85cb-da5fcd043ff8"),
 ("gloomtoad","baby","obj","0476f8ce-4a64-4dbc-887c-2f3b65c50404","067eecb3-006e-44f4-b1c2-70d2a3ac0f3a","1f18ecca-fb0e-49e3-8888-b64f4c516324"),
 ("gloomtoad","youngadult","obj","910392fe-f9af-4641-b24e-ef865d02c6ba","912cedda-e2db-4a52-bb6d-2a1aa63ca8b3","6d557488-2fa5-4d1d-8b94-5eec73eeb0f2"),
 ("gloomtoad","adult","obj","3f3db0e8-7a4d-4d0b-aa9c-0ce085f8ae93","f7272493-e0a7-4e3c-a77d-adff934ec9b4","0ed34817-4850-46c2-973e-eb37ec93e8fe"),
 ("wyrmling","baby","obj","6c232eee-f908-4d64-a4e2-188fcc4debed","7b0d44ec-7c33-47f3-9763-aaa0a3385179","08f24506-dac5-4c00-a085-9fdc972b341a"),
 ("wyrmling","youngadult","obj","b5ced4ac-05c0-46db-b93c-9febb652be31","1480cce5-b00c-4028-ade1-537c5693902b","a994f4a4-1041-4b6e-b324-36ed020ab223"),
 ("wyrmling","adult","obj","a419311b-e59b-4b13-8567-568ccd273ede","dd4beafe-804c-49e5-b7fd-5558dea545a3","fe6ad26c-8c95-4092-b839-e1b19dc50995"),
 ("nightowl","baby","obj","9ab7f045-331d-4e14-9830-3059cd59fbc9","916aee89-ffc4-4414-b675-7dbad4af2a34","0119dd26-d7b7-428f-a12b-dfe8f2e0abf4"),
 ("nightowl","youngadult","obj","4edf230f-3b1e-41e9-bde2-944a3a80ad67","e4d791d4-bd7d-4cf8-ba1e-33b68b7d45b3","a3143abc-a75f-4d5d-8916-db03004f2482"),
 ("nightowl","adult","obj","34b5b1f1-4f9d-4b23-8ba9-8d2cbab9095c","1f3dd056-7397-469a-a3fa-dfbe0ce067cb","327e43a9-9889-44e9-b4be-d9732a13e80a"),
 ("bone_stag","baby","char","3c5dc111-5f76-4bdf-98c2-84072af0daeb","741d07b5-d96d-4b41-91c6-7ec2cb7810c6","56e2edad-f40c-4742-8cfe-d670284d938c"),
 ("bone_stag","youngadult","char","23e2a203-4b39-43d7-8daf-4c280dfcb640","aebf0ce5-04c4-41da-b153-08be02e846b8","2da259ed-7e57-4cba-81f2-f98b0e2def38"),
 ("bone_stag","adult","char","55234923-f020-4b45-bc00-413f4d47d386","08640340-744b-4344-bc99-e3317f12e91f","45486100-f496-4a74-a555-6b7a2e7040df"),
 ("saber_hound","baby","char","1ac9ea0d-bdd4-4b84-ad3b-68b209a1cab6","2afa3bce-9ae5-49f9-b650-cb88a65e59d4","a55292f7-5d07-4e74-a86d-1fa7eb20988d"),
 ("saber_hound","youngadult","char","96c8c0c5-5473-4014-972b-26543d2c47d4","5915c628-1fb8-4ae3-99cd-2ae17de4d820","c52ddf15-bea9-44ee-8cad-b7b8666ebfc0"),
 ("saber_hound","adult","char","2346112d-f076-42b1-9d6c-3f20c3980f61","a5fd739e-495b-430b-8a61-9bb26b7999ea","a5889d44-0c1a-4c52-9adc-9558c177a4fb"),
]

def build(name, kind, cid, grp, direction):
    tmpl = OBJ if kind=="obj" else CHAR
    root = os.path.join("sprites", name)
    os.makedirs(root, exist_ok=True)
    layer_guid = str(uuid.uuid4())
    frame_guids, kf_guids = [], []
    W = H = None
    for i in range(NFRAMES):
        url = tmpl.format(proj=PROJECT, id=cid, grp=grp, dir=direction, i=i)
        req = urllib.request.Request(url, headers={"User-Agent":"Mozilla/5.0"})
        im = Image.open(io.BytesIO(urllib.request.urlopen(req, timeout=60).read())).convert("RGBA")
        if W is None: W,H = im.size
        fg = str(uuid.uuid4()); frame_guids.append(fg); kf_guids.append(str(uuid.uuid4()))
        im.save(os.path.join(root, fg+".png"))
        ld = os.path.join(root,"layers",fg); os.makedirs(ld, exist_ok=True)
        im.save(os.path.join(ld, layer_guid+".png"))
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
    "length":{float(NFRAMES)},
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
    print(f"OK {name}: {W}x{H}")

if __name__ == "__main__":
    import sys
    only = sys.argv[1] if len(sys.argv)>1 else None  # optional species filter
    for species,stage,kind,cid,sg,eg in CFG:
        if only and species!=only: continue
        for direction,grp,suf in (("south",sg,"s"),("east",eg,"e")):
            if grp=="SABER_ADULT_EAST":
                print(f"SKIP spr_pet_{species}_{stage}_{suf} (east pending)"); continue
            build(f"spr_pet_{species}_{stage}_{suf}", kind, cid, grp, direction)
