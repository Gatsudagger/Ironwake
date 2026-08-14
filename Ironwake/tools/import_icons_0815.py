"""Import the 08-15 approved icon batch as GameMaker sprites (GM must be CLOSED).

21 sprites: 9 ability icons + trait/buckler/3 chaos brews (approved SHEET_abilities
+ SHEET_mixed) + 7 rune recolors of the shipped Ember crystal (SHEET_runes_v2).
Clones the spr_icon_rune_ember .yy structure (fresh UUIDs), registers each in
Ironwake.yyp alphabetically. __sprite_includes refs are added separately in
obj_game_controller Create_0 (string-ref strip gotcha).
"""
import os
import re
import uuid

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REV = os.path.join(ROOT, "_for_review", "icons_batch_0815")
SPRITES = os.path.join(ROOT, "sprites")
YYP = os.path.join(ROOT, "Ironwake.yyp")

IMPORTS = [
    ("spr_ability_weapon_strike",           "abilities_00_weapon.png"),
    ("spr_ability_weapon_shot",             "abilities_01_weapon.png"),
    ("spr_ability_magma_golem",             "abilities_02_magma.png"),
    ("spr_ability_warding_effigy",          "abilities_03_warding.png"),
    ("spr_ability_static_husk",             "abilities_04_static.png"),
    ("spr_ability_ricochet_shot",           "abilities_05_ricochet.png"),
    ("spr_ability_bouncing_bomb",           "abilities_06_bouncing.png"),
    ("spr_ability_gout_of_rot",             "abilities_07_gout.png"),
    ("spr_ability_measured_riposte",        "abilities_08_measured.png"),
    ("spr_icon_trait_mandate_heaven",       "mixed_00.png"),
    # ADDITIONAL sprite - the original spr_icon_offhand_buckler stays untouched
    # (M hard rule: never replace originals; code swaps the reference instead).
    ("spr_icon_offhand_buckler_b",          "mixed_01.png"),
    ("spr_icon_consumable_chaotic_brew_a",  "mixed_02.png"),
    ("spr_icon_consumable_chaotic_brew_b",  "mixed_03.png"),
    ("spr_icon_consumable_chaotic_brew_c",  "mixed_04.png"),
    ("spr_icon_rune_rime",                  "rune_recolor_rime.png"),
    ("spr_icon_rune_tempest",               "rune_recolor_tempest.png"),
    ("spr_icon_rune_aether",                "rune_recolor_aether.png"),
    ("spr_icon_rune_abyss",                 "rune_recolor_abyss.png"),
    ("spr_icon_rune_umbra",                 "rune_recolor_umbra.png"),
    ("spr_icon_rune_venom",                 "rune_recolor_venom.png"),
    ("spr_icon_rune_avatar",                "rune_recolor_avatar.png"),
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
