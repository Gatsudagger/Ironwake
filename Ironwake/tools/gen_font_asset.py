"""Generate GameMaker font assets (.yy + atlas .png) from a TTF, cloning an
existing shipped font asset's structure so the runner treats them identically.

Validation mode regenerates the SHIPPED size and diffs per-glyph metrics
(shift/offset/w) against the shipped .yy - if those match, the pipeline is
trustworthy for new sizes.

Usage:
  python gen_font_asset.py validate            # regen fnt_ui@22, diff vs shipped
  python gen_font_asset.py generate            # build all 4 new variants
"""
import json, math, os, re, sys
from PIL import Image, ImageDraw, ImageFont

PROJ   = r"C:\Users\miles\GameMakerProjects\Ironwake"
OUTDIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fonts_out")
TTF    = os.path.expandvars(r"%LOCALAPPDATA%\Microsoft\Windows\Fonts\EBGaramond-VariableFont.ttf")

# (new_name, template_asset, point_size, pil_px)
# pil_px is CALIBRATED to visual glyph size, not pt*dpi: the shipped fonts were
# baked from an older static EB Garamond whose metrics differ from the current
# variable font. Anchor = shipped cap/x-height ink scaled by pt ratio
# (fnt_ui 22pt: cap 18px, x 11px; fnt_ui_small 18pt: cap 15px, x 9px).
VARIANTS = [
    ("fnt_ui_lg",       "fnt_ui",       26, 30),
    ("fnt_ui_sm",       "fnt_ui",       19, 22),
    ("fnt_ui_small_lg", "fnt_ui_small", 21, 25),
    ("fnt_ui_small_sm", "fnt_ui_small", 16, 19),
]

def load_yy(path):
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    clean = re.sub(r",(\s*[}\]])", r"\1", text)
    return json.loads(clean), text

def pil_font(px):
    f = ImageFont.truetype(TTF, px)
    try:
        f.set_variation_by_name("Regular")
    except Exception:
        pass
    return f

def render_glyphs(px, chars, aa=True):
    """Rasterize chars at px (calibrated PIL size). Returns
    (line_height, ascender, {code: (offset, shift, w, cell_image)})."""
    f = pil_font(px)
    ascent, descent = f.getmetrics()
    line_h = ascent + descent
    out = {}
    for code in chars:
        ch = chr(code)
        shift = int(round(f.getlength(ch)))
        bbox = f.getbbox(ch)  # (x0, y0, x1, y1) from left/ascender-top origin
        if code == 9647 or bbox is None or bbox[2] <= bbox[0] or ch == " ":
            if code == 9647:
                # Default/fallback char: hollow box (the TTF lacks U+25AF).
                bw, bh = max(2, int(px * 0.50)), max(3, int(px * 0.62))
                w, offset, shift = bw + 2, 1, bw + 4
                cell = Image.new("RGBA", (w, line_h), (0, 0, 0, 0))
                d = ImageDraw.Draw(cell)
                d.rectangle([1, ascent - bh, 1 + bw, ascent], outline=(255, 255, 255, 255), width=max(1, px // 16))
            else:
                # blank glyph (space): keep advance, minimal cell
                w, offset = max(shift, 1), 0
                cell = Image.new("RGBA", (w, line_h), (0, 0, 0, 0))
        else:
            x0, y0, x1, y1 = bbox
            offset = x0
            w = x1 - x0
            cell = Image.new("RGBA", (w, line_h), (0, 0, 0, 0))
            d = ImageDraw.Draw(cell)
            d.text((-x0, 0), ch, font=f, fill=(255, 255, 255, 255))
        out[code] = (offset, shift, w, cell)
    return line_h, ascent, out

def pack_atlas(glyphs, pad=2, width=512):
    """Row-pack cells; returns (atlas_image, {code: (x, y)})."""
    x, y, row_h = pad, pad, 0
    pos = {}
    items = sorted(glyphs.items())
    for code, (_, _, w, cell) in items:
        h = cell.height
        if x + w + pad > width:
            x = pad
            y += row_h + pad
            row_h = 0
        pos[code] = (x, y)
        x += w + pad
        row_h = max(row_h, h)
    total_h = y + row_h + pad
    atlas_h = 1 << max(0, math.ceil(math.log2(max(1, total_h))))
    atlas = Image.new("RGBA", (width, atlas_h), (0, 0, 0, 0))
    for code, (_, _, w, cell) in items:
        atlas.paste(cell, pos[code])
    return atlas, pos

def build_glyph_json(glyphs, pos, line_h):
    entries = []
    for code in sorted(glyphs):
        offset, shift, w, _ = glyphs[code]
        x, y = pos[code]
        entries.append(
            '    "%d":{"character":%d,"h":%d,"offset":%d,"shift":%d,"w":%d,"x":%d,"y":%d,},'
            % (code, code, line_h, offset, shift, w, x, y))
    return "{\n" + "\n".join(entries) + "\n  }"

def make_variant(new_name, template, pt_size, px):
    tdir = os.path.join(PROJ, "fonts", template)
    tmpl_data, tmpl_text = load_yy(os.path.join(tdir, template + ".yy"))
    chars = sorted(int(k) for k in tmpl_data["glyphs"].keys())
    line_h, ascent, glyphs = render_glyphs(px, chars)
    atlas, pos = pack_atlas(glyphs)

    yy = tmpl_text
    # glyphs block: replace the whole "glyphs":{...} object (ends before '  "hinting"' etc.)
    yy = re.sub(r'"glyphs":\{.*?\n  \}', '"glyphs":' + build_glyph_json(glyphs, pos, line_h),
                yy, count=1, flags=re.S)
    yy = yy.replace('"%%Name":"%s"' % template, '"%%Name":"%s"' % new_name)
    yy = re.sub(r'"name":"%s"' % template, '"name":"%s"' % new_name, yy)
    yy = re.sub(r'"size":\d+(\.\d+)?', '"size":%.1f' % float(pt_size), yy)
    yy = re.sub(r'"ascender":\d+', '"ascender":%d' % ascent, yy)
    yy = re.sub(r'"lineHeight":\d+', '"lineHeight":%d' % line_h, yy)

    odir = os.path.join(OUTDIR, new_name)
    os.makedirs(odir, exist_ok=True)
    with open(os.path.join(odir, new_name + ".yy"), "w", encoding="utf-8", newline="\n") as f:
        f.write(yy)
    atlas.save(os.path.join(odir, new_name + ".png"))
    print("built %s @ %spt  lineHeight=%d ascender=%d atlas=%dx%d"
          % (new_name, pt_size, line_h, ascent, atlas.width, atlas.height))

def draw_from_atlas(yy_path, png_path, text):
    """Compose a string the way the GM runner does (offset/shift/atlas rects) -
    QCs the baked metrics, not just PIL's rendering."""
    data, _ = load_yy(yy_path)
    atlas = Image.open(png_path).convert("RGBA")
    line_h = data["lineHeight"]
    pen, imgs = 0, []
    for ch in text:
        g = data["glyphs"].get(str(ord(ch)))
        if g is None:
            g = data["glyphs"]["9647"]
        imgs.append((pen + g["offset"], atlas.crop((g["x"], g["y"], g["x"] + g["w"], g["y"] + g["h"]))))
        pen += g["shift"]
    out = Image.new("RGBA", (max(1, pen), line_h), (0, 0, 0, 0))
    for x, im in imgs:
        out.alpha_composite(im, (max(0, x), 0))
    return out

def qc_sheet():
    text = "Gore Strike deals 12 damage (3 AP) - Tier II?"
    rows = [("fnt_ui SHIPPED 22pt", os.path.join(PROJ, "fonts", "fnt_ui", "fnt_ui.yy"),
             os.path.join(PROJ, "fonts", "fnt_ui", "fnt_ui.png"))]
    for name, tmpl, pt, px in VARIANTS:
        d = os.path.join(OUTDIR, name)
        rows.append(("%s %spt" % (name, pt), os.path.join(d, name + ".yy"), os.path.join(d, name + ".png")))
    rows.insert(3, ("fnt_ui_small SHIPPED 18pt", os.path.join(PROJ, "fonts", "fnt_ui_small", "fnt_ui_small.yy"),
                    os.path.join(PROJ, "fonts", "fnt_ui_small", "fnt_ui_small.png")))
    imgs = [(label, draw_from_atlas(y, p, text)) for label, y, p in rows]
    W = max(im.width for _, im in imgs) + 340
    H = sum(im.height + 26 for _, im in imgs) + 20
    sheet = Image.new("RGBA", (W, H), (24, 28, 40, 255))
    d = ImageDraw.Draw(sheet)
    y = 10
    for label, im in imgs:
        d.text((10, y + im.height // 2 - 6), label, fill=(160, 190, 230, 255))
        sheet.alpha_composite(im, (330, y))
        y += im.height + 26
    sheet.save(os.path.join(OUTDIR, "SHEET_fonts.png"))
    print("QC sheet:", os.path.join(OUTDIR, "SHEET_fonts.png"))

def validate():
    tdir = os.path.join(PROJ, "fonts", "fnt_ui")
    data, _ = load_yy(os.path.join(tdir, "fnt_ui.yy"))
    chars = sorted(int(k) for k in data["glyphs"].keys())
    line_h, ascent, glyphs = render_glyphs(22, chars)
    print("shipped: lineHeight=%s ascender=%s | mine: lineHeight=%d ascender=%d"
          % (data["lineHeight"], data["ascender"], line_h, ascent))
    deltas = {"shift": [], "offset": [], "w": []}
    worst = []
    for code in chars:
        if code == 9647:
            continue
        g = data["glyphs"][str(code)]
        offset, shift, w, _ = glyphs[code]
        ds, do, dw = shift - g["shift"], offset - g["offset"], w - g["w"]
        deltas["shift"].append(ds)
        deltas["offset"].append(do)
        deltas["w"].append(dw)
        if abs(ds) > 1:
            worst.append((chr(code), "shift", g["shift"], shift))
    for k, v in deltas.items():
        exact = sum(1 for d in v if d == 0)
        within1 = sum(1 for d in v if abs(d) <= 1)
        print("%s: exact %d/%d, within±1 %d/%d, max|d|=%d"
              % (k, exact, len(v), within1, len(v), max(abs(d) for d in v)))
    if worst:
        print("shift deltas >1:", worst[:15])

if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "validate"
    if mode == "validate":
        validate()
    else:
        for args in VARIANTS:
            make_variant(*args)
        qc_sheet()
