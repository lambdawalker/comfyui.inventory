#!/usr/bin/env bash
# End-to-end smoke test for the installer engine.
#
# Uses a 1.2 MiB public template image, an isolated ComfyUI root, and an
# isolated staging directory. No real models are downloaded.
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$ROOT/bin/comfy-inventory"
URL="https://raw.githubusercontent.com/Comfy-Org/workflow_templates/refs/heads/main/input/angry_broccoli.png"
SIZE=1194081
SHA="a407007c0d3d06c8647239ca5ac502097ccc42302317a4b817a338fb3aeee43b"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/comfy-inventory-smoke.XXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT

COMFY="$TMP/Comfy UI"
BUNDLE="$TMP/bundle"
STAGE="$TMP/staging area"
mkdir -p "$COMFY/user/default/workflows" "$BUNDLE"

printf '{"nodes": [], "links": []}\n' > "$BUNDLE/workflow.json"
WF_SHA="$(sha256sum "$BUNDLE/workflow.json" | awk '{print $1}')"

jq -n \
  --arg url "$URL" \
  --arg sha "$SHA" \
  --arg wfsha "$WF_SHA" \
  --argjson size "$SIZE" \
  '{
    schema_version: 1,
    id: "smoke-test",
    name: "Smoke Test",
    description: "Isolated installer test",
    workflow: {
      file: "workflow.json",
      install_as: "Smoke Workflow.json",
      sha256: $wfsha
    },
    models: [{
      name: "angry_broccoli.png",
      path: "input/angry_broccoli.png",
      url: $url,
      size: $size,
      sha256: $sha,
      gated: false
    }]
  }' > "$BUNDLE/manifest.json"

DEST="$COMFY/input/angry_broccoli.png"
WF_DEST="$COMFY/user/default/workflows/Smoke Workflow.json"

pass() { printf 'ok - %s\n' "$*"; }

# 1. Fresh install.
"$CLI" install --manifest "$BUNDLE/manifest.json" --comfy-dir "$COMFY" --staging-dir "$STAGE" --jobs 1 >/dev/null
[[ -f "$DEST" ]] || { echo "FAIL: model not installed"; exit 1; }
[[ "$(sha256sum "$DEST" | awk '{print $1}')" == "$SHA" ]] || { echo "FAIL: model checksum"; exit 1; }
[[ -f "$WF_DEST" ]] || { echo "FAIL: workflow not installed"; exit 1; }
cmp -s "$BUNDLE/workflow.json" "$WF_DEST" || { echo "FAIL: workflow differs"; exit 1; }
pass "fresh install"

# 2. Idempotent re-run.
OUT="$("$CLI" install --manifest "$BUNDLE/manifest.json" --comfy-dir "$COMFY" --staging-dir "$STAGE" 2>&1)"
grep -q "All model files are already installed" <<<"$OUT" || { echo "FAIL: re-run"; echo "$OUT"; exit 1; }
pass "idempotent re-run"

# 3. A size mismatch blocks --verify instead of silently replacing data.
printf 'x' >> "$DEST"
[[ "$(stat -c '%s' "$DEST")" != "$SIZE" ]] || { echo "FAIL: corruption setup"; exit 1; }
if "$CLI" install --manifest "$BUNDLE/manifest.json" --comfy-dir "$COMFY" --staging-dir "$STAGE" --verify >/dev/null 2>&1; then
  echo "FAIL: --verify accepted a size mismatch"
  exit 1
fi
pass "verify rejects corruption"

# 4. Repair the file.
"$CLI" install --manifest "$BUNDLE/manifest.json" --comfy-dir "$COMFY" --staging-dir "$STAGE" --repair >/dev/null
[[ "$(sha256sum "$DEST" | awk '{print $1}')" == "$SHA" ]] || { echo "FAIL: repair"; exit 1; }
pass "repair after corruption"

# 5. Verify.
"$CLI" verify --manifest "$BUNDLE/manifest.json" --comfy-dir "$COMFY" --staging-dir "$STAGE" >/dev/null
pass "verify"

# 6. Dry run leaves a missing file alone.
rm -f "$DEST"
"$CLI" install --manifest "$BUNDLE/manifest.json" --comfy-dir "$COMFY" --staging-dir "$STAGE" --dry-run >/dev/null
[[ ! -f "$DEST" ]] || { echo "FAIL: dry run wrote a file"; exit 1; }
pass "dry run"

# 7. curl fallback.
"$CLI" install --manifest "$BUNDLE/manifest.json" --comfy-dir "$COMFY" --staging-dir "$STAGE" --downloader curl >/dev/null
[[ "$(sha256sum "$DEST" | awk '{print $1}')" == "$SHA" ]] || { echo "FAIL: curl fallback"; exit 1; }
pass "curl fallback"

# 8. --no-workflow does not copy the JSON.
rm -f "$WF_DEST"
"$CLI" install --manifest "$BUNDLE/manifest.json" --comfy-dir "$COMFY" --staging-dir "$STAGE" --no-workflow >/dev/null
[[ ! -f "$WF_DEST" ]] || { echo "FAIL: --no-workflow copied the JSON"; exit 1; }
pass "--no-workflow"

# 9. --workflow-only copies the JSON without touching models.
rm -f "$DEST"
"$CLI" install --manifest "$BUNDLE/manifest.json" --comfy-dir "$COMFY" --staging-dir "$STAGE" --workflow-only >/dev/null
[[ ! -f "$DEST" ]] || { echo "FAIL: --workflow-only downloaded a model"; exit 1; }
[[ -f "$WF_DEST" ]] || { echo "FAIL: --workflow-only did not copy the JSON"; exit 1; }
pass "--workflow-only"

# 10. --force re-downloads a valid file.
"$CLI" install --manifest "$BUNDLE/manifest.json" --comfy-dir "$COMFY" --staging-dir "$STAGE" >/dev/null
"$CLI" install --manifest "$BUNDLE/manifest.json" --comfy-dir "$COMFY" --staging-dir "$STAGE" --force >/dev/null
[[ "$(sha256sum "$DEST" | awk '{print $1}')" == "$SHA" ]] || { echo "FAIL: --force"; exit 1; }
pass "--force"

# 11. A known alternate checksum is accepted.
jq '.id = "alt-test" | .models[0].alternate_sha256 = [.models[0].sha256] | .models[0].sha256 = ("0" * 64)' \
  "$BUNDLE/manifest.json" > "$BUNDLE/alt.json"
"$CLI" verify --manifest "$BUNDLE/alt.json" --comfy-dir "$COMFY" --staging-dir "$STAGE" >/dev/null
pass "alternate checksum"

# 12. Path traversal is rejected before anything is created.
jq '.id = "bad-path" | .models[0].path = "../escape.bin"' "$BUNDLE/manifest.json" > "$BUNDLE/bad.json"
if "$CLI" install --manifest "$BUNDLE/bad.json" --comfy-dir "$COMFY" --staging-dir "$STAGE" >/dev/null 2>&1; then
  echo "FAIL: path traversal was accepted"
  exit 1
fi
[[ ! -e "$TMP/escape.bin" ]] || { echo "FAIL: traversal created a file"; exit 1; }
pass "path traversal rejected"

printf '\nAll smoke tests passed.\n'
