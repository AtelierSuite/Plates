import copy
import json
import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

import layout
from catalog import V
from export import measure, prepare
from qa import SURFACES, VESSEL_FOR

# Draws a few ingredients' parts straight from the catalog, without exporting anything, and lays
# each one out the way the review sheets do: a piece on every surface, a fill in every vessel it
# may go in. Usage: python3 preview.py out.png ingredient [ingredient ...]

RENDER = "/tmp/dish/render"
CELL = 150


def main():
    out, names = sys.argv[1], sys.argv[2:]
    tmp = tempfile.mkdtemp()
    parts = f"{tmp}/Parts"
    shutil.copytree(layout.PARTS, parts)
    manifest = copy.deepcopy(layout.manifest)
    rows, labels, jobs = [], [], []
    for ingredient in names:
        for rank, (variant, entry) in enumerate(V[ingredient].items()):
            e = prepare(parts, ingredient, variant, entry, rank)
            png = f"{tmp}/{ingredient}-{variant}-tone.png"
            open(f"{tmp}/tone.txt", "w").write(f"{parts}/{e['file']} {png} 48\n")
            subprocess.run([RENDER, f"{tmp}/tone.txt"], check=True, capture_output=True)
            e["tones"] = measure(png, single=e["kind"] == "fill")
            manifest["ingredients"].setdefault(ingredient, {})[variant] = e
    layout.PARTS, layout.manifest, layout._bodies = parts, manifest, {}
    for ingredient in names:
        for variant, e in manifest["ingredients"][ingredient].items():
            if e["kind"] == "piece":
                row = [layout.compose(f"{ingredient}-{variant}-{k}", vessel, base + [[ingredient, variant]]) for k, (vessel, base) in enumerate(SURFACES)]
            else:
                row = []
                for k in e["vessels"]:
                    under = [["rice", "bowl" if k in ("bowl", "pot") else "mound"]] if e.get("covers") and k != "board" else []
                    row.append(layout.compose(f"{ingredient}-{variant}-{k}", VESSEL_FOR[k], under + [[ingredient, variant]]))
            rows.append(row)
            labels.append(f"{ingredient} {variant}")
    columns = max(len(r) for r in rows)
    for i, row in enumerate(rows):
        svg = f'<svg width="{columns * 96}" height="96" viewBox="0 0 {columns * 96} 96" xmlns="http://www.w3.org/2000/svg">'
        svg += "".join(f'<g transform="translate({x * 96} 0)">{layout.inner(cell)}</g>' for x, cell in enumerate(row)) + "</svg>"
        open(f"{tmp}/row{i}.svg", "w").write(svg)
        jobs.append(f"{tmp}/row{i}.svg {tmp}/row{i}.png {columns * CELL}")
    open(f"{tmp}/rows.txt", "w").write("\n".join(jobs) + "\n")
    subprocess.run([RENDER, f"{tmp}/rows.txt"], check=True, capture_output=True)
    font = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 18)
    sheet = Image.new("RGB", (columns * CELL + 220, len(rows) * CELL), "#ffffff")
    draw = ImageDraw.Draw(sheet)
    for i, label in enumerate(labels):
        im = Image.open(f"{tmp}/row{i}.png")
        sheet.paste(im, (220, i * CELL), im)
        draw.text((10, i * CELL + CELL // 2), label, font=font, fill="#000000", anchor="lm")
    sheet.save(out)
    print(out)


if __name__ == "__main__":
    main()
