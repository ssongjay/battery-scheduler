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

intent="$(jq -r '.intent' "$meta_path")"
starter="$(jq -r '.starter' "$meta_path")"

if [[ "$intent" != "implementation_bound" ]]; then
  echo "contract draft prompt is only valid for implementation_bound: $task_id" >&2
  exit 1
fi

case "$starter" in
  oracle)
    drafter_name="Oracle"
    ;;
  sisyphus)
    drafter_name="Sisyphus"
    ;;
  *)
    echo "invalid starter in meta.json: $starter" >&2
    exit 1
    ;;
esac

prompt_path="${run_dir}/prompts/contract-draft-${starter}.md"

typeset -a round_paths
for round_dir in "${run_dir}"/debate/round-*; do
  [[ -d "$round_dir" ]] || continue
  round_id="${round_dir:t}"
  round_paths+=("- ${round_id/round-/round } oracle: \`${round_dir}/oracle.md\`")
  round_paths+=("- ${round_id/round-/round } sisyphus: \`${round_dir}/sisyphus.md\`")
done

cat > "$prompt_path" <<EOF
${drafter_name},

아래 canonical 파일만 읽고 contract 초안을 작성하라.

읽을 파일:

- brief: \`${run_dir}/00-brief.md\`
- summary: \`${run_dir}/01-debate-summary.md\`
- score: \`${run_dir}/02-debate-score.json\`
${(F)round_paths}

수정할 파일:

- contract target: \`${run_dir}/03-contract.md\`

작업 규칙:

1. brief, summary, score, round 파일만 근거로 사용한다.
2. \`03-contract.md\`의 핵심 섹션을 실제 내용으로 채운다.
3. unresolved 이슈를 구현 acceptance criteria로 숨겨 넘기지 않는다.
4. \`starter\`는 \`${starter}\`, contract 승인권은 \`oracle\`이라는 점을 전제로 초안만 작성한다.
5. target file 외 다른 파일은 수정하지 않는다.
6. stdout에는 짧게 \`updated contract draft\`만 출력한다.
EOF

printf '%s\n' "$prompt_path"
