from draw import *

# Every ingredient in the app's catalog, keyed by the catalog's kebab-case name, with the
# variants it can be drawn as on a finished dish. An ingredient that cannot be seen once a dish
# is served is listed in HIDDEN with the reason, so the layout leaves it out on purpose.

PLATES = ["plate"]
BOWLS = ["bowl", "pot"]
ANY = ["plate", "bowl", "pan", "pot"]
SAUCE = ["plate", "bowl", "pan", "pot"]
FLAT = ["plate", "board"]
MOUND = ["plate", "pan"]


# Sizes are on the 96 canvas. Scattered pieces are drawn a quarter larger than written, and
# nothing set in the middle is drawn smaller than 18, which is what the review sheets showed
# still reads at the size the grid shows a card.
def p(svg, size, count, tier=0):
    if tier == 0:
        size = round(size * 1.25)
    elif tier == 1:
        size = max(size, 18)
    else:
        size = max(round(size * 1.15), 5)
    return {"kind": "piece", "svg": svg, "size": size, "count": count, "tier": tier}


def fl(maker, vessels, covers=False):
    entry = {"kind": "fill", "make": maker, "vessels": vessels}
    if covers:
        entry["covers"] = True
    return entry


def garnish(svg, size, count):
    return p(svg, size, count, 2)


def center(svg, size, count=1):
    return p(svg, size, count, 1)


# A piece that is one whole thing, such as a fried egg or a sausage. The dish draws as many as
# the recipe's amount says, up to the most it has room for, and the count when it says nothing.
def whole(entry, most):
    return {**entry, "most": most}


GREEN, GREEN_L, GREEN_D = "#7fb069", "#a8cf8e", "#4f8a3a"
DARK_LEAF, DARK_LEAF_L = "#3f6b3a", "#5f8f45"
CREAM = "#f4f1e8"
RED, RED_L = "#d94f45", "#e8695f"

V = {}

# Vegetables --------------------------------------------------------------------------------

V["artichoke"] = {"quartered": p(artichoke_quarter("#7f9c5a", "#ece6bc", "#b8b07a"), 14, 4)}
V["arugula"] = {"leaves": garnish(rocket_leaf("#3f7a35", "#6a9f50"), 12, 6), "bed": fl(lambda r: bed(r, ["#4f8a3a", "#5f9a45", "#6aa04f"], "#8fbf6f"), PLATES + BOWLS)}
V["asparagus"] = {"spears": p(spear("#7fb069", "#5f8f45", "#a8cf8e"), 18, 4), "cut": p(asparagus_piece("#7fb069", "#5f8f45", "#a8cf8e"), 10, 7)}
V["bamboo-shoots"] = {"slices": p(half_moon("#c9b46f", "#efe2b0") + '<path d="M3.4 10h9.2M4.3 8.2h7.4M5.6 6.4h4.8" stroke="#d9c88a" stroke-width="0.7" stroke-linecap="round"/>', 13, 5)}
V["bean-sprouts"] = {"sprouts": p(shreds("#ece4c4", "#e0c860"), 13, 6)}
V["beetroot"] = {"diced": p(dice("#9b2a4a", "#c4476b"), 10, 7), "sliced": p(round_slice("#7d1f3c", "#b8355e", rings="#d4708f"), 14, 4), "wedges": p(wedge("#7d1f3c", "#b8355e"), 13, 5)}
V["bell-pepper"] = {"strips": p(strip("#d94f45", "#ef7a6a"), 13, 6), "diced": p(dice("#d94f45", "#ef7a6a"), 9, 8)}
V["bitter-melon"] = {"slices": p(goya_slice("#4f8f3a", "#e8efcf"), 12, 6)}
V["bok-choy"] = {"halves": p('<path d="M8 1c3.4 0 6 2.3 6 5.3 0 2.2-1.4 3.6-3 4.2H5c-1.6-.6-3-2-3-4.2C2 3.3 4.6 1 8 1Z" fill="#4f8a3a"/><path d="M4.6 8.6c0-1 1.6-1.9 3.4-1.9s3.4.9 3.4 1.9c0 2.5-1.2 5-2.2 6.4H6.8c-1-1.4-2.2-3.9-2.2-6.4Z" fill="#e2edc4"/><path d="M8 7.4v7M6.3 8.4l.8 5.8M9.7 8.4l-.8 5.8" stroke="#bcd89c" stroke-width="0.6" stroke-linecap="round"/><path d="M8 6.8V3" stroke="#7fb069" stroke-width="0.8" stroke-linecap="round"/>', 16, 3)}
V["broccoli"] = {"florets": p(floret("#5f9a45", "#7fb069", "#a8cf8e"), 14, 5)}
V["brussels-sprouts"] = {"halves": p('<path d="M8 1.5C12 1.5 14.5 4.5 14.5 8 14.5 11 12.5 13.5 10 14H6C3.5 13.5 1.5 11 1.5 8 1.5 4.5 4 1.5 8 1.5Z" fill="#4f8a3a"/><path d="M8 2.9C11.2 2.9 13.1 5.2 13.1 8 13.1 10.4 11.6 12.4 9.6 12.7H6.4C4.4 12.4 2.9 10.4 2.9 8 2.9 5.2 4.8 2.9 8 2.9Z" fill="#dbe9a6"/><path d="M5.2 12.4C4 11.4 4.2 7 5.6 5.4 7 4 9 4 10.4 5.4 11.8 7 12 11.4 10.8 12.4M6.6 12.4C6 10.6 6.2 8 7 7 7.6 6.4 8.4 6.4 9 7 9.8 8 10 10.6 9.4 12.4" stroke="#93bd62" stroke-width="0.8" fill="none" stroke-linecap="round"/><path d="M6.9 12.7 8 9.4 9.1 12.7Z" fill="#f2f5d6"/>', 12, 5)}
V["burdock"] = {"julienne": p(julienne("#9c7a55", "#c4a37a"), 11, 8)}
V["butternut-squash"] = {"cubes": p(dice("#f0a646", "#f7c27a"), 11, 6), "mash": fl(lambda r: smooth(r, "#f0a646", "#f7c27a", ridges="#e0902f"), PLATES + BOWLS), "soup": fl(lambda r: soup(r, "#f0a646", "#f7c27a"), BOWLS)}
V["cabbage"] = {"shredded": fl(lambda r: shredded_bed(r, ["#dcebc9", "#c5dea8", "#b4d494"]), PLATES + BOWLS), "chopped": p(torn_leaf("#c5dea8", "#eef3d6"), 13, 5)}
V["carrot"] = {"coins": p(round_slice("#ff832b", "#ffa25c", core="#ffb97a"), 11, 6), "diced": p(dice("#ff832b", "#ffa25c"), 9, 7), "julienne": p(julienne("#ff832b", "#ffa25c"), 11, 7), "chunks": p(chunk("#ff832b", "#ffa25c"), 11, 4)}
V["cauliflower"] = {"florets": p(floret("#f2ecd8", "#fbf7ea", "#dcebc9"), 14, 5)}
V["celery"] = {"slices": p(celery_slice("#6fa555", "#d2e8b2"), 10, 7)}
V["cherry-tomato"] = {"halves": p(round_slice("#d94f45", "#e8695f", seeds="#f4c27a"), 11, 6), "whole": p(berry("#d94f45", "#f08a6a", "#5f8f45"), 11, 5)}
V["chili"] = {"rings": garnish(ring("#d23a30", "#f4c27a", 2.6), 9, 7)}
V["chives"] = {"snipped": garnish(julienne("#4f8a3a"), 6, 12)}
V["corn"] = {"kernels": p(kernels("#f6c84a", "#ffe58a"), 10, 6)}
V["cucumber"] = {"slices": p(round_slice("#4f8a3a", "#dfeec4", seeds="#b9d48f"), 13, 5), "half-moons": p(half_moon("#4f8a3a", "#dfeec4", "#b9d48f"), 12, 6), "julienne": p(julienne("#c5dea8", "#4f8a3a"), 11, 7)}
V["daikon"] = {"grated": center(grated_mound("#f6f4ec", "#dcd8c8"), 22), "simmered": p(round_slice("#e2cfa0", "#efe2bf"), 15, 3), "slices": p(round_slice("#f4f1e8", "#fbf9f4"), 13, 4)}
V["edamame"] = {"pods": p(pod("#6aa04f", "#a8cf8e"), 13, 5), "beans": p(bean("#6aa84a", "#a8d88a"), 8, 9)}
V["eggplant"] = {"slices": p(round_slice("#5b3a6b", "#e9dfb8", seeds="#c9b98a"), 14, 4), "chunks": p(cube("#d9c28f", "#efe2bf", "#5b3a6b"), 12, 5)}
V["enoki"] = {"clusters": p(enoki("#f4ecd0", "#e8dcb4"), 14, 3)}
V["fennel"] = {"slices": p(half_moon("#cfe0a8", "#eef3d6") + '<path d="M4.4 11a3.6 3.6 0 0 1 7.2 0M6.2 11a1.8 1.8 0 0 1 3.6 0" stroke="#c5d99a" stroke-width="0.8" fill="none"/>', 13, 5)}
V["gai-lan"] = {"stalks": p(stalk_with_leaf("#8fbf6f", "#3f6b3a", "#7fb069"), 17, 4)}
V["garlic"] = {"chips": p('<ellipse cx="8" cy="8" rx="6.5" ry="5" fill="#b98340"/><ellipse cx="8" cy="8" rx="4.6" ry="3.4" fill="#f3dca8"/>', 12, 7), "minced": garnish(dust("#ead69c", "#f6ecd0"), 11, 3), "roasted": p(teardrop("#d9a85c", "#f0d49a"), 10, 5)}
V["ginger"] = {"julienne": garnish(julienne("#e9c88a", "#f3dca8"), 10, 6), "grated": center(grated_mound("#efd7a0", "#d9b878"), 22)}
V["green-beans"] = {"cut": p(spear("#5f9a45", "#4f8a3a"), 12, 7)}
V["jalapeno"] = {"rings": p(ring("#4f8a3a", "#e8efcf", 2.6), 11, 6)}
V["kabocha"] = {"wedges": p(squash_wedge("#3f6b3a", "#f0a646"), 16, 4), "cubes": p(cube("#f0a646", "#f7c27a", "#3f6b3a"), 12, 5)}
V["kale"] = {"torn": p(curly_leaf("#3a6a35", "#a8cf8e"), 14, 5), "bed": fl(kale_bed, PLATES + BOWLS)}
V["kimchi"] = {"pieces": p('<path d="M2.5 7.4c3.2-1.4 6.6-2.4 10.2-2.8.8 2.4 1.4 5 1.6 7.6-3.2.6-6.6 1.4-9.8 2.6-1-2.4-1.8-4.8-2-7.4Z" fill="#f4ae76"/><path d="M1.8 7.8C1.6 5.6 3 4.6 4.4 5.4 4.8 3.4 6.8 3 7.8 4.2 8.6 2.4 11 2.4 11.6 3.8c1.4-.6 2.6.6 2 2.2-3.8.2-7.8 1.2-11.8 1.8Z" fill="#d9412c"/><path d="M5.2 13.4c-.6-1.8-1-3.6-1.2-5.2M8.6 12.4c-.4-1.8-.6-3.6-.6-5.4M11.8 11.6c-.2-1.8-.2-3.6-.4-5.4" stroke="#d9603a" stroke-width="0.8" fill="none" stroke-linecap="round"/>', 15, 5)}
V["king-oyster"] = {"slices": p(king_oyster_slice("#b98250", "#f2e8cf"), 15, 4), "coins": p(coin("#d9b98a", "#f2e8cf"), 12, 5)}
V["komatsuna"] = {"chopped": p(torn_leaf("#4f8a3a", "#7fb069"), 13, 5)}
V["leek"] = {"rings": p(ring("#c5dea8", "#eef3d6", 2.4), 10, 6)}
V["lettuce"] = {"torn": p(torn_leaf("#a8cf8e", "#dcebc9"), 15, 4), "bed": fl(lambda r: bed(r, ["#a8cf8e", "#93c27a", "#b9d89f"], "#dcebc9"), PLATES + BOWLS)}
V["lotus-root"] = {"slices": p('<circle cx="8" cy="8" r="7" fill="#e2d2ae"/><circle cx="8" cy="8" r="6" fill="#f2e8cf"/>' + "".join(f'<circle cx="{f(8 + 3.4 * math.cos(math.tau * i / 6))}" cy="{f(8 + 3.4 * math.sin(math.tau * i / 6))}" r="1.3" fill="#d4c39c"/>' for i in range(6)) + '<circle cx="8" cy="8" r="1.1" fill="#d4c39c"/>', 14, 4)}
V["mizuna"] = {"leaves": p(mizuna_sprig("#4f9a38", "#eef3d6"), 14, 5), "bed": fl(lambda r: tiled(r, mizuna_sprig("#3f8a2e", "#f6faea"), 20, 16, base="#8fbf6f"), PLATES + BOWLS)}
V["mushroom"] = {"sliced": p(mushroom_slice("#a87e5a", "#ead9bd"), 13, 5), "quartered": p(mushroom_quarter("#a87e5a", "#ead9bd", "#f2e6cf"), 13, 5)}
V["myoga"] = {"shredded": garnish('<rect x="5.6" y="2" width="4.8" height="12" rx="2.4" fill="#f8ece6"/><rect x="5.6" y="2" width="2" height="12" rx="1" fill="#d9677a"/>', 11, 6)}
V["napa-cabbage"] = {"chopped": p('<path d="M2 8c0-4 3-6 6-5.5 2-1.5 5 0 5.5 2.5 2 1.5 1.5 5-.5 6-1 2.5-4 3.5-6.5 2-3 .5-4.5-2-4.5-5Z" fill="#cfe3b0"/><path d="M3 12 12 4" stroke="#f6f8ea" stroke-width="3" stroke-linecap="round"/>', 14, 5)}
V["nira"] = {"cut": p(julienne("#3f6b3a", "#5f8f45"), 11, 7)}
V["okra"] = {"slices": p('<path d="M8 1.5 10 4.5 13.6 4.8 12.4 8 13.6 11.2 10 11.5 8 14.5 6 11.5 2.4 11.2 3.6 8 2.4 4.8 6 4.5Z" fill="#5f9a45"/><circle cx="8" cy="8" r="3.2" fill="#e8efcf"/>' + "".join(f'<circle cx="{f(8 + 2 * math.cos(math.tau * i / 5))}" cy="{f(8 + 2 * math.sin(math.tau * i / 5))}" r="0.6" fill="#c5dea8"/>' for i in range(5)), 10, 6)}
V["onion"] = {"rings": p(ring("#efe2c4", "#f8f2e2", 2.2), 11, 5), "diced": p(dice("#f4ecd6", "#fbf7ea"), 7, 9), "caramelized": p(shreds("#b9763c", "#d39a5a"), 12, 5)}
V["parsnip"] = {"coins": p(round_slice("#e2cfa0", "#f2e6c4", core="#e8d6a8"), 11, 6), "roasted": p(chunk("#d9a85c", "#f0d49a"), 12, 4)}
V["pea-shoots"] = {"shoots": p(pea_shoot("#bfe08e", "#5fa83f", "#7fb85a"), 14, 5)}
V["peas"] = {"peas": p(small_round("#6aa04f", "#a8cf8e"), 6, 10)}
V["potato"] = {"chunks": p(chunk("#ead08f", "#f6e3b0"), 12, 4), "wedges": p(thick_wedge("#9a6630", "#e9b860", "#f6d68e"), 15, 4), "slices": p(round_slice("#e6c36f", "#f4dc9a"), 13, 4), "mash": fl(lambda r: smooth(r, "#f2e2b0", "#faf0d0", ridges="#e4cf92"), PLATES + BOWLS)}
V["pumpkin"] = {"cubes": p(dice("#f08a2b", "#f7ad5c"), 11, 6), "soup": fl(lambda r: soup(r, "#f08a2b", "#f7ad5c"), BOWLS)}
V["radish"] = {"slices": p(round_slice("#d94f63", "#fbf7f2", rings="#f2d6dc"), 10, 6)}
V["red-onion"] = {"rings": p(ring("#9b4a7a", "#e8c6d8", 2.2), 11, 5), "diced": p(dice("#b5608e", "#e8c6d8"), 7, 9)}
V["shallot"] = {"crispy": garnish(shreds("#a8682f", "#c98a4b"), 9, 5), "rings": p(ring("#b97a8e", "#ecd2da", 1.8), 8, 6)}
V["shiitake"] = {"caps": p(mushroom_cap("#8a5a3a", "#d9b48a", "#6f4a2f"), 13, 4), "sliced": p(mushroom_slice("#8a5a3a", "#e6d3b4"), 12, 5)}
V["shimeji"] = {"clusters": p(small_caps("#b89a74", "#d9c3a0"), 13, 4)}
V["shiso"] = {"shredded": garnish(shred("#4f8a3a", 1.8), 8, 7), "leaf": center(shiso_leaf("#4f8a3a", "#8fbf6f"), 28)}
V["shungiku"] = {"leaves": p(lobed_leaf("#4f8a3a", "#7fb069"), 14, 5)}
V["snow-peas"] = {"pods": p('<path d="M1.5 10C3.5 6.5 9 4.6 14.2 5.6 13 9.2 8.5 11.4 3 11Z" fill="#6aa84a"/><ellipse cx="5.6" cy="9.1" rx="1.5" ry="1" fill="#8cc068" transform="rotate(-20 5.6 9.1)"/><ellipse cx="8.6" cy="8.2" rx="1.5" ry="1" fill="#8cc068" transform="rotate(-20 8.6 8.2)"/><ellipse cx="11.4" cy="7.2" rx="1.3" ry="0.9" fill="#8cc068" transform="rotate(-20 11.4 7.2)"/><path d="M2.4 9.6C5 7 9.5 5.4 13.8 5.8" stroke="#4f8a3a" stroke-width="0.7" fill="none" stroke-linecap="round"/><path d="M14.2 5.6 15.4 4.4" stroke="#4f7a32" stroke-width="1.2" stroke-linecap="round"/>', 14, 5)}
V["spinach"] = {"wilted": p(torn_leaf("#3f6b3a", "#5f8f45"), 13, 5), "bed": fl(lambda r: bed(r, ["#3f6b3a", "#4a7a3f", "#557f47"], "#6f9a55"), PLATES + BOWLS)}
V["spring-onion"] = {"rings": garnish(rings_small("#c5dea8", "#5f9a45", "#eef3d6"), 8, 7), "sliced": p(julienne("#7fb069", "#dcebc9"), 11, 6)}
V["sweet-potato"] = {"coins": p(round_slice("#8a3a5a", "#f2c46a"), 13, 4), "cubes": p(cube("#f2c46a", "#f8d98f", "#8a3a5a"), 11, 6), "mash": fl(lambda r: smooth(r, "#f0b45a", "#f8cf88", ridges="#e09a3f"), PLATES + BOWLS)}
V["swiss-chard"] = {"torn": p(torn_leaf("#3f6b3a", "#d9536b"), 14, 5)}
V["taro"] = {"chunks": p('<path d="M2 6.5 7.5 2.5 14 5.5 13 12.5 5 14 1.5 10.5Z" fill="#e8dccf"/>' + "".join(f'<circle cx="{x}" cy="{y}" r="0.7" fill="#b9a6c2"/>' for x, y in ((6, 6), (10, 7), (7, 10.5), (11, 11))), 12, 5)}
V["tomato"] = {"diced": p(dice("#d94f45", "#f08a6a"), 10, 8), "sliced": p('<circle cx="8" cy="8" r="7" fill="#d94f45"/><circle cx="8" cy="8" r="5.4" fill="#e8695f"/><path d="M8 3.5v9M3.8 6l8.4 4M3.8 10l8.4-4" stroke="#d94f45" stroke-width="1.3"/><circle cx="8" cy="8" r="1.3" fill="#f4b8a0"/>', 18, 4), "wedges": p(wedge("#d94f45", "#f08a6a", "#f4c27a"), 16, 5), "sauce": fl(lambda r: smooth(r, "#d94f45", "#e8695f"), SAUCE)}
V["turnip"] = {"wedges": p(sector("#a8608e", "#f8f5ee"), 13, 5), "slices": p(round_slice("#f2edf2", "#fbf9f4"), 12, 5)}
V["water-chestnut"] = {"slices": p(round_slice("#d9c9a8", "#fbf7ea"), 10, 6)}
V["watercress"] = {"sprigs": p(round_leaflets("#3f7a35", "#8fb86a"), 14, 5)}
V["yam"] = {"grated": center(dollop("#f6f2e6", "#e2dccb"), 22), "cubes": p(cube("#f6f2e6", "#fbf9f4", "#c9b48f"), 10, 6)}
V["zucchini"] = {"coins": p(round_slice("#4f8a3a", "#e6eec0", seeds="#c5d89a"), 12, 5), "half-moons": p(half_moon("#4f8a3a", "#e6eec0"), 12, 6)}

V["cassava"] = {"chunks": p(chunk("#f6efdc", "#ffffff"), 12, 4), "fried": p(stick("#e8c070", "#f6dca0"), 14, 5)}
V["celeriac"] = {"cubes": p(cube("#efe6c8", "#fbf6e2", "#d9c9a0"), 10, 6), "mash": fl(lambda r: smooth(r, "#efe8d0", "#faf6e8", ridges="#e0d6b4"), PLATES + BOWLS)}
V["curry-leaves"] = {"leaves": garnish(leaf("#2f6a2a", "#3f7f35"), 9, 5)}
V["fava-beans"] = {"beans": p(bean("#a8cf6f", "#d4e8a8"), 10, 7)}
V["horseradish"] = {"grated": center(dollop("#f6f2e2", "#e6e0cc"), 22)}
V["kaiware"] = {"sprouts": garnish(sprout("#f4f1e8", "#8fcb63"), 11, 6)}
V["maitake"] = {"torn": p(maitake("#7a604a", "#b49c84", "#eadfca"), 14, 5)}
V["mitsuba"] = {"leaves": garnish(trefoil("#5f9a45", "#a8cf8e"), 11, 5)}
V["nameko"] = {"caps": p(small_round("#c8682a", "#f2b880"), 8, 7)}
V["nanohana"] = {"stalks": p(spear("#4f8a3a", "#e8d23a", "#7fb069"), 15, 4)}
V["perilla-leaves"] = {"leaf": center(serrated_leaf("#3f7a35", "#8fbf6f"), 30), "shredded": garnish(shred("#3f7a35", 1.8), 8, 7)}
V["poblano"] = {"strips": p(strip("#2f5a2a", "#5a9045"), 13, 5)}
V["radicchio"] = {"torn": p(ribbed_leaf("#9c2448", "#f4e4ea"), 14, 5)}
V["shishito"] = {"blistered": p('<path d="M1 8H2.6" stroke="#7a9a4a" stroke-width="1" stroke-linecap="round"/><path d="M3.4 6.4C7 5.3 11.2 5.8 14.8 8.2 11.2 10.8 7 10.8 3.4 9.7Z" fill="#5f9a3a"/><path d="M3.6 6.4C2.6 7 2.4 9 3.6 9.7L4.6 8Z" fill="#4a7a2e"/><path d="M5.5 8.6C8 9 10.5 8.8 13 8.2M6 7c2-.4 4-.3 6 .4" stroke="#8cc068" stroke-width="0.6" fill="none" stroke-linecap="round"/><circle cx="7.4" cy="7.4" r="0.9" fill="#3a3a22" opacity="0.7"/><circle cx="10.6" cy="8.9" r="0.8" fill="#3a3a22" opacity="0.7"/><circle cx="12.6" cy="7.9" r="0.6" fill="#3a3a22" opacity="0.7"/>', 15, 4)}
V["tomatillo"] = {"diced": p(dice("#8fbf3a", "#dfe8a8"), 10, 7)}

# Fruits ------------------------------------------------------------------------------------

V["apple"] = {"slices": p(crescent("#c9373f", "#f6ecc8"), 14, 5), "diced": p('<rect x="2.5" y="2.5" width="11" height="11" rx="1.6" fill="#f6ecc8"/><rect x="2.5" y="2.5" width="11" height="3" rx="1.4" fill="#c9373f"/><rect x="4.6" y="7" width="4" height="2" rx="1" fill="#fbf7ea"/>', 9, 7)}
V["apricot"] = {"halves": p(round_slice("#f0a040", "#f8c070", core="#a8642a"), 12, 4), "slices": p(crescent("#ec8a35", "#f8c878"), 14, 5)}
V["avocado"] = {"half": center(avocado_half("#3f5a2a", "#c9dc8a", "#8a5a3a"), 30), "sliced": p(crescent("#3f5a2a", "#c9dc8a"), 15, 4), "diced": p(cube("#c9dc8a", "#e2edb8", "#6f8f3a"), 9, 7)}
V["banana"] = {"coins": p(round_slice("#f2e2a6", "#fbf2cc", seeds="#c9b07a"), 11, 6)}
V["blackberry"] = {"berries": p(cluster("#3a1f45", "#7a5a8f", 2.2), 9, 6)}
V["blueberry"] = {"berries": p(berry("#4b5a9e", "#7c8ac2"), 7, 8)}
V["cherry"] = {"whole": p(cherry("#a3243a", "#d4556b", "#5f8f45"), 12, 4)}
V["coconut"] = {"flakes": garnish(flake("#fbf9f4", "#e6e0d4"), 9, 6)}
V["cranberry"] = {"berries": p(berry("#b3202c", "#e46a70"), 7, 7), "dried": garnish(chunk("#8a1a24", "#b8404a"), 7, 8)}
V["dates"] = {"chopped": p(chunk("#7a4a2a", "#a0683f"), 8, 6)}
V["dragon-fruit"] = {"cubes": p('<rect x="2.5" y="2.5" width="11" height="11" rx="2.4" fill="#f2eee6"/>' + "".join(f'<circle cx="{x}" cy="{y}" r="0.4" fill="#2a2228"/>' for x, y in ((4.5, 5), (6.4, 4.2), (8.6, 5.4), (10.8, 4.4), (12, 6.6), (5.2, 7.4), (7.6, 7.2), (10, 8), (4.2, 9.8), (6.6, 9.6), (8.8, 10.2), (11.6, 10.4), (5.6, 12), (8, 12.2), (10.4, 12))), 10, 7)}
V["fig"] = {"quarters": p(fig_quarter("#6b3a5a", "#f2e2c4", "#d9506a", "#f6d6a8"), 13, 4)}
V["grape"] = {"halves": p(grape_half("#6b3a7a", "#dde6b0", "#c4d08a"), 11, 7), "whole": p(berry("#6b3a7a", "#9a6aa8"), 11, 6)}
V["grapefruit"] = {"segments": p(citrus_wedge("#f0a07a", "#fbe6d6", "#e8695f"), 17, 4)}
V["guava"] = {"slices": p(round_slice("#9cc25a", "#f0727a", seeds="#f4e6c4"), 13, 4)}
V["jackfruit"] = {"pods": p(teardrop("#f2c23a", "#f8dc7a"), 12, 5)}
V["kiwi"] = {"slices": p('<circle cx="8" cy="8" r="7" fill="#8a6a3a"/><circle cx="8" cy="8" r="6.2" fill="#7fb03a"/><circle cx="8" cy="8" r="2.2" fill="#eef3d6"/>' + "".join(f'<circle cx="{f(8 + 3.2 * math.cos(math.tau * i / 10))}" cy="{f(8 + 3.2 * math.sin(math.tau * i / 10))}" r="0.5" fill="#2a2a2a"/>' for i in range(10)), 13, 4)}
V["kumquat"] = {"slices": p(citrus_wheel("#f29a1f", "#fbe6c8", "#f7b24a"), 10, 5)}
V["lemon"] = {"wedges": p(citrus_wedge("#f1c21b", "#fbf2cc", "#f6dc5c"), 17, 3), "wheels": p(citrus_wheel("#f1c21b", "#fbf2cc", "#f6dc5c"), 13, 3), "zest": garnish(shreds("#f1c21b"), 8, 4)}
V["lime"] = {"wedges": p(citrus_wedge("#5f9a45", "#e8efcf", "#a8cf6f"), 17, 3), "wheels": p(citrus_wheel("#5f9a45", "#e8efcf", "#a8cf6f"), 13, 3)}
V["lychee"] = {"halves": p('<ellipse cx="8" cy="8" rx="6.4" ry="5.8" fill="#eeddd6"/><ellipse cx="8" cy="8" rx="5.4" ry="4.8" fill="#f6f2ea"/><ellipse cx="8.4" cy="8.4" rx="1.8" ry="2.2" fill="#ddd0b8"/><ellipse cx="5.8" cy="5.8" rx="1.8" ry="0.9" fill="#ffffff" opacity="0.7"/>', 11, 6)}
V["mandarin"] = {"segments": p(segment("#f59a2a", "#ffc46a"), 14, 5)}
V["mango"] = {"cubes": p(dice("#f6a63a", "#fbc46a"), 10, 7), "slices": p('<path d="M1.5 9.5C1.5 6 5 4 9 4s5.5 1 5.5 3-2 5-6.5 5S1.5 12 1.5 9.5Z" fill="#f6aa30"/><path d="M4 8.6c2.6-1.6 5.4-2.4 8.4-2.4" stroke="#fcd070" stroke-width="1" fill="none" stroke-linecap="round"/>', 16, 4)}
V["melon"] = {"cubes": p(dice("#c9dc8a", "#e2edb8"), 11, 6)}
V["nashi-pear"] = {"slices": p(crescent("#d9b25a", "#fbf6e2"), 14, 5)}
V["orange"] = {"segments": p(citrus_wedge("#f08a2b", "#fbe6c8", "#f7a64a"), 17, 4), "wheels": p(citrus_wheel("#f08a2b", "#fbe6c8", "#f7a64a"), 13, 3)}
V["papaya"] = {"cubes": p(dice("#f28a3a", "#f7b170"), 10, 7), "slices": p(crescent("#8fb24a", "#f28a3a"), 15, 4)}
V["passion-fruit"] = {"pulp": garnish(pulp("#f4b41a", "#fde08a", "#2a1a1a"), 12, 4)}
V["peach"] = {"slices": p(crescent("#e86a4a", "#f8c47a"), 14, 5)}
V["pear"] = {"slices": p(crescent("#b9c45a", "#f6f0d0"), 14, 5)}
V["persimmon"] = {"wedges": p(thick_wedge("#d9601f", "#f59a3c", "#fbbf6e"), 14, 4)}
V["pineapple"] = {"chunks": p(tidbit("#f2c240", "#f8e08a"), 11, 6), "rings": p(ring("#f2c84a", "#f8e08a", 3.4), 15, 3)}
V["plantain"] = {"fried": p(coin("#b8661f", "#e8a64a"), 12, 6)}
V["plum"] = {"slices": p(crescent("#6b2a4a", "#e8a05a"), 13, 5)}
V["pomegranate"] = {"seeds": garnish(arils("#b8243a", "#f29aa6"), 11, 5)}
V["raspberry"] = {"berries": p(cluster("#c8203f", "#ef7090", 2.5), 10, 6)}
V["rhubarb"] = {"chopped": p(rhubarb_piece("#c8304a", "#e2667a", "#dfe4b0"), 11, 6)}
V["strawberry"] = {"halves": p(heart_half("#d9364a", "#f6a6a6", "#f6e08a"), 13, 5)}
V["sudachi"] = {"wheels": p(citrus_wheel("#5f9e3a", "#f2f2d6", "#d6e48a"), 12, 3), "wedges": p(citrus_wedge("#5f9e3a", "#f2f2d6", "#d6e48a"), 15, 3)}
V["watermelon"] = {"cubes": p(dice("#e8505f", "#f6808a") + '<ellipse cx="10" cy="10" rx="0.9" ry="0.6" fill="#2a2a2a"/>', 11, 6)}
V["yuzu"] = {"zest": garnish(shreds("#f1c21b", "#f6dc5c"), 8, 4), "wheels": p(citrus_wheel("#e8b81b", "#fbf2cc", "#f6dc5c"), 12, 3)}

# Meat --------------------------------------------------------------------------------------

V["bacon"] = {"rashers": whole(p(bacon("#b9503f", "#f2d6c4"), 17, 3), 4), "lardons": p(cube("#c9604f", "#f2d6c4", "#f6e6d6"), 9, 7), "bits": garnish(crumble("#a8402f", "#d9705f"), 7, 8)}
V["beef"] = {"slices": p('<path d="M1 6.4c2-1.4 3.4.2 5.4-.8s4-1.8 6-.8c1.6.8 2.6 2.2 2.2 3.6-.4 1.6.2 2.4-1 3.4-2 1.4-3.6.2-5.6 1s-4 .6-5.4-.6C1.2 11 1.8 9.8 1.4 8.6 1 7.8.8 7 1 6.4Z" fill="#7a4232"/><path d="M3 8.6c2.4-.6 4.6-.4 6.8.4" stroke="#5c2e22" stroke-width="1" fill="none" stroke-linecap="round"/><path d="M4 6.8c1.6-.6 3.2-.8 4.6-.6M6.4 11c1.8-.2 3.6-.2 5.2.4" stroke="#b98a72" stroke-width="0.8" fill="none" stroke-linecap="round"/>', 15, 5), "steak": center(steak_slices("#3f1f15", "#d4707a", "#6a3424"), 46), "cubes": p(chunk("#6f3a2a", "#9a5a42"), 12, 5)}
V["chicken"] = {"pieces": p(chunk("#d4975a", "#ecc184"), 12, 5), "cutlet": center(sliced_fan("#f6e6c8", "#c98a4b", "#d9963f"), 40), "grilled": center(fillet("#d9a56a", "#b9783f", "#c98a4b") + '<path d="M4 6l8 4M3.5 9.5l7 3.5" stroke="#8a5a2a" stroke-width="1" stroke-linecap="round"/>', 50)}
V["chorizo"] = {"coins": p(coin("#b8401f", "#d9602f", "#f2b48a"), 11, 6), "diced": p(dice("#a8302a", "#d9604a"), 8, 8)}
V["corned-beef"] = {"chunks": p(crumble("#c86a68", "#eba2a0"), 11, 6)}
V["duck"] = {"slices": p(roast_slice("#7a3a1e", "#c4626a", "#f2dcc4"), 15, 5)}
V["guanciale"] = {"cubes": p('<rect x="3" y="3" width="10" height="10" rx="2.5" fill="#b8574a"/><rect x="3" y="3" width="10" height="4" rx="1.8" fill="#f0d6a8"/><path d="M4.5 10.5h5" stroke="#d98060" stroke-width="1" stroke-linecap="round"/>', 11, 7)}
V["ham"] = {"diced": p(dice("#e89a9a", "#f6c4c4"), 9, 7), "strips": p(strip("#e89a9a", "#f6c4c4"), 13, 5), "slices": p(coin("#e2908f", "#f2b0ae"), 15, 3)}
V["lamb"] = {"chunks": p(chunk("#8a4a32", "#b06a4a"), 12, 5), "slices": p(roast_slice("#7a4530", "#c46e6a", "#f2e2cf"), 17, 4)}
V["liver"] = {"slices": p('<path d="M1.5 8.5c.5-3 3-5 6.5-5 2.5 0 3.5 1 5 .8 1.4.4 1.8 2 1.2 3.4-.6 1.6-.4 2.8-1.6 3.8-1.6 1.4-4 1.8-6.6 1.6-3-.2-4.8-2-4.5-4.6Z" fill="#7a3a2c"/><ellipse cx="6.4" cy="6.6" rx="2.6" ry="1.1" fill="#ffffff" opacity="0.22" transform="rotate(-12 6.4 6.6)"/>', 15, 5)}
V["luncheon-meat"] = {"slices": p('<rect x="1.5" y="4" width="13" height="8" rx="1.5" fill="#d98a7a"/><rect x="2.5" y="5" width="11" height="6" rx="1" fill="#eaa898"/><path d="M4 7h4" stroke="#f6c8b8" stroke-width="1" stroke-linecap="round"/>', 15, 3), "cubes": p(dice("#d98a7a", "#eaa898"), 10, 6)}
V["minced-meat"] = {"crumbled": p(mince("#8a5040", "#b07a5a"), 10, 7), "sauce": fl(lambda r: smooth(r, "#9a4a32", "#b8604a", specks="#6f3a22"), SAUCE)}
V["pancetta"] = {"cubes": p('<rect x="3" y="3" width="10" height="10" rx="2.5" fill="#d98a7a"/><rect x="3" y="3" width="10" height="3.4" rx="1.7" fill="#f6eedf"/>', 10, 7)}
V["pork"] = {"strips": p('<rect x="1" y="5" width="14" height="6" rx="3" fill="#c9805f"/><rect x="1" y="5" width="14" height="2.2" rx="1.1" fill="#f2ede0"/>', 14, 4), "slices": p(roast_slice("#9a5a30", "#e2b48e", "#f6ead8"), 15, 5), "cutlet": center(sliced_fan("#f6ead8", "#d9a05a", "#c98a3f"), 40), "simmered": fl(lambda r: covering_slices(r, '<path d="M1 6c4-2 10-2 14 0 1 2.4 1 5.4 0 7-4 2-10 2-14 0-1-1.6-1-4.6 0-7Z" fill="#b87650"/><path d="M1.6 7.2c4-1.4 9-1.4 12.8 0" stroke="#e8d3b8" stroke-width="1.4" fill="none" stroke-linecap="round"/>', 30), ANY, covers=True)}
V["prosciutto"] = {"ribbons": p(draped("#d0646e", "#f8ece6", "#a84a56"), 16, 4)}
V["salami"] = {"coins": p(coin("#7a2432", "#a83e4c", "#f6ece4"), 12, 5)}
V["sausage"] = {"links": whole(p(link("#a8603f", "#c98a5f"), 15, 3), 4), "coins": p(coin("#9a5a3a", "#d4a088"), 11, 6)}
V["turkey"] = {"slices": p(roast_slice("#c99a62", "#f0e2c8", "#e6d2ae"), 18, 4)}
V["veal"] = {"cutlet": center(sliced_fan("#f2e6d0", "#c9904b", "#d9a04f"), 40)}

V["chicken-thigh"] = {"pieces": V["chicken"]["pieces"], "grilled": V["chicken"]["grilled"], "cutlet": V["chicken"]["cutlet"]}
V["chicken-wings"] = {"wings": whole(p(wing("#c4742e", "#e6a865"), 17, 3), 6)}
V["lap-cheong"] = {"slices": p('<ellipse cx="8" cy="8" rx="7" ry="4.4" fill="#8e2224"/><ellipse cx="8" cy="8" rx="6" ry="3.5" fill="#b8342e"/>' + "".join(f'<circle cx="{x}" cy="{y}" r="0.8" fill="#f6dccd"/>' for x, y in ((4.6, 7.4), (7, 9.4), (8.6, 6.6), (10.8, 8.8), (12, 7))), 12, 6)}
V["pork-belly"] = {"slices": p('<rect x="1" y="4" width="14" height="8" rx="2" fill="#c97a58"/><rect x="1" y="4" width="14" height="2.2" rx="1.1" fill="#f6e6cc"/><rect x="1" y="7.6" width="14" height="1.4" fill="#f6e6cc"/>', 14, 4), "simmered": V["pork"]["simmered"]}
V["spare-ribs"] = {"ribs": whole(p('<rect x="11" y="4.4" width="4.4" height="2.6" rx="1.3" fill="#efe4cc"/><rect x="11" y="9" width="4.4" height="2.6" rx="1.3" fill="#efe4cc"/><path d="M2 4.4C5 3 9 3 12.4 3.8c.8 2.6.8 5.8 0 8.4C9 13 5 13 2 11.6 1 9.4 1 6.6 2 4.4Z" fill="#8a3a1e"/><path d="M2 8h10.4" stroke="#5a2412" stroke-width="0.8" stroke-linecap="round"/><path d="M3.6 5.6c2.4-.8 5-.8 7.2-.3M3.6 9.8c2.4-.6 5-.6 7.2-.2" stroke="#c4623a" stroke-width="1" fill="none" stroke-linecap="round"/>', 16, 3), 4)}
V["steak"] = {"steak": V["beef"]["steak"], "slices": p(steak_strip("#5a2a1a", "#a06456", "#d4707a"), 15, 5)}

# Seafood -----------------------------------------------------------------------------------

V["abalone"] = {"slices": p('<ellipse cx="8" cy="8" rx="7" ry="5.4" fill="#5a5844"/><ellipse cx="8" cy="8" rx="6" ry="4.5" fill="#e9dfc4"/><ellipse cx="6.6" cy="6.8" rx="2.6" ry="1.3" fill="#ffffff" opacity="0.35"/>', 13, 4)}
V["anchovies"] = {"fillets": p('<path d="M1 8.8C3 6.2 9 5.4 15 7 9.8 10.4 3.6 11 1 8.8Z" fill="#8a4e3c"/><path d="M3 8.5c3-.8 6.5-1 9.6-.8" stroke="#c08a76" stroke-width="0.8" fill="none" stroke-linecap="round"/>', 13, 4)}
V["chikuwa"] = {"rings": p('<circle cx="8" cy="8" r="4.3" fill="none" stroke="#f6eedb" stroke-width="3.4"/><circle cx="8" cy="8" r="6.4" fill="none" stroke="#c07a3a" stroke-width="1.4"/>', 11, 6)}
V["clams"] = {"shells": p(clam("#d9cbb4", "#f2d6b0", "#b8a688"), 13, 5)}
V["cod"] = {"fillet": center(fillet("#f8f4ea", "#e6dfcc", "#c9c4b8"), 50)}
V["crab"] = {"flaked": p(crab_meat("#f8efe6", "#e8735f", "#e6d8c8"), 12, 6)}
V["crab-sticks"] = {"sticks": p(crab_stick("#e04a3a", "#fbf6ee"), 14, 4), "shredded": p(shreds("#fbf6ee", "#e04a3a"), 11, 6)}
V["dried-shrimp"] = {"sprinkle": garnish(shrimp("#e07a4f", "#f4b08a"), 8, 6)}
V["eel"] = {"glazed": center('<path d="M1.5 4.5c4-1 9-1 13 0 .7 2.3.7 4.7 0 7-4 1-9 1-13 0-.7-2.3-.7-4.7 0-7Z" fill="#6e3414"/><path d="M2.6 5.4c3.6-.8 7.2-.8 10.8 0 .5 1.8.5 3.4 0 5.2-3.6.8-7.2.8-10.8 0-.5-1.8-.5-3.4 0-5.2Z" fill="#a0561f"/><path d="M4 6.5l1.4 3M7.3 6.2l1.4 3.6M10.6 6.5l1.4 3" stroke="#5a2a0e" stroke-width="0.8" stroke-linecap="round"/><ellipse cx="6.4" cy="6.4" rx="2.8" ry="0.6" fill="#ffffff" opacity="0.35"/>', 44)}
V["fish"] = {"fillet": center(fillet("#f6efe2", "#e2d6c0", "#b8b0a0"), 50)}
V["lobster"] = {"chunks": p('<path d="M2 7.5C2.5 4 5.5 2 9 2.4c3.4.4 5.4 3 5 6.2-.4 3.4-3.2 5.4-6.6 5.2C4 13.6 1.6 11 2 7.5Z" fill="#f8ece2"/><path d="M2 7.5C2.5 4 5.5 2 9 2.4c3.4.4 5.4 3 5 6.2-1-2.2-3-3.6-5.6-3.8C5.8 4.6 3.6 5.6 2 7.5Z" fill="#e0402f"/><path d="M4.6 9.6c1.6-1.2 3.6-1.6 5.8-1.2M5.6 11.8c1.2-.6 2.6-.8 4-.6" stroke="#f39a80" stroke-width="0.9" fill="none" stroke-linecap="round"/>', 14, 5)}
V["mackerel"] = {"fillet": center(mackerel_skin(), 50)}
V["mentaiko"] = {"dollop": center(dollop("#e2566a", "#f39aa4") + "".join(f'<circle cx="{x}" cy="{y}" r="0.6" fill="#f8b4ba"/>' for x, y in ((5, 10), (7.5, 11.5), (9, 9.5), (11, 11), (10.5, 6.5), (4.5, 7), (8, 5))), 20)}
V["mussels"] = {"shells": p(mussel("#2f3440", "#f2a65a"), 14, 5)}
V["octopus"] = {"slices": p(octopus("#c45a6a", "#f6e6e0", "#e8a0a8"), 12, 5)}
V["oyster"] = {"shells": p(clam("#b8b4aa", "#e8e2d0", "#8a8678"), 15, 4)}
V["salmon"] = {"fillet": center(fillet("#f6906a", "#fbc4a8", "#b8b0a8"), 50), "sashimi": p(sashimi("#f6906a", "#fbc8ae"), 14, 4), "flaked": p(crumble("#f6a080", "#fbc4a8"), 9, 7)}
V["salmon-roe"] = {"roe": p(roe("#ef5a1c", "#ffe2c4"), 12, 4)}
V["sardines"] = {"fillets": whole(p(small_fillet("#b4c2d0", "#3f6488", "#e8eef4"), 15, 3), 4)}
V["scallops"] = {"seared": p(scallop("#f6ead8", "#d9a05a"), 13, 4)}
V["sea-urchin"] = {"lobes": p(uni_lobe("#f2a83a", "#ffd47e", "#d9861e"), 13, 4)}
V["seafood"] = {"shrimp": p(shrimp("#fa7368", "#ffb0a4"), 15, 3), "squid": p(ring("#f6ecdf", "#fbf7f0", 2.6), 11, 3)}
V["shirasu"] = {"sprinkle": garnish(squiggles("#f2ead8", "#3a3a3a"), 15, 3)}
V["shrimp"] = {"whole": p(shrimp("#fa7368", "#ffb0a4"), 15, 4)}
V["smoked-salmon"] = {"slices": p('<path d="M1.5 6C5 3.5 11 3.5 14.5 6c.8 1.6.8 3.6 0 5-3.5 2.5-9.5 2.5-13 0-.8-1.6-.8-3.4 0-5Z" fill="#ee7a52"/><path d="M4.2 4.6C3.2 7 3.2 9.6 4 12.2M7.4 4C6.6 7 6.6 10 7.2 13M10.6 4.1C10 7 10 10 10.4 12.9M13.2 5C12.8 7.4 12.8 9.8 13.2 12" stroke="#f8b898" stroke-width="0.5" fill="none" stroke-linecap="round"/>', 15, 4)}
V["squid"] = {"rings": p('<circle cx="8" cy="8" r="5.2" fill="none" stroke="#f6ecdf" stroke-width="3"/><circle cx="8" cy="8" r="4" fill="none" stroke="#e4d2bd" stroke-width="0.6"/>', 11, 6)}
V["tuna"] = {"sashimi": p(sashimi("#c02e42", "#e0606e"), 15, 4), "cubes": p(dice("#c8374a", "#e0606e"), 10, 7), "flaked": p(crumble("#d9bc9c", "#efdcc4"), 11, 7)}
V["yellowtail"] = {"sashimi": p(sashimi("#f4d6c6", "#fbe8de", skin="#d46a6e"), 15, 4)}

# A fish is drawn the way it is served, so the whole fish and its cut share their parts.
V["bonito"] = {"sashimi": p(sashimi("#8f2232", "#b44a58", skin="#9aa2ac"), 15, 4)}
V["bonito-fillet"] = V["bonito"]
V["canned-tuna"] = {"flaked": p(crumble("#d9b88e", "#f0dcc0"), 10, 7)}
V["cod-fillet"] = V["cod"]
V["flounder"] = {"fillet": center(fillet("#f8f4ec", "#e8e0d0", "#8a6b47"), 50)}
V["flounder-fillet"] = V["flounder"]
V["grilled-eel"] = V["eel"]
V["herring"] = {"fillets": whole(p(oily_fillet("#3f6b78", "#dfe6ea", "#9ab8c0"), 18, 3), 4)}
V["horse-mackerel"] = {"fillets": whole(p(oily_fillet("#5a7486", "#ece8d4", "#c9b98a"), 18, 3), 4)}
V["mackerel-fillet"] = V["mackerel"]
V["salmon-fillet"] = V["salmon"]
V["saury"] = {"grilled": whole(p(long_fish("#c3cbd4", "#2c3f63", "#8a6a4a", "#f0e6d0"), 22, 2), 3)}
V["sea-bass"] = {"fillet": center(fillet("#f6f1e8", "#e6ddcd", "#6b7782"), 50)}
V["sea-bass-fillet"] = V["sea-bass"]
V["sea-bream"] = {"fillet": center(fillet("#f6efe4", "#e8dccb", "#e06872"), 50), "sashimi": p(sashimi("#f7ece6", "#efd8ce", "#e06872"), 14, 4)}
V["sea-bream-fillet"] = V["sea-bream"]
V["swordfish"] = {"steak": center(fillet("#efdfca", "#d9bf9e", "#4a4a5a") + '<path d="M4.5 11.5 9 4.5M7.5 12.5 12 5.5" stroke="#9a6a3e" stroke-width="1" stroke-linecap="round" opacity="0.8"/>', 50)}
V["swordfish-steak"] = V["swordfish"]
V["trout"] = {"fillet": center(fillet("#f2a08e", "#fbd2c2", "#8a8a6e"), 50)}
V["trout-fillet"] = V["trout"]
V["tuna-steak"] = {"sashimi": V["tuna"]["sashimi"], "cubes": V["tuna"]["cubes"]}
V["yellowtail-fillet"] = V["yellowtail"]

V["ayu"] = {"grilled": whole(p(whole_fish("#6f7a5a", "#e6e2d0", "#e8c23a"), 24, 2), 3)}
V["dried-scallops"] = {"shredded": garnish(shreds("#d9963f", "#e8b060"), 9, 5)}
V["hokke"] = {"grilled": center(fillet("#ecd09a", "#c99a5e", "#6b6656") + '<circle cx="6" cy="9" r="1.1" fill="#8a5a2a" opacity="0.5"/><circle cx="10.5" cy="7" r="0.9" fill="#8a5a2a" opacity="0.5"/>', 50)}
V["shishamo"] = {"grilled": whole(p(small_fish("#7a705e", "#d9b36a", "#5a3a22"), 16, 3), 4)}

# Dairy and eggs ----------------------------------------------------------------------------

V["blue-cheese"] = {"crumbled": p('<path d="M3 7 6 3.5l4 1 3 3-1 4.5-4.5 2-4-1.5Z" fill="#efe8d2"/><path d="M5 6.4l1.2 1 1.4-.4M8.6 10.2l1.2-1.2 1.2.6M4.6 10.6l1.4-.2" stroke="#4f6f8a" stroke-width="0.8" fill="none" stroke-linecap="round"/><circle cx="10" cy="6.4" r="0.6" fill="#4f6f8a"/><circle cx="7.4" cy="12" r="0.5" fill="#4f6f8a"/>', 11, 6)}
V["burrata"] = {"whole": center('<circle cx="8" cy="8" r="7" fill="#f8f6ef"/><path d="M5 8c1-3 5-3 6 0s-2 4-3 3-3 0-3-3Z" fill="#fbf2d8"/><circle cx="6" cy="5.5" r="1.4" fill="#ffffff"/>', 34)}
V["butter"] = {"pat": center('<rect x="2" y="2" width="12" height="12" rx="2.5" fill="#f1c21b"/><rect x="3.5" y="3.5" width="9" height="8" rx="2" fill="#ffe97a"/>', 24)}
V["cheddar"] = {"grated": garnish(shreds("#f2a63a", "#f8c46a"), 9, 6), "melted": fl(lambda r: melted(r, "#f6b84a", "#fbd88a", "#d98a2a"), ANY, covers=True)}
V["cheese"] = {"grated": garnish(shreds("#f6dc7a", "#fbe9a8"), 9, 6), "melted": fl(lambda r: melted(r, "#f8d86a", "#fbeaa0", "#e0a83a"), ANY, covers=True), "slice": center('<rect x="2" y="2" width="12" height="12" rx="1" fill="#f6d45a"/><circle cx="6" cy="6" r="1.2" fill="#e8c040"/><circle cx="10.5" cy="9.5" r="1" fill="#e8c040"/>', 26)}
V["condensed-milk"] = {"drizzle": center(drizzle("#f6ecd6", 2.2), 24, 2)}
V["cream"] = {"swirl": center(cream_swirl("#fbf9f4"), 26), "sauce": fl(lambda r: smooth(r, "#f6efdc", "#fbf9f0"), SAUCE)}
V["cream-cheese"] = {"dollop": center(dollop("#f8f6ef", "#e6e0d4"), 22)}
V["creme-fraiche"] = {"dollop": center(dollop("#fbf8ef", "#e8e0cc"), 22)}
V["egg"] = {"fried": whole(center(egg_fried(), 42), 2), "scrambled": p(scrambled_curd("#f7dc6a", "#fbeba6", "#e6c043"), 15, 6), "boiled": whole(center(egg_half("#fbf9f4", "#f1c21b", "#ffe97a"), 24, 2), 3), "yolk": whole(center(yolk("#f6b21b", "#ffd86a"), 22), 2), "omelette": fl(lambda r: omelette(r, "#f6d55c", "#ffe97a", "#e8bc3a"), PLATES)}
V["feta"] = {"crumbled": p(cube("#fbfaf4", "#ffffff", "#e6e0d0"), 8, 8)}
V["goat-cheese"] = {"crumbled": p(crumble("#fbfaf6", "#e6e2d6"), 9, 6)}
V["gruyere"] = {"grated": garnish(shreds("#f2dc9a", "#f8ecc4"), 9, 6), "melted": fl(lambda r: melted(r, "#f2d48a", "#f8e8b8", "#c98a3a"), ANY, covers=True)}
V["halloumi"] = {"grilled": p('<rect x="1.5" y="3" width="13" height="10" rx="2" fill="#f4ecd6"/><path d="M4 4l-1.5 8M8 4l-1.5 8M12 4l-1.5 8" stroke="#a8743a" stroke-width="1.2" stroke-linecap="round"/>', 15, 3)}
V["mascarpone"] = {"dollop": center(dollop("#fbf6e6", "#ece2c8"), 22)}
V["mozzarella"] = {"slices": p(round_slice("#f6f2e6", "#fbfaf4"), 14, 4), "torn": p(crumble("#fbfaf4", "#ece6d8"), 12, 5), "melted": fl(lambda r: melted(r, "#fbf6e0", "#ffffff", "#e8c88a"), ANY, covers=True)}
V["paneer"] = {"cubes": p(cube("#f8f2e0", "#ffffff", "#d9a85c"), 10, 7)}
V["parmesan"] = {"grated": garnish(shred("#fbf2d0", 2), 8, 8), "shaved": p(shaving("#f0d98e", "#fbf0c8", "#d9bd6a"), 12, 5)}
V["pecorino"] = {"grated": garnish('<path d="M4 9c3-3 6-3 8-1" stroke="#fdf6dc" stroke-width="2" fill="none" stroke-linecap="round"/>', 9, 8), "shaved": p(shaving("#f6eccc", "#fffbee", "#e2d4a8"), 12, 5)}
V["ricotta"] = {"dollop": center('<path d="M2.5 9c0-4 3-6.5 5.5-6.5S13.5 5 13.5 9 11 13.5 8 13.5 2.5 12.5 2.5 9Z" fill="#fbfaf4"/>' + "".join(f'<circle cx="{x}" cy="{y}" r="0.8" fill="#e4dfd0"/>' for x, y in ((5.4, 5.6), (9.6, 4.6), (11.6, 7.6), (4, 9.4), (7.8, 8.4), (10.4, 11.2), (6.2, 11.8))), 22)}
V["sour-cream"] = {"dollop": center(cream_swirl("#fbfaf6"), 24)}
V["yogurt"] = {"dollop": center(puddle("#fbfaf6", "#ffffff"), 24), "bowl": fl(lambda r: smooth(r, "#fbfaf6", "#ffffff", full=True, ridges="#ece8de"), BOWLS)}

V["brie"] = {"slices": p(brie_slice("#faf7ee", "#f4dc96"), 14, 4)}
V["cottage-cheese"] = {"dollop": center(curds("#fbfaf4", "#ffffff", "#ece6d6"), 24)}
V["gouda"] = {"grated": garnish(shreds("#f6d06a", "#fbe29a"), 9, 6), "melted": fl(lambda r: melted(r, "#f6c85a", "#fbe29a", "#d9a03a"), ANY, covers=True)}
V["queso-fresco"] = {"crumbled": p(crumble("#fbfaf4", "#e6e0d0"), 9, 7)}

# Grains, noodles, and bread ----------------------------------------------------------------

V["arborio-rice"] = {"risotto": fl(lambda r: grains_in(r, "#f2e6c4", "#e2d2a0", 60, 2.6, 1.5, shape="full"), PLATES + BOWLS + ["pan"])}
V["barley"] = {"mound": fl(lambda r: grains_in(r, "#e2cfa0", "#c9b07a", 80, 1.8, 1.4), MOUND), "bowl": fl(lambda r: grains_in(r, "#e2cfa0", "#c9b07a", 90, 1.8, 1.4, shape="full"), BOWLS)}
V["bread"] = {"toast": fl(lambda r: slice_of_bread("#ecc078", "#b8874a", extra='<path d="M-14 -12h28v26h-28Z" fill="#f3d38e" opacity="0.6"/>'), FLAT), "french-toast": fl(lambda r: slice_of_bread("#d99a4a", "#9c6430", 2, '<path d="M-12 -10c6 4 14-2 22 2M-14 4c8 3 14-3 24 1" stroke="#b97a35" stroke-width="3" fill="none" stroke-linecap="round"/>'), FLAT), "slice": fl(lambda r: slice_of_bread("#f3dfae", "#c9a15f"), FLAT), "croutons": p(cube("#e8b860", "#f6d88a", "#c98a3a"), 9, 7)}
V["breadcrumbs"] = {"toasted": garnish(dust("#c98a3a", "#e8b860"), 10, 4)}
V["couscous"] = {"mound": fl(lambda r: grains_in(r, "#f2dc9a", "#e2c47a", 120, 1, 0.9), MOUND), "bowl": fl(lambda r: grains_in(r, "#f2dc9a", "#e2c47a", 140, 1, 0.9, shape="full"), BOWLS)}
V["egg-noodles"] = {"swirl": fl(lambda r: noodles(r, "#f2c85a", "#f8dc8a", "#e8b84a", 2.2), ANY), "broth": fl(lambda r: noodles(r, "#f2c85a", "#f8dc8a", "#e8b84a", 2.2, broth="#e8c48a"), BOWLS)}
V["fettuccine"] = {"swirl": fl(lambda r: noodles(r, "#f2d68a", "#fbeab5", "#e8c46e", 4, 18), PLATES + ["pan"])}
V["fusilli"] = {"pasta": fl(lambda r: tiled(r, spiral("#f2d27a", "#fbe6a8"), 17, 14, base="#e2b85a"), PLATES + BOWLS + ["pan"])}
V["glutinous-rice"] = {"mound": fl(lambda r: grains_in(r, "#fbf9f4", "#ece6da", 60, 2.6, 1.6), MOUND), "bowl": fl(lambda r: grains_in(r, "#fbf9f4", "#ece6da", 70, 2.6, 1.6, shape="full"), BOWLS)}
V["gnocchi"] = {"pasta": fl(lambda r: tiled(r, pillow("#f2dca0", "#d9b46a"), 16, 13, base="#e2c47a"), PLATES + ["pan"]), "pieces": p(pillow("#f2dca0", "#e2c47a"), 12, 6)}
V["gyoza-wrappers"] = {"dumplings": fl(lambda r: row_of(r, dumpling("#f6ecd6", "#d9c8a8", "#c98a3a"), 26, 3), PLATES + ["pan"]), "pieces": p(dumpling("#f6ecd6", "#d9c8a8", "#c98a3a"), 16, 4)}
V["harusame"] = {"noodles": fl(lambda r: noodles(r, "#c4d0d2", "#ffffff", "#e2e9ea", 1.6, 40), ANY)}
V["lasagna"] = {"square": fl(lasagna_top, PLATES + ["pan"])}
V["macaroni"] = {"pasta": fl(lambda r: tiled(r, elbow("#f6d36a", "#fbe6a8"), 15, 16, base="#e8b84a"), PLATES + BOWLS + ["pan"])}
V["mochi"] = {"pieces": p(mochi("#fbfaf6", "#ffffff"), 13, 4)}
V["noodles"] = {"swirl": fl(lambda r: noodles(r, "#f2d68a", "#fbeab5", "#e8c46e", 2.4), ANY), "broth": fl(lambda r: noodles(r, "#f2d68a", "#fbeab5", "#e8c46e", 2.4, broth="#d9a86a"), BOWLS)}
V["oats"] = {"porridge": fl(lambda r: grains_in(r, "#efe2c4", "#dcc89c", 60, 2.2, 1.6, shape="full"), BOWLS)}
V["orzo"] = {"pasta": fl(lambda r: grains_in(r, "#f2dc9a", "#e2c47a", 90, 2, 1.1), PLATES + BOWLS + ["pan"])}
V["panko"] = {"crumbs": garnish(dust("#e8c47a", "#f6dca0"), 10, 4)}
V["pasta"] = {"pasta": fl(lambda r: tiled(r, tube("#f2d27a", "#d9a84a"), 18, 13, base="#e2b85a"), PLATES + BOWLS + ["pan"])}
V["penne"] = {"pasta": fl(lambda r: tiled(r, quill("#f2d27a", "#d9a84a"), 18, 13, base="#e2b85a"), PLATES + BOWLS + ["pan"])}
V["pita"] = {"bread": fl(lambda r: flatbread(r, "#f2d8a0", "#d9a85c", "#e2bc7a", oval=True), FLAT), "wedges": p(triangle("#e8c47a", "#f6dca0"), 14, 4)}
V["polenta"] = {"soft": fl(lambda r: smooth(r, "#f6cf5a", "#fbe08a"), PLATES + BOWLS)}
V["quinoa"] = {"mound": fl(lambda r: grains_in(r, "#efe2c4", "#c9a888", 140, 1.1, 1), MOUND), "bowl": fl(lambda r: grains_in(r, "#efe2c4", "#c9a888", 150, 1.1, 1, shape="full"), BOWLS)}
V["ramen"] = {"broth": fl(lambda r: noodles(r, "#f2d27a", "#fbe6a8", "#e8c46e", 2, 30, broth="#e2b878"), BOWLS), "swirl": fl(lambda r: noodles(r, "#f2d27a", "#fbe6a8", "#e8c46e", 2, 30), PLATES + ["pan"])}
V["ravioli"] = {"pasta": fl(lambda r: tiled(r, ravioli("#f6dc8a", "#fbecbc", "#e8c46e"), 15, 10), PLATES + BOWLS + ["pan"]), "pieces": p(ravioli("#f6dc8a", "#fbecbc", "#e8c46e"), 14, 4)}
V["rice"] = {"mound": fl(lambda r: grains_in(r, "#fbf8f0", "#ebe5d6", 48), MOUND), "bowl": fl(lambda r: grains_in(r, "#fbf8f0", "#ebe5d6", 60, shape="full"), BOWLS), "fried": fl(lambda r: grains_in(r, "#f2d796", "#e0bb6c", 48), MOUND + BOWLS), "red-fried": fl(lambda r: grains_in(r, "#e8946b", "#d0704b", 48), MOUND + BOWLS)}
V["rice-noodles"] = {"swirl": fl(lambda r: noodles(r, "#f6f2e6", "#ffffff", "#e6e0d0", 3.4, 22), ANY), "broth": fl(lambda r: noodles(r, "#f6f2e6", "#ffffff", "#e6e0d0", 3.4, 22, broth="#e8d9b0"), BOWLS)}
V["rice-paper"] = {"rolls": fl(lambda r: spring_rolls(r, "#f4efe4", "#ffffff", "#ef7a62", "#5f9a45"), FLAT)}
V["rigatoni"] = {"pasta": fl(lambda r: tiled(r, tube("#f2d27a", "#d9a84a", True), 20, 10, base="#e2b85a"), PLATES + BOWLS + ["pan"])}
V["soba"] = {"swirl": fl(lambda r: noodles(r, "#9a8a72", "#b8a88e", "#857560", 1.6, 34), PLATES + BOWLS), "broth": fl(lambda r: noodles(r, "#9a8a72", "#b8a88e", "#857560", 1.6, 34, broth="#9a6a3a"), BOWLS)}
V["somen"] = {"swirl": fl(lambda r: noodles(r, "#fbf9f2", "#ffffff", "#ece8dc", 1.2, 40), PLATES + BOWLS)}
V["spaghetti"] = {"plain": fl(lambda r: noodles(r, "#efd281", "#fbeab5", "#e8c46e"), PLATES + ["pan"]), "creamy": fl(lambda r: noodles(r, "#f2dfa4", "#fdf4dc", "#f7edd4"), PLATES + ["pan"]), "tomato": fl(lambda r: noodles(r, "#e2694f", "#f08a6a", "#d9533f"), PLATES + ["pan"]), "roe": fl(lambda r: noodles(r, "#f2c4a4", "#f8dcc4", "#eab09a", dots="#d9505a"), PLATES + ["pan"])}
V["tortilla"] = {"flat": fl(lambda r: flatbread(r, "#f2dca8", "#d9b070", "#e8c88a"), FLAT), "chips": p(triangle("#f2c85a", "#f8dc8a"), 13, 6)}
V["udon"] = {"broth": fl(lambda r: noodles(r, "#fbf6e6", "#ffffff", "#ece4cc", 4.2, 16, broth="#c99a5a"), BOWLS), "swirl": fl(lambda r: noodles(r, "#fbf6e6", "#ffffff", "#ece4cc", 4.2, 16), PLATES + ["pan"])}
V["wonton-wrappers"] = {"wontons": p(dumpling("#f6f0e0", "#e2d8c0"), 15, 4)}

V["baguette"] = {"slices": p('<ellipse cx="8" cy="8" rx="7" ry="5" fill="#c98a3a"/><ellipse cx="8" cy="8" rx="5.6" ry="3.8" fill="#f6e2b0"/>', 15, 4)}
V["bulgur"] = {"mound": fl(lambda r: grains_in(r, "#d9b06a", "#b8863f", 120, 1.2, 1), MOUND), "bowl": fl(lambda r: grains_in(r, "#d9b06a", "#b8863f", 140, 1.2, 1, shape="full"), BOWLS)}
V["buns"] = {"bun": whole(center('<circle cx="8" cy="8" r="7" fill="#c47a34"/><circle cx="7.6" cy="7.6" r="6" fill="#dc9340"/><ellipse cx="5.5" cy="5.5" rx="0.8" ry="0.45" fill="#fbf2d8" transform="rotate(20 5.5 5.5)"/><ellipse cx="8.5" cy="4.2" rx="0.8" ry="0.45" fill="#fbf2d8" transform="rotate(-10 8.5 4.2)"/><ellipse cx="10.8" cy="6.6" rx="0.8" ry="0.45" fill="#fbf2d8" transform="rotate(35 10.8 6.6)"/><ellipse cx="6.4" cy="8.8" rx="0.8" ry="0.45" fill="#fbf2d8" transform="rotate(-30 6.4 8.8)"/><ellipse cx="9.6" cy="9.6" rx="0.8" ry="0.45" fill="#fbf2d8" transform="rotate(10 9.6 9.6)"/><ellipse cx="4.6" cy="10.6" rx="0.8" ry="0.45" fill="#fbf2d8" transform="rotate(45 4.6 10.6)"/><ellipse cx="11.4" cy="11" rx="0.8" ry="0.45" fill="#fbf2d8" transform="rotate(-20 11.4 11)"/><ellipse cx="7.8" cy="12.2" rx="0.8" ry="0.45" fill="#fbf2d8" transform="rotate(60 7.8 12.2)"/>', 40), 2)}
V["naan"] = {"bread": fl(lambda r: flatbread(r, "#f2d8a0", "#c9803a", "#e2bc7a", oval=True), FLAT)}
V["tteok"] = {"pieces": p(rice_cake("#f4f0e4", "#ffffff"), 13, 6)}

# Seasonings --------------------------------------------------------------------------------

V["basil"] = {"leaves": garnish(basil_leaf("#4a9a3a", "#8fc46f"), 12, 4)}
V["cayenne"] = {"dusting": garnish(powder("#d9533f"), 10, 2)}
V["chili-flakes"] = {"flakes": garnish(dust("#c9402f", "#f2c46a"), 10, 3)}
V["cinnamon"] = {"dusting": garnish(dust("#8a5a32"), 10, 3)}
V["coriander"] = {"leaves": garnish(coriander_leaf("#5fa83f", "#3f8a2e", "#b8e08e"), 10, 6)}
V["dill"] = {"fronds": garnish(needles("#6aa04f"), 9, 5)}
V["furikake"] = {"sprinkle": garnish(dust("#2f4a3a", "#e8d6a0"), 10, 4)}
V["gochugaru"] = {"flakes": garnish(dust("#d9402f", "#e8704a"), 10, 3)}
V["kaffir-lime-leaves"] = {"slivers": garnish(shred("#3f6b3a", 2.6), 10, 5)}
V["mint"] = {"leaves": garnish(leaf("#5fa05a", "#a8d89a"), 11, 4)}
V["mustard-seeds"] = {"seeds": garnish(dust("#c9a03a", "#8a6a2a"), 9, 3)}
V["oregano"] = {"flecks": garnish(fleck("#5f7f3a"), 4, 12)}
V["paprika"] = {"dusting": garnish(dust("#c8432c"), 10, 3)}
V["parsley"] = {"chopped": garnish(fleck("#5f9a45"), 5, 12), "sprig": garnish(parsley_sprig("#4f8a3a", "#7fb069"), 12, 2)}
V["pepper"] = {"cracked": garnish('<circle cx="8" cy="8" r="1.6" fill="#3a3632"/>', 4, 14)}
V["rosemary"] = {"sprig": garnish(needles("#5f8a50"), 14, 2)}
V["sage"] = {"leaves": garnish(leaf("#7f9a7a", "#b8c8b0"), 12, 3)}
V["sesame-seeds"] = {"sprinkle": garnish('<ellipse cx="8" cy="8" rx="2.4" ry="1.4" fill="#e8d4a4"/><ellipse cx="7.4" cy="7.6" rx="1.2" ry="0.6" fill="#f8eed8"/>', 6, 10), "black": garnish('<ellipse cx="8" cy="8" rx="2.4" ry="1.4" fill="#2a2a2a"/>', 6, 10)}
V["shichimi"] = {"sprinkle": garnish(dust("#d9533f", "#2a2a2a"), 10, 2)}
V["sichuan-peppercorns"] = {"cracked": garnish(dust("#8a3a2a", "#c9604a"), 9, 3)}
V["star-anise"] = {"whole": whole(p(star_anise("#7a3f22", "#c08040"), 13, 2), 3)}
V["tarragon"] = {"leaves": garnish(narrow_sprig("#5f8f45"), 11, 5)}
V["thai-basil"] = {"leaves": garnish(leaf("#3f7f3a", "#8a4a7a"), 12, 4)}
V["thyme"] = {"sprigs": garnish(round_leaflets("#6f8a58", "#8a7a5a"), 12, 3)}
V["wasabi"] = {"dollop": center(dollop("#9cc45a", "#c4e08a"), 22)}
V["yuzu-kosho"] = {"dollop": center(dollop("#9ea33a", "#c8cc6a") + '<circle cx="4.6" cy="10.2" r="0.55" fill="#5f6a20"/><circle cx="8.6" cy="12" r="0.55" fill="#5f6a20"/><circle cx="11.6" cy="10.4" r="0.55" fill="#5f6a20"/><circle cx="9.6" cy="5.2" r="0.55" fill="#5f6a20"/>', 22)}

V["chili-powder"] = {"dusting": garnish(powder("#a8342a"), 10, 2)}
V["smoked-paprika"] = {"dusting": garnish(powder("#a8321f", "#c44a2e"), 11, 3)}
V["sumac"] = {"dusting": garnish(powder("#7a1a2a", "#a63446"), 11, 3)}
V["zaatar"] = {"sprinkle": garnish(dust("#7a7f3a", "#f6eedc"), 10, 3)}

# Sauces and condiments ---------------------------------------------------------------------

V["balsamic-vinegar"] = {"drizzle": center(drizzle("#3a1f1a", 1.6), 24, 2)}
V["olive-oil"] = {"drizzle": center(drizzle("#c9b43a", 1.8), 24, 2)}
V["alfredo-sauce"] = {"sauce": fl(lambda r: smooth(r, "#f2e8cc", "#fbf6e6", specks="#d9c48a"), SAUCE)}
V["arrabbiata-sauce"] = {"sauce": fl(lambda r: smooth(r, "#c8382a", "#e2584a", specks="#7a1a12"), SAUCE)}
V["bolognese-sauce"] = {"sauce": fl(lambda r: smooth(r, "#9a3f28", "#b85a3a", specks="#5f2a1a"), SAUCE)}
V["carbonara-sauce"] = {"sauce": fl(lambda r: smooth(r, "#f2d888", "#fbeab8", specks="#3a3530"), SAUCE)}
V["marinara-sauce"] = {"sauce": fl(lambda r: smooth(r, "#cc3e2e", "#e8604a", specks="#4f7a3a"), SAUCE)}
V["vodka-sauce"] = {"sauce": fl(lambda r: smooth(r, "#e8896a", "#f5b296"), SAUCE)}
V["puttanesca-sauce"] = {"sauce": fl(lambda r: smooth(r, "#b8352a", "#d9564a", specks="#2a2a1f"), SAUCE)}
V["pesto"] = {"dollop": center(dollop("#5f8f3a", "#8ab55a"), 22), "sauce": fl(lambda r: smooth(r, "#6a9a3f", "#8ab55a", specks="#3f6b2a"), PLATES + ["pan"])}
V["chili-oil"] = {"drizzle": center(drizzle("#d2401c", 2.6) + "".join(f'<circle cx="{x}" cy="{y}" r="0.9" fill="#5a1a10"/>' for x, y in ((2.6, 6.6), (5.6, 8.4), (9.4, 7.6), (12.6, 6.2))), 24, 2)}
V["douchi"] = {"beans": garnish(bean("#2a2422", "#5a4a42"), 6, 8)}
V["hoisin"] = {"drizzle": center(drizzle("#5a2a1f", 2), 24, 2)}
V["plum-sauce"] = {"dollop": center(dollop("#c9603a", "#e8905a"), 22)}
V["tianmianjiang"] = {"sauce": fl(lambda r: smooth(r, "#4a2a1a", "#6f4430"), SAUCE)}
V["xo-sauce"] = {"dollop": center(dollop("#a8402a", "#d9704a") + '<circle cx="7" cy="10" r="1" fill="#6a2a1a"/>', 22)}
V["dashi"] = {"broth": fl(lambda r: soup(r, "#e8d6a0", "#f6e8c4"), BOWLS)}
V["miso"] = {"soup": fl(lambda r: soup(r, "#d9b06a", "#e8c88a", "#c4954a"), BOWLS), "glaze": center(dollop("#c9903a", "#e2b060"), 22)}
V["okonomiyaki-sauce"] = {"drizzle": center(zigzag("#4a2a1a"), 26, 1)}
V["sesame-dressing"] = {"drizzle": center(drizzle("#e8d6a8", 2.2), 24, 2)}
V["mentaiko-pasta-sauce"] = {"sauce": fl(lambda r: smooth(r, "#ec9a8c", "#f6c4b8", specks="#c9304a"), SAUCE)}
V["tarako-pasta-sauce"] = {"sauce": fl(lambda r: smooth(r, "#f2b8a4", "#f8d8cc", specks="#e07a80"), SAUCE)}
V["teriyaki-sauce"] = {"glaze": center(drizzle("#6a3a1a", 2.6), 24, 2)}
V["tonkatsu-sauce"] = {"drizzle": center(zigzag("#3a1f15"), 24, 1)}
V["yakisoba-sauce"] = {"noodles": fl(lambda r: noodles(r, "#b8743a", "#d4955a", "#9a5a2a", 2.2, 28), PLATES + ["pan"])}
V["doenjang"] = {"stew": fl(lambda r: soup(r, "#b8864a", "#d4a46a", "#8a5a2a"), BOWLS)}
V["gochujang"] = {"dollop": center(dollop("#9e2422", "#d0504a"), 22), "sauce": fl(lambda r: smooth(r, "#a82e26", "#d05a46"), SAUCE)}
V["kecap-manis"] = {"drizzle": center(drizzle("#2a1a15", 2), 24, 2)}
V["sambal"] = {"dollop": center(dollop("#c9301f", "#e8603a") + '<circle cx="9" cy="10" r="0.8" fill="#f2c46a"/>', 22)}
V["sriracha"] = {"drizzle": center(zigzag("#d9301f"), 22, 1)}
V["sweet-chili-sauce"] = {"drizzle": center(drizzle("#e8603a", 2.2) + '<circle cx="5" cy="8" r="0.7" fill="#b8201a"/>', 24, 2)}
V["bbq-sauce"] = {"drizzle": center(drizzle("#6a2a1a", 2.6), 24, 2)}
V["honey"] = {"drizzle": center('<path d="M1 8c3-4 5 4 7 0s5-4 7 0" stroke="#e9a826" stroke-width="2" fill="none" stroke-linecap="round" opacity="0.9"/>', 24, 2)}
V["hot-sauce"] = {"drizzle": center(drizzle("#d9301f", 1.8), 22, 2)}
V["ketchup"] = {"drizzle": center(zigzag("#c9201f"), 22, 1)}
V["maple-syrup"] = {"drizzle": center('<path d="M1 8c3-4 5 4 7 0s5-4 7 0" stroke="#a5531c" stroke-width="2.2" fill="none" stroke-linecap="round" opacity="0.85"/>', 26, 2)}
V["mayonnaise"] = {"drizzle": center(zigzag("#fbf6dc"), 24, 1), "dollop": center(dollop("#fbf2cc", "#ffffff"), 22)}
V["mustard"] = {"drizzle": center(zigzag("#e8b81b"), 22, 1), "dollop": center(dollop("#d9a81b", "#f2c84a"), 22)}
V["tahini"] = {"drizzle": center(drizzle("#d9c08a", 2.2), 24, 2)}

V["harissa"] = {"dollop": center(dollop("#bd4526", "#e0703f") + "".join(f'<circle cx="{x}" cy="{y}" r="0.6" fill="#7a2414"/>' for x, y in ((5.5, 10.5), (9, 11.5), (11, 9), (7, 12.2))), 22)}
V["pomegranate-molasses"] = {"drizzle": center(drizzle("#5a1828", 2), 24, 2)}
V["salsa"] = {"spooned": center('<path d="M2.5 9c0-4 3-6.5 5.5-6.5S13.5 5 13.5 9 11 13.5 8 13.5 2.5 12.5 2.5 9Z" fill="#c8382a"/>' + "".join(f'<rect x="{x}" y="{y}" width="2.4" height="2.4" rx="0.5" fill="{c}" transform="rotate({r} {x + 1.2} {y + 1.2})"/>' for x, y, r, c in ((4.4, 5.6, 12, "#ec6a50"), (8.6, 4.4, -20, "#ec6a50"), (9.4, 9.4, 25, "#e8604a"), (4.6, 9.6, -8, "#f6f0e0"), (7.4, 7.6, 30, "#f6f0e0"), (10.6, 6.8, 0, "#5f9a45"), (6.8, 11, 15, "#5f9a45"))), 22)}
V["thai-curry-paste"] = {"curry": fl(lambda r: smooth(r, "#e06a38", "#f09a68", specks="#4f8a3a"), SAUCE)}

# Baking and sweet --------------------------------------------------------------------------

V["anko"] = {"dollop": center(dollop("#5a2a2a", "#7a3f3a") + "".join(f'<circle cx="{x}" cy="{y}" r="0.7" fill="#86463f"/>' for x, y in ((5, 9.6), (7.4, 11.6), (9, 9.4), (11, 11.2), (10.6, 6.4), (6.2, 5.6), (4.4, 11.8))), 24)}
V["chocolate"] = {"shavings": garnish(flake("#5a3422", "#7a4a32"), 8, 5), "sauce": center(drizzle("#4a2a1a", 2.4), 24, 2)}
V["cocoa-powder"] = {"dusting": garnish(dust("#6a4030"), 10, 3)}
V["coconut-flakes"] = {"flakes": garnish(flake("#fbf9f4", "#e6e0d4"), 9, 6)}
V["golden-syrup"] = {"drizzle": center(drizzle("#e8a82a", 2), 24, 2)}
V["icing-sugar"] = {"dusting": garnish(dust("#ffffff"), 10, 4)}
V["jam"] = {"dollop": center(dollop("#b8243a", "#e05a6a"), 22)}
V["kinako"] = {"dusting": garnish(dust("#d9b878", "#e8cc98"), 10, 4)}
V["peanut-butter"] = {"dollop": center(dollop("#c98a4a", "#e2ac6a"), 22), "drizzle": center(drizzle("#c98a4a", 2.4), 24, 2)}
V["puff-pastry"] = {"square": fl(lambda r: place(pastry_square("#d99a3f", "#f2c46a", "#e8b056"), C, C, 52), FLAT), "pieces": p(pastry_square("#d99a3f", "#f2c46a", "#e8b056"), 16, 3)}
V["raisins"] = {"raisins": garnish(raisin("#4e2038", "#7e4566"), 7, 8)}
V["shiratamako"] = {"dumplings": p('<circle cx="8" cy="8" r="5.6" fill="#f6f2e8"/><circle cx="8" cy="8" r="1.7" fill="#e6dfcf"/><ellipse cx="6" cy="5.8" rx="1.6" ry="0.9" fill="#ffffff" opacity="0.8"/>', 12, 5)}
V["sugar"] = {"dusting": garnish('<circle cx="8" cy="8" r="1.4" fill="#ffffff" opacity="0.95"/>', 4, 14)}

V["filo-pastry"] = {"pieces": p(filo_shard("#d9a24a", "#efcb80", "#f8e4b0"), 16, 3)}
V["shortcrust-pastry"] = {"square": fl(lambda r: place(pastry_square("#d9a85a", "#f2dca8", "#e8c07a"), C, C, 52), FLAT)}

# Preserved and dried -----------------------------------------------------------------------

V["aburaage"] = {"strips": p(strip("#c98a3f", "#e8b46a"), 13, 5), "triangles": p(triangle("#c98a3f", "#e8b46a"), 14, 4)}
V["almonds"] = {"slivered": garnish(teardrop("#e8d2a0", "#c9a870"), 8, 7), "whole": p(teardrop("#a8683a", "#c98a5a"), 9, 6)}
V["aonori"] = {"sprinkle": garnish(dust("#3f7a2a", "#5f9a45"), 13, 4)}
V["azuki"] = {"beans": p(bean_heap("#7a2a2a", "#b85a5a"), 10, 4)}
V["beans"] = {"beans": p(bean("#dcc496", "#f2e2c0"), 9, 7), "stewed": fl(lambda r: tiled(r, bean("#c96a3a", "#e08a5a"), 8, 40, base="#b8502f"), SAUCE)}
V["black-beans"] = {"beans": p(bean("#2a2428", "#4a424a"), 7, 9)}
V["canned-tomatoes"] = {"sauce": fl(lambda r: smooth(r, "#c9402f", "#e8604a", specks="#a8301f"), SAUCE), "chunks": p(chunk("#c9402f", "#e8604a"), 10, 6)}
V["capers"] = {"capers": garnish(small_round("#687b34", "#a6b668"), 6, 8)}
V["chickpeas"] = {"chickpeas": p('<circle cx="8" cy="8.4" r="5.4" fill="#ddb06c"/><path d="M8 3.4c-1.2 1.6-1.2 3.2 0 4.6" stroke="#b8843e" stroke-width="1" fill="none" stroke-linecap="round"/><circle cx="6.2" cy="7.4" r="1.3" fill="#f6dcaa"/>', 10, 7)}
V["coconut-milk"] = {"curry": fl(lambda r: smooth(r, "#f2e2b0", "#fbf2d8"), SAUCE), "drizzle": center(drizzle("#fbf8ef", 2.4), 24, 2)}
V["curry-roux"] = {"sauce": fl(lambda r: smooth(r, "#a4693a", "#c98a4b"), SAUCE)}
V["dried-shiitake"] = {"caps": p(mushroom_cap("#6f4a2f", "#c9a07a", "#5a3a22"), 12, 4)}
V["hijiki"] = {"strands": garnish(short_strokes("#1f1f1f"), 10, 4)}
V["kamaboko"] = {"slices": p(half_moon("#f08aa0", "#fbf8f2"), 13, 4)}
V["katsuobushi"] = {"flakes": garnish(bonito_flake("#dca088", "#f6d8c4"), 12, 6)}
V["kidney-beans"] = {"beans": p(bean("#8a2a2a", "#b04a4a"), 9, 8)}
V["kiriboshi-daikon"] = {"strands": p(shreds("#d9c49a", "#e8d6b0"), 11, 6)}
V["kombu"] = {"strips": p(strip("#2a3a2c", "#4f6550"), 14, 4)}
V["konnyaku"] = {"cubes": p(cube("#8a8580", "#a8a49e", "#6f6a66") + "".join(f'<circle cx="{x}" cy="{y}" r="0.5" fill="#4a4642"/>' for x, y in ((6, 9), (10, 7), (9, 11))), 10, 6)}
V["koya-dofu"] = {"cubes": p(cube("#ecdcb8", "#f6ead0", "#d9c49a"), 11, 5)}
V["lentils"] = {"dal": fl(lambda r: smooth(r, "#e2a83a", "#f2c45a", specks="#c98a2a"), SAUCE), "lentils": p(lentils("#8f6a3a", "#b8925a"), 11, 5)}
V["matcha"] = {"dusting": garnish(dust("#7fa83a"), 10, 3)}
V["menma"] = {"strips": p(strip("#c99a5a", "#e2bc7a"), 13, 4)}
V["natto"] = {"dollop": center(bean_heap("#a8763a", "#e0b880", "#f6eedc"), 26)}
V["nori"] = {"strips": garnish('<rect x="7" y="1" width="2" height="14" rx="1" fill="#1f3a33"/>', 11, 6), "sheet": center(sheet_square("#1f3a33", "#2c5148"), 30)}
V["nuts"] = {"chopped": garnish(crumble("#a8743a", "#d9a86a"), 9, 7)}
V["olives"] = {"rings": p('<ellipse cx="8" cy="8" rx="4.6" ry="4" fill="none" stroke="#2e2830" stroke-width="2.8"/>', 9, 6), "whole": p('<ellipse cx="8" cy="8" rx="4.4" ry="5.8" fill="#7a8a34"/><ellipse cx="6.5" cy="6" rx="1.2" ry="1.9" fill="#b4c068"/>', 10, 5)}
V["passata"] = {"sauce": fl(lambda r: smooth(r, "#d03f30", "#e8604a"), SAUCE)}
V["peanuts"] = {"crushed": garnish(crumble("#c98f4f", "#f2cc94"), 9, 7)}
V["pickled-ginger"] = {"slices": p(strip_heap("#d42a3a", "#f0646c"), 12, 3)}
V["pine-nuts"] = {"toasted": garnish(teardrop("#e8c27a", "#f8e2b0"), 6, 8)}
V["shirataki"] = {"noodles": fl(lambda r: noodles(r, "#e6e2da", "#f6f4ee", "#d4d0c6", 1.6, 30), ANY)}
V["sun-dried-tomatoes"] = {"strips": p('<path d="M2 7c1.5-3 5-3.6 7-2.4 2-1.6 5 0 5.4 2.6.5 2.6-1 5-4 5.4-2.4.4-3-.6-5 .4C3 13.4 1 10.4 2 7Z" fill="#8a2220"/><path d="M4 8.2c2-1.4 4-1.6 6-.6M5 10.8c2-.8 4.4-1 6.6-.4M9.4 5.2c1.2.4 2.2 1.2 2.8 2.2" stroke="#b8402e" stroke-width="0.9" fill="none" stroke-linecap="round"/><path d="M6.4 6.2c.6 1.6.4 3.6-.4 5.2" stroke="#5e1414" stroke-width="0.7" fill="none" stroke-linecap="round"/>', 12, 5)}
V["takuan"] = {"slices": p(half_moon("#f2c81b", "#f8e05a"), 12, 4)}
V["tofu"] = {"cubes": p(cube("#fbf8ee", "#ffffff", "#e8e2d0"), 11, 6), "fried": p(cube("#e3ae62", "#f4d49a", "#c4823a"), 11, 6), "block": fl(lambda r: block(r, "#fbf8ee", "#ffffff", "#e8e2d0"), PLATES + BOWLS)}
V["umeboshi"] = {"whole": whole(center('<circle cx="8" cy="8" r="6.8" fill="#c8344c"/><path d="M4 6.5c1.2-1 2.4-1 3.4 0M8.5 10.5c1.2 1 2.4 1 3.4 0M9 4.6c1 .4 1.6 1.2 1.8 2.2M4.6 10c.4 1 1.2 1.6 2.2 1.8" stroke="#8a1c34" stroke-width="0.8" fill="none" stroke-linecap="round"/><ellipse cx="6" cy="5.6" rx="1.6" ry="1" fill="#f4808f" opacity="0.7"/>', 22), 3)}
V["wakame"] = {"pieces": p(frond("#1f5a40", "#4a8a62"), 13, 5)}
V["walnuts"] = {"halves": p(walnut("#b8864a", "#8a5a2a"), 11, 5)}
V["wheat-gluten"] = {"fu": p(ring("#f2dcb0", "#fbecd0", 3), 12, 3)}
V["zha-cai"] = {"strips": p(strip("#b8b064", "#d4cc88"), 11, 5)}

V["atsuage"] = {"pieces": p('<rect x="2.5" y="2.5" width="11" height="11" rx="1.6" fill="#c98a3f"/><rect x="2.5" y="9.4" width="11" height="4.1" rx="1.4" fill="#fbf6e6"/><circle cx="5" cy="5" r="0.8" fill="#e0aa5e"/><circle cx="9" cy="4.6" r="0.7" fill="#e0aa5e"/><circle cx="11" cy="7" r="0.8" fill="#e0aa5e"/><circle cx="6.6" cy="7.4" r="0.7" fill="#e0aa5e"/>', 12, 5)}
V["cashews"] = {"whole": p('<path d="M3 6c0 5 3 8 7 8s5-3 5-5c-1.4.8-2.6 1.2-4 1.2-2.6 0-3.6-1.8-4-4-.3-1.4-1.6-1.6-2.4-.8Z" fill="#e8c888"/><path d="M5 7.4c.6 2.6 2.4 4.6 5 4.8" stroke="#f6e2b4" stroke-width="0.9" fill="none" stroke-linecap="round"/>', 11, 6)}
V["chia-seeds"] = {"sprinkle": garnish(dust("#3a3632", "#8a8580"), 8, 3), "pudding": fl(lambda r: smooth(r, "#e8e2d6", "#f6f2ea", specks="#2d2a28", full=True), BOWLS)}
V["ganmodoki"] = {"simmered": whole(center('<circle cx="8" cy="8" r="7" fill="#b8762e"/><circle cx="8" cy="8" r="5.8" fill="#d9a050"/><rect x="4.6" y="6" width="1.8" height="1" rx=".4" fill="#ef6a2a"/><rect x="9.4" y="10" width="1.8" height="1" rx=".4" fill="#ef6a2a"/><circle cx="10" cy="6" r=".9" fill="#5f9a45"/><circle cx="6" cy="10.4" r=".9" fill="#5f9a45"/><path d="M7.4 4.6l1.6.6M10.8 8.2l1 1.2M4.6 8.8l1.4-.4M8 11.6l1.2.6" stroke="#2d2622" stroke-width=".6" stroke-linecap="round"/>', 30), 3)}
V["hazelnuts"] = {"chopped": garnish(crumble("#b8763a", "#e2c49a"), 8, 7)}
V["kikurage"] = {"strips": p(shreds("#3a2a26", "#6a5550"), 11, 5)}
V["okara"] = {"mound": fl(lambda r: grains_in(r, "#f2ead2", "#e2d6b4", 120, 1, 0.9), MOUND)}
V["pecans"] = {"halves": p('<path d="M1.5 8c0-3 3-4.5 6.5-4.5s6.5 1.5 6.5 4.5-3 4.5-6.5 4.5S1.5 11 1.5 8Z" fill="#7a3a1f"/><path d="M1.5 8h13" stroke="#4f2210" stroke-width="1"/><path d="M5 5.2c.7 1 .7 1.8 0 2.8M8 4.6c.7 1 .7 2.4 0 3.4M11 5c.7 1 .7 2 0 3" stroke="#a85a32" stroke-width="1" fill="none" stroke-linecap="round"/>', 11, 5)}
V["pickles"] = {"slices": p(round_slice("#5f8a3a", "#cfd28a", seeds="#a8a868"), 11, 6)}
V["pistachios"] = {"chopped": garnish(crumble("#8fae4a", "#c4d888"), 8, 7)}
V["pumpkin-seeds"] = {"seeds": garnish('<path d="M3.6 8c0-1.4 2.4-2.4 4.6-2.4s4.2 1 4.2 2.4-2 2.4-4.2 2.4S3.6 9.4 3.6 8Z" fill="#5f8a3a"/><ellipse cx="7.6" cy="7.4" rx="2" ry=".6" fill="#a8c47a" opacity="0.8"/>', 9, 8)}
V["rakkyo"] = {"whole": p(teardrop("#f6f2dc", "#ffffff"), 9, 5)}
V["sauerkraut"] = {"heap": p(shreds("#efe8b8", "#d9cf88"), 12, 5)}
V["soybeans"] = {"beans": p(small_round("#e8c98a", "#f6e2b4"), 7, 9)}
V["sunflower-seeds"] = {"seeds": garnish('<path d="M2.5 8C2.5 6.6 4.5 5.4 7.5 5.6 10.5 5.8 13 7 14 8 13 9 10.5 10.2 7.5 10.4 4.5 10.6 2.5 9.4 2.5 8Z" fill="#cbbf9c"/><path d="M4 8h7.5" stroke="#a89a78" stroke-width="0.6" stroke-linecap="round"/>', 8, 9)}
V["tenkasu"] = {"sprinkle": garnish(crumble("#f2d48a", "#fbe6b0"), 7, 8)}
V["white-beans"] = {"beans": p(bean("#f6f2e4", "#ffffff"), 9, 7)}
V["yuba"] = {"sheets": p(folded_sheet("#f6e2a8", "#e2be70"), 15, 4)}

HIDDEN = {
    # Cooked into the dish or taken out before serving.
    "bay-leaf": "taken out before serving",
    "cardamom": "taken out before serving",
    "cloves": "taken out before serving",
    "lemongrass": "taken out before serving",
    "galangal": "taken out before serving",
    "juniper": "taken out before serving",
    "caraway": "cooked into the dish",
    # Ground spices and powders colour the dish rather than sit on it.
    "cumin": "ground into the dish", "curry-powder": "ground into the dish", "fennel-seeds": "ground into the dish",
    "five-spice": "ground into the dish", "garam-masala": "ground into the dish", "garlic-powder": "ground into the dish",
    "msg": "dissolved", "nutmeg": "ground into the dish", "onion-powder": "ground into the dish",
    "saffron": "colours the rice", "salt": "dissolved", "sansho": "ground into the dish", "turmeric": "colours the dish",
    "allspice": "ground into the dish", "asafoetida": "ground into the dish", "fenugreek": "ground into the dish",
    # Liquids and seasonings that are absorbed.
    "red-wine": "cooked off", "white-wine": "cooked off", "black-vinegar": "absorbed", "char-siu-sauce": "absorbed",
    "dark-soy-sauce": "absorbed", "doubanjiang": "colours the sauce", "oyster-sauce": "absorbed", "sesame-oil": "absorbed",
    "shacha-sauce": "absorbed", "shaoxing-wine": "cooked off", "mentsuyu": "absorbed", "mirin": "absorbed",
    "ponzu": "absorbed", "rice-vinegar": "absorbed", "sake": "cooked off", "shiro-dashi": "absorbed",
    "soy-sauce": "absorbed", "yakiniku-sauce": "absorbed", "coconut-oil": "cooking fat", "fish-sauce": "absorbed",
    "tamarind": "absorbed", "apple-cider-vinegar": "absorbed", "beer": "cooked off", "oil": "cooking fat",
    "soy-milk": "absorbed", "vinegar": "absorbed", "water": "absorbed", "worcestershire": "absorbed",
    "buttermilk": "absorbed", "ghee": "cooking fat", "milk": "absorbed", "bouillon": "dissolved",
    "tomato-paste": "colours the sauce", "molasses": "absorbed", "vanilla": "absorbed",
    "chipotle-in-adobo": "colours the sauce", "shrimp-paste": "dissolved", "shio-koji": "absorbed", "sake-kasu": "dissolved",
    "rum": "cooked off", "brandy": "cooked off", "evaporated-milk": "absorbed", "kefir": "absorbed",
    # Baking staples that become something else.
    "agar": "sets the dish", "almond-flour": "baked in", "baking-powder": "baked in", "baking-soda": "baked in",
    "bread-flour": "baked in", "brown-sugar": "dissolved", "cake-flour": "baked in", "cornmeal": "baked in",
    "cornstarch": "thickens the sauce", "flour": "baked in", "gelatin": "sets the dish", "rice-flour": "baked in",
    "yeast": "baked in", "palm-sugar": "dissolved", "masa-harina": "baked in",
}
