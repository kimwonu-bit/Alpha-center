import SwiftUI

enum CalendarMode: String, CaseIterable, Identifiable {
    case month, week, day
    var id: String { rawValue }
    var label: String {
        switch self {
        case .month: "월"
        case .week: "주"
        case .day: "일"
        }
    }
}

struct CalendarView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @AppStorage(Keys.calendarMode) private var mode: CalendarMode = .month
    @State private var selected = Date().startOfDay
    @State private var editingEvent: Event?

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                header
                if !store.ddayEvents.isEmpty { ddayBar }
                switch mode {
                case .month:
                    MonthGrid(selected: $selected, onEdit: { editingEvent = $0 }, onNew: newEvent)
                case .week:
                    TimelineGrid(days: Calendar.app.days(inWeekOf: selected), selected: $selected, onEdit: { editingEvent = $0 }, onNew: newEvent)
                case .day:
                    TimelineGrid(days: [selected], selected: $selected, onEdit: { editingEvent = $0 }, onNew: newEvent)
                }
            }
            .padding(DS.Space.l)

            Rectangle().fill(DS.divider).frame(width: 0.5)

            DayDetailPanel(day: selected, onEdit: { editingEvent = $0 }, onNew: { newEvent(selected) })
                .frame(width: 280)
        }
        .background(DS.bg)
        .onAppear { selected = router.calendarDate }
        .onChange(of: router.calendarDate) { _, new in selected = new }
        .onChange(of: selected) { _, new in router.calendarDate = new }
        .sheet(item: $editingEvent) { e in
            EventEditor(event: e, isNew: !store.data.events.contains { $0.id == e.id })
        }
        .toolbar {
            ToolbarItem {
                Button { newEvent(selected) } label: { Label("일정 추가", systemImage: "plus") }
                    .help("일정 추가")
            }
        }
    }

    private var header: some View {
        ScreenHeader(title: title) {
            HStack(spacing: DS.Space.xs) {
                PillToggle(selection: $mode, options: CalendarMode.allCases.map { ($0.label, $0) })
                Button("오늘") { selected = Date().startOfDay }
                    .buttonStyle(.glass)
                CircleIconButton(systemName: "chevron.left", help: "이전") { shift(-1) }
                CircleIconButton(systemName: "chevron.right", help: "다음") { shift(1) }
            }
        }
    }

    private var title: String {
        switch mode {
        case .month:
            return selected.formatted("yyyy년 M월")
        case .week:
            let days = Calendar.app.days(inWeekOf: selected)
            return "\(days.first!.formatted("M월 d일")) – \(days.last!.formatted("M월 d일"))"
        case .day:
            return selected.formatted("M월 d일 EEEE")
        }
    }

    private var ddayBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.ddayEvents) { e in
                    let target = e.nextOccurrence(after: Date().startOfDay, calendar: .app) ?? e.start
                    let days = Calendar.app.dateComponents([.day], from: Date().startOfDay, to: target.startOfDay).day ?? 0
                    Button { editingEvent = e } label: {
                        HStack(spacing: 6) {
                            Text(days == 0 ? "D-DAY" : days > 0 ? "D-\(days)" : "D+\(-days)")
                                .appFont(DS.TextSize.caption, .bold)
                                .foregroundStyle(Palette.color(e.colorIndex))
                            Text(e.title).appFont(DS.TextSize.caption, .medium).foregroundStyle(DS.text)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: DS.Size.pill)
                        .background(DS.surface, in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func shift(_ n: Int) {
        let comp: Calendar.Component = switch mode {
        case .month: .month
        case .week: .weekOfYear
        case .day: .day
        }
        selected = Calendar.app.date(byAdding: comp, value: n, to: selected)!.startOfDay
    }

    /// 자정이 아닌 시각이 들어오면(타임라인 더블 클릭) 그 시각으로, 아니면 다음 정시로 만든다.
    private func newEvent(_ date: Date) {
        let cal = Calendar.app
        let start: Date
        if date != date.startOfDay {
            start = date
        } else {
            let h = min(22, max(9, cal.component(.hour, from: Date()) + 1))
            start = cal.date(bySettingHour: h, minute: 0, second: 0, of: date)!
        }
        editingEvent = Event(title: "", start: start, end: start.addingTimeInterval(3600), colorIndex: 5)
    }
}

// MARK: - 월간

struct MonthGrid: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Binding var selected: Date
    var onEdit: (Event) -> Void
    var onNew: (Date) -> Void

    var body: some View {
        let cal = Calendar.app
        let grid = cal.monthGrid(for: selected)
        let month = cal.component(.month, from: selected)
        VStack(spacing: 0) {
            WeekdayHeader().padding(.bottom, DS.Space.xs)
            GeometryReader { geo in
                let h = geo.size.height / 6
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                    ForEach(grid, id: \.self) { d in
                        MonthCell(day: d, inMonth: cal.component(.month, from: d) == month,
                                  isSelected: d.isSameDay(as: selected), onEdit: onEdit)
                            .frame(height: h)
                            .contentShape(.rect)
                            .onTapGesture(count: 2) { onNew(d) }
                            .simultaneousGesture(TapGesture().onEnded { selected = d.startOfDay })
                            .contextMenu {
                                Button("이 날의 할 일 보기") { router.openTodos(on: d) }
                                Button("일정 추가") { onNew(d) }
                            }
                    }
                }
            }
        }
    }
}

struct MonthCell: View {
    @Environment(Store.self) private var store
    @Environment(\.dsAccent) private var accent
    let day: Date
    let inMonth: Bool
    let isSelected: Bool
    var onEdit: (Event) -> Void

    var body: some View {
        let events = store.events(on: day)
        let c = store.completion(on: day)
        let focus = store.focusSessions(on: day).count
        let isToday = day.isSameDay(as: Date())
        VStack(spacing: 3) {
            HStack(spacing: 2) {
                if c.total > 0 {
                    DayStamp(done: c.done, total: c.total, color: accent, size: 13, showsCount: false)
                }
                DateNumber(date: day, calendar: .app, isSelected: isSelected, isToday: isToday, size: DS.TextSize.caption)
            }
            .frame(maxWidth: .infinity)
            ForEach(events.prefix(3)) { e in
                EventBar(title: e.isAllDay ? e.title : "\(e.startTime(on: day, calendar: .app).formatted("H:mm")) \(e.title)",
                         color: Palette.color(e.colorIndex))
                    .onTapGesture { onEdit(e) }
            }
            if events.count > 3 {
                Text("+\(events.count - 3)").appFont(DS.TextSize.micro, .bold).foregroundStyle(DS.textSecondary)
            }
            Spacer(minLength: 0)
            if focus > 0 {
                Text("🍅 \(focus)").appFont(DS.TextSize.micro).foregroundStyle(DS.textSecondary)
            }
        }
        .padding(3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .opacity(inMonth ? 1 : 0.4)
    }
}
// MARK: - 주간 / 일간 타임라인

struct TimelineGrid: View {
    @Environment(Store.self) private var store
    let days: [Date]
    @Binding var selected: Date
    var onEdit: (Event) -> Void
    var onNew: (Date) -> Void

    private let hourHeight: CGFloat = 48

    var body: some View {
        VStack(spacing: 0) {
            // 날짜 머리말 + 종일 일정
            HStack(alignment: .top, spacing: 0) {
                Color.clear.frame(width: 44)
                ForEach(days, id: \.self) { d in
                    VStack(spacing: 4) {
                        Text(d.formatted("E")).appFont(DS.TextSize.label, .medium)
                            .foregroundStyle(DS.weekdayColor(d, calendar: .app, base: DS.textSecondary))
                        DateNumber(date: d, calendar: .app,
                                   isSelected: d.isSameDay(as: selected),
                                   isToday: d.isSameDay(as: Date()), size: DS.TextSize.body)
                        ForEach(store.events(on: d).filter(\.isAllDay)) { e in
                            EventBar(title: e.title, color: Palette.color(e.colorIndex), size: DS.TextSize.label)
                                .onTapGesture { onEdit(e) }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 2)
                    .contentShape(.rect)
                    .onTapGesture { selected = d.startOfDay }
                }
            }
            .padding(.bottom, 8)

            ScrollViewReader { proxy in
                ScrollView {
                    HStack(alignment: .top, spacing: 0) {
                        VStack(spacing: 0) {
                            ForEach(0..<24, id: \.self) { h in
                                Text("\(h)시").appFont(DS.TextSize.micro).foregroundStyle(DS.textSecondary)
                                    .frame(width: 44, height: hourHeight, alignment: .topTrailing)
                                    .padding(.trailing, 6)
                                    .id(h)
                            }
                        }
                        ForEach(days, id: \.self) { d in
                            dayColumn(d)
                        }
                    }
                }
                .onAppear { proxy.scrollTo(8, anchor: .top) }
            }
        }
    }

    private func dayColumn(_ d: Date) -> some View {
        let cal = Calendar.app
        let events = store.events(on: d).filter { !$0.isAllDay }
        return ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(0..<24, id: \.self) { h in
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: hourHeight)
                        .overlay(alignment: .top) { Rectangle().fill(DS.divider).frame(height: 0.5) }
                        .contentShape(.rect)
                        .onTapGesture(count: 2) {
                            if let start = cal.date(bySettingHour: h, minute: 0, second: 0, of: d) {
                                onNew(start)
                            }
                        }
                }
            }
            GeometryReader { geo in
                ForEach(events) { e in
                    let start = e.startTime(on: d, calendar: cal)
                    let mins = Double(cal.component(.hour, from: start) * 60 + cal.component(.minute, from: start))
                    let length = max(25, e.end.timeIntervalSince(e.start) / 60)
                    let color = Palette.color(e.colorIndex)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(e.title).appFont(DS.TextSize.label, .bold).lineLimit(2)
                        Text(start.formatted("H:mm")).appFont(DS.TextSize.micro).opacity(0.85)
                    }
                    .foregroundStyle(color == DS.ink ? DS.onInk : .white)
                    .padding(4)
                    .frame(width: geo.size.width - 4, height: max(20, length / 60 * hourHeight - 2), alignment: .topLeading)
                    .background(color, in: .rect(cornerRadius: DS.Radius.bar + 1, style: .continuous))
                    .offset(x: 2, y: mins / 60 * hourHeight + 1)
                    .onTapGesture { onEdit(e) }
                }
            }
            if d.isSameDay(as: Date()) {
                let now = Date()
                let mins = Double(cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now))
                Rectangle().fill(DS.sunday).frame(height: 1.5).offset(y: mins / 60 * hourHeight)
            }
        }
        .frame(maxWidth: .infinity)
        .background(d.isSameDay(as: selected) && days.count > 1 ? DS.surface.opacity(0.6) : .clear)
        .overlay(alignment: .leading) { Rectangle().fill(DS.divider).frame(width: 0.5) }
    }
}

// MARK: - 오른쪽 날짜 상세

struct DayDetailPanel: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    let day: Date
    var onEdit: (Event) -> Void
    var onNew: () -> Void

    var body: some View {
        let events = store.events(on: day)
        let todos = store.orderedTodos(on: day)
        let c = store.completion(on: day)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(day.formatted("M월 d일 EEEE")).appFont(DS.TextSize.headline + 2, .bold)

                Button(action: onNew) {
                    GoalChip(title: "일정", icon: "calendar", color: DS.text)
                }
                .buttonStyle(.plain)
                .help("일정 추가")
                if events.isEmpty {
                    Text("일정이 없어요").appFont(DS.TextSize.caption).foregroundStyle(DS.textSecondary)
                }
                ForEach(events) { e in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: DS.Radius.bar).fill(Palette.color(e.colorIndex)).frame(width: 4, height: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.title).appFont(DS.TextSize.body, .medium).foregroundStyle(DS.text)
                            Text(e.isAllDay ? "종일" : "\(e.startTime(on: day, calendar: .app).formatted("a h:mm"))")
                                .appFont(DS.TextSize.label).foregroundStyle(DS.textSecondary)
                        }
                        Spacer()
                        if e.repeatFrequency != .none { Image(systemName: "repeat").foregroundStyle(DS.textSecondary) }
                        if e.alertMinutes != nil { Image(systemName: "bell").foregroundStyle(DS.textSecondary) }
                    }
                    .contentShape(.rect)
                    .onTapGesture { onEdit(e) }
                }

                Rectangle().fill(DS.divider).frame(height: 0.5)

                SectionTitle(title: "할 일", trailing: c.total > 0 ? "\(c.done)/\(c.total)" : nil)
                ForEach(todos.prefix(8)) { t in
                    HStack(spacing: 8) {
                        TodoCheckbox(isOn: t.isDone, color: Palette.color(store.goal(t.goalID)?.colorIndex ?? 0), size: 16)
                            .onTapGesture { store.toggleTodo(t.id) }
                        Text(t.title).appFont(DS.TextSize.body).foregroundStyle(DS.text).lineLimit(1)
                    }
                }
                if todos.count > 8 {
                    Text("외 \(todos.count - 8)개").appFont(DS.TextSize.caption).foregroundStyle(DS.textSecondary)
                }
                Button {
                    router.openTodos(on: day)
                } label: {
                    Label("이 날의 투두로 이동", systemImage: "arrow.right.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)

                let focus = store.focusSessions(on: day)
                if !focus.isEmpty {
                    Rectangle().fill(DS.divider).frame(height: 0.5)
                    SectionTitle(title: "집중 기록")
                    Text("🍅 \(focus.count)회 · \(store.focusMinutes(on: day))분").appFont(DS.TextSize.body)
                }
            }
            .padding(20)
        }
    }
}
