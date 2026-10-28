# ID Card - Layer Split (Qwen-Image-Layered Control)

Prompt-controlled extraction of ID-card layers as RGBA images using Qwen-Image-Layered Control.

## Install

```bash
./workflows/id-card-layer-split/install.sh
# or from the inventory root:
./comfy-inventory install id-card-layer-split
```

## Files

| Destination | Size | SHA-256 |
| --- | ---: | --- |
| `models/diffusion_models/qwen_image_layered_control_bf16.safetensors` | 38.1 GiB | `63b1966f0423bdc9…` |
| `models/vae/qwen_image_layered_vae.safetensors` | 242.1 MiB | `c5320595fc61859c…` |
| `models/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors` | 8.7 GiB | `cb5636d852a0ea6a…` |

## Workflow

Clean copy: [`workflow.json`](workflow.json)  
SHA-256: `3d42eb832e84c27ae0154dbccd4ccdab5679caef8ab89df872e1f3b8f3d551fc`  
Installed as `ID Card Layer Split.json` under `ComfyUI/user/default/workflows/`.

## Notes

- The Control model extracts one layer per prompt. Run the workflow once for each target layer: portrait photo, printed text, hologram, security overlay, and background.
- Use exact OCR strings for text layers, e.g. `Text "SURNAME"`. The model was trained on English prompts and supports negative prompts through the subgraph's Negative Prompt node.
- The Control model is strongest on poster-like graphics and weaker on heavily overlapping or occluded elements. Holograms over photo/text may need a second pass.
- 1024 px input can lose microtext. For pixel-exact text or overlays, use SAM 3.1 masks, PaddleOCR boxes, and inpainting on the original scan instead of generative extraction.
- Holograms are view-dependent; a single photo only captures one projection. Use a screen/overlay blend for the extracted hologram layer.
- Only process ID cards you are authorized to handle; run locally and avoid uploading real IDs to cloud services.

---

[Back to the inventory](../../README.md)
