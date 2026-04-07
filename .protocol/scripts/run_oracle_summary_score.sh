#!/bin/zsh
set -euo pipefail

# Oracle summary/score 자동 실행
# starter=sisyphus일 때 scorer=oracle이므로 이 스크립트를 사용한다.
# starter=oracle이면 run_sisyphus_summary_score.sh를 쓸 것.
#
# Usage: run_oracle_summary_score.sh <task-id> [prompt-file]

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 <task-id> [prompt-file]" >&2
  exit 1
fi

task_id="$1"
script_dir="${0:A:h}"
protocol_dir="${script_dir:h}"
run_dir="${protocol_dir}/runs/${task_id}"
meta_path="${run_dir}/meta.json"

if [[ ! -f "$meta_path" ]]; then
  echo "missing meta.json: $meta_path" >&2
  exit 1
fi

starter="$(jq -r '.starter' "$meta_path")"
if [[ "$starter" == "oracle" ]]; then
  echo "summary/score scorer is sisyphus when starter=oracle; use run_sisyphus_summary_score.sh instead" >&2
  exit 1
fi

prompt_file="${2:-$("${script_dir}/create_summary_score_prompt.sh" "$task_id")}"

exec "${script_dir}/run_oracle_sync.sh" \
  "$task_id" \
  "summary-score" \
  "oracle_summary_score_synced" \
  "$prompt_file" \
  "${run_dir}/01-debate-summary.md" \
  "${run_dir}/02-debate-score.json"
