# Building Nightwave Radio

## Prerequisites

Use an Apple Silicon Mac, macOS 26.2+, full Xcode with a macOS SDK 26.2+ and its Metal Toolchain, Git, Python 3, CMake and WebP development files. The standalone app includes Python for end users; source builds use your development Python for packaging scripts.

Install CMake and WebP with `brew install cmake webp`. Select Xcode with `DEVELOPER_DIR` (or `xcode-select`). If needed, install Apple's Metal Toolchain using `xcodebuild -downloadComponent MetalToolchain`. The checked release was built using Xcode 27; other compatible Xcode versions are not yet validated.

Allow several GB of build space and time for compiling MLX and the native backend. The first build needs network access to GitHub, Hugging Face, Python standalone releases, Creative Commons and upstream dependency hosts.

## Commands

```sh
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
swift test
bash scripts/build.sh
bash scripts/package-release.sh
```

The app appears at `build/Nightwave Radio.app`. The DMG, SHA-256 checksum and architecture/dependency audit appear under `release/<version>/`.

## Source and dependency provenance

`scripts/prepare-backend.sh` checks out MLX-Serve revision `3b6d2fd4d8ee4688f6adfed837e2672b1275582b` into `vendor-cache/mlx-serve`, applies `patches/mlx-serve-instrumental.patch`, initializes the upstream submodules, stages the upstream Zig/llama dependencies, and builds MLX and Jinja. The patch includes the official MIT score scripts, their provenance, the native LoRA implementation and tests. No local sibling checkout or previously installed app is required.

The build uses upstream's pinned llama.cpp b11429 library release. Its complete source is available at https://github.com/ggml-org/llama.cpp/tree/b11429 . To replace that staged binary with your own build, build the same version as a self-contained ARM64 dylib and place it and its headers in `vendor-cache/mlx-serve/lib/llama/` with the matching `.version` stamp.

`scripts/prepare-portable-runtime.sh` pins WebP 1.6.0 and CPython 3.12.15 standalone release 20261013 by SHA-256. The AR LoRA uses a fixed Hugging Face revision and SHA-256. Base model weights are not needed to build or run unit tests; they are downloaded from the app for actual playback.

The Python standalone runtime is an upstream binary distribution; its build source and recipe are at https://github.com/astral-sh/python-build-standalone/releases/tag/20261013 . The source build is not a bootstrap of every compiler/runtime from source. All modified Nightwave and MLX-Serve sources are supplied here; upstream dependency sources and notices remain accessible at their pinned origins.

## Verification

- `swift test`: request contracts, retry behavior, M4A encoding, usage accounting and model-path/download tracking.
- `python3 scripts/audit-bundle.py "build/Nightwave Radio.app"`: ARM64 slices, macOS minimum versions, bundled dependencies and symlinks.
- `codesign --verify --deep --strict "build/Nightwave Radio.app"`: local signature integrity.
- `"build/Nightwave Radio.app/Contents/MacOS/NightwaveRadio" --first-run-preview`: isolated missing-model UI without changing your normal library.
- `--smoke-test` / `--queue-test`: opt-in real generation checks, requiring downloaded model weights, memory and GPU time. They write temporary test recordings.

The generated app is ad-hoc signed. Developer ID signing and Apple notarization require the maintainer's own Apple credentials and are not performed by these scripts.
