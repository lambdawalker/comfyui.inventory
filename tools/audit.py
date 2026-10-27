#!/usr/bin/env python3
"""Audit ComfyInventory manifests against the workflow JSON they install.

Checks:
  * workflow.json still matches its pinned SHA-256
  * workflow.json still matches the saved workflow in ComfyUI (if present)
  * every model filename referenced by the workflow is in the manifest
  * every manifest model is referenced by the workflow
  * model names in the manifest use the directory the workflow expects

This is a development tool. It does not download anything.

Usage:
    python3 tools/audit.py
    python3 tools/audit.py --comfy-dir ~/opt/ComfyUI
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_COMFY = Path(os.environ.get("COMFY_DIR", Path.home() / "opt" / "ComfyUI"))

# The YuE2 workflow contains a stale inner int8 loader and a promoted bf16
# override. Both names are legitimate; the manifest installs the active bf16
# file and the README explains how to switch.
KNOWN_ALTERNATES = {
    "yue2-text-to-music": {"yue2_3b_int8_convrot.safetensors"},
}

# Node type -> ComfyUI models/ subdirectory, used as a fallback when a workflow
# does not carry the newer properties.models metadata.
NODE_DIRS = {
    "UNETLoader": "diffusion_models",
    "CLIPLoader": "text_encoders",
    "DualCLIPLoader": "text_encoders",
    "TripleCLIPLoader": "text_encoders",
    "VAELoader": "vae",
    "LoraLoaderModelOnly": "loras",
    "LoraLoader": "loras",
    "CheckpointLoaderSimple": "checkpoints",
    "CheckpointLoader": "checkpoints",
    "ControlNetLoader": "controlnet",
    "UpscaleModelLoader": "upscale_models",
    "CLIPVisionLoader": "clip_vision",
    "StyleModelLoader": "style_models",
    "GLIGENLoader": "gligen",
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(8 * 1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def walk(value):
    """Yield every dict inside a JSON value."""
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from walk(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk(child)


def collect_models(workflow: dict) -> tuple[dict[str, set[str]], dict[str, str]]:
    """Return (filename -> set of directories, filename -> URL)."""
    names: dict[str, set[str]] = {}
    urls: dict[str, str] = {}

    for obj in walk(workflow):
        node_type = obj.get("type")
        directory = NODE_DIRS.get(node_type) if isinstance(node_type, str) else None

        # Collect from every widget list. Subgraph instance nodes are keyed by
        # a UUID, but can still promote a loader widget (the YuE2 bf16 override
        # is one example). Unknown directories are fine; they are only checked
        # when the node type tells us where the file belongs.
        widgets = obj.get("widgets_values")
        if isinstance(widgets, list):
            for value in widgets:
                if isinstance(value, str) and value.endswith(".safetensors"):
                    name = Path(value).name
                    entry = names.setdefault(name, set())
                    if directory:
                        entry.add(directory)

        named = obj.get("widgets_values_named")
        if isinstance(named, dict):
            for value in named.values():
                if isinstance(value, str) and value.endswith(".safetensors"):
                    name = Path(value).name
                    entry = names.setdefault(name, set())
                    if directory:
                        entry.add(directory)

        properties = obj.get("properties")
        if not isinstance(properties, dict):
            continue
        for model in properties.get("models", []) or []:
            if not isinstance(model, dict):
                continue
            name = model.get("name")
            if not isinstance(name, str):
                continue
            directory = model.get("directory")
            entry = names.setdefault(Path(name).name, set())
            if isinstance(directory, str) and directory:
                entry.add(directory)
            url = model.get("url")
            if isinstance(url, str) and url:
                urls[Path(name).name] = url

    return names, urls


def audit_manifest(manifest_path: Path, comfy_dir: Path) -> list[str]:
    errors: list[str] = []
    warnings: list[str] = []

    try:
        manifest = json.loads(manifest_path.read_text())
    except Exception as exc:
        return [f"cannot read manifest: {exc}"]

    wid = manifest.get("id", "?")
    workflow_info = manifest.get("workflow")
    if not workflow_info:
        return []

    clean = manifest_path.parent / workflow_info["file"]
    if not clean.is_file():
        return [f"{wid}: missing {clean}"]
    actual = sha256_file(clean)
    if actual != workflow_info["sha256"]:
        errors.append(
            f"{wid}: workflow.json checksum mismatch "
            f"(manifest {workflow_info['sha256'][:12]}..., actual {actual[:12]}...)"
        )

    source = comfy_dir / "user" / "default" / "workflows" / workflow_info["install_as"]
    if source.is_file() and sha256_file(source) != actual:
        warnings.append(
            f"{wid}: saved workflow in ComfyUI differs from the inventory copy "
            f"({source})"
        )

    try:
        workflow = json.loads(clean.read_text())
    except Exception as exc:
        return errors + [f"{wid}: invalid workflow.json: {exc}"]

    referenced, urls = collect_models(workflow)
    manifest_models = {m["name"]: m for m in manifest.get("models", [])}
    allowed = KNOWN_ALTERNATES.get(wid, set())

    for name in sorted(set(referenced) - set(manifest_models) - allowed):
        errors.append(f"{wid}: workflow references {name!r} but the manifest does not include it")

    for name in sorted(set(manifest_models) - set(referenced)):
        errors.append(f"{wid}: manifest includes {name!r} but the workflow does not reference it")

    for name, model in manifest_models.items():
        path = model.get("path", "")
        expected_dir = "/".join(path.split("/")[1:-1])
        if name in referenced:
            dirs = referenced[name]
            if dirs and expected_dir not in dirs:
                errors.append(
                    f"{wid}: {name!r} is in {sorted(dirs)} in the workflow, "
                    f"but the manifest uses {expected_dir!r}"
                )
        if name in urls:
            workflow_url = urls[name].split("?", 1)[0]
            manifest_url = (model.get("url") or "").split("?", 1)[0]
            if workflow_url != manifest_url:
                warnings.append(
                    f"{wid}: URL for {name!r} differs from the workflow's embedded metadata"
                )

    for warning in warnings:
        print(f"WARN  {warning}")
    for error in errors:
        print(f"ERROR {error}")
    if not errors and not warnings:
        print(f"OK    {wid}: {len(manifest_models)} model(s)")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit ComfyInventory manifests")
    parser.add_argument("--comfy-dir", type=Path, default=DEFAULT_COMFY)
    args = parser.parse_args()
    comfy_dir = args.comfy_dir.expanduser().resolve()

    manifests = sorted((ROOT / "workflows").glob("*/manifest.json"))
    if not manifests:
        print("error: no workflow manifests found", file=sys.stderr)
        return 1

    errors: list[str] = []
    for manifest in manifests:
        errors.extend(audit_manifest(manifest, comfy_dir))

    print()
    if errors:
        print(f"FAILED: {len(errors)} issue(s)")
        return 1
    print(f"Audited {len(manifests)} workflow(s): OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
