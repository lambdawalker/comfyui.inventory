# MiniMax H3 - Image to Video

MiniMax H3 image-to-video with synchronized stereo audio.

## Install

```bash
./workflows/minimax-h3-image-to-video/install.sh
# or from the inventory root:
./comfy-inventory install minimax-h3-image-to-video
```

## Files

| Destination | Size | SHA-256 |
| --- | ---: | --- |
| `models/diffusion_models/minimax_h3_fl2va_pruned_int8_convrot.safetensors` | 19.5 GiB | `e889202c41dafb67…` |
| `models/text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors` | 14.6 GiB | `35a88d51044231fe…` |
| `models/vae/minimax_h3_video_vae_int8_convrot.safetensors` | 2.6 GiB | `52a2c8c73583c86e…` |
| `models/vae/minimax_h3_audio_vae_fp32.safetensors` | 577.2 MiB | `8e505d95dd1561d4…` |
| `models/loras/minimax_h3_fl2v_turbo_8step_v1.0_comfyui_bf16.safetensors` | 1.8 GiB | `2339acdf19bfe123…` |

## Workflow

Clean copy: [`workflow.json`](workflow.json)  
SHA-256: `0ff390fe70fe92365841d65f186871bdb357eec20725f77c1a0f916cd49e81f1`  
Installed as `MiniMax H3.json` under `ComfyUI/user/default/workflows/`.

## Notes

- The saved workflow's `LoadImage` nodes point at local sample images (`VB00.png`, etc.). They are not bundled; load your own first/last frames.
- The old download script fetched an unrelated template input image. The new installer intentionally does not.

---

[Back to the inventory](../../README.md)
