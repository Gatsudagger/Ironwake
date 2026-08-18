#!/usr/bin/env python
"""Shared GM-CLOSED sprite import helpers (08-17). Clones any single-frame sprite .yy as a
template (fresh frame/layer/sequence uuids, canvas + bbox from the PNG) and registers the new
sprites at the head of Ironwake.yyp's resources array (GM re-sorts on save). Idempotent: an
existing sprite folder is never re-uuid'd (orphan PNGs) and a registered name is skipped.
Run only with GameMaker CLOSED.
"""
import os, re, shutil, uuid
ROOT    = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES = os.path.join(ROOT, "sprites")
YYP     = os.path.join(ROOT, "Ironwake.yyp")

def build_sprite(name, src_png, template_name):
    """Create sprites/<name>/ from src_png using sprites/<template_name>/<template_name>.yy."""
    from PIL import Image
    d = os.path.join(SPRITES, name)
    if os.path.exists(os.path.join(d, name + ".yy")):
        print("exists, skipping:", name)
        return False
    im = Image.open(src_png); w, h = im.size
    tpath = os.path.join(SPRITES, template_name, template_name + ".yy")
    yy = open(tpath, "r", encoding="utf-8").read()
    # ids in the template: frame (in "frames" + sequence keyframe), layer, sequence keyframe ids
    frames = re.findall(r'"\$GMSpriteFrame":"v1","%Name":"([0-9a-f-]{36})"', yy)
    layers = re.findall(r'"\$GMImageLayer":"","%Name":"([0-9a-f-]{36})"', yy)
    if len(frames) != 1 or len(layers) != 1:
        raise SystemExit("template %s must be single-frame/single-layer (frames=%d layers=%d)" % (template_name, len(frames), len(layers)))
    old_frame, old_layer = frames[0], layers[0]
    new_frame, new_layer = str(uuid.uuid4()), str(uuid.uuid4())
    yy = yy.replace(template_name, name)
    yy = yy.replace(old_frame, new_frame).replace(old_layer, new_layer)
    # every other uuid (keyframe ids, track ids) gets a fresh one so two sprites never share
    for u in set(re.findall(r'"id":"([0-9a-f-]{36})"', yy)):
        yy = yy.replace('"id":"%s"' % u, '"id":"%s"' % str(uuid.uuid4()))
    # bbox = the visible (alpha) bounds - pet_sprite_fit and the enemy stage scale by bbox
    bb = im.convert("RGBA").getbbox() or (0, 0, w, h)
    yy = re.sub(r'"bbox_bottom":\d+', '"bbox_bottom":%d' % (bb[3] - 1), yy)
    yy = re.sub(r'"bbox_right":\d+',  '"bbox_right":%d' % (bb[2] - 1), yy)
    yy = re.sub(r'"bbox_left":\d+',   '"bbox_left":%d' % bb[0], yy)
    yy = re.sub(r'"bbox_top":\d+',    '"bbox_top":%d' % bb[1], yy)
    yy = re.sub(r'"origin":\d+',      '"origin":0', yy)
    yy = re.sub(r'"height":\d+', '"height":%d' % h, yy)
    yy = re.sub(r'"width":\d+',  '"width":%d' % w, yy)
    yy = re.sub(r'"xorigin":\d+', '"xorigin":0', yy)
    yy = re.sub(r'"yorigin":\d+', '"yorigin":0', yy)
    os.makedirs(os.path.join(d, "layers", new_frame), exist_ok=True)
    shutil.copyfile(src_png, os.path.join(d, new_frame + ".png"))
    shutil.copyfile(src_png, os.path.join(d, "layers", new_frame, new_layer + ".png"))
    with open(os.path.join(d, name + ".yy"), "w", encoding="utf-8", newline="\n") as f:
        f.write(yy)
    print("built %s (%dx%d) from %s" % (name, w, h, os.path.basename(src_png)))
    return True

def register(names):
    text = open(YYP, "r", encoding="utf-8").read()
    new_lines = []
    for n in names:
        if ('"name":"%s"' % n) in text:
            continue
        new_lines.append('    {"id":{"name":"%s","path":"sprites/%s/%s.yy",},},' % (n, n, n))
    if new_lines:
        marker = '  "resources":[\n'
        idx = text.index(marker) + len(marker)
        text = text[:idx] + "\n".join(new_lines) + "\n" + text[idx:]
        with open(YYP, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
    print("registered %d new .yyp entries" % len(new_lines))


def build_anim_sprite(name, frames, fps=8.0):
    """Animated sprite from a list of equal-size PIL frames (bottom-center origin like the
    shipped pets, alpha-union bbox). REBUILDS if the folder exists (frames change on re-anim)."""
    import shutil, uuid
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
    bb = None
    for im in frames:
        b = im.convert("RGBA").getbbox()
        if b: bb = b if bb is None else (min(bb[0], b[0]), min(bb[1], b[1]), max(bb[2], b[2]), max(bb[3], b[3]))
    if bb is None: bb = (0, 0, W, H)
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
  "bbox_bottom":{bb[3]-1},
  "bbox_left":{bb[0]},
  "bbox_right":{bb[2]-1},
  "bbox_top":{bb[1]},
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
    "playbackSpeed":{fps},
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

