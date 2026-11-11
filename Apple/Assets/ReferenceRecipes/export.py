"""Writes ReferenceRecipes.json for the package from the One-Pan Food recipes.

    python3 export.py /path/to/Recipes

Each recipe is cut down to what Gemma needs to check a dish: its title, how many it serves, the
ingredients with their amounts, and the method. Icons, notes, tools, hints, and troubleshooting
are left out to keep the prompt short.
"""

import json
import sys
from pathlib import Path

# The signature dish each recipe is the reference for, by the recipe's id.
DISHES = {
    "butter-toast": "butter-toast",
    "cheese-risotto": "risotto",
    "chicken-rice": "ketchup-chicken-rice",
    "egg-fried-rice": "egg-fried-rice",
    "french-toast": "french-toast",
    "garlic-fried-rice": "garlic-fried-rice",
    "grilled-cheese": "grilled-cheese",
    "kimchi-fried-rice": "kimchi-fried-rice",
    "pork-bowl": "pork-bowl",
    "seafood-curry": "seafood-curry",
    "spaghetti-carbonara": "spaghetti-carbonara",
    "tomato-egg": "tomato-egg",
    "vegetable-stir-fry": "vegetable-stir-fry",
    "yakisoba": "yakisoba",
}

OUTPUT = Path(__file__).resolve().parents[2] / "CulinaryIntelligence/Sources/CulinaryIntelligence/Resources/ReferenceRecipes.json"
SIGNATURES = OUTPUT.parent / "SignatureDishes.json"


def ingredient(entry):
    amount = entry.get("amount", "").strip()
    item = entry["item"].strip()
    if not amount:
        return item
    if amount[0].isdigit():
        return f"{amount} {item[0].lower() + item[1:]}"
    return f"{item} ({amount})"


def shortened(recipe, dish):
    sections = recipe["ingredients"]
    return {
        "dish": dish,
        "title": recipe["title"],
        "serves": recipe["serves"],
        "ingredients": [ingredient(e) for key in ("supermarket", "general") for e in sections.get(key, [])],
        "optional": [ingredient(e) for e in sections.get("optional", [])],
        "steps": [{"title": s["title"], "points": s["points"]} for s in recipe["steps"]],
    }


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: python3 export.py /path/to/Recipes")
    folder = Path(sys.argv[1]) / "recipes"
    known = {dish["id"] for dish in json.loads(SIGNATURES.read_text())["dishes"]}
    references = []
    for recipe_id, dish in sorted(DISHES.items(), key=lambda item: item[1]):
        if dish not in known:
            sys.exit(f"{dish} is not in SignatureDishes.json")
        recipe = json.loads((folder / f"{recipe_id}.json").read_text())
        references.append(shortened(recipe, dish))
    lines = ",\n".join("  " + json.dumps(r, ensure_ascii=False) for r in references)
    OUTPUT.write_text("[\n" + lines + "\n]\n")
    for r in references:
        size = len(json.dumps(r, ensure_ascii=False))
        print(f"{r['dish']}: {size} characters")


if __name__ == "__main__":
    main()
