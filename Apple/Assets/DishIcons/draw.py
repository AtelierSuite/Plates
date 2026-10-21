import colorsys
import math
import random
import re

# The shapes every prepared part is drawn from. Pieces are drawn on a 16 x 16 canvas around
# (8, 8). Fills are drawn on a 64 x 64 canvas into the circle around (32, 32) of radius 30,
# which the layout scales onto whichever region of a vessel the fill lands in. Vessels are
# drawn on the 96 x 96 canvas the finished icon uses.

C, R = 32, 30


def f(x):
    return f"{x:.1f}".rstrip("0").rstrip(".")


def blob_path(rng, cx, cy, r, wobble=0.08, points=12):
    pts = []
    for i in range(points):
        a = math.tau * i / points
        rr = r * (1 + rng.uniform(-wobble, wobble))
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d = f"M{f(pts[0][0])} {f(pts[0][1])}"
    n = len(pts)
    for i in range(n):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[(i + 1) % n], pts[(i + 2) % n]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        d += f"C{f(c1[0])} {f(c1[1])} {f(c2[0])} {f(c2[1])} {f(p2[0])} {f(p2[1])}"
    return d + "Z"


def scatter_in_circle(rng, cx, cy, r, count, gap=0.0):
    out = []
    for _ in range(count * 6):
        if len(out) >= count:
            break
        a = rng.uniform(0, math.tau)
        d = r * math.sqrt(rng.random())
        x, y = cx + d * math.cos(a), cy + d * math.sin(a)
        if gap and any(math.hypot(x - ox, y - oy) < gap for ox, oy in out):
            continue
        out.append((x, y))
    return out


def place(svg, x, y, size, rot=0):
    return f'<g transform="translate({f(x)} {f(y)}) rotate({f(rot)}) scale({f(size / 16)}) translate(-8 -8)">{svg}</g>'


# Fluent shading --------------------------------------------------------------------------
#
# Parts are written in flat colours and shaded as they are exported, the way the ingredient
# icons are drawn (Assets/IconStyle/STYLE.md): every solid shape runs from a lighter tint to a
# deeper shade of its own colour. Fills and vessels never turn, so they are lit from the top
# left. Pieces are turned to any angle on the dish, so they darken toward their edges instead, and
# a turned piece never looks lit from below. Strokes, see-through shapes and specks stay flat.


def ramp(color, lift, drop):
    r, g, b = (int(color[i:i + 2], 16) / 255 for i in (1, 3, 5))
    h, l, s = colorsys.rgb_to_hls(r, g, b)

    def hex_of(h2, l2, s2):
        return "#%02x%02x%02x" % tuple(round(c * 255) for c in colorsys.hls_to_rgb(h2 % 1, max(0, min(1, l2)), max(0, min(1, s2))))

    # Tints run a little warmer and shades a little deeper, as Fluent's do.
    warm = 0.012 if 0.08 < h < 0.5 else -0.012
    return hex_of(h - warm, l + (1 - l) * lift, s), color, hex_of(h + warm, l * (1 - drop), s * 1.12)


SHAPE = re.compile(r"<(path|circle|ellipse|rect|polygon)\b[^>]*>")


def fluent(svg, turned):
    defs = {}

    def shade(match):
        element = match.group(0)
        fill = re.search(r'fill="(#[0-9a-fA-F]{6})"', element)
        if not fill or "opacity" in element:
            return element
        radius = re.search(r'\br="([0-9.]+)"', element)
        if match.group(1) == "circle" and radius and float(radius.group(1)) < 1.4:
            return element
        color = fill.group(1).lower()
        key = ("p" if turned else "f") + color[1:]
        defs[key] = color
        return element.replace(fill.group(0), f'fill="url(#{key})"')

    body = SHAPE.sub(shade, svg)
    out = ""
    for key, color in defs.items():
        if turned:
            tint, base, deep = ramp(color, 0.08, 0.2)
            out += f'<radialGradient id="{key}" cx="0.5" cy="0.5" r="0.62"><stop offset="0" stop-color="{tint}"/><stop offset="0.55" stop-color="{base}"/><stop offset="1" stop-color="{deep}"/></radialGradient>'
        else:
            tint, base, deep = ramp(color, 0.3, 0.2)
            out += f'<linearGradient id="{key}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{tint}"/><stop offset="0.5" stop-color="{base}"/><stop offset="1" stop-color="{deep}"/></linearGradient>'
    return (f"<defs>{out}</defs>" if out else "") + body


# Pieces ------------------------------------------------------------------------------------


def dice(m, l):
    return f'<rect x="2.5" y="2.5" width="11" height="11" rx="2.4" fill="{m}"/><rect x="4" y="4" width="5.5" height="4.4" rx="1.6" fill="{l}"/>'


def cube(m, l, edge=None):
    e = edge or m
    return f'<rect x="2.5" y="2.5" width="11" height="11" rx="1.6" fill="{e}"/><rect x="3.6" y="3.6" width="8.8" height="8.8" rx="1.2" fill="{m}"/><rect x="4.6" y="4.6" width="4" height="2" rx="1" fill="{l}"/>'


def chunk(m, l):
    return f'<path d="M2 6.5 7.5 2.5 14 5.5 13 12.5 5 14 1.5 10.5Z" fill="{m}"/><path d="M5 6l4.5-2" stroke="{l}" stroke-width="1.6" stroke-linecap="round"/>'


def round_slice(rind, flesh, core=None, seeds=None, rings=None):
    s = f'<circle cx="8" cy="8" r="7" fill="{rind}"/><circle cx="8" cy="8" r="5.6" fill="{flesh}"/>'
    if rings:
        s += f'<circle cx="8" cy="8" r="3.6" fill="none" stroke="{rings}" stroke-width="0.9"/>'
    if seeds:
        for i in range(6):
            a = math.tau * i / 6
            s += f'<ellipse cx="{f(8 + 3.2 * math.cos(a))}" cy="{f(8 + 3.2 * math.sin(a))}" rx="0.9" ry="0.6" fill="{seeds}" transform="rotate({f(math.degrees(a))} {f(8 + 3.2 * math.cos(a))} {f(8 + 3.2 * math.sin(a))})"/>'
    if core:
        s += f'<circle cx="8" cy="8" r="1.6" fill="{core}"/>'
    return s


def half_moon(rind, flesh, seeds=None):
    s = f'<path d="M1 11a7 7 0 0 1 14 0Z" fill="{rind}"/><path d="M2.4 11a5.6 5.6 0 0 1 11.2 0Z" fill="{flesh}"/>'
    if seeds:
        s += "".join(f'<circle cx="{x}" cy="9" r="0.7" fill="{seeds}"/>' for x in (5.5, 8, 10.5))
    return s


def wedge(skin, flesh, seeds=None):
    s = f'<path d="M2 13A10 10 0 0 1 14 2.5Z" fill="{skin}"/><path d="M4.4 11.4A7 7 0 0 1 11.8 5Z" fill="{flesh}"/>'
    if seeds:
        s += f'<circle cx="7.4" cy="8.6" r="0.8" fill="{seeds}"/><circle cx="9.4" cy="7.2" r="0.8" fill="{seeds}"/>'
    return s


def citrus_wheel(rind, pith, flesh):
    s = f'<circle cx="8" cy="8" r="7" fill="{rind}"/><circle cx="8" cy="8" r="6" fill="{pith}"/><circle cx="8" cy="8" r="5.2" fill="{flesh}"/>'
    s += "".join(
        f'<path d="M8 8L{f(8 + 5.2 * math.cos(math.tau * i / 8))} {f(8 + 5.2 * math.sin(math.tau * i / 8))}" stroke="{pith}" stroke-width="0.8"/>'
        for i in range(8)
    )
    return s


def citrus_wedge(rind, pith, flesh):
    return (
        f'<path d="M1 10a7 7 0 0 1 14 0Z" fill="{rind}"/><path d="M2.2 10a5.8 5.8 0 0 1 11.6 0Z" fill="{pith}"/>'
        f'<path d="M3 10a5 5 0 0 1 10 0Z" fill="{flesh}"/><path d="M8 10V5M8 10l-3.5-3.5M8 10l3.5-3.5" stroke="{pith}" stroke-width="0.8"/>'
    )


def strip(m, l):
    return f'<rect x="1" y="5.5" width="14" height="5" rx="2.5" fill="{m}"/><path d="M3.5 7h8" stroke="{l}" stroke-width="1.3" stroke-linecap="round"/>'


def julienne(m, l=None):
    s = f'<rect x="6.9" y="1" width="2.2" height="14" rx="1.1" fill="{m}"/>'
    if l:
        s += f'<rect x="4" y="2.5" width="2" height="11" rx="1" fill="{l}" transform="rotate(14 5 8)"/>'
    return s


def ring(m, l=None, width=2.2):
    s = f'<circle cx="8" cy="8" r="5.4" fill="none" stroke="{m}" stroke-width="{width}"/>'
    if l:
        # The second colour runs inside the band itself, so the hole stays open and a ring never
        # reads as a target.
        s += f'<circle cx="8" cy="8" r="{f(5.4 - width * 0.22)}" fill="none" stroke="{l}" stroke-width="{f(min(0.8, width * 0.35))}"/>'
    return s


def rings_small(m, l, core):
    return f'<circle cx="8" cy="8" r="4.6" fill="{l}"/><circle cx="8" cy="8" r="2.6" fill="{m}"/><circle cx="8" cy="8" r="1" fill="{core}"/>'


def leaf(m, v):
    return f'<path d="M1.5 10c3-7 10-8.5 13-6-2 7-9 9.5-13 6Z" fill="{m}"/><path d="M3.2 9.4 12.6 5" stroke="{v}" stroke-width="0.9" stroke-linecap="round"/>'


def torn_leaf(m, v):
    return f'<path d="M2 8c0-4 3-6 6-5.5 2-1.5 5 0 5.5 2.5 2 1.5 1.5 5-.5 6-1 2.5-4 3.5-6.5 2-3 .5-4.5-2-4.5-5Z" fill="{m}"/><path d="M4 11c2-2 5-4 8-6M8 8.5 7 5M10 7l2 2" stroke="{v}" stroke-width="0.8" fill="none" stroke-linecap="round"/>'


def fleck(m):
    return f'<path d="M3 10c1.5-5 6-7.5 10-5-1.5 5-6 7-10 5Z" fill="{m}"/>'


def needles(m):
    s = f'<path d="M3 13 13 3" stroke="{m}" stroke-width="0.9" stroke-linecap="round"/>'
    for t in (0.2, 0.35, 0.5, 0.65, 0.8):
        x, y = 3 + 10 * t, 13 - 10 * t
        s += f'<path d="M{f(x)} {f(y)}l-3-1M{f(x)} {f(y)}l1 3" stroke="{m}" stroke-width="0.9" stroke-linecap="round"/>'
    return s


def floret(m, l, stem=None):
    s = ""
    if stem:
        s += f'<rect x="7" y="9" width="2.4" height="6" rx="1.2" fill="{stem}"/>'
    for x, y, r in ((5.5, 6.5, 3.2), (10.5, 6.5, 3.2), (8, 4.2, 3), (6.5, 10, 3), (10, 10, 2.8)):
        s += f'<circle cx="{x}" cy="{y}" r="{r}" fill="{m}"/>'
    for x, y in ((5, 5.6), (9.5, 5.4), (7.6, 3.2)):
        s += f'<circle cx="{x}" cy="{y}" r="1" fill="{l}"/>'
    return s


def dot(m, r=2.2):
    return f'<circle cx="8" cy="8" r="{r}" fill="{m}"/>'


def seed(m):
    return f'<ellipse cx="8" cy="8" rx="3.4" ry="2" fill="{m}"/>'


def dust(m, l=None):
    s = "".join(f'<circle cx="{x}" cy="{y}" r="1.7" fill="{m}"/>' for x, y in ((4, 4.5), (10, 3.5), (12.5, 9), (6.5, 9.5), (9.5, 13), (3.5, 12.5)))
    if l:
        s += "".join(f'<circle cx="{x}" cy="{y}" r="1.3" fill="{l}"/>' for x, y in ((8, 6.5), (13, 4.5), (2.8, 8.4)))
    return s


def shred(m, width=2.4):
    return f'<path d="M3 10.6c3-1.8 6.6-3 10-3.2" stroke="{m}" stroke-width="{width}" fill="none" stroke-linecap="round"/>'


def shreds(m, l=None):
    s = f'<path d="M2 5.5c4-2 8-2 12 0M3 10c3-1.5 7-1.5 11 1" stroke="{m}" stroke-width="2.4" fill="none" stroke-linecap="round"/>'
    if l:
        s += f'<path d="M4 13.5c3-1 6-1 8 0" stroke="{l}" stroke-width="2" fill="none" stroke-linecap="round"/>'
    return s


def flake(m, l):
    """A thin shaving that curls as it comes off the block."""
    return f'<path d="M1.6 12.6C1.4 5.8 6.4 1.6 14.2 2.2c.4 2.8-1 4.8-3.8 5.2C8.4 7.8 7 9.6 6.8 12.8c-1.6 1-3.6 1-5.2-.2Z" fill="{m}"/><path d="M3.4 11.4c.2-4.4 3.4-7.2 8.6-7.6" stroke="{l}" stroke-width="1" fill="none" stroke-linecap="round"/>'


def bacon(m, fat):
    return f'<path d="M1 6c2.5-2 4.5 2 7 0s4.5-2 7 0v4c-2.5-2-4.5 2-7 0s-4.5-2-7 0Z" fill="{m}"/><path d="M1 7.6c2.5-2 4.5 2 7 0s4.5-2 7 0" stroke="{fat}" stroke-width="1.2" fill="none"/>'


def mince(m, l):
    s = ""
    for x, y, r in ((5, 6, 2.6), (10, 5.5, 2.4), (7.5, 10, 2.8), (12, 10, 2), (3.8, 10.8, 1.8)):
        s += f'<circle cx="{x}" cy="{y}" r="{r}" fill="{m}"/>'
    return s + f'<circle cx="5" cy="5.4" r="0.9" fill="{l}"/><circle cx="7.6" cy="9.2" r="0.9" fill="{l}"/>'


def crumble(m, l):
    return f'<path d="M3 7 6 3.5l4 1 3 3-1 4.5-4.5 2-4-1.5Z" fill="{m}"/><path d="M5 7.5l2.5-2" stroke="{l}" stroke-width="1.2" stroke-linecap="round"/>'


def berry(m, l, crown=None):
    s = f'<circle cx="8" cy="8.5" r="5.6" fill="{m}"/><circle cx="6.2" cy="6.6" r="1.6" fill="{l}"/>'
    if crown:
        s += f'<path d="M8 3.5l1.5-2M8 3.5l-1.5-2M8 3.5V1.5" stroke="{crown}" stroke-width="1.1" stroke-linecap="round"/>'
    return s


def small_round(m, l):
    return f'<circle cx="8" cy="8" r="4.2" fill="{m}"/><circle cx="6.8" cy="6.8" r="1.3" fill="{l}"/>'


def cluster(m, l, r=2.1, n=7):
    pts = [(8, 8), (8, 3.8), (11.7, 6), (11.7, 10), (8, 12.2), (4.3, 10), (4.3, 6)][:n]
    return "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{m}"/><circle cx="{f(x - 0.6)}" cy="{f(y - 0.6)}" r="{f(r * 0.35)}" fill="{l}"/>' for x, y in pts)


def bean(m, l):
    return f'<path d="M3 9c-1-4 2-6.5 5-5.5 1 .3 2 .3 3 0 3-1 4.5 3 2.5 6-2 3-8 4-10.5-.5Z" fill="{m}"/><path d="M5 7c1-1 2-1.5 3.5-1" stroke="{l}" stroke-width="1.1" stroke-linecap="round" fill="none"/>'


def pod(m, l):
    return f'<path d="M1.5 10c2-6 9-8 13-6-1 6-8 9-13 6Z" fill="{m}"/>' + "".join(f'<circle cx="{x}" cy="{y}" r="1.5" fill="{l}"/>' for x, y in ((5, 9), (8, 7.5), (11, 6)))


def spear(m, tip, l=None):
    s = f'<path d="M2.5 13.5 12 4" stroke="{m}" stroke-width="2.8" stroke-linecap="round"/><path d="M11 2.5c2 0 3 1.5 3 3l-2.5 1-1.5-1.5Z" fill="{tip}"/>'
    if l:
        s += f'<path d="M5 11l1.5 .5M8 8l1.5 .5" stroke="{l}" stroke-width="0.9" stroke-linecap="round"/>'
    return s


def stick(m, l, end=None):
    s = f'<rect x="1" y="6" width="14" height="4" rx="2" fill="{m}"/><path d="M3 7.3h9" stroke="{l}" stroke-width="1" stroke-linecap="round"/>'
    if end:
        s += f'<circle cx="2.5" cy="8" r="1.4" fill="{end}"/>'
    return s


def drizzle(m, width=2.2):
    return f'<path d="M1 8c2.5-4 4.5 4 7 0s4.5-4 7 0" stroke="{m}" stroke-width="{width}" fill="none" stroke-linecap="round"/>'


def zigzag(m):
    """Sauce piped back and forth across the dish, thin enough not to read as a letter."""
    s = ""
    for i, y in enumerate((3, 6, 9, 12)):
        x0, x1 = (1.5, 14.5) if i % 2 == 0 else (14.5, 1.5)
        s += f'<path d="M{x0} {y}C{f((x0 + x1) / 2)} {y - 1.2} {f((x0 + x1) / 2)} {y + 1.2} {x1} {y + 0.4}" stroke="{m}" stroke-width="1.1" fill="none" stroke-linecap="round"/>'
    return s


def dollop(m, l):
    return f'<path d="M2.5 9c0-4 3-6.5 5.5-6.5S13.5 5 13.5 9 11 13.5 8 13.5 2.5 12.5 2.5 9Z" fill="{m}"/><path d="M5 8.5c1-2 4-2.5 5.5-.5" stroke="{l}" stroke-width="1.3" fill="none" stroke-linecap="round"/>'


def puddle(m, l):
    return f'<path d="M2 9c0-3.5 3-5.5 6-5 2-1 5 0 5.5 2.5 1.5 2 0 5-2 5.5-2 1.5-5 1.5-7 .5-2-.5-2.5-2-2.5-3.5Z" fill="{m}"/><ellipse cx="6.5" cy="7" rx="1.8" ry="1" fill="{l}"/>'


def shrimp(m, l):
    return f'<path d="M12 4a6 6 0 1 0 1 7l-3-1a3 3 0 1 1-1-4Z" fill="{m}"/><path d="M7 3.5l1 3M4 6l2.6 1.6M3.4 9.6l3-.4" stroke="{l}" stroke-width="1.1" stroke-linecap="round"/><path d="M12 4l2.5-1.5L13.5 5.5Z" fill="{m}"/>'


def clam(shell, meat, ridge):
    return f'<path d="M1.5 9a6.5 6 0 0 1 13 0c0 3-3 5-6.5 5S1.5 12 1.5 9Z" fill="{shell}"/><path d="M4 9.5a4 3.5 0 0 1 8 0c0 1.8-1.8 3-4 3s-4-1.2-4-3Z" fill="{meat}"/><path d="M3 6.5l1.5 1M13 6.5l-1.5 1M8 3v1.6" stroke="{ridge}" stroke-width="0.9" stroke-linecap="round"/>'


def mussel(shell, meat):
    return f'<path d="M3 13C1 9 4 2 9 1.5c4.5 0 5 5 3 8.5-2 3.5-6 5.5-9 3Z" fill="{shell}"/><path d="M5 11.5c-1-3 1.5-7 4.5-7.5 2.5 0 2.5 3 1 5.5-1.5 2.2-3.8 3-5.5 2Z" fill="{meat}"/>'


def scallop(m, sear):
    return f'<circle cx="8" cy="8" r="6" fill="{m}"/><circle cx="8" cy="8" r="4.2" fill="{sear}"/><circle cx="7" cy="7" r="1.4" fill="{m}" opacity="0.6"/>'


def octopus(m, l, sucker):
    return f'<path d="M2 8a6 5.5 0 0 1 12 0c0 3.3-2.7 5.5-6 5.5S2 11.3 2 8Z" fill="{m}"/><ellipse cx="8" cy="8.5" rx="4" ry="3.4" fill="{l}"/>' + "".join(f'<circle cx="{x}" cy="{y}" r="0.9" fill="{sucker}"/>' for x, y in ((4, 11.5), (6.5, 13), (9.5, 13), (12, 11.5)))


def crab_stick(red, white):
    return f'<rect x="1" y="5" width="14" height="6" rx="2" fill="{white}"/><path d="M1.5 6.5h13" stroke="{red}" stroke-width="2.6" stroke-linecap="round"/>'


def squiggles(m, l):
    return f'<path d="M2 5c1.5-1 3 1 4.5 0M8 4c1.5-1 3 1 4.5 0M3 10c1.5-1 3 1 4.5 0M9 9.5c1.5-1 3 1 4.5 0M5 13.5c1.5-1 3 1 4.5 0" stroke="{m}" stroke-width="1.3" fill="none" stroke-linecap="round"/><circle cx="2" cy="5" r="0.6" fill="{l}"/><circle cx="8" cy="4" r="0.6" fill="{l}"/><circle cx="9" cy="9.5" r="0.6" fill="{l}"/>'


def fillet(m, l, skin):
    return f'<path d="M1 9c1-4 5-6.5 9-6.5s5 2.5 5 5.5-2 6-7 6-7.5-2-7-5Z" fill="{skin}"/><path d="M1.4 9.6c1-3 4.6-4.8 8.6-4.8s5 2.2 5 4.6-2 4.6-7 4.6-7-1.8-6.6-4.4Z" fill="{m}"/><path d="M5 6.5c1 2 1 4 0 5.5M8 5.2c1 2.5 1 5 0 7M11 5.2c.8 2 .8 4.5 0 6.5" stroke="{l}" stroke-width="0.9" fill="none" stroke-linecap="round"/>'


def sliced_fan(m, l, crust):
    s = ""
    for i, dx in enumerate((-4, 0, 4)):
        s += f'<rect x="{f(5.5 + dx)}" y="2" width="4.6" height="12" rx="1.4" fill="{crust}" transform="rotate({(i - 1) * 9} 8 8)"/>'
        s += f'<rect x="{f(6.3 + dx)}" y="3" width="3" height="10" rx="1" fill="{m}" transform="rotate({(i - 1) * 9} 8 8)"/>'
    return s + f'<path d="M4 6h1.2M8 5h1.2M12 6h1.2" stroke="{l}" stroke-width="0.8" stroke-linecap="round"/>'


def steak_slices(m, inner, crust):
    """A seared steak cut across one end, so the pink inside shows beside the crust."""
    return (
        f'<path d="M2 6c1-3 5-4.5 8-4 3 .5 5 2.5 4.5 5.5-.4 2-.2 3.5.5 4.5-1 2-4 2.5-7 2.5S1 13 1.5 10c.3-1.5 0-2.5.5-4Z" fill="{crust}"/>'
        f'<path d="M4 6.5l6-3M4.5 9.5l7-3.5M6 12l6-3" stroke="{m}" stroke-width="1" stroke-linecap="round"/>'
        f'<path d="M10.5 9.5c1.5-.3 3-.2 4 .5-.8 1.6-2.5 2.4-4.3 2.6Z" fill="{inner}"/>'
        f'<path d="M8.6 10.6c.8-.5 1.4-.8 2-1-.2 1.2-.2 2.2 0 3-.8.2-1.6.2-2.3.1Z" fill="{inner}"/>'
    )


def link(m, l):
    return f'<rect x="1" y="5" width="14" height="6" rx="3" fill="{m}"/><path d="M3.5 6.8h7" stroke="{l}" stroke-width="1.2" stroke-linecap="round"/><path d="M5 11l1-1M9 11l1-1" stroke="{l}" stroke-width="0.8" stroke-linecap="round"/>'


def coin(m, l, spots=None):
    s = f'<circle cx="8" cy="8" r="6.4" fill="{m}"/><circle cx="8" cy="8" r="5" fill="{l}"/>'
    if spots:
        s += "".join(f'<circle cx="{x}" cy="{y}" r="0.9" fill="{spots}"/>' for x, y in ((6, 6.5), (10, 7), (7.5, 10.5), (10.5, 10)))
    return s


def egg_fried():
    return '<path d="M2 8c0-5 4-7 7-6s6 3 5 7-3 6-7 6-5-3-5-7Z" fill="#fbf9f4"/><circle cx="8" cy="8" r="3.4" fill="#f1c21b"/><circle cx="7" cy="7" r="1.2" fill="#ffe97a"/>'


def egg_half(white, yolk, l):
    return f'<ellipse cx="8" cy="8" rx="5.6" ry="7" fill="{white}"/><circle cx="8" cy="8.6" r="3.4" fill="{yolk}"/><circle cx="7.2" cy="7.8" r="1" fill="{l}"/>'


def yolk(m, l):
    return f'<circle cx="8" cy="8" r="5" fill="{m}"/><circle cx="6.6" cy="6.6" r="1.6" fill="{l}"/>'


def mushroom_slice(cap, flesh):
    return f'<path d="M2 8a6 5 0 0 1 12 0c0 1-1 1.5-2.5 1.5H10.5v4.5h-5V9.5H4C3 9.5 2 9 2 8Z" fill="{cap}"/><path d="M3.4 8a4.6 3.6 0 0 1 9.2 0H9.6v4.6H6.4V8Z" fill="{flesh}"/>'


def mushroom_cap(cap, mark, l=None):
    s = f'<circle cx="8" cy="8" r="6.4" fill="{cap}"/><path d="M5 5l6 6M11 5l-6 6" stroke="{mark}" stroke-width="1.4" stroke-linecap="round"/>'
    if l:
        s += f'<circle cx="8" cy="8" r="6.4" fill="none" stroke="{l}" stroke-width="0.8"/>'
    return s


def enoki(m, cap):
    s = ""
    for i, x in enumerate((3, 5.5, 8, 10.5, 13)):
        s += f'<path d="M8 15 {x} 3" stroke="{m}" stroke-width="1" stroke-linecap="round"/><circle cx="{x}" cy="3" r="1.3" fill="{cap}"/>'
    return s


def small_caps(cap, l):
    return "".join(f'<circle cx="{x}" cy="{y}" r="2.6" fill="{cap}"/><circle cx="{f(x - 0.7)}" cy="{f(y - 0.7)}" r="0.8" fill="{l}"/>' for x, y in ((5, 5.5), (10.5, 5), (7.8, 10), (12.5, 10.5), (3.5, 11)))


def kernels(m, l):
    return "".join(f'<rect x="{x}" y="{y}" width="3.4" height="3" rx="1" fill="{m}"/>' for x, y in ((2.5, 4), (6.3, 3.5), (10.1, 4), (4.4, 8), (8.2, 7.8), (6.3, 11.6))) + f'<rect x="3" y="4.5" width="1.4" height="1" rx="0.5" fill="{l}"/>'


def teardrop(m, l):
    return f'<path d="M8 1.5c3 3 5 6 5 8.5a5 5 0 0 1-10 0c0-2.5 2-5.5 5-8.5Z" fill="{m}"/><path d="M8 4v8" stroke="{l}" stroke-width="0.9" stroke-linecap="round"/>'


def walnut(m, l):
    return f'<path d="M3 5c1-2.5 4-3 5-1.5 1-1.5 4-1 5 1.5 1.5 3 0 7-2 8-1 .5-2 0-3-1-1 1-2 1.5-3 1-2-1-3.5-5-2-8Z" fill="{m}"/><path d="M8 3.5v9M5 7c1 .5 1.5 1.5 1.5 2.5M11 7c-1 .5-1.5 1.5-1.5 2.5" stroke="{l}" stroke-width="0.9" fill="none" stroke-linecap="round"/>'


def pillow(m, ridge):
    return f'<rect x="2" y="4" width="12" height="8" rx="3.5" fill="{m}"/><path d="M5 5v6M8 5v6M11 5v6" stroke="{ridge}" stroke-width="0.8" stroke-linecap="round"/>'


def ravioli(m, l, edge):
    return f'<rect x="2" y="2" width="12" height="12" rx="1.5" fill="{edge}"/><rect x="4" y="4" width="8" height="8" rx="3" fill="{m}"/><circle cx="7" cy="7" r="1.3" fill="{l}"/>'


def dumpling(m, pleat, sear=None):
    s = f'<path d="M1.5 10c0-4.5 3-7 6.5-7s6.5 2.5 6.5 7c0 1.5-1 2.5-2.5 2.5H4c-1.5 0-2.5-1-2.5-2.5Z" fill="{m}"/>'
    if sear:
        s += f'<path d="M3 11.5h10" stroke="{sear}" stroke-width="1.6" stroke-linecap="round"/>'
    return s + f'<path d="M4 5.5l1 1.6M6.5 4l.7 1.8M9.5 4l-.7 1.8M12 5.5l-1 1.6" stroke="{pleat}" stroke-width="0.9" stroke-linecap="round"/>'


def mochi(m, l):
    return f'<rect x="2.5" y="3" width="11" height="10" rx="4.5" fill="{m}"/><ellipse cx="6.5" cy="6" rx="2" ry="1.2" fill="{l}"/>'


def avocado_half(skin, flesh, pit):
    return f'<path d="M8 1c3 0 5.5 4 5.5 8.5S11 15 8 15s-5.5-1.5-5.5-5.5S5 1 8 1Z" fill="{skin}"/><path d="M8 2.4c2.3 0 4.2 3.4 4.2 7S10.3 13.8 8 13.8s-4.2-1-4.2-4.4S5.7 2.4 8 2.4Z" fill="{flesh}"/><circle cx="8" cy="9.6" r="2.6" fill="{pit}"/>'


def crescent(skin, flesh):
    """A slice of fruit cut from the core out: a plump curve with the skin along its outer edge."""
    return f'<path d="M2 13C1.6 6.6 6.6 2 14 2.4 14.2 9.6 9.2 13.6 2 13Z" fill="{flesh}"/><path d="M14 2.4C14.2 9.6 9.2 13.6 2 13" stroke="{skin}" stroke-width="1.8" fill="none" stroke-linecap="round"/>'


def heart_half(m, l, s):
    return f'<path d="M8 14C4 11 1.5 8 2 5c.5-3 3.5-3.5 6-1.5 2.5-2 5.5-1.5 6 1.5.5 3-2 6-6 9Z" fill="{m}"/><path d="M8 12c-2-1.8-3.4-3.6-3.2-5.4" stroke="{l}" stroke-width="1.6" fill="none" stroke-linecap="round"/>' + "".join(f'<circle cx="{x}" cy="{y}" r="0.5" fill="{s}"/>' for x, y in ((5, 6), (11, 6), (8, 9), (10, 9.5), (6, 9.5)))


def cherry(m, l, stem):
    return f'<path d="M8 6c1-3 3-4.5 5-5" stroke="{stem}" stroke-width="1" fill="none" stroke-linecap="round"/><circle cx="7.5" cy="10" r="4.6" fill="{m}"/><circle cx="6" cy="8.6" r="1.2" fill="{l}"/>'


def sheet_square(m, l):
    return f'<rect x="2" y="2" width="12" height="12" rx="1" fill="{m}"/><path d="M4 5h8M4 8h8M4 11h8" stroke="{l}" stroke-width="0.6"/>'


def triangle(m, l):
    return f'<path d="M2 13 8 2.5 14 13Z" fill="{m}"/><path d="M5 11.5 8 6" stroke="{l}" stroke-width="1.2" stroke-linecap="round"/>'


def short_strokes(m):
    return f'<path d="M2 5l3 1M7 3l1 3M11 4l3-1M3 10l2 2M7 9l3 1M12 9l1 3M6 13l3 0" stroke="{m}" stroke-width="1.2" stroke-linecap="round"/>'


def pastry_square(m, l, top):
    return f'<rect x="2" y="2" width="12" height="12" rx="2" fill="{m}"/><rect x="3.5" y="3.5" width="9" height="9" rx="1.5" fill="{top}"/><path d="M5 6h6M5 9h6" stroke="{l}" stroke-width="0.9" stroke-linecap="round"/>'


def tube(m, l, ridges=False):
    s = f'<rect x="1.5" y="5" width="13" height="6" rx="1" fill="{m}" transform="rotate(-20 8 8)"/><ellipse cx="13.6" cy="5.6" rx="1.4" ry="3" fill="{l}" transform="rotate(-20 13.6 5.6)"/>'
    if ridges:
        s += f'<path d="M3 10.5l9-3.4M3.4 8.4l8.4-3.2" stroke="{l}" stroke-width="0.6" transform="rotate(0)"/>'
    return s


def spiral(m, l):
    return f'<path d="M3 3c3 1 3 3 0 4s0 3 3 4 3 3 0 4" stroke="{m}" stroke-width="3" fill="none" stroke-linecap="round" transform="translate(4 -1) rotate(15 8 8)"/><path d="M4 4c2 .8 2 2 0 2.8" stroke="{l}" stroke-width="0.9" fill="none" stroke-linecap="round" transform="translate(4 -1) rotate(15 8 8)"/>'


def elbow(m, l):
    return f'<path d="M3 11a6 6 0 0 1 9-7" stroke="{m}" stroke-width="3.6" fill="none" stroke-linecap="round"/><path d="M4.4 10a4.6 4.6 0 0 1 6.6-5" stroke="{l}" stroke-width="0.9" fill="none" stroke-linecap="round"/>'


def artichoke_quarter(leaf, heart, line):
    """A quartered heart: the pale base at the stem end, its inner leaves fanning to the tip."""
    return f'<path d="M8 15c-3 0-5-2-5.5-5C2 7 4 3.5 8 1.5c4 2 6 5.5 5.5 8.5-.5 3-2.5 5-5.5 5Z" fill="{leaf}"/><path d="M8 14c-2.2 0-3.7-1.5-3.9-3.5C3.9 8.4 5.5 6 8 4.6c2.5 1.4 4.1 3.8 3.9 5.9-.2 2-1.7 3.5-3.9 3.5Z" fill="{heart}"/><path d="M8 13 5.6 7.4M8 13l2.4-5.6M8 13V5.6" stroke="{line}" stroke-width="0.7" stroke-linecap="round"/>'


def rocket_leaf(m, v):
    """A rocket leaf: a round end lobe and smaller lobes in pairs down the rib."""
    s = f'<path d="M2.5 13.5 11 5" stroke="{m}" stroke-width="1.3" stroke-linecap="round"/><ellipse cx="11.4" cy="4.6" rx="3.4" ry="2.7" fill="{m}" transform="rotate(-45 11.4 4.6)"/>'
    for x, y, r in ((8.2, 7.8, 2.1), (5.8, 10.2, 1.7), (4, 12, 1.3)):
        for dx in (-1, 1):
            cx, cy = x + dx * r * 0.75, y + dx * r * 0.75
            s += f'<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="{f(r)}" ry="{f(r * 0.62)}" fill="{m}" transform="rotate(45 {f(cx)} {f(cy)})"/>'
    return s + f'<path d="M3.5 12.5 12.4 3.6" stroke="{v}" stroke-width="0.7" stroke-linecap="round"/>'


def asparagus_piece(m, tip, l):
    """A short length of spear, cut on the bias, with the tip on it."""
    return f'<rect x="5.6" y="4" width="4.8" height="10.5" rx="2.2" fill="{m}"/><path d="M5.6 7.2c0-2.8 1-5.7 2.4-5.7s2.4 2.9 2.4 5.7c-.8-.7-1.6-1-2.4-1s-1.6.3-2.4 1Z" fill="{tip}"/><path d="M6.6 5.2 8 6.2l1.4-1" stroke="{m}" stroke-width="0.7" fill="none" stroke-linecap="round"/><path d="M6.2 9.2l1.4.6M8.4 11.8l1.4.6" stroke="{l}" stroke-width="0.9" stroke-linecap="round"/>'


def goya_slice(rind, flesh):
    """A slice of a halved, seeded bitter melon: a bumpy green arch around a pale lining."""
    s = f'<path d="M1.5 11.5a6.5 6.5 0 0 1 13 0h-3.6a2.9 2.9 0 0 0-5.8 0Z" fill="{rind}"/><path d="M3 11.5a5 5 0 0 1 10 0h-2.2a2.8 2.8 0 0 0-5.6 0Z" fill="{flesh}"/>'
    for i in range(7):
        a = math.pi + math.pi * (i + 0.5) / 7
        s += f'<circle cx="{f(8 + 6.4 * math.cos(a))}" cy="{f(11.5 + 6.4 * math.sin(a))}" r="1" fill="{rind}"/>'
    return s


def whole_fish(back, belly, spot=None):
    """A small whole fish on its side, head to the left, salt grilled."""
    s = f'<path d="M1.2 8c1.8-2.8 4.8-3.6 7.8-3.4 1.6.1 2.8.8 3.6 1.8L15 4.4v7.2l-2.4-2c-.8 1-2 1.7-3.6 1.8-3 .2-6-.6-7.8-3.4Z" fill="{back}"/>'
    s += f'<path d="M2.4 8.8c1.8 1.6 4.2 2.2 6.6 2.1 1.4-.1 2.6-.6 3.4-1.4-2-.6-6.2-1-10-.7Z" fill="{belly}"/>'
    if spot:
        s += f'<ellipse cx="5.8" cy="7.2" rx="1" ry="0.6" fill="{spot}"/>'
    return s + '<circle cx="3.2" cy="7.4" r="0.6" fill="#1f1f1f"/><path d="M6.6 5.4l-.8 4.8M9.4 5l-.8 5.6" stroke="#3a3020" stroke-width="0.8" stroke-linecap="round" opacity="0.45"/>'


def basil_leaf(m, v):
    """A broad, cupped basil leaf with its side veins."""
    return f'<path d="M8 1.5c3.6 2 5.2 5.4 4.6 8.6-.5 3-2.8 4.9-4.6 4.9s-4.1-1.9-4.6-4.9C2.8 6.9 4.4 3.5 8 1.5Z" fill="{m}"/><path d="M8 3.4v10.4M8 6.4 5.8 7.8M8 6.4l2.2 1.4M8 9.4l-2.6 1.4M8 9.4l2.6 1.4" stroke="{v}" stroke-width="0.7" fill="none" stroke-linecap="round"/>'


def celery_slice(skin, flesh):
    return f'<path d="M3 5.5a5 5 0 0 0 10 0" stroke="{skin}" stroke-width="3.6" fill="none" stroke-linecap="round"/><path d="M3.6 5.6a4.4 4.4 0 0 0 8.8 0" stroke="{flesh}" stroke-width="1.3" fill="none" stroke-linecap="round"/>'


def capsule(x0, y0, x1, y1, w, m):
    cx, cy, length = (x0 + x1) / 2, (y0 + y1) / 2, math.hypot(x1 - x0, y1 - y0) + w
    return f'<rect x="{f(cx - length / 2)}" y="{f(cy - w / 2)}" width="{f(length)}" height="{w}" rx="{w / 2}" fill="{m}" transform="rotate({f(math.degrees(math.atan2(y1 - y0, x1 - x0)))} {f(cx)} {f(cy)})"/>'


def wing(m, l):
    return capsule(3.6, 4.6, 7, 10.2, 4.2, m) + '<circle cx="3.2" cy="3.8" r="2.6" fill="' + m + '"/>' + capsule(7.2, 10.4, 12.4, 5.4, 5, m) + capsule(12.6, 5, 14.2, 2.4, 2, m) + f'<path d="M4.4 6.6l2.2 3.4M8.6 9.6l3-2.8" stroke="{l}" stroke-width="1.1" stroke-linecap="round"/>'


def brie_slice(rind, paste):
    return f'<path d="M1.5 12.5 12 2c1.8.8 3 2.8 3 5.4Z" fill="{rind}"/><path d="M4.6 11.3 12.2 3.9c.9.6 1.5 1.7 1.6 3Z" fill="{paste}"/>'


def grated_mound(m, l):
    """A small mound of grated root, its shreds showing as short strokes."""
    return f'<path d="M2.5 9c0-4 3-6.5 5.5-6.5S13.5 5 13.5 9 11 13.5 8 13.5 2.5 12.5 2.5 9Z" fill="{m}"/><path d="M5 6.5l1.2 1M8.5 5l.6 1.4M11 7.5l-1 1M4.6 10l1.4.4M8 9.2l.8 1.2M10.6 11l1.2-.6M7 12l1.2.2" stroke="{l}" stroke-width="0.8" stroke-linecap="round"/>'


def fig_quarter(skin, pith, flesh, seed_color):
    """A fig cut into quarters, cut face up: purple skin, a pale band, a red middle full of seeds."""
    s = f'<path d="M8 1.5C10 4 14 8 13.5 11.5 13 14 10.5 14.8 8 14.8S3 14 2.5 11.5C2 8 6 4 8 1.5Z" fill="{skin}"/>'
    s += f'<path d="M8 3.2C9.6 5.4 12.6 8.6 12.2 11.4 11.8 13.2 10 13.6 8 13.6S4.2 13.2 3.8 11.4C3.4 8.6 6.4 5.4 8 3.2Z" fill="{pith}"/>'
    s += f'<path d="M8 5.6C9 7.2 10.8 9.4 10.6 11.2 10.4 12.3 9.2 12.5 8 12.5S5.6 12.3 5.4 11.2C5.2 9.4 7 7.2 8 5.6Z" fill="{flesh}"/>'
    return s + "".join(f'<circle cx="{x}" cy="{y}" r="0.5" fill="{seed_color}"/>' for x, y in ((7.2, 9.6), (8.8, 9.4), (8, 8), (7, 11.2), (9, 11.2), (8, 10.6)))


def crab_meat(m, red, fibre):
    """A lump of white crab meat with the red-orange tinge of the shell on one side."""
    return f'<path d="M1.5 8.5c.5-2.5 3-4 6-4.2 1.5-.1 2.5.6 3.6.2 1.5-.4 3 .6 3.4 2.5.6 1.6-.4 3.6-2.6 4.4-2.4 1-6 1.2-8.4.4C1.8 11.2 1.2 10 1.5 8.5Z" fill="{m}"/><path d="M3.4 6.4c1.6-1 3.4-1.4 5.4-1.3" stroke="{red}" stroke-width="1.7" stroke-linecap="round"/><path d="M3.6 9.2c2.6-.6 5.6-.8 8.6-.4M4.6 11c2-.3 4.2-.4 6-.2" stroke="{fibre}" stroke-width="0.8" fill="none" stroke-linecap="round"/>'


def bonito_flake(m, l):
    """A paper thin shaving of dried bonito, wide and ruffled at the edge."""
    return f'<path d="M2 5.6c2-1.8 3.8.2 5.8-1.6s4 .2 6.2-.8c.8 2.8-1.2 3.8 0 6s-1.2 4-3.2 4.2-3.2 1.6-5.2.8-3.8-1.2-4.2-3.2.2-2.4.6-5.4Z" fill="{m}"/><path d="M4.4 9.4c2-1.4 4.4-2 7.2-1.6M5 6.8c1.4-.6 2.8-.8 4.2-.6" stroke="{l}" stroke-width="0.7" fill="none" stroke-linecap="round"/>'


def bean_heap(m, l, strings=None):
    """A small heap of whole beans, each with its own glint, with sticky strings for natto."""
    beans = ((5, 5.6, -20), (10.4, 5, 25), (12, 10, -40), (7.6, 9, 10), (3.8, 10.8, 40), (8.6, 13, -10))
    s = "".join(f'<ellipse cx="{x}" cy="{y}" rx="2.6" ry="1.9" fill="{m}" transform="rotate({r} {x} {y})"/><circle cx="{f(x - 0.8)}" cy="{f(y - 0.6)}" r="0.6" fill="{l}"/>' for x, y, r in beans)
    if strings:
        s += f'<path d="M3 6c3 2 7 1 10 5M5 13c2-3 5-5 8-6" stroke="{strings}" stroke-width="0.5" fill="none" stroke-linecap="round"/>'
    return s


def cream_swirl(m):
    """Cream spooned on and drawn round into a spiral, as on a soup."""
    return f'<path d="M8 8a1 1 0 0 1 2 0 2 2 0 0 1-4 0 3 3 0 0 1 6 0 4 4 0 0 1-8 0 5 5 0 0 1 10 0" stroke="{m}" stroke-width="1.5" fill="none" stroke-linecap="round"/>'


def scrambled_curd(m, l, fold):
    """A soft, folded curd of scrambled egg, uneven at the edge."""
    return f'<path d="M2.5 8.5c-.5-3 2-5.5 4.5-5 1.5-1.5 4.5-1 5.5 1 2 .5 2.5 3 1.5 4.5.5 2-1 4-3.5 4-1.5 1.5-4 1-5-.5-2 0-3.5-1.5-3-4Z" fill="{m}"/><path d="M6.4 11.4c1.8-.2 3.4-1.4 3.8-3" stroke="{fold}" stroke-width="0.9" fill="none" stroke-linecap="round"/><ellipse cx="6.6" cy="5.8" rx="1.8" ry="1" fill="{l}"/>'


def curds(m, l, shade):
    """A spoonful of loose curds: a soft mound under small round lumps."""
    s = f'<path d="M2.5 9c0-4 3-6.5 5.5-6.5S13.5 5 13.5 9 11 13.5 8 13.5 2.5 12.5 2.5 9Z" fill="{shade}"/>'
    for x, y, r in ((5.4, 6.4, 2.2), (9, 5, 2.2), (11.4, 8.4, 2), (8, 8.6, 2.3), (4.8, 10.4, 2), (8.6, 11.6, 2), (11, 11.4, 1.6)):
        s += f'<circle cx="{x}" cy="{y}" r="{r}" fill="{m}"/><circle cx="{f(x - 0.6)}" cy="{f(y - 0.6)}" r="0.6" fill="{l}"/>'
    return s


def coriander_leaf(m, stem, v):
    """A flat leaf of three rounded lobes on a short stem, so it does not read as a pea."""
    return f'<path d="M8 14.5V8.5" stroke="{stem}" stroke-width="1" stroke-linecap="round"/><circle cx="4.8" cy="7.6" r="3" fill="{m}"/><circle cx="11.2" cy="7.6" r="3" fill="{m}"/><circle cx="8" cy="5" r="3.3" fill="{m}"/><path d="M8 9.4V3.6M8 9.4 5 7.6M8 9.4l3-1.8" stroke="{v}" stroke-width="0.7" fill="none" stroke-linecap="round"/>'


def filo_shard(edge, m, l):
    """A broken shard of baked filo, its thin layers showing along one edge."""
    return f'<path d="M1.5 7 5 3l5.5-.5 4 3-1 5-3 3.5-6 .5-2.5-3Z" fill="{edge}"/><path d="M3 6.4 5.8 3.4l4.8-.2 3.2 2.6-1.2 4.4-3 2.8-4.8.2-1.6-2.4Z" fill="{m}"/><path d="M4.4 6l2.4-2.4 3.8-.2M3.8 8.8l1.8-1.6" stroke="{l}" stroke-width="0.9" fill="none" stroke-linecap="round"/>'


# A stalk of gai-lan with the broad leaf still on it.
def stalk_with_leaf(stalk, leaf_m, vein):
    return f'<path d="M2 14 8.5 7.5" stroke="{stalk}" stroke-width="2.6" stroke-linecap="round"/><path d="M7 9c-1-4 1.5-7.5 6.5-7.5.5 5-2.5 8-6.5 7.5Z" fill="{leaf_m}"/><path d="M8 8.2 12.6 2.6" stroke="{vein}" stroke-width="0.9" stroke-linecap="round"/>'


# A thick wedge of squash, cut side up: a band of flesh with the skin along its outer arc.
def squash_wedge(skin, flesh):
    return f'<path d="M1.5 14A12.5 12.5 0 0 1 14 1.5V8.5A5.5 5.5 0 0 0 8.5 14Z" fill="{flesh}"/><path d="M1.5 14A12.5 12.5 0 0 1 14 1.5" stroke="{skin}" stroke-width="2" fill="none" stroke-linecap="round"/>'


# A grape cut lengthwise, cut side up.
def grape_half(skin, flesh, line):
    return f'<ellipse cx="8" cy="8" rx="6.6" ry="5.2" fill="{skin}"/><ellipse cx="8" cy="8" rx="5.4" ry="4.1" fill="{flesh}"/><path d="M5 8h6" stroke="{line}" stroke-width="0.9" stroke-linecap="round"/>'


# A small oily fish fillet, skin side up: a dark back, a silver belly and the line between.
def oily_fillet(back, belly, line):
    return f'<path d="M1 8.5C2 3.5 9 2.5 15 6.5c-3 5-10 7-14 2Z" fill="{belly}"/><path d="M1 8.5C2 3.5 9 2.5 15 6.5c-4 .6-9 1.4-14 2Z" fill="{back}"/><path d="M2.5 8.4C6 7.6 10 7.2 14 6.6" stroke="{line}" stroke-width="0.9" fill="none" stroke-linecap="round"/>'


def curly_leaf(m, rib):
    """A torn piece of curly kale, frilled all the way round, with its pale rib."""
    s = f'<circle cx="8" cy="8" r="5" fill="{m}"/>'
    for i in range(10):
        a = math.tau * i / 10
        s += f'<circle cx="{f(8 + 5.2 * math.cos(a))}" cy="{f(8 + 5.2 * math.sin(a))}" r="1.9" fill="{m}"/>'
    return s + f'<path d="M3.5 12.5C6 10 9 7 12.5 3.5M7 9 5.6 6.4M9.4 6.8l2.6 1.4" stroke="{rib}" stroke-width="0.9" fill="none" stroke-linecap="round"/>'


def king_oyster_slice(cap, flesh):
    """Cut lengthwise: a thick pale stem under a small brown cap."""
    return f'<rect x="4.6" y="4" width="6.8" height="11" rx="3" fill="{flesh}"/><path d="M3.4 5.2C3.4 3 5.4 1.6 8 1.6s4.6 1.4 4.6 3.6c0 1-.8 1.4-1.8 1.4H5.2c-1 0-1.8-.4-1.8-1.4Z" fill="{cap}"/><path d="M6.6 8v5" stroke="#e2d4b4" stroke-width="0.8" stroke-linecap="round"/>'


def sprout(stem, leaf):
    """A radish sprout: a thin white stem with two small round leaves at its tip."""
    return f'<path d="M4 15C5 11 6.5 8 8.6 5.6" stroke="{stem}" stroke-width="1.2" fill="none" stroke-linecap="round"/><ellipse cx="7.2" cy="3.6" rx="2.3" ry="1.5" fill="{leaf}" transform="rotate(-30 7.2 3.6)"/><ellipse cx="11" cy="5.2" rx="2.3" ry="1.5" fill="{leaf}" transform="rotate(20 11 5.2)"/>'


def pea_shoot(stem, leaf, tendril):
    """A cut length of pea shoot: a pale green stem with round leaves at the top and a curled tendril."""
    return f'<path d="M2.5 14 10 5" stroke="{stem}" stroke-width="1.4" stroke-linecap="round"/><path d="M10.4 4.6c.6-2 2.6-3 4-2 1 .8.2 2.2-.8 1.6" stroke="{tendril}" stroke-width="0.8" fill="none" stroke-linecap="round"/><ellipse cx="7.4" cy="5.2" rx="2.8" ry="2" fill="{leaf}" transform="rotate(-40 7.4 5.2)"/><ellipse cx="11.6" cy="8" rx="2.8" ry="2" fill="{leaf}" transform="rotate(20 11.6 8)"/><ellipse cx="4.6" cy="9.6" rx="2.2" ry="1.6" fill="{leaf}" transform="rotate(-20 4.6 9.6)"/>'


def maitake(cap, edge, stem):
    """A torn piece of hen of the woods: overlapping fronds on a pale branching base."""
    s = f'<path d="M8 15 5 9.5M8 15l3-5.2M8 15V6" stroke="{stem}" stroke-width="1.8" stroke-linecap="round"/>'
    for x, y in ((4.4, 8.4), (11.6, 8.6), (5.8, 4.6), (10.2, 4.4), (8, 7)):
        s += f'<ellipse cx="{x}" cy="{y}" rx="3" ry="2.2" fill="{cap}"/><path d="M{f(x - 2)} {f(y + 1)}c1.2.8 2.8.8 4 0" stroke="{edge}" stroke-width="0.8" fill="none" stroke-linecap="round"/>'
    return s


def segment(m, l):
    """A plump fruit segment seen from the side it lies on: round outside, hollow inside."""
    return f'<path d="M1.5 10.5a6.5 6 0 0 1 13 0c-2 1.4-4.2 2-6.5 2s-4.5-.6-6.5-2Z" fill="{m}"/><path d="M5 10.6 4.6 7M8 11V6M11 10.6 11.4 7" stroke="{l}" stroke-width="0.7" stroke-linecap="round"/>'


def roast_slice(crust, pink, fat):
    """A slice off a roast: a browned edge, a pink middle and a band of fat along one side."""
    return f'<path d="M1.5 8c0-3.5 3-5.5 6.5-5.5s6.5 2 6.5 5.5-3 5.5-6.5 5.5S1.5 11.5 1.5 8Z" fill="{crust}"/><path d="M3 8.3c0-2.6 2.3-4.2 5-4.2s5 1.6 5 4.2-2.3 4-5 4-5-1.4-5-4Z" fill="{pink}"/><path d="M3 5.4c2.6-2.6 7.4-2.6 10 0" stroke="{fat}" stroke-width="1.4" fill="none" stroke-linecap="round"/>'


def mackerel_skin():
    """A mackerel fillet grilled skin side up, the way saba is served: a blue back with dark
    wavy bars over a silver belly."""
    return (
        '<path d="M1 9c1-4 5-6.5 9-6.5s5 2.5 5 5.5-2 6-7 6-7.5-2-7-5Z" fill="#d2d9df"/>'
        '<path d="M1.1 8.6C2.4 4.8 6.2 2.5 10 2.5c3 0 4.7 2 5 4.6-3.6 1-9 1.6-13.9 1.5Z" fill="#4f6a84"/>'
        '<path d="M4 6.6c.6-.9 1.4.3 2-.6M6.6 4.6c.6-.9 1.4.3 2-.6M9.8 3.8c.6-.9 1.4.3 2-.6M8.4 6.6c.6-.9 1.4.3 2-.6M11.8 6.2c.6-.9 1.4.3 2-.6M3 8.4c.6-.9 1.4.3 2-.6M5.6 8.2c.6-.9 1.4.3 2-.6" stroke="#22303f" stroke-width="0.8" fill="none" stroke-linecap="round"/>'
    )


def lentils(m, l):
    """A few cooked lentils: small flat discs, not beads."""
    return "".join(f'<ellipse cx="{x}" cy="{y}" rx="2.4" ry="2" fill="{m}"/><path d="M{f(x - 1.4)} {f(y - .6)}a1.6 1.4 0 0 1 2.2-1" stroke="{l}" stroke-width="0.6" fill="none" stroke-linecap="round"/>' for x, y in ((5, 5.5), (10.5, 5), (8, 9.5), (4, 11), (12, 10.5)))


def mizuna_sprig(m, stem):
    """A cut length of mizuna: a thin pale stem with narrow, jagged leaflets off the top half."""
    s = f'<path d="M2.5 13.5 13.5 2.5" stroke="{stem}" stroke-width="1.3" stroke-linecap="round"/>'
    for t in (0.42, 0.62, 0.82):
        x, y = 2.5 + 11 * t, 13.5 - 11 * t
        for side in (-1, 1):
            s += f'<path d="M{f(x)} {f(y)}l{f(side * -1.2)} {f(side * -3.6)}l{f(side * 0.6)} {f(side * 0.5)}l{f(side * -0.8)} {f(side * -1.6)}l{f(side * 2.6)} {f(side * 2.2)}Z" fill="{m}" stroke="{m}" stroke-width="0.9"/>'
    return s


def mushroom_quarter(cap, flesh, stem):
    """A button mushroom cut in four through the stem, cut face up: half the cap's dome over half the stem."""
    return f'<path d="M3.5 2.5C9 2.5 13.5 5.5 13.5 10H3.5Z" fill="{cap}"/><path d="M3.5 4C8 4 11.8 6.4 12 9H3.5Z" fill="{flesh}"/><rect x="3.5" y="8.6" width="4.4" height="5.4" rx="1" fill="{stem}"/>'


def trefoil(m, v):
    """Three rounded leaflets on a short stem, the way a mitsuba leaf sits."""
    s = f'<path d="M8 9v6" stroke="{v}" stroke-width="1" stroke-linecap="round"/>'
    for a in (-90, 30, 150):
        x, y = 8 + 3.3 * math.cos(math.radians(a)), 7 + 3.3 * math.sin(math.radians(a))
        s += f'<ellipse cx="{f(x)}" cy="{f(y)}" rx="3.4" ry="2.7" fill="{m}" transform="rotate({a} {f(x)} {f(y)})"/>'
    return s + f'<path d="M8 7V2.6M8 7l3.4 2M8 7l-3.4 2" stroke="{v}" stroke-width="0.7" stroke-linecap="round"/>'


def thick_wedge(skin, flesh, l):
    """A wedge lying on its side: two cut faces meeting along a ridge, skin down one long edge."""
    return f'<path d="M1.5 12C2 7 6.5 3 13 2.5c1 0 1.6.6 1.5 1.5-.5 5.5-5 10-11 10-1.2 0-2.1-.8-2-2Z" fill="{skin}"/><path d="M1.5 12C2 7 6.5 3 13 2.5c1 0 1.6.6 1.5 1.5-1.4 3.8-5.2 7-10.4 8.2-1.4.3-2.4.6-2.6-.2Z" fill="{flesh}"/><path d="M4 9.6C6 7 8.8 5.2 11.8 4.6" stroke="{l}" stroke-width="1.2" fill="none" stroke-linecap="round"/>'


def serrated_leaf(m, v):
    """A broad ovate leaf with a toothed edge, widest below the middle, as perilla is."""
    n = 14
    right, left = [], []
    for i in range(n + 1):
        t = i / n
        w = 6.4 * math.sin(math.pi * t ** 0.75) + (0.5 if 0 < i < n and i % 2 else 0)
        y = 15 - 13.5 * t
        right.append((8 + w, y))
        left.append((8 - w, y))
    pts = right + left[::-1][1:-1]
    d = "M" + "L".join(f"{f(x)} {f(y)}" for x, y in pts) + "Z"
    veins = "".join(f'M8 {y}l{dx} -2.6' for y, dx in ((11.5, 3.6), (11.5, -3.6), (8, 3.2), (8, -3.2), (5, 2.2), (5, -2.2)))
    return f'<path d="{d}" fill="{m}"/><path d="M8 15V3{veins}" stroke="{v}" stroke-width="0.8" fill="none" stroke-linecap="round"/>'


def pulp(m, l, seed):
    """A spoonful of seeded fruit pulp: a glossy pool with dark seeds through it."""
    s = f'<path d="M2 9c0-3.5 3-5.5 6-5 2-1 5 0 5.5 2.5 1.5 2 0 5-2 5.5-2 1.5-5 1.5-7 .5-2-.5-2.5-2-2.5-3.5Z" fill="{m}"/><ellipse cx="6.4" cy="6.6" rx="1.8" ry="0.9" fill="{l}" opacity="0.7"/>'
    return s + "".join(f'<ellipse cx="{x}" cy="{y}" rx="1" ry="0.75" fill="{seed}"/>' for x, y in ((5, 9.6), (8.6, 7.6), (11, 9.2), (7.8, 11.2), (10.4, 6)))


def arils(m, l):
    """Three loose pomegranate seeds, each a rounded kernel with a glint."""
    s = ""
    for x, y, a in ((5.2, 5.6, 20), (10.8, 6.6, -30), (7.6, 11.2, 70)):
        s += f'<path d="M{x - 2.4} {y + 0.4}c0-1.8 1.2-2.8 2.4-2.8s2.4 1 2.4 2.6c0 1.6-1 2.6-2.4 2.6s-2.4-.8-2.4-2.4Z" fill="{m}" transform="rotate({a} {x} {y})"/><circle cx="{f(x - 0.7)}" cy="{f(y - 0.8)}" r="0.7" fill="{l}"/>'
    return s


def tidbit(m, l):
    """A pineapple chunk: a ring sector with fibres running from the core to the rind."""
    return f'<path d="M1.5 5C5.5 1.6 10.5 1.6 14.5 5L10.6 13.5H5.4Z" fill="{m}"/><path d="M5 5 6.8 12M8 3.8V12.4M11 5 9.2 12" stroke="{l}" stroke-width="0.8" stroke-linecap="round"/>'


def draped(m, fat, fold):
    """A thin slice of cured ham laid in loose folds, the fat along one edge."""
    return f'<path d="M2 9c-.5-3 1.5-5.5 4-5 1-1.5 3.5-2 5-.5 2-.2 3.5 1.8 3 4 1.5 1.5.5 4.5-1.5 4.5-1 1.6-3.6 2-5 .8-2 1-4.6 0-5.5-1.8Z" fill="{m}"/><path d="M2.6 9.6c1 1.6 3.2 2.4 5 1.5 1.6 1 3.8.6 4.8-.8" stroke="{fat}" stroke-width="1.5" fill="none" stroke-linecap="round"/><path d="M4.6 7c1.6-1.2 3.4-1.2 5 0M7.4 4.6c1.2 1 1.4 2.6.6 4" stroke="{fold}" stroke-width="0.8" fill="none" stroke-linecap="round"/>'


def shaving(m, l, edge):
    """A thin shard of hard cheese pulled off with a peeler, one edge curled up into the light."""
    return f'<path d="M2 7 9.5 2.6 14 5.4 12.2 11.6 5.4 13.6 2.4 11Z" fill="{m}"/><path d="M2.8 7.2 9.4 3.4" stroke="{l}" stroke-width="1.5" stroke-linecap="round"/><path d="M5.6 12.8 11.8 11" stroke="{edge}" stroke-width="0.8" stroke-linecap="round"/>'


def quill(m, l):
    """A penne quill: a ridged tube cut on the slant at both ends."""
    return f'<g transform="rotate(-20 8 8)"><path d="M1.5 10.5 4.5 5.5H14.5L11.5 10.5Z" fill="{m}"/><ellipse cx="13" cy="8" rx="1.1" ry="2.8" fill="{l}" transform="rotate(31 13 8)"/><path d="M4.4 7h8.4M3.4 9h8.4" stroke="{l}" stroke-width="0.6"/></g>'


def parsley_sprig(m, stem):
    s = f'<path d="M4 14.5 8 9M8 9 5 5.5M8 9l1.5-5M8 9l4 .5" stroke="{stem}" stroke-width="0.9" fill="none" stroke-linecap="round"/>'
    for cx, cy in ((4.6, 4.8), (9.8, 3.4), (12.4, 9)):
        for dx, dy in ((-1.3, 0.6), (1.3, 0.6), (0, -1.1)):
            s += f'<circle cx="{f(cx + dx)}" cy="{f(cy + dy)}" r="1.6" fill="{m}"/>'
    return s


def ribbed_leaf(m, rib):
    """A torn leaf with a thick pale midrib, as radicchio shows."""
    return f'<path d="M2 8c0-4 3-6 6-5.5 2-1.5 5 0 5.5 2.5 2 1.5 1.5 5-.5 6-1 2.5-4 3.5-6.5 2-3 .5-4.5-2-4.5-5Z" fill="{m}"/><path d="M3.5 12.5C6 10 9 7 12.5 4" stroke="{rib}" stroke-width="1.6" fill="none" stroke-linecap="round"/><path d="M6 10 4.2 6.4M8.4 7.6 7.4 3.8M8 9.6l3.6 1M10.2 6.8l3 .8" stroke="{rib}" stroke-width="0.7" fill="none" stroke-linecap="round"/>'


def rhubarb_piece(m, l, cut):
    return f'<rect x="1.5" y="4.5" width="13" height="7" rx="1.6" fill="{m}"/><path d="M3.5 6.5h8M4 9.4h7.5" stroke="{l}" stroke-width="0.9" stroke-linecap="round"/><ellipse cx="13.2" cy="8" rx="1.2" ry="3.1" fill="{cut}"/>'


def sashimi(m, l, skin=None):
    """A slice cut across the grain: a flat block with the fat lines running across it."""
    s = f'<rect x="1.5" y="4" width="13" height="8" rx="1.4" fill="{m}"/><path d="M4.6 4.6c-.8 2-1 4.6-.4 6.8M8.2 4.6c-.8 2-1 4.6-.4 6.8M11.8 4.6c-.8 2-1 4.6-.4 6.8" stroke="{l}" stroke-width="0.9" fill="none" stroke-linecap="round"/>'
    if skin:
        s += f'<path d="M2.4 4.7h11.2" stroke="{skin}" stroke-width="1.1" stroke-linecap="round"/>'
    return s


def roe(m, l):
    """Loose beads of roe in a small heap, each with its own glint."""
    beads = ((5, 5.4), (9.4, 4.4), (12.2, 7.8), (8, 8.6), (4, 9.8), (7.4, 12.6), (11.4, 11.8))
    return "".join(f'<circle cx="{x}" cy="{y}" r="2.2" fill="{m}"/><circle cx="{f(x - 0.7)}" cy="{f(y - 0.8)}" r="0.7" fill="{l}"/>' for x, y in beads)


def small_fillet(skin, back, line):
    """A small oily fish fillet skin side up, tail left on, with its dark back along one edge."""
    return f'<path d="M1 8.4C2.6 5 9 4.4 13 6.6L15.2 4.8 14.8 8 15.2 11.2 13 9.6C9 11.6 2.6 11.4 1 8.4Z" fill="{skin}"/><path d="M1.6 7.6C3.6 5.4 9 4.8 13 6.6" stroke="{back}" stroke-width="1.6" fill="none" stroke-linecap="round"/><path d="M3 8.6C6 7.8 9.6 7.8 12.6 8.2" stroke="{line}" stroke-width="0.7" fill="none" stroke-linecap="round"/>'


def uni_lobe(m, l, groove):
    return f'<path d="M2 8c0-2 1.2-3.2 3-3.2.8-.6 1.8-.6 2.6 0 .8-.6 1.8-.6 2.6 0 .8-.6 1.8-.6 2.6 0 1.4.4 2.2 1.6 2.2 3.2s-.8 2.8-2.2 3.2c-.8.6-1.8.6-2.6 0-.8.6-1.8.6-2.6 0-.8.6-1.8.6-2.6 0C3.2 11.2 2 10 2 8Z" fill="{m}"/><path d="M3.6 8h8.8" stroke="{groove}" stroke-width="0.8" stroke-linecap="round"/>' + "".join(f'<circle cx="{x}" cy="{y}" r="0.7" fill="{l}"/>' for x, y in ((4.6, 6.4), (7.4, 6.2), (10.2, 6.4), (6, 9.8), (8.8, 9.8), (11.6, 9.4)))


def long_fish(belly, back, char, eye):
    """A long, slender fish such as saury, grilled whole, with a pointed head and a forked tail."""
    return (
        f'<path d="M.6 8C3 5.8 10 5.6 13.2 7.2L15.4 5.6 14.8 8 15.4 10.4 13.2 8.8C10 10.4 3 10.2.6 8Z" fill="{belly}"/>'
        f'<path d="M.6 8C3 5.8 10 5.6 13.2 7.2V8C10 7.4 4 7.4.6 8Z" fill="{back}"/>'
        f'<path d="M5 7.6l.5 1.4M8 7.6l.5 1.5M11 7.8l.4 1.2" stroke="{char}" stroke-width="0.7" stroke-linecap="round"/>'
        f'<circle cx="2.6" cy="7.6" r="0.5" fill="{eye}"/>'
    )


def raisin(m, l):
    return f'<path d="M3 8.5c-.5-3 2-5 5-4.6 2.5-.6 5 .8 5.2 3.4.4 2.8-1.6 4.6-4.6 4.6-3 .4-5.2-1-5.6-3.4Z" fill="{m}"/><path d="M5 7.4c1.5-1 3-1 4.5 0M5.8 10c1.2.6 2.8.6 4.2-.2" stroke="{l}" stroke-width="0.8" fill="none" stroke-linecap="round"/>'


def shiso_leaf(m, v):
    """A broad leaf with a toothed edge and a short point, as shiso is laid on a dish."""
    top, bottom = [], []
    for i in range(15):
        t = i / 14
        w = 5.4 * math.sin(math.pi * min(1, t * 1.08)) ** 0.75 * (1 - 0.25 * t)
        w += 0.55 if i % 2 else 0
        x = 2 + 12.5 * t
        top.append((x, 8 - w))
        bottom.append((x, 8 + w))
    pts = top + bottom[::-1]
    d = "M" + "L".join(f"{f(x)} {f(y)}" for x, y in pts) + "Z"
    veins = "M2.6 8H13.4" + "".join(f"M{x} 8l1.8-{h}M{x} 8l1.8 {h}" for x, h in ((4.5, 3), (7, 3.4), (9.5, 2.8)))
    return f'<path d="{d}" fill="{m}" stroke="{m}" stroke-width="0.6"/><path d="{veins}" stroke="{v}" stroke-width="0.6" fill="none" stroke-linecap="round"/>'


def lobed_leaf(m, v):
    """A deeply cut leaf with rounded lobes in pairs along the rib, as shungiku and chrysanthemum leaves are."""
    s = f'<path d="M1.5 12.5 13 3.5" stroke="{m}" stroke-width="1.4" stroke-linecap="round"/>'
    for t, r in ((0.28, 2.9), (0.53, 2.7), (0.76, 2.2)):
        x, y = 1.5 + 11.5 * t, 12.5 - 9 * t
        for side in (-1, 1):
            cx, cy = x + side * 1.8, y + side * 2
            s += f'<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="{r}" ry="{f(r * 0.7)}" fill="{m}" transform="rotate({-38 + side * 50} {f(cx)} {f(cy)})"/>'
    s += f'<ellipse cx="13" cy="3.5" rx="2.4" ry="1.7" fill="{m}" transform="rotate(-38 13 3.5)"/>'
    return s + f'<path d="M2.5 11.7 13 3.5" stroke="{v}" stroke-width="0.5" stroke-linecap="round"/>'


def steak_strip(crust, band, inner):
    """A slice cut across a seared steak: crust at the ends, pink through the middle."""
    return f'<rect x="1.5" y="4.5" width="13" height="7" rx="2" fill="{crust}"/><rect x="2.6" y="5.4" width="10.8" height="5.2" rx="1.6" fill="{band}"/><rect x="3.8" y="6.2" width="8.4" height="3.6" rx="1.4" fill="{inner}"/>'


def small_fish(back, belly, mark):
    """A small fish grilled whole, head to the left and the tail forked."""
    return (
        f'<path d="M12.2 8 15.2 5.4 14.4 8 15.2 10.6Z" fill="{back}"/>'
        f'<path d="M1.2 8C2.6 5.6 7.5 5 12.6 7.2V8.8C7.5 11 2.6 10.4 1.2 8Z" fill="{belly}"/>'
        f'<path d="M2 7.3C4.6 5.8 8.6 5.6 12.4 7.3" stroke="{back}" stroke-width="1.5" fill="none" stroke-linecap="round"/>'
        f'<path d="M5.5 8.4 6.6 7.4M8.4 8.6 9.4 7.6" stroke="{mark}" stroke-width="0.9" stroke-linecap="round"/>'
        f'<circle cx="3" cy="7.6" r="0.7" fill="#2a2420"/>'
    )


def star_anise(m, s):
    """Eight pointed pods around the stalk, a seed showing in some."""
    out = ""
    for i in range(8):
        out += f'<path d="M8 8Q10.8 6.4 15 8 10.8 9.6 8 8Z" fill="{m}" transform="rotate({i * 45} 8 8)"/>'
        if i % 2 == 0:
            out += f'<ellipse cx="11" cy="8" rx="1.1" ry="0.55" fill="{s}" transform="rotate({i * 45} 8 8)"/>'
    return out + f'<circle cx="8" cy="8" r="1.3" fill="{m}"/>'


def narrow_sprig(m, stem=None):
    """A short stem with long, narrow leaves, as tarragon is picked."""
    st = stem or m
    s = f'<path d="M3 13 12 4" stroke="{st}" stroke-width="0.8" stroke-linecap="round"/>'
    for x, y, a in ((5, 11, -95), (7, 9, 5), (9, 7, -95), (10.6, 5.4, 5), (12, 4, -45)):
        s += f'<path d="M{x} {y}q2.8-1.4 5.6 0-2.8 1.4-5.6 0Z" fill="{m}" transform="rotate({a} {x} {y})"/>'
    return s


def powder(m, l=None):
    """A fine dusting, specks smaller than any grain or seed."""
    pts = ((3, 5), (5.5, 3.2), (8.4, 4.2), (11.6, 3.6), (13, 6.4), (10, 7), (6.6, 6.8), (3.8, 8.6), (7.8, 9.4), (11.2, 9.8), (13.4, 11.4), (9.4, 12.4), (5.6, 11.8), (3, 12), (7, 14))
    s = "".join(f'<circle cx="{x}" cy="{y}" r="0.85" fill="{m}"/>' for x, y in pts)
    if l:
        s += "".join(f'<circle cx="{x}" cy="{y}" r="0.7" fill="{l}"/>' for x, y in ((5, 7.4), (10.6, 5.4), (8.6, 11), (12.2, 8.2)))
    return s


def sector(skin, flesh):
    """A wedge lying on its cut face: a pie slice of flesh under a thin rim of skin."""
    return f'<path d="M3 14V2.5A11.5 11.5 0 0 1 14.5 14Z" fill="{skin}"/><path d="M3 14V4.3A9.7 9.7 0 0 1 12.7 14Z" fill="{flesh}"/>'


def round_leaflets(m, stem):
    s = f'<path d="M3 13 12.5 3.5" stroke="{stem}" stroke-width="1" stroke-linecap="round"/>'
    for x, y, r in ((3.9, 8.5, 2.1), (7.5, 12.1, 2.1), (6.6, 5.8, 2.2), (10.2, 9.4, 2.2), (12, 4, 2.8)):
        s += f'<circle cx="{x}" cy="{y}" r="{r}" fill="{m}"/>'
    return s


def rice_cake(m, l):
    return f'<rect x="1.5" y="4.5" width="13" height="7" rx="3.5" fill="{m}"/><path d="M4 6.6h7" stroke="{l}" stroke-width="1.2" stroke-linecap="round"/>'


def frond(m, rib):
    return f'<path d="M1.5 9c1-3 3-2 4-4s3-3 5-2 2 2 4 2c-.5 2-2 2.5-2 4.5s-2 3.5-4 3-3 .5-4.5-.5S1 11 1.5 9Z" fill="{m}"/><path d="M3 10.5c3-1.5 6-4 10-5.5" stroke="{rib}" stroke-width="1" fill="none" stroke-linecap="round"/>'


def folded_sheet(m, fold):
    return f'<path d="M2 5c2-2 4-1 6-2s4-1 6 1c.5 2.5-.5 5 0 7.5-2 2-4 1-6 2s-4 1-6-1c-.5-2.5.5-5 0-7.5Z" fill="{m}"/><path d="M3 7.5c3 1 7 .5 10-.5M3.5 10.5c3 1 6 .5 9-.5" stroke="{fold}" stroke-width="0.9" fill="none" stroke-linecap="round"/>'


def strip_heap(m, l):
    """A small heap of thin strips, as shredded pickled ginger is served."""
    s = "".join(f'<rect x="2.5" y="{f(7.2 - h)}" width="11" height="1.6" rx="0.8" fill="{m}" transform="rotate({r} 8 8)"/>' for h, r in ((2.4, -24), (0.8, 18), (-1, -8), (-2.6, 30), (0.2, 62)))
    return s + f'<path d="M5 6.4l5-2" stroke="{l}" stroke-width="0.7" stroke-linecap="round"/>'


# Fills -------------------------------------------------------------------------------------


def grains_in(rng, base, grain, count=70, length=2.4, width=1.3, shape="mound", sheen=True):
    if shape == "mound":
        s = f'<path d="{blob_path(rng, C, C, R * 0.97, 0.06)}" fill="{base}"/>'
    else:
        s = f'<circle cx="{C}" cy="{C}" r="{R}" fill="{base}"/>'
    if sheen:
        s += f'<path d="{blob_path(rng, C - 6, C - 7, 15, 0.1)}" fill="#ffffff" opacity="0.28"/>'
    for x, y in scatter_in_circle(rng, C, C, R * 0.88, count):
        rot = rng.uniform(0, 180)
        s += f'<ellipse cx="{f(x)}" cy="{f(y)}" rx="{length}" ry="{width}" transform="rotate({f(rot)} {f(x)} {f(y)})" fill="{grain}"/>'
    return s


def smooth(rng, base, sheen, specks=None, full=False, ridges=None):
    s = f'<circle cx="{C}" cy="{C}" r="{R}" fill="{base}"/>' if full else f'<path d="{blob_path(rng, C, C, R * 0.95, 0.09, 10)}" fill="{base}"/>'
    s += f'<path d="{blob_path(rng, C - 8, C - 9, 10, 0.2, 8)}" fill="{sheen}"/>'
    if ridges:
        s += f'<path d="M14 36c6-8 16-10 24-6M20 44c6-5 14-6 22-2M18 26c4-4 10-5 16-3" stroke="{ridges}" stroke-width="2.2" fill="none" stroke-linecap="round"/>'
    if specks:
        for x, y in scatter_in_circle(rng, C, C, R * 0.8, 18):
            s += f'<circle cx="{f(x)}" cy="{f(y)}" r="0.9" fill="{specks}"/>'
    return s


def soup(rng, base, sheen, dots=None):
    s = f'<circle cx="{C}" cy="{C}" r="{R}" fill="{base}"/><circle cx="{C}" cy="{C}" r="{R - 3}" fill="none" stroke="{sheen}" stroke-width="1.6" opacity="0.6"/>'
    if dots:
        for x, y in scatter_in_circle(rng, C, C, R * 0.75, 9, 5):
            s += f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(rng.uniform(1, 2.2))}" fill="{dots}"/>'
    return s


def noodles(rng, m, l, shade, width=2.4, count=26, broth=None, full=False, dots=None):
    s = ""
    if broth:
        s += f'<circle cx="{C}" cy="{C}" r="{R}" fill="{broth}"/>'
        r_nest = R * 0.72
    else:
        r_nest = R
    s += f'<circle cx="{C}" cy="{C}" r="{f(r_nest)}" fill="{shade}"/>' if (full or not broth) else ""
    for i in range(count):
        rr = r_nest * rng.uniform(0.2, 0.95)
        a0 = rng.uniform(0, math.tau)
        sweep = rng.uniform(1.6, 3.2)
        x0, y0 = C + rr * math.cos(a0), C + rr * math.sin(a0)
        x1, y1 = C + rr * math.cos(a0 + sweep), C + rr * math.sin(a0 + sweep)
        large = 1 if sweep > math.pi else 0
        c = m if i % 3 else l
        s += f'<path d="M{f(x0)} {f(y0)}A{f(rr)} {f(rr)} 0 {large} 1 {f(x1)} {f(y1)}" stroke="{c}" stroke-width="{width}" fill="none" stroke-linecap="round"/>'
    if dots:
        for x, y in scatter_in_circle(rng, C, C, r_nest * 0.85, 40):
            s += f'<circle cx="{f(x)}" cy="{f(y)}" r="0.8" fill="{dots}"/>'
    return s


def tiled(rng, piece_svg, size, count, base=None, shadow=None):
    s = f'<path d="{blob_path(rng, C, C, R * 0.96, 0.06)}" fill="{base}"/>' if base else ""
    for x, y in scatter_in_circle(rng, C, C, R * 0.8, count, size * 0.55):
        s += place(piece_svg, x, y, size, rng.uniform(0, 360))
    return s


def bed(rng, colors, vein, count=16):
    s = f'<path d="{blob_path(rng, C, C, R * 0.95, 0.1)}" fill="{colors[0]}"/>'
    for i, (x, y) in enumerate(scatter_in_circle(rng, C, C, R * 0.72, count)):
        s += place(torn_leaf(colors[i % len(colors)], vein), x, y, 18, rng.uniform(0, 360))
    return s


def shredded_bed(rng, colors):
    s = f'<path d="{blob_path(rng, C, C, R * 0.92, 0.1)}" fill="{colors[0]}"/>'
    for i in range(40):
        x, y = scatter_in_circle(rng, C, C, R * 0.8, 1)[0]
        a = rng.uniform(0, math.tau)
        x1, y1 = x + 7 * math.cos(a), y + 7 * math.sin(a)
        s += f'<path d="M{f(x)} {f(y)}Q{f((x + x1) / 2 + 2)} {f((y + y1) / 2 - 2)} {f(x1)} {f(y1)}" stroke="{colors[i % len(colors)]}" stroke-width="1.6" fill="none" stroke-linecap="round"/>'
    return s


def slice_of_bread(crumb, crust, count=1, extra="", rot=0):
    s = ""
    offsets = [(0, 0, rot)] if count == 1 else [(-6, -5, -10), (7, 6, 12)]
    sc = 1.05 if count == 1 else 0.86
    for dx, dy, r in offsets:
        s += (
            f'<g transform="translate({C + dx} {C + dy}) rotate({r}) scale({sc})">'
            f'<path d="M-24 -8a12 12 0 0 1 10-18h28a12 12 0 0 1 10 18v28a4 4 0 0 1-4 4h-40a4 4 0 0 1-4-4Z" fill="{crust}"/>'
            f'<path d="M-19 -7a8 8 0 0 1 7-13h24a8 8 0 0 1 7 13v24h-38Z" fill="{crumb}"/>{extra}</g>'
        )
    return s


def flatbread(rng, m, spot, edge, oval=False):
    shape = f'<ellipse cx="{C}" cy="{C}" rx="{R}" ry="{R * 0.72}" fill="{edge}"/><ellipse cx="{C}" cy="{C}" rx="{R - 2.5}" ry="{R * 0.72 - 2.5}" fill="{m}"/>' if oval else f'<circle cx="{C}" cy="{C}" r="{R}" fill="{edge}"/><circle cx="{C}" cy="{C}" r="{R - 2.5}" fill="{m}"/>'
    for x, y in scatter_in_circle(rng, C, C, R * 0.6, 10, 5):
        shape += f'<ellipse cx="{f(x)}" cy="{f(y * 0.9 + 3)}" rx="{f(rng.uniform(1.4, 2.8))}" ry="{f(rng.uniform(1, 2))}" fill="{spot}"/>'
    return shape


def omelette(rng, m, l, fold):
    return f'<ellipse cx="{C}" cy="{C}" rx="{R}" ry="{R * 0.62}" fill="{m}"/><path d="M{C - R + 6} {C}c12-10 36-10 48 0" stroke="{fold}" stroke-width="1.6" fill="none" stroke-linecap="round"/><ellipse cx="{C - 8}" cy="{C - 6}" rx="9" ry="3.4" fill="{l}"/>'


def block(rng, m, l, edge):
    return f'<rect x="{C - 21}" y="{C - 17}" width="42" height="34" rx="4" fill="{edge}"/><rect x="{C - 19}" y="{C - 15}" width="38" height="30" rx="3" fill="{m}"/><path d="M{C - 13} {C - 9}h14" stroke="{l}" stroke-width="3" stroke-linecap="round"/>'


def row_of(rng, piece_svg, size, n=5):
    """Pieces set side by side the way gyoza come out of the pan, two short rows."""
    s = ""
    step = size * 0.62
    for row, dy in enumerate((-size * 0.42, size * 0.42)):
        count = n if row == 0 else n - 1
        x0 = C - step * (count - 1) / 2
        for i in range(count):
            s += place(piece_svg, x0 + i * step, C + dy, size)
    return s


def melted(rng, m, l, brown):
    s = f'<path d="{blob_path(rng, C, C, R * 0.8, 0.16, 9)}" fill="{m}"/>'
    for x, y in scatter_in_circle(rng, C, C, R * 0.55, 6, 7):
        s += f'<path d="{blob_path(rng, x, y, 3, 0.3, 6)}" fill="{brown}"/>'
    return s + f'<path d="{blob_path(rng, C - 7, C - 6, 6, 0.3, 7)}" fill="{l}"/>'


def covering_slices(rng, piece_svg, size, n=5):
    s = ""
    for (dx, dy, rot) in [(-10, -11, -20), (9, -10, 15), (-12, 6, 10), (10, 8, -15), (0, -1, 5)][:n]:
        s += place(piece_svg, C + dx, C + dy, size, rot)
    return s


def kale_bed(rng):
    colors = ["#2f5f2e", "#3a6a35", "#447540"]
    s = f'<path d="{blob_path(rng, C, C, R * 0.95, 0.1)}" fill="{colors[0]}"/>'
    for i, (x, y) in enumerate(scatter_in_circle(rng, C, C, R * 0.72, 16)):
        s += place(curly_leaf(colors[i % len(colors)], "#a8cf8e"), x, y, 18, rng.uniform(0, 360))
    return s


def lasagna_top(rng):
    """A square of lasagna from above: browned cheese, with sauce seeping out at the edges."""
    s = f'<rect x="{C - 22}" y="{C - 22}" width="44" height="44" rx="4" fill="#b8502f"/><rect x="{C - 19}" y="{C - 19}" width="38" height="38" rx="3" fill="#eec060"/>'
    for x, y in ((C - 14, C + 12), (C + 13, C - 5), (C + 3, C + 15), (C - 10, C - 15)):
        s += f'<path d="{blob_path(rng, x, y, 4.6, 0.3, 7)}" fill="#c43a2a"/>'
    for x, y in scatter_in_circle(rng, C, C, 13, 6, 7):
        s += f'<path d="{blob_path(rng, x, y, 2.4, 0.3, 6)}" fill="#d49a48"/>'
    return s + f'<path d="{blob_path(rng, C - 8, C - 8, 6, 0.3, 7)}" fill="#ffffff" opacity="0.22"/>'


def spring_rolls(rng, m, l, shrimp, herb):
    """Fresh rolls with the herbs and halved shrimp showing through the wrapper."""
    s = ""
    for dy in (-14, 0, 14):
        s += f'<rect x="{C - 24}" y="{C + dy - 6}" width="48" height="12" rx="6" fill="{m}"/>'
        s += f'<path d="M{C - 20} {C + dy + 2}h40" stroke="{herb}" stroke-width="2.6" stroke-linecap="round" opacity="0.55"/>'
        for dx in (-14, 0, 14):
            s += f'<path d="M{C + dx - 4} {C + dy + 1}a4 3.4 0 0 1 8 0" stroke="{shrimp}" stroke-width="2.4" fill="none" stroke-linecap="round" opacity="0.7"/>'
        s += f'<path d="M{C - 18} {C + dy - 3.6}h20" stroke="{l}" stroke-width="1.2" stroke-linecap="round"/>'
    return s


# Vessels -----------------------------------------------------------------------------------

def dish(cx, rim, well, rim_r, well_r, extra="", inner=""):
    """A plate, bowl or pan seen from above: a rim lit from the top left, a well that falls
    away from it, a bright edge on the lit side of the rim, and a shade inside the far wall."""
    rt, rb, rd = ramp(rim, 0.35, 0.16)
    wt, wb, wd = ramp(well, 0.25, 0.1)
    a = rim_r * 0.7
    return (
        f'<defs><linearGradient id="vr" x1="{cx - rim_r}" y1="{48 - rim_r}" x2="{cx + rim_r}" y2="{48 + rim_r}" gradientUnits="userSpaceOnUse">'
        f'<stop offset="0" stop-color="{rt}"/><stop offset="0.5" stop-color="{rb}"/><stop offset="1" stop-color="{rd}"/></linearGradient>'
        f'<radialGradient id="vw" cx="{cx + well_r * 0.25}" cy="{48 + well_r * 0.3}" r="{well_r * 1.25}" gradientUnits="userSpaceOnUse">'
        f'<stop offset="0" stop-color="{wt}"/><stop offset="0.6" stop-color="{wb}"/><stop offset="1" stop-color="{wd}"/></radialGradient></defs>'
        f'{extra}<circle cx="{cx}" cy="48" r="{rim_r}" fill="url(#vr)"/>'
        f'<path d="M{f(cx - a)} {f(48 + a * 0.35)}A{rim_r - 1.6} {rim_r - 1.6} 0 0 1 {f(cx + a * 0.35)} {f(48 - a)}" stroke="#ffffff" stroke-opacity="0.55" stroke-width="1.6" fill="none" stroke-linecap="round"/>'
        f'{inner}<circle cx="{cx}" cy="48" r="{well_r}" fill="url(#vw)"/>'
        f'<path d="M{f(cx - well_r * 0.8)} {f(48 - well_r * 0.45)}A{well_r - 1} {well_r - 1} 0 0 1 {f(cx + well_r * 0.45)} {f(48 - well_r * 0.8)}" stroke="{wd}" stroke-opacity="0.35" stroke-width="2" fill="none" stroke-linecap="round"/>'
    )


HANDLE = '<defs><linearGradient id="vh" x1="0" y1="43" x2="0" y2="53" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#d79c64"/><stop offset="1" stop-color="#8a5530"/></linearGradient><linearGradient id="vk" x1="0" y1="43" x2="0" y2="53" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#5d636b"/><stop offset="1" stop-color="#26292e"/></linearGradient></defs>'

VESSELS = {
    "plate": (dish(48, "#f0ece4", "#e8e3d8", 46, 37), "plate"),
    "plate-rim": (dish(48, "#f0ece4", "#e8e3d8", 46, 37, inner='<circle cx="48" cy="48" r="43" fill="none" stroke="#5f7fa3" stroke-width="2.4"/>'), "plate"),
    "plate-sage": (dish(48, "#9fb8a0", "#b6cbb5", 46, 37), "plate"),
    "plate-terracotta": (dish(48, "#c9805f", "#d99a7c", 46, 37), "plate"),
    "bowl": (dish(48, "#f0ece4", "#d9d2c3", 46, 40), "bowl"),
    "bowl-indigo": (dish(48, "#3f5a7a", "#2f4762", 46, 40), "bowl"),
    "bowl-sage": (dish(48, "#7f9c82", "#6a876d", 46, 40), "bowl"),
    "pan": (HANDLE + dish(44, "#6f747b", "#4a4e54", 42, 37, extra='<rect x="80" y="43" width="16" height="10" rx="5" fill="url(#vh)"/>'), "pan"),
    "pot": (HANDLE + dish(48, "#8a9097", "#5d6268", 40, 36, extra='<rect x="0" y="43" width="12" height="10" rx="4" fill="url(#vk)"/><rect x="84" y="43" width="12" height="10" rx="4" fill="url(#vk)"/>'), "pot"),
    "board": ('<defs><linearGradient id="vb" x1="4" y1="12" x2="92" y2="84" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#d4a56c"/><stop offset="0.5" stop-color="#b98a55"/><stop offset="1" stop-color="#94683a"/></linearGradient>'
              '<linearGradient id="vt" x1="8" y1="16" x2="88" y2="80" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#e2b77e"/><stop offset="0.5" stop-color="#c99a62"/><stop offset="1" stop-color="#ad7f4a"/></linearGradient></defs>'
              '<rect x="4" y="12" width="88" height="72" rx="10" fill="url(#vb)"/><rect x="8" y="16" width="80" height="64" rx="8" fill="url(#vt)"/>'
              '<path d="M14 30h30M50 44h32M16 62h40" stroke="#a87a46" stroke-opacity="0.7" stroke-width="1.6" stroke-linecap="round"/>'
              '<path d="M12 74V24c0-3 2-5 5-5h40" stroke="#ffffff" stroke-opacity="0.35" stroke-width="1.6" fill="none" stroke-linecap="round"/>', "board"),
}

# Where fills sit on each kind of vessel, as (cx, cy, r) on the 96 canvas.
REGIONS = {
    "plate": {"full": (48, 48, 32), "left": (36, 50, 24), "right": (61, 45, 25)},
    "bowl": {"full": (48, 48, 38), "left": (37, 48, 26), "right": (60, 48, 26)},
    "pan": {"full": (44, 48, 34), "left": (33, 50, 23), "right": (56, 45, 23)},
    "pot": {"full": (48, 48, 35), "left": (37, 48, 24), "right": (60, 48, 24)},
    "board": {"full": (48, 48, 34), "left": (32, 48, 22), "right": (64, 48, 22)},
}
