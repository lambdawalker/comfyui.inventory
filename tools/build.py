#!/usr/bin/env python3
"""Build the ComfyInventory tree from the workflows installed in ComfyUI.

This script is intentionally checked in so the inventory can be regenerated
when a workflow changes. It is not needed at install time.

Usage:
    python3 tools/build.py                # fetch fresh metadata from HF
    python3 tools/build.py --offline      # reuse checksums from existing manifests
    python3 tools/build.py --comfy-dir ~/opt/ComfyUI
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_COMFY = Path(os.environ.get("COMFY_DIR", Path.home() / "opt" / "ComfyUI"))
USER_AGENT = "ComfyInventory/1.0 (+https://github.com/Comfy-Org)"


# ---------------------------------------------------------------------------
# Catalogue
#
# Each model tuple is (hugging-face repo, file in repo, ComfyUI models/ subdir).
# Raw assets are (None, https URL, "input").
# ---------------------------------------------------------------------------
WORKFLOWS = [
    dict(
        id="yue2-text-to-music",
        source="audio_yue2_text2music.json",
        name="YuE2 - Text to Music",
        description="YuE2 text-to-music with native vocals and instrumental accompaniment.",
        models=[
            ("Comfy-Org/YuE2", "checkpoints/yue2_3b_bf16.safetensors", "checkpoints"),
        ],
        notes=[
            "The saved workflow promotes a `ckpt_name` widget on the subgraph. Its active value is "
            "`yue2_3b_bf16.safetensors`, even though the inner loader and the Markdown note mention the int8 file.",
            "To switch the workflow to the int8 checkpoint, also download "
            "`Comfy-Org/YuE2/checkpoints/yue2_3b_int8_convrot.safetensors`.",
            "The old `install_ace_step_1.5_models.sh` script is unrelated to this workflow; ACE-Step is not used by YuE2.",
        ],
    ),
    dict(
        id="flux2-klein-edit-9b",
        source="Flux2 Klein Edit 9b.json",
        name="FLUX.2 Klein 9B - Image Edit",
        description="FLUX.2 Klein 9B image editing with the FLUX.2 small-decoder VAE.",
        models=[
            ("black-forest-labs/FLUX.2-klein-base-9b-fp8", "flux-2-klein-base-9b-fp8.safetensors", "diffusion_models"),
            ("Comfy-Org/flux2-klein-9B", "split_files/text_encoders/qwen_3_8b_fp8mixed.safetensors", "text_encoders"),
            ("black-forest-labs/FLUX.2-small-decoder", "full_encoder_small_decoder.safetensors", "vae"),
        ],
        notes=[
            "The diffusion checkpoint is in a gated Hugging Face repository. Accept the license on "
            "[the model page](https://huggingface.co/black-forest-labs/FLUX.2-klein-base-9b-fp8) and make sure a token is available "
            "(`HF_TOKEN` or `huggingface-cli login`).",
            "The saved workflow contains two copies of the 9B edit subgraph; both use the same three files.",
        ],
    ),
    dict(
        id="flux-outpaint",
        source="Flux outpaint.json",
        name="FLUX.1 Fill Dev - Outpaint",
        description="FLUX.1 Fill Dev outpainting and inpainting workflow.",
        models=[
            ("Comfy-Org/flux1-dev", "split_files/diffusion_models/flux1-fill-dev.safetensors", "diffusion_models"),
            ("comfyanonymous/flux_text_encoders", "clip_l.safetensors", "text_encoders"),
            ("comfyanonymous/flux_text_encoders", "t5xxl_fp16.safetensors", "text_encoders"),
            ("Comfy-Org/Lumina_Image_2.0_Repackaged", "split_files/vae/ae.safetensors", "vae"),
        ],
        notes=[
            "The `LoadImage` node points at a local sample image. Load your own source image; it is not bundled.",
        ],
    ),
    dict(
        id="krea2-style-transfer",
        source="Krea2 Style Transfer.json",
        name="Krea-2 Turbo - Style Transfer",
        description="Krea-2 Turbo style-reference generation with the Krea-2 style LoRA.",
        models=[
            ("Comfy-Org/Krea-2", "diffusion_models/krea2_turbo_int8_convrot.safetensors", "diffusion_models"),
            ("Comfy-Org/Krea-2", "text_encoders/qwen3vl_4b_fp8_scaled.safetensors", "text_encoders"),
            ("Comfy-Org/Krea-2", "vae/qwen_image_vae.safetensors", "vae"),
            ("Comfy-Org/Krea-2", "loras/krea2_style_reference.safetensors", "loras"),
        ],
        notes=[
            "The workflow's `LoadImage` node expects `krea2_reference_image.png`; load your own reference image.",
        ],
    ),
    dict(
        id="minimax-h3-image-to-video",
        source="MiniMax H3.json",
        name="MiniMax H3 - Image to Video",
        description="MiniMax H3 image-to-video with synchronized stereo audio.",
        models=[
            ("Comfy-Org/MiniMax-H3", "diffusion_models/minimax_h3_fl2va_pruned_int8_convrot.safetensors", "diffusion_models"),
            ("Comfy-Org/MiniMax-H3", "text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors", "text_encoders"),
            ("Comfy-Org/MiniMax-H3", "vae/minimax_h3_video_vae_int8_convrot.safetensors", "vae"),
            ("Comfy-Org/MiniMax-H3", "vae/minimax_h3_audio_vae_fp32.safetensors", "vae"),
            ("lightx2v/Minimax-h3-Turbo", "minimax_h3_fl2v_turbo_8step_v1.0_comfyui_bf16.safetensors", "loras"),
        ],
        notes=[
            "The saved workflow's `LoadImage` nodes point at local sample images (`VB00.png`, etc.). "
            "They are not bundled; load your own first/last frames.",
            "The old download script fetched an unrelated template input image. The new installer intentionally does not.",
        ],
    ),
    dict(
        id="qwen-image-2.1-edit",
        source="Qwen 2.1 Edit.json",
        name="Qwen Image 2.1 - Image Edit",
        description="Qwen Image 2.1 instruction-based image editing, including the i2i prompt enhancer.",
        models=[
            ("Comfy-Org/Qwen-Image-2.1", "diffusion_models/qwen_image_2.1_int8_convrot.safetensors", "diffusion_models"),
            ("Comfy-Org/Qwen-Image-2.1", "text_encoders/qwen3vl_8b_int8_convrot.safetensors", "text_encoders"),
            ("Comfy-Org/Qwen-Image-2.1", "text_encoders/qwen3.5_9b_qwen_image_2.1_pe_i2i.int8_convrot.safetensors", "text_encoders"),
            ("Comfy-Org/Qwen-Image-2.1", "vae/qwen_image_2.1_vae_bf16.safetensors", "vae"),
        ],
        notes=[
            "Two text encoders are required: the main Qwen3-VL encoder and the Qwen 3.5 image-edit prompt enhancer.",
            "The workflow loads source images through its subgraph/BatchImages node; no sample images are bundled.",
        ],
    ),
    dict(
        id="qwen-image-2.1-t2i",
        source="Qwen image 2.1.json",
        name="Qwen Image 2.1 - Text to Image",
        description="Qwen Image 2.1 text-to-image with the t2i prompt enhancer.",
        models=[
            ("Comfy-Org/Qwen-Image-2.1", "diffusion_models/qwen_image_2.1_int8_convrot.safetensors", "diffusion_models"),
            ("Comfy-Org/Qwen-Image-2.1", "text_encoders/qwen3vl_8b_int8_convrot.safetensors", "text_encoders"),
            ("Comfy-Org/Qwen-Image-2.1", "text_encoders/qwen3.5_9b_qwen_image_2.1_pe_t2i.int8_convrot.safetensors", "text_encoders"),
            ("Comfy-Org/Qwen-Image-2.1", "vae/qwen_image_2.1_vae_bf16.safetensors", "vae"),
        ],
        notes=[
            "Two text encoders are required: the main Qwen3-VL encoder and the Qwen 3.5 text-to-image prompt enhancer.",
        ],
    ),
    dict(
        id="qwen-image-2511-edit",
        source="Qwen image 2511 edit.json",
        name="Qwen Image Edit 2511 - Int8 + Lightning",
        description="Qwen Image Edit 2511 int8 with the 4-step Lightning LoRA.",
        models=[
            ("Comfy-Org/Qwen-Image-Edit_ComfyUI", "split_files/diffusion_models/qwen_image_edit_2511_int8_convrot.safetensors", "diffusion_models"),
            ("Comfy-Org/HunyuanVideo_1.5_repackaged", "split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors", "text_encoders"),
            ("Comfy-Org/Qwen-Image_ComfyUI", "split_files/vae/qwen_image_vae.safetensors", "vae"),
            ("lightx2v/Qwen-Image-Edit-2511-Lightning", "Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors", "loras"),
        ],
        notes=[
            "The Lightning LoRA is applied by the workflow; keep it in `models/loras`.",
            "The workflow's `LoadImage` nodes use local sample files; load your own source image.",
        ],
    ),
    dict(
        id="qwen-image-2.1-outpaint",
        source="qwen-outpaint.json",
        name="Qwen Image 2.1 - Outpaint",
        description="Qwen Image 2.1 outpainting with the v2 outpaint LoRA.",
        models=[
            ("Comfy-Org/Qwen-Image-2.1", "diffusion_models/qwen_image_2.1_int8_convrot.safetensors", "diffusion_models"),
            ("Comfy-Org/Qwen-Image-2.1", "text_encoders/qwen3vl_8b_int8_convrot.safetensors", "text_encoders"),
            ("Comfy-Org/Qwen-Image-2.1", "vae/qwen_image_2.1_vae_bf16.safetensors", "vae"),
            ("ausboss/Qwen-Image-2.1-Outpaint-LoRA", "qwen-image-2.1-outpaint-v2.safetensors", "loras"),
        ],
        notes=[
            "This workflow uses the v2 outpaint LoRA. The older `qwen-image-2.1-outpaint.safetensors` file is not required.",
            "The workflow's `LoadImage` nodes are empty or point at a local sample; load your own image.",
        ],
    ),
    dict(
        id="z-image-t2i",
        source="Z Image.json",
        name="Z Image - Text to Image",
        description="Z Image base text-to-image workflow.",
        models=[
            ("Comfy-Org/z_image", "split_files/diffusion_models/z_image_bf16.safetensors", "diffusion_models"),
            ("Comfy-Org/z_image_turbo", "split_files/text_encoders/qwen_3_4b.safetensors", "text_encoders"),
            ("Comfy-Org/z_image_turbo", "split_files/vae/ae.safetensors", "vae"),
        ],
        notes=[],
    ),
    dict(
        id="id-card-layer-split",
        source="ID Card Layer Split.json",
        name="ID Card - Layer Split (Qwen-Image-Layered Control)",
        description="Prompt-controlled extraction of ID-card layers as RGBA images using Qwen-Image-Layered Control.",
        models=[
            ("DiffSynth-Studio/Qwen-Image-Layered-Control", "qwen_image_layered_control_bf16.safetensors", "diffusion_models"),
            ("Comfy-Org/Qwen-Image-Layered_ComfyUI", "split_files/vae/qwen_image_layered_vae.safetensors", "vae"),
            ("Comfy-Org/HunyuanVideo_1.5_repackaged", "split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors", "text_encoders"),
        ],
        notes=[
            "The Control model extracts one layer per prompt. Run the workflow once for each target layer: portrait photo, printed text, hologram, security overlay, and background.",
            "Use exact OCR strings for text layers, e.g. `Text \"SURNAME\"`. The model was trained on English prompts and supports negative prompts through the subgraph's Negative Prompt node.",
            "The Control model is strongest on poster-like graphics and weaker on heavily overlapping or occluded elements. Holograms over photo/text may need a second pass.",
            "1024 px input can lose microtext. For pixel-exact text or overlays, use SAM 3.1 masks, PaddleOCR boxes, and inpainting on the original scan instead of generative extraction.",
            "Holograms are view-dependent; a single photo only captures one projection. Use a screen/overlay blend for the extracted hologram layer.",
            "Only process ID cards you are authorized to handle; run locally and avoid uploading real IDs to cloud services.",
        ],
    ),
]

RECIPES = [
    dict(
        id="fired-image-edit-1.1",
        name="FireRed Image Edit 1.1 (legacy recipe)",
        description="FireRed Image Edit 1.1 model set recovered from the legacy download script.",
        models=[
            ("FireRedTeam/FireRed-Image-Edit-1.1-ComfyUI", "FireRed-Image-Edit-1.1-transformer.safetensors", "diffusion_models"),
            ("Comfy-Org/HunyuanVideo_1.5_repackaged", "split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors", "text_encoders"),
            ("FireRedTeam/FireRed-Image-Edit-1.0-ComfyUI", "qwen_image_vae.safetensors", "vae"),
            ("FireRedTeam/FireRed-Image-Edit-1.0-ComfyUI", "FireRed-Image-Edit-1.0-Lightning-8steps-v1.0.safetensors", "loras"),
        ],
        alternates={
            "FireRed-Image-Edit-1.1-transformer.safetensors": [
                "0d33c56b63f3b0819dd476bc6264a520a73614d1549197ce2bb06c99e28440b8"
            ]
        },
        notes=[
            "No saved workflow JSON for FireRed exists under `ComfyUI/user/default/workflows`; this recipe only installs the model set.",
            "The old `download_fired_text_to_image.sh` script contained stray `[cite: N]` tokens in its model registry. "
            "The URLs here are clean and checksum-pinned.",
            "The installed transformer is a valid safetensors file with SHA-256 `0d33c56b…`, while the current upstream "
            "file is `004b0326…`. Both checksums are accepted for an existing file; a fresh download uses the current "
            "upstream pin. This is a documented alternate revision, not corruption.",
        ],
    ),
    dict(
        id="flux2-klein-edit-4b",
        name="FLUX.2 Klein 4B - Image Edit (legacy recipe)",
        description="FLUX.2 Klein 4B image-edit model set from the legacy download script.",
        models=[
            ("black-forest-labs/FLUX.2-klein-base-4b-fp8", "flux-2-klein-base-4b-fp8.safetensors", "diffusion_models"),
            ("Comfy-Org/z_image_turbo", "split_files/text_encoders/qwen_3_4b.safetensors", "text_encoders"),
            ("black-forest-labs/FLUX.2-small-decoder", "full_encoder_small_decoder.safetensors", "vae"),
        ],
        notes=[
            "No saved workflow JSON for the 4B variant exists under `ComfyUI/user/default/workflows`; this recipe only installs the model set.",
            "Some generated PNGs in `ComfyUI/output` contain an embedded FLUX.2 Klein 4B workflow if you need to recover it.",
        ],
    ),
    dict(
        id="qwen-image-2.1-separation",
        name="Qwen Image 2.1 - Background Separation (legacy recipe)",
        description="Qwen Image 2.1 background-removal model set plus the template's sample input.",
        models=[
            ("Comfy-Org/Qwen-Image-2.1", "diffusion_models/qwen_image_2.1_int8_convrot.safetensors", "diffusion_models"),
            ("Comfy-Org/Qwen-Image-2.1", "text_encoders/qwen3vl_8b_int8_convrot.safetensors", "text_encoders"),
            ("Comfy-Org/Qwen-Image-2.1", "vae/qwen_image_2.1_vae_bf16.safetensors", "vae"),
            (None, "https://raw.githubusercontent.com/Comfy-Org/workflow_templates/refs/heads/main/input/angry_broccoli.png", "input"),
        ],
        notes=[
            "No saved workflow JSON for this variant exists under `ComfyUI/user/default/workflows`; this recipe installs the model set and sample input only.",
        ],
    ),
]


class Metadata:
    def __init__(self, offline: bool, token: str):
        self.offline = offline
        self.token = token
        self.repo_cache: dict[str, dict[str, dict]] = {}
        self.raw_cache: dict[str, dict] = {}
        self.existing: dict[str, dict] = {}
        if offline:
            self._load_existing()

    def _load_existing(self) -> None:
        for base in (ROOT / "workflows", ROOT / "recipes"):
            if not base.is_dir():
                continue
            for manifest in base.glob("*/manifest.json"):
                try:
                    data = json.loads(manifest.read_text())
                except Exception:
                    continue
                for model in data.get("models", []):
                    url = model.get("url")
                    if url:
                        self.existing[url] = {
                            "size": model["size"],
                            "sha256": model["sha256"],
                            "gated": bool(model.get("gated", False)),
                        }

    def _request(self, url: str) -> bytes:
        headers = {"User-Agent": USER_AGENT}
        host = urllib.parse.urlparse(url).hostname or ""
        # Never leak a Hugging Face token to GitHub or other hosts.
        if self.token and host in ("huggingface.co", "hf.co"):
            headers["Authorization"] = f"Bearer {self.token}"
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=120) as response:
            return response.read()

    def repo(self, repo: str) -> dict[str, dict]:
        if repo in self.repo_cache:
            return self.repo_cache[repo]
        if self.offline:
            raise RuntimeError(f"offline mode cannot look up repo {repo}")

        quoted = urllib.parse.quote(repo, safe="/")
        url = f"https://huggingface.co/api/models/{quoted}?blobs=true"
        try:
            payload = json.loads(self._request(url))
        except urllib.error.HTTPError as exc:
            raise RuntimeError(
                f"Hugging Face API returned HTTP {exc.code} for {repo}. "
                "If this is a gated repo, accept its terms and set HF_TOKEN."
            ) from exc
        except Exception as exc:
            raise RuntimeError(f"could not fetch metadata for {repo}: {exc}") from exc

        siblings: dict[str, dict] = {}
        gated = bool(payload.get("gated", False))
        for sibling in payload.get("siblings", []):
            name = sibling.get("rfilename")
            if not name:
                continue
            lfs = sibling.get("lfs") or {}
            siblings[name] = {
                "size": sibling.get("size"),
                "sha256": lfs.get("sha256"),
                "gated": gated,
            }
        self.repo_cache[repo] = siblings
        return siblings

    def hf_model(self, repo: str, filename: str) -> dict:
        url = f"https://huggingface.co/{repo}/resolve/main/{filename}"
        if self.offline:
            if url in self.existing:
                return dict(self.existing[url], url=url)
            raise RuntimeError(
                f"offline mode has no cached checksum for {url}. "
                "Run once without --offline to populate manifests."
            )

        sibling = self.repo(repo).get(filename)
        if not sibling:
            raise RuntimeError(f"{filename!r} not found in {repo}")
        if not sibling.get("size") or not sibling.get("sha256"):
            raise RuntimeError(
                f"{repo}/{filename} is not an LFS file with a sha256; refusing to guess"
            )
        return {
            "url": url,
            "size": int(sibling["size"]),
            "sha256": sibling["sha256"],
            "gated": bool(sibling.get("gated", False)),
        }

    def raw_asset(self, url: str) -> dict:
        if url in self.raw_cache:
            return self.raw_cache[url]
        if self.offline:
            if url in self.existing:
                return dict(self.existing[url], url=url)
            raise RuntimeError(f"offline mode has no cached checksum for {url}")
        try:
            payload = self._request(url)
        except Exception as exc:
            raise RuntimeError(f"could not download raw asset {url}: {exc}") from exc
        result = {
            "url": url,
            "size": len(payload),
            "sha256": hashlib.sha256(payload).hexdigest(),
            "gated": False,
        }
        self.raw_cache[url] = result
        return result


def human_size(num: int) -> str:
    value = float(num)
    for unit in ("B", "KiB", "MiB", "GiB", "TiB", "PiB"):
        if value < 1024 or unit == "PiB":
            if unit == "B":
                return f"{int(value)} {unit}"
            return f"{value:.1f} {unit}"
        value /= 1024
    return f"{value:.1f} PiB"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(8 * 1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_token() -> str:
    token = os.environ.get("HF_TOKEN") or os.environ.get("HUGGING_FACE_HUB_TOKEN") or ""
    if not token:
        for candidate in (
            Path.home() / ".cache" / "huggingface" / "token",
            Path.home() / ".huggingface" / "token",
        ):
            if candidate.is_file():
                try:
                    token = candidate.read_text()
                except OSError:
                    continue
                break
    return "".join(token.split())


def build_manifest(spec: dict, kind: str, comfy_dir: Path, meta: Metadata) -> dict:
    folder = ROOT / ("workflows" if kind == "workflow" else "recipes") / spec["id"]
    folder.mkdir(parents=True, exist_ok=True)

    manifest: dict = {
        "schema_version": 1,
        "id": spec["id"],
        "name": spec["name"],
        "description": spec["description"],
    }

    if kind == "workflow":
        source = comfy_dir / "user" / "default" / "workflows" / spec["source"]
        if not source.is_file():
            raise RuntimeError(f"workflow source not found: {source}")
        clean = folder / "workflow.json"
        shutil.copy2(source, clean)
        clean.chmod(0o644)
        manifest["workflow"] = {
            "file": "workflow.json",
            "install_as": spec["source"],
            "sha256": sha256_file(clean),
        }
    else:
        manifest["workflow"] = None

    models = []
    for repo, filename, directory in spec["models"]:
        if repo is None:
            record = meta.raw_asset(filename)
            name = Path(urllib.parse.urlparse(filename).path).name
        else:
            record = meta.hf_model(repo, filename)
            name = Path(filename).name

        if directory == "input":
            path = f"input/{name}"
        else:
            path = f"models/{directory}/{name}"
        model = {
            "name": name,
            "path": path,
            "url": record["url"],
            "size": record["size"],
            "sha256": record["sha256"],
            "gated": record["gated"],
        }
        alternates = spec.get("alternates", {}).get(name)
        if alternates:
            for digest in alternates:
                if len(digest) != 64 or any(c not in "0123456789abcdef" for c in digest):
                    raise RuntimeError(f"invalid alternate sha256 for {name}: {digest!r}")
            model["alternate_sha256"] = alternates
        models.append(model)

    manifest["models"] = models
    if spec.get("notes"):
        manifest["notes"] = spec["notes"]

    manifest_path = folder / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")

    write_install_wrapper(folder, spec["name"])
    write_readme(folder, manifest, kind, spec.get("notes", []))
    return manifest


def write_install_wrapper(folder: Path, name: str) -> None:
    script = f"""#!/usr/bin/env bash
# Generated by tools/build.py. Installs: {name}
set -Eeuo pipefail

HERE="$(cd -- "$(dirname -- "${{BASH_SOURCE[0]}}")" && pwd)"
ROOT="$(cd -- "$HERE/../.." && pwd)"

if [[ ! -x "$ROOT/bin/comfy-inventory" ]]; then
  echo "error: ComfyInventory CLI not found at $ROOT/bin/comfy-inventory" >&2
  echo "       Run this script from inside the ComfyInventory tree." >&2
  exit 1
fi

exec "$ROOT/bin/comfy-inventory" install --manifest "$HERE/manifest.json" "$@"
"""
    path = folder / "install.sh"
    path.write_text(script)
    path.chmod(0o755)


def write_readme(folder: Path, manifest: dict, kind: str, notes: list[str]) -> None:
    lines = [f"# {manifest['name']}", "", manifest["description"], ""]

    if kind == "workflow":
        lines += [
            "## Install",
            "",
            "```bash",
            f"./workflows/{manifest['id']}/install.sh",
            "# or from the inventory root:",
            f"./comfy-inventory install {manifest['id']}",
            "```",
            "",
            "## Files",
            "",
            "| Destination | Size | SHA-256 |",
            "| --- | ---: | --- |",
        ]
    else:
        lines += [
            "> **Legacy recipe:** no saved workflow JSON was found for this entry. "
            "It installs the model set only.",
            "",
            "## Install",
            "",
            "```bash",
            f"./recipes/{manifest['id']}/install.sh",
            "# or from the inventory root:",
            f"./comfy-inventory install {manifest['id']}",
            "```",
            "",
            "## Files",
            "",
            "| Destination | Size | SHA-256 |",
            "| --- | ---: | --- |",
        ]

    for model in manifest["models"]:
        gated = " (gated)" if model.get("gated") else ""
        lines.append(
            f"| `{model['path']}`{gated} | {human_size(model['size'])} | "
            f"`{model['sha256'][:16]}…` |"
        )

    lines.append("")
    alternates = [
        (model["name"], model["alternate_sha256"])
        for model in manifest["models"]
        if model.get("alternate_sha256")
    ]
    if alternates:
        lines += [
            "Known alternate checksums are accepted for existing files (fresh downloads use the primary pin):",
            "",
        ]
        for name, hashes in alternates:
            for digest in hashes:
                lines.append(f"- `{name}`: `{digest}`")
        lines.append("")

    if manifest.get("workflow"):
        wf = manifest["workflow"]
        lines += [
            "## Workflow",
            "",
            f"Clean copy: [`workflow.json`](workflow.json)  ",
            f"SHA-256: `{wf['sha256']}`  ",
            f"Installed as `{wf['install_as']}` under `ComfyUI/user/default/workflows/`.",
            "",
        ]

    if notes:
        lines += ["## Notes", ""]
        for note in notes:
            lines.append(f"- {note}")
        lines.append("")

    lines += ["---", "", "[Back to the inventory](../../README.md)", ""]
    (folder / "README.md").write_text("\n".join(lines))


def write_root_readme(built: list[tuple[str, dict]]) -> None:
    workflows = [(k, m) for k, m in built if k == "workflow"]
    recipes = [(k, m) for k, m in built if k == "recipe"]

    unique: dict[str, dict] = {}
    for _, manifest in built:
        for model in manifest["models"]:
            previous = unique.get(model["path"])
            if previous and (
                previous["size"] != model["size"] or previous["sha256"] != model["sha256"]
            ):
                raise RuntimeError(
                    f"conflicting pins for {model['path']}: "
                    f"{previous['sha256'][:12]}... vs {model['sha256'][:12]}..."
                )
            unique[model["path"]] = model
    unique_bytes = sum(m["size"] for m in unique.values())

    lines = [
        "# ComfyInventory",
        "",
        "Reproducible, per-workflow installers for the ComfyUI instance in "
        "`~/opt/ComfyUI`. Each folder holds a clean copy of the workflow JSON, a "
        "pinned `manifest.json`, and an `install.sh` that downloads exactly the "
        "models the workflow references.",
        "",
        "The inventory was rebuilt from the saved workflows rather than from the "
        "older scripts in `~/opt/download`, so the file lists match what the "
        "workflows actually load. It was built against ComfyUI 0.37.0.",
        "",
        "## Quick start",
        "",
        "```bash",
        "./comfy-inventory list",
        "./comfy-inventory status",
        "./comfy-inventory install z-image-t2i --dry-run",
        "./comfy-inventory install z-image-t2i",
        "./workflows/z-image-t2i/install.sh        # same thing",
        "```",
        "",
        f"**Unique payload:** {len(unique)} files, {human_size(unique_bytes)} "
        "(shared files are counted once).",
        "",
        "## Workflows",
        "",
        "| ID | Workflow file | Models | Size | Gated |",
        "| --- | --- | ---: | ---: | :---: |",
    ]
    for _, manifest in workflows:
        total = sum(m["size"] for m in manifest["models"])
        gated = "yes" if any(m.get("gated") for m in manifest["models"]) else ""
        lines.append(
            f"| [`{manifest['id']}`](workflows/{manifest['id']}/README.md) | "
            f"`{manifest['workflow']['install_as']}` | {len(manifest['models'])} | "
            f"{human_size(total)} | {gated} |"
        )

    lines += [
        "",
        "## Legacy recipes",
        "",
        "These entries correspond to the old scripts that have no saved workflow "
        "JSON in this ComfyUI installation. They install models (and, for the "
        "separation recipe, the sample input) but cannot install a workflow file.",
        "",
        "| ID | Models | Size | Notes |",
        "| --- | ---: | ---: | --- |",
    ]
    for _, manifest in recipes:
        total = sum(m["size"] for m in manifest["models"])
        lines.append(
            f"| [`{manifest['id']}`](recipes/{manifest['id']}/README.md) | "
            f"{len(manifest['models'])} | {human_size(total)} | model set only |"
        )

    lines += [
        "",
        "## Layout",
        "",
        "```text",
        "ComfyInventory/",
        "├── comfy-inventory              # convenience launcher",
        "├── bin/comfy-inventory          # CLI: list, status, install, verify, doctor",
        "├── lib/                         # shared shell implementation",
        "├── workflows/<id>/",
        "│   ├── workflow.json            # exact copy of the saved workflow",
        "│   ├── manifest.json            # pinned URLs, sizes and SHA-256 values",
        "│   ├── install.sh               # thin wrapper around the CLI",
        "│   └── README.md                # file list and workflow-specific notes",
        "├── recipes/<id>/                # legacy model-only entries (no JSON)",
        "├── tests/smoke.sh               # isolated installer smoke test",
        "└── tools/                       # build.py and audit.py",
        "```",
        "",
        "## What the installer does",
        "",
        "- **Derives the file list from the workflow**, not from a hand-written script.",
        "- **Pins every file** with its byte size and SHA-256. Existing files are "
        "checked by size; use `--verify` to hash them.",
        "- **Accepts documented alternate checksums** for known local revisions "
        "(currently the FireRed transformer); fresh downloads use the primary pin.",
        "- **Downloads into a staging area** (`<COMFY_DIR>/.cache/comfy-inventory`) "
        "and moves files into `models/` only after the checksum passes, so ComfyUI "
        "never sees a partial model.",
        "- **Resumes partial downloads** with aria2, or falls back to `curl -C -`.",
        "- **Is non-interactive** by default. Existing files are kept; mismatches "
        "fail loudly instead of being overwritten.",
        "- **Scopes the Hugging Face token** to `huggingface.co` URLs and only "
        "sends it for models marked gated.",
        "- **Copies the workflow** into `ComfyUI/user/default/workflows/` unless "
        "`--no-workflow` is used. A differing workflow is never overwritten "
        "without `--force-workflow` (which keeps a timestamped backup).",
        "",
        "## Adding or updating a workflow",
        "",
        "1. Save the workflow in ComfyUI so it appears in "
        "`ComfyUI/user/default/workflows/`.",
        "2. Add or update its entry in `tools/build.py` (`WORKFLOWS` for full "
        "workflows, `RECIPES` for model-only sets).",
        "3. Run `python3 tools/build.py` (or `--offline` to reuse existing pins).",
        "4. Run `python3 tools/audit.py` to confirm the manifest matches the JSON.",
        "",
        "A manifest is a small JSON file:",
        "",
        "```json",
        "{",
        '  "schema_version": 1,',
        '  "id": "example",',
        '  "name": "Example workflow",',
        '  "workflow": {"file": "workflow.json", "install_as": "Example.json", "sha256": "…"},',
        '  "models": [{"name": "model.safetensors", "path": "models/vae/model.safetensors",',
        '              "url": "https://huggingface.co/…", "size": 123, "sha256": "…", "gated": false}]',
        "}",
        "```",
        "",
        "`path` must be relative and start with `models/` or `input/`. "
        "`gated` attaches the Hugging Face token (use it for gated or private "
        "HF repos). `alternate_sha256` is optional and only for documented, "
        "known-good revisions.",
        "",
        "## Commands",
        "",
        "| Command | Purpose |",
        "| --- | --- |",
        "| `./comfy-inventory list` | List workflow folders and their sizes |",
        "| `./comfy-inventory status [id ...]` | Show present/missing files |",
        "| `./comfy-inventory install <id ...>` | Install one or more workflows or recipes |",
        "| `./comfy-inventory install --all` | Install every workflow and recipe |",
        "| `./comfy-inventory verify [id ...]` | Hash installed files |",
        "| `./comfy-inventory doctor` | Check dependencies, paths, token and disk |",
        "",
        "Common flags: `--comfy-dir`, `--dry-run`, `--repair`, `--force`, "
        "`--verify`, `--jobs N`, `--downloader auto|aria2c|curl`, "
        "`--no-workflow`, `--force-workflow`, `--workflow-only`, `--quiet`.",
        "Run `./comfy-inventory --help` for the full list.",
        "",
        "### Repairing an installation",
        "",
        "```bash",
        "# Hash everything and report mismatches without changing files",
        "./comfy-inventory install z-image-t2i --verify",
        "",
        "# Replace only files that are missing or have the wrong size/checksum",
        "./comfy-inventory install z-image-t2i --repair",
        "",
        "# Re-download every model in the workflow",
        "./comfy-inventory install z-image-t2i --force",
        "```",
        "",
        "## Gated models",
        "",
        "`flux2-klein-edit-9b` uses the "
        "[gated BFL checkpoint](https://huggingface.co/black-forest-labs/FLUX.2-klein-base-9b-fp8). Accept "
        "the license there, then provide a token via `HF_TOKEN` or "
        "`huggingface-cli login`. The installer preflights gated access and prints "
        "the exact repository URL if access is denied.",
        "",
        "## Requirements",
        "",
        "- Linux with Bash 4.3+ (the tested target); macOS may work with GNU coreutils",
        "- `jq`, `curl`, `sha256sum` (or `shasum`), `awk`, `df`",
        "- `aria2c` strongly recommended; `curl` is used as a fallback",
        "- Optional: `flock` for a proper install lock (a mkdir fallback is used)",
        "- Python 3.9+ only for `tools/build.py` and `tools/audit.py`",
        "",
        "## Regenerating",
        "",
        "```bash",
        "python3 tools/build.py             # copy workflows + refresh HF sizes/hashes",
        "python3 tools/build.py --offline   # reuse checksums from existing manifests",
        "python3 tools/audit.py             # check manifests against workflow JSON",
        "```",
        "",
        "`tools/build.py` reads workflow JSON from "
        "`ComfyUI/user/default/workflows/` and requires network access unless "
        "`--offline` is used.",
        "",
        "## Testing",
        "",
        "```bash",
        "./tests/smoke.sh        # isolated download/repair/verify test (~1.2 MiB, network)",
        "python3 tools/audit.py  # manifests vs. workflow JSON",
        "```",
        "",
        "## Relationship to `~/opt/download`",
        "",
        "The old scripts are left in place as an archive. This table maps them to "
        "their replacements.",
        "",
        "| Old script | New entry |",
        "| --- | --- |",
        "| `download_fired_text_to_image.sh` | `recipes/fired-image-edit-1.1` (model set only) |",
        "| `download_flux2_klein_image_edit_9b.sh` | `workflows/flux2-klein-edit-9b` |",
        "| `download_flux2_klein_image_edit.sh` | `recipes/flux2-klein-edit-4b` (model set only) |",
        "| `download_flux_fill.sh` | `workflows/flux-outpaint` |",
        "| `download_krea_2_turbo_style_transfer.sh` | `workflows/krea2-style-transfer` |",
        "| `download_minimax_h3_image_to_video.sh` | `workflows/minimax-h3-image-to-video` |",
        "| `download_qwen_2-1_edit.sh` | `workflows/qwen-image-2.1-edit` |",
        "| `download_qwen_2.1_separation.sh` | `recipes/qwen-image-2.1-separation` (model set only) |",
        "| `download_qwen_2-1.sh` | `workflows/qwen-image-2.1-t2i` |",
        "| `download_qwen_2_1_outpiant.sh` | `workflows/qwen-image-2.1-outpaint` |",
        "| `download_qwen_edit_2511_int8.sh` | `workflows/qwen-image-2511-edit` |",
        "| `download_z_image.sh` | `workflows/z-image-t2i` |",
        "| `install_ace_step_1.5_models.sh` | **no equivalent** — the saved audio workflow is YuE2, not ACE-Step; see `workflows/yue2-text-to-music` |",
        "",
        "Notable fixes made while rebuilding:",
        "",
        "- The old FireRed script contained stray `[cite: N]` text inside its model "
        "array; the new manifest has clean URLs.",
        "- The old MiniMax script downloaded a template input image that the saved "
        "workflow does not use.",
        "- The old audio script installed ACE-Step 1.5, but the saved workflow is "
        "YuE2 and its active checkpoint is bf16.",
        "- The old Qwen outpaint script downloaded both v1 and v2 LoRAs; the "
        "workflow uses v2 only.",
        "- The installed FireRed transformer is a valid alternate revision with a "
        "different checksum from current upstream; the recipe accepts both and "
        "documents the difference.",
        "",
    ]
    (ROOT / "README.md").write_text("\n".join(lines))


def main() -> int:
    parser = argparse.ArgumentParser(description="Build ComfyInventory manifests and READMEs")
    parser.add_argument("--comfy-dir", type=Path, default=DEFAULT_COMFY)
    parser.add_argument("--offline", action="store_true", help="reuse checksums from existing manifests")
    args = parser.parse_args()

    comfy_dir = args.comfy_dir.expanduser().resolve()
    if not (comfy_dir / "user" / "default" / "workflows").is_dir():
        print(f"error: workflow directory not found under {comfy_dir}", file=sys.stderr)
        return 1

    token = load_token()
    meta = Metadata(offline=args.offline, token=token)

    built: list[tuple[str, dict]] = []
    try:
        for spec in WORKFLOWS:
            built.append(("workflow", build_manifest(spec, "workflow", comfy_dir, meta)))
        for spec in RECIPES:
            built.append(("recipe", build_manifest(spec, "recipe", comfy_dir, meta)))
    except Exception as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    try:
        write_root_readme(built)
    except Exception as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print(f"Built {len(WORKFLOWS)} workflows and {len(RECIPES)} recipes under {ROOT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
