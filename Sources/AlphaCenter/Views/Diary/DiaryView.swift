import SwiftUI

// MARK: - 일기 모아보기 탭

struct DiaryView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @State private var query = ""

    private var entries: [DailyNote] {
        let all = store.diaryEntries
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? all : all.filter { $0.text.localizedCaseInsensitiveContains(q) }
    }

    /// 월별로 묶는다 (최신 월이 먼저)
    private var months: [(title: String, items: [DailyNote])] {
        let cal = Calendar.app
        let groups = Dictionary(grouping: entries) { cal.dateComponents([.year, .month], from: $0.date) }
        return groups.keys
            .sorted { ($0.year ?? 0, $0.month ?? 0) > ($1.year ?? 0, $1.month ?? 0) }
            .map { key in
                let items = groups[key] ?? []
                return ("\(key.year ?? 0)년 \(key.month ?? 0)월", items)
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.l) {
                HStack {
                    Text("일기").appFont(DS.TextSize.title, .bold).foregroundStyle(DS.text)
                    Spacer()
                    Text("\(store.diaryEntries.count)편").appFont(DS.TextSize.caption).foregroundStyle(DS.textSecondary)
                }
                searchField
                if entries.isEmpty {
                    empty
                } else {
                    ForEach(months, id: \.title) { month in
                        VStack(alignment: .leading, spacing: DS.Space.s) {
                            Text(month.title).appFont(DS.TextSize.headline, .bold).foregroundStyle(DS.textSecondary)
                            ForEach(month.items) { note in
                                DiaryCard(note: note) { router.openTodos(on: note.date) }
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
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(DS.textSecondary)
            TextField("일기 검색", text: $query).textFieldStyle(.plain).appFont(DS.TextSize.body)
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(DS.textSecondary)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(DS.surface, in: .rect(cornerRadius: DS.Radius.tile))
    }

    private var empty: some View {
        VStack(spacing: DS.Space.s) {
            Image(systemName: "book.closed").font(.system(size: 28)).foregroundStyle(DS.textSecondary)
            Text(query.isEmpty ? "아직 쓴 일기가 없어요" : "검색 결과가 없어요").appFont(DS.TextSize.headline, .bold)
            if query.isEmpty {
                Text("투두 화면 아래의 일기 카드에 한 줄을 남기면 여기에 모여요.")
                    .appFont(DS.TextSize.caption).foregroundStyle(DS.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

private struct DiaryCard: View {
    let note: DailyNote
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(alignment: .top, spacing: DS.Space.s) {
                VStack(spacing: 2) {
                    Text(note.date.formatted("d")).appFont(DS.TextSize.title, .bold)
                    Text(note.date.formatted("E")).appFont(DS.TextSize.label).foregroundStyle(DS.textSecondary)
                }
                .frame(width: 44)
                VStack(alignment: .leading, spacing: 4) {
                    if !note.mood.isEmpty { Text(note.mood).font(.system(size: 22)) }
                    if !note.text.isEmpty {
                        Text(note.text).appFont(DS.TextSize.body).multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(DS.text)
            .padding(DS.Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DiaryStyle.gradient(opacity: 0.3), in: .rect(cornerRadius: DS.Radius.card, style: .continuous))
            .glassEffect(.regular, in: .rect(cornerRadius: DS.Radius.card))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help("이 날짜의 투두 화면으로 이동")
    }
}
