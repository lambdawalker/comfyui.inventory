# Z Image - Text to Image

Z Image base text-to-image workflow.

## Install

```bash
./workflows/z-image-t2i/install.sh
# or from the inventory root:
./comfy-inventory install z-image-t2i
```

## Files

| Destination | Size | SHA-256 |
| --- | ---: | --- |
| `models/diffusion_models/z_image_bf16.safetensors` | 11.5 GiB | `996a67d3ff666946…` |
| `models/text_encoders/qwen_3_4b.safetensors` | 7.5 GiB | `6c671498573ac2f7…` |
| `models/vae/ae.safetensors` | 319.8 MiB | `afc8e28272cd15db…` |

## Workflow

Clean copy: [`workflow.json`](workflow.json)  
SHA-256: `a7a1e8c3da2e436c7964cde2a246e996139f882db8ee7d184124b1cbf20f09f0`  
Installed as `Z Image.json` under `ComfyUI/user/default/workflows/`.

---

[Back to the inventory](../../README.md)
