# Nightwave Radio 1.3.0 — public beta

Local instrumental AI radio for Apple Silicon Macs, with a native English-language interface.

## Download and install

Download `Nightwave-Radio-1.3.0-Apple-Silicon.dmg`, open it and drag the app into Applications. Download YuE2 inside the app, or select a compatible model already on your Mac.

- Apple Silicon M1 or newer; macOS 26.2+.
- 16 GB unified memory recommended; 8 GB is unvalidated.
- About 5 GB for model weights, plus recordings.
- No separate MLX-Serve, Python, Xcode or chat model required.

The DMG is ad-hoc signed, not Developer ID signed or notarized. macOS may block its first launch. Follow [Apple's instructions](https://support.apple.com/102445) for an app you trust; do not disable Gatekeeper globally.

## Included

Six stations, custom prompts, sound options, a playback queue, automatic M4A recording, local resource statistics, model-download progress and a model-folder shortcut. New downloads use Nightwave's own Application Support directory. Existing compatible MLX-Serve models can be reused.

Instrumental generation combines Mothersuperior's AR LoRA with the official YuE2 instrumental score transformation. Invalid scores are retried up to three times. This is not an audio-level guarantee that every result will be free of vocals.

## Licenses

Application source: MIT. YuE2 and the bundled instrumental adapter: **CC BY-NC 4.0, non-commercial use only**. Full credits and license texts are included in the app and source repository. This is an independent project, not endorsed by MLX-Serve, M-A-P, Apple or Mothersuperior.

## Checks and known limits

The Swift test suite passes. The packaged app is checked for ARM64 compatibility, supported deployment targets, bundled dependencies and local signature integrity. Independent testing on additional Mac models and the minimum macOS version is still needed.

Use the included SHA256SUMS.txt to verify the downloaded DMG. Report issues in English with the app version, macOS version, chip and reproduction steps. Review logs for private paths or prompts before attaching them.
