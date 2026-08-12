#!/usr/bin/env python
# Build GameMaker anim sprites for the 08-01 pet-expansion batch:
# crypt_bat / hoarfrost_drake / duskraven / voidkit, 3 stages each, south+east.
# Unlike build_pets_signature.py (one 8-direction object per stage), each stage
# here is TWO 1-direction objects: the approved BASE (side profile = EAST) and
# its derived SOUTH state. Each object's download ZIP holds one idle animation
# whose direction folder is usually "unknown" - we take whatever single
# direction folder exists. Run AFTER all 24 animations complete; GM must be
# CLOSED before the --register step touches Ironwake.yyp.
import os, io, sys, uuid, shutil, urllib.request, zipfile
from PIL import Image

ROOT   = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OBJ_DL = "https://api.pixellab.ai/mcp/objects/{id}/download"
YYP    = os.path.join(ROOT, "Ironwake.yyp")

# (species, stage, east_object_id (approved base), south_object_id (derived state))
CFG = [
 ("crypt_bat","baby",       "d8949408-fd72-46fa-b363-15d078ec5de7","9a188d5e-0127-498b-9770-62217505e285"),
 ("crypt_bat","youngadult", "75ce5d70-f85a-433a-bcce-80aa2fc15b61","ba12678a-247a-44e1-880d-af89af4e7a15"),
 ("crypt_bat","adult",      "72c43384-c4cc-436c-ac4d-7ca2516b0497","ec4ff8e4-e943-4bc3-8906-a7d2b5484fa0"),
 ("hoarfrost_drake","baby",       "0fd035dd-4e50-4295-a3bb-e91633453b58","7f976af2-3276-4f34-b758-fa0829bb9c1d"),
 ("hoarfrost_drake","youngadult", "5d471212-383e-4802-accb-2361f6f9c946","b3cf4e44-d8bd-4177-949e-cc9c95ffc258"),
 ("hoarfrost_drake","adult",      "4e2f0803-359d-4dee-af1a-7162a2ca5c2a","1a365761-aeb9-4fd9-88c7-34b0348423ea"),
 ("duskraven","baby",       "ed669572-40c4-4312-9177-63b20ae4462f","622894cb-2fda-4c2f-b0ed-af2bf8f0ae5c"),
 ("duskraven","youngadult", "2c355969-0722-451f-8025-3245f2acaea1","3189f739-e48c-4fa3-bef1-a35d43521a16"),
 ("duskraven","adult",      "b5dd6bf6-748f-404c-8b74-7635ba1ab40d","09c807e5-8957-4610-90f1-9257723d928f"),
 ("voidkit","baby",       "7b42e5c3-3111-4db9-8326-1c93621e5aef","14c217ca-9076-4ed1-97c2-9117bc896152"),
 ("voidkit","youngadult", "c9b8d2d9-b18c-440c-a7af-e0df5b40302c","251997a0-73b9-4e14-a133-8576718c468f"),
 ("voidkit","adult",      "022bd9c8-b9d5-4ab2-b98c-37b3ca69d312","2d806f23-5b04-4ea6-84ff-7fb61382c3f2"),
 # Batch 2 (08-02): remaining 6 generic species, M approved round-2 lineups
 # (v2 young-adults; sporeling redesigned as treant beast w/ glow-cap adult).
 ("pale_widow","baby",       "82afe030-bddd-4194-9226-4774e15ee75f","0488a5ee-658c-42ee-ba24-05cd01153263"),
 ("pale_widow","youngadult", "daa34761-111b-413b-8507-a0c0b69f38ca","6c0a0470-6931-479d-8f2f-16ea3680ec98"),
 ("pale_widow","adult",      "baf88714-7978-41d3-9046-c197f365dd13","713225cc-ddc1-4c5e-af0f-9b90aa957455"),
 ("shellback","baby",       "cc1e6672-db95-4713-b857-5a9bb1371f23","7d6b1945-0212-4cef-aca1-b14de4cec572"),
 ("shellback","youngadult", "0c283214-a912-44c0-9110-e622f049a89b","2c7f9c5d-b2c5-4e40-8ee6-a95c59a12e7e"),
 ("shellback","adult",      "f8178216-e93d-40dd-ab23-a780485efe62","a66abe4b-8d8e-4b51-969e-4393c96ae1b8"),
 ("thorn_boar","baby",       "1f354de5-fbdf-4e88-aa47-da1b6ff8817d","1c7f25e5-ecca-4780-b80f-db3c42fe4c0a"),
 ("thorn_boar","youngadult", "976afa10-a547-448a-97cf-b04aa5c2596c","ccf90c0a-780f-4a7f-8799-f89ccfb631fe"),
 ("thorn_boar","adult",      "92fcec2b-cc6e-4f69-a0ae-ffc42adba9d5","6ae3a202-6511-4092-9551-77df61b45313"),
 ("glimmer_slime","baby",       "31a30d20-8589-4741-9e19-859e7ac13473","22589a60-5709-4acf-89ad-73db07b4d104"),
 ("glimmer_slime","youngadult", "04bab86d-2726-4fe1-849d-6e251cc12140","3897d93e-d688-479d-80f5-53f4c37e7fed"),
 ("glimmer_slime","adult",      "d4b51b4b-279e-4c85-baa5-e4ef1ffa8241","4c603888-6751-42e2-ad4f-736ebcc1a6ba"),
 ("sporeling","baby",       "b4d8d1c4-8ecc-4110-b271-684ef5ee69d2","99abbc71-efeb-495c-ae2a-1db45da0a6d6"),
 ("sporeling","youngadult", "f507eb8d-088a-4471-bf74-b673a8d4f4a2","deafcba0-e9d9-49d0-93e3-ec92a66ece2c"),
 ("sporeling","adult",      "85cc9eae-6bdf-4d18-80c5-3c406f0ec9f8","51340517-0152-4311-9b9c-208f09b33afe"),
 ("ironshell_beetle","baby",       "b62d83b9-f889-490c-82e1-d66450b3c07a","3029a32e-1337-4054-9e29-37e6d502d7e6"),
 ("ironshell_beetle","youngadult", "b7950b4e-d32e-4839-a036-5e2861bc8891","07588cfb-87b1-45b7-80d0-fb58acef0399"),
 ("ironshell_beetle","adult",      "be0de209-9344-4297-aa0f-5273e6b896ff","64eb02de-ed4f-44a5-bdf9-923328f14e8f"),
 # Batch 3 (08-11): lockjaw_turtle RE-AUTHOR pilot (species 1/20) - replaces the
 # 33-39px stills with proper-canvas animated sprites (85/124/124). Sprite names
 # already in .yyp, so this is a pure frame swap; see tools/REAUTHOR_LOCKJAW_0811.md.
 ("lockjaw_turtle","baby",       "04afe5cc-a866-4359-b1a5-10b25654b6e3","52ecfe38-b885-413e-a524-d170679be28e"),
 ("lockjaw_turtle","youngadult", "473a4aff-1db0-45eb-a549-de7914ab1beb","1af936dc-d687-412d-9d4e-ec2627c19ba7"),
 ("lockjaw_turtle","adult",      "ebe11ccb-f90f-401a-801f-9998689c3985","c2821797-d1e9-43a0-975c-c89913e0e345"),
 # Batch 1 (08-12) object-pipeline stages (M's candidate picks; the other
 # stages of these species import via tools/import_reauthor_images.py).
 ("pyre_bison","adult",       "664e66c9-49b2-4fb7-9cf8-0ab2fd3c04f8","87d9d4c4-1d90-4f32-8e01-364878772d0a"),
 ("null_hound","youngadult",  "65038238-ce6a-4ccf-be07-62d619d505db","350485c7-3f94-45c0-9c1e-4982f84e37b8"),
]

def fetch_zip(cid):
    req = urllib.request.Request(OBJ_DL.format(id=cid), headers={"User-Agent":"Mozilla/5.0"})
    return zipfile.ZipFile(io.BytesIO(urllib.request.urlopen(req, timeout=180).read()))

def anim_frames(z):
    # Frames of the single idle animation, whatever the direction folder is
    # named ("unknown" for 1-direction objects).
    names = sorted(n for n in z.namelist()
                   if "animations/" in n and n.endswith(".png"))
    return names

def build(name, z):
    frames_in = anim_frames(z)
    if not frames_in:
        print(f"FAIL {name}: no animation frames in zip"); return False
    root = os.path.join(ROOT, "sprites", name)
    if os.path.isdir(root): shutil.rmtree(root)
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

def register_yyp(spr_names):
    with open(YYP, "r", encoding="utf-8") as f:
        text = f.read()
    new_lines = []
    for n in spr_names:
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
    do_register = "--register" in sys.argv
    only = next((a for a in sys.argv[1:] if not a.startswith("--")), None)
    only_set = set(only.split(",")) if only else None
    names, ok = [], 0
    for species, stage, east_id, south_id in CFG:
        if only_set and species not in only_set: continue
        for cid, suf in ((south_id,"s"), (east_id,"e")):
            name = f"spr_pet_{species}_{stage}_{suf}"
            z = fetch_zip(cid)
            if build(name, z): ok += 1
            names.append(name)
    print(f"built {ok}/{len(names)}")
    if do_register and ok == len(names):
        added = register_yyp(names)
        print(f"yyp: +{added} registered")
    elif do_register:
        print("yyp: SKIPPED (build failures above)")
