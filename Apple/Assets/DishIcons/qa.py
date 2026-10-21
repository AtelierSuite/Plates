import json
import os
import subprocess
import sys

from layout import compose, inner, manifest

# Review sheets. Every piece is laid out on each of the surfaces it is likely to land on, and
# every fill is laid into each vessel it is allowed in, so a part that disappears or clashes
# anywhere shows up on a sheet.

OUT = "Review"
RENDER = "/tmp/dish/render"
CELL = 100

SURFACES = [
    ("plate", []),
    ("plate-rim", [["rice", "mound"]]),
    ("plate", [["rice", "fried"]]),
    ("plate", [["tomato", "sauce"]]),
    ("plate-sage", [["curry-roux", "sauce"]]),
    ("plate", [["spaghetti", "creamy"]]),
    ("bowl", [["lettuce", "bed"]]),
    ("bowl-indigo", [["ramen", "broth"]]),
    ("pan", []),
]
VESSEL_FOR = {"plate": "plate-rim", "bowl": "bowl-indigo", "pan": "pan", "pot": "pot", "board": "board"}


def sheet(rows, path, columns):
    w, h = columns * CELL, len(rows) * CELL
    s = f'<svg width="{w}" height="{h}" viewBox="0 0 {w} {h}" xmlns="http://www.w3.org/2000/svg"><rect width="{w}" height="{h}" fill="#ffffff"/>'
    for y, row in enumerate(rows):
        for x, cell in enumerate(row):
            if cell:
                s += f'<g transform="translate({x * CELL + 2} {y * CELL + 2}) scale({(CELL - 4) / 96:.4f})">{inner(cell)}</g>'
    with open(path, "w") as f:
        f.write(s + "</svg>\n")


def main():
    os.makedirs(OUT, exist_ok=True)
    pieces, fills = [], []
    for ingredient, variants in sorted(manifest["ingredients"].items()):
        for variant, e in variants.items():
            (fills if e["kind"] == "fill" else pieces).append((ingredient, variant, e))
    jobs = []
    per = 30
    index = {}
    for n in range(0, len(pieces), per):
        chunk = pieces[n:n + per]
        rows = [[compose(f"{i}-{v}-{k}", vessel, base + [[i, v]]) for k, (vessel, base) in enumerate(SURFACES)] for i, v, _ in chunk]
        name = f"{OUT}/pieces-{n // per + 1:02d}"
        sheet(rows, name + ".svg", len(SURFACES))
        jobs.append(f"{name}.svg {name}.png {len(SURFACES) * CELL}")
        index[name] = [f"{i} {v}" for i, v, _ in chunk]
    fill_rows = []
    for i, v, e in fills:
        fill_rows.append([compose(f"{i}-{v}-{k}", VESSEL_FOR[k], ([["rice", "bowl" if k in ("bowl", "pot") else "mound"]] if e.get("covers") and k != "board" else []) + [[i, v]]) for k in e["vessels"]])
    for n in range(0, len(fill_rows), per):
        name = f"{OUT}/fills-{n // per + 1:02d}"
        sheet(fill_rows[n:n + per], name + ".svg", 4)
        jobs.append(f"{name}.svg {name}.png {4 * CELL}")
        index[name] = [f"{i} {v} {e['vessels']}" for i, v, e in fills[n:n + per]]
    with open("/tmp/dish/jobs.txt", "w") as f:
        f.write("\n".join(jobs) + "\n")
    subprocess.run([RENDER, "/tmp/dish/jobs.txt"], check=True)
    with open(f"{OUT}/index.json", "w") as f:
        json.dump(index, f, indent=1)
    print(len(pieces), "pieces,", len(fills), "fills,", len(jobs), "sheets")


if __name__ == "__main__":
    main()
