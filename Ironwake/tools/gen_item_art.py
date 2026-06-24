#!/usr/bin/env python
"""
Build GameMaker sprite resources from PixelLab map-object downloads for the Item Codex.

Input: a JSON file mapping  spr_name -> {"base": "<item base name>", "url": "<download url>"}
For each entry it:
  - downloads the 128x128 RGBA PNG (User-Agent header; pixellab needs no auth)
  - writes sprites/<spr_name>/<frame_guid>.png + layers/<frame_guid>/<layer_guid>.png
  - writes sprites/<spr_name>/<spr_name>.yy (single frame, single layer, 128x128)
Then:
  - inserts resource lines into Ironwake.yyp (idempotent; skips already-registered)
  - prints the item_splash_sprite() switch cases to paste into scr_ui.gml

Usage: python tools/gen_item_art.py tools/item_art_batch.json
"""
import json, os, sys, time, uuid, urllib.request, urllib.error

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES = os.path.join(ROOT, "sprites")
YYP = os.path.join(ROOT, "Ironwake.yyp")
W = H = 128

YY_TEMPLATE = '''{{
  "$GMSprite":"v2",
  "%Name":"{name}",
  "bboxMode":0,
  "bbox_bottom":{bb},
  "bbox_left":0,
  "bbox_right":{br},
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
  "height":{h},
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
              }},"Disabled":false,"id":"{kfid}","IsCreationKey":false,"Key":0.0,"Length":1.0,"resourceType":"Keyframe<SpriteFrameKeyframe>","resourceVersion":"2.0","Stretch":false,}},
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
  "width":{w},
}}'''


def dl(url, dest, retries=40, wait=8):
    """Download a PixelLab object PNG, retrying while the job is still rendering."""
    last = None
    for _ in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req) as r:
                data = r.read()
            if data[:8] == b"\x89PNG\r\n\x1a\n":
                with open(dest, "wb") as f:
                    f.write(data)
                return
            last = "not-png (%d bytes)" % len(data)
        except urllib.error.HTTPError as e:
            last = "HTTP %s" % e.code
        except Exception as e:
            last = str(e)
        time.sleep(wait)
    raise RuntimeError("download failed for %s: %s" % (url, last))


def url_for(info):
    if "url" in info:
        return info["url"]
    return "https://api.pixellab.ai/mcp/map-objects/%s/download" % info["id"]


def build_sprite(spr_name, info):
    url = url_for(info)
    sdir = os.path.join(SPRITES, spr_name)
    frame = str(uuid.uuid4())
    layer = str(uuid.uuid4())
    kfid = str(uuid.uuid4())
    os.makedirs(os.path.join(sdir, "layers", frame), exist_ok=True)
    comp = os.path.join(sdir, frame + ".png")
    dl(url, comp)
    # layer image is identical to the composite for a single-layer sprite
    with open(comp, "rb") as a:
        blob = a.read()
    with open(os.path.join(sdir, "layers", frame, layer + ".png"), "wb") as b:
        b.write(blob)
    yy = YY_TEMPLATE.format(name=spr_name, frame=frame, layer=layer, kfid=kfid,
                            w=W, h=H, br=W - 1, bb=H - 1)
    with open(os.path.join(sdir, spr_name + ".yy"), "w", newline="\n") as f:
        f.write(yy)


def register_yyp(spr_names):
    with open(YYP, "r", encoding="utf-8") as f:
        text = f.read()
    new_lines = []
    for n in spr_names:
        line = '    {"id":{"name":"%s","path":"sprites/%s/%s.yy",},},' % (n, n, n)
        if ('"name":"%s"' % n) in text:
            continue  # already registered
        new_lines.append(line)
    if not new_lines:
        return 0
    marker = '  "resources":[\n'
    idx = text.index(marker) + len(marker)
    text = text[:idx] + "\n".join(new_lines) + "\n" + text[idx:]
    with open(YYP, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    return len(new_lines)


def main():
    batch = json.load(open(sys.argv[1], encoding="utf-8"))
    spr_names = []
    cases = []
    for spr_name, info in batch.items():
        build_sprite(spr_name, info)
        spr_names.append(spr_name)
        base = info["base"].replace('"', '\\"')
        cases.append('        case "%s": return %s;' % (base, spr_name))
    n = register_yyp(spr_names)
    # Accumulate switch cases across rounds for one final wiring edit.
    casefile = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_splash_cases.txt")
    existing = ""
    if os.path.exists(casefile):
        existing = open(casefile, encoding="utf-8").read()
    with open(casefile, "a", encoding="utf-8", newline="\n") as f:
        for c in cases:
            if c not in existing:
                f.write(c + "\n")
    print("built %d sprites, registered %d new in .yyp" % (len(spr_names), n))
    print("\n".join(cases))


if __name__ == "__main__":
    main()
