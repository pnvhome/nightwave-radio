# Release validation

## 1.3.0 public beta

- Swift test suite: 16 tests passed after English-only UI conversion.
- Covered behavior: instrumental/full-score requests; presets and custom prompts; settings/history compatibility; incomplete models; private model-directory selection; partial download accounting; M4A/AAC format and duration; usage statistics; retry success and exhaustion; immediate propagation of missing-runtime failures.
- Backend sources are fetched at a fixed upstream revision and patched locally; the build no longer depends on a sibling checkout or a previously installed application.
- Bundle audit verifies ARM64 support, macOS deployment targets, included dylibs and absence of external symlinks. Signature verification checks local bundle integrity.

- Public beta live smoke check: bundled engine generated a short instrumental M4A with the existing YuE2 weights and bundled adapter. PASS.
- English first-run interface checked visually.
- Signature verified again after real generation.

## Previously exercised integration behavior

Earlier builds on the development Mac completed real short-track tests covering generation, a three-track queue, pause/resume, manual and automatic transitions, statistics persistence, and stopping the app-owned engine. M4A output was stereo AAC at 48 kHz, approximately 256 kb/s. These checks do not establish that every generated track is free of vocals.

## Remaining platform coverage

The public beta still needs independent clean-Mac installation and full download testing, especially on M1 systems and the minimum supported macOS version. Not every Apple Silicon chip has been tested. No Developer ID signing or notarization is provided.

## Local 1.3.1 candidate: Ambient recovery

- 21 Swift tests passed, including bounded retries, preservation of user sound choices, and symbolic loop rejection.
- A dominant melodic phrase is rejected for Ambient only: at least five occurrences of an exact four-bar phrase covering at least one quarter of a score with 32 or more bars. Phrases with fewer than three pitch letters are excluded to retain rests and drones. This is a heuristic, not an audio similarity detector.
- A real 180-second request produced a repetitive first result, which was rejected before archiving/playback. The second attempt used a different arrangement and produced 120 seconds of audio, 12 distinct score phrases, and zero vocal notes in the official transfer report. A duration request is an upper bound.
- Bundle audit and strict signature verification passed. The app uses the unchanged, previously built 1.3.0 backend and runtime; this candidate changes Swift application behavior only.
- Repetition is currently checked after audio synthesis, so a rejected result costs generation time. Three unsuccessful attempts still stop generation; uninterrupted recovery and absence of audible repetition/vocals are not guaranteed. Listening and a longer Ambient session remain necessary before a public release.

### Refined repetition policy

The earlier frequency-based rule was too strict for recurring themes. The local candidate now rejects only eight consecutive identical four-bar phrases, including unchanged harmony. Intervening melodic or harmonic changes reset the run; ordinary returning themes and shorter repeats pass. This still cannot observe timbre or arrangement changes that are absent from the symbolic score.
