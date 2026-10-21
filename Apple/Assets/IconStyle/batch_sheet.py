# Renders icons before (HEAD) and after (working tree) through CoreSVG, the path the asset
# catalog uses, and lays them out on light and dark at 48 pt and 20 pt.
# Usage: python3 batch_sheet.py out.png Name [Name ...]
import os, subprocess, sys, tempfile
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RENDER = os.path.join(ROOT, "Assets", "DishIcons", "render.swift")
out, names = sys.argv[1], sys.argv[2:]
tmp = tempfile.mkdtemp()

def find(name):
    for cat in ("Ingredients", "Tools"):
        rel = f"Plates/{cat}.xcassets/{name}.imageset/{name}.svg"
        if os.path.exists(os.path.join(ROOT, rel)):
            return rel
    sys.exit(f"no icon named {name}")

lines = []
for n in names:
    rel = find(n)
    before = subprocess.run(["git", "-C", ROOT, "show", f"HEAD:{rel}"], capture_output=True, text=True).stdout
    open(f"{tmp}/{n}-old.svg", "w").write(before)
    for key, src in (("old", f"{tmp}/{n}-old.svg"), ("new", os.path.join(ROOT, rel))):
        for s in (144, 60):
            lines.append(f"{src} {tmp}/{key}-{n}-{s}.png {s}")
open(f"{tmp}/list.txt", "w").write("\n".join(lines) + "\n")
subprocess.run(["swift", RENDER, f"{tmp}/list.txt"], check=True)

sf = "/System/Library/Fonts/SFNS.ttf"
small = ImageFont.truetype(sf, 20)
cell, rowh = 170, 230
W = 110 + cell * len(names) * 2
H = 40 + rowh * 2
img = Image.new("RGB", (W, H), "#f2f2f7")
d = ImageDraw.Draw(img)
half = cell * len(names)
for p, (bg, fg) in enumerate((("#ffffff", "#000"), ("#1c1c1e", "#fff"))):
    x0 = 110 + p * half
    d.rectangle([x0, 0, x0 + half, H], fill=bg)
    for i, n in enumerate(names):
        d.text((x0 + i * cell + cell // 2, 20), n, font=small, fill=fg, anchor="mm")
        for r, key in enumerate(("old", "new")):
            y = 40 + r * rowh
            for s, (dx, dy) in ((144, (4, 10)), (60, (100, 160))):
                path = f"{tmp}/{key}-{n}-{s}.png"
                if os.path.exists(path):
                    im = Image.open(path)
                    img.paste(im, (x0 + i * cell + dx, y + dy), im)
for r, key in enumerate(("Before", "After")):
    d.text((10, 40 + r * rowh + rowh // 2), key, font=small, fill="#000", anchor="lm")
img.save(out)
print(out)
