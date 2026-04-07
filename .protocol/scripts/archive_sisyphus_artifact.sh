#!/bin/zsh
set -euo pipefail

# Sisyphus-starter 전용 아카이빙 래퍼
# Sisyphus가 이미 실행 중인 세션에서 직접 파일을 편집한 뒤,
# 아카이빙(사본 저장)과 stage-log 기록을 수행한다.
#
# 기존 run_sisyphus_sync.sh는 Claude CLI를 subprocess로 호출하는 구조라
# Sisyphus-starter에서는 사용할 수 없다. 이 스크립트가 그 역할을 대체한다.
#
# Usage: archive_sisyphus_artifact.sh <task-id> <artifact-id> <event-name> <artifact-file>
#
# 예시:
#   archive_sisyphus_artifact.sh 20260404-foo round-001 sisyphus_round_written debate/round-001/sisyphus.md
#   archive_sisyphus_artifact.sh 20260404-foo summary-score sisyphus_summary_written 01-debate-summary.md 02-debate-score.json
#
# artifact-file은 run dir 기준 상대경로 또는 절대경로.
# 여러 파일을 넘기면 전부 아카이빙한다.

if [[ $# -lt 4 ]]; then
  echo "usage: $0 <task-id> <artifact-id> <event-name> <artifact-file>..." >&2
  exit 1
fi

task_id="$1"
artifact_id="$2"
event_name="$3"
shift 3
artifact_files=("$@")

script_dir="${0:A:h}"
protocol_dir="${script_dir:h}"
repo_root="${protocol_dir:h}"
canonical_run_dir="${protocol_dir}/runs/${task_id}"
archive_dir="${canonical_run_dir}/sisyphus/archives"
stage_log="${canonical_run_dir}/stage-log.jsonl"
artifact_slug="$(printf '%s' "$artifact_id" | tr -cs 'A-Za-z0-9._-' '-')"

# ── 검증 ──

if [[ ! -d "$canonical_run_dir" ]]; then
  echo "missing canonical run dir: $canonical_run_dir" >&2
  exit 1
fi

if [[ ! -f "$stage_log" ]]; then
  echo "missing stage log: $stage_log" >&2
  exit 1
fi

mkdir -p "$archive_dir"

# ── 아카이빙 ──

typeset -a archived_paths
for artifact_file in "${artifact_files[@]}"; do
  artifact_abs="$artifact_file"
  if [[ "$artifact_abs" != /* ]]; then
    artifact_abs="${canonical_run_dir}/${artifact_abs}"
  fi

  if [[ ! -f "$artifact_abs" ]]; then
    echo "missing artifact file: $artifact_abs" >&2
    exit 1
  fi

  # placeholder만 있는 파일 감지
  line_count="$(wc -l < "$artifact_abs" | tr -d ' ')"
  if [[ "$line_count" -le 5 ]]; then
    echo "WARNING: artifact file looks like placeholder (${line_count} lines): $artifact_abs" >&2
    echo "  Sisyphus가 아직 내용을 작성하지 않은 것 같다. 작성 후 다시 실행하라." >&2
    exit 1
  fi

  # 사본 저장 (artifact-slug + 원본 파일명)
  base_name="${artifact_abs:t}"
  archive_path="${archive_dir}/${artifact_slug}--${base_name}"
  cp "$artifact_abs" "$archive_path"
  archived_paths+=("$archive_path")
done

# ── stage-log 기록 ──

timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
python3 - "$stage_log" "$timestamp" "$event_name" "$artifact_id" "${archived_paths[@]}" <<'PY'
import json
import sys

stage_log, timestamp, event_name, artifact_id, *archived_paths = sys.argv[1:]
record = {
    "timestamp": timestamp,
    "event": event_name,
    "artifact_id": artifact_id,
    "archived_paths": archived_paths,
}
with open(stage_log, "a", encoding="utf-8") as fh:
    fh.write(json.dumps(record, ensure_ascii=False) + "\n")
PY

echo "[sisyphus-archive] done:"
echo "  artifact: $artifact_id"
for p in "${archived_paths[@]}"; do
  echo "  archived: $p"
done
