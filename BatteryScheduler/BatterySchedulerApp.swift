import SwiftUI

@main
struct BatterySchedulerApp: App {
    @StateObject private var scheduler = SchedulerService()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(scheduler: scheduler)
        } label: {
            Label(menuBarTitle, systemImage: menuBarIcon)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarTitle: String {
        if let limit = scheduler.currentLimit, limit < 100 {
            return "\(limit)%"
        }
        return ""
    }

    private var menuBarIcon: String {
        guard let limit = scheduler.currentLimit else {
            return "battery.0"
        }
        if scheduler.policy.overrideUntilMidnight {
            return "battery.100.bolt"
        }
        return limit <= 80 ? "battery.75" : "battery.100"
    }
}
