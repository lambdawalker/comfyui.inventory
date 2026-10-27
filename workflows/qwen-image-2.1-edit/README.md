# Qwen Image 2.1 - Image Edit

Qwen Image 2.1 instruction-based image editing, including the i2i prompt enhancer.

## Install

```bash
./workflows/qwen-image-2.1-edit/install.sh
# or from the inventory root:
./comfy-inventory install qwen-image-2.1-edit
```

## Files

| Destination | Size | SHA-256 |
| --- | ---: | --- |
| `models/diffusion_models/qwen_image_2.1_int8_convrot.safetensors` | 6.8 GiB | `cb74113cb03faecd…` |
| `models/text_encoders/qwen3vl_8b_int8_convrot.safetensors` | 8.7 GiB | `8bfd0f6e12abf2d2…` |
| `models/text_encoders/qwen3.5_9b_qwen_image_2.1_pe_i2i.int8_convrot.safetensors` | 8.8 GiB | `32707d01b427e488…` |
| `models/vae/qwen_image_2.1_vae_bf16.safetensors` | 644.2 MiB | `bb21f7473051e1ac…` |

## Workflow

Clean copy: [`workflow.json`](workflow.json)  
SHA-256: `39512ef16b7fe09e56fdaa21fd9abfd6b4be972b1eca0711278bff8994e5521e`  
Installed as `Qwen 2.1 Edit.json` under `ComfyUI/user/default/workflows/`.

## Notes

- Two text encoders are required: the main Qwen3-VL encoder and the Qwen 3.5 image-edit prompt enhancer.
- The workflow loads source images through its subgraph/BatchImages node; no sample images are bundled.

---

[Back to the inventory](../../README.md)
