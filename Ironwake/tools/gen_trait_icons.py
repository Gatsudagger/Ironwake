#!/usr/bin/env python
"""
Build 64x64 GameMaker sprite resources for trait icons (spr_icon_trait_<effect_id>).

Two source kinds per trait:
  - "lib": an icon from the Asset_Library framed packs (warrior/mage). Already
           framed -> just downscale 512->64.
  - "px":  a PixelLab map-object id. Frameless transparent art -> trim, scale to
           fit, and composite onto a dark bronze badge frame so it matches the
           framed library icons.

Then registers each sprite in Ironwake.yyp (idempotent) and prints the
ui_trait_icon_sprite() switch cases.

Usage:
  python tools/gen_trait_icons.py lib   # import library icons only
  python tools/gen_trait_icons.py px    # import PixelLab icons only (waits for render)
  python tools/gen_trait_icons.py all   # both
"""
import os, sys, time, uuid, urllib.request, urllib.error
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES = os.path.join(ROOT, "sprites")
YYP = os.path.join(ROOT, "Ironwake.yyp")
LIBR = "C:/Asset_Library/icons"
WARR = os.path.join(LIBR, "250 WARRIOR ICONS (pack by batareya)")
MAGE = os.path.join(LIBR, "MAGE ICONS BIG PACk (by Batareya)")
SZ = 64

# effect_id -> source.  "Wnn"/"Mnn" = library pack icon number; "px:<uuid>" = PixelLab.
MANIFEST = {
    "sense":            "W76",
    "scavenger":        "px:0f241362-0c32-47b5-8ffe-78d66ed2a5a4",
    "thick_skin":       "W146",
    "quick_recovery":   "px:3059a805-c2a3-4e88-a985-0b0688903f06",
    "treasure_hunter":  "px:e75cf4c0-cabb-4f5b-b561-cc6e467a189d",
    "lucky_find":       "px:2a8b70e0-4dd9-4504-b7ab-d03d07f9ccd2",
    "battle_hardened":  "M0",   # placeholder, set below
    "salvager":         "M191",
    "iron_will":        "W163",
    "expanded_arsenal": "M72",
    "prospector":       "px:69508c08-7aca-42e4-8511-3099ea1200ac",
    "pack_rat":         "px:4f001b9a-0fb2-42c8-a50a-df86b374f5bb",
    "last_stand":       "M122",
    "focused_power":    "W164",
    "chain_caster":     "px:f6ae5d3c-0af1-4400-bc99-bb32de38d2d2",
    "plaguebearer":     "M82",
    "soul_siphon":      "M91",
    "ley_tap":          "M36",
    "arcane_surge":     "M38",
    "crimson_reserve":  "M65",
    "vampiric_edge":    "W49",
    "berserker_rage":   "M214",
    "phantom_step":     "M156",
    "shadow_meld":      "W124",
    "serrated_strikes": "W109",
}
MANIFEST["battle_hardened"] = "W6"

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


def lib_path(tok):
    pack = WARR if tok[0] == "W" else MAGE
    return os.path.join(pack, tok[1:] + ".png")


def make_badge():
    """64x64 dark slate badge with a bronze double border (matches framed packs)."""
    img = Image.new("RGBA", (SZ, SZ), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # vertical dark gradient fill
    for y in range(SZ):
        t = y / (SZ - 1)
        r = int(30 - 16 * t); g = int(34 - 18 * t); b = int(46 - 24 * t)
        d.line([(0, y), (SZ, y)], fill=(r, g, b, 255))
    d.rectangle([0, 0, SZ - 1, SZ - 1], outline=(120, 84, 40, 255), width=1)      # outer bronze
    d.rectangle([2, 2, SZ - 3, SZ - 3], outline=(196, 152, 84, 255), width=1)     # inner gold
    return img


def fit_onto_badge(art):
    """Trim transparent margins, scale to fit the badge interior, composite centered."""
    bbox = art.getbbox()
    if bbox:
        art = art.crop(bbox)
    inner = SZ - 12
    art.thumbnail((inner, inner), Image.LANCZOS)
    badge = make_badge()
    x = (SZ - art.width) // 2
    y = (SZ - art.height) // 2
    badge.alpha_composite(art, (x, y))
    return badge


def dl(url, retries=40, wait=8):
    last = None
    for _ in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req) as r:
                data = r.read()
            if data[:8] == b"\x89PNG\r\n\x1a\n":
                return data
            last = "not-png (%d bytes)" % len(data)
        except urllib.error.HTTPError as e:
            last = "HTTP %s" % e.code
        except Exception as e:
            last = str(e)
        time.sleep(wait)
    raise RuntimeError("download failed for %s: %s" % (url, last))


def render_image(effect_id, src):
    if src.startswith("px:"):
        oid = src[3:]
        data = dl("https://api.pixellab.ai/mcp/map-objects/%s/download" % oid)
        tmp = os.path.join(SPRITES, "_tmp_%s.png" % effect_id)
        with open(tmp, "wb") as f:
            f.write(data)
        art = Image.open(tmp).convert("RGBA")
        os.remove(tmp)
        return fit_onto_badge(art)
    else:
        art = Image.open(lib_path(src)).convert("RGBA")
        return art.resize((SZ, SZ), Image.LANCZOS)


def build_sprite(spr_name, img):
    sdir = os.path.join(SPRITES, spr_name)
    frame = str(uuid.uuid4()); layer = str(uuid.uuid4()); kfid = str(uuid.uuid4())
    os.makedirs(os.path.join(sdir, "layers", frame), exist_ok=True)
    comp = os.path.join(sdir, frame + ".png")
    img.save(comp)
    img.save(os.path.join(sdir, "layers", frame, layer + ".png"))
    yy = YY_TEMPLATE.format(name=spr_name, frame=frame, layer=layer, kfid=kfid,
                            w=SZ, h=SZ, br=SZ - 1, bb=SZ - 1)
    with open(os.path.join(sdir, spr_name + ".yy"), "w", newline="\n") as f:
        f.write(yy)


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


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "all"
    names = []
    for effect_id, src in MANIFEST.items():
        is_px = src.startswith("px:")
        if mode == "lib" and is_px:
            continue
        if mode == "px" and not is_px:
            continue
        spr_name = "spr_icon_trait_" + effect_id
        img = render_image(effect_id, src)
        build_sprite(spr_name, img)
        names.append(spr_name)
        print("built", spr_name, "<-", src)
    n = register_yyp(names)
    print("registered %d new sprites in .yyp (of %d built)" % (n, len(names)))


if __name__ == "__main__":
    main()
