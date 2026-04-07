#!/bin/zsh
set -euo pipefail

# Oracle 토론 라운드 실행
# Usage: run_oracle_round.sh <task-id> <round-id> [prompt-file]
#
# prompt-file 생략 시 prompts/<round-id>-oracle.md 사용

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "usage: $0 <task-id> <round-id> [prompt-file]" >&2
  exit 1
fi

task_id="$1"
round_id="$2"
script_dir="${0:A:h}"
protocol_dir="${script_dir:h}"
prompt_file="${3:-${protocol_dir}/runs/${task_id}/prompts/${round_id}-oracle.md}"
target_round_file="${protocol_dir}/runs/${task_id}/debate/${round_id}/oracle.md"

exec "${script_dir}/run_oracle_sync.sh" \
  "$task_id" \
  "$round_id" \
  "oracle_round_synced" \
  "$prompt_file" \
  "$target_round_file"
