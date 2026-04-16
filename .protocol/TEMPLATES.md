# Sisyphus-Oracle Canonical Templates

이 문서는 [PROTOCOL.md](/Users/inje/Desktop/develop/projects/buy-good-things/.protocol/PROTOCOL.md)의 canonical 산출물 템플릿이다.
단계별 입력/출력/완료 조건은 [STAGE_CONTRACTS.md](/Users/inje/Desktop/develop/projects/buy-good-things/.protocol/STAGE_CONTRACTS.md)를 따른다.

원칙:

- `.protocol/` 아래 템플릿이 정본이다
- `.claude/session-management/TEMPLATES.md`는 레거시 호환 템플릿이다
- 번호보다 역할 의미를 우선하지만, canonical 번호 체계는 아래를 기준으로 고정한다

## Canonical Artifact Layout

### discussion_only

```text
.protocol/runs/<task-id>/
  stage-log.jsonl
  00-brief.md
  debate/
    opening-oracle.md
    opening-sisyphus.md
    round-001/
      oracle.md
      sisyphus.md
  prompts/
    opening-oracle.md
    opening-sisyphus.md
    round-001-oracle.md
    round-001-sisyphus.md
  01-debate-summary.md
  02-debate-score.json
  debate-meta.json
  meta.json
```

### implementation_bound

```text
.protocol/runs/<task-id>/
  stage-log.jsonl
  00-brief.md
  debate/
    opening-oracle.md
    opening-sisyphus.md
    round-001/
      oracle.md
      sisyphus.md
  prompts/
    opening-oracle.md
    opening-sisyphus.md
    round-001-oracle.md
    round-001-sisyphus.md
    contract-draft-<starter>.md
  01-debate-summary.md
  02-debate-score.json
  debate-meta.json
  03-contract.md
  04-review1.md
  05-oracle-final.md
  06-fix-from-final.md
  07-oracle-closeout.md
  review1/
    code-review.md
    security-review.md
    architecture-review.md
    findings.json
  meta.json
  oracle/
    implementation-guardrails.md
    shadow-implementation-summary.md
    shadow-implementation-report.json
    final-report.json
    closeout-report.json
  sisyphus/
    implementation-summary.md
    implementation-report.json
    final-fix-report.json
```

## 00-brief.md

```md
# Brief

## Request

## Intent

- `discussion_only` | `implementation_bound`

## Starter

- `oracle` | `sisyphus`

## Problem Statement

## Change Targets

## Non-Goals

## Constraints

## Relevant Files / Docs
```

규칙:

- brief는 문제 정의 문서다
- preferred solution / 추천 architecture / 대안 비교 결론은 brief에 쓰지 않는다

## debate/opening-oracle.md

```md
# Oracle Opening

## Preferred Direction

## Alternatives Considered

## Why This Direction

## Risks In Other Directions
```

## debate/opening-sisyphus.md

```md
# Sisyphus Opening

## Preferred Direction

## Alternatives Considered

## Why This Direction

## Risks In Other Directions
```

## debate/round-001/oracle.md

```md
# Oracle Round 001

## Oracle Position

## Oracle Critique

## Current State

- `resolved` | `still_open` | `near_convergence`

## Notes
```

## debate/round-001/sisyphus.md

```md
# Sisyphus Round 001

## Sisyphus Position

## Sisyphus Critique

## Current State

- `resolved` | `still_open` | `near_convergence`

## Notes
```

토론 기록은 opening + 라운드별 + actor별 파일로 누적한다.
각 actor는 자기 파일만 직접 수정한다.
opening 단계에서는 상대 opening을 읽지 않는다.
summary/score는 두 opening과 최소 1회 라운드 이후에만 작성한다.

## prompts/opening-oracle.md

```md
Oracle,

아래 canonical 파일만 읽고 작업하라.

- brief: `.protocol/runs/<task-id>/00-brief.md`
- target file: `.protocol/runs/<task-id>/debate/opening-oracle.md`

해야 할 일:

1. brief만 읽는다.
2. counterpart opening이나 round 파일은 읽지 않는다.
3. `target file`의 아래 섹션만 채운다.
   - `## Preferred Direction`
   - `## Alternatives Considered`
   - `## Why This Direction`
   - `## Risks In Other Directions`
4. stdout에는 짧게 `updated <target file>`만 출력한다.
```

## prompts/opening-sisyphus.md

```md
Sisyphus,

아래 canonical 파일만 읽고 작업하라.

- brief: `.protocol/runs/<task-id>/00-brief.md`
- target file: `.protocol/runs/<task-id>/debate/opening-sisyphus.md`

해야 할 일:

1. brief만 읽는다.
2. counterpart opening이나 round 파일은 읽지 않는다.
3. `target file`의 아래 섹션만 채운다.
   - `## Preferred Direction`
   - `## Alternatives Considered`
   - `## Why This Direction`
   - `## Risks In Other Directions`
4. stdout에는 짧게 `updated <target file>`만 출력한다.
```

## prompts/round-001-sisyphus.md

```md
Sisyphus,

아래 canonical 파일만 읽고 작업하라.

- brief: `.protocol/runs/<task-id>/00-brief.md`
- oracle round file: `.protocol/runs/<task-id>/debate/round-001/oracle.md`
- target file: `.protocol/runs/<task-id>/debate/round-001/sisyphus.md`

해야 할 일:

1. brief와 oracle round file을 읽는다.
2. `target file`의 아래 섹션만 채운다.
   - `## Sisyphus Position`
   - `## Sisyphus Critique`
   - `## Current State`
   - `## Notes`
3. Oracle 파일이나 다른 round 파일은 수정하지 않는다.
4. stdout에는 짧게 `updated <target file>`만 출력한다.
```

## prompts/summary-score-<scorer>.md

```md
<ScorerName>,

이 토론은 사실상 종료됐다. 이제 canonical summary와 score를 직접 채워라.

읽을 파일:

- brief: `.protocol/runs/<task-id>/00-brief.md`
- opening oracle: `.protocol/runs/<task-id>/debate/opening-oracle.md`
- opening sisyphus: `.protocol/runs/<task-id>/debate/opening-sisyphus.md`
- round 001 oracle: `.protocol/runs/<task-id>/debate/round-001/oracle.md`
- round 001 sisyphus: `.protocol/runs/<task-id>/debate/round-001/sisyphus.md`

수정할 파일:

- summary target: `.protocol/runs/<task-id>/01-debate-summary.md`
- score target: `.protocol/runs/<task-id>/02-debate-score.json`

작업 규칙:

1. 위 round 파일들만 근거로 사용한다.
2. `01-debate-summary.md`를 실제 내용으로 채운다.
3. `02-debate-score.json`도 실제 내용으로 채운다.
4. `starter`, `scorer`, `intent` 값은 canonical 메타와 일치하게 유지한다.
5. 다른 파일은 수정하지 않는다.
6. stdout에는 짧게 `updated summary and score`만 출력한다.
```

## prompts/round-001-oracle.md

```md
Oracle,

아래 canonical 파일만 읽고 작업하라.

- brief: `.protocol/runs/<task-id>/00-brief.md`
- counterpart round file: `.protocol/runs/<task-id>/debate/round-001/sisyphus.md`
- target file: `.protocol/runs/<task-id>/debate/round-001/oracle.md`

해야 할 일:

1. brief를 읽는다.
2. counterpart round file에 실질 내용이 있으면 그 내용을 읽고 반론/응답한다.
3. `target file`의 아래 섹션만 채운다.
   - `## Oracle Position`
   - `## Oracle Critique`
   - `## Current State`
   - `## Notes`
4. counterpart round file이 아직 placeholder 수준이면, 이번 응답을 opening position으로 작성한다.
5. target file 외 다른 round 파일은 수정하지 않는다.
6. stdout에는 짧게 `updated <target file>`만 출력한다.
```

## prompts/debate-meta-<evaluator>.md

```md
<EvaluatorName>,

이제 canonical debate meta를 채워라.

읽을 파일:

- brief: `.protocol/runs/<task-id>/00-brief.md`
- summary: `.protocol/runs/<task-id>/01-debate-summary.md`
- score: `.protocol/runs/<task-id>/02-debate-score.json`
- round 001 oracle: `.protocol/runs/<task-id>/debate/round-001/oracle.md`
- round 001 sisyphus: `.protocol/runs/<task-id>/debate/round-001/sisyphus.md`

수정할 파일:

- debate meta target: `.protocol/runs/<task-id>/debate-meta.json`

작업 규칙:

1. 위 파일들만 근거로 사용한다.
2. `oracle_profile`, `sisyphus_profile`, `comparative`, `notes`를 모두 채운다.
3. 제3 evaluator가 아니면 `notes` 첫 문장에 평가자 중첩을 밝힌다.
4. 다른 파일은 수정하지 않는다.
5. stdout에는 짧게 `updated debate meta`만 출력한다.
```

## 01-debate-summary.md

```md
# Debate Summary

## Resolved

## Unresolved

## Position Summary By Issue

### issue-1

- Oracle:
- Sisyphus:
- Direction quality:
- Critique quality:
- Originator:
- Final owner:
- Current conclusion:

### issue-2

- Oracle:
- Sisyphus:
- Direction quality:
- Critique quality:
- Originator:
- Final owner:
- Current conclusion:

## Decision For Next Stage

- selected: `pending`
```

## 02-debate-score.json

```json
{
  "task_id": "20260330-example-task",
  "starter": "sisyphus",
  "scorer": "oracle",
  "intent": "implementation_bound",
  "overall_verdict": "balanced",
  "issues": [
    {
      "topic": "example topic",
      "oracle_position": "example oracle position",
      "sisyphus_position": "example sisyphus position",
      "direction_quality": "oracle",
      "critique_quality": "sisyphus",
      "originator": "sisyphus",
      "final_owner": "oracle",
      "verdict": "oracle",
      "confidence": "high",
      "reason": "example reason",
      "adopted_in_contract": true,
      "status": "resolved"
    }
  ]
}
```

규칙:

- `verdict`는 `oracle | sisyphus | converged | unresolved`만 사용
- `overall_verdict`는 `oracle_dominant | sisyphus_dominant | balanced | unresolved`만 사용
- `direction_quality`, `critique_quality`는 `oracle | sisyphus | balanced`만 사용
- `originator`는 `oracle | sisyphus | shared`만 사용
- `final_owner`는 `oracle | sisyphus | shared | unresolved`만 사용
- `starter`와 `scorer`는 같지 않아야 한다
- unresolved 이슈가 남아 있으면 `/escalate` 후 contract 단계로 넘어가지 않는다

## debate-meta.json

```json
{
  "task_id": "20260330-example-task",
  "starter": "oracle",
  "scorer": "sisyphus",
  "meta_evaluator": "oracle",
  "meta_evaluator_model": "codex",
  "oracle_profile": {
    "abstraction_level": "high",
    "risk_posture": "high",
    "evidence_orientation": "medium",
    "execution_bias": "medium",
    "adaptability": "medium"
  },
  "sisyphus_profile": {
    "abstraction_level": "medium",
    "risk_posture": "medium",
    "evidence_orientation": "high",
    "execution_bias": "high",
    "adaptability": "high"
  },
  "comparative": {
    "problem_framing": "balanced",
    "bottleneck_identification": "sisyphus",
    "guardrail_design": "oracle",
    "convergence_driving": "balanced"
  },
  "notes": "short meta summary"
}
```

규칙:

- `meta_evaluator`는 가능하면 `starter`와 `scorer` 모두와 다른 제3 평가자가 맡는다
- 제3 평가자가 없으면 `scorer`가 맡고 `notes` 첫 문장에 평가자 중첩을 밝힌다
- 성향 평가는 `oracle_profile`, `sisyphus_profile`, `comparative`를 고정 축으로 구조화한다
- profile 값은 `low | medium | high`만 사용
- comparative 값은 `oracle | sisyphus | balanced`만 사용

## prompts/contract-draft-<starter>.md

```md
<StarterName>,

아래 canonical 파일만 읽고 contract 초안을 작성하라.

읽을 파일:

- brief: `.protocol/runs/<task-id>/00-brief.md`
- summary: `.protocol/runs/<task-id>/01-debate-summary.md`
- score: `.protocol/runs/<task-id>/02-debate-score.json`
- debate round files: `.protocol/runs/<task-id>/debate/round-*/{oracle,sisyphus}.md`

수정할 파일:

- contract target: `.protocol/runs/<task-id>/03-contract.md`

작업 규칙:

1. brief, summary, score, round 파일만 근거로 사용한다.
2. `03-contract.md`의 핵심 섹션을 실제 내용으로 채운다.
3. unresolved 이슈를 구현 acceptance criteria로 숨겨 넘기지 않는다.
4. `starter`는 `<starter>`, contract 승인권은 `oracle`이라는 점을 전제로 초안만 작성한다.
5. target file 외 다른 파일은 수정하지 않는다.
6. stdout에는 짧게 `updated contract draft`만 출력한다.
```

## 03-contract.md

```md
# Contract

## Goal

## Non-Goals

## Files In Scope

## Structural Constraints

## Forbidden Approaches

## Acceptance Criteria

## Verification Plan
```

## 04-review1.md

```md
# Review1 Summary

## Review Bundle

- `review1/code-review.md`
- `review1/security-review.md`
- `review1/architecture-review.md`

## Overall Judgment

## Contract Compliance

## Key Findings

## Open Questions

## Remaining Risks
```

## oracle/implementation-guardrails.md

```md
# Oracle Implementation Guardrails

## Must Hold Invariants

## Hidden Failure Modes

## Review Emphasis
```

## oracle/shadow-implementation-summary.md

```md
# Oracle Shadow Implementation Summary

## Scope Assumptions

## Stash / Isolation Record

## Files Touched

## Validation Run

## Compare Notes For Sisyphus Review

## Open Issues
```

## oracle/shadow-implementation-report.json

```json
{
  "task_id": "20260330-example-task",
  "summary": {
    "files_touched_count": 4,
    "validation_commands_run": 1,
    "stash_recorded": true,
    "comparison_ready": true
  },
  "stash_ref": "stash@{0}",
  "model_notes": "Oracle shadow 구현은 guardrail과 fail-fast를 강하게 챙겼지만 scope를 넓히는 경향이 있었다."
}
```

## review1/code-review.md

```md
# Code Review

## Critical

## High

## Medium

## Low
```

## review1/security-review.md

```md
# Security Review

## Critical

## High

## Medium

## Low
```

## review1/architecture-review.md

```md
# Architecture Review

## Critical

## High

## Medium

## Low
```

## review1/findings.json

```json
{
  "task_id": "20260330-example-task",
  "summary": {
    "total_findings": 3,
    "by_part": {
      "code": { "critical": 0, "high": 1, "medium": 1, "low": 0, "total": 2 },
      "security": { "critical": 0, "high": 0, "medium": 1, "low": 0, "total": 1 },
      "architecture": { "critical": 0, "high": 0, "medium": 0, "low": 0, "total": 0 }
    },
    "implementer_mistakes": {
      "missing_requirement": 1,
      "wrong_behavior": 0,
      "out_of_scope_change": 0,
      "contract_violation": 1,
      "test_gap": 1
    }
  },
  "model_notes": "Review1은 구현 범위를 잘 지켰는지와 조용히 틀릴 수 있는 경로를 텍스트로 짧게 남긴다.",
  "findings": [
    {
      "id": "R1",
      "part": "code",
      "severity": "high",
      "category": "missing_requirement",
      "status": "open",
      "detected_before_oracle": true,
      "summary": "required branch missing"
    }
  ]
}
```

규칙:

- `part`는 `code | security | architecture`
- `severity`는 `critical | high | medium | low`
- `category`는 아래 중 하나만 사용
  - `missing_requirement`
  - `wrong_behavior`
  - `out_of_scope_change`
  - `contract_violation`
  - `test_gap`
  - `security_gap`
  - `architecture_issue`
- `status`는 `open | resolved | accepted_risk`

## 05-oracle-final.md

```md
# Oracle Final Review

## Contract Compliance

## Final Judgment

## Remaining Risks

## Release Decision
```

## 06-fix-from-final.md

```md
# Fix From Final

## Findings Addressed

## Files Changed

## Validation Run

## Remaining Open Findings
```

## sisyphus/final-fix-report.json

```json
{
  "task_id": "20260330-example-task",
  "summary": {
    "oracle_findings_total": 2,
    "findings_addressed_count": 1,
    "findings_remaining_open_count": 1,
    "validation_commands_run": 1
  },
  "model_notes": "fix 단계에서는 Sisyphus가 Oracle의 guardrail 지적을 좁은 범위로 얼마나 잘 흡수했는지 적는다."
}
```

## 07-oracle-closeout.md

```md
# Oracle Closeout

## Final Finding Closure

## Closeout Judgment

## Residual Risks

## Release Decision
```

## oracle/final-report.json

```json
{
  "task_id": "20260330-example-task",
  "decision": "hold",
  "summary": {
    "oracle_total_findings": 2,
    "oracle_new_findings_missed_by_review1": 1,
    "oracle_carried_findings_from_review1": 1,
    "oracle_resolved_findings_from_review1": 2,
    "blocking_findings": 1,
    "implementer_mistakes_missed_by_review1": {
      "missing_requirement": 1,
      "wrong_behavior": 0,
      "out_of_scope_change": 0,
      "contract_violation": 0,
      "test_gap": 0
    }
  },
  "model_notes": "Oracle final은 review1이 놓친 invariant나 reproducibility 경계를 자유 텍스트로 남길 수 있다.",
  "findings": [
    {
      "id": "O1",
      "severity": "high",
      "category": "missing_requirement",
      "origin": "missed_by_review1",
      "status": "open",
      "blocking": true,
      "summary": "critical requirement still missing"
    }
  ]
}
```

규칙:

- `decision`은 `approve | hold | reject`
- `origin`은 `missed_by_review1 | carried_from_review1`
- `severity`, `category`, `status`는 `review1/findings.json`과 같은 어휘를 쓴다

## oracle/closeout-report.json

```json
{
  "task_id": "20260330-example-task",
  "decision": "approve",
  "summary": {
    "oracle_total_findings": 2,
    "findings_closed_after_fix": 2,
    "findings_still_open": 0,
    "blocking_findings": 0
  },
  "model_notes": "closeout에서는 두 모델의 장단점이 최종 산출물에 어떻게 합성됐는지 기록한다."
}
```

## meta.json

```json
{
  "task_id": "20260330-example-task",
  "starter": "sisyphus",
  "oracle": "oracle",
  "implementer": "sisyphus",
  "intent": "implementation_bound",
  "oracle_model": "gpt-5.4",
  "sisyphus_model": "claude-opus-4-6"
}
```

## stage-log.jsonl

`run_stage.sh`가 append-only로 쓰는 실행 로그다.

예시:

```jsonl
{"timestamp":"2026-03-30T12:00:00+09:00","event":"stage_start","stage":"debate-build","intent":"implementation_bound","starter":"sisyphus","owner":"starter","oracle_model":"gpt-5.4","sisyphus_model":"claude-opus-4-6"}
{"timestamp":"2026-03-30T12:42:00+09:00","event":"stage_complete","stage":"debate-build","intent":"implementation_bound","starter":"sisyphus","owner":"starter","oracle_model":"gpt-5.4","sisyphus_model":"claude-opus-4-6"}
```

이 파일은 나중에 아래 통계를 낼 때 기준 로그로 사용한다.

- 어떤 모델 조합이 어떤 stage를 더 자주 완료하는가
- Sisyphus Review1과 Oracle Final Review가 어느 stage에서 자주 hold/reject를 내는가
- starter/scorer/model 조합에 따라 debate verdict 경향이 어떻게 바뀌는가

## sisyphus/implementation-summary.md

```md
# Implementation Summary

## Contract Scope

## Files Changed

## Acceptance Criteria Status

## Validation Run

## Open Issues
```

## sisyphus/implementation-report.json

```json
{
  "task_id": "20260330-example-task",
  "summary": {
    "contract_requirements_total": 4,
    "implemented_requirements_count": 4,
    "self_reported_known_gaps": 0,
    "validation_commands_run": 2
  },
  "model_notes": "Sisyphus 구현은 contract 준수와 범위 절제는 좋았지만 숨은 invariant 방어는 약했다."
}
```

구현·리뷰·final 계열 JSON의 `model_notes`는 고정 축 점수가 아니라 자유 텍스트 메모다.
이 칸에는 아래처럼 이번 run에서 관찰된 구현 성향을 짧게 남긴다.

- scope discipline
- guardrail / fail-fast 감각
- 숨은 invariant를 먼저 막는지
- review가 표면 오류를 넘어서 조용히 틀릴 경로까지 보는지
