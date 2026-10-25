import Foundation

// MARK: - 목표 / 할 일

nonisolated struct Goal: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var colorIndex: Int
    var icon: String
    var order: Int
    var isArchived = false
}

nonisolated struct Todo: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var title: String
    /// 그날의 시작 시각(startOfDay)으로 저장한다.
    var date: Date
    var isDone = false
    var doneAt: Date?
    var memo = ""
    var order: Int
    var goalID: UUID
    /// 루틴에서 생성된 인스턴스라면 원본 루틴과 생성 기준 날짜
    var routineID: UUID?
    var routineDate: Date?
    var reminderAt: Date?
    var pomodoroCount = 0
}

nonisolated enum RepeatFrequency: String, Codable, CaseIterable, Identifiable, Sendable {
    case none, daily, weekly, monthly, yearly
    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "반복 안 함"
        case .daily: "매일"
        case .weekly: "매주"
        case .monthly: "매월"
        case .yearly: "매년"
        }
    }
}

nonisolated struct RepeatRule: Codable, Hashable, Sendable {
    var frequency: RepeatFrequency
    /// 매주 반복일 때의 요일 (1 = 일요일 … 7 = 토요일)
    var weekdays: Set<Int> = []
    var endDate: Date?

    func matches(_ day: Date, start: Date, calendar cal: Calendar) -> Bool {
        let day = cal.startOfDay(for: day)
        let start = cal.startOfDay(for: start)
        guard day >= start else { return false }
        if let end = endDate, day > cal.startOfDay(for: end) { return false }
        switch frequency {
        case .none:
            return day == start
        case .daily:
            return true
        case .weekly:
            let wd = cal.component(.weekday, from: day)
            return weekdays.isEmpty ? wd == cal.component(.weekday, from: start) : weekdays.contains(wd)
        case .monthly:
            return cal.component(.day, from: day) == cal.component(.day, from: start)
        case .yearly:
            return cal.component(.day, from: day) == cal.component(.day, from: start)
                && cal.component(.month, from: day) == cal.component(.month, from: start)
        }
    }
}

/// 반복 할 일의 원본. 날짜를 열 때 규칙에 맞으면 Todo 인스턴스를 만든다.
nonisolated struct Routine: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var title: String
    var goalID: UUID
    var rule: RepeatRule
    var startDate: Date
    var memo = ""
    /// 사용자가 지운 인스턴스의 날짜 — 다시 만들지 않는다.
    var skippedDates: Set<Date> = []
}

// MARK: - 일정

nonisolated struct Event: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var title: String
    var start: Date
    var end: Date
    var isAllDay = false
    var colorIndex = 0
    var memo = ""
    var repeatFrequency: RepeatFrequency = .none
    /// 시작 N분 전 알림. nil이면 알림 없음
    var alertMinutes: Int?
    var isDday = false

    func occurs(on day: Date, calendar cal: Calendar) -> Bool {
        let day = cal.startOfDay(for: day)
        let startDay = cal.startOfDay(for: start)
        if repeatFrequency == .none {
            let endDay = cal.startOfDay(for: max(end, start))
            return day >= startDay && day <= endDay
        }
        return RepeatRule(frequency: repeatFrequency).matches(day, start: start, calendar: cal)
    }

    /// day에 발생하는 회차의 시작 시각
    func startTime(on day: Date, calendar cal: Calendar) -> Date {
        let comps = cal.dateComponents([.hour, .minute], from: start)
        return cal.date(bySettingHour: comps.hour ?? 0, minute: comps.minute ?? 0, second: 0, of: day) ?? day
    }

    /// 지금 이후 가장 가까운 회차의 시작 시각
    func nextOccurrence(after date: Date, calendar cal: Calendar, searchDays: Int = 400) -> Date? {
        if repeatFrequency == .none { return start >= date ? start : nil }
        var day = cal.startOfDay(for: date)
        for _ in 0..<searchDays {
            if occurs(on: day, calendar: cal) {
                let t = startTime(on: day, calendar: cal)
                if t >= date { return t }
            }
            day = cal.date(byAdding: .day, value: 1, to: day)!
        }
        return nil
    }
}

// MARK: - 포모도로

nonisolated enum SessionKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case focus, shortBreak, longBreak
    var id: String { rawValue }

    var label: String {
        switch self {
        case .focus: "집중"
        case .shortBreak: "짧은 휴식"
        case .longBreak: "긴 휴식"
        }
    }

    var symbol: String {
        switch self {
        case .focus: "brain.head.profile"
        case .shortBreak: "cup.and.saucer"
        case .longBreak: "sofa"
        }
    }
}

nonisolated struct PomodoroSession: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var kind: SessionKind
    var start: Date
    var duration: TimeInterval
    var completed: Bool
    var todoID: UUID?
}

/// 타이머 상태는 "남은 초"가 아니라 시작 시각 + 총 길이로 저장한다.
nonisolated struct TimerState: Codable, Equatable, Sendable {
    var kind: SessionKind = .focus
    var startedAt: Date?
    var duration: TimeInterval = 25 * 60
    var pausedRemaining: TimeInterval?
    /// 현재 사이클에서 완료한 집중 횟수
    var cycleCount = 0
    var isExtension = false
    var todoID: UUID?

    var isRunning: Bool { startedAt != nil }
    var isPaused: Bool { startedAt == nil && pausedRemaining != nil }
    var isIdle: Bool { startedAt == nil && pausedRemaining == nil }
    var endDate: Date? { startedAt.map { $0.addingTimeInterval(duration) } }

    func remaining(at now: Date) -> TimeInterval {
        if let startedAt { return max(0, duration - now.timeIntervalSince(startedAt)) }
        return pausedRemaining ?? duration
    }
}

// MARK: - 하루 회고

nonisolated struct DailyNote: Codable, Identifiable, Hashable, Sendable {
    var id: Date { date }
    var date: Date
    var text = ""
    var mood = ""
}

// MARK: - 저장 파일

nonisolated struct AppData: Codable, Sendable {
    var version = 1
    var goals: [Goal] = []
    var todos: [Todo] = []
    var routines: [Routine] = []
    var events: [Event] = []
    var sessions: [PomodoroSession] = []
    var notes: [DailyNote] = []
}
