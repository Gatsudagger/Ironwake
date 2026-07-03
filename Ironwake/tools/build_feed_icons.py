#!/usr/bin/env python
# Build single-frame, center-origin GameMaker icon sprites for the 6 pet feeds.
# Source = promoted 1-direction objects (rotations/unknown.png). Run from Ironwake root.
import os, uuid, urllib.request, io
from PIL import Image

PROJECT = "c50e1365-1a8c-44be-a773-5ee635581147"
STATIC  = "https://backblaze.pixellab.ai/file/pixellab-characters/objects/{proj}/{id}/rotations/unknown.png"

# (feed_id, object_id)
FEEDS = [
 ("scraps",       "c89da5e7-2bd6-49c2-af37-82f8cd58b4ef"),
 ("forage",       "7ea31639-466a-413c-bd14-79ec58991f5e"),
 ("prime",        "aef1f9e7-c0a7-4dc6-b778-55c45277ba27"),
 ("mending_mash", "2ca39d30-9967-447b-bf6b-95310bf0f25d"),
 ("purgeroot",    "aab0d389-73bf-499c-a7b0-4f34c157b71f"),
 ("hearty_roast", "6b911be8-0ed3-42a0-82dd-ed849e0798e7"),
]

# Preferred-feed icons (M-approved 2026-07-03): 17 species favourites, built from the
# review-pick PNGs staged in _art_staging/pets_signature_review/feed_icons. feed ids are
# pref_<species>, so the sprites resolve via the existing spr_pet_feed_<id> lookup.
PREF_SRC = os.path.join("_art_staging", "pets_signature_review", "feed_icons")
PREFS = [
 ("pref_luna_moth",       "00_luna_moth_nectar.png"),
 ("pref_bone_stag",       "01_bone_stag_bale.png"),
 ("pref_saber_hound",     "02_saber_hound_haunch.png"),
 ("pref_gloomtoad",       "03_gloomtoad_clutch.png"),
 ("pref_wyrmling",        "04_wyrmling_heart.png"),
 ("pref_nightowl",        "05_nightowl_vole.png"),
 ("pref_bonehound",       "06_bonehound_bone.png"),
 ("pref_hollow_pup",      "07_hollow_pup_sop.png"),
 ("pref_vaultling",       "08_vaultling_gravel.png"),
 ("pref_marrow_adder",    "09_marrow_adder_knucklebones.png"),
 ("pref_gaolwyrm",        "10_gaolwyrm_shavings.png"),
 ("pref_cinder_newt",     "11_cinder_newt_grubs.png"),
 ("pref_magma_leech",     "12_magma_leech_ore.png"),
 ("pref_golemite",        "13_golemite_chips.png"),
 ("pref_rimefox",         "14_rimefox_hare.png"),
 ("pref_crypt_bat",       "15_crypt_bat_wings.png"),
 ("pref_hoarfrost_drake", "roe_candidate_12.png"),
]

def dl(url):
    req = urllib.request.Request(url, headers={"User-Agent":"Mozilla/5.0"})
    return Image.open(io.BytesIO(urllib.request.urlopen(req, timeout=60).read())).convert("RGBA")

def build(name, im):
    root = os.path.join("sprites", name)
    os.makedirs(root, exist_ok=True)
    W, H = im.size
    layer_guid = str(uuid.uuid4())
    fg = str(uuid.uuid4()); kg = str(uuid.uuid4())
    im.save(os.path.join(root, fg+".png"))
    ld = os.path.join(root,"layers",fg); os.makedirs(ld, exist_ok=True)
    im.save(os.path.join(ld, layer_guid+".png"))
    frames = f'    {{"$GMSpriteFrame":"v1","%Name":"{fg}","name":"{fg}","resourceType":"GMSpriteFrame","resourceVersion":"2.0",}},'
    kfs = ('            {"$Keyframe<SpriteFrameKeyframe>":"","Channels":{\n'
        f'                "0":{{"$SpriteFrameKeyframe":"","Id":{{"name":"{fg}","path":"sprites/{name}/{name}.yy",}},"resourceType":"SpriteFrameKeyframe","resourceVersion":"2.0",}},\n'
        f'              }},"Disabled":false,"id":"{kg}","IsCreationKey":false,"Key":0.0,"Length":1.0,"resourceType":"Keyframe<SpriteFrameKeyframe>","resourceVersion":"2.0","Stretch":false,}},')
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
{kfs}
          ],"resourceType":"KeyframeStore<SpriteFrameKeyframe>","resourceVersion":"2.0",}},"modifiers":[],"name":"frames","resourceType":"GMSpriteFramesTrack","resourceVersion":"2.0","spriteId":null,"trackColour":0,"tracks":[],"traits":0,}},
    ],
    "visibleRange":null,
    "volume":1.0,
    "xorigin":{W//2},
    "yorigin":{H//2},
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
    if len(sys.argv) > 1 and sys.argv[1] == "prefs":
        for fid, fn in PREFS:
            build("spr_pet_feed_" + fid, Image.open(os.path.join(PREF_SRC, fn)).convert("RGBA"))
    else:
        for fid, oid in FEEDS:
            build("spr_pet_feed_" + fid, dl(STATIC.format(proj=PROJECT, id=oid)))
