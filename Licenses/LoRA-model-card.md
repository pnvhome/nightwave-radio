---
license: cc-by-nc-4.0
base_model:
- m-a-p/YuE2-3B
tags:
- audio
- music
- yue2
- lora
- instrumental
---
# YuE2-instrumental-cot-full-loras

AR-branch LoRA for [YuE2-3B](https://huggingface.co/m-a-p/YuE2-3B) that makes the model write **instrumental** music with a **section plan**.
Rank 64 on `self_attn.{q,k,v,o}_proj` + `mlp.{gate,up,down}_proj` of all 28 layers, trained on ~2.7k instrumental tracks paired with
chord-annotated ABC scores from [SheetSage2](https://huggingface.co/m-a-p/SheetSage2), regularized 50/50 with YuE2's own generations.

## Use with `cot="full"`
This LoRA is meant to run with YuE2's chain-of-thought **on** (`cot="full"`): the model first writes its own ABC score, then the music tokens
conditioned on that score. It was trained with the score present half the time and absent half the time, so `cot="off"` still works, but in our
renders the score-first path ended songs on its own 8 times out of 9 and sounded more deliberate, while the score-free path either bailed early or ran
to the length cap. Set `cot="full"` in the pipeline call (ComfyUI: the `mode` input of the YuE2 nodes with a non-empty ABC step; our script: `COT=full`).

## Files
| file | what |
|---|---|
| `ar_lora_inst_v3abc.safetensors` | fp32, 392 named tensors: `layers.{i}.self_attn.{q,k,v,o}_proj.lora_{A,B}`, `layers.{i}.mlp.{gate,up,down}_proj.lora_{A,B}`. Apply `W += lora_B @ lora_A`, scale 1.0. |
| `ar_lora_inst_v3abc.bf16.safetensors` | same weights in bf16 (half size). |
| `ar_lora_inst_v3abc_comfyui.safetensors` | ComfyUI-native layout (fused qkv / gate_up keys), for the LoraLoader CLIP slot. |
| `scripts/ar_generate.py`, `scripts/ckpt_io.py` | reference merge-and-generate script (folds the LoRA into the base weights, then runs YuE2's stock pipeline). |

Works with the stock NAR decoder. For real-production sounding output pair it with the NAR LoRA and tokenizer from
[yue2-mothersuperior-realaudio-tokenizer-v4](https://huggingface.co/Mothersuperior/yue2-mothersuperior-realaudio-tokenizer-v4) (our renders used that NAR LoRA).

## ComfyUI
`ar_lora_inst_v3abc_comfyui.safetensors` is the same LoRA in ComfyUI's native YuE2 layout. In ComfyUI the AR planner lives in the **CLIP** slot, so
load this file with the standard **LoraLoader** and connect its **CLIP** output onward (strength 1.0); the MODEL output is untouched by this file.
Set the YuE2 Generate nodes' `mode` to **full** and connect the ABC node so the model writes its score first. ComfyUI fuses q/k/v into
`text_encoders.model.layers.{i}.self_attn.qkv_proj` and gate/up into `mlp.gate_up_proj`; this file packs the separate LoRAs block-diagonally into
those fused keys (`lora_up`/`lora_down`, no alpha = scale 1.0; `up @ down` equals the stacked deltas exactly). Pair with the NAR LoRA from
[yue2-mothersuperior-realaudio-tokenizer-v4](https://huggingface.co/Mothersuperior/yue2-mothersuperior-realaudio-tokenizer-v4) (`nar_lora_joint_v4_comfyui.safetensors`, MODEL slot) for real-production sound.

## Prompting: three caption styles
The **style** field is a normal YuE2 tag string (genre, instruments, mood, BPM). The **lyrics** field carries the structure, in one of three forms the
LoRA was trained on in equal thirds. Use only these bare tag names: `intro`, `verse`, `pre-chorus`, `chorus`, `bridge`, `outro`. One tag per line,
real line breaks, nothing else in the brackets.

**1. Bare** — let the model choose the structure and length.
```
[instrumental]
```

**2. Untimed tags** — you choose the section order, the model chooses the timing.
```
[intro]
[verse]
[chorus]
[bridge]
[chorus]
[outro]
```

**3. Timed tags** — you also give each section a start and end in `m:ss`. The model was trained with exact section times from real tracks, so this is the
strongest structural steer. Treat the times as a guide rather than a guarantee: the model follows the section order and proportions better than the
absolute end time, and it tends toward 3–5 minute songs regardless of the plan.
```
[intro 0:00-0:15]
[verse 0:15-0:45]
[chorus 0:45-1:10]
[bridge 1:10-1:40]
[chorus 1:40-2:05]
[outro 2:05-2:30]
```

Keep production notes (`[guitar solo, distorted]`), lyrics text, and literal `\n` characters out of the lyrics field: the LoRA never saw them and they
pull the output away from the trained behavior.

## Example
```bash
COT=full STYLE_TEXT="dark ambient, water phone, theremin, piano, slow" \
python scripts/ar_generate.py ar_lora_inst_v3abc.safetensors none out_tag any_style_track plan.txt 21
```
`plan.txt` holds one of the three caption forms above. `AR_SCALE` (default 1.0) scales the LoRA delta; lower values give the base model more say.

## Training notes
lr 6e-5, 5,000 steps, rank 64, one song per step with 2-step gradient accumulation; 50% of steps use the score-conditioned layout (`cot=full`) and 50% the
score-free layout with a separate score-writing sequence, so the model always learns to write the score; an auxiliary section-cursor loss (frame → active
tag line) and an up-weighted END token. Held-out loss on unseen instrumentals fell from 5.33 to 4.51 (score-free) and 3.64 to 2.92 (score-conditioned)
with no overfitting turn. About 5% of tracks were held out and never trained on.

## License
Weights derive from YuE2-3B (CC BY-NC 4.0): non-commercial use only. Provided as-is.
