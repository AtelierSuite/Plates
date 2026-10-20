# Icon style for Plates

Plates draws two kinds of icon, and both are in a Fluent Color style: flat shapes with no
outlines, soft gradients of each shape's own colour, and light from the top left.

- Ingredient and tool icons are hand written SVGs in `Plates/Ingredients.xcassets` and
  `Plates/Tools.xcassets`. They carry their own gradients and highlights.
- Dish icons are put together from parts that `Assets/DishIcons` generates. Parts are written
  in flat colours and shaded as they are exported.

Whatever you draw, check it against the real thing first, and look at it rendered before you
call it done.

## Accuracy, before drawing anything

1. Work out what the thing is. Icon names are the Pascal cased recipe id. The English and
   Japanese names are under `Ingredient.Name.<Name>` or `Tool.Name.<Name>` in
   `CulinaryIntelligence/Sources/CulinaryIntelligence/Resources/Localizable.xcstrings`. Read
   both: the Japanese name often says which form is meant (`紅しょうが` is red shredded ginger,
   not pink gari; `包丁` is an everyday kitchen knife, not a cleaver).
2. Draw the form a cook buys or uses it in, with the right shape, proportions, colour and
   anatomy. When unsure, look at photos before drawing.
3. A fish ingredient is the whole fish. Fillets, steaks, cans and kabayaki are their own
   variants and share the parent's colours.
4. Tell it apart from its neighbours by shape, not only by colour. Families to check against
   each other: citrus (lemon, lime, yuzu, sudachi, mandarin); mushrooms; leafy herbs (basil,
   shiso, perilla, mint, coriander, parsley); bottled sauces; spice jars; flours; pasta shapes;
   white cheeses and dairy; beans; white fish.
5. Things to avoid, each of which came up in review:
   - Two dark dots under a curved highlight read as a face.
   - Thin curved strokes read as worms. Shreds and shavings need width.
   - A rosette of round dots reads as a flower, and a thin pointed lens reads as a seed or an
     almond.
   - A ring with a second circle inside its hole reads as a target.
   - A rounded capsule reads as a sausage, whatever colour it is.

## Ingredient and tool icons

### File rules

- Root element exactly: `<svg width="48" height="48" viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="...">`.
  The `aria-label` is plain English (US), describing the thing drawn.
- Allowed elements: `defs`, `linearGradient`, `radialGradient`, `stop`, `g`, `path`, `circle`,
  `ellipse`, `rect`, `line`, `polygon`. Attributes: `fill`, `fill-opacity`, `stroke`,
  `stroke-opacity`, `stroke-width`, `stroke-linecap`, `stroke-linejoin`, `opacity`, `transform`.
- Not allowed: `filter`, `mask`, `clipPath`, `pattern`, `image`, `text`, `use`, `style`
  elements or attributes, CSS classes, `fill-rule`. The asset catalog renders through CoreSVG.
  Cut a hole by drawing its path in the opposite direction.
- Gradients use `gradientUnits="userSpaceOnUse"` with explicit coordinates and live in `<defs>`
  at the top, with short ids unique within the file.
- No file header or comments. Two space indentation, one element per line.
- The drawing fills roughly 40 by 40 inside the 48 box, centred. Wrapping it in
  `<g transform="translate(...) scale(1.125)">` is fine; gradient coordinates are then in the
  inner space.

### Light and colour

- Every main body runs from a lighter tint at the top left, through its base colour, to a
  deeper shade at the bottom right.
  - Round bodies (fruit, bulbs, florets): `radialGradient` centred at the upper left of the
    shape, radius about 1.5 times the shape's. Stops: tint, base at about .5, shade at 1.
  - Flat faces and boxes: `linearGradient` on the diagonal. On a box the top face is lightest,
    the left face is the base and the right face is darkest.
  - Cylinders, bottles and handles: horizontal `linearGradient`, light on the left.
- Tints run a little warmer and lighter, shades deeper and more saturated. Tomato goes
  `#ff8a75` to `#ec4a3c` to `#b3242b`.
- One highlight on each main body, at the upper left: a white ellipse or a short round capped
  stroke at opacity .5 to .85. Glossy things (tomato, yolk, eggplant, chili, glass) get a crisp
  one. Matte things (bread, flour, meat, tofu) get a soft one at .3 to .5, or none.
- Detail lines (ridges, veins, segments, scale marks, seams) are a darker shade of the body at
  opacity .4 to .6, not a new opaque colour.
- No outlines, drop shadows, backgrounds or ground planes.

| Material | Tint, base, shade |
| --- | --- |
| Leaf green | `#a6dc7e`, `#5fa83f`, `#3f8a2e` |
| Deep green (broccoli, kale) | `#8fcf5c`, `#4f9a34`, `#2f6e22` |
| Red (tomato, strawberry) | `#ff8a75`, `#ec4a3c`, `#b3242b` |
| Orange (carrot) | `#ffb25c`, `#ff7a1f`, `#d9520c` |
| Yellow (lemon, butter) | `#fff59a`, `#ffd21f`, `#e09a00` |
| White food (garlic, rice, tofu) | `#ffffff`, `#f1ece0`, `#cfc6b2` |
| Brown (mushroom, crust) | `#d79a63`, `#a4693a`, `#6e3d1c` |
| Dark sauce (soy, Worcestershire) | `#7a5638`, `#3c2a1c`, `#1e140c` |
| Steel | `#e3e9ef`, `#b2bcc6`, `#8e99a4` |
| Dark metal (pans, pots) | `#767d86`, `#4e545c`, `#25282d` |
| Wood | `#d79c64`, `#b07440`, `#8a5530` |
| Fish back (blue grey) | `#7f9fb6`, `#5a7b93`, `#3f5e75` |

### Packaged things

Bottles, jars and tubs are the hardest family, because the real ones look alike. Give each its
own outline, taken from how it is sold, before reaching for cap and label colour: the round
Kikkoman table bottle for soy sauce, a long neck for dark soy, a wide waisted plastic bottle for
mentsuyu, a paper wrapped slim bottle for Worcestershire, a round bottle for yakiniku sauce, a
clay jar for Shaoxing wine, a squeeze bottle with a flip cap for tonkatsu sauce. A small picture
on the label (a fish for fish sauce, a maple leaf, a chili) helps more than a coloured band. To
compare a family, render it together with `overview.py` on the dark background.

### Small sizes and dark mode

- The smallest size the app draws is 20 pt, in recipe steps. Every icon must still read there.
  Nothing structural is thinner than about 1.2 units; the silhouette carries recognition, not
  the gradients.
- Check every icon on white and on `#1c1c1e`. White foods keep their lightest stop at `#f0f0f0`
  or above so they do not turn grey. Very dark items (soy sauce, nori, black beans, pans) need a
  lighter tint or a highlight on the top left edge to separate from a dark background.

### Workflow

1. Do the accuracy check above, and open the neighbouring icons.
2. Draw or edit the SVG. A new icon also needs its `Ingredient.Name.` or `Tool.Name.` key in both
   languages (see `AGENTS.md`) and, for an ingredient, dish parts (below).
3. `python3 Assets/IconStyle/batch_sheet.py /tmp/icons.png Name ...` (up to about 8 names)
   renders the committed version beside the working tree, on light and dark, at 48 pt and 20 pt.
   Look at it, fix what is wrong, and render again.
4. `python3 Assets/IconStyle/overview.py /tmp/family "#1c1c1e" SoySauce Mentsuyu ...` lays out a
   family side by side. Pass `all` for a contact sheet of every icon.

## Dish icons

A dish icon is a vessel (plate, bowl, pan, pot or board), the fill it is built on (rice, a
sauce, a soup), and pieces scattered or set on top. It is seen from directly above and shown at
about 72 pt on a recipe card, so a piece is only a few points across.

### How parts are drawn

- Every ingredient that can be seen on a served dish has an entry in
  `Assets/DishIcons/catalog.py`, one variant per way it is served (`diced`, `sliced`, `sauce`).
  An ingredient that cannot be seen goes in `HIDDEN`, with the reason.
- Shapes are helper functions in `draw.py`. Pieces are drawn on a 16 by 16 canvas around (8, 8);
  fills on a 64 by 64 canvas inside the circle of radius 30 around (32, 32). The catalog only
  picks a helper and its colours, size and count.
- Write flat colours. `export.py` shades every part through `draw.fluent()`:
  - Fills and vessels never turn, so they are lit from the top left.
  - Pieces are turned to any angle on the dish, so they darken toward their edges instead.
    Never draw a directional highlight into a piece; once turned it would be lit from below.
  - Strokes, specks and shapes with `opacity` stay flat. Sheens and glints are written as white
    shapes with `opacity`.
  - Vessels are shaded by hand in `draw.dish()`.
- Reuse a helper before writing a new one, so a family stays consistent: `sashimi` for raw fish
  slices, `whole_fish`, `small_fish` and `long_fish` for fish served whole, `small_fillet` and
  `oily_fillet` for small fillets, `roast_slice` for sliced roast meat, `thick_wedge` and
  `crescent` for cut fruit and vegetables, `powder` for fine spices, `bean_heap` for beans,
  `grated_mound` for grated roots. A new helper goes in `draw.py`, beside the ones like it.
- Do not rename variants or remove them. Recipes and the planner refer to them.

### Reading on the dish

- Preview every variant on the surfaces it will land on. A piece whose colours are too close to
  what it sits on gets an outline from the layout, which is fine; a piece that needs one
  everywhere should change colour instead.
- Similar foods should differ in shape where they can: chorizo and salami differ in colour and
  fat; sour cream is a swirl, yogurt a smooth spoonful, grated ginger a grated mound.
- Size pieces so they read on a 72 pt card. Garnish is the smallest, and nothing set in the
  middle is smaller than 18.

### Workflow

From `Assets/DishIcons`:

1. `python3 preview.py /tmp/parts.png ingredient ...` draws ingredients straight from the
   catalog on every surface and in every vessel, without exporting. Iterate here.
2. `python3 export.py` writes the parts and their manifest and syncs them into
   `Plates/Dishes.xcassets` and `DishParts.json`.
3. `python3 qa.py` writes the review sheets, `python3 layout.py` the sample sheet `dishes.png`,
   and `swift contrast.swift` lists pieces that are hard to see on a test surface.
4. Only the PNGs are committed. Delete `Review/*.svg` and `dishes.svg` afterwards.

## Signature dish icons

About ninety well known dishes have an icon of their own, drawn by hand, which the app shows in
place of the dish put together from parts whenever a recipe's title names that dish. They live in
`Plates/SignatureDishes.xcassets` as `DishSignature<Name>.imageset/DishSignature<Name>.svg`, where
the name is the Pascal cased id in `SignatureDishes.json` in the package. The prefix keeps them
apart from ingredient icons of the same name, such as `Hummus`.

They do not have to reuse dish parts, and should not look like a scatter of them. Draw the dish
the way it is recognised: a few large, well made shapes for what defines it, and only the
garnish that tells it apart.

### File rules

- Root element exactly: `<svg width="96" height="96" viewBox="0 0 96 96" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="...">`,
  with the dish's English (US) name as the label.
- The same elements, attributes and gradient rules as ingredient icons. No `filter`, `mask`,
  `clipPath`, `pattern`, `image`, `text`, `use`, `style` or `fill-rule`. Cut a hole by drawing
  its path in the opposite direction.
- Gradient ids are unique within the file. No comments, one element per line.

### Composition

- Seen from directly above, like the dish icons made from parts, so a library grid stays even.
- The vessel fills the canvas the way the generated vessels do: a round plate or bowl is a
  circle of radius 46 around (48, 48), with its well at radius 37 for a plate and 40 for a bowl.
  The vessels in `Plates/Dishes.xcassets/Vessels` are a good start, and may be copied. A dish
  served in something else gets that instead: a board for pizza, a two handled pan for paella, a
  stone bowl for bibimbap, a clay pot for a stew. Handles and boards stay inside the 96 box.
- The food fills most of the well. The thing that names the dish is the largest shape and sits
  near the middle; nothing that matters is smaller than about 6 units across.
- Pieces may sit on a soft contact shadow, a dark ellipse at opacity .15 to .25 a little down
  and to the right. Nothing outside the vessel casts a shadow.

### Light and colour

- Light from the top left, as everywhere else. Fills, sauces and broths run lighter at the top
  left; glossy things (yolk, sauce, broth, glazed meat) get a crisp highlight, matte things
  (bread, rice, fried coating) a soft one or none.
- Use the material colours in the table above where they fit.
- Dishes in the same family must differ by more than one colour: curries, rice bowls, noodle
  soups, fried rices and stews each need their own vessel, layout, or defining topping.

### Checking

`python3 Assets/SignatureDishes/sheet.py /tmp/sheet.png Name ...` renders icons through CoreSVG on
light and dark, at the 168 pt header size and the 72 pt smallest size. Pass `all` for the full
set. Every icon has to read as its dish at 72 pt, on both backgrounds.
