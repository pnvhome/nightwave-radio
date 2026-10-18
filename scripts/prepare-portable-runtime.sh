#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="$ROOT/vendor-cache"
mkdir -p "$CACHE"
fetch() {
  local url="$1" file="$2" sha="$3"
  if [ ! -f "$file" ] || [ "$(shasum -a 256 "$file" | cut -d ' ' -f1)" != "$sha" ]; then
    curl -fL --retry 2 "$url" -o "$file.download"
    [ "$(shasum -a 256 "$file.download" | cut -d ' ' -f1)" = "$sha" ]
    mv "$file.download" "$file"
  fi
}
fetch 'https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.6.0.tar.gz' "$CACHE/libwebp-1.6.0.tar.gz" e4ab7009bf0629fd11982d4c2aa83964cf244cffba7347ecd39019a9e38c4564
fetch 'https://github.com/astral-sh/python-build-standalone/releases/download/20261013/cpython-3.12.15%2B20261013-aarch64-apple-darwin-install_only_stripped.tar.gz' "$CACHE/python-runtime.tar.gz" 9866e11cf2ae9caa1e671383786f248859a52dd8bfb702fb4c0dc2c65f1d36de
if [ ! -d "$CACHE/libwebp-1.6.0" ]; then tar -xzf "$CACHE/libwebp-1.6.0.tar.gz" -C "$CACHE"; fi
if [ ! -x "$CACHE/python/bin/python3" ]; then tar -xzf "$CACHE/python-runtime.tar.gz" -C "$CACHE"; fi
cmake -S "$CACHE/libwebp-1.6.0" -B "$CACHE/webp-build" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_DEPLOYMENT_TARGET=26.2 -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DBUILD_SHARED_LIBS=ON -DWEBP_BUILD_ANIM_UTILS=OFF -DWEBP_BUILD_CWEBP=OFF -DWEBP_BUILD_DWEBP=OFF \
  -DWEBP_BUILD_GIF2WEBP=OFF -DWEBP_BUILD_IMG2WEBP=OFF -DWEBP_BUILD_VWEBP=OFF \
  -DWEBP_BUILD_WEBPINFO=OFF -DWEBP_BUILD_WEBPMUX=OFF -DWEBP_BUILD_EXTRAS=OFF
cmake --build "$CACHE/webp-build" -j 8

# Rebuild the native backend for the oldest Apple Silicon CPU. Explicit libc
# paths keep cross-target builds from using Zig's fallback Darwin headers.
pushd "$ROOT/vendor-cache/mlx-serve" >/dev/null
export ZIG_GLOBAL_CACHE_DIR="$PWD/.zig-global-cache"
.zig-toolchain/zig libc > "$CACHE/macos.libc"
.zig-toolchain/zig build -Doptimize=ReleaseFast -Dtarget=aarch64-macos.26.2 -Dcpu=apple_m1 \
  --libc "$CACHE/macos.libc" --cache-dir "$CACHE/zig-portable-cache" --prefix "$CACHE/portable-backend"
popd >/dev/null
