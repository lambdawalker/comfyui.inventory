# Qwen Image 2.1 - Text to Image

Qwen Image 2.1 text-to-image with the t2i prompt enhancer.

## Install

```bash
./workflows/qwen-image-2.1-t2i/install.sh
# or from the inventory root:
./comfy-inventory install qwen-image-2.1-t2i
```

## Files

| Destination | Size | SHA-256 |
| --- | ---: | --- |
| `models/diffusion_models/qwen_image_2.1_int8_convrot.safetensors` | 6.8 GiB | `cb74113cb03faecd…` |
| `models/text_encoders/qwen3vl_8b_int8_convrot.safetensors` | 8.7 GiB | `8bfd0f6e12abf2d2…` |
| `models/text_encoders/qwen3.5_9b_qwen_image_2.1_pe_t2i.int8_convrot.safetensors` | 8.8 GiB | `9182abae56fe0545…` |
| `models/vae/qwen_image_2.1_vae_bf16.safetensors` | 644.2 MiB | `bb21f7473051e1ac…` |

## Workflow

Clean copy: [`workflow.json`](workflow.json)  
SHA-256: `381ed14caf52f77a2496e72afdef1b6cdb8704e577101ad08d6f1e2fa4e356ba`  
Installed as `Qwen image 2.1.json` under `ComfyUI/user/default/workflows/`.

## Notes

- Two text encoders are required: the main Qwen3-VL encoder and the Qwen 3.5 text-to-image prompt enhancer.

---

[Back to the inventory](../../README.md)
