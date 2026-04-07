# Brief

## Request

macOS 26.4 공식 Charge Limit 기능의 plist를 프로그래밍적으로 제어하는 SwiftUI 메뉴바 앱. 요일별 자동 충전 상한 전환 (토/일/화 80%, 나머지 100%).

## Intent

- `implementation_bound`

## Starter

- `sisyphus`

## Problem Statement

macOS 26.4에 Charge Limit UI가 추가되었으나 프로그래밍적 제어 API가 없다. pmset getter만 존재하고 setter, Shortcuts 액션 모두 미제공. 리버스엔지니어링으로 `/Library/Preferences/com.apple.powerd.charging.plist`의 ChargeCtrlPolicy (NSKeyedArchiver) 구조를 파악 완료.

## Change Targets

- 새 Swift Package: `BatteryScheduler/`
- SwiftUI MenuBarExtra 앱
- ChargeCtrlPolicy NSCoding 인코더/디코더
- Timer 기반 요일별 스케줄러

## Non-Goals

- SMC 직접 접근, batt/battery CLI, Shortcuts, SIP 비활성화, Intel Mac, App Store

## Constraints

- macOS 26.4+ (Apple Silicon)
- root 권한 필요 (plist 쓰기)
- Swift/SwiftUI

## Relevant Files / Docs

- 선행 토론: `.protocol/runs/20260407-battery-menu-app/`
- 리버스엔지니어링 스크립트: `/tmp/decode_policy3.swift`, `/tmp/encode_policy.swift`
