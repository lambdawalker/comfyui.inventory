# FireRed Image Edit 1.1 (legacy recipe)

FireRed Image Edit 1.1 model set recovered from the legacy download script.

> **Legacy recipe:** no saved workflow JSON was found for this entry. It installs the model set only.

## Install

```bash
./recipes/fired-image-edit-1.1/install.sh
# or from the inventory root:
./comfy-inventory install fired-image-edit-1.1
```

## Files

| Destination | Size | SHA-256 |
| --- | ---: | --- |
| `models/diffusion_models/FireRed-Image-Edit-1.1-transformer.safetensors` | 38.1 GiB | `004b0326de38ffee…` |
| `models/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors` | 8.7 GiB | `cb5636d852a0ea6a…` |
| `models/vae/qwen_image_vae.safetensors` | 242.0 MiB | `a70580f0213e6796…` |
| `models/loras/FireRed-Image-Edit-1.0-Lightning-8steps-v1.0.safetensors` | 810.2 MiB | `dc65fec1f5b92aa1…` |

Known alternate checksums are accepted for existing files (fresh downloads use the primary pin):

- `FireRed-Image-Edit-1.1-transformer.safetensors`: `0d33c56b63f3b0819dd476bc6264a520a73614d1549197ce2bb06c99e28440b8`

## Notes

- No saved workflow JSON for FireRed exists under `ComfyUI/user/default/workflows`; this recipe only installs the model set.
- The old `download_fired_text_to_image.sh` script contained stray `[cite: N]` tokens in its model registry. The URLs here are clean and checksum-pinned.
- The installed transformer is a valid safetensors file with SHA-256 `0d33c56b…`, while the current upstream file is `004b0326…`. Both checksums are accepted for an existing file; a fresh download uses the current upstream pin. This is a documented alternate revision, not corruption.

---

[Back to the inventory](../../README.md)
