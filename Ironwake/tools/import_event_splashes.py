"""Import approved 400x224 event-splash PNGs from _for_review as GameMaker sprites.

For each event id given on the command line (or the APPROVED list below):
  _for_review/splash_<id>_candidate.png  ->  sprites/spr_event_splash_<id>/...
    <frame_guid>.png + layers/<frame_guid>/<layer_guid>.png + .yy
and inserts the resource line into Ironwake.yyp alphabetically.

Skips sprites that already exist (safe to re-run). Run from the repo root:
    python tools/import_event_splashes.py [event_id ...]
"""
import os
import sys
import uuid

from PIL import Image

# Sprite-name prefix; override for non-event splashes, e.g.
#   SPLASH_PREFIX=spr_shrine_splash_ python tools/import_event_splashes.py ancient_altar curse_altar
PREFIX = os.environ.get("SPLASH_PREFIX", "spr_event_splash_")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REVIEW = os.path.join(ROOT, "_for_review")
SPRITES = os.path.join(ROOT, "sprites")
YYP = os.path.join(ROOT, "Ironwake.yyp")

# The 11 approved 07-09 (merchants_ghost/whispering_mirror redo pending, not here).
APPROVED = [
    "abandoned_nest", "arcane_locus", "collapsed_shrine", "forked_omen",
    "gamblers_cache", "runed_anvil", "starving_hound", "strangers_memory",
    "trapped_corridor", "vagrant_oracle", "wounded_wanderer",
]

YY_TEMPLATE = """{{
  "$GMSprite":"v2",
  "%Name":"{name}",
  "bboxMode":0,
  "bbox_bottom":223,
  "bbox_left":0,
  "bbox_right":399,
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
  "height":224,
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
              }},"Disabled":false,"id":"{keyframe}","IsCreationKey":false,"Key":0.0,"Length":1.0,"resourceType":"Keyframe<SpriteFrameKeyframe>","resourceVersion":"2.0","Stretch":false,}},
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
  "width":400,
}}"""


def import_one(event_id):
    name = PREFIX + event_id
    src = os.path.join(REVIEW, "splash_%s_candidate.png" % event_id)
    spr_dir = os.path.join(SPRITES, name)
    if os.path.isdir(spr_dir):
        print("SKIP (exists):", name)
        return name
    if not os.path.isfile(src):
        raise SystemExit("missing candidate png: " + src)

    img = Image.open(src).convert("RGBA")
    if img.size != (400, 224):
        raise SystemExit("%s is %r, expected 400x224" % (src, img.size))

    frame, layer, keyframe = str(uuid.uuid4()), str(uuid.uuid4()), str(uuid.uuid4())
    layer_dir = os.path.join(spr_dir, "layers", frame)
    os.makedirs(layer_dir)
    img.save(os.path.join(spr_dir, frame + ".png"))
    img.save(os.path.join(layer_dir, layer + ".png"))
    with open(os.path.join(spr_dir, name + ".yy"), "w", newline="\n") as f:
        f.write(YY_TEMPLATE.format(name=name, frame=frame, layer=layer, keyframe=keyframe))
    print("IMPORTED:", name)
    return name


def register_in_yyp(names):
    with open(YYP, "r", encoding="utf-8") as f:
        lines = f.readlines()
    entry = '    {{"id":{{"name":"{n}","path":"sprites/{n}/{n}.yy",}},}},\n'

    def res_name(line):
        s = line.strip()
        if s.startswith('{"id":{"name":"'):
            return s.split('"')[5]
        return None

    for n in sorted(names):
        if any(('"%s"' % n) in ln for ln in lines):
            print("SKIP yyp (already registered):", n)
            continue
        # Insert alphabetically among the resource entries (yyp keeps them sorted).
        idx = None
        for i, ln in enumerate(lines):
            rn = res_name(ln)
            if rn is not None and rn.lower() > n.lower():
                idx = i
                break
        if idx is None:
            raise SystemExit("could not find yyp insertion point for " + n)
        lines.insert(idx, entry.format(n=n))
        print("REGISTERED in yyp:", n)

    with open(YYP, "w", encoding="utf-8", newline="") as f:
        f.writelines(lines)


if __name__ == "__main__":
    ids = sys.argv[1:] or APPROVED
    made = [import_one(e) for e in ids]
    register_in_yyp(made)
    print("done: %d sprites" % len(made))
