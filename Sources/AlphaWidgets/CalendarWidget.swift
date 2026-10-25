import SwiftUI
import WidgetKit

struct CalendarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AlphaCalendar", provider: AlphaProvider()) { entry in
            CalendarWidgetView(entry: entry)
                .alphaWidgetStyle(entry)
                .widgetURL(entry.url("calendar", date: entry.date))
        }
        .configurationDisplayName("캘린더")
        .description("오늘과 다음 일정, 이번 주, 이번 달 완료율을 보여 줘요.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct CalendarWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AlphaEntry

    var body: some View {
        if entry.isMissingData {
            MissingDataView(entry: entry)
        } else {
            switch family {
            case .systemSmall: small
            case .systemLarge: month
            default: week
            }
        }
    }

    private var cal: Calendar { entry.cal }

    /// 지금 이후 가장 가까운 일정 (7일 안)
    private var nextEvent: (event: Event, at: Date)? {
        let now = entry.date
        return entry.data.events
            .compactMap { e -> (Event, Date)? in
                if e.isAllDay {
                    return e.occurs(on: now, calendar: cal) ? (e, cal.startOfDay(for: now)) : nil
                }
                return e.nextOccurrence(after: now, calendar: cal, searchDays: 8).map { (e, $0) }
            }
            .filter { $0.1 < now.addingTimeInterval(7 * 86400) }
            .min { $0.1 < $1.1 }
            .map { (event: $0.0, at: $0.1) }
    }

    private var small: some View {
        let c = entry.data.completion(on: entry.date, calendar: cal)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(entry.date.formatted("EEEE")).font(entry.font(DS.TextSize.caption, .bold))
                        .foregroundStyle(DS.weekdayColor(entry.date, calendar: cal, base: DS.textSecondary))
                    Text(entry.date.formatted("d")).font(entry.font(40, .bold))
                }
                Spacer()
                DayStamp(done: c.done, total: c.total, color: entry.accent, size: 24)
            }
            Spacer(minLength: 0)
            if let next = nextEvent {
                VStack(alignment: .leading, spacing: 3) {
                    EventBar(title: next.event.title, color: Palette.color(next.event.colorIndex), size: DS.TextSize.label)
                    Text(next.event.isAllDay ? "종일" : relative(next.at))
                        .font(entry.font(DS.TextSize.micro)).foregroundStyle(DS.textSecondary)
                }
            } else {
                Text("다가오는 일정 없음").font(entry.font(DS.TextSize.label)).foregroundStyle(DS.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func relative(_ date: Date) -> String {
        if cal.isDate(date, inSameDayAs: entry.date) { return "오늘 " + date.formatted("a h:mm") }
        if let tomorrow = cal.date(byAdding: .day, value: 1, to: entry.date), cal.isDate(date, inSameDayAs: tomorrow) {
            return "내일 " + date.formatted("a h:mm")
        }
        return date.formatted("M/d (E) a h:mm")
    }

    private var week: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.date.formatted("yyyy년 M월")).font(entry.font(DS.TextSize.headline - 1, .bold))
                Spacer()
                let c = entry.data.completion(on: entry.date, calendar: cal)
                Text("오늘 \(c.done)/\(c.total)").font(entry.font(DS.TextSize.label)).foregroundStyle(DS.textSecondary)
            }
            HStack(spacing: 4) {
                ForEach(cal.days(inWeekOf: entry.date), id: \.self) { d in
                    Link(destination: entry.url("calendar", date: d)) {
                        dayColumn(d)
                    }
                }
            }
        }
    }

    private func dayColumn(_ d: Date) -> some View {
        let events = entry.data.events(on: d, calendar: cal)
        let c = entry.data.completion(on: d, calendar: cal)
        return VStack(spacing: 4) {
            Text(d.formatted("E")).font(entry.font(DS.TextSize.micro, .medium))
                .foregroundStyle(DS.weekdayColor(d, calendar: cal, base: DS.textSecondary))
            DayStamp(done: c.done, total: c.total, color: entry.accent, size: 20)
            DateNumber(date: d, calendar: cal, isSelected: cal.isDate(d, inSameDayAs: entry.date))
            VStack(spacing: 2) {
                ForEach(events.prefix(3)) { e in
                    RoundedRectangle(cornerRadius: DS.Radius.bar).fill(Palette.color(e.colorIndex)).frame(height: 4)
                }
            }
            .frame(height: 16, alignment: .top)
        }
        .frame(maxWidth: .infinity)
    }

    private var month: some View {
        let grid = cal.monthGrid(for: entry.date)
        let monthNo = cal.component(.month, from: entry.date)
        return VStack(spacing: 6) {
            HStack {
                Text(entry.date.formatted("yyyy년 M월")).font(entry.font(DS.TextSize.headline, .bold))
                Spacer()
                let c = entry.data.completion(on: entry.date, calendar: cal)
                Text("오늘 \(c.done)/\(c.total)").font(entry.font(DS.TextSize.label)).foregroundStyle(DS.textSecondary)
            }
            HStack(spacing: 0) {
                ForEach(Array(cal.orderedWeekdaySymbols.enumerated()), id: \.offset) { i, s in
                    Text(s).font(entry.font(DS.TextSize.micro, .medium))
                        .foregroundStyle(DS.weekdayColor(for: (i + cal.firstWeekday - 1) % 7 + 1, base: DS.textSecondary))
                        .frame(maxWidth: .infinity)
                }
            }
            Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                ForEach(0..<6, id: \.self) { row in
                    GridRow {
                        ForEach(0..<7, id: \.self) { col in
                            let d = grid[row * 7 + col]
                            Link(destination: entry.url("calendar", date: d)) {
                                monthCell(d, inMonth: cal.component(.month, from: d) == monthNo)
                            }
                        }
                    }
                }
            }
        }
    }

    private func monthCell(_ d: Date, inMonth: Bool) -> some View {
        let c = entry.data.completion(on: d, calendar: cal)
        return VStack(spacing: 1) {
            DayStamp(done: c.done, total: c.total, color: entry.accent, size: 16, showsCount: false)
            DateNumber(date: d, calendar: cal, isSelected: cal.isDate(d, inSameDayAs: entry.date), size: DS.TextSize.micro)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(inMonth ? 1 : 0.35)
    }
}
