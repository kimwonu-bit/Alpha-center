import AppIntents
import SwiftUI
import WidgetKit

struct PomodoroWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Pomodoro", provider: AlphaProvider()) { entry in
            PomodoroWidgetView(entry: entry)
                .alphaWidgetStyle(entry)
                .widgetURL(entry.url("pomodoro"))
        }
        .configurationDisplayName("포모도로")
        .description("남은 시간을 보고 바로 시작·일시정지·건너뛰기해요.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct PomodoroWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AlphaEntry

    var body: some View {
        if entry.isMissingData {
            MissingDataView(entry: entry)
        } else if family == .systemMedium {
            medium
        } else {
            small
        }
    }

    private var timer: TimerState { entry.displayTimer.state }
    private var finished: SessionKind? { entry.displayTimer.finished }
    private var color: Color { Palette.color(for: timer.kind) }
    private var todayCount: Int {
        // 위젯이 보여 주는 시점에 끝난 세션도 오늘 횟수에 넣는다
        entry.data.focusCount(on: entry.date, calendar: entry.cal) + (finished == .focus ? 1 : 0)
    }

    /// 실행 중이면 시스템이 매초 그리는 카운트다운, 아니면 고정 시간
    @ViewBuilder private func countdown(size: CGFloat) -> some View {
        if timer.isRunning, let start = timer.startedAt, let end = timer.endDate, end > entry.date {
            Text(timerInterval: start...end, countsDown: true)
                .font(entry.font(size, .bold))
                .monospacedDigit()
                .multilineTextAlignment(.leading)
        } else {
            Text(timer.remaining(at: entry.date).clockText)
                .font(entry.font(size, .bold))
                .monospacedDigit()
        }
    }

    private var statusText: String {
        if let finished { return "\(finished.label) 완료! 🎉" }
        if timer.isPaused { return "일시정지됨" }
        if let end = timer.endDate, timer.isRunning { return "\(end.formatted("a h:mm"))에 끝나요" }
        return "대기 중"
    }

    /// 실행 중이면 시스템이 그리는 막대, 아니면 고정 진행률
    @ViewBuilder private var progress: some View {
        if timer.isRunning, let start = timer.startedAt, let end = timer.endDate, end > entry.date {
            ProgressView(timerInterval: start...end, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                .progressViewStyle(.linear)
                .tint(color)
        } else {
            let total = max(1, timer.duration)
            ProgressBar(progress: (total - timer.remaining(at: entry.date)) / total, color: color)
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button(intent: ToggleTimerIntent()) {
                Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                    .foregroundStyle(timer.kind == .focus ? DS.onInk : .white)
                    .frame(maxWidth: .infinity)
            }
            .tint(color)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            Button(intent: SkipTimerIntent()) {
                Image(systemName: "forward.end.fill").foregroundStyle(DS.text)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
        }
        .controlSize(.small)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(timer.kind.label).font(entry.font(DS.TextSize.caption, .bold))
                Spacer()
                Text("🍅\(todayCount)").font(.system(size: 11))
            }
            Spacer(minLength: 0)
            countdown(size: 34)
            progress
            Text(statusText).font(entry.font(DS.TextSize.micro)).foregroundStyle(DS.textSecondary).lineLimit(1)
            Spacer(minLength: 0)
            controls
        }
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(timer.kind.label).font(entry.font(DS.TextSize.headline, .bold))
                Spacer()
                cycleDots
            }
            Rectangle().fill(DS.divider).frame(height: 0.5)
            HStack(alignment: .center, spacing: DS.Space.m) {
                countdown(size: 44)
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(statusText).font(entry.font(DS.TextSize.label)).foregroundStyle(DS.textSecondary).lineLimit(1)
                    if let todo = entry.data.todos.first(where: { $0.id == timer.todoID }) {
                        Label(todo.title, systemImage: "link").font(entry.font(DS.TextSize.label)).lineLimit(1)
                    } else {
                        Text("오늘 집중 \(todayCount)회").font(entry.font(DS.TextSize.label)).foregroundStyle(DS.textSecondary)
                    }
                }
            }
            progress
            Spacer(minLength: 0)
            controls
        }
    }

    private var cycleDots: some View {
        let total = max(1, entry.settings.longBreakInterval)
        let c = timer.cycleCount
        let done = c > 0 && c % total == 0 ? total : c % total
        return HStack(spacing: 3) {
            ForEach(0..<total, id: \.self) { i in
                TodoCheckbox(isOn: i < done, color: DS.ink, size: 9, animated: false)
            }
        }
    }
}
