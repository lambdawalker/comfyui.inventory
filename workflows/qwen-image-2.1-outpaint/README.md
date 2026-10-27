# Qwen Image 2.1 - Outpaint

Qwen Image 2.1 outpainting with the v2 outpaint LoRA.

## Install

```bash
./workflows/qwen-image-2.1-outpaint/install.sh
# or from the inventory root:
./comfy-inventory install qwen-image-2.1-outpaint
```

## Files

| Destination | Size | SHA-256 |
| --- | ---: | --- |
| `models/diffusion_models/qwen_image_2.1_int8_convrot.safetensors` | 6.8 GiB | `cb74113cb03faecd…` |
| `models/text_encoders/qwen3vl_8b_int8_convrot.safetensors` | 8.7 GiB | `8bfd0f6e12abf2d2…` |
| `models/vae/qwen_image_2.1_vae_bf16.safetensors` | 644.2 MiB | `bb21f7473051e1ac…` |
| `models/loras/qwen-image-2.1-outpaint-v2.safetensors` | 152.1 MiB | `3611a5ccae5f7904…` |

## Workflow

Clean copy: [`workflow.json`](workflow.json)  
SHA-256: `d73eba113d1bbec6ba66c7c700c6f47290b5cc700a2c08163e9e9cfc8e88a93b`  
Installed as `qwen-outpaint.json` under `ComfyUI/user/default/workflows/`.

## Notes

- This workflow uses the v2 outpaint LoRA. The older `qwen-image-2.1-outpaint.safetensors` file is not required.
- The workflow's `LoadImage` nodes are empty or point at a local sample; load your own image.

---

[Back to the inventory](../../README.md)
