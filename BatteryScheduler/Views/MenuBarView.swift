import SwiftUI

struct MenuBarView: View {
    @ObservedObject var scheduler: SchedulerService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 현재 상태
            statusSection

            Divider()

            // 빠른 설정
            quickActionsSection

            Divider()

            // 요일별 스케줄 표시
            scheduleSection

            Divider()

            // 다음 전환
            if let next = scheduler.policy.nextTransition() {
                nextTransitionSection(next)
                Divider()
            }

            // 에러 표시
            if let error = scheduler.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
                Divider()
            }

            Button("종료") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(8)
        .frame(width: 280)
    }

    // MARK: - Sections

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "battery.100.bolt")
                    .foregroundStyle(.green)
                Text("충전 한도")
                    .font(.headline)
                Spacer()
                if scheduler.isApplying {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            HStack {
                if let limit = scheduler.currentLimit {
                    Text("현재: \(limit)%")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                } else {
                    Text("확인 중...")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if scheduler.manualOverrideActive {
                    Text("수동")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.2))
                        .clipShape(Capsule())
                } else if scheduler.policy.overrideUntilMidnight {
                    Text("오늘만 \(scheduler.policy.overrideLimit)%")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("빠른 설정")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach([80, 85, 90, 95, 100], id: \.self) { value in
                    Button("\(value)%") {
                        Task { await scheduler.applyLimit(value, manual: true) }
                    }
                    .buttonStyle(.bordered)
                    .tint(scheduler.currentLimit == value ? .accentColor : nil)
                    .controlSize(.small)
                }
            }

            if scheduler.manualOverrideActive {
                Button("스케줄 복귀") {
                    scheduler.clearManualOverride()
                }
                .controlSize(.small)
                .tint(.orange)
            }

            if !scheduler.policy.overrideUntilMidnight {
                Button("오늘만 100%") {
                    scheduler.enableOverride()
                }
                .controlSize(.small)
            } else {
                Button("오늘만 100% 취소") {
                    scheduler.cancelOverride()
                }
                .controlSize(.small)
                .tint(.orange)
            }
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("주간 스케줄")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                ForEach(1...7, id: \.self) { weekday in
                    let limit = scheduler.policy.weekdayLimits[weekday] ?? 100
                    let isToday = Calendar.current.component(.weekday, from: Date()) == weekday
                    Menu {
                        ForEach([80, 85, 90, 95, 100], id: \.self) { value in
                            Button {
                                scheduler.policy.weekdayLimits[weekday] = value
                            } label: {
                                HStack {
                                    Text("\(value)%")
                                    if value == limit {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Text(SchedulePolicy.weekdayName(weekday))
                                .font(.caption2)
                                .fontWeight(isToday ? .bold : .regular)
                            Text("\(limit)")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(limit <= 85 ? .orange : .green)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(isToday ? Color.accentColor.opacity(0.1) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .menuStyle(.borderlessButton)
                }
            }
        }
    }

    private func nextTransitionSection(_ next: (date: Date, limit: Int)) -> some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(.secondary)
            Text("다음 전환")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(next.limit)% → \(next.date.formatted(.relative(presentation: .named)))")
                .font(.caption)
        }
    }
}
