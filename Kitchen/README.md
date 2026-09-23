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

Each selected model receives all three dish requests in both languages, with one shared cookbook prompt, temperature 0.7, seeds 1001 onward, a 4096 token context, and 1400 output tokens. Runs are sequential. Apple Intelligence extracts each plain recipe with `@Generable`, with instructions to preserve omissions and mistakes. Automatic checks flag missing fields and dish-specific constraints. Reviewers compare the extraction with the original, then mark cookability, constraint adherence, ingredient use, step order, language, and critical failures. Results are saved locally after each change and restored on the next launch. Export saves the original model text, Apple structured recipe, separate generation and structuring timings, flags, and review marks.

**Structure saved outputs** applies the Apple pass to an existing session, including earlier runs that tried to produce JSON directly. It archives the session first. A new eval also archives the current session before replacing its runs. The older JSON attempts remain useful to inspect but are a different prompting condition from the new plain recipe runs.

This is a screening test, not the full Plates generator. Plates writes a recipe in several structured passes and runs a review pass. A promising model needs a second eval in that pipeline plus testing on a real iPhone 15 Pro. Recipe quality, latency, and memory should all be measured there before adoption.
