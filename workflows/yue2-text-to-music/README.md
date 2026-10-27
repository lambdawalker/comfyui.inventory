# YuE2 - Text to Music

YuE2 text-to-music with native vocals and instrumental accompaniment.

## Install

```bash
./workflows/yue2-text-to-music/install.sh
# or from the inventory root:
./comfy-inventory install yue2-text-to-music
```

## Files

| Destination | Size | SHA-256 |
| --- | ---: | --- |
| `models/checkpoints/yue2_3b_bf16.safetensors` | 7.3 GiB | `33765adbf9813c9a…` |

## Workflow

Clean copy: [`workflow.json`](workflow.json)  
SHA-256: `fcb17c21ca80356421e62db76353c0ffdb87ad847714e068000ceb4243a0415b`  
Installed as `audio_yue2_text2music.json` under `ComfyUI/user/default/workflows/`.

## Notes

- The saved workflow promotes a `ckpt_name` widget on the subgraph. Its active value is `yue2_3b_bf16.safetensors`, even though the inner loader and the Markdown note mention the int8 file.
- To switch the workflow to the int8 checkpoint, also download `Comfy-Org/YuE2/checkpoints/yue2_3b_int8_convrot.safetensors`.
- The old `install_ace_step_1.5_models.sh` script is unrelated to this workflow; ACE-Step is not used by YuE2.

---

[Back to the inventory](../../README.md)
