# Oracle: Contract Review

## Context

macOS 26.4 배터리 충전 상한 자동 전환 메뉴바 앱의 구현 계약서를 검토해달라.

## 핵심 기술 발견 (토론 이후)

1. macOS 26.4에 공식 Charge Limit UI 추가 확인
2. 설정은 `/Library/Preferences/com.apple.powerd.charging.plist`에 NSKeyedArchiver로 저장
3. ChargeCtrlPolicy 구조 완전 디코딩 성공:
   - reason: "manualChargeLimit"
   - owner: 177 (시스템 설정)
   - soclimit: 80 (충전 상한 %)
   - drain, terminated, noChargeToFull, isEndOfCharge: Bool 플래그
   - token: UUID
4. NSKeyedArchiver round-trip (인코딩→디코딩) 성공 확인
5. pmset setter, Shortcuts 액션 모두 미존재 → plist 직접 제어가 유일한 프로그래밍 경로

## Contract

아래 파일을 읽고 검토하라:
- `.protocol/runs/20260407-battery-chargelimit-app/03-contract.md`

## 검토 포인트

1. **plist 쓰기 후 반영 메커니즘**: powerd가 plist 변경을 어떻게 감지하는지 — `pmset touch`로 충분한지, SIGHUP이 필요한지, 아니면 IOKit 알림이 필요한지
2. **owner 값의 의미**: 177은 시스템 설정 UI의 식별자인가? 우리 앱이 같은 값을 써야 하는가?
3. **root 권한 처리**: plist 쓰기에 sudo가 필요한데, GUI 앱에서 어떻게 처리할 것인가?
4. **Contract의 Acceptance Criteria가 충분한가?**
5. **빠진 리스크가 있는가?**

## 응답

Contract에 대한 평가와 수정 권고를 `.protocol/runs/20260407-battery-chargelimit-app/oracle/contract-review.md` 파일에 작성하라.

형식:
```markdown
# Oracle Contract Review

## Verdict: approve | hold | reject

## Findings
[항목별 검토]

## Required Changes (hold/reject 시)
[수정 필요 사항]
```
