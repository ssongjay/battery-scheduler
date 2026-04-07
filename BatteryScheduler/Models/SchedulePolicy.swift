import Foundation

struct SchedulePolicy: Codable {
    /// 요일별 충전 한도 (1=일요일, 2=월요일, ..., 7=토요일)
    var weekdayLimits: [Int: Int]

    /// 오늘만 override 활성화 여부
    var overrideUntilMidnight: Bool = false

    /// override 시 적용할 한도
    var overrideLimit: Int = 100

    static let `default` = SchedulePolicy(
        weekdayLimits: [
            1: 80,  // 일
            2: 100, // 월
            3: 80,  // 화
            4: 100, // 수
            5: 100, // 목
            6: 100, // 금
            7: 80   // 토
        ]
    )

    func limitForToday() -> Int {
        if overrideUntilMidnight {
            return overrideLimit
        }
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekdayLimits[weekday] ?? 100
    }

    func nextTransition() -> (date: Date, limit: Int)? {
        let cal = Calendar.current
        let now = Date()
        let currentLimit = limitForToday()

        // 오늘 자정 (override 만료 시)
        if overrideUntilMidnight {
            if let midnight = cal.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) {
                let weekday = cal.component(.weekday, from: midnight)
                let nextLimit = weekdayLimits[weekday] ?? 100
                return (midnight, nextLimit)
            }
        }

        // 다음 7일 중 limit이 바뀌는 첫 날
        for dayOffset in 1...7 {
            guard let futureDate = cal.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let futureWeekday = cal.component(.weekday, from: futureDate)
            let futureLimit = weekdayLimits[futureWeekday] ?? 100
            if futureLimit != currentLimit {
                let midnight = cal.startOfDay(for: futureDate)
                return (midnight, futureLimit)
            }
        }
        return nil
    }

    /// 요일 이름 (한국어 짧은 형태)
    static func weekdayName(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "일"
        case 2: return "월"
        case 3: return "화"
        case 4: return "수"
        case 5: return "목"
        case 6: return "금"
        case 7: return "토"
        default: return "?"
        }
    }
}
