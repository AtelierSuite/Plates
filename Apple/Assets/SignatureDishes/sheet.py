# Renders signature dish icons through CoreSVG, the path the asset catalog uses, on light and
# dark at the sizes the app draws them: 168 pt in the recipe header and 72 pt as the smallest.
# Usage: python3 sheet.py out.png Name [Name ...]    (Name as in DishSignature<Name>, or "all")
import os, subprocess, sys, tempfile
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CATALOG = os.path.join(ROOT, "Plates", "SignatureDishes.xcassets")
RENDER = os.path.join(ROOT, "Assets", "DishIcons", "render.swift")

def path(name):
    asset = f"DishSignature{name}"
    return os.path.join(CATALOG, f"{asset}.imageset", f"{asset}.svg")

out, names = sys.argv[1], sys.argv[2:]
if names == ["all"]:
    names = sorted(d[len("DishSignature"):-len(".imageset")] for d in os.listdir(CATALOG) if d.endswith(".imageset"))
missing = [n for n in names if not os.path.exists(path(n))]
if missing:
    sys.exit("no icon named " + ", ".join(missing))

tmp = tempfile.mkdtemp()
sizes = (336, 144)
lines = [f"{path(n)} {tmp}/{n}-{s}.png {s}" for n in names for s in sizes]
open(f"{tmp}/list.txt", "w").write("\n".join(lines) + "\n")
subprocess.run(["swift", RENDER, f"{tmp}/list.txt"], check=True)

font = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 18)
cell_w, cell_h = 360, 560
per_row = min(len(names), 4)
rows = (len(names) + per_row - 1) // per_row
img = Image.new("RGB", (cell_w * per_row * 2, cell_h * rows), "#ffffff")
d = ImageDraw.Draw(img)
d.rectangle([cell_w * per_row, 0, img.width, img.height], fill="#1c1c1e")
for i, n in enumerate(names):
    col, row = i % per_row, i // per_row
    for side, fg in ((0, "#000000"), (1, "#ffffff")):
        x = side * cell_w * per_row + col * cell_w
        y = row * cell_h
        d.text((x + cell_w // 2, y + 18), n, font=font, fill=fg, anchor="mm")
        big = Image.open(f"{tmp}/{n}-{sizes[0]}.png")
        small = Image.open(f"{tmp}/{n}-{sizes[1]}.png")
        img.paste(big, (x + 12, y + 36), big)
        img.paste(small, (x + 12, y + 36 + sizes[0] + 12), small)
img.save(out)
print(out)
