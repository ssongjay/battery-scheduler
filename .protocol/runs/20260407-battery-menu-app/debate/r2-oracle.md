# Round 2 — Oracle

## Position: MVP는 가능하지만, Sisyphus가 상정한 동작 원리는 틀렸고, 제품의 중심은 SMC 해킹이 아니라 백엔드 추상화된 "스케줄 정책 엔진"이어야 한다.

Sisyphus의 결론 중 "지금 만들 수 있다"는 방향 자체는 대체로 맞다. 다만 근거가 잘못됐다. 핵심 오판은 `batt`/`battery`가 Sequoia에서 `IOPMAssertion`이나 `pmset`만으로 간접 제어한다는 추정이다. 실제 코드를 보면 둘 다 여전히 **SMC 직접 쓰기**를 중심으로 동작한다. `batt`는 `CH0B`, `CH0C`, `CHTE`, `CH0I/J`, `CHIE` 같은 키를 쓰고, `battery`도 동일한 계열 키를 `sudo smc -k ... -w ...`로 쓴다. `IOPMAssertion`은 충전 제어가 아니라 **잠자기 방지**에만 쓰인다. Apple 문서도 `kIOPMAssertionTypePreventSystemSleep`를 "sleep 방지"로 설명한다. 즉 Sequoia에서 살아남은 경로는 "공식 우회 API"가 아니라, **일부 SMC write path가 아직 펌웨어/SoC 조합에 따라 열려 있는 상태**에 가깝다.

이 점은 아키텍처 판단을 바꾼다. Sequoia에서의 실현 가능성은 "Swift냐 Go냐"의 문제가 아니라, **해당 Mac의 firmware + SoC + OS 조합에서 현재 어떤 SMC 키 세트가 살아 있느냐**의 문제다. `batt` README도 호환성을 macOS 버전이 아니라 firmware version 기준으로 표기한다. 더 나쁘게는, 실제 이슈를 보면 안정성도 균일하지 않다. `battery`는 2025-09-17에 macOS 15.7 회귀 이슈가 있었고, `batt`도 2025-09-18과 2026-03-03에 15.7/15.7.4 관련 실패 사례가 보인다. 따라서 "Sequoia 지원"은 제품 관점에서 보면 **조건부 지원**이지, 플랫폼 보장이 아니다.

그래서 나는 Sisyphus의 Phase 구성을 그대로 받지 않는다. 방향은 유지하되, 경계를 바꿔야 한다.

1. **Phase 0 - 메커니즘 검증**
   먼저 UI가 아니라 backend probe를 만들어야 한다. 목표는 간단하다: 대상 기기에서 어떤 SMC 키 조합이 읽기/쓰기에 성공하는지, sleep/wake 후 유지되는지, clamshell/forced sleep에서 깨지는지 표로 만드는 것이다. 이 단계 없이 SwiftUI 메뉴바부터 올리면, 보기 좋은 실패 앱이 된다.

2. **Phase 1 - SwiftUI 앱 + 백엔드 어댑터**
   MVP는 가능하다. 다만 "batt CLI 래핑"을 제품 아키텍처가 아니라 **한 구현체**로만 취급해야 한다. 즉 앱 내부에 `ChargeLimitBackend` 같은 추상 인터페이스를 두고, 초기 구현체를 `BattBackend`로 둔다. 스케줄링, 상태 판단, 에러 표면화, 권한 UX는 Swift 쪽이 소유하고, 충전 on/off만 backend가 수행한다. 이렇게 해야 나중에 `batt`를 버리거나 native backend로 교체해도 UI/정책 계층이 안 무너진다.

3. **Phase 2 - Native backend는 "포팅"이 아니라 "대체"**
   batt를 Swift로 포팅하는 것을 너무 일찍 목표로 잡으면 안 된다. 그건 기술적 순수함은 주지만 제품 리스크를 줄이지는 않는다. batt의 본질적 난점은 언어가 아니라 **불안정한 하드웨어 제어 경로와 sleep edge case**다. 따라서 native 구현은 batt를 번역하는 작업이 아니라, Phase 0/1에서 수집한 실제 호환성 데이터를 바탕으로 **검증된 키 조합만 다시 구현하는 작업**이어야 한다.

4. **Phase 3 - Apple 공식 기능은 "통합"이 아니라 "우선 백엔드"**
   Apple Support 문서 기준으로 `Charge Limit`은 **macOS Tahoe 26.4 이상 + Apple silicon**에서 제공되고, 설정 범위는 **80%~100%**다. 또한 충전량이 limit보다 몇 % 낮아지면 다시 충전을 재개한다. 이건 사용자가 원하는 "화/토/일 80%, 나머지 100%"와 매우 잘 맞는다. 문제는, 내가 확인한 범위에서는 **공개 개발자 API가 아직 보이지 않는다**는 점이다. 그러므로 Phase 3를 "Charge Limit API 연동"으로 쓰면 과장이다. 더 정확한 표현은:
   - 공개 API 또는 Shortcuts/Automation surface가 생기면 그걸 최우선 backend로 채택
   - 그 전까지는 26.4+에서 시스템 기능 존재를 감지하고, 충돌을 피하는 방향으로 공존

가장 큰 기술 리스크는 스케줄링이 아니다. **충전 제어 write path의 취약성**이다. 일정은 `Calendar`와 background process로 해결된다. 반면 SMC 제어는 다음 변수들에 취약하다:

- firmware 업데이트로 키 의미가 바뀌거나 사라질 수 있음
- forced sleep, lid close, hibernation에서 제어가 끊길 수 있음
- root helper와 launch 구조가 꼬이면 "설정은 됐다고 나오는데 실제로는 100%까지 충전"하는 거짓 양성 상태가 생김
- notarization/권한 UX가 나쁘면 설치 이탈이 큼

사업 리스크도 분명하다. Apple이 26.4에서 공식 Charge Limit를 넣은 순간, "배터리 충전 상한 앱" 자체는 빠르게 commodity가 된다. 따라서 이 앱의 존재 의의는 **충전 제한 그 자체**가 아니라:

- 요일/시간 기반 정책
- 예외 처리(출장 모드, 오늘만 100%)
- 상태 가시성
- 시스템 기능과 비공식 backend 사이의 자동 fallback

이 네 가지에 있어야 한다. 다시 말해 제품은 "배터리 limit setter"가 아니라 **battery policy scheduler**여야 한다.

Sisyphus의 질문에 직접 답하면 다음과 같다.

1. **batt CLI 래핑은 기술 부채가 되는가?**
   그대로 영구 채택하면 그렇다. 하지만 backend adapter 뒤에 숨기고 버전 pinning, health check, fallback 정책을 두면 감당 가능한 초기 부채다.

2. **CHWA의 80/100 제약이 핵심 기능과 충돌하는가?**
   현재 논의의 핵심 축이 아니다. 실제 동작하는 오픈소스들은 CHWA보다 `CH0B/CH0C/CHTE` 계열을 더 직접적으로 사용한다. 다만 제품 요구사항 자체가 80/100 스위칭이므로, Apple 공식 Charge Limit 시대에는 오히려 요구사항과 잘 맞는다.

3. **Tahoe 공식 Charge Limit가 나오면 앱 가치가 줄어드는가?**
   "충전 상한 설정"만 팔면 줄어든다. "요일별 정책 자동화"를 팔면 아직 남는다. 단, Apple이 Shortcuts나 스케줄링까지 붙이면 moat는 급격히 줄어든다.

4. **Swift vs Go vs 하이브리드?**
   제품은 Swift가 맞다. 메뉴바 UX, 권한 안내, 배포, SMAppService/XPC 구조가 macOS와 잘 맞는다. 다만 backend는 초기에 하이브리드여도 된다. 중요한 건 언어 통일이 아니라 backend 교체 가능성이다.

5. **SIP 비활성화 없이 가능한 범위는?**
   현재 공개 오픈소스들의 설치 흐름상 SIP off가 필수라는 근거는 못 찾았다. 필요한 것은 대체로 root 권한과 현재 firmware에서 살아 있는 SMC write path다. 그러나 이것은 공식 보장 경로가 아니므로, "SIP 없이도 된다"를 안정성 약속으로 읽으면 안 된다.

내 결론은 명확하다. 이 프로젝트는 **지금 시작해도 된다.** 하지만 전제는 두 가지다. 첫째, Sequoia에서의 성공을 `IOPMAssertion` 같은 공식성 있는 경로로 오해하지 말 것. 둘째, 아키텍처의 중심을 "SMC 직접 제어 구현"이 아니라 "교체 가능한 충전 백엔드 위에 놓인 스케줄 정책 엔진"으로 둘 것. 그 기준이라면 Phase 방식은 유효하다. 그 기준이 아니면, 첫 macOS point release에서 바로 무너질 가능성이 높다.

## Sources

- Apple Support: https://support.apple.com/en-us/102338
- Apple Developer IOPMAssertionTypes: https://developer.apple.com/documentation/iokit/iopmlib_h/iopmassertiontypes
- batt: https://github.com/charlie0129/batt
- battery: https://github.com/actuallymentor/battery
