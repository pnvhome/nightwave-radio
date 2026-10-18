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

### Playback continuity takes priority (build 11)

Removed the post-synthesis score-quality gate from live generation. Completed audio is no longer discarded and regenerated because of melodic repetition. The symbolic checker remains an offline diagnostic helper only. Automatic retries are limited to invalid/truncated instrumental plans that fail before synthesis. This avoids multiplying full-track generation time but does not guarantee uninterrupted playback when the model itself generates too slowly. A regression test verifies that musical-quality errors cannot cause additional full-generation attempts.

### Pre-synthesis static-run edit (build 13)

The timed section-caption experiment was rejected: two of the three captured Ambient requests produced an invalid or truncated score. It is not in this build. Planning retains the existing instrumental LoRA caption and sampling.

After the unchanged official transfer, a separate stdlib-only edit shortens exact consecutive melody-and-harmony groups lasting at least 60 nominal seconds. It retains at least two occurrences and approximately 32 seconds, preserves later music, and revalidates synchronized voices and ties. Section labels alone do not conceal unchanged music. Returning themes, changed chords, short repeats and drones are unchanged. Invalid splices retain the original validated score. A separate `arrangement_edit` audit records removed duration and hashes; upstream transfer fields refer to the score before this local edit.

This is conservative symbolic editing, not audio similarity detection or newly composed variation. It can shorten tracks. It does not guarantee that timbre or arrangement will sound varied, nor does it detect approximate repeats. It adds no model calls, quality retries, or discarded rendered audio.

- 23 Swift tests passed.
- 13 CPU score tests passed (4 official bridge tests, 9 arrangement tests), including embedded isolated-Python execution, recurring themes, harmony changes, section labels, synchronized timelines and tied-note splices.
- Full backend test command completed successfully before the final Python edit; focused YuE2 backend tests also completed successfully after it.
- Final patch application was checked against pinned upstream files and reproduces the local changed sources.
- The score edit alone averaged 4.53 ms over 20 runs on the long-loop example (not an end-to-end generation benchmark).

Three captured Ambient requests were replayed with their original seeds, duration cap (180 seconds) and 32 steps. All three completed in one attempt with no vocal notes after official transfer:

| Seed | Generation wall time | Rendered duration | Arrangement edit |
| --- | ---: | ---: | --- |
| 504381763 | 61.82 s | 180.00 s | None; recurring phrases retained |
| 1683861984 | 67.65 s | 180.00 s | None; differences retained |
| 2098101470 | 30.72 s | 46.08 s | 23 repeated groups removed before synthesis |

The first two requests reproduce their earlier symbolic structures; this change specifically fixes the long exact static run in the third example. These results do not demonstrate that all three sound sufficiently varied. Listening remains necessary before publication.

Shortened tracks also trigger one extra ready-track reserve when their duration is below 1.5 times the longest generation in the current session (minimum budget 60 seconds). The queue is bounded to two ready tracks, generated serially. Normal long queued tracks retain the previous one-track buffer. This uses idle playback time to prepare the following track rather than waiting for the short track to start. Sustained generation slower than playback can still exhaust the buffer.

The final Swift suite passes 26 tests, including short-track reserve policy and the measured generation budget.

The final bundled app passed a live three-track queue test: paused playback while filling the reserve, FIFO reserve promotion on manual skip, automatic transition, stop/cancellation, usage persistence and resource counters. Bundle audit and strict signature verification passed. Public release remains deferred pending listening feedback.

### Automatic playback crossfade (build 14)

Automatic transitions overlap the outgoing and queued audio for up to three seconds, bounded to one quarter of either track's duration. Complementary linear gains follow the current volume control. Pausing freezes both players; seeking, manual skipping and stopping dispose of the outgoing player. A completion callback from the outgoing player cannot skip the new track. When no next track is ready, playback follows the existing end-of-track behavior. Model generation and saved audio are unchanged.

Validation: 26 core tests and 3 audio integration tests passed on the development Mac with `NIGHTWAVE_AUDIO_TESTS=1 swift test`. Silent local fixtures exercise real AVAudioPlayer overlap, queue consumption, pause/resume, volume changes, outgoing completion, seek, immediate manual skip, missing queue and stopping both players. Audio-device tests are opt-in for headless CI. Audible smoothness across actual generated songs still needs listening feedback.

### Recording playback and warm start (build 15)

Start radio attempts the newest readable matching recording before preparing the model. New recordings persist a generation-settings snapshot; legacy recordings require an exact generated prompt and matching requested duration from their request sidecar. Volume is excluded. Unknown settings, absent files and unreadable audio are not treated as valid matches. Replays do not create duplicate history entries or increment generation statistics.

Previous/Next navigation uses a separate playback trail and preserves the generated queue. Manual recording selection leaves active radio generation running; offline selection starts only the audio player. The Recordings page has play buttons, and the player offers a searchable recording popover. Automatic crossfades also respect forward navigation history.

Validation: 30 core tests and 7 real audio-player integration tests passed with NIGHTWAVE_AUDIO_TESTS=1. Tests cover metadata backward compatibility, settings and duration mismatches, restart recovery without a model, legacy sidecars, unreadable newest-file fallback, back/forward navigation, generated-queue preservation, and crossfade after navigating back. The backend and model generation algorithm are unchanged.

Installed-app UI checks confirmed that the searchable recording popover lists existing recordings, selection starts playback immediately, Previous selects the preceding saved track, and the Recordings page exposes play buttons. Existing user recordings and their metadata were retained.

After installing and reopening build 15, Start radio immediately played the latest matching existing Ambient recording while the UI showed model loading. The installed app passed strict signature verification.
