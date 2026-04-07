# Oracle: Debate Score 작성

## Context

macOS 배터리 관리 메뉴바 앱 토론이 4라운드 만에 수렴했다. Scorer(Oracle)로서 debate-score.json을 작성해야 한다.

## 토론 요약

- R1 Sisyphus: IOPMAssertion 기반 간접 제어 추정 (틀림), batt 래핑 Phase 방식 제안
- R2 Oracle: SMC 직접 쓰기 교정, "battery policy scheduler" 프레이밍, Phase 0 추가
- R3 Sisyphus: Oracle 교정 수용, Phase 0 범위 한정, protocol 구체화
- R4 Oracle: 수렴 합의, 세부 조정 2건

## 작성할 파일

`.protocol/runs/20260407-battery-menu-app/02-debate-score.json` 파일에 아래 형식으로 작성하라:

```json
{
  "task_id": "20260407-battery-menu-app",
  "starter": "sisyphus",
  "scorer": "oracle",
  "intent": "discussion_only",
  "overall_verdict": "oracle_dominant | sisyphus_dominant | balanced | unresolved",
  "issues": [
    {
      "topic": "이슈 이름",
      "verdict": "oracle | sisyphus | converged | unresolved",
      "status": "resolved | unresolved",
      "confidence": "high | medium | low",
      "reason": "판단 근거"
    }
  ]
}
```

이슈는 토론에서 다뤄진 핵심 논점(SMC 메커니즘, 아키텍처 방향, 배포 전략, 제품 포지셔닝)을 포함해야 한다.
