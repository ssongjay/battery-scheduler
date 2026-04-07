#!/bin/zsh
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <task-id>" >&2
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
intent="$(jq -r '.intent' "$meta_path")"

scorer="oracle"
scorer_name="Oracle"
if [[ "$starter" == "oracle" ]]; then
  scorer="sisyphus"
  scorer_name="Sisyphus"
fi

prompt_path="${run_dir}/prompts/summary-score-${scorer}.md"

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
${scorer_name},

이 토론은 사실상 종료됐다. 이제 canonical summary와 score를 직접 채워라.

읽을 파일:

- brief: \`${run_dir}/00-brief.md\`
${(F)round_paths}

수정할 파일:

- summary target: \`${run_dir}/01-debate-summary.md\`
- score target: \`${run_dir}/02-debate-score.json\`

작업 규칙:

1. 위 round 파일들만 근거로 사용한다.
2. \`01-debate-summary.md\`를 실제 내용으로 채운다.
3. \`02-debate-score.json\`도 실제 내용으로 채운다.
4. \`starter\`는 \`${starter}\`, \`scorer\`는 \`${scorer}\`, \`intent\`는 \`${intent}\`로 유지한다.
5. unresolved 이슈가 있으면 \`overall_verdict\`는 \`unresolved\`만 사용한다.
6. contract가 아직 없으면 각 issue의 \`adopted_in_contract\`는 \`false\`로 둔다.
7. \`score\`의 issue는 최소 4개 이상으로 구조화하라.
8. 다른 파일은 수정하지 않는다.
9. stdout에는 짧게 \`updated summary and score\`만 출력한다.

## summary 필수 구조 (01-debate-summary.md)

아래 markdown 헤딩을 **정확히** 사용하라. 이름을 바꾸면 검증이 실패한다.

\`\`\`
## Resolved
(합의된 항목 목록)

## Unresolved
(미합의 항목 목록, 없으면 "없음" 한 줄)

## Position Summary By Issue
(이슈별 Oracle/Sisyphus 입장 비교 테이블 또는 목록)

## Decision For Next Stage
(다음 단계 결정 설명)

- selected: stop_at_discussion
\`\`\`

\`selected:\` 값은 다음 중 하나다: \`stop_at_discussion\`, \`ready_for_contract\`, \`pending\`

## score 필수 스키마 (02-debate-score.json)

아래 필드명을 **정확히** 사용하라. 이름을 바꾸면 검증이 실패한다.

\`\`\`json
{
  "starter": "${starter}",
  "scorer": "${scorer}",
  "intent": "${intent}",
  "overall_verdict": "oracle_dominant | sisyphus_dominant | balanced | unresolved",
  "issues": [
    {
      "topic": "이슈 제목 (string)",
      "verdict": "oracle | sisyphus | converged | unresolved",
      "status": "resolved | unresolved",
      "confidence": "high | medium | low",
      "reason": "판정 근거 (string)",
      "adopted_in_contract": false
    }
  ]
}
\`\`\`

- \`overall_verdict\` 허용값: \`oracle_dominant\`, \`sisyphus_dominant\`, \`balanced\`, \`unresolved\`
- \`verdict\` 허용값: \`oracle\`, \`sisyphus\`, \`converged\`, \`unresolved\`
- \`status\` 허용값: \`resolved\`, \`unresolved\`
- \`confidence\` 허용값: \`high\`, \`medium\`, \`low\`
- unresolved 이슈가 1개라도 있으면 \`overall_verdict\`는 반드시 \`unresolved\`
EOF

printf '%s\n' "$prompt_path"
