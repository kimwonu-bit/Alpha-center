import AppKit
import Observation
import UserNotifications

@Observable
final class NotificationManager: NSObject {
    static let shared = NotificationManager()

    nonisolated enum ID {
        static let pomodoro = "pomodoro.end"
        static let category = "POMODORO_END"
        static let startBreak = "START_BREAK"
        static let startFocus = "START_FOCUS"
        static let extend = "EXTEND_5"
        static let todoPrefix = "todo."
        static let eventPrefix = "event."
    }

    private(set) var status: UNAuthorizationStatus = .notDetermined
    var isAuthorized: Bool { status == .authorized || status == .provisional }

    private var center: UNUserNotificationCenter { .current() }

    func setup() {
        center.delegate = self
        let actions = [
            UNNotificationAction(identifier: ID.startBreak, title: "휴식 시작"),
            UNNotificationAction(identifier: ID.startFocus, title: "다음 집중 시작"),
            UNNotificationAction(identifier: ID.extend, title: "5분 연장"),
        ]
        center.setNotificationCategories([
            UNNotificationCategory(identifier: ID.category, actions: actions, intentIdentifiers: []),
        ])
        Task { await requestAuthorization() }
    }

    func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        await refreshStatus()
    }

    func refreshStatus() async {
        status = await center.notificationSettings().authorizationStatus
    }

    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: 포모도로

    func schedulePomodoroEnd(at date: Date, kind: SessionKind) {
        cancelPomodoro()
        let content = UNMutableNotificationContent()
        switch kind {
        case .focus:
            content.title = "집중 끝! 🎉"
            content.body = "수고했어요. 잠깐 쉬어 가요."
        case .shortBreak, .longBreak:
            content.title = "휴식 끝"
            content.body = "다시 집중할 시간이에요."
        }
        content.sound = soundForNotification()
        content.categoryIdentifier = ID.category
        content.interruptionLevel = .timeSensitive
        let interval = max(1, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.add(UNNotificationRequest(identifier: ID.pomodoro, content: content, trigger: trigger))
    }

    func cancelPomodoro() {
        center.removePendingNotificationRequests(withIdentifiers: [ID.pomodoro])
    }

    /// 앱이 켜져 있으면 선택한 사운드를 앱이 직접 재생하고,
    /// 앱이 꺼져 있을 때만 시스템 기본 알림음이 울린다.
    private func soundForNotification() -> UNNotificationSound { .default }

    func sendTest() {
        let content = UNMutableNotificationContent()
        content.title = AppInfo.name
        content.body = "테스트 알림이에요. 잘 보이나요?"
        content.sound = soundForNotification()
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        center.add(UNNotificationRequest(identifier: "test.\(UUID())", content: content, trigger: trigger))
    }

    // MARK: 할 일 / 일정 알림

    /// 앞으로 7일 안의 할 일·일정 알림을 다시 예약한다.
    func rescheduleReminders(store: Store) {
        let now = Date()
        let horizon = now.addingTimeInterval(7 * 86400)
        let cal = Calendar.app
        var requests: [UNNotificationRequest] = []

        for t in store.data.todos where !t.isDone {
            guard let at = t.reminderAt, at > now, at < horizon else { continue }
            let c = UNMutableNotificationContent()
            c.title = "할 일 알림"
            c.body = t.title
            c.sound = .default
            requests.append(request(id: ID.todoPrefix + t.id.uuidString, content: c, at: at))
        }

        for e in store.data.events {
            guard let minutes = e.alertMinutes else { continue }
            var day = cal.startOfDay(for: now)
            while day < horizon {
                if e.occurs(on: day, calendar: cal) {
                    let start = e.isAllDay
                        ? cal.date(bySettingHour: 9, minute: 0, second: 0, of: day)!
                        : e.startTime(on: day, calendar: cal)
                    let fire = start.addingTimeInterval(TimeInterval(-minutes * 60))
                    if fire > now {
                        let c = UNMutableNotificationContent()
                        c.title = e.title
                        c.body = minutes == 0 ? "지금 시작해요" : "\(Self.alertLabel(minutes)) 시작해요 · \(start.formatted("a h:mm"))"
                        c.sound = .default
                        requests.append(request(id: "\(ID.eventPrefix)\(e.id.uuidString).\(Int(day.timeIntervalSince1970))", content: c, at: fire))
                    }
                }
                day = cal.date(byAdding: .day, value: 1, to: day)!
            }
        }

        let prefixes = [ID.todoPrefix, ID.eventPrefix]
        Task {
            let pending = await center.pendingNotificationRequests()
            let stale = pending.map(\.identifier).filter { id in prefixes.contains { id.hasPrefix($0) } }
            center.removePendingNotificationRequests(withIdentifiers: stale)
            // macOS는 예약 알림 수에 제한이 있으므로 가까운 순으로 50개까지만
            let sorted = requests.sorted { fireDate($0) < fireDate($1) }.prefix(50)
            for r in sorted { try? await center.add(r) }
        }
    }

    private func request(id: String, content: UNNotificationContent, at date: Date) -> UNNotificationRequest {
        let comps = Calendar.app.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return UNNotificationRequest(identifier: id, content: content,
                                     trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
    }

    private func fireDate(_ r: UNNotificationRequest) -> Date {
        (r.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantFuture
    }

    static func alertLabel(_ minutes: Int) -> String {
        switch minutes {
        case 0: "정시"
        case 1440: "1일 전"
        case 60: "1시간 전"
        default: "\(minutes)분 전"
        }
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        notification.request.identifier == ID.pomodoro ? [.banner, .list] : [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let action = response.actionIdentifier
        await MainActor.run {
            TimerEngine.shared.handleNotificationAction(action)
        }
    }
}
