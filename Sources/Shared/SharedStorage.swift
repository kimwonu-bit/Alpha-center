import Foundation

/// 앱과 위젯이 함께 읽고 쓰는 파일들.
/// 위젯은 샌드박스라 홈 경로가 컨테이너로 바뀌므로, 실제 홈 디렉터리를 기준으로 경로를 만든다.
nonisolated enum SharedStorage {
    static let appBundleID = "kr.hs.bssm.alphacenter"
    /// 위젯이 데이터를 바꿨을 때 앱에 알리는 분산 알림
    static let widgetChanged = Notification.Name("kr.hs.bssm.alphacenter.widgetChanged")
    static let urlScheme = "alphacenter"

    static var realHome: URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    static var directory: URL {
        realHome.appendingPathComponent("Library/Application Support/AlphaCenter", isDirectory: true)
    }
    static var dataURL: URL { directory.appendingPathComponent("data.json") }
    static var timerURL: URL { directory.appendingPathComponent("timer.json") }
    static var settingsURL: URL { directory.appendingPathComponent("settings.json") }
    static var fontsDirectory: URL { directory.appendingPathComponent("Fonts", isDirectory: true) }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static func read<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let raw = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(type, from: raw)
    }

    static func write<T: Encodable>(_ value: T, to url: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try encoder.encode(value).write(to: url, options: .atomic)
    }

    static func readData() -> AppData? { read(AppData.self, from: dataURL) }
    static func readTimer() -> TimerState? { read(TimerState.self, from: timerURL) }
    static func readSettings() -> SharedSettings { read(SharedSettings.self, from: settingsURL) ?? SharedSettings() }

    static func notifyAppOfWidgetChange() {
        DistributedNotificationCenter.default().postNotificationName(widgetChanged, object: nil, userInfo: nil, deliverImmediately: true)
    }
}

/// 위젯이 알아야 하는 앱 설정. 앱이 바뀔 때마다 settings.json으로 내보낸다.
nonisolated struct SharedSettings: Codable, Equatable, Sendable {
    var focusMinutes = 25
    var shortBreakMinutes = 5
    var longBreakMinutes = 15
    var longBreakInterval = 4
    var weekStartsOnMonday = false
    var fontOption = FontOption.system.rawValue
    var accentIndex = Palette.defaultAccent

    var font: FontOption { FontOption(rawValue: fontOption) ?? .system }
    var calendar: Calendar { .alpha(mondayFirst: weekStartsOnMonday) }
}
