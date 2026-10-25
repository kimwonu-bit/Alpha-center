import Charts
import SwiftUI

struct PomodoroView: View {
    @Environment(Store.self) private var store
    @Environment(TimerEngine.self) private var timer
    @State private var notifications = NotificationManager.shared
    @Namespace private var glass
    @FocusState private var focused: Bool

    private var kindColor: Color { Palette.color(for: timer.state.kind) }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ScreenHeader(title: "포모도로", subtitle: subtitle) {
                    Button("사이클 처음으로") { timer.resetCycle() }
                        .buttonStyle(.glass)
                        .disabled(timer.state.isRunning)
                }

                if !notifications.isAuthorized && notifications.status != .notDetermined {
                    permissionBanner
                }

                kindPicker
                ring
                controls
                cycleDots
                linkedTodo

                Rectangle().fill(DS.divider).frame(height: 0.5).padding(.vertical, DS.Space.xs)
                FocusStatsView()
            }
            .padding(DS.Space.xl)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(DS.bg)
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onKeyPress(.space) {
            timer.toggle()
            return .handled
        }
        .onAppear {
            focused = true
            Task { await notifications.refreshStatus() }
        }
    }

    private var subtitle: String {
        let n = store.focusSessions(on: Date()).count
        return "오늘 집중 \(n)회 · \(store.focusMinutes(on: Date()))분"
    }

    private var permissionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.slash.fill").foregroundStyle(DS.sunday)
            VStack(alignment: .leading) {
                Text("알림이 꺼져 있어요").appFont(DS.TextSize.body, .bold)
                Text("앱이 켜져 있으면 소리로 알려 주지만, 확실한 알림을 위해 허용해 주세요.").appFont(DS.TextSize.caption).foregroundStyle(DS.textSecondary)
            }
            Spacer()
            Button("시스템 설정 열기") { notifications.openSystemSettings() }
        }
        .padding(DS.Space.s)
        .background(DS.surface, in: .rect(cornerRadius: DS.Radius.tile, style: .continuous))
    }

    private var kindPicker: some View {
        PillToggle(
            selection: Binding(get: { timer.state.kind }, set: { kind in
                guard !timer.state.isRunning else { return }
                withAnimation(.smooth) { timer.select(kind) }
            }),
            options: SessionKind.allCases.map { ($0.label, $0) }
        )
        .opacity(timer.state.isRunning ? 0.5 : 1)
    }

    /// 투두메이트 타이머: 세션 이름 → 구분선 → 아주 굵은 숫자 → 진행 막대
    private var ring: some View {
        VStack(spacing: DS.Space.m) {
            Text(timer.state.kind.label + (timer.state.isExtension ? " (연장)" : ""))
                .appFont(DS.TextSize.headline, .bold)
                .foregroundStyle(DS.text)
            Rectangle().fill(DS.divider).frame(height: 0.5)
            Text(timer.remaining.clockText)
                .font(FontManager.shared.font(size: DS.TextSize.display + 24, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(DS.text)
                .contentTransition(.numericText(countsDown: true))
            ProgressBar(progress: timer.progress, color: kindColor, height: 2)
                .animation(.linear(duration: 0.25), value: timer.progress)
            Group {
                if let finished = timer.lastFinished {
                    Text("\(finished.label) 완료! 🎉")
                } else if timer.state.isPaused {
                    Text("일시정지됨")
                } else if let end = timer.state.endDate {
                    Text("\(end.formatted("a h:mm"))에 끝나요")
                } else {
                    Text("Space로 시작")
                }
            }
            .appFont(DS.TextSize.caption)
            .foregroundStyle(DS.textSecondary)
        }
        .frame(maxWidth: 460)
        .padding(.vertical, DS.Space.l)
        .animation(.smooth(duration: 0.5), value: timer.state.kind)
    }

    /// 원형 아이콘 + 글자 캡슐 (Glass 유지)
    private func capsuleLabel(_ title: String, systemImage: String, iconColor: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(iconColor)
                .frame(width: 26, height: 26)
                .background(DS.surface, in: .circle)
            Text(title).appFont(DS.TextSize.caption, .bold)
        }
        .padding(.trailing, 6)
        .frame(height: 34)
    }

    private var controls: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                Button { timer.reset() } label: {
                    capsuleLabel("재설정", systemImage: "arrow.counterclockwise", iconColor: DS.text)
                }
                .buttonStyle(.glass)
                .help("재설정")
                .glassEffectID("reset", in: glass)

                Button {
                    withAnimation(.bouncy) { timer.toggle() }
                } label: {
                    capsuleLabel(timer.state.isRunning ? "일시정지" : "시작",
                                 systemImage: timer.state.isRunning ? "pause.fill" : "play.fill",
                                 iconColor: Palette.color(3))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.glassProminent)
                .tint(kindColor)
                .help(timer.state.isRunning ? "일시정지" : "시작")
                .glassEffectID("main", in: glass)

                Button { timer.skip() } label: {
                    capsuleLabel("건너뛰기", systemImage: "forward.end.fill", iconColor: DS.text)
                }
                .buttonStyle(.glass)
                .help("건너뛰기")
                .glassEffectID("skip", in: glass)

                if timer.state.isRunning {
                    Button { timer.addTime(minutes: 5) } label: {
                        capsuleLabel("+5분", systemImage: "plus", iconColor: DS.text)
                    }
                    .buttonStyle(.glass)
                    .glassEffectID("extend", in: glass)
                }
            }
        }
        .animation(.bouncy, value: timer.state.isRunning)
    }

    private var cycleDots: some View {
        let dots = timer.cycleDots
        return HStack(spacing: 6) {
            ForEach(0..<dots.total, id: \.self) { i in
                TodoCheckbox(isOn: i < dots.done, color: DS.ink, size: 14, animated: false)
            }
            Text("\(dots.total)회마다 긴 휴식").appFont(DS.TextSize.caption).foregroundStyle(DS.textSecondary).padding(.leading, 6)
        }
    }

    private var linkedTodo: some View {
        let todos = store.orderedTodos(on: Date()).filter { !$0.isDone || $0.id == timer.state.todoID }
        let current = store.todo(timer.state.todoID)
        return HStack(spacing: 10) {
            Image(systemName: "link").foregroundStyle(DS.textSecondary)
            Menu {
                Button("연결 안 함") { timer.link(todo: nil) }
                if !todos.isEmpty { Divider() }
                ForEach(todos) { t in
                    Button {
                        timer.link(todo: t.id)
                    } label: {
                        Label(t.title, systemImage: store.goal(t.goalID)?.icon ?? "circle")
                    }
                }
            } label: {
                Text(current.map { "집중할 할 일: \($0.title)" } ?? "집중할 할 일 선택")
                    .appFont(DS.TextSize.body)
            }
            .menuStyle(.button)
            .buttonStyle(.glass)
            .fixedSize()
            if let current, current.pomodoroCount > 0 {
                Text("🍅 \(current.pomodoroCount)").appFont(13).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - 집중 통계

struct FocusStatsView: View {
    @Environment(Store.self) private var store
    @State private var range = 7

    struct Point: Identifiable {
        let day: Date
        let minutes: Int
        var id: Date { day }
    }

    var body: some View {
        let today = Date().startOfDay
        let points = (0..<range).reversed().map { offset -> Point in
            let d = today.adding(days: -offset)
            return Point(day: d, minutes: store.focusMinutes(on: d))
        }
        let total = points.reduce(0) { $0 + $1.minutes }
        let count = points.reduce(0) { $0 + store.focusSessions(on: $1.day).count }

        VStack(alignment: .leading, spacing: DS.Space.m) {
            HStack {
                Text("집중 통계").appFont(DS.TextSize.headline, .bold)
                Spacer()
                PillToggle(selection: $range, options: [("1주", 7), ("1개월", 30)])
            }
            HStack(spacing: DS.Space.s) {
                stat("집중 횟수", "\(count)회")
                stat("총 집중 시간", total >= 60 ? "\(total / 60)시간 \(total % 60)분" : "\(total)분")
                stat("하루 평균", "\(total / max(1, range))분")
            }
            Chart(points) { p in
                BarMark(
                    x: .value("날짜", p.day, unit: .day),
                    y: .value("분", p.minutes)
                )
                .foregroundStyle(DS.ink)
                .cornerRadius(DS.Radius.bar)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: range > 7 ? 5 : 1)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.defaultDigits))
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(DS.divider)
                    AxisValueLabel()
                }
            }
            .chartYAxisLabel("분")
            .frame(height: 180)

            GoalDotStats(days: range)
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).appFont(DS.TextSize.caption).foregroundStyle(DS.textSecondary)
            Text(value).appFont(DS.TextSize.title, .bold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Space.m)
        .background(DS.surface, in: .rect(cornerRadius: DS.Radius.tile, style: .continuous))
    }
}

// MARK: - 목표별 점 격자 (투두메이트 분석 화면)

struct GoalDotStats: View {
    @Environment(Store.self) private var store
    let days: Int

    var body: some View {
        let today = Date().startOfDay
        let from = today.adding(days: -(days - 1))
        let todos = store.data.todos.filter { $0.date >= from && $0.date <= today }
        let goals = store.activeGoals.filter { g in todos.contains { $0.goalID == g.id } }
        if !goals.isEmpty {
            VStack(alignment: .leading, spacing: DS.Space.s) {
                Text("목표별 달성").appFont(DS.TextSize.headline, .bold)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: DS.Space.l, alignment: .topLeading)],
                          alignment: .leading, spacing: DS.Space.l) {
                    ForEach(goals) { g in
                        let items = todos.filter { $0.goalID == g.id }
                        let done = items.filter(\.isDone).count
                        VStack(alignment: .leading, spacing: DS.Space.xs) {
                            HStack(spacing: 0) {
                                Text(g.name).appFont(DS.TextSize.caption, .bold).foregroundStyle(Palette.color(g.colorIndex))
                                Text(" / \(items.count)").appFont(DS.TextSize.caption).foregroundStyle(DS.textSecondary)
                            }
                            DotGrid(filled: done, total: min(items.count, 49), color: Palette.color(g.colorIndex))
                        }
                    }
                }
            }
        }
    }
}
