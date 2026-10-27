# Krea-2 Turbo - Style Transfer

Krea-2 Turbo style-reference generation with the Krea-2 style LoRA.

## Install

```bash
./workflows/krea2-style-transfer/install.sh
# or from the inventory root:
./comfy-inventory install krea2-style-transfer
```

## Files

| Destination | Size | SHA-256 |
| --- | ---: | --- |
| `models/diffusion_models/krea2_turbo_int8_convrot.safetensors` | 12.6 GiB | `8e4eeda70dd5037a…` |
| `models/text_encoders/qwen3vl_4b_fp8_scaled.safetensors` | 4.9 GiB | `54bd5144df0bbc25…` |
| `models/vae/qwen_image_vae.safetensors` | 242.0 MiB | `a70580f0213e6796…` |
| `models/loras/krea2_style_reference.safetensors` | 435.9 MiB | `f50df5a9e62e4be8…` |

## Workflow

Clean copy: [`workflow.json`](workflow.json)  
SHA-256: `adc147d8175a43fe4dc422f796cde96b28aec98befe5a60d7ee5876f3f9c01fa`  
Installed as `Krea2 Style Transfer.json` under `ComfyUI/user/default/workflows/`.

## Notes

- The workflow's `LoadImage` node expects `krea2_reference_image.png`; load your own reference image.

---

[Back to the inventory](../../README.md)
