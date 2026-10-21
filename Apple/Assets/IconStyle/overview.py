# Renders every ingredient and tool icon from the working tree into contact sheets.
# Usage: python3 overview.py /tmp/icons "#ffffff" all   (or a list of names instead of "all")
import glob, os, subprocess, sys, tempfile
from PIL import Image, ImageDraw, ImageFont
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
prefix, bg, names = sys.argv[1], sys.argv[2], sys.argv[3:]
paths = {}
for cat in ("Ingredients", "Tools"):
    for p in sorted(glob.glob(f"{ROOT}/Plates/{cat}.xcassets/*.imageset/*.svg")):
        paths[os.path.basename(p)[:-4]] = p
if names == ["all"]:
    names = list(paths)
tmp = tempfile.mkdtemp()
open(f"{tmp}/l.txt", "w").write("".join(f"{paths[n]} {tmp}/{n}.png 112\n" for n in names))
subprocess.run(["swift", f"{ROOT}/Assets/DishIcons/render.swift", f"{tmp}/l.txt"], check=True)
font = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 15)
fg = "#000" if bg == "#ffffff" else "#fff"
cols, cw, ch, per = 12, 150, 150, 120
for page in range(0, len(names), per):
    chunk = names[page:page + per]
    rows = (len(chunk) + cols - 1) // cols
    img = Image.new("RGB", (cols * cw, rows * ch), bg)
    d = ImageDraw.Draw(img)
    for i, n in enumerate(chunk):
        x, y = (i % cols) * cw, (i // cols) * ch
        im = Image.open(f"{tmp}/{n}.png")
        img.paste(im, (x + 19, y + 4), im)
        d.text((x + cw // 2, y + 132), n, font=font, fill=fg, anchor="mm")
    out = f"{prefix}-{page // per + 1}.png"
    img.save(out)
    print(out)
