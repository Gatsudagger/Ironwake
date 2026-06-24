#!/usr/bin/env python
# Download all 16 candidate frames of a PixelLab object and tile them into a
# labelled 4x4 contact sheet on a grey checker bg so transparency is visible.
# Usage: python fx_contact.py <object_id> <out_png>
import sys, io, urllib.request
from PIL import Image, ImageDraw

PROJECT = "c50e1365-1a8c-44be-a773-5ee635581147"

def checker(w, h, c=8):
    im = Image.new("RGBA", (w, h), (40, 40, 48, 255))
    d = ImageDraw.Draw(im)
    for y in range(0, h, c):
        for x in range(0, w, c):
            if (x // c + y // c) % 2 == 0:
                d.rectangle([x, y, x + c, y + c], fill=(58, 58, 68, 255))
    return im

def main():
    obj_id, out = sys.argv[1], sys.argv[2]
    cell, pad, cols = 64, 18, 4
    rows = 4
    sheet = Image.new("RGBA", (cols * (cell + pad) + pad, rows * (cell + pad) + pad), (20, 20, 26, 255))
    draw = ImageDraw.Draw(sheet)
    for i in range(16):
        url = f"https://backblaze.pixellab.ai/file/pixellab-characters/objects/{PROJECT}/{obj_id}/rotations/frame_{i}.png"
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        data = urllib.request.urlopen(req, timeout=60).read()
        im = Image.open(io.BytesIO(data)).convert("RGBA")
        bg = checker(im.width, im.height)
        bg.alpha_composite(im)
        cx = pad + (i % cols) * (cell + pad)
        cy = pad + (i // cols) * (cell + pad)
        sheet.paste(bg, (cx, cy))
        draw.text((cx + 1, cy - 13), str(i), fill=(220, 220, 120, 255))
    sheet.convert("RGB").save(out)
    print("OK", out)

main()
