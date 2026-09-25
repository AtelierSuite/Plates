#!/bin/zsh
# Builds the locally converted image models in ImageModels/<model id>/Resources.
#   convert-image-models.sh setup
#   convert-image-models.sh bk-sdm-v2-small | bk-sdm-v2-tiny | sd21-base-4bit
# Each model reuses the text encoder and VAE decoder from Apple's palettized SD 2.1 base
# (download sd21-base in the app first), so only the UNet differs between models.
# Heavy conversion steps take a lock so that concurrent invocations do not exhaust memory.
set -euo pipefail

project_dir="${0:A:h:h}"
support="$HOME/Library/Application Support/Plates Kitchen"
work="$support/Conversion"
models="$support/ImageModels"
py="$work/.venv/bin/python"
lock="/tmp/plates-kitchen-convert.lock"
mkdir -p "$work"
cd "$work"

with_lock() {
    until mkdir "$lock" 2>/dev/null; do sleep 10; done
    trap 'rmdir "$lock" 2>/dev/null' EXIT
    "$@"
    rmdir "$lock"
    trap - EXIT
}

setup() {
    rm -rf python_coreml_stable_diffusion
    cp -R "$project_dir/.build/checkouts/ml-stable-diffusion/python_coreml_stable_diffusion" .
    chmod -R u+w python_coreml_stable_diffusion
    # The upstream script requires a saved Hugging Face token even for public models.
    sed -i '' 's/use_auth_token=True)/token=None)/' python_coreml_stable_diffusion/torch2coreml.py
    # The upstream compile step does not quote paths, and Application Support contains a space.
    sed -i '' 's/^import shutil$/import shlex\nimport shutil/' python_coreml_stable_diffusion/torch2coreml.py
    sed -i '' 's/compile {source_model_path} {output_dir}/compile {shlex.quote(source_model_path)} {shlex.quote(output_dir)}/' \
        python_coreml_stable_diffusion/torch2coreml.py
    # The pre-analysis module downloads test images from Flickr at import time, and those links are dead.
    python3 - python_coreml_stable_diffusion <<'PY'
import sys
path = sys.argv[1] + "/mixed_bit_compression_pre_analysis.py"
source = open(path).read()
if "_random_test_images" not in source:
    start = source.index("RANDOM_TEST_IMAGE_DATA = [")
    end = source.index("]]", start) + 2
    block = source[start:end].replace("RANDOM_TEST_IMAGE_DATA = [", "def _random_test_images():\n    return [", 1)
    source = source[:start] + block + "\n\ntry:\n    RANDOM_TEST_IMAGE_DATA = _random_test_images()\nexcept Exception:\n    RANDOM_TEST_IMAGE_DATA = []" + source[end:]
    open(path, "w").write(source)
print("patched", path)
PY
    # BK-SDM removes the UNet mid block, which the upstream ANE UNet assumes is present.
    python3 - python_coreml_stable_diffusion <<'PY'
import sys
path = sys.argv[1] + "/unet.py"
source = open(path).read()
source = source.replace('assert mid_block_type == "UNetMidBlock2DCrossAttn"\n        self.mid_block = UNetMidBlock2DCrossAttn(',
                        'assert mid_block_type in ("UNetMidBlock2DCrossAttn", None)\n        self.mid_block = None if mid_block_type is None else UNetMidBlock2DCrossAttn(')
call = "        sample = self.mid_block(sample,\n                                emb,\n                                encoder_hidden_states=encoder_hidden_states)"
guarded = "        if self.mid_block is not None:\n            sample = self.mid_block(sample,\n                                    emb,\n                                    encoder_hidden_states=encoder_hidden_states)"
assert source.count(call) == 2
open(path, "w").write(source.replace(call, guarded))
PY
    uv venv -q -p 3.11 .venv
    uv pip install -q -p .venv "torch==2.2.2" "coremltools==8.0" "diffusers==0.27.2" "transformers==4.29.2" \
        "huggingface_hub==0.23.5" "numpy<2" scipy scikit-learn safetensors accelerate requests pytest
}

download() {
    "$py" -c "
from huggingface_hub import snapshot_download
path = snapshot_download('$1', allow_patterns=['*.json', '*.txt', '*.fp16.safetensors'])
print('Downloaded $1 to', path)"
}

assemble() {
    local base
    base="$(dirname "$(find "$models/sd21-base" -name VAEDecoder.mlmodelc -maxdepth 3 | head -1)")"
    [[ -d "$base" ]] || { print "Download Stable Diffusion 2.1 base in the app first."; exit 1 }
    rm -rf "$models/$1"
    mkdir -p "$models/$1/Resources"
    cp -R "$base/TextEncoder.mlmodelc" "$base/VAEDecoder.mlmodelc" "$base/vocab.json" "$base/merges.txt" "$models/$1/Resources/"
    cp -R "$2" "$models/$1/Resources/Unet.mlmodelc"
    du -sh "$models/$1/Resources"/*
}

distilled() {
    local repository="nota-ai/$1"
    download "$repository"
    with_lock "$py" -m python_coreml_stable_diffusion.torch2coreml --model-version "$repository" \
        --convert-unet --attention-implementation SPLIT_EINSUM_V2 --quantize-nbits 6 \
        --bundle-resources-for-swift-cli -o "$work/$1"
    assemble "$1" "$work/$1/Resources/Unet.mlmodelc"
}

sd21_4bit() {
    local repository="sd2-community/stable-diffusion-2-1-base"
    download "$repository"
    if [[ ! -d "$work/sd21-fp16/Stable_Diffusion_version_sd2-community_stable-diffusion-2-1-base_unet.mlpackage" ]]; then
        with_lock "$py" -m python_coreml_stable_diffusion.torch2coreml --model-version "$repository" \
            --convert-unet --attention-implementation SPLIT_EINSUM_V2 -o "$work/sd21-fp16"
    fi
    # Apple's pre-analysis names the restricted stabilityai repository; the mirror has the same weights,
    # and the apply step asserts that every weight matches the recipe.
    curl -fsSL https://huggingface.co/apple/coreml-stable-diffusion-mixed-bit-palettization/resolve/main/recipes/stabilityai-stable-diffusion-2-1-base_palettization_recipe.json \
        | "$py" -c "import json, sys; r = json.load(sys.stdin); r['model_version'] = '$repository'; json.dump(r, open('sd21-recipe.json', 'w'))"
    rm -rf "$work/sd21-4bit"
    mkdir -p "$work/sd21-4bit"
    with_lock "$py" -m python_coreml_stable_diffusion.mixed_bit_compression_apply \
        --mlpackage-path "$work/sd21-fp16/Stable_Diffusion_version_sd2-community_stable-diffusion-2-1-base_unet.mlpackage" \
        -o "$work/sd21-4bit/Unet.mlpackage" --pre-analysis-json-path sd21-recipe.json \
        --selected-recipe recipe_4.00_bit_mixedpalette
    xcrun coremlcompiler compile "$work/sd21-4bit/Unet.mlpackage" "$work/sd21-4bit"
    assemble sd21-base-4bit "$work/sd21-4bit/Unet.mlmodelc"
}

case "${1:-}" in
    setup) setup ;;
    bk-sdm-v2-small|bk-sdm-v2-tiny) distilled "$1" ;;
    sd21-base-4bit) sd21_4bit ;;
    *) print "Usage: $0 setup | bk-sdm-v2-small | bk-sdm-v2-tiny | sd21-base-4bit"; exit 1 ;;
esac
