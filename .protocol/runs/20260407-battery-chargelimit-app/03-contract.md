# Contract

## Goal

macOS 26.4의 공식 Charge Limit 기능을 프로그래밍적으로 제어하여, 요일별로 배터리 충전 상한을 자동 전환하는 SwiftUI 메뉴바 앱을 만든다.

- 토/일/화 → 80%, 월/수/목/금 → 100% 자동 전환
- "오늘만 100%" 일회성 override
- 현재 정책, 다음 전환 시각 표시

## Non-Goals

- AlDente의 모든 기능 복제 (Discharge, Heat Protection 등)
- SMC 직접 접근 (CH0B, CHWA 등)
- batt/battery CLI 래핑
- App Store 배포
- Intel Mac 지원
- macOS 26.3 이하 지원

## Files In Scope

```
BatteryScheduler/
├── BatterySchedulerApp.swift          # @main, MenuBarExtra 진입점
├── Models/
│   ├── ChargePolicy.swift             # ChargeCtrlPolicy NSCoding 모델
│   ├── SchedulePolicy.swift           # 요일별 스케줄 정의
│   └── AppState.swift                 # 앱 상태 관리 (ObservableObject)
├── Services/
│   ├── ChargeLimitService.swift       # plist 읽기/쓰기 + powerd reload
│   └── SchedulerService.swift         # Timer 기반 요일별 자동 전환
├── Views/
│   ├── MenuBarView.swift              # 메뉴바 드롭다운 UI
│   └── ScheduleConfigView.swift       # 요일별 설정 뷰 (선택)
├── Info.plist                         # LSUIElement = YES
└── BatteryScheduler.entitlements
```

## Structural Constraints

1. **plist 경로**: `/Library/Preferences/com.apple.powerd.charging.plist`
2. **직렬화 포맷**: NSKeyedArchiver, className = `ChargeCtrlPolicy`
3. **ChargeCtrlPolicy 필드**:
   - `reason: String` ("manualChargeLimit")
   - `owner: Int` (177 = 시스템 설정에서 설정한 값)
   - `soclimit: Int` (80, 85, 90, 95, 100)
   - `drain: Bool` (true)
   - `terminated: Bool` (false)
   - `noChargeToFull: Bool` (false)
   - `isEndOfCharge: Bool` (true)
   - `token: UUID`
4. **plist 쓰기 후** `pmset touch` 또는 powerd에 reload 신호 필요 (검증 필요)
5. **root 권한 필요**: plist가 `/Library/Preferences/`에 있으므로 sudo 필요
6. **MenuBarExtra**: `.window` 스타일, macOS 13+
7. **LSUIElement**: YES (Dock 아이콘 숨김)

## Forbidden Approaches

1. SMC 키 직접 접근 (IOKit AppleSMC)
2. batt/battery CLI 래핑
3. Shortcuts 앱 의존 (Set Charge Limit 액션 미존재 확인됨)
4. SIP 비활성화 요구
5. 커널 확장/DriverKit
6. NSKeyedArchiver 대신 plist 바이너리 직접 조작

## Acceptance Criteria

1. 앱 실행 시 메뉴바에 배터리 아이콘 표시
2. 현재 Charge Limit 값을 `pmset -g battlimit`에서 읽어 표시
3. 80% / 100% 수동 전환 버튼 동작 → `pmset -g battlimit` 출력 변경 확인
4. 요일별 자동 전환: 토/일/화에는 80%, 나머지에는 100%
5. "오늘만 100%" 클릭 시 자정까지 100%, 자정 이후 원래 스케줄 복귀
6. 앱 재시작 / 로그인 시 자동 실행 (LaunchAgent)
7. 현재 정책, 다음 전환 시각 표시

## Verification Plan

1. `swift build` 성공
2. 앱 실행 후 메뉴바 아이콘 확인
3. 80% 설정 → `pmset -g battlimit` 출력에 `chargeSocLimitSoc = 80` 확인
4. 100% 설정 → `pmset -g battlimit` 출력에 `No battery level limits set` 또는 `chargeSocLimitSoc = 100` 확인
5. 요일별 전환: Timer fire 시 올바른 값 설정 확인 (로그)
6. "오늘만 100%" 후 자정 경과 시 원래 스케줄 복귀 확인
