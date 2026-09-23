# Plates Kitchen

A Mac app for screening small on-device recipe models against the same three cooking requests in English and Japanese. Each local GGUF model writes a plain recipe through `llama-server`. Apple Intelligence then uses `@Generable` to extract the recipe into a consistent structure. The original model text stays beside the extracted recipe for review. The app records automated flags and human review, then exports the session as JSON.

## Build and open

Requires macOS 26 or later on a Mac with Apple Intelligence enabled and ready, Xcode command line tools, and a recent [llama.cpp](https://github.com/ggml-org/llama.cpp) `llama-server` executable. For example, `brew install llama.cpp` provides the runtime. Build the app with:

```sh
./Scripts/build-app.sh
open "dist/Plates Kitchen.app"
```

Choose the `llama-server` executable in the app. Use **Download** beside a model to save its GGUF to Application Support, or **Choose** to import an existing copy. For Gemma, open **Source**, accept Google's model access terms yourself, then enter a Hugging Face token for the download. The token remains in memory for the current app session and is not saved. Model downloads come from Hugging Face; recipe prompts go only to the local server at `127.0.0.1`.

| Model | GGUF repository | Selected file | Approximate weight size |
| --- | --- | --- | ---: |
| Gemma 3 1B instruction tuned | [Google](https://huggingface.co/google/gemma-3-1b-it-qat-q4_0-gguf) | `gemma-3-1b-it-q4_0.gguf` | 1 GB |
| Granite 4.0 1B | [IBM](https://huggingface.co/ibm-granite/granite-4.0-1b-GGUF) | `granite-4.0-1b-Q4_K_M.gguf` | 1.02 GB |
| LFM2.5 1.2B Instruct | [Liquid AI](https://huggingface.co/LiquidAI/LFM2.5-1.2B-Instruct-GGUF) | `LFM2.5-1.2B-Instruct-Q4_K_M.gguf` | About 730 MB |
| LFM2.5 1.2B JP | [Liquid AI](https://huggingface.co/LiquidAI/LFM2.5-1.2B-JP-GGUF) | `LFM2.5-1.2B-JP-Q4_K_M.gguf` | 731 MB |

These files are small enough to be plausible iPhone 15 Pro candidates. GGUF and llama.cpp have an [iOS XCFramework](https://github.com/ggml-org/llama.cpp/blob/master/docs/xcframework.md) path. This Mac screening app does not establish iPhone 15 Pro performance or memory headroom; measure both on that device before integration. The 3.8B Phi and larger Gemma variants are excluded from this shortlist. Prism ML Bonsai variants are excluded because their published notices identify Qwen base models. The independent deepgrove Bonsai 500M is not instruction tuned and is English only, so it is unsuitable for this bilingual app eval without further training.

## Eval protocol

To run the complete eval from Terminal without opening or controlling the app window, build the bundle and run:

```sh
./Scripts/build-app.sh
"dist/Plates Kitchen.app/Contents/MacOS/PlatesKitchen" --headless-eval --output "$HOME/Library/Application Support/Plates Kitchen/headless-eval.json"
```

The headless run uses `/opt/homebrew/bin/llama-server` and GGUFs in `~/Library/Application Support/Plates Kitchen/Models` by default. Use `--server`, `--models-directory`, or `--repetitions` to override those values. The output JSON is saved after each run, separately from the app window's `session.json`. Exit status 2 means at least one generation or Apple structuring attempt failed.

Each selected model receives all three dish requests in both languages, with one shared cookbook prompt, temperature 0.7, seeds 1001 onward, a 4096 token context, and 1400 output tokens. Runs are sequential. Apple Intelligence extracts each plain recipe with `@Generable`, with instructions to preserve omissions and mistakes. Automatic checks flag missing fields and dish-specific constraints. Reviewers compare the extraction with the original, then mark cookability, constraint adherence, ingredient use, step order, language, and critical failures. Results are saved locally after each change and restored on the next launch. Export saves the original model text, Apple structured recipe, separate generation and structuring timings, flags, and review marks.

**Structure saved outputs** applies the Apple pass to an existing session, including earlier runs that tried to produce JSON directly. It archives the session first. A new eval also archives the current session before replacing its runs. The older JSON attempts remain useful to inspect but are a different prompting condition from the new plain recipe runs.

This is a screening test, not the full Plates generator. Plates writes a recipe in several structured passes and runs a review pass. A promising model needs a second eval in that pipeline plus testing on a real iPhone 15 Pro. Recipe quality, latency, and memory should all be measured there before adoption.

## SVG graphics eval

The **SVG graphics** screen tests a square recipe icon and every step illustration for three bundled sample recipes: egg fried rice, spaghetti with tomato meat sauce, and grilled cheese. The editable sample data is in `Sources/PlatesKitchen/Samples/svg-recipes.json`. Each model receives the same subject, cooking action, style rules, and dimensions. The model writes SVG directly; Apple Intelligence does not generate or repair the drawing. The gallery shows a model's icons and step drawings together; selecting a graphic opens its individual trials and review controls.

The harness stores the full model output, generation time, static checks, and human review per graphic in `~/Library/Application Support/Plates Kitchen/svg-session.json`. **Import JSON** merges headless result files for comparison and archives any prior session. A single clean Markdown code fence is removed and recorded as a formatting warning. Only SVGs that pass the static checks are previewed or offered for saving. Checks cover XML syntax and rendering, the required viewBox, allowed SVG elements and attributes, external references, colors, size, and shape count. Human review covers whether the subject and action are depicted, thumbnail readability, and style consistency. Passing static checks does not establish visual quality or cooking accuracy.

After downloading a model on the recipe screen, the SVG eval can also run without controlling the app window:

```sh
./Scripts/build-app.sh
"dist/Plates Kitchen.app/Contents/MacOS/PlatesKitchen" --headless-svg-eval --model granite4-1b --output "$HOME/Library/Application Support/Plates Kitchen/svg-granite.json"
```

The default is one run per graphic. `--repetitions`, `--server`, and `--models-directory` work here too. Use `--model` with one of the candidate IDs to run a single model. Exit status 2 means at least one output failed generation or the static SVG checks. A drawing that passes still needs a human review in the app.

### Scene plan baseline

The **Run Apple scene plan** button tests a second approach. Apple Intelligence uses `@Generable` to select an action and a few objects from 18 existing Plates ingredient and tool icons. The harness assembles those trusted SVG symbols into a fixed layout. It checks the selection against the expected symbols and action in the sample data, then applies the same SVG checks and human review. This evaluates visual content selection separately from SVG path writing. The resulting icon collage is a prototype, not finished step art.

```sh
"dist/Plates Kitchen.app/Contents/MacOS/PlatesKitchen" --headless-scene-eval --output "$HOME/Library/Application Support/Plates Kitchen/svg-apple-scene.json"
```

Both approaches write compatible result files. Import them on the SVG screen to compare model drawings and scene plans in the gallery.
