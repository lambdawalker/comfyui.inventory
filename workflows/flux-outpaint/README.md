# FLUX.1 Fill Dev - Outpaint

FLUX.1 Fill Dev outpainting and inpainting workflow.

## Install

```bash
./workflows/flux-outpaint/install.sh
# or from the inventory root:
./comfy-inventory install flux-outpaint
```

## Files

| Destination | Size | SHA-256 |
| --- | ---: | --- |
| `models/diffusion_models/flux1-fill-dev.safetensors` | 22.2 GiB | `03e289f530df51d0…` |
| `models/text_encoders/clip_l.safetensors` | 234.7 MiB | `660c6f5b1abae9dc…` |
| `models/text_encoders/t5xxl_fp16.safetensors` | 9.1 GiB | `6e480b09fae049a7…` |
| `models/vae/ae.safetensors` | 319.8 MiB | `afc8e28272cd15db…` |

## Workflow

Clean copy: [`workflow.json`](workflow.json)  
SHA-256: `1370b86841733f61e2a675cce0c208bedf9d5b0d059f6457897e605243284f9b`  
Installed as `Flux outpaint.json` under `ComfyUI/user/default/workflows/`.

## Notes

- The `LoadImage` node points at a local sample image. Load your own source image; it is not bundled.

---

[Back to the inventory](../../README.md)
