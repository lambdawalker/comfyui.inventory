# ComfyInventory

Reproducible, per-workflow installers for the ComfyUI instance in `~/opt/ComfyUI`. Each folder holds a clean copy of the workflow JSON, a pinned `manifest.json`, and an `install.sh` that downloads exactly the models the workflow references.

The inventory was rebuilt from the saved workflows rather than from the older scripts in `~/opt/download`, so the file lists match what the workflows actually load. It was built against ComfyUI 0.37.0.

## Quick start

```bash
./comfy-inventory list
./comfy-inventory status
./comfy-inventory install z-image-t2i --dry-run
./comfy-inventory install z-image-t2i
./workflows/z-image-t2i/install.sh        # same thing
```

**Unique payload:** 37 files, 300.5 GiB (shared files are counted once).

## Workflows

| ID | Workflow file | Models | Size | Gated |
| --- | --- | ---: | ---: | :---: |
| [`yue2-text-to-music`](workflows/yue2-text-to-music/README.md) | `audio_yue2_text2music.json` | 1 | 7.3 GiB |  |
| [`flux2-klein-edit-9b`](workflows/flux2-klein-edit-9b/README.md) | `Flux2 Klein Edit 9b.json` | 3 | 17.2 GiB | yes |
| [`flux-outpaint`](workflows/flux-outpaint/README.md) | `Flux outpaint.json` | 4 | 31.8 GiB |  |
| [`krea2-style-transfer`](workflows/krea2-style-transfer/README.md) | `Krea2 Style Transfer.json` | 4 | 18.1 GiB |  |
| [`minimax-h3-image-to-video`](workflows/minimax-h3-image-to-video/README.md) | `MiniMax H3.json` | 5 | 39.1 GiB |  |
| [`qwen-image-2.1-edit`](workflows/qwen-image-2.1-edit/README.md) | `Qwen 2.1 Edit.json` | 4 | 24.9 GiB |  |
| [`qwen-image-2.1-t2i`](workflows/qwen-image-2.1-t2i/README.md) | `Qwen image 2.1.json` | 4 | 24.9 GiB |  |
| [`qwen-image-2511-edit`](workflows/qwen-image-2511-edit/README.md) | `Qwen image 2511 edit.json` | 4 | 28.9 GiB |  |
| [`qwen-image-2.1-outpaint`](workflows/qwen-image-2.1-outpaint/README.md) | `qwen-outpaint.json` | 4 | 16.2 GiB |  |
| [`z-image-t2i`](workflows/z-image-t2i/README.md) | `Z Image.json` | 3 | 19.3 GiB |  |
| [`id-card-layer-split`](workflows/id-card-layer-split/README.md) | `ID Card Layer Split.json` | 3 | 47.0 GiB |  |
| [`id-card-inpaint-qwen-instantx`](workflows/id-card-inpaint-qwen-instantx/README.md) | `ID Card Inpaint.json` | 5 | 33.5 GiB |  |

## Legacy recipes

These entries correspond to the old scripts that have no saved workflow JSON in this ComfyUI installation. They install models (and, for the separation recipe, the sample input) but cannot install a workflow file.

| ID | Models | Size | Notes |
| --- | ---: | ---: | --- |
| [`fired-image-edit-1.1`](recipes/fired-image-edit-1.1/README.md) | 4 | 47.8 GiB | model set only |
| [`flux2-klein-edit-4b`](recipes/flux2-klein-edit-4b/README.md) | 3 | 11.5 GiB | model set only |
| [`qwen-image-2.1-separation`](recipes/qwen-image-2.1-separation/README.md) | 4 | 16.1 GiB | model set only |

## Layout

```text
ComfyInventory/
├── comfy-inventory              # convenience launcher
├── bin/comfy-inventory          # CLI: list, status, install, verify, doctor
├── lib/                         # shared shell implementation
├── workflows/<id>/
│   ├── workflow.json            # exact copy of the saved workflow
│   ├── manifest.json            # pinned URLs, sizes and SHA-256 values
│   ├── install.sh               # thin wrapper around the CLI
│   └── README.md                # file list and workflow-specific notes
├── recipes/<id>/                # legacy model-only entries (no JSON)
├── tests/smoke.sh               # isolated installer smoke test
└── tools/                       # build.py and audit.py
```

## What the installer does

- **Derives the file list from the workflow**, not from a hand-written script.
- **Pins every file** with its byte size and SHA-256. Existing files are checked by size; use `--verify` to hash them.
- **Accepts documented alternate checksums** for known local revisions (currently the FireRed transformer); fresh downloads use the primary pin.
- **Downloads into a staging area** (`<COMFY_DIR>/.cache/comfy-inventory`) and moves files into `models/` only after the checksum passes, so ComfyUI never sees a partial model.
- **Resumes partial downloads** with aria2, or falls back to `curl -C -`.
- **Is non-interactive** by default. Existing files are kept; mismatches fail loudly instead of being overwritten.
- **Scopes the Hugging Face token** to `huggingface.co` URLs and only sends it for models marked gated.
- **Copies the workflow** into `ComfyUI/user/default/workflows/` unless `--no-workflow` is used. A differing workflow is never overwritten without `--force-workflow` (which keeps a timestamped backup).

## Adding or updating a workflow

1. Save the workflow in ComfyUI so it appears in `ComfyUI/user/default/workflows/`.
2. Add or update its entry in `tools/build.py` (`WORKFLOWS` for full workflows, `RECIPES` for model-only sets).
3. Run `python3 tools/build.py` (or `--offline` to reuse existing pins).
4. Run `python3 tools/audit.py` to confirm the manifest matches the JSON.

A manifest is a small JSON file:

```json
{
  "schema_version": 1,
  "id": "example",
  "name": "Example workflow",
  "workflow": {"file": "workflow.json", "install_as": "Example.json", "sha256": "…"},
  "models": [{"name": "model.safetensors", "path": "models/vae/model.safetensors",
              "url": "https://huggingface.co/…", "size": 123, "sha256": "…", "gated": false}]
}
```

`path` must be relative and start with `models/` or `input/`. `gated` attaches the Hugging Face token (use it for gated or private HF repos). `alternate_sha256` is optional and only for documented, known-good revisions.

## Commands

| Command | Purpose |
| --- | --- |
| `./comfy-inventory list` | List workflow folders and their sizes |
| `./comfy-inventory status [id ...]` | Show present/missing files |
| `./comfy-inventory install <id ...>` | Install one or more workflows or recipes |
| `./comfy-inventory install --all` | Install every workflow and recipe |
| `./comfy-inventory verify [id ...]` | Hash installed files |
| `./comfy-inventory doctor` | Check dependencies, paths, token and disk |

Common flags: `--comfy-dir`, `--dry-run`, `--repair`, `--force`, `--verify`, `--jobs N`, `--downloader auto|aria2c|curl`, `--no-workflow`, `--force-workflow`, `--workflow-only`, `--quiet`.
Run `./comfy-inventory --help` for the full list.

### Repairing an installation

```bash
# Hash everything and report mismatches without changing files
./comfy-inventory install z-image-t2i --verify

# Replace only files that are missing or have the wrong size/checksum
./comfy-inventory install z-image-t2i --repair

# Re-download every model in the workflow
./comfy-inventory install z-image-t2i --force
```

## Gated models

`flux2-klein-edit-9b` uses the [gated BFL checkpoint](https://huggingface.co/black-forest-labs/FLUX.2-klein-base-9b-fp8). Accept the license there, then provide a token via `HF_TOKEN` or `huggingface-cli login`. The installer preflights gated access and prints the exact repository URL if access is denied.

## Requirements

- Linux with Bash 4.3+ (the tested target); macOS may work with GNU coreutils
- `jq`, `curl`, `sha256sum` (or `shasum`), `awk`, `df`
- `aria2c` strongly recommended; `curl` is used as a fallback
- Optional: `flock` for a proper install lock (a mkdir fallback is used)
- Python 3.9+ only for `tools/build.py` and `tools/audit.py`

## Regenerating

```bash
python3 tools/build.py             # copy workflows + refresh HF sizes/hashes
python3 tools/build.py --offline   # reuse checksums from existing manifests
python3 tools/audit.py             # check manifests against workflow JSON
```

`tools/build.py` reads workflow JSON from `ComfyUI/user/default/workflows/` and requires network access unless `--offline` is used.

## Testing

```bash
./tests/smoke.sh        # isolated download/repair/verify test (~1.2 MiB, network)
python3 tools/audit.py  # manifests vs. workflow JSON
```

## Relationship to `~/opt/download`

The old scripts are left in place as an archive. This table maps them to their replacements.

| Old script | New entry |
| --- | --- |
| `download_fired_text_to_image.sh` | `recipes/fired-image-edit-1.1` (model set only) |
| `download_flux2_klein_image_edit_9b.sh` | `workflows/flux2-klein-edit-9b` |
| `download_flux2_klein_image_edit.sh` | `recipes/flux2-klein-edit-4b` (model set only) |
| `download_flux_fill.sh` | `workflows/flux-outpaint` |
| `download_krea_2_turbo_style_transfer.sh` | `workflows/krea2-style-transfer` |
| `download_minimax_h3_image_to_video.sh` | `workflows/minimax-h3-image-to-video` |
| `download_qwen_2-1_edit.sh` | `workflows/qwen-image-2.1-edit` |
| `download_qwen_2.1_separation.sh` | `recipes/qwen-image-2.1-separation` (model set only) |
| `download_qwen_2-1.sh` | `workflows/qwen-image-2.1-t2i` |
| `download_qwen_2_1_outpiant.sh` | `workflows/qwen-image-2.1-outpaint` |
| `download_qwen_edit_2511_int8.sh` | `workflows/qwen-image-2511-edit` |
| `download_z_image.sh` | `workflows/z-image-t2i` |
| `install_ace_step_1.5_models.sh` | **no equivalent** — the saved audio workflow is YuE2, not ACE-Step; see `workflows/yue2-text-to-music` |

Notable fixes made while rebuilding:

- The old FireRed script contained stray `[cite: N]` text inside its model array; the new manifest has clean URLs.
- The old MiniMax script downloaded a template input image that the saved workflow does not use.
- The old audio script installed ACE-Step 1.5, but the saved workflow is YuE2 and its active checkpoint is bf16.
- The old Qwen outpaint script downloaded both v1 and v2 LoRAs; the workflow uses v2 only.
- The installed FireRed transformer is a valid alternate revision with a different checksum from current upstream; the recipe accepts both and documents the difference.
