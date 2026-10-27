# FLUX.2 Klein 9B - Image Edit

FLUX.2 Klein 9B image editing with the FLUX.2 small-decoder VAE.

## Install

```bash
./workflows/flux2-klein-edit-9b/install.sh
# or from the inventory root:
./comfy-inventory install flux2-klein-edit-9b
```

## Files

| Destination | Size | SHA-256 |
| --- | ---: | --- |
| `models/diffusion_models/flux-2-klein-base-9b-fp8.safetensors` (gated) | 8.9 GiB | `a9f5028c24a7a96f…` |
| `models/text_encoders/qwen_3_8b_fp8mixed.safetensors` | 8.1 GiB | `abad16806e0cbabc…` |
| `models/vae/full_encoder_small_decoder.safetensors` | 238.0 MiB | `ea4273f02d1fafbf…` |

## Workflow

Clean copy: [`workflow.json`](workflow.json)  
SHA-256: `1a635d1a0f84b57f9206c316c6728a3164c32e9c8a95346377196d0842fa2506`  
Installed as `Flux2 Klein Edit 9b.json` under `ComfyUI/user/default/workflows/`.

## Notes

- The diffusion checkpoint is in a gated Hugging Face repository. Accept the license on [the model page](https://huggingface.co/black-forest-labs/FLUX.2-klein-base-9b-fp8) and make sure a token is available (`HF_TOKEN` or `huggingface-cli login`).
- The saved workflow contains two copies of the 9B edit subgraph; both use the same three files.

---

[Back to the inventory](../../README.md)
