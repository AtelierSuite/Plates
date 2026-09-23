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

Defaults to `/opt/homebrew/bin/llama-server` and GGUFs in `~/Library/Application Support/Plates Kitchen/Models`. Options: `--model <id>` (e.g. `qwen3-17b`), `--server`, `--models-directory`, `--repetitions`. Output is saved after each run. Exit status 2 means a generation or structuring attempt failed.

Each model gets all three dishes in both languages with a shared prompt, temperature 0.7, seeds from 1001, 4096 context, and 1400 output tokens, run sequentially. Automatic checks flag missing fields and dish constraints; reviewers mark cookability, constraint adherence, ingredient use, step order, language, and critical failures. **Structure saved outputs** applies the Apple pass to an existing session after archiving it.

This is a screening test only. A promising model still needs evaluation in the full multi-pass Plates pipeline and on a real iPhone 15 Pro.

## SVG graphics eval

The **SVG graphics** screen has each model draw a recipe icon and every step illustration for three sample recipes (`Sources/PlatesKitchen/Samples/svg-recipes.json`). Static checks cover XML validity, viewBox, allowed elements and attributes, external references, colors, size, and shape count; only passing SVGs are previewed. Human review covers subject, action, readability, and style. Results are stored in `svg-session.json`, and **Import JSON** merges headless result files.

```sh
"dist/Plates Kitchen.app/Contents/MacOS/PlatesKitchen" --headless-svg-eval --model granite4-1b --output "$HOME/Library/Application Support/Plates Kitchen/svg-granite.json"
```

Takes the same options as the recipe eval. Exit status 2 means a generation or static check failed.

### Scene plan baseline

**Run Apple scene plan** has Apple Intelligence pick an action and objects from 18 existing Plates icons, which the harness assembles into a fixed layout and checks against the sample data. This isolates content selection from SVG path writing.

```sh
"dist/Plates Kitchen.app/Contents/MacOS/PlatesKitchen" --headless-scene-eval --output "$HOME/Library/Application Support/Plates Kitchen/svg-apple-scene.json"
```
