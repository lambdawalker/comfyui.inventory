#!/usr/bin/env bash
# Installer engine for ComfyInventory.
# Sourced by bin/comfy-inventory. All user-facing commands are in the CLI.

# ---------------------------------------------------------------------------
# Manifest loading and validation
# ---------------------------------------------------------------------------
M_MANIFEST=""
M_DIR=""
M_ID=""
M_NAME=""
M_DESCRIPTION=""
M_WORKFLOW_FILE=""
M_INSTALL_AS=""
M_WORKFLOW_SHA=""
WORKFLOW_RESULT="none"

validate_manifest() {
  local manifest="$1"

  [[ -n "$manifest" ]] || die "no manifest supplied"
  [[ -f "$manifest" ]] || die "manifest not found: $manifest"

  jq -e 'type == "object"' "$manifest" >/dev/null 2>&1 \
    || die "invalid manifest (not a JSON object): $manifest"

  M_SCHEMA_VERSION="$(jq -r '.schema_version // empty' "$manifest")"
  [[ "$M_SCHEMA_VERSION" == "1" ]] \
    || die "unsupported manifest schema_version '$M_SCHEMA_VERSION' in $manifest (expected 1)"

  M_ID="$(jq -r '.id // empty' "$manifest")"
  M_NAME="$(jq -r '.name // empty' "$manifest")"
  M_DESCRIPTION="$(jq -r '.description // empty' "$manifest")"
  M_WORKFLOW_FILE="$(jq -r '.workflow.file // empty' "$manifest")"
  M_INSTALL_AS="$(jq -r '.workflow.install_as // empty' "$manifest")"
  M_WORKFLOW_SHA="$(jq -r '.workflow.sha256 // empty' "$manifest")"

  [[ "$M_ID" =~ ^[a-z0-9][a-z0-9._-]*$ ]] \
    || die "invalid manifest id '$M_ID' in $manifest (use lowercase letters, digits, . _ -)"
  [[ -n "$M_NAME" ]] || die "manifest $manifest is missing a name"

  # Validate model records with jq so that malformed values are rejected
  # before any shell arrays or paths are built.
  jq -e '
    (.models | type == "array") and
    (all(.models[];
      (.name | type == "string" and length > 0) and
      (.path | type == "string" and length > 0) and
      (.url  | type == "string" and test("^https://")) and
      (.size | type == "number" and . > 0 and floor == .) and
      (.sha256 | type == "string" and test("^[0-9a-f]{64}$")) and
      ((.alternate_sha256 // []) | (type == "array" and all(.[]; type == "string" and test("^[0-9a-f]{64}$")))) and
      ((.gated // false) | type == "boolean") and
      (.name | test("[\\t\\n\\r]") | not) and
      (.path | test("[\\t\\n\\r]") | not) and
      (.url  | test("[\\t\\n\\r]") | not)
    ))
  ' "$manifest" >/dev/null 2>&1 \
    || die "invalid manifest $manifest: every model needs name, path, https url, positive integer size, 64-char sha256, optional alternate_sha256 array, and boolean gated"

  if [[ -n "$M_WORKFLOW_FILE" ]]; then
    [[ "$M_WORKFLOW_FILE" != /* ]] || die "workflow.file must be relative: $M_WORKFLOW_FILE"
    [[ "$M_WORKFLOW_FILE" != *".."* ]] || die "workflow.file must not contain '..': $M_WORKFLOW_FILE"
    [[ -n "$M_INSTALL_AS" ]] || die "manifest has workflow.file but no workflow.install_as"
    [[ "$M_INSTALL_AS" != */* && "$M_INSTALL_AS" != *\\* ]] \
      || die "workflow.install_as must be a filename, not a path: $M_INSTALL_AS"
    [[ "$M_INSTALL_AS" != *".."* ]] || die "workflow.install_as must not contain '..': $M_INSTALL_AS"
    [[ "$M_INSTALL_AS" == *.json ]] || die "workflow.install_as must end in .json: $M_INSTALL_AS"
    [[ "$M_WORKFLOW_SHA" =~ ^[0-9a-f]{64}$ ]] \
      || die "manifest workflow.sha256 is missing or invalid"
  fi

  # Reject unsafe model paths and duplicate destinations.
  local name path url size sha gated alt
  local -A seen=()
  while IFS=$'\t' read -r name path url size sha gated alt; do
    [[ -n "$path" ]] || die "manifest $manifest contains a model with an empty path"
    [[ "$path" != /* ]] || die "model path must be relative: $path"
    [[ "$path" != *"\\"* ]] || die "model path must use forward slashes: $path"

    local seg
    local -a segs=()
    IFS='/' read -r -a segs <<< "$path"
    for seg in "${segs[@]}"; do
      [[ -n "$seg" && "$seg" != "." && "$seg" != ".." ]] \
        || die "unsafe model path '$path' in manifest $manifest"
    done
    [[ "${segs[0]}" == "models" || "${segs[0]}" == "input" ]] \
      || die "model path must start with models/ or input/: $path"

    if [[ -n "${seen[$path]:-}" ]]; then
      die "duplicate model path '$path' in manifest $manifest"
    fi
    seen[$path]=1

    [[ "$url" == https://* ]] || die "model URL must use https: $url"
    [[ "$size" =~ ^[0-9]+$ ]] || die "invalid size for $path: $size"
    [[ "$sha" =~ ^[0-9a-f]{64}$ ]] || die "invalid sha256 for $path: $sha"
    if [[ -n "$alt" ]]; then
      local a
      local -a alt_list=()
      IFS='|' read -r -a alt_list <<< "$alt"
      for a in "${alt_list[@]}"; do
        [[ "$a" =~ ^[0-9a-f]{64}$ ]] || die "invalid alternate_sha256 for $path: $a"
      done
    fi
    [[ "$gated" == "true" || "$gated" == "false" ]] \
      || die "invalid gated value for $path: $gated"
  done < <(model_rows "$manifest")

  M_MANIFEST="$(abspath "$manifest")"
  M_DIR="$(cd -- "$(dirname -- "$M_MANIFEST")" && pwd -P)"

  # The clean workflow copy must exist and match its pin.
  if [[ -n "$M_WORKFLOW_FILE" ]]; then
    local wf="$M_DIR/$M_WORKFLOW_FILE"
    [[ -f "$wf" ]] || die "workflow file not found: $wf"
    local actual
    actual="$(sha256_file "$wf")" || die "could not hash workflow file: $wf"
    [[ "$actual" == "$M_WORKFLOW_SHA" ]] \
      || die "workflow checksum mismatch for $wf (manifest $M_WORKFLOW_SHA, actual $actual)"
  fi
}

model_rows() {
  local manifest="${1:-$M_MANIFEST}"
  jq -r '
    .models[] |
    [
      (.name // ""),
      (.path // ""),
      (.url // ""),
      ((.size // 0) | tostring),
      (.sha256 // ""),
      ((.gated // false) | tostring),
      ((.alternate_sha256 // []) | join("|"))
    ] | @tsv
  ' "$manifest"
}

# True when $1 matches the primary checksum or one of the pipe-separated
# alternate checksums in $3. Alternates are used for known-good local
# revisions whose bytes differ from the current upstream pin.
hash_matches() {
  local hash="$1" primary="$2" alternates="${3:-}" candidate
  [[ "$hash" == "$primary" ]] && return 0
  [[ -n "$alternates" ]] || return 1
  local -a list=()
  IFS='|' read -r -a list <<< "$alternates"
  for candidate in "${list[@]}"; do
    [[ -n "$candidate" && "$hash" == "$candidate" ]] && return 0
  done
  return 1
}

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
dest_path_for() {
  printf '%s/%s' "${CI_COMFY_DIR%/}" "$1"
}

stage_path_for() {
  printf '%s/%s/%s' "${CI_STAGE_ROOT%/}" "$M_ID" "$1"
}

workflow_source_path() { printf '%s/%s' "$M_DIR" "$M_WORKFLOW_FILE"; }
workflow_dest_path()   { printf '%s/user/default/workflows/%s' "${CI_COMFY_DIR%/}" "$M_INSTALL_AS"; }

# ---------------------------------------------------------------------------
# Hugging Face token handling
# ---------------------------------------------------------------------------
is_hf_url() {
  [[ "$1" == https://huggingface.co/* || "$1" == https://hf.co/* ]]
}

hf_repo_from_url() {
  printf '%s' "$1" | sed -E 's#^https://(huggingface\.co|hf\.co)/([^/]+/[^/]+)/.*#\2#'
}

discover_hf_token() {
  local token="${HF_TOKEN:-${HUGGING_FACE_HUB_TOKEN:-}}"
  if [[ -z "$token" ]]; then
    local f
    for f in "$HOME/.cache/huggingface/token" "$HOME/.huggingface/token"; do
      if [[ -r "$f" ]]; then
        token="$(<"$f")"
        break
      fi
    done
  fi
  token="$(printf '%s' "$token" | tr -d '[:space:]')"
  printf '%s' "$token"
}

# Write a 0600 curl config containing the HF header, so the token does not
# appear in curl's argv. The caller is responsible for deleting the file.
curl_auth_config() {
  local token="$1" cfg
  cfg="$(mktemp "${TMPDIR:-/tmp}/comfy-inventory-curl.XXXXXX")"     || die "could not create a temporary curl config"
  chmod 600 "$cfg"
  printf 'header = "Authorization: Bearer %s"\n' "$token" > "$cfg"
  printf '%s' "$cfg"
}

# ---------------------------------------------------------------------------
# Workflow installation
# ---------------------------------------------------------------------------
install_workflow() {
  WORKFLOW_RESULT="skipped"
  [[ -n "$M_WORKFLOW_FILE" ]] || return 0
  [[ "${CI_NO_WORKFLOW:-0}" == "1" ]] && return 0

  local src dest dest_dir
  src="$(workflow_source_path)"
  dest="$(workflow_dest_path)"
  dest_dir="$(dirname -- "$dest")"

  if [[ -f "$dest" ]] && cmp -s -- "$src" "$dest"; then
    WORKFLOW_RESULT="already"
    info "workflow  already installed  $(display_path "$dest")"
    return 0
  fi

  if [[ -f "$dest" && "${CI_FORCE_WORKFLOW:-0}" != "1" ]]; then
    WORKFLOW_RESULT="differs"
    warn "workflow  destination differs and was not overwritten: $(display_path "$dest")"
    info "          use --force-workflow to replace it (a timestamped backup is kept)"
    return 0
  fi

  if [[ "${CI_DRY_RUN:-0}" == "1" ]]; then
    WORKFLOW_RESULT="would-install"
    info "workflow  would install       $(display_path "$dest")"
    return 0
  fi

  ensure_dir "$dest_dir"

  if [[ -f "$dest" ]]; then
    local backup="$dest.bak.$(timestamp)"
    cp -p -- "$dest" "$backup"
    info "workflow  backed up           $(display_path "$backup")"
  fi

  local tmp="$dest.tmp.$$"
  cp -p -- "$src" "$tmp"
  mv -f -- "$tmp" "$dest"
  WORKFLOW_RESULT="installed"
  ok "workflow  installed           $(display_path "$dest")"
}

# ---------------------------------------------------------------------------
# Planning
# ---------------------------------------------------------------------------
QUEUE_NAMES=()
QUEUE_PATHS=()
QUEUE_URLS=()
QUEUE_SIZES=()
QUEUE_SHAS=()
QUEUE_GATED=()
QUEUE_ALTS=()

PLAN_PRESENT=0
PLAN_MISSING=0
PLAN_MISMATCH=0
PLAN_CORRUPT=0
PLAN_BLOCKED=0
PLAN_RESUME=0
PLAN_QUEUED=0

queue_add() {
  QUEUE_NAMES+=("$1")
  QUEUE_PATHS+=("$2")
  QUEUE_URLS+=("$3")
  QUEUE_SIZES+=("$4")
  QUEUE_SHAS+=("$5")
  QUEUE_GATED+=("$6")
  QUEUE_ALTS+=("${7:-}")
  PLAN_QUEUED=$((PLAN_QUEUED + 1))
}

plan_models() {
  QUEUE_NAMES=() QUEUE_PATHS=() QUEUE_URLS=() QUEUE_SIZES=() QUEUE_SHAS=() QUEUE_GATED=() QUEUE_ALTS=()
  PLAN_PRESENT=0 PLAN_MISSING=0 PLAN_MISMATCH=0 PLAN_CORRUPT=0 PLAN_BLOCKED=0 PLAN_RESUME=0 PLAN_QUEUED=0

  local name path url size sha gated alt
  while IFS=$'\t' read -r name path url size sha gated alt; do
    local dest actual stage
    dest="$(dest_path_for "$path")"
    stage="$(stage_path_for "$path")"

    if [[ -f "$dest" ]]; then
      actual="$(file_size "$dest" 2>/dev/null || printf '0')"
      if [[ "$actual" == "$size" ]]; then
        if [[ "${CI_FORCE:-0}" == "1" ]]; then
          queue_add "$name" "$path" "$url" "$size" "$sha" "$gated" "$alt"
          [[ "${CI_QUIET:-0}" == "1" ]] || info "replace   $path ($(human_size "$size"))"
        elif [[ "${CI_VERIFY:-0}" == "1" || "${CI_REPAIR:-0}" == "1" ]]; then
          [[ "${CI_QUIET:-0}" == "1" ]] || info "hashing   $path ..."
          if hash_matches "$(sha256_file "$dest" 2>/dev/null || true)" "$sha" "$alt"; then
            PLAN_PRESENT=$((PLAN_PRESENT + 1))
            [[ "${CI_QUIET:-0}" == "1" ]] || ok "verified  $path"
          else
            PLAN_CORRUPT=$((PLAN_CORRUPT + 1))
            if [[ "${CI_REPAIR:-0}" == "1" ]]; then
              queue_add "$name" "$path" "$url" "$size" "$sha" "$gated" "$alt"
              warn "corrupt   $path (checksum mismatch; queued for repair)"
            else
              PLAN_BLOCKED=$((PLAN_BLOCKED + 1))
              err "corrupt   $path (checksum mismatch; use --repair)"
            fi
          fi
        else
          PLAN_PRESENT=$((PLAN_PRESENT + 1))
          [[ "${CI_QUIET:-0}" == "1" ]] || info "present   $path ($(human_size "$size"))"
        fi
      else
        PLAN_MISMATCH=$((PLAN_MISMATCH + 1))
        if [[ "${CI_FORCE:-0}" == "1" || "${CI_REPAIR:-0}" == "1" ]]; then
          queue_add "$name" "$path" "$url" "$size" "$sha" "$gated" "$alt"
          warn "mismatch  $path (expected $size bytes, found $actual; queued)"
        else
          PLAN_BLOCKED=$((PLAN_BLOCKED + 1))
          err "mismatch  $path (expected $size bytes, found $actual; use --repair)"
        fi
      fi
    else
      PLAN_MISSING=$((PLAN_MISSING + 1))

      # A complete-but-corrupt staged file would make aria2 think the download
      # is already finished. Discard it now so the retry starts cleanly.
      if [[ -f "$stage" ]]; then
        local ssize
        ssize="$(file_size "$stage" 2>/dev/null || printf '0')"
        if [[ "$ssize" == "$size" ]]; then
          if ! hash_matches "$(sha256_file "$stage" 2>/dev/null || true)" "$sha" "$alt"; then
            warn "discard   $path (staged file has a bad checksum)"
            rm -f -- "$stage" "$stage.aria2"
          fi
        elif (( ssize > size )); then
          warn "discard   $path (staged file is larger than expected)"
          rm -f -- "$stage" "$stage.aria2"
        fi
      fi

      queue_add "$name" "$path" "$url" "$size" "$sha" "$gated" "$alt"
      if [[ -f "$stage" ]]; then
        PLAN_RESUME=$((PLAN_RESUME + 1))
        [[ "${CI_QUIET:-0}" == "1" ]] || info "resume    $path (partial download found)"
      else
        [[ "${CI_QUIET:-0}" == "1" ]] || info "missing   $path ($(human_size "$size"))"
      fi
    fi
  done < <(model_rows)
}

queue_total_bytes() {
  local total=0 n
  for n in "${QUEUE_SIZES[@]}"; do
    total=$((total + n))
  done
  printf '%s' "$total"
}

# ---------------------------------------------------------------------------
# Preflight checks
# ---------------------------------------------------------------------------
preflight_space() {
  [[ "${CI_SKIP_SPACE_CHECK:-0}" == "1" ]] && return 0
  have df || { warn "df not found; skipping disk space check"; return 0; }

  local needed free extra headroom
  needed="$(queue_total_bytes)"
  headroom=$((100 * 1024 * 1024))
  extra=$((needed + headroom))

  ensure_dir "$CI_STAGE_ROOT"
  ensure_dir "$CI_COMFY_DIR"

  free="$(free_bytes "$CI_COMFY_DIR")"
  [[ -n "$free" ]] || { warn "could not determine free space for $CI_COMFY_DIR"; return 0; }

  if (( free < extra )); then
    die "not enough free space in $CI_COMFY_DIR: need $(human_size "$extra") (downloads + 100 MiB headroom), have $(human_size "$free"). Free space or use --skip-space-check."
  fi

  # The staging area should normally live on the same filesystem as ComfyUI.
  # If it does not, both sides need room for the data.
  local dest_dev stage_dev
  dest_dev="$(stat -c '%d' "$CI_COMFY_DIR" 2>/dev/null || stat -f '%d' "$CI_COMFY_DIR" 2>/dev/null || true)"
  stage_dev="$(stat -c '%d' "$CI_STAGE_ROOT" 2>/dev/null || stat -f '%d' "$CI_STAGE_ROOT" 2>/dev/null || true)"
  if [[ -n "$dest_dev" && -n "$stage_dev" && "$dest_dev" != "$stage_dev" ]]; then
    local sfree
    sfree="$(free_bytes "$CI_STAGE_ROOT")"
    if [[ -n "$sfree" ]] && (( sfree < extra )); then
      die "not enough free space in staging area $CI_STAGE_ROOT: need $(human_size "$extra"), have $(human_size "$sfree")"
    fi
    warn "staging area is on a different filesystem; final moves will copy data"
  fi

  info "space     need $(human_size "$needed") + 100 MiB headroom, free $(human_size "$free")"
}

preflight_auth() {
  local i token repo code header
  local -A checked=()

  for i in "${!QUEUE_PATHS[@]}"; do
    [[ "${QUEUE_GATED[$i],,}" == "true" ]] || continue
    local url="${QUEUE_URLS[$i]}"
    local path="${QUEUE_PATHS[$i]}"

    if ! is_hf_url "$url"; then
      warn "gated model is not hosted on huggingface.co; no token will be sent: $path"
      continue
    fi

    repo="$(hf_repo_from_url "$url")"
    [[ -n "$repo" && "$repo" != "$url" ]] || die "could not parse Hugging Face repo from URL: $url"

    if [[ -z "${HF_TOKEN_CACHE:-}" ]]; then
      HF_TOKEN_CACHE="$(discover_hf_token)"
    fi
    token="$HF_TOKEN_CACHE"
    [[ -n "$token" ]] \
      || die "gated model requires a Hugging Face token: $path
       Accept the terms at https://huggingface.co/$repo and then either
       export HF_TOKEN=... or run 'huggingface-cli login'."

    [[ -n "${checked[$repo]:-}" ]] && continue
    checked[$repo]=1

    if [[ "${CI_SKIP_AUTH_CHECK:-0}" == "1" ]]; then
      continue
    fi

    local cfg
    cfg="$(curl_auth_config "$token")"
    header="$(curl -sSIL -m 30 --config "$cfg" "$url" 2>/dev/null || true)"
    rm -f -- "$cfg"
    code="$(printf '%s\n' "$header" | awk '/^HTTP\// { c=$2 } END { print c }')"
    case "$code" in
      200|206|302|307)
        info "gated     access OK for $repo"
        ;;
      401|403)
        die "access denied for gated repo $repo.
       Open https://huggingface.co/$repo and accept the license/terms with the
       account that owns this token, then retry."
        ;;
      404)
        die "model URL returned 404: $url"
        ;;
      ""|000)
        warn "could not verify gated access for $repo (network error); continuing"
        ;;
      *)
        warn "unexpected HTTP $code while checking $repo; continuing"
        ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# Downloading
# ---------------------------------------------------------------------------
download_all() {
  ensure_dir "$CI_STAGE_ROOT/$M_ID"

  # If preflight_auth was skipped, make sure a token is available for gated
  # downloads (it is only ever attached to huggingface.co URLs).
  local need_token=0 i
  for i in "${!QUEUE_GATED[@]}"; do
    if [[ "${QUEUE_GATED[$i],,}" == "true" ]] && is_hf_url "${QUEUE_URLS[$i]}"; then
      need_token=1
      break
    fi
  done
  if (( need_token == 1 )) && [[ -z "${HF_TOKEN_CACHE:-}" ]]; then
    HF_TOKEN_CACHE="$(discover_hf_token)"
  fi

  local input rc=0
  input="$(mktemp "${TMPDIR:-/tmp}/comfy-inventory-aria2.XXXXXX")" || die "could not create temporary file"

  local i url path stage_file stage_dir token
  for i in "${!QUEUE_PATHS[@]}"; do
    url="${QUEUE_URLS[$i]}"
    path="${QUEUE_PATHS[$i]}"
    stage_file="$(stage_path_for "$path")"
    stage_dir="$(dirname -- "$stage_file")"
    ensure_dir "$stage_dir"

    {
      printf '%s\n' "$url"
      printf '  dir=%s\n' "$stage_dir"
      printf '  out=%s\n' "$(basename -- "$stage_file")"
      if [[ "${QUEUE_GATED[$i],,}" == "true" ]] && is_hf_url "$url"; then
        token="${HF_TOKEN_CACHE:-}"
        if [[ -n "$token" ]]; then
          printf '  header=Authorization: Bearer %s\n' "$token"
        fi
      fi
    } >> "$input"
  done

  local downloader="${CI_DOWNLOADER:-auto}"
  if [[ "$downloader" == "auto" ]]; then
    if have aria2c; then downloader="aria2c"; else downloader="curl"; fi
  fi
  [[ "$downloader" == "aria2c" || "$downloader" == "curl" ]] \
    || die "unsupported downloader '$downloader' (use auto, aria2c, or curl)"

  info "download  ${PLAN_QUEUED} file(s), $(human_size "$(queue_total_bytes)") total"

  case "$downloader" in
    aria2c)
      require aria2c "Install it with: sudo apt install aria2"
      local jobs="${CI_JOBS:-4}"
      local log_level="warn"
      [[ "${CI_QUIET:-0}" == "1" ]] && log_level="error"

      set +e
      aria2c \
        --input-file="$input" \
        --max-concurrent-downloads="$jobs" \
        --max-connection-per-server=8 \
        --split=8 \
        --min-split-size=10M \
        --continue=true \
        --allow-overwrite=true \
        --auto-file-renaming=false \
        --file-allocation=none \
        --max-tries=5 \
        --retry-wait=5 \
        --connect-timeout=30 \
        --timeout=60 \
        --summary-interval=30 \
        --console-log-level="$log_level" \
        --download-result=hide
      rc=$?
      set -e
      if (( rc != 0 )); then
        warn "aria2c exited with status $rc; checking which files completed"
      fi
      ;;
    curl)
      require curl
      info "download  using curl fallback (sequential)"
      local j
      for j in "${!QUEUE_PATHS[@]}"; do
        url="${QUEUE_URLS[$j]}"
        path="${QUEUE_PATHS[$j]}"
        stage_file="$(stage_path_for "$path")"
        ensure_dir "$(dirname -- "$stage_file")"

        local -a auth=()
        local cfg=""
        if [[ "${QUEUE_GATED[$j],,}" == "true" ]] && is_hf_url "$url"; then
          token="${HF_TOKEN_CACHE:-}"
          if [[ -n "$token" ]]; then
            cfg="$(curl_auth_config "$token")"
            auth=(--config "$cfg")
          fi
        fi

        info "download  $path"
        set +e
        if [[ -t 2 ]]; then
          curl -fL --retry 5 --retry-delay 3 --connect-timeout 30 \
            --continue-at - --progress-bar \
            "${auth[@]}" -o "$stage_file" "$url"
        else
          curl -fsSL --retry 5 --retry-delay 3 --connect-timeout 30 \
            --continue-at - \
            "${auth[@]}" -o "$stage_file" "$url"
        fi
        rc=$?
        set -e
        [[ -n "$cfg" ]] && rm -f -- "$cfg"
        (( rc == 0 )) || warn "curl failed for $path (status $rc)"
      done
      ;;
  esac

  rm -f -- "$input"
}

finalize_downloads() {
  local installed=0 failed=0
  local i name path stage_file dest actual hash expected

  for i in "${!QUEUE_PATHS[@]}"; do
    name="${QUEUE_NAMES[$i]}"
    path="${QUEUE_PATHS[$i]}"
    stage_file="$(stage_path_for "$path")"
    dest="$(dest_path_for "$path")"

    if [[ ! -f "$stage_file" ]]; then
      err "failed    $path (no downloaded file)"
      failed=$((failed + 1))
      continue
    fi

    actual="$(file_size "$stage_file" 2>/dev/null || printf '0')"
    if [[ "$actual" != "${QUEUE_SIZES[$i]}" ]]; then
      err "failed    $path (incomplete: $(human_size "$actual") of $(human_size "${QUEUE_SIZES[$i]}"); rerun to resume)"
      failed=$((failed + 1))
      continue
    fi

    hash="$(sha256_file "$stage_file" 2>/dev/null || true)"
    if ! hash_matches "$hash" "${QUEUE_SHAS[$i]}" "${QUEUE_ALTS[$i]}"; then
      expected="${QUEUE_SHAS[$i]}"
      [[ -n "${QUEUE_ALTS[$i]}" ]] && expected="$expected (or ${QUEUE_ALTS[$i]//|/, })"
      err "failed    $path (checksum mismatch: expected $expected, got ${hash:-<none>})"
      # A complete but corrupt stage file would fail forever on resume.
      # Drop it (and aria2's control file) so the next run starts fresh.
      rm -f -- "$stage_file" "$stage_file.aria2"
      failed=$((failed + 1))
      continue
    fi

    ensure_dir "$(dirname -- "$dest")"
    mv -f -- "$stage_file" "$dest"
    rm -f -- "$stage_file.aria2"
    installed=$((installed + 1))
    ok "installed $path ($(human_size "${QUEUE_SIZES[$i]}"))"
  done

  # Remove now-empty staging directories, but keep partials for a resume.
  find "$CI_STAGE_ROOT/$M_ID" -type d -empty -delete 2>/dev/null || true

  PLAN_INSTALLED=$installed
  PLAN_FAILED=$failed
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------
print_manifest_header() {
  info ""
  info "${C_BOLD}${M_NAME}${C_RESET}  ${C_DIM}(${M_ID})${C_RESET}"
  if [[ -n "$M_DESCRIPTION" ]]; then
    info "$M_DESCRIPTION"
  fi
  info "${C_DIM}manifest: $(display_path "$M_MANIFEST")${C_RESET}"
}

install_manifest() {
  local manifest="$1"
  validate_manifest "$manifest"
  print_manifest_header

  info ""
  info "Target: ${CI_COMFY_DIR}"

  if [[ "${CI_WORKFLOW_ONLY:-0}" == "1" ]]; then
    [[ -n "$M_WORKFLOW_FILE" ]] || die "manifest $M_ID has no workflow file; --workflow-only cannot be used"
    install_workflow
    info ""
    if [[ "$WORKFLOW_RESULT" == "differs" ]]; then
      warn "Workflow-only install did not update the existing workflow. Use --force-workflow to replace it."
      return 1
    fi
    if [[ "$WORKFLOW_RESULT" == "would-install" ]]; then
      info "Dry run: workflow would be installed."
      return 0
    fi
    ok "Workflow-only install complete."
    return 0
  fi

  info "Planning model files..."
  plan_models

  if (( PLAN_BLOCKED > 0 )); then
    die "$PLAN_BLOCKED existing file(s) do not match the manifest. Nothing was changed. Re-run with --repair to replace only missing/corrupt files, or --force to replace everything."
  fi

  install_workflow

  if (( PLAN_QUEUED == 0 )); then
    info ""
    if [[ "$WORKFLOW_RESULT" == "would-install" ]]; then
      info "Dry run: all model files are present; workflow would be installed."
      return 0
    fi
    ok "All model files are already installed."
    if [[ "$WORKFLOW_RESULT" == "differs" ]]; then
      warn "The workflow JSON was not updated (use --force-workflow to replace it)."
    fi
    return 0
  fi

  if [[ "${CI_DRY_RUN:-0}" == "1" ]]; then
    info ""
    info "Dry run: would download ${PLAN_QUEUED} file(s), $(human_size "$(queue_total_bytes)")."
    return 0
  fi

  preflight_space
  preflight_auth
  download_all
  finalize_downloads

  info ""
  info "Summary: ${PLAN_PRESENT} present, ${PLAN_INSTALLED:-0} installed, ${PLAN_FAILED:-0} failed, ${PLAN_QUEUED} queued."
  if (( ${PLAN_FAILED:-0} > 0 )); then
    err "Some files failed. Partial downloads are kept in $CI_STAGE_ROOT/$M_ID for resume."
    return 1
  fi
  if [[ "$WORKFLOW_RESULT" == "differs" ]]; then
    warn "Models are installed, but the workflow JSON was not updated (use --force-workflow)."
  else
    ok "Install complete."
  fi
}

status_manifest() {
  local manifest="$1"
  validate_manifest "$manifest"

  local total=0 present=0 missing=0 mismatch=0
  local name path url size sha gated alt dest actual

  if [[ "${CI_QUIET:-0}" != "1" ]]; then
    info ""
    info "${C_BOLD}${M_NAME}${C_RESET}  ${C_DIM}(${M_ID})${C_RESET}"
  fi

  while IFS=$'\t' read -r name path url size sha gated alt; do
    total=$((total + 1))
    dest="$(dest_path_for "$path")"
    if [[ -f "$dest" ]]; then
      actual="$(file_size "$dest" 2>/dev/null || printf '0')"
      if [[ "$actual" == "$size" ]]; then
        present=$((present + 1))
        [[ "${CI_VERBOSE:-0}" == "1" ]] && ok "present   $path"
      else
        mismatch=$((mismatch + 1))
        [[ "${CI_VERBOSE:-0}" == "1" ]] && err "mismatch  $path (expected $size, found $actual)"
      fi
    else
      missing=$((missing + 1))
      [[ "${CI_VERBOSE:-0}" == "1" ]] && warn "missing   $path"
    fi
  done < <(model_rows)

  local wf_state="n/a"
  if [[ -n "$M_WORKFLOW_FILE" ]]; then
    local src dest
    src="$(workflow_source_path)"
    dest="$(workflow_dest_path)"
    if [[ ! -f "$dest" ]]; then
      wf_state="missing"
    elif cmp -s -- "$src" "$dest"; then
      wf_state="installed"
    else
      wf_state="differs"
    fi
  fi

  local rc=0
  (( missing == 0 && mismatch == 0 )) || rc=1
  if [[ "$wf_state" == "missing" || "$wf_state" == "differs" ]]; then
    rc=1
  fi

  if [[ "${CI_QUIET:-0}" != "1" ]]; then
    info "models    $present/$total present, $missing missing, $mismatch wrong size"
    info "workflow  $wf_state"
  fi
  return $rc
}

verify_manifest() {
  local manifest="$1"
  validate_manifest "$manifest"

  info ""
  info "${C_BOLD}${M_NAME}${C_RESET}  ${C_DIM}(${M_ID})${C_RESET}"

  local failed=0 total=0
  local name path url size sha gated alt dest actual hash expected

  while IFS=$'\t' read -r name path url size sha gated alt; do
    total=$((total + 1))
    dest="$(dest_path_for "$path")"
    if [[ ! -f "$dest" ]]; then
      err "missing   $path"
      failed=$((failed + 1))
      continue
    fi
    actual="$(file_size "$dest" 2>/dev/null || printf '0')"
    if [[ "$actual" != "$size" ]]; then
      err "size      $path (expected $size, found $actual)"
      failed=$((failed + 1))
      continue
    fi
    info "hashing   $path ($(human_size "$actual")) ..."
    hash="$(sha256_file "$dest" 2>/dev/null || true)"
    if hash_matches "$hash" "$sha" "$alt"; then
      ok "verified  $path"
    else
      expected="$sha"
      [[ -n "$alt" ]] && expected="$expected (or ${alt//|/, })"
      err "checksum  $path (expected $expected, got ${hash:-<none>})"
      failed=$((failed + 1))
    fi
  done < <(model_rows)

  if [[ -n "$M_WORKFLOW_FILE" ]]; then
    local dest
    dest="$(workflow_dest_path)"
    if [[ ! -f "$dest" ]]; then
      warn "workflow  not installed: $(display_path "$dest")"
      failed=$((failed + 1))
    elif cmp -s -- "$(workflow_source_path)" "$dest"; then
      ok "workflow  verified  $(display_path "$dest")"
    else
      err "workflow  differs from inventory copy: $(display_path "$dest")"
      failed=$((failed + 1))
    fi
  fi

  info ""
  if (( failed == 0 )); then
    ok "All $total model file(s) verified."
    return 0
  fi
  err "$failed of $total model file(s) failed verification."
  return 1
}
