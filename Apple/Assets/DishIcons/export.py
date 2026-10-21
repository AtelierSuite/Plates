import json
import os
import random
import subprocess
import xml.etree.ElementTree as ET

from PIL import Image

from catalog import HIDDEN, V
from draw import REGIONS, VESSELS, fluent

# Writes every vessel and ingredient variant out as its own prepared SVG, and a manifest that
# says what each one is and how the layout treats it. The layout reads only these files.

OUT = "Parts"


def pascal(name):
    return "".join(part.capitalize() for part in name.split("-"))


def write(path, size, body):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    text = f'<svg width="{size}" height="{size}" viewBox="0 0 {size} {size}" xmlns="http://www.w3.org/2000/svg">{body}</svg>\n'
    ET.fromstring(text)
    with open(path, "w") as f:
        f.write(text)


def prepare(out_dir, ingredient, variant, entry, rank):
    """Writes one variant's prepared SVG and returns its manifest entry, before tones."""
    name = pascal(ingredient) + pascal(variant)
    if entry["kind"] == "fill":
        file = f"Fills/{name}.svg"
        write(f"{out_dir}/{file}", 64, fluent(entry["make"](random.Random(f"{ingredient}-{variant}")), turned=False))
        out = {"kind": "fill", "file": file, "vessels": entry["vessels"], "rank": rank}
        if entry.get("covers"):
            out["covers"] = True
    else:
        file = f"Pieces/{name}.svg"
        write(f"{out_dir}/{file}", 16, fluent(entry["svg"], turned=True))
        out = {"kind": "piece", "file": file, "size": entry["size"], "count": entry["count"], "tier": entry["tier"], "rank": rank}
        if "most" in entry:
            out["most"] = entry["most"]
    return out


def measure(png, well=False, single=False):
    """The colours a part reads as, measured off the part as CoreSVG draws it."""
    im = Image.open(png).convert("RGBA")
    if well:
        w, h = im.size
        im = im.crop((w // 2 - 6, h // 2 - 6, w // 2 + 6, h // 2 + 6))
    # Parts are shaded, so a colour spreads across a range. Pixels are grouped coarsely and each
    # group is read as the average of what fell in it.
    groups = {}
    for r, g, b, a in im.getdata():
        if a > 200:
            groups.setdefault((r // 32, g // 32, b // 32), []).append((r, g, b))
    total = sum(len(v) for v in groups.values())
    ranked = sorted(groups.values(), key=len, reverse=True)[:3]
    tones = ["#%02x%02x%02x" % tuple(round(sum(c[i] for c in v) / len(v)) for i in range(3)) for v in ranked if len(v) > total * 0.12]
    return tones[:1] if well or single else tones


def main():
    manifest = {"vessels": {}, "regions": {k: {r: list(v) for r, v in rs.items()} for k, rs in REGIONS.items()}, "ingredients": {}, "hidden": HIDDEN}
    for name, (svg, kind) in VESSELS.items():
        file = f"Vessels/{pascal(name)}.svg"
        write(f"{OUT}/{file}", 96, svg)
        manifest["vessels"][name] = {"file": file, "kind": kind}

    for ingredient in sorted(V):
        for rank, (variant, entry) in enumerate(V[ingredient].items()):
            manifest["ingredients"].setdefault(ingredient, {})[variant] = prepare(OUT, ingredient, variant, entry, rank)

    # The colours each part reads as, measured off the part as CoreSVG draws it. The layout uses
    # them to tell when a piece would vanish into what it sits on.
    jobs, targets = [], []
    os.makedirs("/tmp/dish/tones", exist_ok=True)
    for name, v in manifest["vessels"].items():
        jobs.append(f"{OUT}/{v['file']} /tmp/dish/tones/vessel-{name}.png 96")
        targets.append((v, f"/tmp/dish/tones/vessel-{name}.png", "well"))
    for ingredient, variants in manifest["ingredients"].items():
        for variant, e in variants.items():
            png = f"/tmp/dish/tones/{ingredient}-{variant}.png"
            jobs.append(f"{OUT}/{e['file']} {png} 48")
            targets.append((e, png, "main"))
    with open("/tmp/dish/tones.txt", "w") as f:
        f.write("\n".join(jobs) + "\n")
    subprocess.run(["/tmp/dish/render", "/tmp/dish/tones.txt"], check=True)
    for entry, png, what in targets:
        entry["tones"] = measure(png, well=what == "well", single=entry.get("kind") == "fill")

    with open(f"{OUT}/manifest.json", "w") as f:
        json.dump(manifest, f, indent=2)
        f.write("\n")
    fills = sum(1 for v in manifest["ingredients"].values() for e in v.values() if e["kind"] == "fill")
    pieces = sum(1 for v in manifest["ingredients"].values() for e in v.values() if e["kind"] == "piece")
    print(f"{len(manifest['vessels'])} vessels, {fills} fills, {pieces} pieces, {len(HIDDEN)} hidden")

    # Copy the prepared parts into the app through the Swift sync tool.
    subprocess.run(["swift", "sync.swift"], check=True)


if __name__ == "__main__":
    main()
