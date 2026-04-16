#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
protocol_dir="${script_dir:h}"
repo_root="${protocol_dir:h}"
consumers_path="${protocol_dir}/consumers.json"
lock_path="${protocol_dir}/protocol.lock"

export PROTOCOL_SCRIPT_DIR="$script_dir"
source "${script_dir}/protocol_common.sh"

lock_only=false
dry_run=false
override_consumers=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lock-only)
      lock_only=true
      shift
      ;;
    --dry-run)
      dry_run=true
      shift
      ;;
    --consumers-file)
      override_consumers="$2"
      shift 2
      ;;
    *)
      echo "usage: $0 [--lock-only] [--dry-run] [--consumers-file <path>]" >&2
      exit 1
      ;;
  esac
done

if [[ -n "$override_consumers" ]]; then
  consumers_path="$override_consumers"
fi

generate_lock() {
  python3 "${script_dir}/generate_protocol_lock.py" \
    --protocol-dir "$protocol_dir" \
    --repo-root "$repo_root" \
    --output "$lock_path"
}

consumer_dirty() {
  local consumer_root="$1"
  local rel_path status_out=""
  local -a artifacts
  artifacts=("${(@f)$(protocol_shared_artifacts)}")

  for rel_path in "${artifacts[@]}"; do
    [[ -n "$rel_path" ]] || continue
    status_out+="$(git -C "$consumer_root" status --porcelain -- ".protocol/${rel_path}" 2>/dev/null || true)"
  done
  [[ -n "$status_out" ]]
}

cleanup_stale_artifacts() {
  local consumer_protocol="$1"
  local rel_path consumer_rel
  local -a canonical_artifacts consumer_artifacts

  canonical_artifacts=("${(@f)$(protocol_shared_artifacts)}")
  consumer_artifacts=("${(@f)$(protocol_shared_artifacts "$consumer_protocol")}")

  for consumer_rel in "${consumer_artifacts[@]}"; do
    [[ -n "$consumer_rel" ]] || continue
    if (( ${canonical_artifacts[(Ie)$consumer_rel]} == 0 )); then
      if [[ "$dry_run" == "true" ]]; then
        echo "[release] DRY-RUN remove stale ${consumer_rel}" >&2
      else
        rm -f "${consumer_protocol}/${consumer_rel}"
      fi
    fi
  done
}

project_to_consumers() {
  if [[ ! -f "$consumers_path" ]]; then
    echo "missing consumers registry: $consumers_path" >&2
    exit 1
  fi

  local name rel_root abs_root consumer_protocol rel_path
  while IFS=$'\t' read -r name rel_root; do
    [[ -n "$name" ]] || continue
    abs_root="$(cd "$repo_root" && cd "$rel_root" && pwd -P)"
    if [[ ! -d "$abs_root/.git" ]]; then
      echo "consumer is not a git repo: $abs_root" >&2
      exit 1
    fi
    consumer_protocol="${abs_root}/.protocol"
    mkdir -p "${consumer_protocol}/scripts"

    if consumer_dirty "$abs_root"; then
      echo "consumer has dirty tracked/staged/untracked shared artifacts: $abs_root" >&2
      exit 1
    fi

    if [[ "$dry_run" == "true" ]]; then
      echo "[release] DRY-RUN project to ${name} (${abs_root})"
    else
      while IFS= read -r rel_path; do
        [[ -n "$rel_path" ]] || continue
        mkdir -p "${consumer_protocol}/${rel_path:h}"
        cp "${protocol_dir}/${rel_path}" "${consumer_protocol}/${rel_path}"
      done < <(protocol_shared_artifacts)
      cleanup_stale_artifacts "$consumer_protocol"
      cp "$lock_path" "${consumer_protocol}/protocol.lock"
    fi
  done < <(jq -r '.consumers[] | [.name, .path] | @tsv' "$consumers_path")
}

if [[ "$dry_run" == "true" ]]; then
  echo "[release] DRY-RUN mode"
  echo "[release] canonical source: ${protocol_dir}"
  if [[ "$lock_only" == "false" ]]; then
    project_to_consumers
  fi
  echo "[release] done (no writes)"
  exit 0
fi

generate_lock

if [[ "$lock_only" == "false" ]]; then
  project_to_consumers
fi

echo "[release] done"
