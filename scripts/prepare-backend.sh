#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/vendor-cache/mlx-serve"
REVISION=3b6d2fd4d8ee4688f6adfed837e2672b1275582b
PATCH="$ROOT/patches/mlx-serve-instrumental.patch"
mkdir -p "$ROOT/vendor-cache"
if [ ! -d "$SOURCE/.git" ]; then
  git clone --no-checkout https://github.com/ddalcu/mlx-serve.git "$SOURCE"
  git -C "$SOURCE" checkout --detach "$REVISION"
fi
[ "$(git -C "$SOURCE" rev-parse HEAD)" = "$REVISION" ] || { echo 'Backend revision differs from the pinned revision'; exit 1; }
if git -C "$SOURCE" apply --reverse --check "$PATCH" 2>/dev/null; then :
else git -C "$SOURCE" apply --check "$PATCH"; git -C "$SOURCE" apply "$PATCH"; fi
git -C "$SOURCE" submodule update --init --recursive
bash "$SOURCE/scripts/fetch-zig.sh"
bash "$SOURCE/scripts/fetch-llama.sh"
bash "$SOURCE/scripts/build-mlx.sh"
# Recompile the bundled Jinja sources instead of relying on upstream's archive.
mkdir -p "$SOURCE/lib/jinja_cpp/obj"
for unit in jinja_wrapper caps lexer parser runtime jinja_string value; do
  xcrun clang++ -arch arm64 -mmacosx-version-min=26.2 -std=c++17 -O2 -DNDEBUG \
    -I "$SOURCE/lib/jinja_cpp" -c "$SOURCE/lib/jinja_cpp/$unit.cpp" -o "$SOURCE/lib/jinja_cpp/obj/$unit.o"
done
ar rcs "$SOURCE/lib/jinja_cpp/libjinja.a" "$SOURCE/lib/jinja_cpp/obj/"*.o
LORA="$ROOT/vendor-cache/ar_lora_inst_v3abc.bf16.safetensors"
SHA=e408fd3148b75b1165f7ddbf63db575d83bb6402a0b5f876fcb767dbcb2c5414
if [ ! -f "$LORA" ] || [ "$(shasum -a 256 "$LORA" | cut -d ' ' -f1)" != "$SHA" ]; then
  curl -fL --retry 2 'https://huggingface.co/Mothersuperior/YuE2-instrumental-cot-full-loras/resolve/947f2f4b28978b2b6c3e316e6a87925c76bf3c4b/ar_lora_inst_v3abc.bf16.safetensors' -o "$LORA.download"
  [ "$(shasum -a 256 "$LORA.download" | cut -d ' ' -f1)" = "$SHA" ]
  mv "$LORA.download" "$LORA"
fi
