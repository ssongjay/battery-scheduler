# Sisyphus-Oracle Stage Contracts

이 문서는 [PROTOCOL.md](/Users/inje/Desktop/develop/projects/buy-good-things/.protocol/PROTOCOL.md)의 단계별 실행 계약 원본이다.

원칙:

- 각 단계는 `owner`, `required inputs`, `required outputs`, `completion gate`, `stop conditions`를 가진다
- 단계 이름은 command 이름과 1:1로 맞춘다
- runner나 wrapper를 만들 때도 이 문서를 기준으로 입력/출력 검증을 건다

## 공통 run 전제

모든 단계는 동일 run 디렉터리를 기준으로 움직인다.

```text
.protocol/runs/<task-id>/
```

공통 필수 파일:

- `stage-log.jsonl`
- `meta.json`
- `00-brief.md`

`meta.json` 최소 불변식:

- `starter`
- `oracle = "oracle"`
- `implementer = "sisyphus"`
- `intent`

운영 기본값:

- 새 run은 `discussion_only`로 시작한다
- 구현이 필요하면 같은 run에서 `/escalate`로 `implementation_bound`로 전환한다
- `implementation_bound` 직접 시작은 legacy/manual recovery 용도다

추가 원칙:

- Oracle shadow implementation은 comparison-only다
- canonical 구현 owner는 계속 `implementer = "sisyphus"`다
- Oracle shadow code는 stage 완료 시 stash 또는 동등한 격리 상태로 active working tree에서 빠져 있어야 한다
- 구현/리뷰/final/closeout 계열 JSON에는 필요 시 `model_notes` 자유 텍스트를 넣어, 이번 run에서 드러난 모델 특성을 남긴다

## Stage Matrix

| Stage | Owner | Intent | Reads | Writes |
|------|------|------|------|------|
| `debate-discuss` | Starter initiates, Oracle + Sisyphus debate | `discussion_only` | `stage-log.jsonl`, `meta.json`, `00-brief.md` | `debate/round-*/oracle.md`, `debate/round-*/sisyphus.md`, `prompts/*`, `01-debate-summary.md`, `02-debate-score.json`, `debate-meta.json`, `stage-log.jsonl` |
| `debate-build` | Starter initiates, Oracle + Sisyphus debate | `implementation_bound` | `stage-log.jsonl`, `meta.json`, `00-brief.md` | `debate/round-*/oracle.md`, `debate/round-*/sisyphus.md`, `prompts/*`, `01-debate-summary.md`, `02-debate-score.json`, `debate-meta.json`, `03-contract.md`, `stage-log.jsonl` |
| `oracle-pre-impl-guardrails` | Oracle | `implementation_bound` | `stage-log.jsonl`, `meta.json`, `03-contract.md`, `01-debate-summary.md`, `02-debate-score.json` | `oracle/implementation-guardrails.md`, `stage-log.jsonl` |
| `oracle-shadow-implement` | Oracle | `implementation_bound` | `stage-log.jsonl`, `meta.json`, `03-contract.md`, `oracle/implementation-guardrails.md`, 현재 작업 트리 상태 | comparison-only shadow code changes, `oracle/shadow-implementation-summary.md`, `oracle/shadow-implementation-report.json`, validation notes, `stage-log.jsonl` |
| `implement-from-contract` | Sisyphus | `implementation_bound` | `stage-log.jsonl`, `meta.json`, `00-brief.md`, `01-debate-summary.md`, `02-debate-score.json`, `03-contract.md` | code changes, `sisyphus/implementation-summary.md`, `sisyphus/implementation-report.json`, validation notes, `stage-log.jsonl` |
| `review1-from-contract` | Sisyphus | `implementation_bound` | `stage-log.jsonl`, `meta.json`, `03-contract.md`, implementation diff, validation output, `sisyphus/implementation-summary.md`, `sisyphus/implementation-report.json` | `review1/code-review.md`, `review1/security-review.md`, `review1/architecture-review.md`, `review1/findings.json`, `04-review1.md`, `stage-log.jsonl` |
| `oracle-final-review` | Oracle | `implementation_bound` | `stage-log.jsonl`, `meta.json`, `03-contract.md`, implementation diff, validation output, `04-review1.md`, `review1/*`, `sisyphus/implementation-summary.md`, `sisyphus/implementation-report.json` | `05-oracle-final.md`, `oracle/final-report.json`, `stage-log.jsonl` |
| `fix-from-final` | Sisyphus | `implementation_bound` | `stage-log.jsonl`, `meta.json`, `03-contract.md`, `05-oracle-final.md`, `oracle/final-report.json`, implementation diff, validation output | code changes, `06-fix-from-final.md`, `sisyphus/final-fix-report.json`, validation notes, `stage-log.jsonl` |
| `oracle-closeout` | Oracle | `implementation_bound` | `stage-log.jsonl`, `meta.json`, `03-contract.md`, `05-oracle-final.md`, `oracle/final-report.json`, `06-fix-from-final.md`, `sisyphus/final-fix-report.json` | `07-oracle-closeout.md`, `oracle/closeout-report.json`, `stage-log.jsonl` |

## debate-discuss

### Owner

- starter가 진입을 열고, Oracle/Sisyphus가 동급 토론을 수행한다
- scorer는 starter가 아닌 쪽이 기본이다

### Required Inputs

- `meta.json`
- `00-brief.md`
- counter-brief에 필요한 문맥

### Required Outputs

- `debate/round-*/oracle.md`
- `debate/round-*/sisyphus.md`
- `prompts/round-*-sisyphus.md`
- `debate-meta.json`
- `01-debate-summary.md`
- `02-debate-score.json`
- `stage-log.jsonl`

### Completion Gate

- `summary`에 resolved / unresolved가 모두 정리되어 있다
- `score`에 각 핵심 issue가 기록되어 있다
- `overall_verdict`가 비어 있지 않다
- `Decision For Next Stage = closed`

### Stop Conditions

- 핵심 논점이 아직 정리되지 않았다
- score의 핵심 issue가 비어 있다
- scorer가 starter와 동일하다

## debate-build

### Owner

- starter가 진입을 열고, Oracle/Sisyphus가 동급 토론을 수행한다
- contract 승인권은 항상 Oracle이다

### Required Inputs

- `meta.json`
- `00-brief.md`
- counter-brief에 필요한 문맥

### Required Outputs

- `debate/round-*/oracle.md`
- `debate/round-*/sisyphus.md`
- `prompts/round-*-sisyphus.md`
- `debate-meta.json`
- `01-debate-summary.md`
- `02-debate-score.json`
- `03-contract.md`
- `stage-log.jsonl`

### Completion Gate

- `summary`가 완성되어 있다
- `score`가 완성되어 있다
- `03-contract.md`가 scope / non-goals / forbidden approaches / acceptance criteria를 포함한다
- Oracle이 contract를 승인했다
- `Decision For Next Stage = closed`

### Stop Conditions

- `overall_verdict = unresolved`
- unresolved 핵심 issue가 contract로 넘어가 있다
- contract가 summary/score와 충돌한다

## implement-from-contract

### Owner

- Sisyphus

### Required Inputs

- `meta.json`
- `00-brief.md`
- `01-debate-summary.md`
- `02-debate-score.json`
- `03-contract.md`
- 현재 작업 트리 상태

### Required Outputs

- contract 범위 안의 코드 변경
- `sisyphus/implementation-summary.md`
- `sisyphus/implementation-report.json`
- 필요한 검증 결과
- Oracle에 넘길 구현 요약 근거
- `stage-log.jsonl`

### Completion Gate

- 변경이 `03-contract.md`의 files in scope를 벗어나지 않는다
- forbidden approaches 위반이 없다
- acceptance criteria를 만족하거나, 미충족 이유가 명시돼 있다
- 다음 단계인 `review1-from-contract`가 읽을 diff/validation 근거가 남아 있다

### Stop Conditions

- contract 밖 설계 변경이 필요하다
- unresolved 토론 쟁점이 다시 열렸다
- 검증 실패를 설명 없이 넘기려 한다

## oracle-pre-impl-guardrails

### Owner

- Oracle

### Required Inputs

- `meta.json`
- `01-debate-summary.md`
- `02-debate-score.json`
- `03-contract.md`

### Required Outputs

- `oracle/implementation-guardrails.md`
- `stage-log.jsonl`

### Completion Gate

- 반드시 지켜야 할 invariant가 적혀 있다
- “거짓 통과”가 일어날 수 있는 failure mode가 적혀 있다
- 이후 `implement-from-contract`와 `review1-from-contract`가 참고할 review emphasis가 적혀 있다

### Stop Conditions

- contract를 반복 요약만 하고 guardrail이 비어 있다
- 구현자에게 실제로 도움이 되는 invariant / failure mode가 없다

## oracle-shadow-implement

### Owner

- Oracle

### Required Inputs

- `meta.json`
- `03-contract.md`
- `oracle/implementation-guardrails.md` 권장
- 현재 작업 트리 상태

### Required Outputs

- comparison-only shadow code changes
- `oracle/shadow-implementation-summary.md`
- `oracle/shadow-implementation-report.json`
- 필요한 검증 결과
- `stage-log.jsonl`

### Completion Gate

- shadow 구현이 contract 범위 안인지 명시돼 있다
- 결과가 comparison-only라는 점이 summary/report에 적혀 있다
- stash ref 또는 동등한 격리 경로가 기록돼 있다
- shadow code가 active working tree에 남아 있지 않다

### Stop Conditions

- Oracle shadow patch를 canonical 구현으로 착각하게 만드는 기록을 남긴다
- stash / 격리 없이 shadow code를 main working tree에 남긴다
- contract 밖 확장을 comparison 단계라는 이유로 덮어쓴다

## review1-from-contract

### Owner

- Sisyphus

### Required Inputs

- `meta.json`
- `03-contract.md`
- implementation diff
- validation output

### Required Outputs

- `review1/code-review.md`
- `review1/security-review.md`
- `review1/architecture-review.md`
- `review1/findings.json`
- `04-review1.md`
- `stage-log.jsonl`

### Completion Gate

- 세부 리뷰 3개가 모두 존재한다
- `04-review1.md`가 세부 리뷰를 종합한다
- contract compliance가 명시돼 있다
- 남은 리스크와 열린 쟁점이 숨김 없이 적혀 있다

### Stop Conditions

- 세부 리뷰 중 하나라도 비어 있다
- contract 위반 여부가 없다
- 심각도 구분 없이 감상문처럼 끝난다

## oracle-final-review

### Owner

- Oracle

### Required Inputs

- `meta.json`
- `03-contract.md`
- implementation diff
- validation output
- `04-review1.md`
- `review1/*`

### Required Outputs

- `05-oracle-final.md`
- `oracle/final-report.json`
- `stage-log.jsonl`

### Completion Gate

- 최종 판단이 `approve | hold | reject` 중 하나로 명시돼 있다
- contract compliance가 최우선으로 판정돼 있다
- review1에서 열린 쟁점이 닫혔는지 평가돼 있다
- 남은 리스크가 기록돼 있다

### Stop Conditions

- contract 대비 판정 근거가 없다
- review1 열린 쟁점을 무시한다
- release decision이 비어 있다

## fix-from-final

### Owner

- Sisyphus

### Required Inputs

- `meta.json`
- `03-contract.md`
- `05-oracle-final.md`
- `oracle/final-report.json`
- 현재 작업 트리 상태

### Required Outputs

- final finding 반영 코드 변경
- `06-fix-from-final.md`
- `sisyphus/final-fix-report.json`
- 필요한 검증 결과
- `stage-log.jsonl`

### Completion Gate

- 어떤 final finding을 닫았는지 명시돼 있다
- 남은 open finding이 숨김 없이 적혀 있다
- 검증 결과가 기록돼 있다

### Stop Conditions

- Oracle final finding을 임의로 재분류하거나 무시한다
- 변경이 final finding 범위를 넘어 새 설계 작업으로 번진다

## oracle-closeout

### Owner

- Oracle

### Required Inputs

- `meta.json`
- `03-contract.md`
- `05-oracle-final.md`
- `oracle/final-report.json`
- `06-fix-from-final.md`
- `sisyphus/final-fix-report.json`

### Required Outputs

- `07-oracle-closeout.md`
- `oracle/closeout-report.json`
- `stage-log.jsonl`

### Completion Gate

- closeout 판단이 `approve | hold | reject` 중 하나로 명시돼 있다
- final finding이 실제로 닫혔는지 재판정한다
- 남은 blocking risk가 있으면 숨기지 않는다

### Stop Conditions

- final finding closure 근거가 없다
- `fix-from-final` 내용을 읽지 않고 결론만 바꾼다
