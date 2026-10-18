# Release validation

## 1.3.0 public beta

- Swift test suite: 16 tests passed after English-only UI conversion.
- Covered behavior: instrumental/full-score requests; presets and custom prompts; settings/history compatibility; incomplete models; private model-directory selection; partial download accounting; M4A/AAC format and duration; usage statistics; retry success and exhaustion; immediate propagation of missing-runtime failures.
- Backend sources are fetched at a fixed upstream revision and patched locally; the build no longer depends on a sibling checkout or a previously installed application.
- Bundle audit verifies ARM64 support, macOS deployment targets, included dylibs and absence of external symlinks. Signature verification checks local bundle integrity.

## Previously exercised integration behavior

Earlier builds on the development Mac completed real short-track tests covering generation, a three-track queue, pause/resume, manual and automatic transitions, statistics persistence, and stopping the app-owned engine. M4A output was stereo AAC at 48 kHz, approximately 256 kb/s. These checks do not establish that every generated track is free of vocals.

## Remaining platform coverage

The public beta still needs independent clean-Mac installation and full download testing, especially on M1 systems and the minimum supported macOS version. Not every Apple Silicon chip has been tested. No Developer ID signing or notarization is provided.
