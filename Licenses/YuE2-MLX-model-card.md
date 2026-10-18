---
license: cc-by-nc-4.0
base_model: m-a-p/YuE2-3B
base_model_relation: quantized
library_name: mlx
pipeline_tag: text-to-audio
tags:
- mlx
- music-generation
- yue2
language:
- en
- zh
---

# YuE2-3B — MLX Serve (8-bit)

[m-a-p/YuE2-3B](https://huggingface.co/m-a-p/YuE2-3B) with the [YuE2-Vae](https://huggingface.co/m-a-p/YuE2-Vae)
decoder folded in and 8-bit affine (group size 64) on the backbone, in the layout of
[ahmadw/YuE2-3B-MLX](https://huggingface.co/ahmadw/YuE2-3B-MLX) (its `8bit/` folder, mirrored unchanged).
Lyrics and a style prompt in, a 48 kHz stereo song out, planned from an editable ABC score.

Runs in [mlx-serve](https://github.com/ddalcu/mlx-serve) (`POST /v1/audio/music-generations` and the app's Music tab):

    mlx-serve pull ddalcu/YuE2-3B-MLX-Serve-8bit

Files: `model.safetensors` (backbone), `vae.safetensors` (decoder), `config.json`, `vae_config.json`,
`qwen.tiktoken`, `yue2_generation_config.json`.

## License

Weights are **CC BY-NC 4.0 (non-commercial)**, inherited from YuE2-3B and YuE2-Vae. Credit YuE2 (m-a-p) and
ahmadw's MLX conversion when you publish output. The SnakeBeta and Oobleck decoder code are MIT (NVIDIA, Stability AI);
see the upstream `THIRD_PARTY_NOTICES.md`.
