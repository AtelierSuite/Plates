# Plates Kitchen

A Mac app for screening small on-device recipe models on three cooking requests in English and Japanese. Each local GGUF model writes a plain recipe through `llama-server`, then Apple Intelligence extracts it into a consistent structure with `@Generable`. The app shows the original text beside the extraction, records automated flags and human review, and exports the session as JSON.

## Build and open

Requires macOS 26+ with Apple Intelligence enabled, Xcode command line tools, and a recent [llama.cpp](https://github.com/ggml-org/llama.cpp) `llama-server` (e.g. `brew install llama.cpp`).

```sh
./Scripts/build-app.sh
open "dist/Plates Kitchen.app"
```

Choose the `llama-server` executable in the app, then **Download** or **Choose** a GGUF for each model. For Gemma, accept Google's terms via **Source** and enter a Hugging Face token (kept in memory only). Prompts go only to the local server at `127.0.0.1`.

| Model | GGUF repository | File | Size |
| --- | --- | --- | ---: |
| Gemma 3 1B instruction tuned | [Google](https://huggingface.co/google/gemma-3-1b-it-qat-q4_0-gguf) | `gemma-3-1b-it-q4_0.gguf` | 1 GB |
| Granite 4.0 1B | [IBM](https://huggingface.co/ibm-granite/granite-4.0-1b-GGUF) | `granite-4.0-1b-Q4_K_M.gguf` | 1.02 GB |
| Qwen3 1.7B | [ggml-org](https://huggingface.co/ggml-org/Qwen3-1.7B-GGUF) | `Qwen3-1.7B-Q4_K_M.gguf` | 1.28 GB |
| Bonsai 1.7B | [Prism ML](https://huggingface.co/prism-ml/Bonsai-1.7B-gguf) | `Bonsai-1.7B-Q1_0.gguf` | 248 MB |
| LFM2.5 1.2B Instruct | [Liquid AI](https://huggingface.co/LiquidAI/LFM2.5-1.2B-Instruct-GGUF) | `LFM2.5-1.2B-Instruct-Q4_K_M.gguf` | ~730 MB |
| LFM2.5 1.2B JP | [Liquid AI](https://huggingface.co/LiquidAI/LFM2.5-1.2B-JP-GGUF) | `LFM2.5-1.2B-JP-Q4_K_M.gguf` | 731 MB |

These are plausible iPhone 15 Pro candidates via llama.cpp's [iOS XCFramework](https://github.com/ggml-org/llama.cpp/blob/master/docs/xcframework.md), but on-device performance and memory must be measured separately. Bonsai 1.7B (a 1-bit Qwen3 derivative) loads in Homebrew llama.cpp 0.4.1 (build 10964); older builds may need Prism ML's [fork](https://github.com/PrismML-Eng/llama.cpp).

## Recipe eval

```sh
"dist/Plates Kitchen.app/Contents/MacOS/PlatesKitchen" --headless-eval --output "$HOME/Library/Application Support/Plates Kitchen/headless-eval.json"
```

Defaults to `/opt/homebrew/bin/llama-server` and GGUFs in `~/Library/Application Support/Plates Kitchen/Models`. Options: `--model <id>` (e.g. `qwen3-17b`), `--server`, `--models-directory`, `--repetitions`, and `--concurrency 1...4` (default 2). The app has the same Concurrent trials setting. It loads one GGUF at a time and gives each parallel server slot a 4096-token context; separate Apple Intelligence sessions structure completed recipes. Output is saved as trials finish. Exit status 2 means a generation or structuring attempt failed.

Each model gets all three dishes in both languages with a shared prompt, temperature 0.7, seeds from 1001, 4096 context, and 1400 output tokens, run sequentially. Automatic checks flag missing fields and dish constraints; reviewers mark cookability, constraint adherence, ingredient use, step order, language, and critical failures. **Structure saved outputs** applies the Apple pass to an existing session after archiving it.

This is a screening test only. A promising model still needs evaluation in the full multi-pass Plates pipeline and on a real iPhone 15 Pro.

## SVG graphics eval

The **SVG graphics** screen has each model compose a recipe icon and every step illustration for three sample recipes (`Sources/PlatesKitchen/Samples/svg-recipes.json`). Prompts include the requested subject and the SVG paths of its required ingredient and cookware symbols, so this evaluates scene composition from a known visual vocabulary. Static checks cover XML validity, viewBox, allowed elements and attributes, external references, colors, size, and shape count; they do not verify that the composition depicts the cooking action. Only passing SVGs are previewed. Human review covers subject, action, readability, and style. Results are stored in `svg-session.json`, and **Import JSON** merges headless result files.

```sh
"dist/Plates Kitchen.app/Contents/MacOS/PlatesKitchen" --headless-svg-eval --model granite4-1b --output "$HOME/Library/Application Support/Plates Kitchen/svg-granite.json"
```

Takes the same options as the recipe eval, including `--concurrency 1...4`, plus `--assets <comma-separated asset IDs>` for short trials. Up to two SVG requests run together by default. Exit status 2 means a generation or static check failed.

### Scene plan baseline

**Run Apple scene plan** has Apple Intelligence pick an action and objects from 18 existing Plates icons, which the harness assembles into a fixed layout and checks against the sample data. This isolates content selection from SVG path writing.
Scene plans also use the Concurrent trials setting or headless `--concurrency` option.

```sh
"dist/Plates Kitchen.app/Contents/MacOS/PlatesKitchen" --headless-scene-eval --output "$HOME/Library/Application Support/Plates Kitchen/svg-apple-scene.json"
```

## Image eval

The **Images** screen runs Apple's [Core ML Stable Diffusion](https://github.com/apple/ml-stable-diffusion) pipeline on the same icon and step assets as the SVG eval. Each prompt starts with the asset's visual description and a short, asset-specific ingredient color palette, followed by composition, background, and style. SD 2.1 and its variants default to Cookbook. SDXL defaults to Flat color on a light pastel background because the cookbook wording tends to produce ink sketches. Settings offers Cookbook, Flat color, Cartoon, Sticker, Simple geometric, Outline glyph, 3D abstract, and 3D photorealistic. Style-specific negative prompts keep illustration and photo styles distinct. Generation uses DPM-Solver, guidance 7.5, 25 steps, and seed 1001. Models run on the CPU and Neural Engine, as they would on iPhone, with the safety checker off. Images are saved to `Images/` and results to `image-session.json`.

| Model | Repository | Resolution | Download |
| --- | --- | ---: | ---: |
| Stable Diffusion 2.1 base | [apple/coreml-stable-diffusion-2-1-base-palettized](https://huggingface.co/apple/coreml-stable-diffusion-2-1-base-palettized) | 512 | 1.14 GB |
| Stable Diffusion XL base (iOS) | [apple/coreml-stable-diffusion-xl-base-ios](https://huggingface.co/apple/coreml-stable-diffusion-xl-base-ios) | 768 | 3.05 GB |

Download the compiled `split_einsum` archives from **Settings**, or extract them into `ImageModels/<model id>` yourself.

Three smaller variants are converted locally. Each reuses the text encoder and VAE decoder from Apple's SD 2.1 base, so only the UNet differs:

| Model ID | UNet source | Compression |
| --- | --- | --- |
| `sd21-base-4bit` | [sd2-community/stable-diffusion-2-1-base](https://huggingface.co/sd2-community/stable-diffusion-2-1-base), a mirror of the restricted Stability AI repository | Apple's 4.00-bit [mixed-bit recipe](https://huggingface.co/apple/coreml-stable-diffusion-mixed-bit-palettization) |
| `bk-sdm-v2-small` | [nota-ai/bk-sdm-v2-small](https://huggingface.co/nota-ai/bk-sdm-v2-small), distilled from SD 2.1 base | 6-bit, like Apple's SD 2.1 base |
| `bk-sdm-v2-tiny` | [nota-ai/bk-sdm-v2-tiny](https://huggingface.co/nota-ai/bk-sdm-v2-tiny), distilled from SD 2.1 base | 6-bit |

```sh
./Scripts/convert-image-models.sh setup
./Scripts/convert-image-models.sh bk-sdm-v2-small
```

Setup creates a Python 3.11 environment with `uv` in `Conversion/`. Conversion needs `sd21-base` downloaded first. Heavy steps take a lock, so several conversions can be started at once.

```sh
"dist/Plates Kitchen.app/Contents/MacOS/PlatesKitchen" --headless-image-eval --model sd21-base --output "$HOME/Library/Application Support/Plates Kitchen/image-sd21.json"
```

Each image then goes through a background removal step. Vision's foreground instance mask finds the subject. When Vision returns several instances, the one under the image center is kept, or else the largest; instances touching three image edges are treated as background. When Vision finds nothing, pixels that match the border color and connect to the border are removed, so matching colors inside the subject stay. The subject is scaled to 80% of a transparent 512 px canvas and centered. Checks flag a missing subject, a subject cut off at the image edge, or one under 8% of the image. Corrections, such as dropped duplicates or re-centering, are listed separately. **Results > Redo background removal** reruns this step on saved images.
Image generation uses two independent Core ML pipelines per model by default, so two images can generate at once. Set **Concurrent image workers** in Settings, or pass `--concurrency 1...4` to the headless image eval. Each worker loads its own pipeline, so higher values use more memory; models are still evaluated one at a time. Redo background removal processes two images at once.

**Settings > Style** applies one style to every selected model, and **Select all downloaded models** selects every model that is ready. The gallery can filter by style. For example, to compare every model in the flat color style:

```sh
"dist/Plates Kitchen.app/Contents/MacOS/PlatesKitchen" --headless-image-eval --model all --styles flat-color --output "$HOME/Library/Application Support/Plates Kitchen/image-flat-color.json"
```

Options: `--model` with `all` (every downloaded model), one ID, or a comma-separated list of `sd21-base`, `sdxl-ios`, `sd21-base-4bit`, `bk-sdm-v2-small`, and `bk-sdm-v2-tiny`, `--background white|green`, `--styles cookbook,flat-color,cartoon,sticker,simple-geometric,outline-glyph,3d-abstract,3d-photorealistic` to compare styles in one model load, `--assets <ids>` to run only some assets, `--models-directory`, `--repetitions`, `--steps`, and `--recut` to redo background removal on the images in `--output`. Two contact sheets are written next to the JSON: generated images, and cutouts over a checkerboard. The recorded memory footprint leaves out most Neural Engine allocations, so measure memory on the iPhone.
