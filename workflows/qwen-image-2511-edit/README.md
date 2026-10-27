# Qwen Image Edit 2511 - Int8 + Lightning

Qwen Image Edit 2511 int8 with the 4-step Lightning LoRA.

## Install

```bash
./workflows/qwen-image-2511-edit/install.sh
# or from the inventory root:
./comfy-inventory install qwen-image-2511-edit
```

## Files

| Destination | Size | SHA-256 |
| --- | ---: | --- |
| `models/diffusion_models/qwen_image_edit_2511_int8_convrot.safetensors` | 19.1 GiB | `11b5af5ac601821d…` |
| `models/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors` | 8.7 GiB | `cb5636d852a0ea6a…` |
| `models/vae/qwen_image_vae.safetensors` | 242.0 MiB | `a70580f0213e6796…` |
| `models/loras/Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors` | 810.2 MiB | `22226e8d05d354bb…` |

## Workflow

Clean copy: [`workflow.json`](workflow.json)  
SHA-256: `d97601bef06eb4bd221792445d4d6fb995abb39f91b89833bc635c91148ebc1f`  
Installed as `Qwen image 2511 edit.json` under `ComfyUI/user/default/workflows/`.

## Notes

- The Lightning LoRA is applied by the workflow; keep it in `models/loras`.
- The workflow's `LoadImage` nodes use local sample files; load your own source image.

---

[Back to the inventory](../../README.md)
