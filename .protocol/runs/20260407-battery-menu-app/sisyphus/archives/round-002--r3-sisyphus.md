# Round 3 — Sisyphus

## Position: Oracle의 핵심 교정을 수용하되, Phase 0의 범위와 "정책 엔진" 프레이밍의 실질적 의미를 구체화한다

### 1. Oracle의 교정 중 수용하는 것

Oracle이 지적한 두 가지 핵심 오판을 인정한다:

1. **IOPMAssertion 기반 간접 제어라는 추정은 틀렸다.** batt/battery 소스를 직접 확인하지 않고 추정했다. 실제로는 `CH0B`, `CH0C`, `CHTE` 등 SMC 직접 쓰기가 핵심이고, IOPMAssertion은 sleep 방지용이다. 이 교정은 아키텍처 판단에 직접적 영향을 미친다.

2. **"Sequoia 지원"은 조건부 지원이다.** firmware + SoC + OS 조합에 따라 동작 여부가 달라지며, 안정성도 균일하지 않다. 이것을 "플랫폼 보장"으로 읽은 것은 오류였다.

3. **"battery policy scheduler"라는 프레이밍이 더 정확하다.** 제품의 핵심 가치가 충전 제한 자체가 아니라 스케줄 정책에 있다는 분석에 동의한다.

### 2. Oracle의 제안 중 조정이 필요한 것

#### Phase 0의 범위

Oracle은 "UI 전에 backend probe를 먼저 만들라"고 했다. 방향은 맞지만 범위가 모호하다. 구체적으로:

- **대상 기기가 1대다.** 사용자 본인의 MacBook 하나. 다양한 firmware/SoC 조합을 테스트할 수 없다. Phase 0이 "포괄적 호환성 매트릭스 작성"이 되면 끝나지 않는다.
- **검증 범위를 한정한다**: 사용자 기기에서 (1) batt 설치 후 80/100 전환이 되는지, (2) sleep/wake 후 유지되는지, (3) clamshell 모드에서 유지되는지. 이 세 가지만 확인하면 Phase 1 진입 판단이 가능하다.
- **Phase 0은 코드가 아니라 검증이다.** 별도 probe 앱을 만들 필요 없이, batt CLI를 직접 실행하고 결과를 기록하면 된다. 30분이면 끝난다.

#### Backend Adapter 추상화의 깊이

Oracle이 제안한 `ChargeLimitBackend` 인터페이스는 올바르다. 하지만 초기에 너무 많은 추상화를 넣으면 오히려 부담이다:

```swift
protocol ChargeLimitBackend {
    func setChargeLimit(_ percent: Int) async throws
    func currentChargeLimit() async throws -> Int?
    func isAvailable() async -> Bool
}
```

이 정도면 충분하다. 구현체는:
- `BattCLIBackend` (Phase 1 — batt subprocess 호출)
- `NativeSMCBackend` (Phase 2 — 직접 SMC 접근, 검증된 키만)
- `AppleChargeLimitBackend` (Phase 3 — 공식 API 사용 가능 시)

에러 surface, health check, fallback은 이 protocol 위에 `BackendManager`가 처리한다.

### 3. 수렴 가능한 아키텍처

Oracle과 Sisyphus 양쪽의 제안을 통합하면:

```
Phase 0 (검증, 1시간):
  - 사용자 기기에서 batt CLI 설치/실행
  - 80/100 전환, sleep/wake 유지, clamshell 유지 확인
  - 결과 기록 → Phase 1 진입 판단

Phase 1 (MVP, 2주):
  - SwiftUI MenuBarExtra 앱
  - ChargeLimitBackend protocol + BattCLIBackend 구현
  - 요일별 스케줄 정책 엔진 (Timer + Calendar 기반)
  - LaunchAgent 자동시작
  - 상태 표시: 현재 limit, 오늘 정책, 다음 전환 시각
  - "오늘만 100%" 예외 처리

Phase 2 (선택, batt가 불안정할 때만):
  - Phase 0/1에서 수집한 호환성 데이터 기반
  - NativeSMCBackend (검증된 키 조합만)
  - SMAppService + LaunchDaemon + XPC

Phase 3 (Apple API 공개 시):
  - AppleChargeLimitBackend
  - 공식 API 감지 시 자동 우선 선택
  - batt backend는 fallback으로 유지
```

### 4. 남은 논점

1. **batt 바이너리 번들링 vs 사용자 직접 설치**: batt를 앱에 포함시키면 라이선스(GPL? MIT?) 확인 필요. 사용자가 Homebrew로 직접 설치하게 하고 앱은 PATH에서 찾는 방식이 더 깔끔한가?

2. **정책 엔진의 복잡도**: MVP에서 "요일별 자동 전환"만 넣을지, "출장 모드", "충전 필요 시간 기반 자동 판단" 같은 것도 초기에 설계할지?

3. **앱 이름과 정체성**: Oracle이 말한 대로 "battery policy scheduler"로 포지셔닝하면, 단순 limit setter 대비 사용자에게 더 복잡하게 느껴질 수 있다. MVP에서의 UX는 어떻게 단순하게 유지할 것인가?

### 5. 합의 확인 요청

다음 사항에 대해 Oracle과 합의하고 싶다:

- Phase 0을 "사용자 기기 1대에서 batt CLI 3가지 시나리오 검증"으로 한정하는 것에 동의하는가?
- ChargeLimitBackend protocol 수준이 적절한가?
- batt 번들링 vs Homebrew 의존 — 어느 쪽이 적절한가?
- MVP의 정책 엔진 범위 — 요일별 스케줄링만으로 충분한가?
