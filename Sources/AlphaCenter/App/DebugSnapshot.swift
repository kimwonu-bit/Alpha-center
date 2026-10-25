#if DEBUG
import AppKit
import SwiftUI

/// 개발용: ALPHA_SNAPSHOT_DIR 환경 변수가 있으면 각 탭 화면을 PNG로 저장하고 종료한다.
/// (ALPHA_SNAPSHOT_DARK가 있으면 다크 모드로 그린다. Glass 효과는 오프스크린에서 다르게 보일 수 있다)
enum DebugSnapshot {
    static func runIfRequested() {
        guard let dir = ProcessInfo.processInfo.environment["ALPHA_SNAPSHOT_DIR"] else { return }
        Task {
            try? await Task.sleep(for: .seconds(1))
            // ALPHA_SNAPSHOT_DATE=2026-10-20 처럼 주면 그 날짜로 그린다
            if let text = ProcessInfo.processInfo.environment["ALPHA_SNAPSHOT_DATE"],
               let url = URL(string: "\(SharedStorage.urlScheme)://todo?date=\(text)") {
                Router.shared.handle(url)
                Router.shared.calendarDate = Router.shared.todoDate
            }
            for tab in AppTab.allCases {
                let view = Group {
                    switch tab {
                    case .todo: TodoView()
                    case .routine: RoutineView()
                    case .pomodoro: PomodoroView()
                    case .calendar: CalendarView()
                    case .settings: SettingsView()
                    }
                }
                .frame(width: 900, height: 780)
                .background(DS.bg)
                .environment(\.appFontResolver, .app)
                .environment(Store.shared)
                .environment(TimerEngine.shared)
                .environment(Router.shared)
                .tint(Palette.color(Palette.defaultAccent))
                // ScrollView는 ImageRenderer로 그려지지 않아서 실제 창에 올린 뒤 비트맵으로 뜬다
                let host = NSHostingView(rootView: view)
                host.frame = NSRect(x: 0, y: 0, width: 900, height: 780)
                let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
                window.appearance = NSAppearance(named: ProcessInfo.processInfo.environment["ALPHA_SNAPSHOT_DARK"] != nil ? .darkAqua : .aqua)
                window.contentView = host
                window.orderBack(nil)
                try? await Task.sleep(for: .milliseconds(800))
                guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { continue }
                host.cacheDisplay(in: host.bounds, to: rep)
                window.orderOut(nil)
                let url = URL(fileURLWithPath: dir).appendingPathComponent("\(tab.rawValue).png")
                try? rep.representation(using: .png, properties: [:])?.write(to: url)
            }
            NSApp.terminate(nil)
        }
    }
}
#endif
