import SwiftUI

struct TodoView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @AppStorage(Keys.todoTopMode) private var showMonth = false
    @State private var addingGoal: UUID?
    @State private var showGoalManager = false
    @State private var detailTodo: Todo?
    @State private var celebration: Date?
    @State private var showMoveUndone = false
    @State private var moveTarget = Date()

    private struct Progress: Equatable {
        let day: Date
        let done: Int
        let total: Int
    }

    private var progress: Progress {
        let c = store.completion(on: day)
        return Progress(day: day, done: c.done, total: c.total)
    }

    private var day: Date { router.todoDate }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                // 투두메이트 Mac처럼 넓으면 2단(왼쪽 달력 / 오른쪽 목록), 좁으면 1단
                if geo.size.width >= 900 {
                    HStack(alignment: .top, spacing: DS.Space.xl) {
                        VStack(alignment: .leading, spacing: DS.Space.l) {
                            calendarColumn(wide: true)
                            DailyNoteCard(day: day)
                        }
                        .frame(width: 340)
                        goalList
                            .frame(maxWidth: 560, alignment: .leading)
                    }
                    .padding(DS.Space.xl)
                    .frame(maxWidth: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: DS.Space.l) {
                        calendarColumn(wide: false)
                        goalList
                        DailyNoteCard(day: day)
                    }
                    .padding(DS.Space.l)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .background(DS.bg)
        .overlay { if let t = celebration { CelebrationOverlay(start: t).id(t) } }
        .onChange(of: progress) { old, new in
            // 같은 날짜에서 할 일 하나를 체크해 방금 전부 끝났을 때만 (날짜 이동·할 일 추가/삭제는 제외)
            guard old.day == new.day, old.total == new.total, new.total > 0,
                  new.done == new.total, new.done == old.done + 1 else { return }
            celebration = Date()
            Task { try? await Task.sleep(for: .seconds(3.2)); celebration = nil }
        }
        .onAppear { store.materializeRoutines(for: day) }
        .onChange(of: router.todoDate) { _, new in store.materializeRoutines(for: new) }
        .onChange(of: router.newTodoRequest) { _, _ in addingGoal = store.activeGoals.first?.id }
        .sheet(isPresented: $showGoalManager) { GoalManagerSheet() }
        .sheet(item: $detailTodo) { t in TodoDetailSheet(todo: t) }
        .toolbar {
            ToolbarItemGroup {
                undoneButtons
                Button { showGoalManager = true } label: { Label("목표 관리", systemImage: "folder.badge.gearshape") }
                    .help("목표 관리")
            }
        }
    }

    // MARK: 못 한 일 옮기기

    private var undoneButtons: some View {
        let count = store.undoneTodos(on: day).count
        return Group {
            Button {
                withAnimation(.snappy) { store.moveUndoneTodosToNextDay(from: day) }
            } label: {
                Label("못 한 일 다음 날로", systemImage: "arrow.turn.up.right")
            }
            .disabled(count == 0)
            .help(count == 0 ? "이 날 못 한 일이 없어요" : "못 한 일 \(count)개를 다음 날로 이동")

            Button {
                moveTarget = day.adding(days: 1)
                showMoveUndone = true
            } label: {
                Label("못 한 일 지정한 날로", systemImage: "calendar.badge.clock")
            }
            .disabled(count == 0)
            .help(count == 0 ? "이 날 못 한 일이 없어요" : "못 한 일 \(count)개를 지정한 날로 이동")
        .popover(isPresented: $showMoveUndone) {
            VStack(spacing: 12) {
                Text("못 한 일 \(store.undoneTodos(on: day).count)개를 옮길 날").appFont(DS.TextSize.headline, .bold)
                DatePicker("", selection: $moveTarget, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                HStack {
                    Button("취소") { showMoveUndone = false }
                    Button("이동") {
                        withAnimation(.snappy) { store.moveUndoneTodos(from: day, to: moveTarget) }
                        showMoveUndone = false
                    }
                    .buttonStyle(.glassProminent)
                    .tint(DS.ink)
                    .disabled(moveTarget.isSameDay(as: day))
                }
            }
            .padding()
        }
        }
    }

    // MARK: 왼쪽: 프로필 + 달력

    /// 넓은 화면(2단)에서는 항상 한 달, 좁은 화면에서는 한 주(주/월 전환 가능)
    private func calendarColumn(wide: Bool) -> some View {
        @Bindable var router = router
        let month = wide || showMonth
        return VStack(alignment: .leading, spacing: DS.Space.m) {
            ProfileHeader(day: day)
            calendarHeader(month: month, canToggle: !wide)
            Group {
                if month {
                    MonthAchievementGrid(selection: $router.todoDate)
                } else {
                    WeekStrip(selection: $router.todoDate)
                }
            }
            .animation(.snappy, value: month)
        }
    }

    private func calendarHeader(month isMonth: Bool, canToggle: Bool) -> some View {
        let c = store.completion(on: day)
        return HStack(spacing: DS.Space.xs) {
            DayStamp(done: c.done, total: c.total, size: 18, showsCount: false)
            Button { router.todoDate = Date().startOfDay } label: {
                Text(periodTitle(month: isMonth)).appFont(DS.TextSize.headline, .bold).foregroundStyle(DS.text)
            }
            .buttonStyle(.plain)
            .help("오늘로 이동 (⌘T)")
            Spacer()
            if canToggle {
                PillToggle(selection: $showMonth, options: [("주", false), ("월", true)])
            }
            CircleIconButton(systemName: "chevron.left", help: isMonth ? "이전 달" : "이전 주") { shift(-1, month: isMonth) }
            CircleIconButton(systemName: "chevron.right", help: isMonth ? "다음 달" : "다음 주") { shift(1, month: isMonth) }
        }
    }

    private func periodTitle(month isMonth: Bool) -> String {
        if isMonth { return day.formatted("yyyy년 M월") }
        let week = Calendar.app.component(.weekOfMonth, from: day)
        return day.formatted("yyyy년 M월 ") + "\(week)주차"
    }

    private func shift(_ n: Int, month isMonth: Bool) {
        let comp: Calendar.Component = isMonth ? .month : .weekOfYear
        router.todoDate = Calendar.app.date(byAdding: comp, value: n, to: day)!.startOfDay
    }

    // MARK: 오른쪽: 목표별 할 일

    private var goalList: some View {
        VStack(alignment: .leading, spacing: DS.Space.l) {
            if store.activeGoals.isEmpty {
                emptyGoals
            } else {
                ForEach(store.activeGoals) { goal in
                    GoalSection(goal: goal, day: day, addingGoal: $addingGoal, detailTodo: $detailTodo)
                }
            }
        }
    }

    private var emptyGoals: some View {
        VStack(spacing: DS.Space.s) {
            GoalChip(title: "새 목표", icon: "target", color: DS.textSecondary)
            Text("먼저 목표를 만들어 주세요").appFont(DS.TextSize.headline, .bold)
            Text("할 일은 목표(카테고리) 아래에 쌓여요.").appFont(DS.TextSize.caption).foregroundStyle(DS.textSecondary)
            Button("목표 만들기") { showGoalManager = true }
                .buttonStyle(.glassProminent)
                .tint(DS.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

// MARK: - 프로필 머리말

/// 투두메이트 프로필 영역: 원형 아이콘 + 이름 + 한 줄 상태
struct ProfileHeader: View {
    @Environment(Store.self) private var store
    let day: Date

    var body: some View {
        let c = store.completion(on: day)
        HStack(spacing: DS.Space.s) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 48, height: 48)
                .background(DS.surface, in: .circle)
                .clipShape(.circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(AppInfo.shortName).appFont(DS.TextSize.headline, .bold).foregroundStyle(DS.text)
                Text(status(c)).appFont(DS.TextSize.caption).foregroundStyle(DS.textSecondary)
            }
            Spacer()
        }
    }

    private func status(_ c: (done: Int, total: Int)) -> String {
        let date = day.formatted("M월 d일 EEEE")
        if c.total == 0 { return "\(date) · 할 일이 없어요" }
        if c.done == c.total { return "\(date) · 모두 완료했어요" }
        return "\(date) · \(c.total)개 중 \(c.done)개 완료"
    }
}

// MARK: - 주간 스트립

struct WeekStrip: View {
    @Environment(Store.self) private var store
    @Environment(\.dsAccent) private var accent
    @Binding var selection: Date
    @Namespace private var selectionNS

    var body: some View {
        let cal = Calendar.app
        VStack(spacing: DS.Space.xs) {
            WeekdayHeader()
            let days = cal.days(inWeekOf: selection)
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { d in
                    let c = store.completion(on: d)
                    VStack(spacing: 6) {
                        DayStamp(done: c.done, total: c.total, color: accent, highlight: store.hasMajorEvent(on: d),
                         segments: store.doneSegments(on: d))
                        DateNumber(date: d, calendar: cal,
                                   isSelected: d.isSameDay(as: selection),
                                   isToday: d.isSameDay(as: Date()))
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(.rect)
                    .onTapGesture { withAnimation(.snappy) { selection = d.startOfDay } }
                    .dropDestination(for: String.self) { items, _ in
                        return dropTodos(items, to: d, store: store)
                    }
                }
            }
            .padding(.vertical, 4)
            .background { DiaryRuns(flags: days.map { store.hasDiary(on: $0) }) }
        }
    }
}

/// 할 일을 날짜 칸에 끌어다 놓으면 그 날로 옮긴다
func dropTodos(_ items: [String], to day: Date, store: Store) -> Bool {
    var moved = false
    for s in items where s.hasPrefix("todo:") {
        if let id = UUID(uuidString: String(s.dropFirst(5))) { store.moveTodo(id, to: day); moved = true }
    }
    return moved
}

// MARK: - 월간 달성 캘린더

struct MonthAchievementGrid: View {
    @Environment(Store.self) private var store
    @Environment(\.dsAccent) private var accent
    @Binding var selection: Date

    var body: some View {
        let cal = Calendar.app
        let grid = cal.monthGrid(for: selection)
        let month = cal.component(.month, from: selection)
        // 마지막 주가 통째로 다음 달이면 그리지 않는다
        let rows = cal.component(.month, from: grid[35]) == month ? 42 : 35
        let weeks: [[Date]] = Array(grid.prefix(rows)).chunked(by: 7)
        VStack(spacing: DS.Space.xs) {
            WeekdayHeader()
            VStack(spacing: 6) {
                ForEach(weeks.indices, id: \.self) { i in
                    weekRow(weeks[i], month: month)
                }
            }
        }
    }

    private func weekRow(_ week: [Date], month: Int) -> some View {
        let flags = week.map { store.hasDiary(on: $0) }
        return HStack(spacing: 0) {
            ForEach(week, id: \.self) { d in
                dayCell(d, month: month)
            }
        }
        .padding(.vertical, 4)
        .background { DiaryRuns(flags: flags) }
    }

    private func dayCell(_ d: Date, month: Int) -> some View {
        let cal = Calendar.app
        let c = store.completion(on: d)
        let inMonth = cal.component(.month, from: d) == month
        return VStack(spacing: 4) {
            DayStamp(done: c.done, total: c.total, color: accent, highlight: store.hasMajorEvent(on: d),
                         segments: store.doneSegments(on: d))
            DateNumber(date: d, calendar: cal,
                       isSelected: d.isSameDay(as: selection),
                       isToday: d.isSameDay(as: Date()))
        }
        .opacity(inMonth ? 1 : 0.4)
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
        .onTapGesture { withAnimation(.snappy) { selection = d.startOfDay } }
        .dropDestination(for: String.self) { items, _ in
            return dropTodos(items, to: d, store: store)
        }
    }
}

/// 일기 색: 아주 연한 하늘색에서 오른쪽으로 갈수록 조금 짙은 파란색
enum DiaryStyle {
    static func gradient(opacity: Double) -> LinearGradient {
        LinearGradient(colors: [Color(hex: 0xCFEFFF).opacity(opacity), Color(hex: 0x7DB4FF).opacity(opacity)],
                       startPoint: .leading, endPoint: .trailing)
    }
}

/// 일기를 쓴 날짜 뒤에 깔리는 투명 리퀴드 글래스 사각형. 연속된 날짜는 하나로 이어진다.
struct DiaryRuns: View {
    let flags: [Bool]

    private var runs: [Range<Int>] {
        var result: [Range<Int>] = []
        var start: Int?
        for (i, on) in flags.enumerated() {
            if on, start == nil { start = i }
            if !on, let s = start { result.append(s..<i); start = nil }
        }
        if let s = start { result.append(s..<flags.count) }
        return result
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width / CGFloat(max(flags.count, 1))
            GlassEffectContainer {
                ZStack(alignment: .topLeading) {
                    ForEach(runs, id: \.lowerBound) { r in
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(DiaryStyle.gradient(opacity: 0.3))
                            .frame(width: w * CGFloat(r.count) - 4, height: geo.size.height)
                            .glassEffect(.clear, in: .rect(cornerRadius: 10))
                            .offset(x: w * CGFloat(r.lowerBound) + 2)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

extension Array {
    func chunked(by size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}

// MARK: - 목표 섹션

struct GoalSection: View {
    @Environment(Store.self) private var store
    let goal: Goal
    let day: Date
    @Binding var addingGoal: UUID?
    @Binding var detailTodo: Todo?
    @State private var draft = ""
    @State private var isTargeted = false
    @FocusState private var inputFocused: Bool

    private var color: Color { Palette.color(goal.colorIndex) }

    var body: some View {
        // 완료한 할 일은 목록 아래로 (같은 상태끼리는 기존 순서 유지)
        let items = store.todos(on: day, goal: goal.id).enumerated()
            .sorted { ($0.element.isDone ? 1 : 0, $0.offset) < ($1.element.isDone ? 1 : 0, $1.offset) }
            .map(\.element)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    addingGoal = goal.id
                } label: {
                    GoalChip(title: goal.name, icon: goal.icon, color: color)
                }
                .buttonStyle(.plain)
                .help("\(goal.name)에 할 일 추가")
                .draggable("goal:\(goal.id.uuidString)")
                Spacer()
                if !items.isEmpty {
                    Text("\(items.filter(\.isDone).count)/\(items.count)")
                        .appFont(DS.TextSize.caption)
                        .monospacedDigit()
                        .foregroundStyle(DS.textSecondary)
                }
            }
            .padding(.bottom, DS.Space.xs)
            .dropDestination(for: String.self) { strings, _ in handleDrop(strings) } isTargeted: { isTargeted = $0 }

            ForEach(items) { t in
                TodoRow(todo: t, color: color, detailTodo: $detailTodo)
                    .draggable("todo:\(t.id.uuidString)") {
                        Text(t.title).appFont(DS.TextSize.body).padding(8).background(DS.surface, in: .rect(cornerRadius: 8))
                    }
                    .dropDestination(for: String.self) { strings, _ in
                        for s in strings where s.hasPrefix("todo:") {
                            if let id = UUID(uuidString: String(s.dropFirst(5))) { store.moveTodo(id, before: t.id) }
                        }
                        return true
                    }
            }

            if addingGoal == goal.id {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: DS.Radius.checkbox, style: .continuous)
                        .strokeBorder(DS.checkOff, style: StrokeStyle(lineWidth: 1.5, dash: [3]))
                        .frame(width: DS.Size.checkbox, height: DS.Size.checkbox)
                    TextField("할 일 입력 후 Enter", text: $draft)
                        .textFieldStyle(.plain)
                        .appFont(DS.TextSize.body)
                        .focused($inputFocused)
                        .onSubmit(submit)
                        .onExitCommand { close() }
                    Button("완료") { close() }
                        .buttonStyle(.plain)
                        .appFont(DS.TextSize.caption, .bold)
                        .foregroundStyle(DS.textSecondary)
                }
                .padding(.vertical, 6)
                .overlay(alignment: .bottom) { Rectangle().fill(color).frame(height: 1.5) }
                .onAppear { inputFocused = true }
            }
        }
        .animation(.snappy, value: items.map(\.id))
        .padding(isTargeted ? 6 : 0)
        .background(isTargeted ? color.opacity(0.08) : .clear, in: .rect(cornerRadius: DS.Radius.tile))
        .onChange(of: addingGoal) { _, new in if new == goal.id { inputFocused = true } }
    }

    private func submit() {
        if draft.trimmingCharacters(in: .whitespaces).isEmpty {
            close()
            return
        }
        withAnimation(.snappy) { _ = store.addTodo(title: draft, goalID: goal.id, date: day) }
        draft = ""
        inputFocused = true // Enter로 연속 추가
    }

    private func close() {
        draft = ""
        if addingGoal == goal.id { addingGoal = nil }
    }

    private func handleDrop(_ strings: [String]) -> Bool {
        for s in strings {
            if s.hasPrefix("todo:"), let id = UUID(uuidString: String(s.dropFirst(5))) {
                store.moveTodo(id, toGoal: goal.id, on: day)
            } else if s.hasPrefix("goal:"), let id = UUID(uuidString: String(s.dropFirst(5))) {
                withAnimation(.snappy) { store.moveGoal(id, before: goal.id) }
            }
        }
        return true
    }
}

// MARK: - 할 일 행

struct TodoRow: View {
    @Environment(Store.self) private var store
    @Environment(TimerEngine.self) private var timer
    @Environment(Router.self) private var router
    let todo: Todo
    let color: Color
    @Binding var detailTodo: Todo?
    @State private var isEditing = false
    @State private var editText = ""
    @State private var showActions = false
    @State private var showDatePicker = false
    @State private var pickedDate = Date()
    @State private var hovering = false
    @FocusState private var editFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            TodoCheckbox(isOn: todo.isDone, color: color)
                .onTapGesture {
                    if !todo.isDone { SoundPlayer.playCheck() }
                    store.toggleTodo(todo.id)
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(todo.isDone ? "완료 취소" : "완료")

            if isEditing {
                TextField("", text: $editText)
                    .textFieldStyle(.plain)
                    .appFont(DS.TextSize.body)
                    .focused($editFocused)
                    .onSubmit(commitEdit)
                    .onExitCommand { isEditing = false }
                    .onChange(of: editFocused) { _, f in if !f { commitEdit() } }
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text(todo.title)
                        .appFont(DS.TextSize.body)
                        .foregroundStyle(DS.text)
                    if !todo.memo.isEmpty {
                        Text(todo.memo).appFont(DS.TextSize.caption).foregroundStyle(DS.textSecondary).lineLimit(1)
                    }
                }
                .onTapGesture(count: 2) { beginEdit() }
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                if todo.routineID != nil {
                    Image(systemName: "repeat").help("반복 할 일")
                }
                if let r = todo.reminderAt {
                    Label(r.formatted("a h:mm"), systemImage: "bell").labelStyle(.titleAndIcon)
                }
                if todo.pomodoroCount > 0 {
                    Text("🍅 \(todo.pomodoroCount)")
                }
                if timer.state.todoID == todo.id {
                    Image(systemName: "timer").foregroundStyle(DS.text).help("포모도로 연결됨")
                }
                Button { showActions = true } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 22, height: 22)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.textSecondary)
                .opacity(hovering || showActions ? 1 : 0)
                .help("더 보기")
                .popover(isPresented: $showActions, arrowEdge: .trailing) { actionSheet }
            }
            .appFont(DS.TextSize.caption)
            .foregroundStyle(DS.textSecondary)
        }
        .frame(minHeight: 32)
        .contentShape(.rect)
        .onHover { hovering = $0 }
        .contextMenu { menu }
        .popover(isPresented: $showDatePicker) {
            VStack(spacing: 12) {
                Text("다른 날 하기").appFont(DS.TextSize.headline, .bold)
                DatePicker("", selection: $pickedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                HStack {
                    Button("취소") { showDatePicker = false }
                    Button("이동") {
                        store.moveTodo(todo.id, to: pickedDate)
                        showDatePicker = false
                    }
                    .buttonStyle(.glassProminent)
                    .tint(DS.ink)
                }
            }
            .padding()
        }
    }

    /// 투두메이트식 액션 시트: 제목 + 3열 타일
    private var actionSheet: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            HStack(spacing: 8) {
                TodoCheckbox(isOn: todo.isDone, color: color, size: 16, animated: false)
                Text(todo.title).appFont(DS.TextSize.headline, .bold).lineLimit(2)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ActionTile(title: "수정", systemImage: "pencil") { act(beginEdit) }
                ActionTile(title: "자세히", systemImage: "slider.horizontal.3") { act { detailTodo = todo } }
                if todo.date.isSameDay(as: Date()) {
                    ActionTile(title: "내일 하기", systemImage: "arrow.turn.up.right") {
                        act { store.moveTodo(todo.id, to: todo.date.adding(days: 1)) }
                    }
                } else {
                    ActionTile(title: "오늘 하기", systemImage: "sun.max") { act { store.moveTodo(todo.id, to: Date()) } }
                }
                ActionTile(title: "다른 날 하기", systemImage: "calendar") {
                    act {
                        pickedDate = todo.date
                        showDatePicker = true
                    }
                }
                ActionTile(title: "집중 시작", systemImage: "timer") { act(startFocus) }
                ActionTile(title: "삭제", systemImage: "trash", isDestructive: true) {
                    act { withAnimation { store.deleteTodo(todo.id) } }
                }
            }
        }
        .padding(DS.Space.m)
        .frame(width: 300)
    }

    /// 팝오버를 닫은 다음 동작한다 (다른 팝오버·시트와 겹치지 않게)
    private func act(_ f: @escaping @MainActor () -> Void) {
        showActions = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            f()
        }
    }

    @ViewBuilder private var menu: some View {
        Button(todo.isDone ? "완료 취소" : "완료") { store.toggleTodo(todo.id) }
        Button("이름 수정") { beginEdit() }
        Button("자세히 (메모·알림·반복)…") { detailTodo = todo }
        Divider()
        if !todo.date.isSameDay(as: Date()) {
            Button("오늘 하기") { store.moveTodo(todo.id, to: Date()) }
        }
        Button("내일 하기") { store.moveTodo(todo.id, to: todo.date.adding(days: 1)) }
        Button("다른 날 하기…") {
            pickedDate = todo.date
            showDatePicker = true
        }
        Divider()
        Button("이 할 일로 포모도로 시작", action: startFocus)
        Divider()
        Button("삭제", role: .destructive) { withAnimation { store.deleteTodo(todo.id) } }
    }

    private func startFocus() {
        timer.link(todo: todo.id)
        if !timer.state.isRunning {
            timer.select(.focus)
            timer.start()
        }
        router.tab = .pomodoro
    }

    private func beginEdit() {
        editText = todo.title
        isEditing = true
        DispatchQueue.main.async { editFocused = true }
    }

    private func commitEdit() {
        guard isEditing else { return }
        isEditing = false
        let text = editText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, text != todo.title else { return }
        var t = todo
        t.title = text
        store.updateTodo(t)
    }
}

// MARK: - 하루 회고 (투두메이트 일기 카드)

struct DailyNoteCard: View {
    @Environment(Store.self) private var store
    let day: Date
    @State private var text = ""
    @State private var mood = ""
    private let moods = ["😀", "🙂", "😐", "😮‍💨", "😢", "🔥"]
    @State private var pickedEmoji = ""
    @FocusState private var emojiFieldFocused: Bool

    /// 목록에 없는, 이모지 선택기로 고른 기분
    private var customMood: String? { mood.isEmpty || moods.contains(mood) ? nil : mood }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            HStack {
                Text("일기").appFont(DS.TextSize.headline, .bold)
                Spacer()
                Text(day.formatted("M월 d일 EEEE")).appFont(DS.TextSize.caption).opacity(0.6)
            }
            HStack(spacing: 6) {
                ForEach(moods + (customMood.map { [$0] } ?? []), id: \.self) { m in
                    Text(m)
                        .font(.system(size: mood == m ? 30 : 22))
                        .opacity(mood.isEmpty || mood == m ? 1 : 0.4)
                        .frame(width: 38, height: 38)
                        .contentShape(.rect)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { mood = mood == m ? "" : m }
                            save()
                        }
                }
                emojiPickerButton
            }
            TextField("", text: $text, prompt: Text("오늘은 어땠나요? 한 줄로 남겨요").foregroundStyle(DS.textSecondary), axis: .vertical)
                .textFieldStyle(.plain)
                .appFont(DS.TextSize.body)
                .lineLimit(1...4)
                .onChange(of: text) { _, _ in save() }
                .padding(10)
                .background(.white.opacity(0.55), in: .rect(cornerRadius: 10, style: .continuous))
        }
        .foregroundStyle(DS.text)
        .padding(DS.Space.m)
        .background(DiaryStyle.gradient(opacity: 0.35), in: .rect(cornerRadius: DS.Radius.card, style: .continuous))
        .glassEffect(.regular, in: .rect(cornerRadius: DS.Radius.card))
        .onAppear(perform: loadNote)
        .onChange(of: day) { _, _ in loadNote() }
    }

    /// 맥 이모지 선택기(fn / 🌐 키로 여는 것과 같은 창)를 열어 기분을 고른다
    private var emojiPickerButton: some View {
        ZStack {
            // 선택기가 글자를 넣어 줄 보이지 않는 입력칸
            TextField("", text: $pickedEmoji)
                .textFieldStyle(.plain)
                .focused($emojiFieldFocused)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .onChange(of: pickedEmoji) { _, new in
                    guard let e = new.last(where: { $0.unicodeScalars.contains { $0.properties.isEmojiPresentation || ($0.properties.isEmoji && $0.value > 0xFF) } }) else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { mood = String(e) }
                    pickedEmoji = ""
                    save()
                }
            Button {
                emojiFieldFocused = true
                DispatchQueue.main.async { NSApp.orderFrontCharacterPalette(nil) }
            } label: {
                Image(systemName: "face.smiling.inverse")
                    .font(.system(size: 18))
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.55), in: .circle)
            }
            .buttonStyle(.plain)
            .help("모든 이모지에서 고르기")
        }
    }

    private func loadNote() {
        let n = store.note(on: day)
        text = n.text
        mood = n.mood
    }

    private func save() {
        store.saveNote(DailyNote(date: day.startOfDay, text: text, mood: mood))
    }
}
