# BatteryScheduler

macOS 메뉴바 앱으로, 요일별 배터리 충전 한도를 자동으로 전환합니다.

macOS 26.4(Tahoe)의 공식 Charge Limit 기능을 Accessibility API를 통해 프로그래밍적으로 제어합니다.

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
- 접근성(Accessibility) 권한 허용 필요

## 동작 원리

macOS 26.4에 추가된 공식 Charge Limit 기능(시스템 설정 > 배터리 > 충전)의 슬라이더를 AppleScript(Accessibility API)로 자동 조작합니다.

```
앱 → AppleScript → System Events → 시스템 설정 Charge Limit 슬라이더 조작
     → pmset -g battlimit 으로 현재 상태 읽기
```

### 왜 이 방식인가?

| 방법 | 가능 여부 | 이유 |
|------|----------|------|
| `pmset` setter | 불가 | 공식 setter 미제공 (getter만 존재) |
| IOPSLimitBatteryLevel API | 불가 | `com.apple.private.powerd.chargeCtrlQ` private entitlement 필요 |
| plist 직접 수정 | 불가 | powerd reload 방법 없음 (SIP가 차단) |
| Shortcuts 액션 | 불가 | Set Charge Limit 액션 미존재 |
| **Accessibility API** | **가능** | 시스템 설정 UI를 자동 조작 |

## 빌드 및 실행

```bash
cd BatteryScheduler
swift build
.build/debug/BatteryScheduler
```

첫 실행 시 **시스템 설정 > 개인정보 보호 및 보안 > 접근성**에서 터미널(또는 앱)을 허용해야 합니다.

## 프로젝트 구조

```
BatteryScheduler/
├── Package.swift
├── BatterySchedulerApp.swift          # @main, MenuBarExtra 진입점
├── Models/
│   └── SchedulePolicy.swift           # 요일별 스케줄 정의
├── Services/
│   ├── ChargeLimitService.swift       # AppleScript로 Charge Limit 제어
│   └── SchedulerService.swift         # Timer 기반 자동 전환 스케줄러
└── Views/
    └── MenuBarView.swift              # 메뉴바 드롭다운 UI
```

## 제한 사항

- 충전 한도 변경 시 시스템 설정이 잠깐 열렸다 닫힘 (~8초 소요)
- 100%로 설정 시 macOS 확인 알럿이 표시됨 (자동 처리)
- macOS UI 구조 변경 시 AppleScript 경로 업데이트 필요
- macOS 26.4 미만 버전 미지원

## 라이선스

MIT
