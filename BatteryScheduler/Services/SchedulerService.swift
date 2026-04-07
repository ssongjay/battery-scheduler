import Foundation
import Combine

/// 요일별 자동 전환 스케줄러
@MainActor
final class SchedulerService: ObservableObject {
    @Published var policy: SchedulePolicy {
        didSet { savePolicy(); scheduleNextCheck() }
    }
    @Published var currentLimit: Int? = nil
    @Published var lastApplied: Date? = nil
    @Published var lastError: String? = nil
    @Published var isApplying: Bool = false

    /// 수동 설정 시 스케줄러가 덮어쓰지 않도록 하는 플래그
    @Published var manualOverrideActive: Bool = false
    private var manualOverrideLimit: Int? = nil

    private let chargeLimitService = ChargeLimitService()
    private var timer: Timer?
    private var midnightTimer: Timer?

    private static let policyKey = "BatteryScheduler.policy"

    init() {
        self.policy = Self.loadPolicy()
        refreshCurrentLimit()
        scheduleNextCheck()
    }

    /// 현재 스케줄에 따라 즉시 적용
    func applySchedule() {
        let target = policy.limitForToday()
        Task { await applyLimit(target) }
    }

    /// 특정 값으로 즉시 적용 (수동 = 스케줄 일시 중지)
    func applyLimit(_ percent: Int, manual: Bool = false) async {
        isApplying = true
        lastError = nil
        if manual {
            manualOverrideActive = true
            manualOverrideLimit = percent
        }
        do {
            try await chargeLimitService.setLimit(percent)
            lastApplied = Date()
            refreshCurrentLimit()
        } catch {
            lastError = error.localizedDescription
        }
        isApplying = false
    }

    /// 수동 override 해제 → 스케줄 복귀
    func clearManualOverride() {
        manualOverrideActive = false
        manualOverrideLimit = nil
        applySchedule()
    }

    /// "오늘만 100%" 활성화
    func enableOverride() {
        policy.overrideUntilMidnight = true
        policy.overrideLimit = 100
        applySchedule()
        scheduleMidnightReset()
    }

    /// Override 취소
    func cancelOverride() {
        policy.overrideUntilMidnight = false
        applySchedule()
        midnightTimer?.invalidate()
        midnightTimer = nil
    }

    func refreshCurrentLimit() {
        Task {
            let limit = await chargeLimitService.currentLimit()
            await MainActor.run { self.currentLimit = limit }
        }
    }

    // MARK: - Scheduling

    private func scheduleNextCheck() {
        timer?.invalidate()

        // 매 분마다 체크 (요일 전환 감지)
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAndApply()
            }
        }

        // override 활성화 상태면 자정 타이머도 설정
        if policy.overrideUntilMidnight {
            scheduleMidnightReset()
        }
    }

    private func checkAndApply() {
        // 수동 override 중이면 스케줄러가 간섭하지 않음
        if manualOverrideActive { return }

        let target = policy.limitForToday()
        refreshCurrentLimit()
        if target != currentLimit {
            applySchedule()
        }
    }

    private func scheduleMidnightReset() {
        midnightTimer?.invalidate()
        let cal = Calendar.current
        guard let midnight = cal.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0, second: 5),
            matchingPolicy: .nextTime
        ) else { return }

        let interval = midnight.timeIntervalSinceNow
        midnightTimer = Timer.scheduledTimer(withTimeInterval: max(1, interval), repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.policy.overrideUntilMidnight = false
                self?.applySchedule()
            }
        }
    }

    // MARK: - Persistence

    private func savePolicy() {
        if let data = try? JSONEncoder().encode(policy) {
            UserDefaults.standard.set(data, forKey: Self.policyKey)
        }
    }

    private static func loadPolicy() -> SchedulePolicy {
        guard let data = UserDefaults.standard.data(forKey: Self.policyKey),
              let policy = try? JSONDecoder().decode(SchedulePolicy.self, from: data) else {
            return .default
        }
        return policy
    }
}
