import json
import math
import random
import re

# Builds a dish icon from the prepared parts alone. A dish is a vessel and a list of layers,
# each an ingredient and one of its variants, optionally with a piece count. The manifest says
# which layers are fills and which are pieces, and where on each kind of vessel a fill sits.

PARTS = "Parts"
manifest = json.load(open(f"{PARTS}/manifest.json"))
_bodies = {}


def body(file):
    if file not in _bodies:
        svg = re.sub(r"^\s*<svg[^>]*>|</svg>\s*$", "", open(f"{PARTS}/{file}").read())
        # Gradient ids are only unique within a part, so they are named after it once parts
        # share one sheet.
        name = re.sub(r"\W", "", file)
        svg = re.sub(r'id="([^"]+)"', rf'id="{name}-\1"', svg)
        _bodies[file] = re.sub(r"url\(#([^)]+)\)", rf"url(#{name}-\1)", svg)
    return _bodies[file]


def silhouette(svg):
    """The piece in one dark colour, the way SwiftUI draws a template image."""
    svg = re.sub(r"<defs>.*?</defs>", "", svg)
    svg = re.sub(r'(fill|stroke)="(#[0-9a-fA-F]{3,6}|url\(#[^)]+\))"', r'\1="#000000"', svg)
    return re.sub(r' opacity="[0-9.]+"', "", svg)


def scatter(rng, region, count, size, taken, center):
    cx, cy, r = region
    placed = []
    for _ in range(count):
        for attempt in range(80):
            spread = (0.12 if count == 1 else 0.6) if center else 0.85
            a, d = rng.uniform(0, math.tau), r * spread * math.sqrt(rng.random())
            x, y = cx + d * math.cos(a), cy + d * math.sin(a)
            gap = 0.5 if center else 0.42
            if attempt > 60 or all(math.hypot(x - tx, y - ty) > (size + ts) * gap for tx, ty, ts in taken):
                taken.append((x, y, size))
                placed.append((x, y, 0 if center else rng.uniform(0, 360)))
                break
    return placed


def lab(h):
    def lin(c):
        c /= 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (lin(int(h[i:i + 2], 16)) for i in (1, 3, 5))
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
    f = lambda t: t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116
    return (116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z)))


def distance(a, b):
    return sum((p - q) ** 2 for p, q in zip(lab(a), lab(b))) ** 0.5


def mix(a, b, t):
    pa = [int(a[i:i + 2], 16) for i in (1, 3, 5)]
    pb = [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return "#%02x%02x%02x" % tuple(round(x + (y - x) * t) for x, y in zip(pa, pb))


# A piece whose colours all sit closer than this to the surface under it gets an outline.
CLASH = 18
DIRECTIONS = [(1, 0), (-1, 0), (0, 1), (0, -1), (0.7, 0.7), (-0.7, 0.7), (0.7, -0.7), (-0.7, -0.7)]


def outline_for(tones, surface):
    """The edge a piece needs on this surface, or None when it reads without one."""
    if not tones or max(distance(t, surface) for t in tones) >= CLASH:
        return None
    return mix(surface, "#3a3026", 0.4) if lab(surface)[0] > 45 else mix(surface, "#ffffff", 0.45)


def piece(svg, x, y, size, rot, edge=None):
    t = f"translate({x:.1f} {y:.1f}) rotate({rot:.0f}) scale({size / 16:.3f}) translate(-8 -8)"
    out = f'<g opacity="0.22" transform="translate(0.35 0.7)"><g transform="{t}">{silhouette(svg)}</g></g>'
    if edge:
        stamp = silhouette(svg).replace("#000000", edge)
        out += "".join(f'<g transform="translate({dx * 0.7:.2f} {dy * 0.7:.2f})"><g transform="{t}">{stamp}</g></g>' for dx, dy in DIRECTIONS)
    return out + f'<g transform="{t}">{svg}</g>'


def compose(dish_id, vessel, layers):
    rng = random.Random(dish_id)
    v = manifest["vessels"][vessel]
    regions = manifest["regions"][v["kind"]]
    entries = []
    for layer in layers:
        ingredient, variant = layer[0], layer[1]
        if ingredient in manifest["hidden"]:
            continue
        if variant not in manifest["ingredients"].get(ingredient, {}):
            raise ValueError(f"{ingredient} has no {variant} variant")
        e = dict(manifest["ingredients"][ingredient][variant])
        if len(layer) > 2:
            e["count"] = layer[2]
        if e["kind"] == "fill" and v["kind"] not in e["vessels"] and not (v["kind"] == "board" and "board" in e["vessels"]):
            raise ValueError(f"{ingredient} {variant} does not go on a {v['kind']}")
        entries.append(e)
    bases = [e for e in entries if e["kind"] == "fill" and not e.get("covers")]
    slots = iter(["full"] if len(bases) <= 1 else ["left", "right"])
    out = [body(v["file"])]
    region = regions["full"]
    surface = v["tones"][0]
    tiers = {0: [], 1: [], 2: []}
    taken = []
    for e in entries:
        if e["kind"] == "fill":
            if not e.get("covers"):
                region = regions[next(slots)]
                taken = []
            surface = e["tones"][0]
            cx, cy, r = region
            out.append(f'<g transform="translate({cx} {cy}) scale({r / 30:.3f}) translate(-32 -32)">{body(e["file"])}</g>')
        else:
            # Garnish is scattered over everything except what is set in the middle, so a
            # sprinkle never lands across the fried egg.
            pool = taken if e["tier"] != 2 else [t for t in taken if t[2] >= 18]
            edge = outline_for(e["tones"], surface)
            for x, y, rot in scatter(rng, region, e["count"], e["size"], pool, e["tier"] == 1):
                tiers[e["tier"]].append(piece(body(e["file"]), x, y, e["size"], rot, edge))
    out += tiers[0] + tiers[1] + tiers[2]
    return '<svg width="96" height="96" viewBox="0 0 96 96" xmlns="http://www.w3.org/2000/svg">' + "".join(out) + "</svg>\n"


def inner(svg):
    return re.sub(r"^<svg[^>]*>|</svg>\s*$", "", svg.strip())


if __name__ == "__main__":
    import subprocess
    from qa import sheet

    dishes = json.load(open("dishes.json"))
    rows = []
    for n in range(0, len(dishes), 8):
        rows.append([compose(d["id"], d["vessel"], d["layers"]) for d in dishes[n:n + 8]])
    sheet(rows, "dishes.svg", 8)
    with open("/tmp/dish/dishes.txt", "w") as f:
        f.write("dishes.svg dishes.png 1600\n")
    subprocess.run(["/tmp/dish/render", "/tmp/dish/dishes.txt"], check=True)
