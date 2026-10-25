import SwiftUI

struct EventEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var event: Event
    let isNew: Bool
    @State private var alert: Int = -1
    @State private var confirmDelete = false

    private let alertOptions = [-1, 0, 5, 10, 15, 30, 60, 1440]

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("제목", text: $event.title)
                    Toggle("종일", isOn: $event.isAllDay)
                    DatePicker("시작", selection: $event.start,
                               displayedComponents: event.isAllDay ? .date : [.date, .hourAndMinute])
                    DatePicker("종료", selection: $event.end, in: event.start...,
                               displayedComponents: event.isAllDay ? .date : [.date, .hourAndMinute])
                }
                Section("색상") {
                    ColorPalettePicker(selection: $event.colorIndex, size: 20)
                }
                Section {
                    Picker("반복", selection: $event.repeatFrequency) {
                        ForEach(RepeatFrequency.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("알림", selection: $alert) {
                        ForEach(alertOptions, id: \.self) { m in
                            Text(m < 0 ? "없음" : NotificationManager.alertLabel(m)).tag(m)
                        }
                    }
                    Toggle("D-day로 상단 고정", isOn: $event.isDday)
                }
                Section("메모") {
                    TextField("메모", text: $event.memo, axis: .vertical).lineLimit(3...6)
                }
            }
            .formStyle(.grouped)

            HStack {
                if !isNew {
                    Button("삭제", role: .destructive) { confirmDelete = true }
                }
                Spacer()
                Button("취소") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(isNew ? "추가" : "저장", action: save)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.glassProminent)
                    .tint(DS.ink)
                    .disabled(event.title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 460, height: 620)
        .onAppear { alert = event.alertMinutes ?? -1 }
        .onChange(of: event.start) { old, new in
            // 시작을 옮기면 길이를 유지한 채 종료도 옮긴다
            event.end = event.end.addingTimeInterval(new.timeIntervalSince(old))
        }
        .confirmationDialog("이 일정을 삭제할까요?", isPresented: $confirmDelete) {
            Button("삭제", role: .destructive) {
                store.deleteEvent(event.id)
                dismiss()
            }
        }
    }

    private func save() {
        var e = event
        e.title = e.title.trimmingCharacters(in: .whitespaces)
        if e.isAllDay {
            e.start = e.start.startOfDay
            e.end = max(e.end, e.start).startOfDay
        }
        if e.end < e.start { e.end = e.start.addingTimeInterval(3600) }
        e.alertMinutes = alert < 0 ? nil : alert
        store.upsertEvent(e)
        if e.alertMinutes != nil {
            Task { await NotificationManager.shared.requestAuthorization() }
        }
        dismiss()
    }
}
