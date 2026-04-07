# Round 1 — Sisyphus

## Position: 실용적 래핑 + 점진적 네이티브 전환

### 1. 핵심 문제 인식

macOS Sequoia(15.x)에서 SMC 배터리 키(`CHWA`, `CHLS`)에 entitlement가 강제 적용되면서, **순수 Swift로 IOKit→SMC 직접 접근하는 방식은 사실상 막혔다.** bclm은 Sequoia에서 동작하지 않고, SMCKit도 Intel 전용이다.

그런데 charlie0129/batt(Go)와 actuallymentor/battery(Shell/Swift)는 Sequoia에서도 동작한다. 이들이 어떻게 동작하는지가 이 프로젝트의 실현 가능성을 결정한다.

### 2. batt/battery의 Sequoia 우회 방식 (조사 결과)

- **batt**: Go로 작성. `smc` 바이너리를 직접 포함하지 않고, Apple의 `pmset` 명령과 IOPMAssertion API를 조합해서 충전을 제어. Sequoia에서는 SMC 직접 접근 대신 **IOPMAssertion 기반 충전 억제**를 사용하는 것으로 추정.
- **battery**: `sudo smc -k BCLM -w <hex>` 방식이지만, Apple Silicon에서는 다른 경로를 사용. `sudo pmset -a discharging 1` 같은 명령 조합 활용.

→ Sequoia에서의 핵심은 **SMC 직접 쓰기가 아니라 pmset/IOPMAssertion 기반 간접 제어**일 가능성이 높다.

### 3. 제안 아키텍처

```
Phase 1 (MVP — 2주):
  SwiftUI 메뉴바 앱 (MenuBarExtra)
  + batt CLI를 번들링하여 subprocess로 호출
  + Timer 기반 요일별 스케줄링
  + LaunchAgent로 로그인 시 자동시작

Phase 2 (1개월):
  batt의 핵심 로직을 Swift로 포팅
  + SMAppService + LaunchDaemon + XPC 구조
  + IOPMAssertion 기반 네이티브 충전 제어
  + Privileged Helper로 root 권한 분리

Phase 3 (선택):
  macOS Tahoe 26.4+ Charge Limit API 감지 및 연동
  + Apple 공식 API 사용 가능 시 자동 전환
```

### 4. 왜 batt 래핑부터 시작하는가

- **검증된 동작**: batt는 Sequoia + Apple Silicon에서 동작이 확인됨
- **빠른 MVP**: CLI subprocess 호출은 XPC/Helper 구현 대비 10배 빠름
- **리스크 분산**: 네이티브 포팅이 막히더라도 앱 자체는 동작
- **학습 기회**: batt 소스 분석하면서 Sequoia 우회 방법을 정확히 파악

### 5. 토론 요청 사항

Oracle에게 다음을 묻고 싶다:

1. **batt CLI 래핑 접근이 기술 부채가 되지 않는가?** Go 바이너리를 Swift 앱에 번들링하는 것이 장기적으로 유지보수 가능한가?
2. **Apple Silicon에서 CHWA가 80/100만 지원하는 제약** — 이 제약이 "요일별 자동 전환"이라는 핵심 기능과 충돌하는가? (80%와 100% 두 값이면 우리 요구사항에 충분하긴 하다)
3. **macOS Tahoe의 공식 Charge Limit** — Apple이 Shortcuts 연동까지 계획 중이라면, 이 앱의 존재 의의가 줄어드는가? 아니면 "요일별 자동 스케줄링"이라는 차별점으로 충분한가?
4. **개발 언어 선택** — Swift 순수 구현 vs batt처럼 Go 사용 vs 하이브리드?
5. **SIP 비활성화 없이 가능한 범위는 어디까지인가?**
