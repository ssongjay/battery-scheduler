# Oracle Round 2: 수렴을 위한 합의 확인

## Context

이 토론의 목적은 macOS 메뉴바 배터리 관리 앱(요일별 충전 상한 자동 스케줄링)의 **기술적 실현 가능성과 아키텍처 방향**에 대한 합의다.

## 토론 진행 상황

- **R1 Sisyphus**: batt CLI 래핑 + Phase 방식 제안. IOPMAssertion 기반 간접 제어를 추정.
- **R2 Oracle**: IOPMAssertion 추정 오류 교정. SMC 직접 쓰기가 핵심. "battery policy scheduler" 프레이밍. Phase 0(메커니즘 검증) 추가 제안. Backend adapter 추상화 권고.
- **R3 Sisyphus**: Oracle의 핵심 교정 수용. Phase 0 범위를 "사용자 기기 1대에서 batt 3가지 시나리오 검증"으로 한정 제안. ChargeLimitBackend protocol 구체화. 4가지 합의 요청.

## Sisyphus의 합의 요청

1. **Phase 0 범위**: 사용자 기기 1대에서 batt CLI로 (1) 80/100 전환 (2) sleep/wake 후 유지 (3) clamshell 모드 유지 — 이 3가지만 검증하는 것에 동의하는가?

2. **ChargeLimitBackend protocol**: 
```swift
protocol ChargeLimitBackend {
    func setChargeLimit(_ percent: Int) async throws
    func currentChargeLimit() async throws -> Int?
    func isAvailable() async -> Bool
}
```
이 수준이 적절한가?

3. **batt 번들링 vs Homebrew 의존**: 앱에 batt 바이너리를 포함시킬지, 사용자가 Homebrew로 직접 설치하게 할지?

4. **MVP 정책 엔진 범위**: 요일별 스케줄링만으로 충분한가, 아니면 "오늘만 100%" 예외 처리도 포함해야 하는가?

## 수렴된 아키텍처 (Sisyphus 제안)

```
Phase 0: batt CLI 검증 (1시간)
Phase 1: SwiftUI MenuBarExtra + BattCLIBackend + 요일별 스케줄 정책
Phase 2: NativeSMCBackend (선택, batt 불안정 시만)
Phase 3: AppleChargeLimitBackend (API 공개 시)
```

## 당신의 역할

Oracle로서 위 합의 요청에 대해 답변하고, 추가 조정이 필요한 부분이 있으면 제시하라. 수렴이 가능하면 그 지점을 명확히 하라.

## 응답 작성 위치

아래 파일에 직접 작성하라:
- `.protocol/runs/20260407-battery-menu-app/debate/r4-oracle.md`

형식:
```markdown
# Round 4 — Oracle

## Position: [한 줄 요약]

[본문]
```
