#!/bin/zsh
set -euo pipefail

if [[ $# -lt 1 || $# -gt 3 ]]; then
  echo "usage: $0 <task-id> [discussion_only|implementation_bound] [oracle|sisyphus]" >&2
  exit 1
fi

raw_id="$1"
intent="${2:-implementation_bound}"
starter="${3:-sisyphus}"

# task-id에 YYYYMMDD- 접두사가 없으면 오늘 날짜를 자동으로 붙인다
if [[ "$raw_id" =~ ^[0-9]{8}- ]]; then
  task_id="$raw_id"
else
  task_id="$(date +%Y%m%d)-${raw_id}"
fi

case "$intent" in
  discussion_only|implementation_bound)
    ;;
  *)
    echo "invalid intent: $intent" >&2
    exit 1
    ;;
esac

case "$starter" in
  oracle|sisyphus)
    ;;
  *)
    echo "invalid starter: $starter" >&2
    exit 1
    ;;
esac

scorer="oracle"
if [[ "$starter" == "oracle" ]]; then
  scorer="sisyphus"
fi

base_dir=".protocol/runs/${task_id}"
abs_base_dir="$(pwd -P)/${base_dir}"
debate_dir="${base_dir}/debate"
round1_dir="${debate_dir}/round-001"
prompts_dir="${base_dir}/prompts"
review1_dir="${base_dir}/review1"
sisyphus_dir="${base_dir}/sisyphus"
oracle_dir="${base_dir}/oracle"
round1_oracle_prompt="${prompts_dir}/round-001-oracle.md"
round1_sisyphus_prompt="${prompts_dir}/round-001-sisyphus.md"

mkdir -p "$base_dir" "$debate_dir" "$round1_dir" "$prompts_dir"

if [[ "$intent" == "implementation_bound" ]]; then
  mkdir -p "${oracle_dir}" "${sisyphus_dir}" "$review1_dir"
fi

write_if_missing() {
  local path="$1"
  local content="$2"

  if [[ ! -f "$path" ]]; then
    printf '%s' "$content" > "$path"
  fi
}

write_if_missing "${base_dir}/00-brief.md" "# Brief

## Request

## Intent

- \`${intent}\`

## Starter

- \`${starter}\`

## Problem Statement

## Change Targets

## Non-Goals

## Constraints

## Relevant Files / Docs
"

write_if_missing "${round1_dir}/oracle.md" "# Oracle Round 001

## Oracle Position

## Oracle Critique

## Current State

- \`resolved\` | \`still_open\` | \`near_convergence\`

## Notes
"

write_if_missing "${round1_dir}/sisyphus.md" "# Sisyphus Round 001

## Sisyphus Position

## Sisyphus Critique

## Current State

- \`resolved\` | \`still_open\` | \`near_convergence\`

## Notes
"

write_if_missing "${round1_oracle_prompt}" "Oracle,

아래 canonical 파일만 읽고 작업하라.

- brief: \`${abs_base_dir}/00-brief.md\`
- counterpart round file: \`${abs_base_dir}/debate/round-001/sisyphus.md\`
- target file: \`${abs_base_dir}/debate/round-001/oracle.md\`

해야 할 일:

1. brief를 읽는다.
2. counterpart round file에 실질 내용이 있으면 그 내용을 읽고 반론/응답한다.
3. target file의 아래 섹션만 채운다.
   - \`## Oracle Position\`
   - \`## Oracle Critique\`
   - \`## Current State\`
   - \`## Notes\`
4. counterpart round file이 아직 placeholder 수준이면, 이번 응답을 opening position으로 작성한다.
5. target file 외 다른 round 파일은 수정하지 않는다.
6. stdout에는 짧게 \`updated <target file>\`만 출력한다.
"

write_if_missing "${round1_sisyphus_prompt}" "Sisyphus,

아래 canonical 파일만 읽고 작업하라.

- brief: \`${abs_base_dir}/00-brief.md\`
- counterpart round file: \`${abs_base_dir}/debate/round-001/oracle.md\`
- target file: \`${abs_base_dir}/debate/round-001/sisyphus.md\`

해야 할 일:

1. brief를 읽는다.
2. counterpart round file에 실질 내용이 있으면 그 내용을 읽고 반론/응답한다.
3. target file의 아래 섹션만 채운다.
   - \`## Sisyphus Position\`
   - \`## Sisyphus Critique\`
   - \`## Current State\`
   - \`## Notes\`
4. counterpart round file이 아직 placeholder 수준이면, 이번 응답을 opening position으로 작성한다.
5. target file 외 다른 round 파일은 수정하지 않는다.
6. stdout에는 짧게 \`updated <target file>\`만 출력한다.
"

write_if_missing "${base_dir}/01-debate-summary.md" "# Debate Summary

## Resolved

## Unresolved

## Position Summary By Issue

### issue-1

- Oracle:
- Sisyphus:
- Current conclusion:

## Decision For Next Stage

- selected: \`pending\`
"

write_if_missing "${base_dir}/02-debate-score.json" "{
  \"task_id\": \"${task_id}\",
  \"starter\": \"${starter}\",
  \"scorer\": \"${scorer}\",
  \"intent\": \"${intent}\",
  \"overall_verdict\": \"unresolved\",
  \"issues\": []
}
"

write_if_missing "${base_dir}/debate-meta.json" "{}"

write_if_missing "${base_dir}/stage-log.jsonl" ""

write_if_missing "${base_dir}/meta.json" "{
  \"task_id\": \"${task_id}\",
  \"starter\": \"${starter}\",
  \"oracle\": \"oracle\",
  \"implementer\": \"sisyphus\",
  \"intent\": \"${intent}\",
  \"oracle_model\": \"\",
  \"sisyphus_model\": \"\"
}
"

if [[ "$intent" == "implementation_bound" ]]; then
  write_if_missing "${base_dir}/03-contract.md" "# Contract

## Goal

## Non-Goals

## Files In Scope

## Structural Constraints

## Forbidden Approaches

## Acceptance Criteria

## Verification Plan
"

  write_if_missing "${prompts_dir}/contract-draft-${starter}.md" "$(if [[ "$starter" == "oracle" ]]; then echo "Oracle"; else echo "Sisyphus"; fi),

아래 canonical 파일만 읽고 contract 초안을 작성하라.

- brief: \`${abs_base_dir}/00-brief.md\`
- summary: \`${abs_base_dir}/01-debate-summary.md\`
- score: \`${abs_base_dir}/02-debate-score.json\`
- target file: \`${abs_base_dir}/03-contract.md\`

해야 할 일:

1. brief, summary, score를 읽는다.
2. \`03-contract.md\`의 아래 섹션을 실제 내용으로 채운다.
   - \`## Goal\`
   - \`## Non-Goals\`
   - \`## Files In Scope\`
   - \`## Structural Constraints\`
   - \`## Forbidden Approaches\`
   - \`## Acceptance Criteria\`
   - \`## Verification Plan\`
3. summary/score와 충돌하는 요구를 넣지 않는다.
4. target file 외 다른 파일은 수정하지 않는다.
5. stdout에는 짧게 \`updated contract draft\`만 출력한다.
"

  write_if_missing "${base_dir}/04-review1.md" "# Review1 Summary

## Review Bundle

- \`review1/code-review.md\`
- \`review1/security-review.md\`
- \`review1/architecture-review.md\`

## Overall Judgment

## Contract Compliance

## Key Findings

## Open Questions

## Remaining Risks
"

  write_if_missing "${review1_dir}/code-review.md" "# Code Review

## Critical

## High

## Medium

## Low
"

  write_if_missing "${review1_dir}/security-review.md" "# Security Review

## Critical

## High

## Medium

## Low
"

  write_if_missing "${review1_dir}/architecture-review.md" "# Architecture Review

## Critical

## High

## Medium

## Low
"

  write_if_missing "${review1_dir}/findings.json" "{
  \"task_id\": \"${task_id}\",
  \"summary\": {
    \"total_findings\": 0,
    \"by_part\": {
      \"code\": { \"critical\": 0, \"high\": 0, \"medium\": 0, \"low\": 0, \"total\": 0 },
      \"security\": { \"critical\": 0, \"high\": 0, \"medium\": 0, \"low\": 0, \"total\": 0 },
      \"architecture\": { \"critical\": 0, \"high\": 0, \"medium\": 0, \"low\": 0, \"total\": 0 }
    },
    \"implementer_mistakes\": {
      \"missing_requirement\": 0,
      \"wrong_behavior\": 0,
      \"out_of_scope_change\": 0,
      \"contract_violation\": 0,
      \"test_gap\": 0
    }
  },
  \"model_notes\": \"\",
  \"findings\": []
}
"

  write_if_missing "${base_dir}/05-oracle-final.md" "# Oracle Final Review

## Contract Compliance

## Final Judgment

## Remaining Risks

## Release Decision
"

  write_if_missing "${oracle_dir}/implementation-guardrails.md" "# Oracle Implementation Guardrails

## Must Hold Invariants

## Hidden Failure Modes

## Review Emphasis
"

  write_if_missing "${oracle_dir}/shadow-implementation-summary.md" "# Oracle Shadow Implementation Summary

## Scope Assumptions

## Stash / Isolation Record

## Files Touched

## Validation Run

## Compare Notes For Sisyphus Review

## Open Issues
"

  write_if_missing "${sisyphus_dir}/implementation-summary.md" "# Implementation Summary

## Contract Scope

## Files Changed

## Acceptance Criteria Status

## Validation Run

## Open Issues
"

  write_if_missing "${sisyphus_dir}/implementation-report.json" "{
  \"task_id\": \"${task_id}\",
  \"summary\": {
    \"contract_requirements_total\": 0,
    \"implemented_requirements_count\": 0,
    \"self_reported_known_gaps\": 0,
    \"validation_commands_run\": 0
  },
  \"model_notes\": \"\"
}
"

  write_if_missing "${oracle_dir}/shadow-implementation-report.json" "{
  \"task_id\": \"${task_id}\",
  \"summary\": {
    \"files_touched_count\": 0,
    \"validation_commands_run\": 0,
    \"stash_recorded\": false,
    \"comparison_ready\": false
  },
  \"stash_ref\": null,
  \"model_notes\": \"\"
}
"

  write_if_missing "${oracle_dir}/final-report.json" "{
  \"task_id\": \"${task_id}\",
  \"decision\": \"hold\",
  \"summary\": {
    \"oracle_total_findings\": 0,
    \"oracle_new_findings_missed_by_review1\": 0,
    \"oracle_carried_findings_from_review1\": 0,
    \"oracle_resolved_findings_from_review1\": 0,
    \"blocking_findings\": 0,
    \"implementer_mistakes_missed_by_review1\": {
      \"missing_requirement\": 0,
      \"wrong_behavior\": 0,
      \"out_of_scope_change\": 0,
      \"contract_violation\": 0,
      \"test_gap\": 0
    }
  },
  \"model_notes\": \"\",
  \"findings\": []
}
"

  write_if_missing "${base_dir}/06-fix-from-final.md" "# Fix From Final

## Findings Addressed

## Files Changed

## Validation Run

## Remaining Open Findings
"

  write_if_missing "${sisyphus_dir}/final-fix-report.json" "{
  \"task_id\": \"${task_id}\",
  \"summary\": {
    \"oracle_findings_total\": 0,
    \"findings_addressed_count\": 0,
    \"findings_remaining_open_count\": 0,
    \"validation_commands_run\": 0
  },
  \"model_notes\": \"\"
}
"

  write_if_missing "${base_dir}/07-oracle-closeout.md" "# Oracle Closeout

## Final Finding Closure

## Closeout Judgment

## Residual Risks

## Release Decision
"

  write_if_missing "${oracle_dir}/closeout-report.json" "{
  \"task_id\": \"${task_id}\",
  \"decision\": \"hold\",
  \"summary\": {
    \"oracle_total_findings\": 0,
    \"findings_closed_after_fix\": 0,
    \"findings_still_open\": 0,
    \"blocking_findings\": 0
  },
  \"model_notes\": \"\"
}
"
fi

printf '%s\n' "$abs_base_dir"
