# BatteryScheduler

macOS 메뉴바 앱으로, 요일별 배터리 충전 한도를 자동으로 전환합니다.

macOS 26.4(Tahoe)의 공식 Charge Limit 기능을 macOS 내부 PowerUI API로 제어합니다.

![BatteryScheduler 메뉴바 패널](docs/screenshot_panel.png)

## 기능

- **요일별 자동 전환**: 토/일/화 → 80%, 월/수/목/금 → 100%
- **수동 설정**: 80% / 85% / 90% / 95% / 100% 빠른 전환
- **오늘만 100%**: 자정까지 일회성 override, 자정 이후 스케줄 복귀
- **상태 표시**: 현재 충전 한도, 다음 전환 시각, 주간 스케줄 시각화
- **메뉴바 전용**: Dock에 표시되지 않음 (LSUIElement)

## 요구 사항

- macOS 26.4 (Tahoe) 이상
- Apple Silicon Mac
- macOS 내부 PowerUI 수동 충전 한도 API 사용
- PowerUI 직접 호출 실패 시 Shortcuts 또는 접근성(Accessibility) fallback 사용

## 동작 원리

macOS 26.4에 추가된 공식 Charge Limit 기능을 먼저 PowerUI의 수동 충전 한도 클라이언트로 직접 설정합니다. 이 경로는 시스템 설정 창을 열지 않습니다.

PowerUI 직접 호출이 실패하면 Shortcuts 단축어를 시도하고, 단축어도 없으면 기존 방식대로 시스템 설정의 슬라이더를 AppleScript(Accessibility API)로 자동 조작합니다.

```
앱 → PowerUI.framework / PowerUISmartChargeClient
     → setMCLLimit:error:
     → pmset -g battlimit 으로 현재 상태 검증

fallback 1:
앱 → shortcuts run "BatteryScheduler Set 80/85/90/95/100"
     → pmset -g battlimit 으로 현재 상태 검증

fallback 2:
앱 → AppleScript → System Events → 시스템 설정 Charge Limit 슬라이더 조작
     → pmset -g battlimit 으로 현재 상태 읽기
```

### Shortcuts 설정

PowerUI 직접 호출이 동작하지 않는 macOS 업데이트에 대비하려면 Shortcuts 앱에서 아래 이름의 단축어 5개를 만들어 둘 수 있습니다.

| 단축어 이름 | 액션 |
|-------------|------|
| `BatteryScheduler Set 80` | Set Battery Charge Limit → 80% |
| `BatteryScheduler Set 85` | Set Battery Charge Limit → 85% |
| `BatteryScheduler Set 90` | Set Battery Charge Limit → 90% |
| `BatteryScheduler Set 95` | Set Battery Charge Limit → 95% |
| `BatteryScheduler Set 100` | Set Battery Charge Limit → 100% |

앱은 PowerUI 직접 호출이 실패하고 해당 단축어가 있으면 `/usr/bin/shortcuts run`으로 실행합니다. 이 경로도 시스템 설정 창을 열지 않습니다.

### 왜 이 방식인가?

| 방법 | 가능 여부 | 이유 |
|------|----------|------|
| `pmset` setter | 불가 | 공식 setter 미제공 (getter만 존재) |
| **PowerUI private API** | **가능** | `PowerUISmartChargeClient.setMCLLimit:error:` 직접 호출 |
| IOPSLimitBatteryLevel API | 불가 | `com.apple.private.powerd.chargeCtrlQ` private entitlement 필요 |
| plist 직접 수정 | 불가 | powerd reload 방법 없음 (SIP가 차단) |
| Shortcuts 액션 | fallback | 단축어를 미리 만들어 둔 경우 실행 가능 |
| **Accessibility API** | **fallback** | 단축어가 없을 때 시스템 설정 UI를 자동 조작 |

## 빌드 및 실행

```bash
cd BatteryScheduler
swift build
.build/debug/BatteryScheduler
```

앱 번들로 빌드/실행하려면:

```bash
./scripts/run-app.sh
```

생성된 앱은 `dist/BatteryScheduler.app`에 저장됩니다. `dist/`는 로컬 빌드 산출물이며 Git에는 커밋하지 않습니다. 레포에는 앱을 재생성할 수 있는 Swift 소스와 `scripts/build-app.sh`, `scripts/run-app.sh`만 커밋합니다.

앱 번들만 만들고 실행하지 않으려면:

```bash
./scripts/build-app.sh
```

PowerUI 직접 호출 경로는 접근성 권한이 필요 없습니다. AppleScript fallback이 실행되는 경우에만 **시스템 설정 > 개인정보 보호 및 보안 > 접근성**에서 터미널(또는 앱)을 허용해야 합니다.

## 프로젝트 구조

```
BatteryScheduler/
├── Package.swift
├── BatterySchedulerApp.swift          # @main, MenuBarExtra 진입점
├── Models/
│   └── SchedulePolicy.swift           # 요일별 스케줄 정의
├── Services/
│   ├── ChargeLimitService.swift       # PowerUI/Shortcuts/AppleScript로 Charge Limit 제어
│   └── SchedulerService.swift         # Timer 기반 자동 전환 스케줄러
└── Views/
    └── MenuBarView.swift              # 메뉴바 드롭다운 UI
scripts/
├── build-app.sh                       # release 빌드 후 dist/BatteryScheduler.app 생성
└── run-app.sh                         # 앱 번들 생성 후 실행
dist/
└── BatteryScheduler.app               # 로컬 빌드 산출물 (Git 커밋 제외)
```

## 제한 사항

- PowerUI private API는 macOS 내부 API이므로 향후 macOS 업데이트에서 변경될 수 있음
- PowerUI/Shortcuts fallback이 모두 실패한 경우 충전 한도 변경 시 시스템 설정이 잠깐 열렸다 닫힘 (~8초 소요)
- AppleScript fallback에서 100%로 설정 시 macOS 확인 알럿이 표시됨 (자동 처리)
- AppleScript fallback은 macOS UI 구조 변경 시 경로 업데이트 필요
- macOS 26.4 미만 버전 미지원

## 라이선스

MIT
