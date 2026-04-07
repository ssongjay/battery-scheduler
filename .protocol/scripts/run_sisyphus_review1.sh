#!/bin/zsh
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 <task-id> [prompt-file]" >&2
  exit 1
fi

task_id="$1"
script_dir="${0:A:h}"
protocol_dir="${script_dir:h}"
run_dir="${protocol_dir}/runs/${task_id}"
prompt_file="${2:-${run_dir}/prompts/review1-from-contract-sisyphus.md}"

export SISYPHUS_LOCAL_SCRIPT="review1_local.sh"

exec "${script_dir}/run_sisyphus_sync.sh" \
  "$task_id" \
  "review1" \
  "sisyphus_review1_synced" \
  "$prompt_file" \
  "${run_dir}/review1/code-review.md" \
  "${run_dir}/review1/security-review.md" \
  "${run_dir}/review1/architecture-review.md" \
  "${run_dir}/review1/findings.json" \
  "${run_dir}/04-review1.md"
