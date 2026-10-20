# Plates

A single-view iOS recipe manager. Recipes are JSON files that follow the schema used by the
One-Pan Food site in `../Recipes`, one file per recipe, stored either in the app's Documents
folder or in iCloud Drive depending on what the user picks in the ellipsis menu.

## Code rules

- No file headers. Swift files start at the first `import`, with no leading comment block
  naming the file, the project, or the author.
- Never use em-dashes anywhere: not in user-facing copy, code comments, commit messages, or
  this file. Use a period, comma, or colon instead.
- All user-facing text ships in English (US) and Japanese. A new key is written in both.
- The app is a single view. Do not add a `TabView`. Menu items and settings live in the top
  trailing ellipsis menu.
- Everything that is not a view goes in the `CulinaryIntelligence` package. What the app uses
  is `public`, and public types need hand written `public` initializers.
- The package never imports ActivityKit. Progress goes out through `RunObserver`.
- The widget extension carries no strings. The app localizes everything before it goes into
  the activity state.

## Copy style rules

- Write plainly, like a good cookbook. No breathless adjectives, no "it's not X, it's Y"
  constructions, no rule-of-three padding.
- Write ranges with the word "to", never a dash.

## Recipe files

- Files are written by hand in `RecipeJSON`, not `JSONEncoder`, which does not keep key order.
  Property order is the key order on disk, so keep the properties and `Recipe.json` matching the
  site's schema and each other.
- Sample recipes are written out once per language, in `en-US.lproj` and `ja.lproj`, under the
  same file name and the same `id`, so switching languages does not add a second copy.

## PlatesCloud

The Worker lives in `../PlatesCloud` (github.com/katagaki/PlatesCloud) and keeps every daily
limit. The app only shows what it is told is left.

- `PlatesCloudAddress.url` is empty in the repository. `ci_scripts/ci_pre_xcodebuild.sh` writes
  Xcode Cloud's `PLATES_CLOUD_URL` into it. For a local build against the Worker, run the script
  with `PLATES_CLOUD_URL` and `CI_PRIMARY_REPOSITORY_PATH` set, and do not commit the result.
- App Attest does not run in Simulator, so a debug build there sends unsigned requests to
  `http://localhost:8787`. Run `npm run dev` in `../PlatesCloud` with `SKIP_APP_ATTEST=true` in
  its `.dev.vars`.

## Model lessons

Gemma writes on Cloudflare and Apple Intelligence sorts on the device. Each rule below came out
of the evals, so do not undo one without running them again.

- Gemma is always given English, read through `String(culinaryEnglish:)`, and a non-ASCII
  request is put into English first. The model before it read "卵チャーハン" as egg curry.
  The Japanese values on those keys are never sent.
- Read in code whatever code can read: sections, time, servings, units, icons, and whether a
  line is optional. A model read "1 hour 20 minutes" as two hours and got half a cup wrong.
- Sort one line per session. Given a whole list, the on-device model dropped lines, merged
  steps, and padded from the troubleshooting.
- Every sorting pass has a response token limit. One ran past seven thousand tokens and was
  reported as a request too large for the device.
- Sorting passes are not given the house style. They turned its cooking rules into steps.
- When a line names a catalog ingredient, hand the pass the catalog's name, or "frozen peas"
  comes back as green peppers.
- Asked whether the picks can make a dish, the model said yes to a tomato pasta with no pasta.
  The starch is checked against the picks in code.
- Neither a generation nor an edit has a read through at the end. In a generation it rewrote
  whole lists, dropping, duplicating, and inventing lines. In an edit it met no more requests
  than going without, and undid swaps, scaled a recipe twice, and wrote its reasoning into steps.
- An edit changes one line per pass. Asked to write a list back with one change, the model
  dropped lines, moved them between sections, and lost their notes. Lines are dropped and
  serving counts scaled in code.
- The edit plan points at lines by label (I3, T1, S2, N4), and the label decides the list.
  Numbered from 1 per list, it filed a step change as an ingredient change.
- The edit plan sees step titles only, so code follows a swap or a removal into every step,
  note, and title that names it, and checks the result. Left to the plan, a swap changed the
  shopping list and none of the method.
- The edit plan files changes under the wrong target, such as a shorter soak as a serving
  count. Code moves a change that names nothing on its line to the step it belongs in.
- Never inline the catalog into a `@Generable` schema. The on-device window is 4,096 tokens,
  and an `.anyOf` over every ingredient name overruns it on its own.
- Keep passes small enough that Private Cloud Compute stays a fallback for
  `contextSizeExceeded`, not the usual path.
- Jev says whether a seasoning, aromatic, or optional line can be seen on the served dish, one
  question per line, and a line under 0.6 is left off the icon. The title and the last step
  only decide when the Worker cannot be reached.

## Icons

- Asset catalog items are Pascal cased, including the SVG inside: `SpringOnion.imageset/SpringOnion.svg`.
  Recipe files stay kebab cased, as the site's schema is.
- Copy an SVG in with explicit `width` and `height` on the root element, or the asset catalog
  will not take it.
- Adding an icon means adding its `Ingredient.Name.` or `Tool.Name.` key in both languages, by
  hand, with `extractionState` set to `manual`.
- Every icon, dish parts included, follows the Fluent style in `Assets/IconStyle/STYLE.md`.
  Check what you draw against the real thing first, and look at it rendered on light and dark
  before you finish.

### Dish icons

The parts, `Plates/Dishes.xcassets`, and the package's `Resources/DishParts.json` are all written
from `Assets/DishIcons/Parts`. Do not edit the outputs.

- Parts are drawn in flat colours. `export.py` shades them as it writes them, so do not add
  gradients to `catalog.py` or `draw.py` by hand.
- Work in `Assets/DishIcons`: `python3 preview.py` while drawing, then `python3 export.py`,
  `python3 qa.py`, `python3 layout.py` and `swift contrast.swift`. `STYLE.md` has the details.
- Only the PNGs from `qa.py` and `layout.py` are committed. Delete the SVGs they leave behind.

### Signature dish icons

Well known dishes have a hand drawn icon in `Plates/SignatureDishes.xcassets`, shown instead of the
dish made from parts when a recipe's title names the dish. `SignatureDishes.json` in the package
lists the English and Japanese titles each one answers to.

- A title matches only when it names the dish and nothing more, once fillers such as "easy" or
  "簡単" are taken out. "Seafood Carbonara" is not drawn as carbonara.
- A new dish needs its titles in both languages and an icon named `DishSignature<PascalId>`,
  drawn to the "Signature dish icons" section of `Assets/IconStyle/STYLE.md`.
- Check the full set with `python3 Assets/SignatureDishes/sheet.py /tmp/sheet.png all`.

## Localization

English (US) is the source language and Japanese the second. Japanese copy follows the same
plain style, written in です・ます.

- Package code reads its own catalog through `String(culinary:)` and
  `LocalizedStringResource(culinary:)`, never `String(localized:)`, which would look in the
  app's. A key both a view and the package use is kept in both catalogs.
- Keys are dot notated and Pascal cased by segment, from broad to narrow:
  `Recipe.Detail.Ingredients.Supermarket`. Never write the English text as the key.
- Formatted strings use `String(format: String(localized: "Key"), ...)` with positional
  specifiers such as `%1$@`.
- Recipe data is not localized. Show it with `Text(verbatim:)`.
- Everything a model is given is a key, down to the comma a list is joined with. Only the
  `@Generable` schema descriptions stay in English.

## Commit rules

- Single line only. No body, no trailers, no attribution or co-author lines.
- Keep it short (under about 60 characters) and in the imperative mood: "Add recipe detail
  view", not "Added" or "Adds".
- No prefixes like `feat:`/`fix:`, no emoji, no issue references.
- Commit whenever a major change is complete, rather than batching unrelated work.
