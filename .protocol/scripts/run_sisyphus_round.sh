#!/bin/zsh
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 <task-id> <round-id> <prompt-file>" >&2
  exit 1
fi

task_id="$1"
round_id="$2"
prompt_file="$3"

script_dir="${0:A:h}"
protocol_dir="${script_dir:h}"
target_round_file="${protocol_dir}/runs/${task_id}/debate/${round_id}/sisyphus.md"

exec "${script_dir}/run_sisyphus_sync.sh" \
  "$task_id" \
  "$round_id" \
  "sisyphus_round_synced" \
  "$prompt_file" \
  "$target_round_file"
