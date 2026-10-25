import AppIntents
import UserNotifications
import WidgetKit

/// 위젯 체크박스: 할 일 완료 / 완료 취소
struct ToggleTodoIntent: AppIntent {
    static let title: LocalizedStringResource = "할 일 완료 전환"
    static let isDiscoverable = false

    @Parameter(title: "할 일 ID")
    var todoID: String

    init() {}
    init(todoID: UUID) { self.todoID = todoID.uuidString }

    func perform() async throws -> some IntentResult {
        guard var data = SharedStorage.readData(),
              let id = UUID(uuidString: todoID),
              let i = data.todos.firstIndex(where: { $0.id == id }) else { return .result() }
        data.todos[i].isDone.toggle()
        data.todos[i].doneAt = data.todos[i].isDone ? Date() : nil
        try SharedStorage.write(data, to: SharedStorage.dataURL)
        SharedStorage.notifyAppOfWidgetChange()
        return .result()
    }
}

/// 위젯 ▶️ / ⏸ 버튼
struct ToggleTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "포모도로 시작 / 일시정지"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        try await TimerIntentSupport.update { st, settings in
            if st.isRunning { TimerLogic.pause(&st) } else { TimerLogic.start(&st, settings) }
        }
        return .result()
    }
}

/// 위젯 ⏭ 버튼
struct SkipTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "포모도로 건너뛰기"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        try await TimerIntentSupport.update { st, settings in
            TimerLogic.skip(&st, settings)
        }
        return .result()
    }
}

enum TimerIntentSupport {
    static let notificationID = "pomodoro.end"

    /// 끝난 세션을 먼저 기록한 뒤 change를 적용하고, 종료 알림을 다시 예약한다.
    static func update(_ change: (inout TimerState, SharedSettings) -> Void) async throws {
        let settings = SharedStorage.readSettings()
        var st = SharedStorage.readTimer() ?? TimerState()
        var data = SharedStorage.readData() ?? AppData()
        if TimerLogic.settle(&st, data: &data, settings) != nil {
            try SharedStorage.write(data, to: SharedStorage.dataURL)
        }
        change(&st, settings)
        try SharedStorage.write(st, to: SharedStorage.timerURL)

        // 앱이 켜져 있으면 앱이 다시 예약하지만, 꺼져 있을 때를 위해 여기서도 예약한다
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
        if let end = st.endDate, st.isRunning {
            let content = UNMutableNotificationContent()
            content.title = st.kind == .focus ? "집중 끝! 🎉" : "휴식 끝"
            content.body = st.kind == .focus ? "수고했어요. 잠깐 쉬어 가요." : "다시 집중할 시간이에요."
            content.sound = .default
            content.categoryIdentifier = "POMODORO_END"
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, end.timeIntervalSinceNow), repeats: false)
            try? await center.add(UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger))
        }
        SharedStorage.notifyAppOfWidgetChange()
    }
}
