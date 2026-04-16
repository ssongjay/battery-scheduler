#!/bin/zsh
set -euo pipefail

# Opening-first debate bootstrap wrapper
# Usage:
#   start_debate.sh <task-id> [oracle|sisyphus] [discussion_only|implementation_bound]
#
# It performs:
# 1. create_run.sh
# 2. Oracle opening + Sisyphus opening (starter order respected)
# 3. run_stage.sh <task-id> debate-discuss start

if [[ $# -lt 1 || $# -gt 3 ]]; then
  echo "usage: $0 <task-id> [oracle|sisyphus] [discussion_only|implementation_bound]" >&2
  exit 1
fi

task_id="$1"
starter="sisyphus"
intent="discussion_only"

for arg in "${@:2}"; do
  case "$arg" in
    oracle|sisyphus)
      starter="$arg"
      ;;
    discussion_only|implementation_bound)
      intent="$arg"
      ;;
    *)
      echo "invalid arg: $arg" >&2
      exit 1
      ;;
  esac
done

script_dir="${0:A:h}"
protocol_dir="${script_dir:h}"
run_dir="${protocol_dir}/runs/${task_id}"

"${script_dir}/create_run.sh" "$task_id" "$starter" "$intent"

if [[ "$starter" == "oracle" ]]; then
  "${script_dir}/run_oracle_opening.sh" "$task_id"
  "${script_dir}/run_sisyphus_opening.sh" "$task_id"
else
  "${script_dir}/run_sisyphus_opening.sh" "$task_id"
  "${script_dir}/run_oracle_opening.sh" "$task_id"
fi

"${script_dir}/run_stage.sh" "$task_id" debate-discuss start

echo "debate bootstrap complete:"
echo "  run: ${run_dir}"
echo "  starter: ${starter}"
echo "  intent: ${intent}"
