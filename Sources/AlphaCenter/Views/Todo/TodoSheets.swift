import SwiftUI

// MARK: - 할 일 상세

struct TodoDetailSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var todo: Todo
    @State private var hasReminder = false
    @State private var reminderTime = Date()
    @State private var frequency: RepeatFrequency = .none
    @State private var weekdays: Set<Int> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section {
                    TextField("제목", text: $todo.title)
                    Picker("목표", selection: $todo.goalID) {
                        ForEach(store.activeGoals) { g in
                            Label(g.name, systemImage: g.icon).tag(g.id)
                        }
                    }
                    DatePicker("날짜", selection: $todo.date, displayedComponents: .date)
                }
                Section("메모") {
                    TextField("짧은 메모", text: $todo.memo, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("알림") {
                    Toggle("시간 알림", isOn: $hasReminder)
                    if hasReminder {
                        DatePicker("시각", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                }
                Section("반복 (루틴)") {
                    Picker("반복", selection: $frequency) {
                        ForEach([RepeatFrequency.none, .daily, .weekly, .monthly]) { f in
                            Text(f.label).tag(f)
                        }
                    }
                    if frequency == .weekly {
                        WeekdayPicker(selection: $weekdays)
                    }
                    if todo.routineID != nil {
                        Text("반복 규칙을 바꾸면 앞으로 만들어질 할 일에 적용돼요.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if todo.pomodoroCount > 0 {
                    Section("포모도로") {
                        LabeledContent("완료한 집중", value: "🍅 \(todo.pomodoroCount)회")
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("삭제", role: .destructive) {
                    store.deleteTodo(todo.id)
                    dismiss()
                }
                Spacer()
                Button("취소") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("저장", action: save)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.glassProminent)
                    .tint(DS.ink)
            }
            .padding()
        }
        .frame(width: 460, height: 600)
        .onAppear {
            hasReminder = todo.reminderAt != nil
            reminderTime = todo.reminderAt ?? Calendar.app.date(bySettingHour: 9, minute: 0, second: 0, of: todo.date)!
            if let r = store.routine(todo.routineID) {
                frequency = r.rule.frequency
                weekdays = r.rule.weekdays
            }
        }
    }

    private func save() {
        var t = todo
        let cal = Calendar.app
        if hasReminder {
            let hm = cal.dateComponents([.hour, .minute], from: reminderTime)
            t.reminderAt = cal.date(bySettingHour: hm.hour ?? 9, minute: hm.minute ?? 0, second: 0, of: t.date)
            Task { await NotificationManager.shared.requestAuthorization() }
        } else {
            t.reminderAt = nil
        }
        store.updateTodo(t)

        if frequency == .none {
            if let rid = t.routineID { store.stopRoutine(rid) }
        } else {
            let wd = frequency == .weekly && weekdays.isEmpty ? [cal.component(.weekday, from: t.date)] : weekdays
            store.makeRoutine(from: t.id, rule: RepeatRule(frequency: frequency, weekdays: Set(wd)))
        }
        dismiss()
    }
}

struct WeekdayPicker: View {
    @Binding var selection: Set<Int>
    private let symbols = ["일", "월", "화", "수", "목", "금", "토"]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Calendar.app.firstWeekday == 2 ? [2, 3, 4, 5, 6, 7, 1] : Array(1...7), id: \.self) { wd in
                let on = selection.contains(wd)
                Text(symbols[wd - 1])
                    .frame(width: 30, height: 30)
                    .appFont(DS.TextSize.caption, .bold)
                    .background(on ? DS.ink : DS.surface, in: .circle)
                    .foregroundStyle(on ? DS.onInk : DS.weekdayColor(for: wd))
                    .onTapGesture {
                        if on { selection.remove(wd) } else { selection.insert(wd) }
                    }
            }
        }
    }
}

// MARK: - 목표 관리

struct GoalManagerSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var editing: Goal?
    @State private var creating = false
    @State private var showArchived = false
    @State private var confirmDelete: Goal?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("목표 관리").appFont(DS.TextSize.title, .bold)
                Spacer()
                Toggle("보관된 목표 보기", isOn: $showArchived).toggleStyle(.switch).controlSize(.small)
            }
            .padding()

            List {
                ForEach(store.allGoalsSorted.filter { showArchived || !$0.isArchived }) { g in
                    HStack(spacing: 12) {
                        Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary)
                        GoalChip(title: g.name, icon: g.icon, color: Palette.color(g.colorIndex), showsPlus: false)
                            .opacity(g.isArchived ? 0.5 : 1)
                        if g.isArchived {
                            Text("보관됨").appFont(DS.TextSize.caption).foregroundStyle(DS.textSecondary)
                        }
                        Spacer()
                        Button { editing = g } label: { Image(systemName: "pencil") }.buttonStyle(.borderless)
                        Button {
                            var x = g
                            x.isArchived.toggle()
                            store.updateGoal(x)
                        } label: { Image(systemName: g.isArchived ? "tray.and.arrow.up" : "archivebox") }
                            .buttonStyle(.borderless)
                            .help(g.isArchived ? "보관 해제" : "보관 (기록은 유지)")
                        Button(role: .destructive) { confirmDelete = g } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 4)
                }
                .onMove { from, to in
                    var ids = store.allGoalsSorted.filter { showArchived || !$0.isArchived }.map(\.id)
                    ids.move(fromOffsets: from, toOffset: to)
                    let rest = store.allGoalsSorted.map(\.id).filter { !ids.contains($0) }
                    store.reorderGoals(ids + rest)
                }
            }
            .frame(minHeight: 260)

            HStack {
                Button { creating = true } label: { Label("목표 추가", systemImage: "plus") }
                Spacer()
                Button("완료") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.glassProminent)
                    .tint(DS.ink)
            }
            .padding()
        }
        .frame(width: 480, height: 480)
        .sheet(item: $editing) { g in GoalEditor(goal: g) }
        .sheet(isPresented: $creating) {
            GoalEditor(goal: Goal(name: "", colorIndex: store.data.goals.count % Palette.colors.count, icon: "star", order: 0), isNew: true)
        }
        .alert("목표를 삭제할까요?", isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } })) {
            Button("삭제", role: .destructive) {
                if let g = confirmDelete { store.deleteGoal(g.id) }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("이 목표에 속한 할 일과 루틴도 모두 지워져요. 기록을 남기려면 '보관'을 사용하세요.")
        }
    }
}

struct GoalEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var goal: Goal
    var isNew = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isNew ? "새 목표" : "목표 수정").appFont(DS.TextSize.title, .bold)
            HStack {
                GoalChip(title: goal.name.isEmpty ? "미리보기" : goal.name, icon: goal.icon, color: Palette.color(goal.colorIndex))
                Spacer()
            }
            TextField("목표 이름", text: $goal.name)
                .textFieldStyle(.roundedBorder)
            Text("색상").appFont(DS.TextSize.caption, .bold).foregroundStyle(DS.textSecondary)
            ColorPalettePicker(selection: $goal.colorIndex)
            Text("아이콘").appFont(DS.TextSize.caption, .bold).foregroundStyle(DS.textSecondary)
            IconPicker(selection: $goal.icon, color: Palette.color(goal.colorIndex))
            HStack {
                Spacer()
                Button("취소") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(isNew ? "추가" : "저장") {
                    let name = goal.name.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    if isNew {
                        store.addGoal(name: name, colorIndex: goal.colorIndex, icon: goal.icon)
                    } else {
                        goal.name = name
                        store.updateGoal(goal)
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.glassProminent)
                .tint(DS.ink)
                .disabled(goal.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
    }
}
