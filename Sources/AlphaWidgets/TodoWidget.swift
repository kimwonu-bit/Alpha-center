import AppIntents
import SwiftUI
import WidgetKit

struct TodayTodoWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayTodo", provider: AlphaProvider()) { entry in
            TodayTodoView(entry: entry)
                .alphaWidgetStyle(entry)
                .widgetURL(entry.url("todo", date: entry.date))
        }
        .configurationDisplayName("오늘의 할 일")
        .description("완료율을 보고, 체크박스로 바로 완료해요.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct TodayTodoView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AlphaEntry

    var body: some View {
        if entry.isMissingData {
            MissingDataView(entry: entry)
        } else {
            switch family {
            case .systemSmall: small
            case .systemLarge: list(maxRows: 11, grouped: true)
            default: medium
            }
        }
    }

    private var todos: [Todo] { entry.data.todos(on: entry.date, calendar: entry.cal) }
    private var completion: (done: Int, total: Int) { entry.data.completion(on: entry.date, calendar: entry.cal) }

    private func color(_ t: Todo) -> Color { Palette.color(entry.data.goal(t.goalID)?.colorIndex ?? 0) }

    /// 미완료 먼저
    private var sorted: [Todo] { todos.filter { !$0.isDone } + todos.filter(\.isDone) }

    private var countText: String? {
        completion.total == 0 ? nil : "\(completion.done)/\(completion.total)"
    }

    private var empty: some View {
        VStack(spacing: 6) {
            DayStamp(done: 0, total: 0, size: 28)
            Text("오늘 할 일이 없어요").font(entry.font(DS.TextSize.caption)).foregroundStyle(DS.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var small: some View {
        let shown = Array(sorted.prefix(4))
        return VStack(alignment: .leading, spacing: 7) {
            WidgetTodayHeader(entry: entry, trailing: countText)
            if todos.isEmpty {
                empty
            } else {
                ForEach(shown) { row($0, size: DS.TextSize.caption) }
                Spacer(minLength: 0)
                if todos.count > shown.count {
                    Text("외 \(todos.count - shown.count)개").font(entry.font(DS.TextSize.micro)).foregroundStyle(DS.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// 투두메이트 위젯처럼 2열
    private var medium: some View {
        let shown = Array(sorted.prefix(8))
        let half = (shown.count + 1) / 2
        return VStack(alignment: .leading, spacing: 8) {
            WidgetTodayHeader(entry: entry, trailing: countText)
            if todos.isEmpty {
                empty
            } else {
                HStack(alignment: .top, spacing: DS.Space.s) {
                    VStack(alignment: .leading, spacing: 7) { ForEach(shown.prefix(half)) { row($0) } }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 7) { ForEach(shown.dropFirst(half)) { row($0) } }
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// 목표별로 묶은 목록
    private func list(maxRows: Int, grouped: Bool) -> some View {
        let shown = Array(todos.prefix(maxRows))
        return VStack(alignment: .leading, spacing: 6) {
            WidgetTodayHeader(entry: entry, trailing: countText)
                .padding(.bottom, 2)
            if todos.isEmpty {
                empty
            } else {
                ForEach(Array(shown.enumerated()), id: \.element.id) { i, t in
                    if i == 0 || shown[i - 1].goalID != t.goalID, let g = entry.data.goal(t.goalID) {
                        HStack(spacing: 4) {
                            Image(systemName: g.icon).font(.system(size: 9, weight: .semibold)).foregroundStyle(DS.textSecondary)
                            Text(g.name).font(entry.font(DS.TextSize.label, .bold)).foregroundStyle(Palette.color(g.colorIndex))
                        }
                        .padding(.horizontal, 8)
                        .frame(height: 20)
                        .background(DS.surface, in: .capsule)
                        .padding(.top, i == 0 ? 0 : 4)
                    }
                    row(t)
                }
                Spacer(minLength: 0)
                if todos.count > shown.count {
                    Text("외 \(todos.count - shown.count)개").font(entry.font(DS.TextSize.micro)).foregroundStyle(DS.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ t: Todo, size: CGFloat = DS.TextSize.caption + 1) -> some View {
        Button(intent: ToggleTodoIntent(todoID: t.id)) {
            HStack(spacing: 7) {
                TodoCheckbox(isOn: t.isDone, color: color(t), size: 15, animated: false)
                Text(t.title)
                    .font(entry.font(size))
                    .foregroundStyle(DS.text)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if t.pomodoroCount > 0 {
                    Text("🍅\(t.pomodoroCount)").font(.system(size: 10))
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
