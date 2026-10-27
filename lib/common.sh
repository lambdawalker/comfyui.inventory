#!/usr/bin/env bash
# Shared helpers for ComfyInventory.
# This file is sourced by bin/comfy-inventory and must not have side effects
# beyond defining functions and colour variables.

if [[ -n "${CI_COMMON_SH_LOADED:-}" ]]; then
  return 0
fi
CI_COMMON_SH_LOADED=1

CI_ROOT="${CI_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
CI_COLOR="${CI_COLOR:-auto}"
if [[ "$CI_COLOR" == "auto" ]]; then
  if [[ -t 2 && -z "${NO_COLOR:-}" ]]; then
    CI_COLOR=always
  else
    CI_COLOR=never
  fi
fi
if [[ "$CI_COLOR" == "always" ]]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
  C_CYAN=$'\033[36m'
else
  C_RESET="" C_BOLD="" C_DIM="" C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_CYAN=""
fi

# Progress and report lines go to stdout so `status`/`verify` can be
# redirected; warnings and errors go to stderr.
log()   { printf '%s\n' "$*"; }
info()  { printf '%s\n' "$*"; }
ok()    { printf '%s%s%s\n' "$C_GREEN" "$*" "$C_RESET"; }
warn()  { printf '%sWARN:%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()   { printf '%sERROR:%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
die()   { err "$*"; exit 1; }
debug() { if [[ "${CI_DEBUG:-0}" == "1" ]]; then printf '%sDEBUG:%s %s\n' "$C_DIM" "$C_RESET" "$*" >&2; fi; }

# ---------------------------------------------------------------------------
# Basic helpers
# ---------------------------------------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }

require() {
  local cmd="$1" hint="${2:-}"
  if ! have "$cmd"; then
    if [[ -n "$hint" ]]; then
      die "required command '$cmd' not found. $hint"
    else
      die "required command '$cmd' not found."
    fi
  fi
}

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

trim() {
  local s="${1-}"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

expand_home() {
  local p="${1-}"
  if [[ "$p" == "~" ]]; then
    p="$HOME"
  elif [[ "$p" == "~/"* ]]; then
    p="$HOME/${p#\~/}"
  fi
  printf '%s' "$p"
}

abspath() {
  local p
  p="$(expand_home "${1-}")"
  if have realpath; then
    realpath -m -- "$p"
  else
    # Portable fallback for the common case of an existing parent.
    ( cd -- "$(dirname -- "$p")" 2>/dev/null && printf '%s/%s\n' "$(pwd -P)" "$(basename -- "$p")" ) \
      || printf '%s\n' "$p"
  fi
}

file_size() {
  local f="$1" n
  n="$(wc -c < "$f" 2>/dev/null)" || return 1
  printf '%s' "$n"
}

sha256_file() {
  local f="$1" h
  if have sha256sum; then
    h="$(sha256sum -- "$f" 2>/dev/null | awk '{print $1}')" || return 1
  elif have shasum; then
    h="$(shasum -a 256 -- "$f" 2>/dev/null | awk '{print $1}')" || return 1
  else
    return 1
  fi
  printf '%s' "$h"
}

human_size() {
  awk -v b="${1:-0}" 'BEGIN {
    split("B KiB MiB GiB TiB PiB", unit, " ")
    i = 1
    while (b >= 1024 && i < 6) { b /= 1024; i++ }
    if (i == 1) printf "%d %s", b, unit[i]
    else printf "%.1f %s", b, unit[i]
  }'
}

# Print a path relative to $CI_ROOT when possible, for tidy logs.
display_path() {
  local p="$1"
  if [[ "$p" == "$CI_ROOT/"* ]]; then
    printf '%s' "${p#"$CI_ROOT/"}"
  else
    printf '%s' "$p"
  fi
}

# ---------------------------------------------------------------------------
# Filesystem helpers
# ---------------------------------------------------------------------------
ensure_dir() {
  local d="$1"
  [[ -d "$d" ]] || mkdir -p -- "$d"
}

# True when $1 is a path inside $2 (both absolute, no symlink resolution).
path_is_within() {
  local child="$1" parent="$2"
  [[ "$child" == "$parent" || "$child" == "$parent/"* ]]
}

free_bytes() {
  local path="$1"
  df -Pk -- "$path" 2>/dev/null | awk 'NR==2 { printf "%.0f", $4 * 1024 }'
}

# ---------------------------------------------------------------------------
# Locking
# ---------------------------------------------------------------------------
CI_LOCK_DIR=""

ci_lock() {
  local state_dir="$1"
  ensure_dir "$state_dir"
  if have flock; then
    # FD 9 is intentionally process-wide for the lifetime of the command.
    exec 9>"$state_dir/lock"
    if ! flock -n 9; then
      die "another ComfyInventory process is already running (lock: $state_dir/lock)"
    fi
    debug "acquired lock $state_dir/lock"
  else
    CI_LOCK_DIR="$state_dir/lock.d"
    if ! mkdir -- "$CI_LOCK_DIR" 2>/dev/null; then
      die "another ComfyInventory process is already running (lock: $CI_LOCK_DIR)"
    fi
    trap 'rmdir -- "$CI_LOCK_DIR" 2>/dev/null || true' EXIT
    debug "acquired lock $CI_LOCK_DIR"
  fi
}

# ---------------------------------------------------------------------------
# Misc
# ---------------------------------------------------------------------------
now_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }
timestamp() { date +%Y%m%d-%H%M%S; }

print_rule() {
  printf '%s\n' "--------------------------------------------------------------------------" >&2
}
