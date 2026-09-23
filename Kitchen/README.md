# Plates Kitchen

A Mac app for screening small on-device recipe models against the same three cooking requests in English and Japanese. It runs local GGUF weights through `llama-server`, shows every output, records automated flags and human review, and exports the session as JSON.

## Build and open

Requires macOS 15 or later, Xcode command line tools, and a recent [llama.cpp](https://github.com/ggml-org/llama.cpp) `llama-server` executable. For example, `brew install llama.cpp` provides the runtime. Build the app with:

```sh
./Scripts/build-app.sh
open "dist/Plates Kitchen.app"
```

Choose the `llama-server` executable in the app. Download the exact GGUF files from the linked model pages, review each publisher's terms, and choose each file in the model list. The app never downloads weights or sends prompts to a remote model. The server binds to `127.0.0.1`.

| Model | GGUF repository | Selected file | Approximate weight size |
| --- | --- | --- | ---: |
| Gemma 3 1B instruction tuned | [Google](https://huggingface.co/google/gemma-3-1b-it-qat-q4_0-gguf) | `gemma-3-1b-it-q4_0.gguf` | 1 GB |
| Granite 4.0 1B | [IBM](https://huggingface.co/ibm-granite/granite-4.0-1b-GGUF) | `granite-4.0-1b-Q4_K_M.gguf` | 1.02 GB |
| LFM2.5 1.2B Instruct | [Liquid AI](https://huggingface.co/LiquidAI/LFM2.5-1.2B-Instruct-GGUF) | `LFM2.5-1.2B-Instruct-Q4_K_M.gguf` | About 730 MB |
| LFM2.5 1.2B JP | [Liquid AI](https://huggingface.co/LiquidAI/LFM2.5-1.2B-JP-GGUF) | `LFM2.5-1.2B-JP-Q4_K_M.gguf` | 731 MB |

These files are small enough to be plausible iPhone 15 Pro candidates. GGUF and llama.cpp have an [iOS XCFramework](https://github.com/ggml-org/llama.cpp/blob/master/docs/xcframework.md) path. This Mac screening app does not establish iPhone 15 Pro performance or memory headroom; measure both on that device before integration. The 3.8B Phi and larger Gemma variants are excluded from this shortlist. Prism ML Bonsai variants are excluded because their published notices identify Qwen base models. The independent deepgrove Bonsai 500M is not instruction tuned and is English only, so it is unsuitable for this bilingual app eval without further training.

## Eval protocol

Each selected model receives all three dish requests in both languages, with one shared system prompt, temperature 0.7, seeds 1001 onward, a 4096 token context, and 1400 output tokens. Runs are sequential. Each output is parsed as recipe JSON; automatic checks flag missing fields and dish-specific constraints. Reviewers then mark cookability, constraint adherence, ingredient use, step order, language, and critical failures. Results are saved locally after each change and restored on the next launch. Export saves the raw output, parsed recipe, flags, timing, model file path, and review marks.

This is a screening test, not the full Plates generator. Plates writes a recipe in several structured passes and runs a review pass. A promising model needs a second eval in that pipeline plus testing on a real iPhone 15 Pro. Recipe quality, latency, and memory should all be measured there before adoption.
