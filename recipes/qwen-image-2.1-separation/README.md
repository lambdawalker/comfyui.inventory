# Qwen Image 2.1 - Background Separation (legacy recipe)

Qwen Image 2.1 background-removal model set plus the template's sample input.

> **Legacy recipe:** no saved workflow JSON was found for this entry. It installs the model set only.

## Install

```bash
./recipes/qwen-image-2.1-separation/install.sh
# or from the inventory root:
./comfy-inventory install qwen-image-2.1-separation
```

## Files

| Destination | Size | SHA-256 |
| --- | ---: | --- |
| `models/diffusion_models/qwen_image_2.1_int8_convrot.safetensors` | 6.8 GiB | `cb74113cb03faecd…` |
| `models/text_encoders/qwen3vl_8b_int8_convrot.safetensors` | 8.7 GiB | `8bfd0f6e12abf2d2…` |
| `models/vae/qwen_image_2.1_vae_bf16.safetensors` | 644.2 MiB | `bb21f7473051e1ac…` |
| `input/angry_broccoli.png` | 1.1 MiB | `a407007c0d3d06c8…` |

## Notes

- No saved workflow JSON for this variant exists under `ComfyUI/user/default/workflows`; this recipe installs the model set and sample input only.

---

[Back to the inventory](../../README.md)
