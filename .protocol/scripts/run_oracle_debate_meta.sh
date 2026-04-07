#!/bin/zsh
set -euo pipefail

# Oracle debate meta 평가 실행
# Usage: run_oracle_debate_meta.sh <task-id> [prompt-file]

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 <task-id> [prompt-file]" >&2
  exit 1
fi

task_id="$1"
script_dir="${0:A:h}"
protocol_dir="${script_dir:h}"
run_dir="${protocol_dir}/runs/${task_id}"
prompt_file="${2:-${run_dir}/prompts/debate-meta-oracle.md}"

exec "${script_dir}/run_oracle_sync.sh" \
  "$task_id" \
  "debate-meta" \
  "oracle_debate_meta_synced" \
  "$prompt_file" \
  "${run_dir}/debate-meta.json"
