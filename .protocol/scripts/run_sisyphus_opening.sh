#!/bin/zsh
set -euo pipefail

# Sisyphus opening 실행
# Usage: run_sisyphus_opening.sh <task-id> [prompt-file]
#
# prompt-file 생략 시 prompts/opening-sisyphus.md 사용

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 <task-id> [prompt-file]" >&2
  exit 1
fi

task_id="$1"
script_dir="${0:A:h}"
protocol_dir="${script_dir:h}"
prompt_file="${2:-${protocol_dir}/runs/${task_id}/prompts/opening-sisyphus.md}"
target_file="${protocol_dir}/runs/${task_id}/debate/opening-sisyphus.md"

exec "${script_dir}/run_sisyphus_sync.sh" \
  "$task_id" \
  "opening-sisyphus" \
  "sisyphus_opening_synced" \
  "$prompt_file" \
  "$target_file"
