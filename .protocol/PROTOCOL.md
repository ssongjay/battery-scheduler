# Sisyphus-Oracle Debate Protocol

이 문서는 이 프로젝트의 Sisyphus-Oracle 토론/구현 프로토콜 원본이다.

canonical 템플릿은 [TEMPLATES.md](/Users/inje/Desktop/develop/projects/buy-good-things/.protocol/TEMPLATES.md)에 있다.
canonical run 스캐폴드는 [create_run.sh](/Users/inje/Desktop/develop/projects/buy-good-things/.protocol/scripts/create_run.sh)로 생성한다.
추가 debate round 스캐폴드는 [create_debate_round.sh](/Users/inje/Desktop/develop/projects/buy-good-things/.protocol/scripts/create_debate_round.sh)로 생성한다.
summary/score prompt 생성은 [create_summary_score_prompt.sh](/Users/inje/Desktop/develop/projects/buy-good-things/.protocol/scripts/create_summary_score_prompt.sh)로 한다.
contract draft prompt 생성은 [create_contract_draft_prompt.sh](/Users/inje/Desktop/develop/projects/buy-good-things/.protocol/scripts/create_contract_draft_prompt.sh)로 한다.
debate meta prompt 생성은 [create_debate_meta_prompt.sh](/Users/inje/Desktop/develop/projects/buy-good-things/.protocol/scripts/create_debate_meta_prompt.sh)로 한다.
canonical 단계 실행 계약은 [STAGE_CONTRACTS.md](/Users/inje/Desktop/develop/projects/buy-good-things/.protocol/STAGE_CONTRACTS.md)에 있다.
canonical stage runner는 [run_stage.sh](/Users/inje/Desktop/develop/projects/buy-good-things/.protocol/scripts/run_stage.sh)다.
Sisyphus 토론 응답 동기화 래퍼는 [run_sisyphus_round.sh](/Users/inje/Desktop/develop/projects/buy-good-things/.protocol/scripts/run_sisyphus_round.sh)다.
Sisyphus summary/score 동기화 래퍼는 [run_sisyphus_summary_score.sh](/Users/inje/Desktop/develop/projects/buy-good-things/.protocol/scripts/run_sisyphus_summary_score.sh)다.
Oracle summary/score 수동 helper는 [run_oracle_summary_score.sh](/Users/inje/Desktop/develop/projects/buy-good-things/.protocol/scripts/run_oracle_summary_score.sh)다.
Oracle 토론 라운드 래퍼는 [run_oracle_round.sh](/Users/inje/Desktop/develop/projects/buy-good-things/.protocol/scripts/run_oracle_round.sh)다.
Oracle 범용 동기화 래퍼는 [run_oracle_sync.sh](/Users/inje/Desktop/develop/projects/buy-good-things/.protocol/scripts/run_oracle_sync.sh)다.
Oracle debate meta 래퍼는 [run_oracle_debate_meta.sh](/Users/inje/Desktop/develop/projects/buy-good-things/.protocol/scripts/run_oracle_debate_meta.sh)다.
Sisyphus contract draft 동기화 래퍼는 [run_sisyphus_contract_draft.sh](/Users/inje/Desktop/develop/projects/buy-good-things/.protocol/scripts/run_sisyphus_contract_draft.sh)다.
Sisyphus debate meta 동기화 래퍼는 [run_sisyphus_debate_meta.sh](/Users/inje/Desktop/develop/projects/buy-good-things/.protocol/scripts/run_sisyphus_debate_meta.sh)다.
Sisyphus-starter 전용 아카이빙 래퍼는 [archive_sisyphus_artifact.sh](/Users/inje/Desktop/develop/projects/buy-good-things/.protocol/scripts/archive_sisyphus_artifact.sh)다.
Sisyphus stage artifact 생성기는 [write_claude_stage_artifact.py](/Users/inje/Desktop/develop/projects/buy-good-things/.protocol/scripts/write_claude_stage_artifact.py)다.
canonical/legacy 통계 집계는 [aggregate_stats.py](/Users/inje/Desktop/develop/projects/buy-good-things/.protocol/scripts/aggregate_stats.py)로 한다.
실전 입력 안내는 [RUN_GUIDE.md](/Users/inje/Desktop/develop/projects/buy-good-things/.protocol/RUN_GUIDE.md)를 기준으로 한다.

핵심 정의:

- `Oracle = Codex`
- `Sisyphus = Claude Code`
- `starter`는 바뀔 수 있지만 `oracle`은 바뀌지 않는다.

또한 이 프로토콜은 작업 시작 시 아래 두 intent 중 하나를 반드시 고른다.

- `discussion_only`
- `implementation_bound`

## task-id 네이밍 규칙

- task-id 형식: `YYYYMMDD-kebab-case-slug` (예: `20260404-kimchi-premium-diversification`)
- `YYYYMMDD`는 run 생성일이다
- `create_run.sh`는 날짜 접두사가 없으면 자동으로 오늘 날짜를 붙인다
- 이미 `YYYYMMDD-`로 시작하면 그대로 사용한다
- 디렉토리 정렬 시 시간순이 보장되어야 하므로 날짜 접두사를 생략하지 않는다

## 역할 구분 원칙

이 문서에서 가장 중요한 건 `역할`, `실행 파라미터`, `단계별 담당`을 섞지 않는 것이다.

- `역할(actor role)`:
  - 장기간 변하지 않는 주체 정의
- `실행 파라미터(run parameter)`:
  - 이번 run을 어떻게 시작하고 어디까지 갈지 정하는 값
- `단계별 담당(phase ownership)`:
  - 각 단계에서 기본적으로 누가 초안/구현/승인을 맡는지

## 고정 actor 역할

| 역할 | 담당 |
|------|------|
| Oracle | Oracle |
| Sisyphus | Sisyphus |

이 표는 `누가 누구인가`만 정의한다.
여기에는 구현자/리뷰어 같은 단계별 책임을 넣지 않는다.

## 실행 파라미터

| 파라미터 | 값 |
|------|----|
| Starter | `sisyphus` or `oracle` |
| Intent | `discussion_only` or `implementation_bound` |

이 표는 `이번 run이 어떤 방식으로 시작되는가`만 정의한다.
즉 `starter`, `intent`는 역할이 아니라 실행 설정이다.

## 토론 원칙

Oracle과 Sisyphus는 **동급 토론자**로서 서로를 굉장히 비판적으로 대해야 한다.

핵심 규칙:

- 상대의 약점, 허점, 약한 가정, 구조적 타협을 **적극적으로 공격**한다.
- 예의 바른 동의보다 **날카로운 반박**이 우선이다. 합의는 싸워서 얻는 것이지 양보해서 얻는 것이 아니다.
- 수치, 코드, 데이터로 반박한다. "그럴 수 있다" 같은 모호한 인정은 약점이다.
- 상대 주장에 동의할 때도 **왜 옳은지 독립적으로 검증**한 뒤에만 수용한다.
- 합의될 때까지 토론을 멈추지 않는다. 10라운드가 넘어도 합의가 안 되면 사용자에게 쟁점과 선택지를 보고하고 결정을 요청한다.
- 일찍 수렴하는 것은 **의심 신호**다. 2라운드 만에 모든 쟁점이 합의되면 한쪽이 너무 쉽게 양보한 것이 아닌지 반드시 점검한다.

근거 조사 의무:

- 모르는 것, 애매한 것, 확신이 없는 주장에 대해서는 **반드시 웹검색으로 근거를 확보**한 뒤 발언한다.
- "아마 그럴 것이다", "일반적으로 알려져 있다" 같은 추측성 주장은 금지. 검색해서 수치/출처를 찾아 붙여라.
- 상대 주장을 반박할 때도 웹검색으로 반례/데이터를 찾아서 근거를 대라.
- 특히 Sisyphus(Claude Code)는 웹검색을 회피하는 경향이 있으므로, 토론 중 불확실한 주장을 할 때는 **웹검색부터 하고 발언**하는 것을 기본으로 한다.

금지 사항:

- 상대의 체면을 위해 약점을 넘기는 행위
- "좋은 지적이다"로 시작해서 실질적 반박 없이 수용하는 행위
- 자기 입장의 핵심을 포기하면서 "조건부 동의"로 포장하는 행위
- 검색하면 확인할 수 있는 사실을 추측으로 넘기는 행위

## 단계별 기본 담당

| 단계 | 기본 담당 | 비고 |
|------|------|------|
| Brief | Starter | starter가 최초 문제 정의와 맥락 수집을 연다 |
| Counter-brief | Non-starter | starter advantage 상쇄용 독립 반론/대안 제시 |
| Debate | Oracle + Sisyphus | 동급 토론 단계 |
| Debate Summary | Non-starter 기본 | 토론 종료 후 정리, 양측 검토 가능 |
| Debate Score | Non-starter 기본 | 논점별 판정 기록, Oracle이 최종 확인 |
| Debate Meta | 제3 평가자 권장 | 성향/관점/강약점 메타 평가, 제3 평가자가 없으면 `scorer`가 맡고 `notes` 첫 문장에 중첩을 밝힌다 |
| Contract Draft | Starter 기본 | `implementation_bound`일 때만 의미 있음 |
| Contract Approval | Oracle | 항상 Oracle 최종 승인 |
| Oracle Guardrails | Oracle | 구현 전 불변식/거짓 통과 포인트를 고정 |
| Oracle Shadow Implementation | Oracle | comparison-only shadow patch, canonical 구현으로 취급하지 않음 |
| Implementation | Sisyphus | 항상 Sisyphus |
| Review1 | Sisyphus | 항상 Sisyphus |
| Final Review | Oracle | 항상 Oracle |
| Fix From Final | Sisyphus | Oracle final finding을 반영하는 보정 단계 |
| Oracle Closeout | Oracle | fix 반영 후 최종 종료 승인 |

핵심 불변식:

- `implementation_bound`에서는
  - Oracle Guardrails = Oracle
  - Oracle Shadow Implementation = Oracle
  - Implementation = Sisyphus
  - Review1 = Sisyphus
  - Contract Approval = Oracle
  - Final Review = Oracle
  - Fix From Final = Sisyphus
  - Oracle Closeout = Oracle
- `discussion_only`에서는
  - Contract / Implementation / Review1 / Final Review를 만들지 않는다

중요:

- `Oracle Shadow Implementation`은 비교용 구현이다
- canonical 구현 owner는 여전히 Sisyphus다
- Oracle이 contract를 보고 먼저 구현해 보더라도, 그 결과는 stash 또는 동등한 격리 상태로 보관하고 comparison artifact로만 남긴다
- Sisyphus 구현 시작 시점에는 Oracle shadow code가 active working tree에 남아 있으면 안 된다
- 토론 메타는 구조화 축으로 남기되, 구현/리뷰/final/closeout에서 보인 모델 특성은 각 report JSON의 `model_notes` 자유 텍스트로 남긴다

## Intent

### discussion_only

- 목적: 구현 없이 논점 정리, 설계 검토, 아이디어 비교, 리스크 토론
- 계약서, 구현, Review1, Oracle Final Review는 기본적으로 생성하지 않는다
- 토론 종료 후 `summary`와 `score`를 모두 남긴다

### implementation_bound

- 목적: 구현으로 이어지는 토론
- 계약서가 반드시 필요하다
- 계약서 전에 `summary`와 `score`가 먼저 고정되어야 한다
- Sisyphus 구현, Sisyphus Review1, Oracle Final Review까지 전체 플로우를 탄다

## 단계 순서

`implementation_bound`에서는 항상 아래 순서를 유지한다.

1. Brief
2. Counter-brief
3. Debate
4. Debate Summary
5. Debate Score
6. Contract
7. Oracle Guardrails
8. Oracle Shadow Implementation
9. Implementation
10. Review1
11. Oracle Final Review
12. 필요 시 Fix From Final
13. 필요 시 Oracle Closeout

단계 생략 금지:

- Counter-brief 없이 본 토론 진입 금지
- Summary 없이 Score 작성 금지
- Score 없이 Contract 진입 금지
- 계약서 없이 Oracle guardrails / shadow implementation / 구현 진입 금지
- Review1 없이 Oracle Final Review 금지

`discussion_only`에서는 아래만 수행한다.

1. Brief
2. Counter-brief
3. Debate
4. Debate Summary
5. Debate Score

## Starter별 흐름

### starter = oracle

1. Oracle이 맥락 수집과 문제 정의를 시작한다
2. Sisyphus가 counter-brief를 제출한다
3. Oracle과 Sisyphus가 동급 토론을 한다
4. Sisyphus가 summary와 score 초안을 작성한다
5. `discussion_only`면 양측 검토 후 종료한다
6. `implementation_bound`면 Oracle이 contract를 작성/승인한다
7. Oracle이 implementation guardrails를 남긴다
8. Oracle이 comparison-only shadow implementation을 만들고 stash/격리한다
9. Sisyphus가 canonical 구현을 한다
10. Sisyphus가 1차 리뷰를 한다
11. Oracle이 최종 Oracle 리뷰를 한다
12. 필요하면 Sisyphus가 final finding을 반영한다
13. Oracle이 closeout으로 종료 승인한다

### starter = sisyphus

1. Sisyphus가 brief와 초기 입장을 정리한다
2. Oracle이 counter-brief를 제출한다
3. Sisyphus가 Oracle에 토론 handoff를 한다
4. Oracle과 Sisyphus가 동급 토론을 한다
5. Oracle이 summary와 score 초안을 작성한다
6. `discussion_only`면 양측 검토 후 종료한다
7. `implementation_bound`면 Sisyphus가 contract 초안을 쓸 수는 있지만, 최종 승인자는 Oracle이다
8. Oracle이 implementation guardrails를 남긴다
9. Oracle이 comparison-only shadow implementation을 만들고 stash/격리한다
10. Sisyphus가 canonical 구현을 한다
11. Sisyphus가 1차 리뷰를 한다
12. Oracle이 최종 Oracle 리뷰를 한다
13. 필요하면 Sisyphus가 final finding을 반영한다
14. Oracle이 closeout으로 종료 승인한다

## 언제 이 문서를 읽는가

### Oracle

Oracle은 아래 시점에 이 문서를 다시 확인한다.

- Oracle 워크플로우가 들어간 작업을 처음 시작할 때
- Sisyphus가 starter인 handoff를 받았을 때
- Contract 승인 전에
- Final Review 전에
- 프로토콜 변경 요청을 받았을 때

### Sisyphus

Sisyphus는 아래 시점에 이 문서를 다시 확인한다.

- Oracle 워크플로우가 들어간 작업을 처음 시작할 때
- `debate-discuss`, `debate-build`, `/contract`, `/review1` 진입 전
- starter가 Sisyphus인 상태에서 brief나 contract draft를 만들기 전
- Oracle에 handoff를 보내기 전

## Sisyphus 실행 계약

Sisyphus 단계는 `ask-claude` 스타일의 운영 계약을 따른다.

- Sisyphus 단계는 **반드시 로컬 Claude CLI**를 사용한다.
- 기본 실행 경로는 canonical wrapper(`run_sisyphus_round.sh`, `run_sisyphus_summary_score.sh`, `run_sisyphus_contract_draft.sh`, `run_sisyphus_implementation.sh`, `run_sisyphus_review1.sh`, `run_sisyphus_fix_from_final.sh`)다.
- `claude` 바이너리가 없으면 MCP나 다른 경로로 우회하지 않는다.
- 로컬 설치 확인 명령은 `claude --version`이다.
- Sisyphus 단계가 끝나면 prompt, raw response, history, markdown artifact를 canonical run 디렉터리에 남긴다.

## Sisyphus-starter 실행 계약

Sisyphus가 starter이면서 현재 실행 중인 Claude Code 세션인 경우, 기존 래퍼(`run_sisyphus_round.sh` → `claude_session.sh`)는 **자기 자신을 subprocess로 호출하는 구조**이므로 사용할 수 없다.

이 경우 아래 대체 경로를 따른다.

### 파이프라인 레이어별 대체

| 레이어 | Oracle-starter (기존) | Sisyphus-starter (대체) |
|--------|---------------------|----------------------|
| Layer 4: `run_stage.sh` | 그대로 사용 | **그대로 사용** |
| Layer 3: 아카이빙 | `run_sisyphus_sync.sh` | **`archive_sisyphus_artifact.sh`** |
| Layer 2: 세션 launch | `peer_local.sh` | 불필요 (이미 실행 중) |
| Layer 1: CLI 실행 | `claude_session.sh` | 불필요 (이미 실행 중) |

### Sisyphus 라운드 실행 절차

1. `create_debate_round.sh <task-id> N` — round 스캐폴드 생성
2. Sisyphus가 `debate/round-00N/sisyphus.md`에 직접 Position, Critique, Current State, Notes를 작성
3. `archive_sisyphus_artifact.sh <task-id> round-00N sisyphus_round_written debate/round-00N/sisyphus.md` — 아카이빙 + stage-log 기록

### Oracle 라운드 실행 절차

1. `run_oracle_round.sh <task-id> round-00N` — `codex exec`로 Oracle 호출
   - 첫 호출: 새 세션 생성, `oracle/session-id.txt`에 thread_id 저장
   - 이후 호출: `codex exec resume <session-id>`로 동일 세션 유지
2. Oracle이 `debate/round-00N/oracle.md`에 직접 작성
3. 응답/JSONL이 `oracle/responses/`에 자동 아카이빙, stage-log에 자동 기록

### Oracle 세션 관리

- session-id 저장: `.protocol/runs/<task-id>/oracle/session-id.txt`
- 첫 호출에서 `codex exec --json` 출력의 `thread.started` 이벤트에서 `thread_id`를 추출하여 저장
- 이후 `codex exec resume <session-id>`로 동일 세션 컨텍스트를 유지
- `resume`은 `-s` (sandbox), `-m` (model) 옵션을 받지 않으므로, **첫 세션 생성 시 설정한 sandbox/model이 이후에도 유지됨**
- DB 쿼리, curl 등이 필요하면 첫 호출에서 반드시 `-s danger-full-access`로 세션을 열어야 함
- 환경변수 `ORACLE_SANDBOX`로 기본값 override 가능 (기본: `danger-full-access`)

### Summary/Score/Debate-Meta

- `create_summary_score_prompt.sh <task-id>` — summary/score 프롬프트 생성
- `run_oracle_summary_score.sh <task-id>` — Oracle이 summary/score 작성 (starter=sisyphus이므로 scorer=oracle)
- `create_debate_meta_prompt.sh <task-id>` — debate-meta 프롬프트 생성
- `run_oracle_debate_meta.sh <task-id>` — Oracle이 debate-meta 작성

### Stage 검증

- `run_stage.sh <task-id> debate-discuss start` — 토론 시작 기록
- `run_stage.sh <task-id> debate-discuss complete` — 전체 shape 검증 (summary, score, debate-meta)
- shape 검증은 starter에 무관하게 동일한 기준을 적용함

### 필수 산출물 체크리스트 (discussion_only)

- [ ] `stage-log.jsonl` — 이벤트 기록
- [ ] `meta.json` — `oracle_model`, `sisyphus_model` 포함
- [ ] `00-brief.md` — Sisyphus가 작성
- [ ] `debate/round-NNN/sisyphus.md` — Sisyphus가 직접 작성
- [ ] `debate/round-NNN/oracle.md` — Oracle이 `codex exec`로 직접 작성
- [ ] `sisyphus/archives/` — `archive_sisyphus_artifact.sh`로 아카이빙
- [ ] `oracle/responses/` — `run_oracle_sync.sh`가 자동 아카이빙
- [ ] `oracle/session-id.txt` — Oracle 세션 ID
- [ ] `01-debate-summary.md` — scorer(Oracle)가 작성
- [ ] `02-debate-score.json` — scorer(Oracle)가 작성, `run_stage.sh` shape 통과
- [ ] `debate-meta.json` — evaluator가 작성, `run_stage.sh` shape 통과
- [ ] `run_stage.sh complete` — 전체 검증 통과

### 금지 사항

- Sisyphus가 `codex:codex-rescue` subagent로 Oracle을 대체하는 것은 금지. 세션 연속성과 아카이빙이 보장되지 않는다.
- Sisyphus가 score, debate-meta를 직접 작성하는 것은 금지 (starter=sisyphus이면 scorer=oracle).
- `run_stage.sh complete` 없이 토론을 종료 선언하는 것은 금지.

## 산출물

### intent별 산출물 차이표

| 산출물 | discussion_only | implementation_bound |
|------|------|------|
| `stage-log.jsonl` | 필수 | 필수 |
| `00-brief.md` | 필수 | 필수 |
| `debate/` | 필수 | 필수 |
| `prompts/` | 필수 | 필수 |
| `01-debate-summary.md` | 필수 | 필수 |
| `02-debate-score.json` | 필수 | 필수 |
| `debate-meta.json` | 필수 | 필수 |
| `sisyphus/responses/*.txt|json` | Sisyphus stage 실행 시 필수 | Sisyphus stage 실행 시 필수 |
| `sisyphus/history/*.log` | Sisyphus stage 실행 시 필수 | Sisyphus stage 실행 시 필수 |
| `sisyphus/artifacts/*.md` | Sisyphus stage 실행 시 필수 | Sisyphus stage 실행 시 필수 |
| `03-contract.md` | 생성 안 함 | 필수 |
| `04-review1.md` | 생성 안 함 | 필수 |
| `06-fix-from-final.md` | 생성 안 함 | 필요 시 |
| `07-oracle-closeout.md` | 생성 안 함 | 필요 시 |
| `review1/` | 생성 안 함 | 필수 |
| `05-oracle-final.md` | 생성 안 함 | 필수 |
| `sisyphus/implementation-summary.md` | 생성 안 함 | 필수 |
| `sisyphus/implementation-report.json` | 생성 안 함 | 필수 |
| `sisyphus/final-fix-report.json` | 생성 안 함 | 필요 시 |
| `review1/findings.json` | 생성 안 함 | 필수 |
| `oracle/final-report.json` | 생성 안 함 | 필수 |
| `oracle/implementation-guardrails.md` | 생성 안 함 | 권장 |
| `oracle/shadow-implementation-summary.md` | 생성 안 함 | 권장 |
| `oracle/shadow-implementation-report.json` | 생성 안 함 | 권장 |
| `oracle/closeout-report.json` | 생성 안 함 | 필요 시 |
| `meta.json` | 필수 | 필수 |

이 표에서 핵심은 `discussion_only`가 "토론 자체가 결과"인 흐름이고,
`implementation_bound`는 "토론이 구현 계약으로 이어지는 흐름"이라는 점이다.

### discussion_only

```text
.protocol/
  runs/<task-id>/
    stage-log.jsonl
    00-brief.md
    debate/
      round-001/
        oracle.md
        sisyphus.md
    prompts/
      round-001-oracle.md
      round-001-sisyphus.md
    01-debate-summary.md
    02-debate-score.json
    debate-meta.json
    oracle/                          # Oracle(Codex) 산출물
      session-id.txt                 # Codex 세션 UUID (starter=sisyphus 시)
      responses/                     # 라운드별 응답 txt + JSONL
    sisyphus/
      responses/                     # starter=oracle 시 CLI 응답
      history/                       # starter=oracle 시 실행 이력
      archives/                      # starter=sisyphus 시 아카이빙 사본
      artifacts/
    meta.json
```

### implementation_bound

장기적으로는 아래 중립 디렉터리를 기준으로 산출물을 둔다.

```text
.protocol/
  PROTOCOL.md
  runs/<task-id>/
    stage-log.jsonl
    00-brief.md
    debate/
      round-001/
        oracle.md
        sisyphus.md
    prompts/
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
      responses/
      history/
      artifacts/
      implementation-summary.md
      implementation-report.json
      final-fix-report.json
```

`meta.json` 최소 필드:

```json
{
  "starter": "sisyphus",
  "oracle": "oracle",
  "implementer": "sisyphus",
  "intent": "discussion_only",
  "oracle_model": "gpt-5.4",
  "sisyphus_model": "claude-opus-4-6"
}
```

정확한 파일별 템플릿은 [TEMPLATES.md](/Users/inje/Desktop/develop/projects/buy-good-things/.protocol/TEMPLATES.md)를 기준으로 한다.
작업 디렉터리 초기 생성은 `.protocol/scripts/create_run.sh <task-id> [intent] [starter]`를 기준으로 한다.
단계별 입력/출력/완료 조건은 [STAGE_CONTRACTS.md](/Users/inje/Desktop/develop/projects/buy-good-things/.protocol/STAGE_CONTRACTS.md)를 기준으로 한다.
단계 시작/완료 검증은 `.protocol/scripts/run_stage.sh <task-id> <stage> [start|complete]`를 기준으로 한다.
Sisyphus 토론 왕복은 가능하면 `.protocol/scripts/run_sisyphus_round.sh <task-id> <round-id> <prompt-file>`를 사용해 응답/히스토리를 canonical run에 직접 기록한다.
이 canonical wrapper들은 응답/히스토리만이 아니라 markdown artifact도 함께 남긴다.
canonical prompt 파일(`.protocol/runs/<task-id>/prompts/round-*-{oracle,sisyphus}.md`)을 각 actor 실행 경로에 연결하더라도, 응답/히스토리는 canonical 경로를 기준으로 남기는 방향을 기본값으로 한다.
markdown artifact는 최소 아래 섹션을 포함한다.

1. Original user task
2. Final prompt sent to Claude CLI
3. Claude output (raw)
4. Concise summary
5. Action items / next steps

성향 통계의 source of truth는 `debate-meta.json`이며, 가능하면 `starter`/`scorer`와 분리된 제3 평가자가 작성한다. 제3 평가자가 없으면 `scorer`가 작성하고 `notes` 첫 문장에 평가자 중첩을 밝힌다.

## 명령어 체계

사용자가 기억하는 명령어는 4개다. 나머지는 protocol 내부 단계로, 플로우 안에서만 사용한다.

### 주요 명령어 (4개)

| 명령어 | 용도 | 시작 intent |
|--------|------|------------|
| `/debate-discuss` | Oracle과 토론 | `discussion_only` |
| `/escalate` | 토론을 구현으로 전환 | `discussion_only` → contract → 구현 → 리뷰 |
| `/implement` | 구현 + 자동 코드리뷰 (토론 없이) | 없음 (protocol run 선택적) |
| `/full-code-review` | 코드리뷰만 (3 Claude + Oracle) | 없음 |

### 전형적인 플로우

```
플로우 1: 토론 → 구현
  /debate-discuss → (합의) → /escalate → contract → 구현 → 1차리뷰(3 Claude) → 2차리뷰(Oracle)

플로우 2: 바로 구현
  /implement → 구현 → 1차리뷰(3 Claude) → 2차리뷰(Oracle)

플로우 3: 토론만
  /debate-discuss → (합의) → 끝

플로우 4: 리뷰만
  /full-code-review → 1차(3 Claude 병렬) → 2차(Oracle)
```

### 내부 단계 명령어 (플로우 안에서만)

| 명령어 | 용도 | 비고 |
|--------|------|------|
| `/contract` | 구현 계약서 작성 | `/escalate` 내부에서 사용 |
| `/review1` | 1차 리뷰 (3 Claude 병렬) | code + security + architecture |
| `/oracle-final-review` | Oracle 2차 리뷰 | `run_oracle_sync.sh` 사용 |
| `/fix-from-final` | Oracle 지적 반영 | hold 시에만 |

### 폐기된 명령어

아래 명령어는 제거되었다. 사용하지 않는다.

- `/debate-build` → `/debate-discuss` + `/escalate`로 대체
- `/oracle-debate` → `/debate-discuss`로 통합
- `/peer`, `/codex-oracle-peer` → `/debate-discuss`로 통합
- `/codex-implementation-contract` → `/contract`로 통합
- `/codex-first-review`, `/review1-from-contract` → `/review1`로 통합
- `/implement-from-contract` → `/implement`로 통합
- `/debate-build-full` → `/escalate`로 대체

### Oracle 호출 규칙

- **반드시 `codex exec`를 `run_oracle_sync.sh`로 실행**한다
- `codex:codex-rescue`, `codex:codex-review` subagent로 Oracle을 대체하지 않는다
- 기본 sandbox: **bypass** (`--dangerously-bypass-approvals-and-sandbox`)
- session-id 기반 resume: `.protocol/runs/<task-id>/oracle/session-id.txt`
- `codex exec resume`은 `-s`, `-m` 옵션 미지원. 첫 세션 설정이 유지됨.

### `/escalate` 세부 플로우

`/debate-discuss`로 토론 완료 후, 사용자가 구현을 요청하면:

1. **토론 마무리**: summary + score가 없으면 먼저 작성 (scorer = Oracle)
2. **Contract 작성** (`/contract`): 토론 합의 → `03-contract.md`
3. **Oracle 계약 승인**: `run_oracle_sync.sh`로 contract 검토
4. **구현**: Sisyphus가 contract 범위 내에서 구현
5. **1차 리뷰** (`/review1`): 3 Claude 에이전트 병렬 (code + security + architecture)
6. **CRITICAL 수정**: 1차에서 CRITICAL 발견 시 즉시 수정
7. **2차 리뷰** (`/oracle-final-review`): Oracle 최종 리뷰
8. **hold 시**: `/fix-from-final` → Oracle closeout

## Debate Score 규칙

### 목적

- summary는 토론의 서사를 남긴다
- score는 논점별 판정과 근거를 구조화한다
- 둘 다 있어야 나중에 모델별 성향, 채택 근거, 미해결 쟁점을 추적할 수 있다

### 필수 원칙

1. `01-debate-summary.md`와 `02-debate-score.json`은 모든 intent에서 필수다.
2. score는 summary 없이 작성하면 안 된다.
3. score는 contract보다 먼저 고정되어야 한다.

### verdict 어휘

논점별 verdict는 아래 네 개만 허용한다.

- `oracle`
- `sisyphus`
- `converged`
- `unresolved`

규칙:

- `converged` = 양측이 합의점에 도달함
- `unresolved` = 합의 실패, 추가 토론 또는 사용자 결정 필요
- `draw`, `tie`, `both good` 같은 모호한 표현은 금지한다

### overall 규칙

종합 verdict는 아래 네 개만 허용한다.

- `oracle_dominant`
- `sisyphus_dominant`
- `balanced`
- `unresolved`

추가 규칙:

1. `unresolved` 논점이 하나라도 있으면 overall은 `unresolved`만 가능하다.
2. `implementation_bound`에서 overall이 `unresolved`이면 contract 단계로 넘어가면 안 된다.

### 평가 기준 우선순위

논점별 verdict를 정할 때는 아래 우선순위를 따른다.

1. `evidence`
  - 코드, 데이터, 문서, 선례 같은 명시적 근거가 있는가
2. `risk_identification`
  - 상대 안의 리스크를 구체적으로 짚었는가
3. `feasibility`
  - 현재 시스템에서 실제로 구현 가능한가
4. `scope_discipline`
  - 논점에 집중했고 범위를 불필요하게 넓히지 않았는가
5. `concession_quality`
  - 상대 주장을 수용하거나 수정할 때 이유가 명확한가

### starter advantage 상쇄 규칙

1. Non-starter는 반드시 counter-brief를 제출한다.
2. counter-brief는 최소 하나의 대안 또는 최소 세 개의 리스크를 포함해야 한다.
3. starter와 score 초안 작성자는 같으면 안 된다.
4. `meta.json`에는 `starter`를 기록하고, `02-debate-score.json`에는 `scorer`를 기록한다.

### score 최소 구조

```json
{
  "starter": "sisyphus",
  "scorer": "oracle",
  "topic_scores": [
    {
      "topic": "논점 이름",
      "position_oracle": "Oracle 입장 한 줄",
      "position_sisyphus": "Sisyphus 입장 한 줄",
      "verdict": "oracle",
      "criteria_basis": ["evidence", "risk_identification"],
      "reasoning": "판정 근거 한 줄"
    }
  ],
  "overall": {
    "verdict": "oracle_dominant",
    "reasoning": "종합 근거 한 줄"
  }
}
```

## 어댑터 문서

이 문서는 원본이다.

- Sisyphus 쪽 어댑터: `.claude/CLAUDE.md`, `.claude/commands/*`, `.claude/skills/*`
- Oracle 쪽 어댑터: `AGENTS.md`
- 전역 어댑터: `~/.claude/CLAUDE.md`, `~/.claude/commands/*`, `~/.claude/skills/*`

어댑터 문서는 이 문서를 요약하거나 실행 경로를 연결할 수는 있지만, 역할 정의를 임의로 바꾸면 안 된다.
산출물 정본은 `.protocol/runs/<task-id>/`다.
