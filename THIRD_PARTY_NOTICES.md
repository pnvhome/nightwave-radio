# Third-party notices and distribution terms

Nightwave Radio is an independent project, not an official product of the authors below. No endorsement is implied.

## Application source vs. model weights

The original Nightwave Radio application source is licensed under MIT (see `LICENSE`). This does not relicense third-party code or model weights. The supplied instrumental adapter and the downloaded YuE2 weights are **CC BY-NC 4.0**. The model-powered release is intended for **non-commercial use**. Do not advertise the complete distribution as unrestricted MIT software or as granting commercial music rights. A model license does not establish rights to every generated recording; users remain responsible for their use of outputs.

CC BY-NC 4.0 permits non-commercial sharing and adaptation with attribution, license information, notices of modifications, and no added restrictions. See the complete legal text in `Licenses/CC-BY-NC-4.0.txt` and https://creativecommons.org/licenses/by-nc/4.0/ .

## Credits and licenses

| Component | Author / source | Terms and modifications |
| --- | --- | --- |
| MLX-Serve | David Dalcu, https://github.com/ddalcu/mlx-serve | MIT and upstream third-party notices. Pinned base `3b6d2fd4d8ee4688f6adfed837e2672b1275582b`. Our patch adds instrumental score transfer, native AR LoRA, conservative shortening of long unchanged score passages, tests, and a download-directory override. |
| YuE2 3B | M-A-P, https://huggingface.co/m-a-p/YuE2-3B | CC BY-NC 4.0. Base weights downloaded separately, not in this source repository or DMG. |
| YuE2 MLX 8-bit conversion | ddalcu, https://huggingface.co/ddalcu/YuE2-3B-MLX-Serve-8bit ; upstream layout credited to ahmadw/YuE2-3B-MLX | Under the original model terms. Downloaded separately; never re-licensed by this project. |
| Instrumental AR LoRA | Mothersuperior, https://huggingface.co/Mothersuperior/YuE2-instrumental-cot-full-loras | CC BY-NC 4.0. Bundled unmodified BF16 weights, revision `947f2f4b28978b2b6c3e316e6a87925c76bf3c4b`. Native application code applies the adapter at runtime; weights are not merged into the base model. |
| Official YuE Music Skill instrumental scripts | M-A-P contributors, https://github.com/multimodal-art-projection/YuE/tree/1647252d68b70cbead046ffd3f7caf036dde47ee/skills/yue2-music | The instrumental directory's MIT license applies to the embedded scripts. Four upstream modules retained unchanged; our bridge adapts them to MLX-Serve. See bundled provenance. This code license is distinct from the weights' license. |
| MLX, MLX-C, JACCL | Apple and contributors, https://github.com/ml-explore/mlx and https://github.com/ml-explore/mlx-c | MIT. Versions pinned by upstream git submodules; build includes the upstream MLX-C patch. |
| llama.cpp / GGML | Georgi Gerganov and contributors, https://github.com/ggml-org/llama.cpp/tree/b11429 | MIT. Backend dependency, ARM64 library from upstream build tag b11429. |
| DS4 | Salvatore Sanfilippo and contributors, https://github.com/antirez/ds4 | MIT. Embedded upstream backend dependency; see retained license. |
| Jinja C++ and other embedded backend components | See `Licenses/MLX-Serve-NOTICE.txt` and `Licenses/Jinja.txt` | Their MIT, Apache-2.0, BSD and other retained notices continue to apply. |
| WebP 1.6.0 | Google and contributors, https://chromium.googlesource.com/webm/libwebp | BSD-style license in `Licenses/WebP.txt`; rebuilt for macOS 26.2. |
| CPython 3.12.15 standalone | Python Software Foundation; packaged by Astral, https://github.com/astral-sh/python-build-standalone/releases/tag/20261013 | PSF and bundled third-party licenses. Runtime files and dependency notices retained in `Licenses/Python-dependencies/`. These notices were extracted from the matching full standalone archive; the zlib-ng notice was retrieved from its upstream repository because that notice was absent from the archive. Python is used only for local score transformation. |

## Adapter provenance

Bundled file: `ar_lora_inst_v3abc.bf16.safetensors`.
SHA-256: `e408fd3148b75b1165f7ddbf63db575d83bb6402a0b5f876fcb767dbcb2c5414`.
Original title and author are preserved in `Licenses/LoRA-model-card.md`. No changes to the weight file. The adapter requires the non-commercial YuE2 base model; it is not a separately trained Nightwave model.

## Distribution review

Reviewed against the upstream license texts and model cards on 2026-10-18. The release retains source attribution, full applicable notices, model license links, and modification notices. The model cards are evidence of the publishers' stated terms, not an independent audit of training-data rights. New dependencies or model versions require a new review.
