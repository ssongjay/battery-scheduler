#!/bin/zsh
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 <task-id> [oracle|sisyphus]" >&2
  exit 1
fi

task_id="$1"
requested_evaluator="${2:-}"
script_dir="${0:A:h}"
protocol_dir="${script_dir:h}"
run_dir="${protocol_dir}/runs/${task_id}"
meta_path="${run_dir}/meta.json"
score_path="${run_dir}/02-debate-score.json"
summary_path="${run_dir}/01-debate-summary.md"

if [[ ! -f "$meta_path" ]]; then
  echo "missing meta.json: $meta_path" >&2
  exit 1
fi

starter="$(jq -r '.starter' "$meta_path")"
intent="$(jq -r '.intent' "$meta_path")"
scorer="$(jq -r '.scorer // empty' "$score_path" 2>/dev/null || true)"
if [[ -z "$scorer" || "$scorer" == "null" ]]; then
  if [[ "$starter" == "oracle" ]]; then
    scorer="sisyphus"
  else
    scorer="oracle"
  fi
fi

evaluator="$requested_evaluator"
if [[ -z "$evaluator" ]]; then
  evaluator="$scorer"
fi

case "$evaluator" in
  oracle|sisyphus)
    ;;
  *)
    echo "invalid evaluator: $evaluator" >&2
    exit 1
    ;;
esac

if [[ "$evaluator" == "oracle" ]]; then
  evaluator_name="Oracle"
else
  evaluator_name="Sisyphus"
fi

conflict_note=""
if [[ "$evaluator" == "$starter" && "$evaluator" == "$scorer" ]]; then
  conflict_note="현재 evaluator는 starter이면서 scorer다. notes 첫 문장에 이 이해충돌을 명시하라."
elif [[ "$evaluator" == "$starter" ]]; then
  conflict_note="현재 evaluator는 starter와 동일하다. 자기 initial framing을 평가하는 이해충돌이 있으므로 notes 첫 문장에 이 점을 명시하라."
elif [[ "$evaluator" == "$scorer" ]]; then
  conflict_note="현재 evaluator는 scorer와 동일하다. summary/score 작성자와 meta evaluator가 겹치므로 notes 첫 문장에 이 점을 명시하라."
fi

prompt_path="${run_dir}/prompts/debate-meta-${evaluator}.md"

typeset -a round_paths
for round_dir in "${run_dir}"/debate/round-*; do
  [[ -d "$round_dir" ]] || continue
  round_id="${round_dir:t}"
  round_paths+=("- ${round_id/round-/round } oracle: \`${round_dir}/oracle.md\`")
  round_paths+=("- ${round_id/round-/round } sisyphus: \`${round_dir}/sisyphus.md\`")
done

if [[ "$#round_paths" -eq 0 ]]; then
  echo "no debate rounds found under: ${run_dir}/debate" >&2
  exit 1
fi

cat > "$prompt_path" <<EOF
${evaluator_name},

이제 canonical debate meta를 채워라. 이 평가는 summary/score와 별도로, 토론 성향과 비교 우세 축을 구조화하는 용도다.

읽을 파일:

- brief: \`${run_dir}/00-brief.md\`
- summary: \`${summary_path}\`
- score: \`${score_path}\`
${(F)round_paths}

수정할 파일:

- debate meta target: \`${run_dir}/debate-meta.json\`

작업 규칙:

1. 위 파일들만 근거로 사용한다.
2. 자기 편을 과장하지 말고, 실제 토론에서 드러난 성향을 냉정하게 적는다.
3. ${conflict_note:-제3 evaluator가 아니면 notes 첫 문장에 평가자 중첩 여부를 간단히 밝힌다.}
4. 다른 파일은 수정하지 않는다.
5. stdout에는 짧게 \`updated debate meta\`만 출력한다.

## 필수 스키마 (debate-meta.json)

아래 필드명을 **정확히** 사용하라. 이름을 바꾸면 검증이 실패한다.

\`\`\`json
{
  "task_id": "${task_id}",
  "starter": "${starter}",
  "scorer": "${scorer}",
  "intent": "${intent}",
  "meta_evaluator": "${evaluator}",
  "meta_evaluator_model": "(사용 모델명, 예: gpt-5.4, claude-opus-4-6)",
  "oracle_profile": {
    "abstraction_level": "low | medium | high",
    "risk_posture": "low | medium | high",
    "evidence_orientation": "low | medium | high",
    "execution_bias": "low | medium | high",
    "adaptability": "low | medium | high"
  },
  "sisyphus_profile": {
    "abstraction_level": "low | medium | high",
    "risk_posture": "low | medium | high",
    "evidence_orientation": "low | medium | high",
    "execution_bias": "low | medium | high",
    "adaptability": "low | medium | high"
  },
  "comparative": {
    "problem_framing": "oracle | sisyphus | balanced",
    "bottleneck_identification": "oracle | sisyphus | balanced",
    "guardrail_design": "oracle | sisyphus | balanced",
    "convergence_driving": "oracle | sisyphus | balanced"
  },
  "notes": "성향 해석 메모 (string)"
}
\`\`\`

**profile 필드명** (5개, 정확히 이 이름):
- \`abstraction_level\`: 추상화 수준
- \`risk_posture\`: 리스크 감수 성향
- \`evidence_orientation\`: 증거 기반 정도
- \`execution_bias\`: 실행/구현 편향
- \`adaptability\`: 입장 수정 유연성

**comparative 필드명** (4개, 정확히 이 이름):
- \`problem_framing\`: 문제 정의 우세
- \`bottleneck_identification\`: 병목 식별 우세
- \`guardrail_design\`: 가드레일 설계 우세
- \`convergence_driving\`: 수렴 주도 우세

모든 값은 \`low | medium | high\` 또는 \`oracle | sisyphus | balanced\`만 허용된다.
EOF

printf '%s\n' "$prompt_path"
