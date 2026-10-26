import Foundation
import SwiftUI
import Observation
import WidgetKit

/// 모든 데이터를 로컬 JSON 파일 하나에 저장한다. 서버 없음.
@Observable
final class Store {
    static let shared = Store()

    private(set) var data = AppData()
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    static var directory: URL { SharedStorage.directory }
    static var fileURL: URL { SharedStorage.dataURL }

    private var cal: Calendar { .app }

    // MARK: 불러오기 / 저장

    func load() {
        try? FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
        if let decoded = SharedStorage.readData() {
            data = decoded
        } else {
            seed()
        }
        ensureMajorEventGoal()
    }

    /// "주요 이벤트" 목표. 기존 데이터에도 한 번 만들어 주고, 지우면 다시 만들지 않는다.
    static let majorEventGoalName = "주요 이벤트"

    private func ensureMajorEventGoal() {
        let key = "majorEventGoalCreated"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        guard !data.goals.contains(where: { $0.name == Self.majorEventGoalName }) else { return }
        data.goals.insert(Goal(name: Self.majorEventGoalName, colorIndex: 0, icon: "star.fill",
                               order: (data.goals.map(\.order).min() ?? 1) - 1), at: 0)
        scheduleSave()
    }

    /// 그날 "주요 이벤트" 목표에 할 일이 하나라도 적혀 있는가
    /// 그날 완료한 할 일을 목표(색) 순서대로 센다 — 달력 도장에 색을 쌓는 데 쓴다
    func doneSegments(on day: Date) -> [(color: Color, count: Int)] {
        let done = todos(on: day).filter(\.isDone)
        return allGoalsSorted.compactMap { g in
            let n = done.filter { $0.goalID == g.id }.count
            return n > 0 ? (color: Palette.color(g.colorIndex), count: n) : nil
        }
    }

    func hasMajorEvent(on day: Date) -> Bool {
        let ids = Set(data.goals.filter { $0.name == Self.majorEventGoalName }.map(\.id))
        guard !ids.isEmpty else { return false }
        let day = cal.startOfDay(for: day)
        return data.todos.contains { $0.date == day && ids.contains($0.goalID) }
    }

    /// 위젯이 파일을 바꿨을 때 다시 읽는다.
    func reloadFromDisk() {
        saveTask?.cancel()
        if let decoded = SharedStorage.readData() { data = decoded }
        NotificationManager.shared.rescheduleReminders(store: self)
    }

    /// 앱 밖의 규칙(TimerLogic 등)으로 데이터를 직접 고칠 때 쓴다.
    func mutate(_ body: (inout AppData) -> Void) {
        body(&data)
        scheduleSave()
    }

    private func seed() {
        data = AppData()
        data.goals = [
            Goal(name: Self.majorEventGoalName, colorIndex: 0, icon: "star.fill", order: -1),
            Goal(name: "공부", colorIndex: 5, icon: "book.closed", order: 0),
            Goal(name: "운동", colorIndex: 3, icon: "figure.run", order: 1),
            Goal(name: "일상", colorIndex: 1, icon: "house", order: 2),
        ]
        let today = Date().startOfDay
        data.todos = [
            Todo(title: "ALPHA 육성 센터 둘러보기", date: today, order: 0, goalID: data.goals[1].id),
            Todo(title: "포모도로 한 번 돌려보기", date: today, order: 1, goalID: data.goals[1].id),
        ]
        scheduleSave()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let self else { return }
            self.saveNow()
            NotificationManager.shared.rescheduleReminders(store: self)
        }
    }

    func saveNow() {
        do {
            try SharedStorage.write(data, to: Self.fileURL)
            WidgetReloader.reload()
        } catch {
            NSLog("저장 실패: \(error)")
        }
    }

    // MARK: 백업 / 복원 / 초기화

    func exportData() throws -> Data { try SharedStorage.encoder.encode(data) }

    func importData(_ raw: Data) throws {
        data = try SharedStorage.decoder.decode(AppData.self, from: raw)
        scheduleSave()
    }

    func resetAll() {
        seed()
    }

    // MARK: 목표

    var activeGoals: [Goal] { data.goals.filter { !$0.isArchived }.sorted { $0.order < $1.order } }
    var allGoalsSorted: [Goal] { data.goals.sorted { $0.order < $1.order } }
    func goal(_ id: UUID?) -> Goal? { data.goals.first { $0.id == id } }

    @discardableResult
    func addGoal(name: String, colorIndex: Int, icon: String) -> Goal {
        let g = Goal(name: name, colorIndex: colorIndex, icon: icon, order: (data.goals.map(\.order).max() ?? -1) + 1)
        data.goals.append(g)
        scheduleSave()
        return g
    }

    func updateGoal(_ goal: Goal) {
        guard let i = data.goals.firstIndex(where: { $0.id == goal.id }) else { return }
        data.goals[i] = goal
        scheduleSave()
    }

    func deleteGoal(_ id: UUID) {
        data.goals.removeAll { $0.id == id }
        data.todos.removeAll { $0.goalID == id }
        data.routines.removeAll { $0.goalID == id }
        scheduleSave()
    }

    func reorderGoals(_ ordered: [UUID]) {
        for (n, id) in ordered.enumerated() {
            if let i = data.goals.firstIndex(where: { $0.id == id }) { data.goals[i].order = n }
        }
        scheduleSave()
    }

    /// 목표 dragged를 target 앞으로 옮긴다.
    func moveGoal(_ dragged: UUID, before target: UUID) {
        guard dragged != target else { return }
        var ids = allGoalsSorted.map(\.id)
        ids.removeAll { $0 == dragged }
        let at = ids.firstIndex(of: target) ?? ids.endIndex
        ids.insert(dragged, at: at)
        reorderGoals(ids)
    }

    // MARK: 할 일

    func todo(_ id: UUID?) -> Todo? { data.todos.first { $0.id == id } }

    func todos(on day: Date) -> [Todo] {
        let day = cal.startOfDay(for: day)
        return data.todos.filter { $0.date == day }.sorted { $0.order < $1.order }
    }

    func todos(on day: Date, goal: UUID) -> [Todo] {
        todos(on: day).filter { $0.goalID == goal }
    }

    /// 목표 순서대로 정렬한 그날의 할 일
    func orderedTodos(on day: Date) -> [Todo] { data.todos(on: day, calendar: cal) }

    func completion(on day: Date) -> (done: Int, total: Int) {
        let items = todos(on: day)
        return (items.filter(\.isDone).count, items.count)
    }

    @discardableResult
    func addTodo(title: String, goalID: UUID, date: Date) -> Todo? {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        let day = cal.startOfDay(for: date)
        let next = (todos(on: day, goal: goalID).map(\.order).max() ?? -1) + 1
        let t = Todo(title: title, date: day, order: next, goalID: goalID)
        data.todos.append(t)
        scheduleSave()
        return t
    }

    func updateTodo(_ todo: Todo) {
        guard let i = data.todos.firstIndex(where: { $0.id == todo.id }) else { return }
        var t = todo
        t.date = cal.startOfDay(for: t.date)
        data.todos[i] = t
        scheduleSave()
    }

    func toggleTodo(_ id: UUID) {
        guard let i = data.todos.firstIndex(where: { $0.id == id }) else { return }
        data.todos[i].isDone.toggle()
        data.todos[i].doneAt = data.todos[i].isDone ? Date() : nil
        scheduleSave()
    }

    func deleteTodo(_ id: UUID) {
        guard let t = todo(id) else { return }
        if let rid = t.routineID, let rDate = t.routineDate,
           let i = data.routines.firstIndex(where: { $0.id == rid }) {
            data.routines[i].skippedDates.insert(rDate)
        }
        data.todos.removeAll { $0.id == id }
        scheduleSave()
    }

    func moveTodo(_ id: UUID, to date: Date) {
        guard var t = todo(id) else { return }
        let day = cal.startOfDay(for: date)
        guard t.date != day else { return }
        t.date = day
        t.order = (todos(on: day, goal: t.goalID).map(\.order).max() ?? -1) + 1
        if let r = t.reminderAt {
            // 알림 시각도 같은 날짜 차이만큼 옮긴다
            let comps = cal.dateComponents([.hour, .minute], from: r)
            t.reminderAt = cal.date(bySettingHour: comps.hour ?? 9, minute: comps.minute ?? 0, second: 0, of: day)
        }
        updateTodo(t)
    }

    /// 할 일 dragged를 target 앞으로 옮긴다 (다른 목표로도 이동 가능).
    func moveTodo(_ dragged: UUID, before target: UUID) {
        guard dragged != target, var d = todo(dragged), let tgt = todo(target) else { return }
        d.goalID = tgt.goalID
        d.date = tgt.date
        var list = todos(on: tgt.date, goal: tgt.goalID).filter { $0.id != dragged }
        let at = list.firstIndex { $0.id == target } ?? list.endIndex
        list.insert(d, at: at)
        for (n, var item) in list.enumerated() {
            item.order = n
            if let i = data.todos.firstIndex(where: { $0.id == item.id }) { data.todos[i] = item }
        }
        scheduleSave()
    }

    /// 할 일을 목표의 맨 끝으로 옮긴다.
    func moveTodo(_ dragged: UUID, toGoal goalID: UUID, on day: Date) {
        guard var d = todo(dragged) else { return }
        let day = cal.startOfDay(for: day)
        d.order = (todos(on: day, goal: goalID).filter { $0.id != dragged }.map(\.order).max() ?? -1) + 1
        d.goalID = goalID
        d.date = day
        updateTodo(d)
    }

    func addPomodoro(toTodo id: UUID) {
        guard let i = data.todos.firstIndex(where: { $0.id == id }) else { return }
        data.todos[i].pomodoroCount += 1
        scheduleSave()
    }

    /// 그날 끝내지 못한 할 일
    func undoneTodos(on day: Date) -> [Todo] { todos(on: day).filter { !$0.isDone } }

    /// 그날 끝내지 못한 할 일을 모두 target 날짜로 옮긴다. 옮긴 개수를 돌려준다.
    @discardableResult
    func moveUndoneTodos(from day: Date, to target: Date) -> Int {
        let target = cal.startOfDay(for: target)
        guard cal.startOfDay(for: day) != target else { return 0 }
        let ids = undoneTodos(on: day).map(\.id)
        for id in ids { moveTodo(id, to: target) }
        return ids.count
    }

    /// 그날 끝내지 못한 할 일을 다음 날로 옮긴다.
    @discardableResult
    func moveUndoneTodosToNextDay(from day: Date) -> Int {
        moveUndoneTodos(from: day, to: cal.startOfDay(for: day).adding(days: 1))
    }

    /// 지난 미완료 할 일을 오늘로 옮긴다.
    func carryOverIfNeeded() {
        guard UserDefaults.standard.bool(forKey: Keys.autoCarryOver) else { return }
        let today = cal.startOfDay(for: Date())
        let stale = data.todos.filter { !$0.isDone && $0.date < today && $0.routineID == nil }
        for t in stale { moveTodo(t.id, to: today) }
    }

    // MARK: 루틴

    func routine(_ id: UUID?) -> Routine? { data.routines.first { $0.id == id } }
    var routines: [Routine] { data.routines }

    /// 루틴 탭에서 추가·수정. 수정하면 오늘 이후 미완료 인스턴스를 지우고 새 규칙으로 다시 만든다.
    func upsertRoutine(_ r: Routine) {
        let today = cal.startOfDay(for: Date())
        if let i = data.routines.firstIndex(where: { $0.id == r.id }) {
            var r = r
            r.skippedDates = data.routines[i].skippedDates
            data.routines[i] = r
            data.todos.removeAll { $0.routineID == r.id && !$0.isDone && $0.date >= today }
            for j in data.todos.indices where data.todos[j].routineID == r.id && data.todos[j].date < today {
                data.todos[j].goalID = r.goalID
            }
        } else {
            data.routines.append(r)
        }
        scheduleSave()
        materializeRoutines(for: today)
    }

    /// 할 일을 루틴으로 만든다. 기존 할 일이 첫 인스턴스가 된다.
    func makeRoutine(from todoID: UUID, rule: RepeatRule) {
        guard var t = todo(todoID) else { return }
        if let rid = t.routineID, let i = data.routines.firstIndex(where: { $0.id == rid }) {
            data.routines[i].rule = rule
            data.routines[i].title = t.title
            data.routines[i].goalID = t.goalID
            scheduleSave()
            return
        }
        let r = Routine(title: t.title, goalID: t.goalID, rule: rule, startDate: t.date, memo: t.memo)
        data.routines.append(r)
        t.routineID = r.id
        t.routineDate = t.date
        updateTodo(t)
    }

    /// 루틴을 멈춘다. 오늘 이후의 미완료 인스턴스는 지운다.
    func stopRoutine(_ id: UUID) {
        let today = cal.startOfDay(for: Date())
        data.routines.removeAll { $0.id == id }
        data.todos.removeAll { $0.routineID == id && !$0.isDone && $0.date > today }
        for i in data.todos.indices where data.todos[i].routineID == id {
            data.todos[i].routineID = nil
        }
        scheduleSave()
    }

    /// 날짜를 열 때 그날의 루틴 인스턴스를 만든다.
    func materializeRoutines(for day: Date) {
        let day = cal.startOfDay(for: day)
        var changed = false
        for r in data.routines where r.rule.matches(day, start: r.startDate, calendar: cal) {
            guard !r.skippedDates.contains(day) else { continue }
            let exists = data.todos.contains { $0.routineID == r.id && $0.routineDate == day }
            guard !exists, data.goals.contains(where: { $0.id == r.goalID }) else { continue }
            let next = (todos(on: day, goal: r.goalID).map(\.order).max() ?? -1) + 1
            data.todos.append(Todo(title: r.title, date: day, memo: r.memo, order: next,
                                   goalID: r.goalID, routineID: r.id, routineDate: day))
            changed = true
        }
        if changed { scheduleSave() }
    }

    // MARK: 일정

    func events(on day: Date) -> [Event] { data.events(on: day, calendar: cal) }

    var ddayEvents: [Event] {
        let now = Date()
        return data.events.filter(\.isDday)
            .compactMap { e -> (Event, Date)? in
                if let n = e.nextOccurrence(after: cal.startOfDay(for: now), calendar: cal) { return (e, n) }
                return (e, e.start)
            }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    func upsertEvent(_ e: Event) {
        if let i = data.events.firstIndex(where: { $0.id == e.id }) { data.events[i] = e } else { data.events.append(e) }
        scheduleSave()
    }

    func deleteEvent(_ id: UUID) {
        data.events.removeAll { $0.id == id }
        scheduleSave()
    }

    // MARK: 포모도로 기록

    func addSession(_ s: PomodoroSession) {
        data.sessions.append(s)
        scheduleSave()
    }

    func focusSessions(on day: Date) -> [PomodoroSession] {
        data.sessions.filter { $0.kind == .focus && $0.completed && cal.isDate($0.start, inSameDayAs: day) }
    }

    func focusMinutes(on day: Date) -> Int {
        Int(focusSessions(on: day).reduce(0) { $0 + $1.duration } / 60)
    }

    // MARK: 하루 회고

    func note(on day: Date) -> DailyNote {
        let day = cal.startOfDay(for: day)
        return data.notes.first { $0.date == day } ?? DailyNote(date: day)
    }

    /// 쓴 일기 전체 (최신순)
    var diaryEntries: [DailyNote] {
        data.notes.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !$0.mood.isEmpty }
            .sorted { $0.date > $1.date }
    }

    /// 그날 일기를 썼는가
    func hasDiary(on day: Date) -> Bool {
        let day = cal.startOfDay(for: day)
        return data.notes.contains { $0.date == day && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    func saveNote(_ note: DailyNote) {
        data.notes.removeAll { $0.date == note.date }
        if !note.text.isEmpty || !note.mood.isEmpty { data.notes.append(note) }
        scheduleSave()
    }
}

/// 데이터가 바뀌면 위젯 타임라인을 다시 그리게 한다 (짧은 시간에 여러 번 불려도 한 번만).
enum WidgetReloader {
    private static var pending: Task<Void, Never>?

    static func reload() {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
