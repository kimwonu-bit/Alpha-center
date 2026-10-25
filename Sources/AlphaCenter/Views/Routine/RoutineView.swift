import SwiftUI

// MARK: - 루틴 탭

struct RoutineView: View {
    @Environment(Store.self) private var store
    @State private var editing: Routine?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.l) {
                HStack {
                    Text("루틴").appFont(DS.TextSize.title, .bold).foregroundStyle(DS.text)
                    Spacer()
                    Button { startNew() } label: { Label("루틴 추가", systemImage: "plus") }
                        .buttonStyle(.glassProminent)
                        .tint(DS.ink)
                        .disabled(store.activeGoals.isEmpty)
                }
                if store.routines.isEmpty {
                    empty
                } else {
                    ForEach(store.activeGoals) { goal in
                        let items = store.routines.filter { $0.goalID == goal.id }
                        if !items.isEmpty {
                            VStack(alignment: .leading, spacing: DS.Space.xs) {
                                GoalChip(title: goal.name, icon: goal.icon, color: Palette.color(goal.colorIndex), showsPlus: false)
                                ForEach(items) { r in
                                    RoutineRow(routine: r) { editing = r }
                                }
                            }
                        }
                    }
                }
            }
            .padding(DS.Space.xl)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(DS.bg)
        .sheet(item: $editing) { r in RoutineEditor(routine: r) }
    }

    private func startNew() {
        guard let goal = store.activeGoals.first else { return }
        editing = Routine(title: "", goalID: goal.id, rule: RepeatRule(frequency: .daily), startDate: Date().startOfDay)
    }

    private var empty: some View {
        VStack(spacing: DS.Space.s) {
            Image(systemName: "repeat").font(.system(size: 28)).foregroundStyle(DS.textSecondary)
            Text("등록된 루틴이 없어요").appFont(DS.TextSize.headline, .bold)
            Text("매일·매주·매월 반복할 일을 등록하면\n해당 날짜를 열 때 자동으로 할 일이 만들어져요.")
                .appFont(DS.TextSize.caption).foregroundStyle(DS.textSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

private struct RoutineRow: View {
    @Environment(Store.self) private var store
    let routine: Routine
    let edit: () -> Void
    @State private var confirmDelete = false

    var body: some View {
        HStack(spacing: DS.Space.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text(routine.title).appFont(DS.TextSize.body, .medium).foregroundStyle(DS.text)
                Text(summary).appFont(DS.TextSize.caption).foregroundStyle(DS.textSecondary)
            }
            Spacer()
            Button("수정", action: edit).buttonStyle(.plain).appFont(DS.TextSize.caption, .bold)
                .foregroundStyle(DS.textSecondary)
            Button { confirmDelete = true } label: { Image(systemName: "trash") }
                .buttonStyle(.plain).foregroundStyle(DS.textSecondary).help("루틴 삭제")
        }
        .padding(.vertical, 8).padding(.horizontal, DS.Space.s)
        .background(DS.surface, in: .rect(cornerRadius: DS.Radius.tile))
        .contentShape(.rect)
        .onTapGesture(perform: edit)
        .confirmationDialog("'\(routine.title)' 루틴을 삭제할까요?", isPresented: $confirmDelete) {
            Button("삭제", role: .destructive) { store.stopRoutine(routine.id) }
        } message: {
            Text("오늘 이후의 미완료 할 일도 함께 지워져요. 지난 기록은 남아요.")
        }
    }

    private var summary: String {
        let symbols = ["일", "월", "화", "수", "목", "금", "토"]
        var text = routine.rule.frequency.label
        if routine.rule.frequency == .weekly {
            let wds = routine.rule.weekdays.isEmpty
                ? [Calendar.app.component(.weekday, from: routine.startDate)] : routine.rule.weekdays.sorted()
            text += " " + wds.map { symbols[$0 - 1] }.joined(separator: "·")
        }
        text += " · " + routine.startDate.formatted("M월 d일") + "부터"
        if let end = routine.rule.endDate { text += " " + end.formatted("M월 d일") + "까지" }
        return text
    }
}

// MARK: - 추가 / 수정 시트

struct RoutineEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var routine: Routine
    @State private var hasEnd = false
    @State private var endDate = Date()
    private let isNew: Bool

    init(routine: Routine) {
        _routine = State(initialValue: routine)
        isNew = routine.title.isEmpty
        _hasEnd = State(initialValue: routine.rule.endDate != nil)
        _endDate = State(initialValue: routine.rule.endDate ?? Calendar.app.date(byAdding: .month, value: 1, to: routine.startDate) ?? routine.startDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section {
                    TextField("제목", text: $routine.title)
                    Picker("목표", selection: $routine.goalID) {
                        ForEach(store.activeGoals) { g in Label(g.name, systemImage: g.icon).tag(g.id) }
                    }
                    TextField("메모", text: $routine.memo, axis: .vertical).lineLimit(2...4)
                }
                Section("반복") {
                    Picker("주기", selection: $routine.rule.frequency) {
                        ForEach([RepeatFrequency.daily, .weekly, .monthly, .yearly]) { Text($0.label).tag($0) }
                    }
                    if routine.rule.frequency == .weekly {
                        WeekdayPicker(selection: $routine.rule.weekdays)
                    }
                    DatePicker("시작일", selection: $routine.startDate, displayedComponents: .date)
                    Toggle("종료일", isOn: $hasEnd)
                    if hasEnd {
                        DatePicker("종료일", selection: $endDate, in: routine.startDate..., displayedComponents: .date)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                if !isNew {
                    Button("삭제", role: .destructive) {
                        store.stopRoutine(routine.id)
                        dismiss()
                    }
                }
                Spacer()
                Button("취소") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("저장", action: save)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.glassProminent)
                    .tint(DS.ink)
                    .disabled(routine.title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 460, height: 520)
    }

    private func save() {
        var r = routine
        r.title = r.title.trimmingCharacters(in: .whitespacesAndNewlines)
        r.startDate = Calendar.app.startOfDay(for: r.startDate)
        r.rule.endDate = hasEnd ? Calendar.app.startOfDay(for: endDate) : nil
        if r.rule.frequency != .weekly { r.rule.weekdays = [] }
        store.upsertRoutine(r)
        dismiss()
    }
}
