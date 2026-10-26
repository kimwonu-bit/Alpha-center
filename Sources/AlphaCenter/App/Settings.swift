import SwiftUI

enum AppInfo {
    static let name = "코치조의 ALPHA 육성 센터"
    static let shortName = "ALPHA 센터"
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "개발 빌드"
    }
}

/// @AppStorage 키 모음
enum Keys {
    static let startTab = "startTab"
    static let showMenuBar = "showMenuBar"
    static let weekStartsOnMonday = "weekStartsOnMonday"
    static let autoCarryOver = "autoCarryOver"
    static let checkSound = "checkSound"
    static let focusMinutes = "focusMinutes"
    static let shortBreakMinutes = "shortBreakMinutes"
    static let longBreakMinutes = "longBreakMinutes"
    static let longBreakInterval = "longBreakInterval"
    static let autoStartBreak = "autoStartBreak"
    static let autoStartFocus = "autoStartFocus"
    static let soundName = "soundName"
    static let soundVolume = "soundVolume"
    static let fontOption = "fontOption"
    static let fontScale = "fontScale"
    static let fontWeightShift = "fontWeightShift"
    static let accentIndex = "accentIndex"
    static let todoTopMode = "todoTopMode"
    static let calendarMode = "calendarMode"
    static let didOnboard = "didOnboard"
}

enum Defaults {
    static func register() {
        UserDefaults.standard.register(defaults: [
            Keys.startTab: AppTab.todo.rawValue,
            Keys.showMenuBar: true,
            Keys.weekStartsOnMonday: false,
            Keys.autoCarryOver: false,
            Keys.checkSound: true,
            Keys.focusMinutes: 25,
            Keys.shortBreakMinutes: 5,
            Keys.longBreakMinutes: 15,
            Keys.longBreakInterval: 4,
            Keys.autoStartBreak: false,
            Keys.autoStartFocus: false,
            Keys.soundName: "Glass",
            Keys.soundVolume: 0.8,
            Keys.fontOption: FontOption.system.rawValue,
            Keys.accentIndex: Palette.defaultAccent,
        ])
    }

    static var d: UserDefaults { .standard }

    static func minutes(for kind: SessionKind) -> TimeInterval {
        TimerLogic.duration(for: kind, shared)
    }

    /// 위젯과 공유하는 설정 스냅샷
    static var shared: SharedSettings {
        SharedSettings(
            focusMinutes: d.integer(forKey: Keys.focusMinutes),
            shortBreakMinutes: d.integer(forKey: Keys.shortBreakMinutes),
            longBreakMinutes: d.integer(forKey: Keys.longBreakMinutes),
            longBreakInterval: d.integer(forKey: Keys.longBreakInterval),
            weekStartsOnMonday: d.bool(forKey: Keys.weekStartsOnMonday),
            fontOption: d.string(forKey: Keys.fontOption) ?? FontOption.system.rawValue,
            accentIndex: d.integer(forKey: Keys.accentIndex)
        )
    }

    /// 설정이 바뀌었으면 settings.json으로 내보내고 위젯을 갱신한다.
    static func exportSharedIfChanged() {
        let current = shared
        guard SharedStorage.read(SharedSettings.self, from: SharedStorage.settingsURL) != current else { return }
        try? SharedStorage.write(current, to: SharedStorage.settingsURL)
        WidgetReloader.reload()
    }
}

enum GoalIcons {
    static let all = [
        "book.closed", "pencil", "laptopcomputer", "chevron.left.forwardslash.chevron.right",
        "figure.run", "dumbbell", "heart", "leaf", "house", "cart", "briefcase", "graduationcap",
        "music.note", "paintbrush", "camera", "gamecontroller", "airplane", "star", "flame", "sparkles",
    ]
}

// MARK: - 날짜 도우미

extension Calendar {
    /// 주 시작 요일 설정을 반영한 한국어 달력
    static var app: Calendar { .alpha(mondayFirst: UserDefaults.standard.bool(forKey: Keys.weekStartsOnMonday)) }
}

extension Date {
    var startOfDay: Date { Calendar.app.startOfDay(for: self) }
    func adding(days: Int) -> Date { Calendar.app.date(byAdding: .day, value: days, to: self)! }
    func isSameDay(as other: Date) -> Bool { Calendar.app.isDate(self, inSameDayAs: other) }
}
