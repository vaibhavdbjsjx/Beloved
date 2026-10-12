#!/usr/bin/env python3
"""Tiles screenshots into one labelled contact sheet for visual review.

    python3 scripts/contact_sheet.py OUT.png img1.png img2.png ... [--cols 4] [--width 300]
"""
import sys
from PIL import Image, ImageDraw

args = [a for a in sys.argv[1:]]
cols = 4
width = 300
if "--cols" in args:
    i = args.index("--cols"); cols = int(args[i + 1]); del args[i:i + 2]
if "--width" in args:
    i = args.index("--width"); width = int(args[i + 1]); del args[i:i + 2]
out, paths = args[0], args[1:]
thumbs = []
for p in paths:
    im = Image.open(p).convert("RGB")
    h = int(im.height * width / im.width)
    thumbs.append((p.rsplit("/", 1)[-1].rsplit(".", 1)[0], im.resize((width, h), Image.LANCZOS)))
label = 22
cell_h = max(t.height for _, t in thumbs) + label
rows = (len(thumbs) + cols - 1) // cols
sheet = Image.new("RGB", (cols * (width + 8) + 8, rows * (cell_h + 8) + 8), (120, 120, 120))
draw = ImageDraw.Draw(sheet)
for n, (name, t) in enumerate(thumbs):
    x = 8 + (n % cols) * (width + 8)
    y = 8 + (n // cols) * (cell_h + 8)
    draw.text((x + 4, y + 4), name, fill=(255, 255, 255))
    sheet.paste(t, (x, y + label))
sheet.save(out)
print(out, sheet.size)
