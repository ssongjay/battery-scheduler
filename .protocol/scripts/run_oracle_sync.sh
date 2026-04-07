#!/bin/zsh
set -euo pipefail

# Oracle 실행 동기화 래퍼
# codex exec로 Oracle을 호출하고, Oracle이 target 파일에 직접 작성한다.
#
# Usage: run_oracle_sync.sh <task-id> <artifact-id> <event-name> <prompt-file> <required-output>...
#
# Session management:
#   첫 호출 → codex exec --json (새 세션), session-id.txt에 thread_id 저장
#   이후   → codex exec resume <session-id> --json (같은 세션 이어하기)
#   session-id 저장 경로: .protocol/runs/<task-id>/oracle/session-id.txt
#
# Sandbox:
#   기본값: bypass (sandbox 완전 해제, Gradle/네트워크/DB 모두 가능)
#   옵션: read-only | workspace-write | danger-full-access | bypass
#   bypass = --dangerously-bypass-approvals-and-sandbox (sandbox 완전 해제, Gradle/네트워크 가능)
#
#   주의 (2026-04-04 테스트 확인):
#   - `codex exec resume`은 -s (sandbox), -m (model) 옵션을 받지 않는다.
#   - 첫 세션 생성 시 설정한 sandbox/model이 resume에서도 그대로 유지된다.
#   - 따라서 DB 쿼리가 필요한 토론은 반드시 첫 호출에서 -s danger-full-access로 열어야 한다.
#
# 환경 변수:
#   ORACLE_SANDBOX  — sandbox 모드 override (기본: danger-full-access)
#   ORACLE_MODEL    — codex 모델 override (기본: 미지정, codex 기본값 사용)

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
oracle_dir="${canonical_run_dir}/oracle"
oracle_response_dir="${oracle_dir}/responses"
stage_log="${canonical_run_dir}/stage-log.jsonl"
session_id_file="${oracle_dir}/session-id.txt"
artifact_slug="$(printf '%s' "$artifact_id" | tr -cs 'A-Za-z0-9._-' '-')"
response_text_out="${oracle_response_dir}/${artifact_slug}-response.txt"
json_out="${oracle_response_dir}/${artifact_slug}-output.jsonl"

sandbox="${ORACLE_SANDBOX:-bypass}"
model_arg=()
if [[ -n "${ORACLE_MODEL:-}" ]]; then
  model_arg=(-m "$ORACLE_MODEL")
fi

# ── 입력 검증 ──

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

mkdir -p "$oracle_response_dir"

# ── target 파일 mtime 기록 (변경 감지용) ──

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

# ── Oracle 실행 ──

cd "$repo_root"

if [[ -f "$session_id_file" ]]; then
  session_id="$(<"$session_id_file")"
  echo "[oracle-sync] Resuming Oracle session ${session_id} for ${artifact_id}"
  # resume은 원래 세션의 sandbox/model 설정을 유지하므로 -s, -m 불필요
  codex exec resume "$session_id" \
    --json \
    -o "$response_text_out" \
    - < "$prompt_abs" \
    > "$json_out" 2>/dev/null
else
  echo "[oracle-sync] Starting new Oracle session for ${task_id}/${artifact_id}"
  typeset -a sandbox_args
  if [[ "$sandbox" == "bypass" ]]; then
    sandbox_args=(--dangerously-bypass-approvals-and-sandbox)
  else
    sandbox_args=(-s "$sandbox")
  fi
  codex exec \
    --json \
    "${sandbox_args[@]}" \
    "${model_arg[@]}" \
    -o "$response_text_out" \
    - < "$prompt_abs" \
    > "$json_out" 2>/dev/null

  # thread_id 추출 및 저장
  new_session_id="$(head -1 "$json_out" | jq -r '.thread_id // empty')"
  if [[ -n "$new_session_id" ]]; then
    printf '%s\n' "$new_session_id" > "$session_id_file"
    echo "[oracle-sync] Saved session id: $new_session_id"
  else
    echo "[oracle-sync] WARNING: could not extract thread_id from codex output" >&2
  fi
fi

# ── 결과 검증 ──

if [[ ! -f "$response_text_out" ]]; then
  echo "missing response: $response_text_out" >&2
  exit 1
fi

if [[ ! -s "$response_text_out" ]]; then
  echo "Oracle response is empty: $response_text_out" >&2
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

# ── stage-log 기록 ──

timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
python3 - "$stage_log" "$timestamp" "$event_name" "$artifact_id" "$prompt_abs" "$response_text_out" "$json_out" "${required_abs[@]}" <<'PY'
import json
import sys

stage_log, timestamp, event_name, artifact_id, prompt_file, response_text, json_out, *required_outputs = sys.argv[1:]
record = {
    "timestamp": timestamp,
    "event": event_name,
    "artifact_id": artifact_id,
    "prompt_file": prompt_file,
    "response_text_path": response_text,
    "json_output_path": json_out,
    "required_outputs": required_outputs,
}
with open(stage_log, "a", encoding="utf-8") as fh:
    fh.write(json.dumps(record, ensure_ascii=False) + "\n")
PY

echo "[oracle-sync] done:"
echo "  artifact: $artifact_id"
echo "  text: $response_text_out"
echo "  jsonl: $json_out"
echo "  session: ${session_id_file}"
