import SwiftUI
import WidgetKit

@main
struct AlphaWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayTodoWidget()
        PomodoroWidget()
        CalendarWidget()
    }
}

// MARK: - 타임라인

struct AlphaEntry: TimelineEntry {
    let date: Date
    let data: AppData
    let timer: TimerState
    let settings: SharedSettings
    /// 앱을 한 번도 실행하지 않아 데이터 파일이 없을 때
    var isMissingData = false

    var cal: Calendar { settings.calendar }
    var accent: Color { Palette.color(settings.accentIndex) }

    func font(_ size: CGFloat, _ weight: AppWeight = .regular) -> Font {
        FontCatalog.font(size: size, weight: weight, option: settings.font)
    }

    /// 공용 컴포넌트(DateNumber, EventBar 등)에 넘길 서체
    var fontResolver: AppFontResolver {
        let option = settings.font
        return AppFontResolver { FontCatalog.font(size: $0, weight: $1, option: option) }
    }

    /// 이 시점에 보여 줄 타이머 상태. 이미 끝난 세션은 다음 세션으로 넘겨서 보여 준다.
    var displayTimer: (state: TimerState, finished: SessionKind?) {
        var st = timer
        var copy = data
        let finished = TimerLogic.settle(&st, data: &copy, settings, now: date)
        return (st, finished)
    }

    func url(_ host: String, date: Date? = nil) -> URL {
        var s = "\(SharedStorage.urlScheme)://\(host)"
        if let date { s += "?date=\(date.linkKey)" }
        return URL(string: s)!
    }
}

struct AlphaProvider: TimelineProvider {
    private static let fontsReady: Void = FontCatalog.registerDefaultLocations()

    func placeholder(in context: Context) -> AlphaEntry { Self.sample() }

    func getSnapshot(in context: Context, completion: @escaping (AlphaEntry) -> Void) {
        let entry = Self.load(at: Date())
        completion(context.isPreview && entry.isMissingData ? Self.sample() : entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AlphaEntry>) -> Void) {
        let now = Date()
        let first = Self.load(at: now)
        var entries = [first]
        // 타이머가 끝나는 순간 "완료"로 바뀌도록 항목을 하나 더 둔다
        if let end = first.timer.endDate, first.timer.isRunning, end > now {
            entries.append(AlphaEntry(date: end, data: first.data, timer: first.timer, settings: first.settings))
        }
        let midnight = first.cal.startOfDay(for: now).addingTimeInterval(86400 + 5)
        let refresh = min(midnight, now.addingTimeInterval(30 * 60))
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }

    static func load(at date: Date) -> AlphaEntry {
        _ = fontsReady
        let settings = SharedStorage.readSettings()
        guard let data = SharedStorage.readData() else {
            return AlphaEntry(date: date, data: AppData(), timer: TimerState(), settings: settings, isMissingData: true)
        }
        var timer = SharedStorage.readTimer() ?? TimerState()
        if timer.isIdle { timer.duration = TimerLogic.duration(for: timer.kind, settings) }
        return AlphaEntry(date: date, data: data, timer: timer, settings: settings)
    }

    /// 위젯 갤러리 미리보기용 예시 데이터
    static func sample() -> AlphaEntry {
        let cal = Calendar.alpha(mondayFirst: false)
        let today = cal.startOfDay(for: Date())
        var data = AppData()
        let study = Goal(name: "공부", colorIndex: 5, icon: "book.closed", order: 0)
        let health = Goal(name: "운동", colorIndex: 3, icon: "figure.run", order: 1)
        data.goals = [study, health]
        data.todos = [
            Todo(title: "수학 과제 제출", date: today, isDone: true, order: 0, goalID: study.id),
            Todo(title: "영어 단어 50개", date: today, order: 1, goalID: study.id, pomodoroCount: 2),
            Todo(title: "Swift 위젯 공부", date: today, order: 2, goalID: study.id),
            Todo(title: "스트레칭 10분", date: today, order: 0, goalID: health.id),
        ]
        let start = cal.date(bySettingHour: 15, minute: 0, second: 0, of: today)!
        data.events = [Event(title: "동아리 회의", start: start, end: start.addingTimeInterval(3600), colorIndex: 7)]
        var timer = TimerState()
        timer.cycleCount = 2
        return AlphaEntry(date: Date(), data: data, timer: timer, settings: SharedSettings())
    }
}

// MARK: - 공용 조각

extension View {
    /// 위젯 공통: 투두메이트 배경 + 앱과 같은 서체·강조색
    func alphaWidgetStyle(_ entry: AlphaEntry) -> some View {
        self
            .environment(\.appFontResolver, entry.fontResolver)
            .environment(\.dsAccent, entry.accent)
            .foregroundStyle(DS.text)
            .containerBackground(DS.bg, for: .widget)
    }
}

/// "TODAY 23" 머리말
struct WidgetTodayHeader: View {
    let entry: AlphaEntry
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("TODAY \(entry.cal.component(.day, from: entry.date))").font(entry.font(DS.TextSize.headline, .bold))
            Spacer()
            if let trailing {
                Text(trailing).font(entry.font(DS.TextSize.label)).foregroundStyle(DS.textSecondary).monospacedDigit()
            }
        }
    }
}

struct MissingDataView: View {
    let entry: AlphaEntry

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "app.badge")
                .font(.title2)
                .foregroundStyle(DS.text)
            Text("앱을 먼저 실행해 주세요")
                .font(entry.font(12, .medium))
                .multilineTextAlignment(.center)
        }
    }
}
