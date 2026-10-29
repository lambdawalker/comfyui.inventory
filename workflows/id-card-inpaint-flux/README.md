# ID Card - Inpaint (FLUX.1 Fill)

Mask inpainting for ID-card backgrounds using the installed FLUX.1 Fill model.

## Install

```bash
./workflows/id-card-inpaint-flux/install.sh
# or from the inventory root:
./comfy-inventory install id-card-inpaint-flux
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
SHA-256: `aa76c744b06c1069f064d63c68dc18d89cc381b69566de1726b286acc0588bdb`  
Installed as `ID Card Inpaint FLUX.json` under `ComfyUI/user/default/workflows/`.

## Notes

- Upload the card as `id_card.png`, paint only the area to remove with MaskEditor, and edit the top-level `Inpaint prompt` node.
- The workflow uses FLUX.1 Fill at 20 steps, CFG 1, FluxGuidance 30. It needs no new downloads; the model and encoders are already installed.
- The `Composite original outside mask` output (`id-card-inpaint-flux`) restores exact original pixels outside the mask.
- FLUX Fill is a general inpainting model and may smear fine guilloche/microprint. Switch to `id-card-inpaint-qwen-instantx` if structure preservation matters.
- Exact security print hidden behind a photo or hologram cannot be recovered; clone nearby pattern regions or redraw when exactness matters.
- Only process ID cards you are authorized to handle; run locally and avoid uploading real IDs to cloud services.

---

[Back to the inventory](../../README.md)
