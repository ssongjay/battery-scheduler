# Debate Summary

## Resolved

1. **실현 가능성**: MVP는 batt CLI를 활용해 구현 가능하다 (양측 합의)
2. **제품 정체성**: "battery limit setter"가 아니라 "battery policy scheduler" (Oracle 제안, Sisyphus 수용)
3. **아키텍처**: ChargeLimitBackend protocol로 backend 교체 가능성 확보 (양측 합의)
4. **Phase 0 범위**: 사용자 기기 1대, 3개 시나리오, 실제 상태 변화까지 확인 (양측 합의)
5. **배포 방식**: batt 바이너리 번들링, Homebrew/PATH 의존 금지 (Oracle 제안, Sisyphus 수용)
6. **MVP 정책 범위**: 요일별 스케줄 + "오늘만 100%" override (Oracle 제안, Sisyphus 수용)
7. **Protocol 설계**: `configuredChargeLimit()` best-effort contract (Oracle 제안, Sisyphus 수용)

## Unresolved

없음. 핵심 논점 전부 수렴.

## Position Summary By Issue

### issue-1: SMC 접근 메커니즘

- Oracle: batt/battery는 IOPMAssertion이 아니라 SMC 직접 쓰기(`CH0B`, `CH0C`, `CHTE`)로 동작. Sequoia 지원은 조건부.
- Sisyphus: 초기 IOPMAssertion 추정을 철회하고 Oracle 분석을 수용.
- Current conclusion: SMC 직접 쓰기가 핵심. Sequoia 지원은 firmware/SoC/OS 조합에 의존하는 조건부 지원.

### issue-2: 아키텍처 방향 (Phase 구성)

- Oracle: Phase 0(메커니즘 검증) 추가. Phase 1에서 backend adapter 추상화 필수. "오늘만 100%" MVP 포함.
- Sisyphus: Phase 0 범위를 기기 1대 3시나리오로 한정. ChargeLimitBackend protocol 구체화.
- Current conclusion: Phase 0(검증) → Phase 1(MVP: SwiftUI + BattCLIBackend + 정책엔진) → Phase 2(NativeSMC, 선택) → Phase 3(Apple API)

### issue-3: 배포 및 의존성 전략

- Oracle: batt 번들링 > Homebrew. PATH 탐색 의존 금지. pinned implementation으로 취급.
- Sisyphus: 초기에 Homebrew 의존 가능성 제기했으나 Oracle 권고 수용.
- Current conclusion: batt 바이너리를 앱 번들에 포함. 라이선스 확인 필요.

### issue-4: 제품의 존재 의의 (vs Apple 공식 기능)

- Oracle: 충전 제한 자체는 commodity화 예정. 차별점은 요일별 정책, 예외 처리, 상태 가시성, 자동 fallback.
- Sisyphus: 동의. "battery policy scheduler"로 포지셔닝.
- Current conclusion: Apple 공식 Charge Limit이 나와도 "정책 자동화"로 차별화 가능. API 공개 시 최우선 backend로 채택.

## Decision For Next Stage

selected: stop_at_discussion
