# ID Card - Inpaint (Qwen-Image InstantX ControlNet)

Mask inpainting for ID-card backgrounds using Qwen-Image with the InstantX Inpainting ControlNet.

## Install

```bash
./workflows/id-card-inpaint-qwen-instantx/install.sh
# or from the inventory root:
./comfy-inventory install id-card-inpaint-qwen-instantx
```

## Files

| Destination | Size | SHA-256 |
| --- | ---: | --- |
| `models/diffusion_models/qwen_image_fp8_e4m3fn.safetensors` | 19.0 GiB | `98763a127701eb6f…` |
| `models/controlnet/Qwen-Image-InstantX-ControlNet-Inpainting.safetensors` | 3.9 GiB | `49c01aafe6545c1f…` |
| `models/loras/Qwen-Image-Lightning-4steps-V1.0.safetensors` | 1.6 GiB | `9526e90d71c42903…` |
| `models/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors` | 8.7 GiB | `cb5636d852a0ea6a…` |
| `models/vae/qwen_image_vae.safetensors` | 242.0 MiB | `a70580f0213e6796…` |

## Workflow

Clean copy: [`workflow.json`](workflow.json)  
SHA-256: `cd0a4f8f8754e737126c32625eca53030eedb1c50963e1dbc3c0211fa20d6ccc`  
Installed as `ID Card Inpaint.json` under `ComfyUI/user/default/workflows/`.

## Notes

- Paint the area to remove in MaskEditor: portrait photo, a text block, a hologram patch, or an overlay. Inpaint one small region at a time.
- The active 20-step branch is quality-oriented. Enable the bypassed 4-step Lightning branch for faster iterations; the Lightning LoRA is included.
- Use the `ImageCompositeMasked` output (`id-card-inpaint`) to preserve the exact original pixels outside the mask. The raw output is `id-card-inpaint-raw`.
- Exact guilloche/microprint hidden behind a photo or hologram cannot be recovered; inpainting produces a plausible continuation. Clone nearby pattern regions or redraw security print when exactness matters.
- Only process ID cards you are authorized to handle; run locally and avoid uploading real IDs to cloud services.

---

[Back to the inventory](../../README.md)
