import AppKit
import Observation
import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case todo, routine, diary, pomodoro, calendar, settings
    var id: String { rawValue }

    var label: String {
        switch self {
        case .todo: "투두"
        case .routine: "루틴"
        case .diary: "일기"
        case .pomodoro: "포모도로"
        case .calendar: "캘린더"
        case .settings: "설정"
        }
    }

    var symbol: String {
        switch self {
        case .todo: "checklist"
        case .routine: "repeat"
        case .diary: "book.closed"
        case .pomodoro: "timer"
        case .calendar: "calendar"
        case .settings: "gearshape"
        }
    }
}

/// 화면 간 이동 상태 (캘린더 → 투두 이동, 단축키 등)
@Observable
final class Router {
    static let shared = Router()
    var tab: AppTab = AppTab(rawValue: UserDefaults.standard.string(forKey: Keys.startTab) ?? "") ?? .todo
    var todoDate = Date().startOfDay
    /// 값이 바뀌면 투두 화면이 첫 목표의 입력창을 연다 (⌘N)
    var newTodoRequest = 0

    var calendarDate = Date().startOfDay

    func openTodos(on date: Date) {
        todoDate = date.startOfDay
        tab = .todo
    }

    /// 위젯 딥 링크: alphacenter://todo?date=2026-10-20, alphacenter://calendar?date=…, alphacenter://pomodoro
    func handle(_ url: URL) {
        guard url.scheme == SharedStorage.urlScheme else { return }
        let dateText = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "date" }?.value
        let date = dateText.flatMap(Self.parseDate) ?? Date()
        switch url.host() {
        case "todo": openTodos(on: date)
        case "calendar":
            calendarDate = date.startOfDay
            tab = .calendar
        case "pomodoro": tab = .pomodoro
        default: break
        }
    }

    private static func parseDate(_ text: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: text)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Defaults.exportSharedIfChanged()
        // 위젯에서 할 일을 체크하거나 타이머를 조작하면 파일을 다시 읽는다
        DistributedNotificationCenter.default().addObserver(forName: SharedStorage.widgetChanged, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                Store.shared.reloadFromDisk()
                TimerEngine.shared.reloadFromDisk()
            }
        }
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { Defaults.exportSharedIfChanged() }
        }
        Store.shared.carryOverIfNeeded()
        NotificationManager.shared.rescheduleReminders(store: Store.shared)
        // 자정이 지나면 이월·루틴을 다시 확인한다
        NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                Store.shared.carryOverIfNeeded()
                Store.shared.materializeRoutines(for: Date())
            }
        }
        #if DEBUG
        DebugSnapshot.runIfRequested()
        #endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        Store.shared.saveNow()
    }
}

@main
struct AlphaCenterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(Keys.showMenuBar) private var showMenuBar = true

    private let store: Store
    private let timer: TimerEngine
    private let router: Router

    init() {
        Defaults.register()
        Store.shared.load()
        FontManager.shared.setup()
        NotificationManager.shared.setup()
        TimerEngine.shared.restore()
        store = .shared
        timer = .shared
        router = .shared
    }

    var body: some Scene {
        Window(AppInfo.name, id: "main") {
            RootView()
                .environment(store)
                .environment(timer)
                .environment(router)
        }
        .defaultSize(width: 1120, height: 780)
        .windowToolbarStyle(.unified)
        .commands { AppCommands(router: router, timer: timer) }

        MenuBarExtra(isInserted: $showMenuBar) {
            MenuBarView()
                .environment(store)
                .environment(timer)
                .environment(router)
        } label: {
            MenuBarLabel(timer: timer)
        }
        .menuBarExtraStyle(.window)
    }
}

struct AppCommands: Commands {
    let router: Router
    let timer: TimerEngine

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("할 일 추가") {
                router.tab = .todo
                router.newTodoRequest += 1
            }
            .keyboardShortcut("n")
        }
        CommandMenu("이동") {
            ForEach(Array(AppTab.allCases.enumerated()), id: \.element) { i, tab in
                Button(tab.label) { router.tab = tab }
                    .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")))
            }
            Divider()
            Button("오늘로 이동") { router.openTodos(on: Date()) }
                .keyboardShortcut("t")
        }
        CommandMenu("타이머") {
            Button(timer.state.isRunning ? "일시정지" : "시작") { timer.toggle() }
                .keyboardShortcut(.space, modifiers: [.command, .shift])
            Button("건너뛰기") { timer.skip() }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .shift])
            Button("재설정") { timer.reset() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
        }
    }
}

struct RootView: View {
    @Environment(Router.self) private var router
    @AppStorage(Keys.accentIndex) private var accentIndex = Palette.defaultAccent
    @State private var fonts = FontManager.shared

    var body: some View {
        @Bindable var router = router
        NavigationSplitView {
            List(selection: Binding(get: { router.tab }, set: { if let t = $0 { router.tab = t } })) {
                Section(AppInfo.shortName) {
                    ForEach(AppTab.allCases) { tab in
                        Label(tab.label, systemImage: tab.symbol)
                            .appFont(14, .medium)
                            .tag(tab)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
            .safeAreaInset(edge: .bottom) { SidebarTimerBadge().padding(12) }
        } detail: {
            Group {
                switch router.tab {
                case .todo: TodoView()
                case .routine: RoutineView()
                case .diary: DiaryView()
                case .pomodoro: PomodoroView()
                case .calendar: CalendarView()
                case .settings: SettingsView()
                }
            }
            .frame(minWidth: 640, minHeight: 520)
            .background(DS.bg)
        }
        .environment(\.appFontResolver, .app)
        .environment(\.dsAccent, Palette.color(accentIndex))
        .tint(Palette.color(accentIndex))
        .accentColor(Palette.color(accentIndex))
        .id("\(fonts.selected.rawValue)-\(fonts.scale)-\(fonts.weightShift)") // 서체·글자 크기 변경 시 전체 다시 그리기
        .onOpenURL { router.handle($0) }
    }
}

/// 사이드바 하단의 작은 타이머 표시
struct SidebarTimerBadge: View {
    @Environment(TimerEngine.self) private var timer
    @Environment(Router.self) private var router

    var body: some View {
        if !timer.state.isIdle {
            Button {
                router.tab = .pomodoro
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: timer.state.kind.symbol)
                    Text(timer.remaining.clockText).monospacedDigit()
                    Spacer()
                    Image(systemName: timer.state.isRunning ? "pause.fill" : "play.fill")
                        .onTapGesture { timer.toggle() }
                }
                .appFont(13, .medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.tint(Palette.color(for: timer.state.kind).opacity(0.2)).interactive(), in: .capsule)
        }
    }
}
