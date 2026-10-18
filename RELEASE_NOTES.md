# Nightwave Radio 1.3.1 — public beta

## Download and install

[Download Nightwave Radio for Mac (.dmg)](https://github.com/pnvhome/nightwave-radio/releases/download/v1.3.1/Nightwave-Radio-1.3.1-Apple-Silicon.dmg)

Open the DMG and drag Nightwave Radio into Applications. For an update, quit the old app first and replace it. Your model, settings, history and recordings remain in place; no model download is needed again.

Apple Silicon M1 or newer, macOS 26.2+, and 16 GB unified memory recommended. 8 GB configurations remain unvalidated. New installations download about 5 GB of model weights inside the app. No separate MLX-Serve, Python, Xcode or chat model is needed.

## New in this release

- Automatic transitions crossfade for up to three seconds when the next track is ready. Pause and volume work across both tracks; saved audio is unchanged.
- Start radio immediately plays the newest readable recording with matching station, sound options, description and requested duration while new music is prepared.
- Previous and Next navigate listening history without losing freshly generated queued tracks.
- A searchable recording picker and Play buttons in Recordings let you listen to saved music without loading the model.
- Long, exact consecutive melody-and-harmony repeats are shortened before audio synthesis. Normal recurring themes and changing arrangements are retained. Edits are validated and recorded in score metadata.
- Short tracks can trigger one extra queued reserve. Audio is not repeatedly regenerated for aesthetic checks, keeping generation throughput a priority.

## Checks and limitations

37 Swift tests passed, including 7 audio-player integration tests; 13 CPU score tests passed. Live generation and queue checks, app signature verification and bundle dependency audits passed on the development Mac. See [VALIDATION.md](https://github.com/pnvhome/nightwave-radio/blob/v1.3.1/VALIDATION.md) for details. Other Mac models and the minimum macOS version still need independent testing.

The score edit cannot detect every audible loop and can shorten tracks. Duration is a cap. Invalid scores may require up to three attempts. Instrumental score checks do not guarantee that every rendered result is free of vocals. Generation speed depends on hardware and available memory.

This beta is ad-hoc signed, not Developer ID signed or notarized. If macOS blocks the first launch and you trust the download, follow [Apple's instructions](https://support.apple.com/102445). Do not disable Gatekeeper globally.

## Licenses and files

Application source: MIT. YuE2 and the bundled instrumental adapter: **CC BY-NC 4.0, non-commercial use only**. Credits and license texts are included in the app and repository.

Choose the DMG to install. The source ZIP is for building the app yourself; model weights are downloaded separately. SHA256SUMS.txt contains checksums for the DMG and source ZIP. bundle-audit.json records packaged dependency checks.
