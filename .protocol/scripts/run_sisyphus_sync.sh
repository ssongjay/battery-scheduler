#!/bin/zsh
set -euo pipefail

if [[ $# -lt 5 ]]; then
  echo "usage: $0 <task-id> <artifact-id> <event-name> <prompt-file> <required-output>..." >&2
  exit 1
fi

task_id="$1"
artifact_id="$2"
event_name="$3"
prompt_file="$4"
shift 4
required_outputs=("$@")

script_dir="${0:A:h}"
protocol_dir="${script_dir:h}"
repo_root="${protocol_dir:h}"
canonical_run_dir="${protocol_dir}/runs/${task_id}"
canonical_response_dir="${canonical_run_dir}/sisyphus/responses"
canonical_history_dir="${canonical_run_dir}/sisyphus/history"
canonical_artifact_dir="${canonical_run_dir}/sisyphus/artifacts"
stage_log="${canonical_run_dir}/stage-log.jsonl"
launcher_script="${SISYPHUS_LOCAL_SCRIPT:-peer_local.sh}"
session_id_out="${canonical_response_dir}/session-id.txt"
artifact_slug="$(printf '%s' "$artifact_id" | tr -cs 'A-Za-z0-9._-' '-')"
response_text_out="${canonical_response_dir}/${artifact_slug}-response.txt"
response_json_out="${canonical_response_dir}/${artifact_slug}-response.json"
history_out="${canonical_history_dir}/${artifact_slug}-history.log"
artifact_markdown_out="${canonical_artifact_dir}/${artifact_slug}.md"

if [[ ! -d "$canonical_run_dir" ]]; then
  echo "missing canonical run dir: $canonical_run_dir" >&2
  exit 1
fi

if [[ ! -f "$stage_log" ]]; then
  echo "missing stage log: $stage_log" >&2
  exit 1
fi

prompt_abs="$prompt_file"
if [[ "$prompt_abs" != /* ]]; then
  prompt_abs="${repo_root}/${prompt_abs}"
fi

if [[ ! -f "$prompt_abs" ]]; then
  echo "missing prompt file: $prompt_abs" >&2
  exit 1
fi

mkdir -p "$canonical_response_dir" "$canonical_history_dir" "$canonical_artifact_dir"

launcher_path="$launcher_script"
if [[ "$launcher_path" != /* ]]; then
  launcher_path="${repo_root}/.claude/session-management/scripts/${launcher_script}"
fi

if [[ ! -x "$launcher_path" ]]; then
  echo "missing launcher script: $launcher_path" >&2
  exit 1
fi

typeset -a required_abs before_mtimes
for required_output in "${required_outputs[@]}"; do
  required_abs_path="$required_output"
  if [[ "$required_abs_path" != /* ]]; then
    required_abs_path="${repo_root}/${required_abs_path}"
  fi
  if [[ ! -f "$required_abs_path" ]]; then
    echo "missing required output file: $required_abs_path" >&2
    exit 1
  fi
  required_abs+=("$required_abs_path")
  before_mtimes+=("$(stat -f '%m' "$required_abs_path" 2>/dev/null || echo 0)")
done

export CLAUDE_LATEST_TEXT_FILE="$response_text_out"
export CLAUDE_LATEST_JSON_FILE="$response_json_out"
export CLAUDE_HISTORY_LOG_FILE="$history_out"
export CLAUDE_SESSION_ID_MIRROR_FILE="$session_id_out"

(
  cd "$repo_root"
  "$launcher_path" "$task_id" "$prompt_abs"
) >/dev/null

for mirrored_file in "$response_text_out" "$response_json_out" "$history_out"; do
  if [[ ! -f "$mirrored_file" ]]; then
    echo "missing expected canonical Claude output: $mirrored_file" >&2
    exit 1
  fi
done

if [[ ! -s "$response_text_out" ]]; then
  echo "Claude response text is empty: $response_text_out" >&2
  exit 1
fi

if [[ ! -f "$session_id_out" ]]; then
  echo "missing mirrored session id file: $session_id_out" >&2
  exit 1
fi

for idx in {1..$#required_abs}; do
  output_path="${required_abs[$idx]}"
  before_mtime="${before_mtimes[$idx]}"
  after_mtime="$(stat -f '%m' "$output_path" 2>/dev/null || echo 0)"
  if [[ "$after_mtime" -le "$before_mtime" ]]; then
    echo "required output was not updated: $output_path" >&2
    exit 1
  fi
done

timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
python3 - "$stage_log" "$timestamp" "$event_name" "$artifact_id" "$prompt_abs" "$response_text_out" "$response_json_out" "$history_out" "${required_abs[@]}" <<'PY'
import json
import sys

stage_log, timestamp, event_name, artifact_id, prompt_file, response_text, response_json, history, *required_outputs = sys.argv[1:]
record = {
    "timestamp": timestamp,
    "event": event_name,
    "artifact_id": artifact_id,
    "prompt_file": prompt_file,
    "response_text_path": response_text,
    "response_json_path": response_json,
    "history_path": history,
    "required_outputs": required_outputs,
}
with open(stage_log, "a", encoding="utf-8") as fh:
    fh.write(json.dumps(record, ensure_ascii=False) + "\n")
PY

python3 "${script_dir}/write_claude_stage_artifact.py" \
  "$task_id" \
  "$artifact_id" \
  "$event_name" \
  "$canonical_run_dir" \
  "$prompt_abs" \
  "$response_text_out" \
  "$response_json_out" \
  "$history_out" \
  "$artifact_markdown_out" \
  "${required_abs[@]}"

echo "synced sisyphus artifact:"
echo "  artifact: $artifact_id"
echo "  text: $response_text_out"
echo "  json: $response_json_out"
echo "  history: $history_out"
echo "  markdown: $artifact_markdown_out"
