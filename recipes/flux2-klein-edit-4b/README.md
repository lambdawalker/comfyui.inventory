# FLUX.2 Klein 4B - Image Edit (legacy recipe)

FLUX.2 Klein 4B image-edit model set from the legacy download script.

> **Legacy recipe:** no saved workflow JSON was found for this entry. It installs the model set only.

## Install

```bash
./recipes/flux2-klein-edit-4b/install.sh
# or from the inventory root:
./comfy-inventory install flux2-klein-edit-4b
```

## Files

| Destination | Size | SHA-256 |
| --- | ---: | --- |
| `models/diffusion_models/flux-2-klein-base-4b-fp8.safetensors` | 3.8 GiB | `44bab3a86fe98b85…` |
| `models/text_encoders/qwen_3_4b.safetensors` | 7.5 GiB | `6c671498573ac2f7…` |
| `models/vae/full_encoder_small_decoder.safetensors` | 238.0 MiB | `ea4273f02d1fafbf…` |

## Notes

- No saved workflow JSON for the 4B variant exists under `ComfyUI/user/default/workflows`; this recipe only installs the model set.
- Some generated PNGs in `ComfyUI/output` contain an embedded FLUX.2 Klein 4B workflow if you need to recover it.

---

[Back to the inventory](../../README.md)
