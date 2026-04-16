#!/bin/zsh
set -euo pipefail

protocol_script_dir() {
  if [[ -n "${PROTOCOL_SCRIPT_DIR:-}" ]]; then
    printf '%s' "$PROTOCOL_SCRIPT_DIR"
    return 0
  fi
  printf '%s' "${0:A:h}"
}

protocol_dir() {
  printf '%s' "$(cd "$(protocol_script_dir)/.." && pwd -P)"
}

protocol_repo_root() {
  printf '%s' "$(cd "$(protocol_dir)/.." && pwd -P)"
}

protocol_local_dir() {
  printf '%s' "$(protocol_repo_root)/.protocol"
}

protocol_lock_path() {
  printf '%s' "$(protocol_local_dir)/protocol.lock"
}

protocol_detached_enabled() {
  local arg
  if [[ "${PROTOCOL_DETACHED:-0}" == "1" ]]; then
    return 0
  fi
  for arg in "$@"; do
    if [[ "$arg" == "--detached-protocol" ]]; then
      return 0
    fi
  done
  return 1
}

protocol_shared_artifacts() {
  local base_dir="${1:-$(protocol_local_dir)}"
  {
    printf '%s\n' "PROTOCOL.md"
    printf '%s\n' "RUN_GUIDE.md"
    printf '%s\n' "STAGE_CONTRACTS.md"
    printf '%s\n' "TEMPLATES.md"
    find "${base_dir}/scripts" -type f ! -path '*/__pycache__/*' -print \
      | sed "s#^${base_dir}/##"
  } | sort
}

protocol_checksum() {
  local file_path="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file_path" | awk '{print $1}'
  else
    shasum -a 256 "$file_path" | awk '{print $1}'
  fi
}

protocol_require_managed_alignment() {
  if protocol_detached_enabled "$@"; then
    return 0
  fi

  local lock_path
  lock_path="$(protocol_lock_path)"
  if [[ ! -f "$lock_path" ]]; then
    echo "missing protocol lock: $lock_path" >&2
    echo "run .protocol/scripts/release_protocol.sh first, or use --detached-protocol" >&2
    exit 1
  fi

  if ! jq -e '.artifacts | type == "object"' "$lock_path" >/dev/null 2>&1; then
    echo "malformed protocol lock: $lock_path" >&2
    exit 1
  fi

  typeset -A lock_artifacts
  local checksum entry
  local -a lock_entries

  lock_entries=("${(@f)$(jq -r '.artifacts | to_entries[] | [.key, .value] | @tsv' "$lock_path")}")

  for entry in "${lock_entries[@]}"; do
    rel_path="${entry%%$'\t'*}"
    checksum="${entry#*$'\t'}"
    [[ -n "$rel_path" ]] || continue
    lock_artifacts["$rel_path"]="$checksum"
  done

  local rel_path local_path actual expected
  local -a local_artifacts
  local missing=0
  local mismatched=0
  local untracked=0

  local_artifacts=("${(@f)$(protocol_shared_artifacts)}")

  for rel_path in "${local_artifacts[@]}"; do
    [[ -n "$rel_path" ]] || continue
    local_path="$(protocol_local_dir)/$rel_path"
    expected="${lock_artifacts["$rel_path"]:-}"
    if [[ -z "$expected" ]]; then
      echo "untracked protocol artifact: $rel_path" >&2
      ((untracked++))
      continue
    fi
    if [[ ! -f "$local_path" ]]; then
      echo "missing protocol artifact: $rel_path" >&2
      ((missing++))
      continue
    fi
    actual="$(protocol_checksum "$local_path")"
    if [[ "$actual" != "$expected" ]]; then
      echo "protocol drift detected: $rel_path" >&2
      echo "expected: $expected" >&2
      echo "actual:   $actual" >&2
      ((mismatched++))
    fi
    unset "lock_artifacts[\"$rel_path\"]"
  done

  if [[ ${#lock_artifacts[@]} -gt 0 ]]; then
    for rel_path in ${(k)lock_artifacts}; do
      echo "stale protocol lock entry: $rel_path" >&2
      ((untracked++))
    done
  fi

  if [[ $missing -gt 0 || $mismatched -gt 0 || $untracked -gt 0 ]]; then
    echo "protocol guard failed: ${missing} missing, ${mismatched} mismatched, ${untracked} untracked/stale" >&2
    echo "run .protocol/scripts/release_protocol.sh first, or use --detached-protocol" >&2
    exit 1
  fi
}
