# Brief

## Request

macOS 메뉴바 배터리 관리 앱 개발. AlDente와 유사하게 SMC를 통해 배터리 충전 상한을 제어하되, 요일별 자동 스케줄링(토/일/화 → 80%, 나머지 → 100%) 기능을 핵심으로 한다.

## Intent

- `discussion_only`

## Starter

- `sisyphus`

## Problem Statement

MacBook 배터리 수명 관리를 위해 충전 상한을 요일별로 자동 전환하는 macOS 메뉴바 앱을 만들려 한다. 기존 AlDente는 유료(Pro)이고 스케줄링 기능이 없으며, bclm 등 CLI 도구는 macOS Sequoia에서 동작하지 않는다.

## Technical Context (조사 결과)

### SMC 접근 현황
- **Intel**: `BCLM` 키 (0-100 범위), IOKit 직접 접근 가능
- **Apple Silicon**: `CHWA` 키 (80 또는 100만 가능)
- **macOS Sequoia 15.x**: SMC 배터리 키에 entitlement 강제 적용 → bclm, 일반 Privileged Helper 동작 불가
- **macOS Tahoe 26.4+**: Apple 공식 Charge Limit 기능 추가 (80-100%), 공개 API 미확인

### 동작하는 오픈소스
- **charlie0129/batt** (Stars 1.5k): Apple Silicon 전용, Sequoia까지 지원, Go 작성
- **actuallymentor/battery** (Stars 6.9k): CLI/GUI, 활발 업데이트, Shell/Swift 혼합

### 앱 아키텍처 스택
- SwiftUI MenuBarExtra (macOS 13+)
- SMAppService + LaunchDaemon + XPC (SMJobBless deprecated)
- Developer ID 서명 + Notarization (App Store 배포 불가)

## Discussion Topics

1. **Sequoia entitlement 문제 우회**: batt/battery가 어떻게 Sequoia에서 동작하는지 — SIP 비활성화 필수인지, 다른 방법이 있는지
2. **Apple Silicon 제약 (80 or 100 only)**: CHWA 키는 80/100만 가능 — 세밀한 값 설정이 불가능한데, 이게 앱 가치에 문제가 되는지
3. **macOS Tahoe Charge Limit**: Apple 공식 기능이 나오는 상황에서 자체 앱 개발이 의미가 있는지
4. **개발 전략**: Swift 순수 구현 vs batt/battery 래핑 vs Apple 공식 API 대기
5. **MVP 범위**: 최소한 어떤 기능부터 만들어야 하는지

## Change Targets

- N/A (discussion_only)

## Non-Goals

- Windows/Linux 지원
- App Store 배포
- AlDente의 모든 기능 복제 (Discharge, Heat Protection 등)

## Constraints

- macOS 13+ (Ventura 이상)
- Apple Silicon 우선 (Intel 지원은 선택)
- Swift/SwiftUI 사용
- 관리자 권한(root) 필요

## Relevant Files / Docs

- [charlie0129/batt](https://github.com/charlie0129/batt) — Sequoia 지원 배터리 관리 도구
- [actuallymentor/battery](https://github.com/actuallymentor/battery) — 인기 배터리 CLI/GUI
- [beltex/SMCKit](https://github.com/beltex/SMCKit) — Swift SMC 라이브러리
- [alienator88/HelperToolApp](https://github.com/alienator88/HelperToolApp) — SMAppService 예제
- [Apple Support: Charge Limit](https://support.apple.com/en-us/102338)
