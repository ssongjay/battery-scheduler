#!/bin/zsh
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <task-id> <round-number>" >&2
  exit 1
fi

task_id="$1"
round_number="$2"

if ! [[ "$round_number" =~ '^[0-9]+$' ]]; then
  echo "round-number must be an integer: $round_number" >&2
  exit 1
fi

script_dir="${0:A:h}"
protocol_dir="${script_dir:h}"
run_dir="${protocol_dir}/runs/${task_id}"
meta_path="${run_dir}/meta.json"
prompts_dir="${run_dir}/prompts"
debate_dir="${run_dir}/debate"
round_id="$(printf 'round-%03d' "$round_number")"
round_dir="${debate_dir}/${round_id}"
oracle_round_path="${round_dir}/oracle.md"
sisyphus_round_path="${round_dir}/sisyphus.md"
oracle_prompt_path="${prompts_dir}/${round_id}-oracle.md"
sisyphus_prompt_path="${prompts_dir}/${round_id}-sisyphus.md"

if [[ ! -d "$run_dir" || ! -f "$meta_path" ]]; then
  echo "run directory not found: $run_dir" >&2
  exit 1
fi

starter="$(jq -r '.starter' "$meta_path")"

mkdir -p "$prompts_dir" "$debate_dir" "$round_dir" "${debate_dir}/raw"

write_if_missing() {
  local path="$1"
  local content="$2"
  if [[ ! -f "$path" ]]; then
    printf '%s' "$content" > "$path"
  fi
}

write_round_prompt() {
  local actor="$1"
  local prompt_path="$2"
  local target_file="$3"
  local counterpart_file="$4"
  local previous_same_file="${5:-}"
  local actor_name section_prefix counterpart_name

  if [[ "$actor" == "oracle" ]]; then
    actor_name="Oracle"
    section_prefix="Oracle"
    counterpart_name="Sisyphus"
  else
    actor_name="Sisyphus"
    section_prefix="Sisyphus"
    counterpart_name="Oracle"
  fi

  cat > "$prompt_path" <<EOF
${actor_name},

아래 canonical 파일만 읽고 작업하라.

- brief: \`${run_dir}/00-brief.md\`
EOF

  if [[ -n "$previous_same_file" ]]; then
    cat >> "$prompt_path" <<EOF
- previous your round file: \`${previous_same_file}\`
EOF
  fi

  cat >> "$prompt_path" <<EOF
- counterpart round file: \`${counterpart_file}\`
- target file: \`${target_file}\`

## 토론 원칙 (반드시 준수)

너는 상대와 **동급 토론자**다. 목적은 합의가 아니라 **약점 발견과 검증**이다.

필수 규칙:
- 상대 주장의 약점, 허점, 약한 가정을 **적극적으로 공격**한다.
- "좋은 지적이다", "동의한다"로 시작하지 마라. 먼저 반박하고, 정말 옳은 부분만 인정한다.
- 상대 주장을 수용하기 전에 **대안을 제시하고 비교**해야 한다. 대안 없이 수용하면 항복이다.
- 수치, 코드, 데이터로 반박한다. "그럴 수 있다" 같은 모호한 인정은 금지.
- 라운드 수가 늘어나는 것을 두려워하지 마라. 5~8라운드가 정상이다.

자기 점검 (응답 작성 전 반드시 확인):
- 이 라운드에서 상대 주장의 **핵심 약점 최소 1개**를 지적했는가?
- 상대가 양보한 척 하면서 핵심을 바꾸는 것은 아닌가?
- "근거 없이 그럴듯해서" 동의한 것은 아닌가?
- 내 반박이 부차적 디테일이 아닌 **핵심 논리**를 겨냥하고 있는가?

## 해야 할 일

1. brief를 읽는다.
2. counterpart round file에 실질 내용이 있으면 그 내용을 읽고 **비판적으로** 반론/응답한다.
3. previous your round file이 있으면 자기 기존 입장과 무엇이 달라졌는지 반영한다.
4. target file의 아래 섹션만 채운다.
   - \`## ${section_prefix} Position\`
   - \`## ${section_prefix} Critique\`
   - \`## Current State\`
   - \`## Notes\`
5. counterpart round file이 아직 placeholder 수준이면, 이번 응답을 opening position으로 작성한다.
6. target file 외 다른 round 파일은 수정하지 않는다.
7. stdout에는 짧게 \`updated <target file>\`만 출력한다.
EOF
}

write_if_missing "$oracle_round_path" "# Oracle Round $(printf '%03d' "$round_number")

## Oracle Position

## Oracle Critique

## Current State

- \`resolved\` | \`still_open\` | \`near_convergence\`

## Notes
"

write_if_missing "$sisyphus_round_path" "# Sisyphus Round $(printf '%03d' "$round_number")

## Sisyphus Position

## Sisyphus Critique

## Current State

- \`resolved\` | \`still_open\` | \`near_convergence\`

## Notes
"

if [[ "$round_number" -eq 1 ]]; then
  write_round_prompt "oracle" "$oracle_prompt_path" "$oracle_round_path" "$sisyphus_round_path"
  write_round_prompt "sisyphus" "$sisyphus_prompt_path" "$sisyphus_round_path" "$oracle_round_path"
else
  previous_round_number=$((round_number - 1))
  previous_round_id="$(printf 'round-%03d' "$previous_round_number")"
  previous_oracle_round_path="${debate_dir}/${previous_round_id}/oracle.md"
  previous_sisyphus_round_path="${debate_dir}/${previous_round_id}/sisyphus.md"

  if [[ ! -f "$previous_oracle_round_path" || ! -f "$previous_sisyphus_round_path" ]]; then
    echo "missing previous round files under: ${debate_dir}/${previous_round_id}" >&2
    exit 1
  fi

  write_round_prompt "oracle" "$oracle_prompt_path" "$oracle_round_path" "$sisyphus_round_path" "$previous_oracle_round_path"
  write_round_prompt "sisyphus" "$sisyphus_prompt_path" "$sisyphus_round_path" "$oracle_round_path" "$previous_sisyphus_round_path"
fi

if [[ "$starter" == "oracle" ]]; then
  printf '%s\n' "$sisyphus_prompt_path"
else
  printf '%s\n' "$oracle_prompt_path"
fi
