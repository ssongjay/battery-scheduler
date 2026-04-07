#!/bin/zsh
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "usage: $0 <task-id> <stage> [start|complete]" >&2
  exit 1
fi

task_id="$1"
stage="$2"
action="${3:-start}"

case "$stage" in
  debate-discuss|debate-build|oracle-pre-impl-guardrails|oracle-shadow-implement|implement-from-contract|review1-from-contract|oracle-final-review|fix-from-final|oracle-closeout)
    ;;
  *)
    echo "invalid stage: $stage" >&2
    exit 1
    ;;
esac

case "$action" in
  start|complete)
    ;;
  *)
    echo "invalid action: $action" >&2
    exit 1
    ;;
esac

script_dir="${0:A:h}"
protocol_dir="${script_dir:h}"
repo_root="${protocol_dir:h}"
run_dir="${protocol_dir}/runs/${task_id}"

meta_path="${run_dir}/meta.json"
stage_log_path="${run_dir}/stage-log.jsonl"
brief_path="${run_dir}/00-brief.md"
summary_path="${run_dir}/01-debate-summary.md"
score_path="${run_dir}/02-debate-score.json"
debate_meta_path="${run_dir}/debate-meta.json"
contract_path="${run_dir}/03-contract.md"
review1_summary_path="${run_dir}/04-review1.md"
oracle_final_path="${run_dir}/05-oracle-final.md"
fix_from_final_path="${run_dir}/06-fix-from-final.md"
oracle_closeout_path="${run_dir}/07-oracle-closeout.md"
implementation_summary_path="${run_dir}/sisyphus/implementation-summary.md"
implementation_report_path="${run_dir}/sisyphus/implementation-report.json"
final_fix_report_path="${run_dir}/sisyphus/final-fix-report.json"
code_review_path="${run_dir}/review1/code-review.md"
security_review_path="${run_dir}/review1/security-review.md"
architecture_review_path="${run_dir}/review1/architecture-review.md"
review1_findings_path="${run_dir}/review1/findings.json"
oracle_guardrails_path="${run_dir}/oracle/implementation-guardrails.md"
oracle_shadow_summary_path="${run_dir}/oracle/shadow-implementation-summary.md"
oracle_shadow_report_path="${run_dir}/oracle/shadow-implementation-report.json"
oracle_final_report_path="${run_dir}/oracle/final-report.json"
oracle_closeout_report_path="${run_dir}/oracle/closeout-report.json"

require_file() {
  local file_path="$1"
  if [[ ! -f "$file_path" ]]; then
    echo "missing required file: $file_path" >&2
    exit 1
  fi
}

require_section_has_content() {
  local file_path="$1"
  local heading="$2"
  awk -v heading="$heading" '
    $0 == heading { in_section = 1; next }
    in_section && /^## / { exit found ? 0 : 1 }
    in_section && $0 !~ /^[[:space:]]*$/ { found = 1 }
    END {
      if (!in_section || !found) {
        exit 1
      }
    }
  ' "$file_path" >/dev/null 2>&1 || {
    echo "section has no content: ${heading} in ${file_path}" >&2
    exit 1
  }
}

json_field() {
  local key="$1"
  jq -r "$key" "$meta_path"
}

starter=""
intent=""
oracle_model=""
sisyphus_model=""

load_meta() {
  require_file "$meta_path"
  require_file "$stage_log_path"
  require_file "$brief_path"

  starter="$(json_field '.starter')"
  intent="$(json_field '.intent')"
  oracle_model="$(json_field '.oracle_model // ""')"
  sisyphus_model="$(json_field '.sisyphus_model // ""')"
}

resolve_owner() {
  case "$stage" in
    debate-discuss|debate-build)
      printf '%s' "starter"
      ;;
    oracle-pre-impl-guardrails|oracle-shadow-implement|oracle-final-review|oracle-closeout)
      printf '%s' "oracle"
      ;;
    implement-from-contract|review1-from-contract)
      printf '%s' "sisyphus"
      ;;
    fix-from-final)
      printf '%s' "sisyphus"
      ;;
  esac
}

require_intent_match() {
  case "$stage" in
    debate-discuss)
      [[ "$intent" == "discussion_only" ]] || {
        echo "stage $stage requires intent=discussion_only, got $intent" >&2
        exit 1
      }
      ;;
    debate-build|oracle-pre-impl-guardrails|oracle-shadow-implement|implement-from-contract|review1-from-contract|oracle-final-review|fix-from-final|oracle-closeout)
      [[ "$intent" == "implementation_bound" ]] || {
        echo "stage $stage requires intent=implementation_bound, got $intent" >&2
        exit 1
      }
      ;;
  esac
}

append_stage_log() {
  local event="$1"
  local owner="$2"
  local timestamp
  timestamp="$(date '+%Y-%m-%dT%H:%M:%S%z')"

  jq -cn \
    --arg timestamp "$timestamp" \
    --arg event "$event" \
    --arg task_id "$task_id" \
    --arg stage "$stage" \
    --arg intent "$intent" \
    --arg starter "$starter" \
    --arg owner "$owner" \
    --arg oracle_model "$oracle_model" \
    --arg sisyphus_model "$sisyphus_model" \
    '{
      timestamp: $timestamp,
      event: $event,
      task_id: $task_id,
      stage: $stage,
      intent: $intent,
      starter: $starter,
      owner: $owner,
      oracle_model: $oracle_model,
      sisyphus_model: $sisyphus_model
    }' >> "$stage_log_path"
}

selected_next_stage() {
  local selected
  selected="$(sed -n '/^## Decision For Next Stage$/,/^## /p' "$summary_path" | rg -o 'selected:\s*(pending|stop_at_discussion|ready_for_contract)' | head -n1 | sed -E 's/^selected:[[:space:]]*//; s/[[:space:]]+$//')"
  if [[ -z "$selected" ]]; then
    echo "summary missing selected next stage: $summary_path" >&2
    exit 1
  fi
  printf '%s' "$selected"
}

require_score_shape() {
  require_file "$score_path"

  jq -e '
    (.starter == $starter) and
    (.intent == $intent) and
    (.starter | type == "string") and
    (.scorer | type == "string") and
    (.starter != .scorer) and
    (.issues | type == "array") and
    (.issues | length > 0) and
    (.overall_verdict | IN("oracle_dominant", "sisyphus_dominant", "balanced", "unresolved")) and
    (.issues | all(
      .topic | type == "string" and length > 0
    )) and
    (.issues | all(
      .verdict | IN("oracle", "sisyphus", "converged", "unresolved")
    )) and
    (.issues | all(
      .status | IN("resolved", "unresolved")
    )) and
    (.issues | all(
      .confidence | IN("high", "medium", "low")
    )) and
    (.issues | all(
      .reason | type == "string" and length > 0
    )) and
    (([.issues[] | select(.status == "unresolved")] | length) as $unresolved_count |
      if $unresolved_count > 0 then
        .overall_verdict == "unresolved"
      else
        .overall_verdict != "unresolved"
      end)
  ' --arg starter "$starter" --arg intent "$intent" "$score_path" >/dev/null || {
    echo "invalid debate score shape: $score_path" >&2
    exit 1
  }
}

require_debate_meta_shape() {
  require_file "$debate_meta_path"

  jq -e '
    (.task_id == $task_id) and
    (.starter == $starter) and
    (.intent == $intent) and
    (.scorer | type == "string" and length > 0) and
    (.meta_evaluator | type == "string" and length > 0) and
    (.meta_evaluator_model | type == "string" and length > 0) and
    (.notes | type == "string" and length > 0) and
    (.oracle_profile.abstraction_level | IN("low", "medium", "high")) and
    (.oracle_profile.risk_posture | IN("low", "medium", "high")) and
    (.oracle_profile.evidence_orientation | IN("low", "medium", "high")) and
    (.oracle_profile.execution_bias | IN("low", "medium", "high")) and
    (.oracle_profile.adaptability | IN("low", "medium", "high")) and
    (.sisyphus_profile.abstraction_level | IN("low", "medium", "high")) and
    (.sisyphus_profile.risk_posture | IN("low", "medium", "high")) and
    (.sisyphus_profile.evidence_orientation | IN("low", "medium", "high")) and
    (.sisyphus_profile.execution_bias | IN("low", "medium", "high")) and
    (.sisyphus_profile.adaptability | IN("low", "medium", "high")) and
    (.comparative.problem_framing | IN("oracle", "sisyphus", "balanced")) and
    (.comparative.bottleneck_identification | IN("oracle", "sisyphus", "balanced")) and
    (.comparative.guardrail_design | IN("oracle", "sisyphus", "balanced")) and
    (.comparative.convergence_driving | IN("oracle", "sisyphus", "balanced"))
  ' --arg task_id "$task_id" --arg starter "$starter" --arg intent "$intent" "$debate_meta_path" >/dev/null || {
    echo "invalid debate meta shape: $debate_meta_path" >&2
    exit 1
  }
}

require_oracle_guardrails_shape() {
  require_file "$oracle_guardrails_path"
  rg -q '^## Must Hold Invariants$' "$oracle_guardrails_path" || {
    echo "oracle guardrails missing Must Hold Invariants section: $oracle_guardrails_path" >&2
    exit 1
  }
  require_section_has_content "$oracle_guardrails_path" '## Must Hold Invariants'
  require_section_has_content "$oracle_guardrails_path" '## Hidden Failure Modes'
  require_section_has_content "$oracle_guardrails_path" '## Review Emphasis'
}

require_oracle_shadow_shape() {
  require_file "$oracle_shadow_summary_path"
  require_file "$oracle_shadow_report_path"
  require_section_has_content "$oracle_shadow_summary_path" '## Scope Assumptions'
  require_section_has_content "$oracle_shadow_summary_path" '## Stash / Isolation Record'
  require_section_has_content "$oracle_shadow_summary_path" '## Files Touched'
  require_section_has_content "$oracle_shadow_summary_path" '## Validation Run'
  jq -e '
    (.task_id == $task_id) and
    (.summary.files_touched_count | type == "number") and
    (.summary.validation_commands_run | type == "number") and
    (.summary.stash_recorded | type == "boolean") and
    (.summary.comparison_ready | type == "boolean") and
    ((.stash_ref == null) or (.stash_ref | type == "string"))
  ' --arg task_id "$task_id" "$oracle_shadow_report_path" >/dev/null || {
    echo "invalid oracle shadow report shape: $oracle_shadow_report_path" >&2
    exit 1
  }
}

require_implementation_report_shape() {
  require_file "$implementation_report_path"
  jq -e '
    (.task_id == $task_id) and
    (.summary.contract_requirements_total | type == "number") and
    (.summary.implemented_requirements_count | type == "number") and
    (.summary.self_reported_known_gaps | type == "number") and
    (.summary.validation_commands_run | type == "number") and
    (.summary.contract_requirements_total >= .summary.implemented_requirements_count)
  ' --arg task_id "$task_id" "$implementation_report_path" >/dev/null || {
    echo "invalid implementation report shape: $implementation_report_path" >&2
    exit 1
  }
}

require_final_fix_shape() {
  require_file "$fix_from_final_path"
  require_file "$final_fix_report_path"
  require_section_has_content "$fix_from_final_path" '## Findings Addressed'
  require_section_has_content "$fix_from_final_path" '## Files Changed'
  require_section_has_content "$fix_from_final_path" '## Validation Run'
  jq -e '
    (.task_id == $task_id) and
    (.summary.oracle_findings_total | type == "number") and
    (.summary.findings_addressed_count | type == "number") and
    (.summary.findings_remaining_open_count | type == "number") and
    (.summary.validation_commands_run | type == "number")
  ' --arg task_id "$task_id" "$final_fix_report_path" >/dev/null || {
    echo "invalid final fix report shape: $final_fix_report_path" >&2
    exit 1
  }
}

require_review1_findings_shape() {
  require_file "$review1_findings_path"
  jq -e '
    (.task_id == $task_id) and
    (.summary.total_findings | type == "number") and
    (.summary.by_part.code.total | type == "number") and
    (.summary.by_part.security.total | type == "number") and
    (.summary.by_part.architecture.total | type == "number") and
    (.summary.implementer_mistakes.missing_requirement | type == "number") and
    (.summary.implementer_mistakes.wrong_behavior | type == "number") and
    (.summary.implementer_mistakes.out_of_scope_change | type == "number") and
    (.summary.implementer_mistakes.contract_violation | type == "number") and
    (.summary.implementer_mistakes.test_gap | type == "number") and
    (.findings | type == "array") and
    (.findings | all(
      .part | IN("code", "security", "architecture")
    )) and
    (.findings | all(
      .severity | IN("critical", "high", "medium", "low")
    )) and
    (.findings | all(
      .category | IN("missing_requirement", "wrong_behavior", "out_of_scope_change", "contract_violation", "test_gap", "security_gap", "architecture_issue")
    )) and
    (.findings | all(
      .status | IN("open", "resolved", "accepted_risk")
    )) and
    (.summary.total_findings == (
      .summary.by_part.code.total +
      .summary.by_part.security.total +
      .summary.by_part.architecture.total
    )) and
    (.summary.total_findings >= (.findings | length))
  ' --arg task_id "$task_id" "$review1_findings_path" >/dev/null || {
    echo "invalid review1 findings shape: $review1_findings_path" >&2
    exit 1
  }
}

require_oracle_closeout_shape() {
  require_file "$oracle_closeout_path"
  require_file "$oracle_closeout_report_path"
  require_section_has_content "$oracle_closeout_path" '## Final Finding Closure'
  require_section_has_content "$oracle_closeout_path" '## Closeout Judgment'
  require_section_has_content "$oracle_closeout_path" '## Residual Risks'
  require_section_has_content "$oracle_closeout_path" '## Release Decision'
  jq -e '
    (.task_id == $task_id) and
    (.decision | IN("approve", "hold", "reject")) and
    (.summary.oracle_total_findings | type == "number") and
    (.summary.findings_closed_after_fix | type == "number") and
    (.summary.findings_still_open | type == "number") and
    (.summary.blocking_findings | type == "number")
  ' --arg task_id "$task_id" "$oracle_closeout_report_path" >/dev/null || {
    echo "invalid oracle closeout report shape: $oracle_closeout_report_path" >&2
    exit 1
  }
}

require_oracle_final_report_shape() {
  require_file "$oracle_final_report_path"
  jq -e '
    (.task_id == $task_id) and
    (.decision | IN("approve", "hold", "reject")) and
    (.summary.oracle_total_findings | type == "number") and
    (.summary.oracle_new_findings_missed_by_review1 | type == "number") and
    (.summary.oracle_carried_findings_from_review1 | type == "number") and
    (.summary.oracle_resolved_findings_from_review1 | type == "number") and
    (.summary.blocking_findings | type == "number") and
    (.summary.implementer_mistakes_missed_by_review1.missing_requirement | type == "number") and
    (.summary.implementer_mistakes_missed_by_review1.wrong_behavior | type == "number") and
    (.summary.implementer_mistakes_missed_by_review1.out_of_scope_change | type == "number") and
    (.summary.implementer_mistakes_missed_by_review1.contract_violation | type == "number") and
    (.summary.implementer_mistakes_missed_by_review1.test_gap | type == "number") and
    (.findings | type == "array") and
    (.findings | all(
      .origin | IN("missed_by_review1", "carried_from_review1")
    )) and
    (.findings | all(
      .severity | IN("critical", "high", "medium", "low")
    )) and
    (.findings | all(
      .category | IN("missing_requirement", "wrong_behavior", "out_of_scope_change", "contract_violation", "test_gap", "security_gap", "architecture_issue")
    )) and
    (.findings | all(
      .status | IN("open", "resolved", "accepted_risk")
    )) and
    (.summary.oracle_total_findings >= (.findings | length)) and
    (.summary.blocking_findings == ([.findings[] | select(.blocking == true)] | length))
  ' --arg task_id "$task_id" "$oracle_final_report_path" >/dev/null || {
    echo "invalid oracle final report shape: $oracle_final_report_path" >&2
    exit 1
  }
}

require_summary_shape() {
  require_file "$summary_path"
  rg -q '^## Resolved$' "$summary_path" || {
    echo "summary missing Resolved section: $summary_path" >&2
    exit 1
  }
  rg -q '^## Unresolved$' "$summary_path" || {
    echo "summary missing Unresolved section: $summary_path" >&2
    exit 1
  }
  rg -q '^## Decision For Next Stage$' "$summary_path" || {
    echo "summary missing Decision For Next Stage section: $summary_path" >&2
    exit 1
  }
  require_section_has_content "$summary_path" '## Resolved'
  require_section_has_content "$summary_path" '## Unresolved'
  require_section_has_content "$summary_path" '## Position Summary By Issue'
  selected_next_stage >/dev/null
}

require_contract_shape() {
  require_file "$contract_path"
  rg -q '^## Goal$' "$contract_path" || {
    echo "contract missing Goal section: $contract_path" >&2
    exit 1
  }
  rg -q '^## Acceptance Criteria$' "$contract_path" || {
    echo "contract missing Acceptance Criteria section: $contract_path" >&2
    exit 1
  }
  rg -q '^## Verification Plan$' "$contract_path" || {
    echo "contract missing Verification Plan section: $contract_path" >&2
    exit 1
  }
  require_section_has_content "$contract_path" '## Goal'
  require_section_has_content "$contract_path" '## Files In Scope'
  require_section_has_content "$contract_path" '## Forbidden Approaches'
  require_section_has_content "$contract_path" '## Acceptance Criteria'
  require_section_has_content "$contract_path" '## Verification Plan'
}

require_review1_shape() {
  require_file "$review1_summary_path"
  require_file "$code_review_path"
  require_file "$security_review_path"
  require_file "$architecture_review_path"

  rg -q '^## Contract Compliance$' "$review1_summary_path" || {
    echo "review1 summary missing Contract Compliance section: $review1_summary_path" >&2
    exit 1
  }
  require_section_has_content "$review1_summary_path" '## Overall Judgment'
  require_section_has_content "$review1_summary_path" '## Contract Compliance'
  require_section_has_content "$review1_summary_path" '## Key Findings'
  require_section_has_content "$review1_summary_path" '## Remaining Risks'

  rg -q '^## Critical$' "$code_review_path" || {
    echo "code review missing Critical section: $code_review_path" >&2
    exit 1
  }
  rg -q '^## Critical$' "$security_review_path" || {
    echo "security review missing Critical section: $security_review_path" >&2
    exit 1
  }
  rg -q '^## Critical$' "$architecture_review_path" || {
    echo "architecture review missing Critical section: $architecture_review_path" >&2
    exit 1
  }
}

require_oracle_final_shape() {
  require_file "$oracle_final_path"
  rg -q '^## Final Judgment$' "$oracle_final_path" || {
    echo "oracle final missing Final Judgment section: $oracle_final_path" >&2
    exit 1
  }
  rg -q '^## Release Decision$' "$oracle_final_path" || {
    echo "oracle final missing Release Decision section: $oracle_final_path" >&2
    exit 1
  }
  require_section_has_content "$oracle_final_path" '## Contract Compliance'
  require_section_has_content "$oracle_final_path" '## Final Judgment'
  require_section_has_content "$oracle_final_path" '## Remaining Risks'
  require_section_has_content "$oracle_final_path" '## Release Decision'
  rg -q 'approve|hold|reject' "$oracle_final_path" || {
    echo "oracle final must include approve|hold|reject decision: $oracle_final_path" >&2
    exit 1
  }
}

require_implementation_shape() {
  require_file "$implementation_summary_path"
  rg -q '^## Acceptance Criteria Status$' "$implementation_summary_path" || {
    echo "implementation summary missing Acceptance Criteria Status section: $implementation_summary_path" >&2
    exit 1
  }
  rg -q '^## Validation Run$' "$implementation_summary_path" || {
    echo "implementation summary missing Validation Run section: $implementation_summary_path" >&2
    exit 1
  }
  require_section_has_content "$implementation_summary_path" '## Contract Scope'
  require_section_has_content "$implementation_summary_path" '## Files Changed'
  require_section_has_content "$implementation_summary_path" '## Acceptance Criteria Status'
  require_section_has_content "$implementation_summary_path" '## Validation Run'
  require_implementation_report_shape
}

validate_start_inputs() {
  case "$stage" in
    debate-discuss|debate-build)
      require_file "$meta_path"
      require_file "$brief_path"
      ;;
    oracle-pre-impl-guardrails)
      require_contract_shape
      require_summary_shape
      require_score_shape
      ;;
    oracle-shadow-implement)
      require_contract_shape
      ;;
    implement-from-contract)
      require_file "$summary_path"
      require_score_shape
      require_contract_shape
      ;;
    review1-from-contract)
      require_contract_shape
      require_implementation_shape
      ;;
    oracle-final-review)
      require_contract_shape
      require_implementation_shape
      require_review1_shape
      ;;
    fix-from-final)
      require_contract_shape
      require_oracle_final_shape
      require_oracle_final_report_shape
      ;;
    oracle-closeout)
      require_contract_shape
      require_oracle_final_shape
      require_oracle_final_report_shape
      require_final_fix_shape
      ;;
  esac
}

validate_completion() {
  case "$stage" in
    debate-discuss)
      require_summary_shape
      require_score_shape
      require_debate_meta_shape
      [[ "$(selected_next_stage)" == "stop_at_discussion" ]] || {
        echo "debate-discuss requires selected next stage = stop_at_discussion" >&2
        exit 1
      }
      ;;
    debate-build)
      require_summary_shape
      require_score_shape
      require_debate_meta_shape
      require_contract_shape
      [[ "$(selected_next_stage)" == "ready_for_contract" ]] || {
        echo "debate-build requires selected next stage = ready_for_contract" >&2
        exit 1
      }
      jq -e '.overall_verdict != "unresolved"' "$score_path" >/dev/null || {
        echo "debate-build cannot complete with overall_verdict=unresolved" >&2
        exit 1
      }
      ;;
    oracle-pre-impl-guardrails)
      require_contract_shape
      require_oracle_guardrails_shape
      ;;
    oracle-shadow-implement)
      require_contract_shape
      require_oracle_shadow_shape
      ;;
    implement-from-contract)
      require_contract_shape
      require_implementation_shape
      ;;
    review1-from-contract)
      require_contract_shape
      require_implementation_shape
      require_review1_shape
      require_review1_findings_shape
      ;;
    oracle-final-review)
      require_contract_shape
      require_implementation_shape
      require_review1_shape
      require_review1_findings_shape
      require_oracle_final_shape
      require_oracle_final_report_shape
      ;;
    fix-from-final)
      require_contract_shape
      require_oracle_final_shape
      require_oracle_final_report_shape
      require_final_fix_shape
      ;;
    oracle-closeout)
      require_contract_shape
      require_oracle_final_shape
      require_oracle_final_report_shape
      require_final_fix_shape
      require_oracle_closeout_shape
      ;;
  esac
}

print_stage_summary() {
  local owner="$1"
  printf 'run=%s\n' "$run_dir"
  printf 'stage=%s\n' "$stage"
  printf 'action=%s\n' "$action"
  printf 'intent=%s\n' "$intent"
  printf 'starter=%s\n' "$starter"
  printf 'owner=%s\n' "$owner"
}

if [[ ! -d "$run_dir" ]]; then
  echo "run directory not found: $run_dir" >&2
  exit 1
fi

load_meta
require_intent_match

owner="$(resolve_owner)"

if [[ "$action" == "start" ]]; then
  validate_start_inputs
  append_stage_log "stage_start" "$owner"
  print_stage_summary "$owner"
  exit 0
fi

validate_completion
append_stage_log "stage_complete" "$owner"
print_stage_summary "$owner"
