# Sisyphus-Oracle Run Guide

이 문서는 canonical run을 실제로 시작할 때 `누가 무엇을 채우는지`를 빠르게 확인하기 위한 안내다.

## 시작 순서

```bash
./.protocol/scripts/create_run.sh <task-id> [oracle|sisyphus] [discussion_only|implementation_bound]
```

opening까지 한 번에 올리는 래퍼:

```bash
./.protocol/scripts/start_debate.sh <task-id> [oracle|sisyphus] [discussion_only|implementation_bound]
```

**task-id 네이밍 규칙**: `YYYYMMDD-kebab-case-slug` 형식이다. 날짜 접두사가 없으면 스크립트가 자동으로 오늘 날짜를 붙인다.

예:

```bash
# 기본: discussion_only + sisyphus starter
./.protocol/scripts/create_run.sh example

# Oracle starter로 토론 시작
./.protocol/scripts/create_run.sh example oracle

# opening + debate start까지 한 번에
./.protocol/scripts/start_debate.sh example oracle

# legacy/manual: 처음부터 implementation_bound로 열고 싶을 때만 명시
./.protocol/scripts/create_run.sh example oracle implementation_bound
# → .protocol/runs/20260330-example/ 생성
```

run 디렉터리가 생기면 아래 순서로 채운다.

`start_debate.sh`를 쓰면 아래 3단계를 한 번에 수행한다.

1. `create_run.sh`
2. starter 순서를 지키며 Oracle/Sisyphus opening 실행
3. `run_stage.sh <task-id> debate-discuss start`

## 사람이 직접 주는 것

사람은 보통 아래만 주면 된다.

### 1. 요청 주제

- 무엇을 토론/구현할지
- 예:
  - `release-binding-system 재설계`
  - `EmaOversoldLong provenance 정리`

### 2. starter

- `sisyphus`
  - Claude가 먼저 brief를 씀
- `oracle`
  - Codex가 먼저 brief를 씀

### 3. intent

- 새 run 기본값은 `discussion_only`
- 구현이 필요해지면 같은 run에서 `/escalate`로 `implementation_bound`로 전환
- 처음부터 `implementation_bound`로 여는 건 legacy/manual recovery용

### 4. 모델 정보

`meta.json`의 아래 값은 실제 사용 모델로 채운다.

- `oracle_model`
- `sisyphus_model`

예:

```json
{
  "oracle_model": "gpt-5.4",
  "sisyphus_model": "claude-opus-4-6"
}
```

## 단계별로 누가 채우는가

## 00-brief.md

### 기본 담당

- `starter`

### 반드시 채울 것

- `## Request`
- `## Problem Statement`
- `## Change Targets`
- `## Non-Goals`
- `## Constraints`
- `## Relevant Files / Docs`

### 사람이 최소로 도와주면 좋은 것

- 작업 목표 1~2문장
- 건드리면 안 되는 것
- 관련 파일/문서 경로

### 중요한 규칙

- brief는 문제 정의 문서다
- preferred solution / 추천 architecture / 대안 비교 결론은 brief에 넣지 않는다

## Opening

### 기본 담당

- Oracle opening: `oracle`
- Sisyphus opening: `sisyphus`

### 핵심 원칙

- 두 opening은 **서로를 읽기 전에** 독립적으로 작성한다
- opening 단계에서는 상대 opening이나 round 파일을 읽지 않는다
- 각 opening은 preferred direction과 최소 1개 이상의 alternative/counter-shape를 포함한다

### 산출물

- `debate/opening-oracle.md`
- `debate/opening-sisyphus.md`
- `prompts/opening-oracle.md`
- `prompts/opening-sisyphus.md`

### 권장 실행 방식

opening도 round처럼 canonical wrapper를 통해 실행하는 편이 낫다.

```bash
./.protocol/scripts/run_oracle_opening.sh <task-id>
./.protocol/scripts/run_sisyphus_opening.sh <task-id>
```

이 래퍼는:
- 세션 관리
- canonical 응답/히스토리 보존
- `stage-log.jsonl` 이벤트 기록
을 opening 단계에도 동일하게 적용한다

처음부터 opening까지 자동으로 올리고 싶으면 `start_debate.sh`를 쓰면 된다.

## Debate

### 권장 실행 방식

새 round를 열 때는 먼저 아래 스캐폴더를 쓴다.

```bash
./.protocol/scripts/create_debate_round.sh <task-id> <round-number>
```

예:

```bash
./.protocol/scripts/create_debate_round.sh 20260330-example 2
```

이 스크립트는:
- `debate/round-00N/{oracle,sisyphus}.md`를 만들고
- `prompts/round-00N-oracle.md`, `prompts/round-00N-sisyphus.md`를 실제 절대경로 기준으로 생성한다
- round 2 이상이면 각 actor의 직전 same-actor round 파일을 prompt에 자동 연결한다
- opening 두 개는 round prompt의 공통 읽기 집합으로 간주한다
- 마지막 출력은 해당 starter의 counterpart actor가 바로 사용할 prompt path다

시지푸스 토론 handoff는 직접 `peer_local.sh`를 치지 말고 아래 canonical 래퍼를 쓴다.

```bash
./.protocol/scripts/run_sisyphus_round.sh <task-id> <round-id> <prompt-file>
```

예:

```bash
./.protocol/scripts/run_sisyphus_round.sh 20260330-example round-001 .protocol/runs/20260330-example/prompts/round-001-sisyphus.md
```

이 래퍼는:
- Claude 응답이 끝날 때까지 기다리고
- canonical `.protocol/runs/.../sisyphus/responses/`와 `sisyphus/history/`에 바로 쓰고
- `sisyphus/artifacts/*.md`에 brief/prompt/raw output/요약/다음 액션을 묶은 markdown artifact를 남기고
- `stage-log.jsonl`에 `sisyphus_round_synced` 이벤트를 남긴다

즉 "답은 왔는데 canonical run이 안 업데이트된 상태"를 줄이는 용도다.
또 canonical prompt를 `peer_local.sh`로 직접 보내더라도 같은 canonical 경로를 기본 출력으로 사용한다.

### round 파일 원칙

- `debate/round-001/oracle.md`는 Oracle만 수정
- `debate/round-001/sisyphus.md`는 Sisyphus만 수정
- handoff prompt는 `prompts/round-001-oracle.md`, `prompts/round-001-sisyphus.md`처럼 얇게 유지
- 실질 기록 원본은 round 파일이고, prompt는 실행 지시만 담는다

### starter = sisyphus일 때

- `00-brief.md`는 Sisyphus가 먼저 채운다
- opening은 `opening-sisyphus.md` -> `opening-oracle.md` 순으로 채운다
- 본토론 첫 prompt는 `prompts/round-001-oracle.md`다
- 이후 추가 round도 `create_debate_round.sh`가 Oracle/Sisyphus prompt를 둘 다 만든다

### starter = oracle일 때

- `00-brief.md`는 Oracle이 먼저 채운다
- opening은 `opening-oracle.md` -> `opening-sisyphus.md` 순으로 채운다
- 본토론 첫 prompt는 `prompts/round-001-sisyphus.md`다
- 이후 추가 round도 `create_debate_round.sh`가 Oracle/Sisyphus prompt를 둘 다 만든다

### 사람이 직접 채울 필요

- 보통 없음
- 다만 쟁점이 애매하면 “이 논점도 꼭 다뤄라” 정도만 추가

## 01-debate-summary.md

### 기본 담당

- `starter`가 아닌 쪽

### 반드시 채울 것

- `## Resolved`
- `## Unresolved`
- `## Position Summary By Issue`
- `## Decision For Next Stage`
  - `selected: pending`
  - 또는 `selected: closed`

### 사람이 확인할 포인트

- unresolved가 정말 없는지
- contract로 넘겨도 되는 수준인지
- 두 opening이 실제로 독립 아이디어를 냈는지

### 권장 실행 방식

summary/score prompt는 아래로 생성한다.

```bash
./.protocol/scripts/create_summary_score_prompt.sh <task-id>
```

scorer가 `sisyphus`인 run이면 아래 래퍼로 canonical sync까지 한 번에 닫는다.

```bash
./.protocol/scripts/run_sisyphus_summary_score.sh <task-id>
```

scorer가 `oracle`인 run이면 아래 prompt 생성기로 target을 고정한 뒤 Oracle이 직접 채운다.

```bash
./.protocol/scripts/run_oracle_summary_score.sh <task-id>
```

즉 starter 기준으로 보면:

- starter=`oracle` → scorer=`sisyphus` → `run_sisyphus_summary_score.sh`
- starter=`sisyphus` → scorer=`oracle` → `run_oracle_summary_score.sh`

`selected`는 다음 단계 의미를 담지 않는다.

- `pending` = 토론이 아직 안 닫힘
- `closed` = 토론이 닫힘

토론 종료 후 구현으로 갈지는 `/escalate`가 결정한다.

## 02-debate-score.json

### 기본 담당

- `starter`가 아닌 쪽

### 반드시 채울 것

- `starter`
- `scorer`
- `intent`
- `overall_verdict`
- `issues[*]`
- `issues[*].direction_quality`
- `issues[*].critique_quality`
- `issues[*].originator`
- `issues[*].final_owner`

### 사람이 확인할 포인트

- `starter != scorer`인지
- `implementation_bound`인데 unresolved 이슈가 남아 있지 않은지
- adopted_in_contract가 과장 없이 체크됐는지
- 방향성 평가와 비판 평가를 섞어 쓰지 않았는지

## debate-meta.json

### 기본 담당

- 가능하면 `starter`, `scorer`와 다른 제3 평가자
- 제3 평가자가 없으면 `scorer`

### 반드시 채울 것

- `meta_evaluator`
- `meta_evaluator_model`
- `oracle_profile`
- `sisyphus_profile`
- `comparative`
- `notes`

### 사람이 확인할 포인트

- 제3 evaluator가 아니면 `notes` 첫 문장에 평가자 중첩이 명시됐는지
- 성향 평가는 `low|medium|high` 고정 축으로만 썼는지
- 비교 우세 평가는 `oracle|sisyphus|balanced`로만 썼는지

### 권장 실행 방식

debate meta prompt는 아래로 생성한다.

```bash
./.protocol/scripts/create_debate_meta_prompt.sh <task-id>
```

evaluator가 `sisyphus`인 run이면 아래 래퍼로 canonical sync까지 한 번에 닫는다.

```bash
./.protocol/scripts/run_sisyphus_debate_meta.sh <task-id>
```

evaluator가 `oracle`인 run이면 아래 prompt 생성기로 target을 고정한 뒤 Oracle이 직접 채운다.

```bash
./.protocol/scripts/run_oracle_debate_meta.sh <task-id>
```

## 03-contract.md

### 기본 담당

- 초안은 starter가 써도 됨
- 최종 승인자는 항상 `Oracle`

### 반드시 채울 것

- `## Goal`
- `## Non-Goals`
- `## Files In Scope`
- `## Structural Constraints`
- `## Forbidden Approaches`
- `## Acceptance Criteria`
- `## Verification Plan`

### 사람이 확인할 포인트

- 구현 범위가 너무 넓지 않은지
- 금지 구현 방식이 빠지지 않았는지

### 권장 실행 방식

starter가 `sisyphus`인 run이면 contract draft prompt를 아래로 생성하거나 바로 sync까지 닫는다.

```bash
./.protocol/scripts/create_contract_draft_prompt.sh <task-id>
./.protocol/scripts/run_sisyphus_contract_draft.sh <task-id>
```

starter가 `oracle`인 run이면 `prompts/contract-draft-oracle.md`를 기준으로 Oracle이 직접 채운다.

## oracle/implementation-guardrails.md

### 기본 담당

- `Oracle`

### 왜 중요한가

- Oracle 강점인 invariant / guardrail / 거짓 통과 포인트를 구현 전에 고정한다
- 이후 Sisyphus 구현과 review1이 같은 failure mode를 보게 만든다

### 반드시 채울 것

- `## Must Hold Invariants`
- `## Hidden Failure Modes`
- `## Review Emphasis`

## oracle/shadow-implementation-summary.md

### 기본 담당

- `Oracle`

### 왜 중요한가

- Oracle이 contract를 보고 먼저 구현해 본 흔적을 비교 가능한 근거로 남긴다
- 이 구현은 canonical이 아니라 comparison-only다
- stage 완료 시 shadow patch는 stash 또는 동등한 격리 상태로 빠져 있어야 한다

### 반드시 채울 것

- `## Scope Assumptions`
- `## Stash / Isolation Record`
- `## Files Touched`
- `## Validation Run`
- `## Compare Notes For Sisyphus Review`

### 사람이 확인할 포인트

- shadow 구현이 canonical 구현으로 오해되지 않게 적혔는지
- stash ref 또는 격리 경로가 실제로 남았는지

## sisyphus/implementation-summary.md

### 기본 담당

- `Sisyphus`

### 반드시 채울 것

- `## Contract Scope`
- `## Files Changed`
- `## Acceptance Criteria Status`
- `## Validation Run`
- `## Open Issues`

## sisyphus/implementation-report.json

### 기본 담당

- `Sisyphus`

### 반드시 채울 것

- `contract_requirements_total`
- `implemented_requirements_count`
- `self_reported_known_gaps`
- `validation_commands_run`

### 사람이 확인할 포인트

- 계약 요구 수를 과소 보고하지 않았는지
- 구현자가 자기 미완성 항목을 숨기지 않았는지
- `model_notes`에 이번 run에서 보인 구현 성향이 짧게 적혀 있는지

## review1/*

### 기본 담당

- `Sisyphus`

### 세부 파일

- `review1/code-review.md`
- `review1/security-review.md`
- `review1/architecture-review.md`
- `review1/findings.json`
- `04-review1.md`

### 사람이 직접 채울 필요

- 보통 없음
- 다만 “이건 security로 봐라”, “이건 architecture 이슈다” 같은 분류 피드백은 가능

## review1/findings.json

### 왜 중요한가

이 파일이 있어야 나중에 아래를 통계로 볼 수 있다.

- 1차 리뷰가 구현자 실수를 얼마나 잡았는가
- code/security/architecture 중 어디가 더 많이 잡는가
- 어떤 카테고리 실수가 반복되는가

### 반드시 채울 것

- `summary.total_findings`
- `summary.by_part`
- `summary.implementer_mistakes`
- `findings[*].part`
- `findings[*].severity`
- `findings[*].category`
- `findings[*].status`
- 가능하면 `model_notes`

## 06-fix-from-final.md / sisyphus/final-fix-report.json

### 기본 담당

- `Sisyphus`

### 왜 중요한가

- Oracle final에서 잡힌 문제를 실제 결과물에 흡수하는 단계다
- “누가 더 잘 봤는가”에서 끝나지 않고, 장단점을 실제 산출물에 합성한다

### 반드시 채울 것

- 어떤 final finding을 닫았는지
- 어떤 finding이 아직 열려 있는지
- 어떤 검증을 다시 돌렸는지

## oracle/final-report.json

## oracle/final-report.json

### 기본 담당

- `Oracle`

### 왜 중요한가

이 파일이 있어야 나중에 아래를 통계로 볼 수 있다.

- Oracle이 review1 전에 못 잡은 문제를 얼마나 더 잡았는가
- blocking finding이 얼마나 나오는가
- review1이 놓친 구현자 실수는 무엇이었는가

### 반드시 채울 것

- `decision`
- `summary.oracle_total_findings`
- `summary.oracle_new_findings_missed_by_review1`
- `summary.oracle_carried_findings_from_review1`
- `summary.oracle_resolved_findings_from_review1`
- `summary.blocking_findings`
- `summary.implementer_mistakes_missed_by_review1`
- `findings[*].origin`
- `findings[*].blocking`
- 가능하면 `model_notes`

## oracle/closeout-report.json

### 기본 담당

- `Oracle`

### 왜 중요한가

- final fix 이후 정말 닫혔는지 다시 판정하는 마지막 게이트다
- `approve | hold | reject`를 최종적으로 확정한다

### 반드시 채울 것

- `decision`
- `summary.oracle_total_findings`
- `summary.findings_closed_after_fix`
- `summary.findings_still_open`
- `summary.blocking_findings`
- 가능하면 `model_notes`

## implementation/review/final의 자유 메모

토론 메타는 고정 5축 + comparative 구조를 유지한다.
반면 구현/리뷰/final/closeout은 문맥 의존성이 커서, 억지 점수화보다 각 JSON의 `model_notes`에 자유 텍스트로 남기는 쪽을 권장한다.

권장 길이:

- 2~5문장
- 이번 run에서 실제로 드러난 성향만 쓴다
- "항상 그렇다" 같은 일반화는 피한다

## 사람이 실제로 개입해야 하는 최소 순간

사람이 실제로 확인/결정하면 좋은 지점은 보통 셋이다.

1. `00-brief.md`
- 요청과 비목표가 맞는지

2. `01-debate-summary.md` / `02-debate-score.json`
- 정말 contract로 넘어가도 되는지

3. `03-contract.md`
- 스코프가 맞는지

그 이후 구현/리뷰는 원칙적으로 Sisyphus와 Oracle이 채우고, 사람은 중간에 쟁점이 열릴 때만 개입하면 된다.

현재 이 저장소의 권장 운용은 아래 순서다.

1. `03-contract.md` 고정
2. `oracle/implementation-guardrails.md`
3. `oracle/shadow-implementation-summary.md` + stash
4. `sisyphus/implementation-summary.md`
5. `review1/*`
6. `oracle/final-report.json`
7. 필요 시 `06-fix-from-final.md`
8. 필요 시 `oracle/closeout-report.json`

## 빠른 운영 팁

- 처음엔 사람이 `00-brief.md`만 제대로 잡아주는 게 가장 중요하다
- `review1/findings.json`과 `oracle/final-report.json`은 반드시 채운다
- 이 두 파일이 비어 있으면 통계는 거의 의미가 없어진다
