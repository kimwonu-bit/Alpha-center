import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(Store.self) private var store
    @State private var fonts = FontManager.shared
    @State private var notifications = NotificationManager.shared

    @AppStorage(Keys.startTab) private var startTab: AppTab = .todo
    @AppStorage(Keys.showMenuBar) private var showMenuBar = true
    @AppStorage(Keys.weekStartsOnMonday) private var weekStartsOnMonday = false
    @AppStorage(Keys.autoCarryOver) private var autoCarryOver = false
    @AppStorage(Keys.checkSound) private var checkSound = true
    @AppStorage(Keys.focusMinutes) private var focusMinutes = 25
    @AppStorage(Keys.shortBreakMinutes) private var shortBreakMinutes = 5
    @AppStorage(Keys.longBreakMinutes) private var longBreakMinutes = 15
    @AppStorage(Keys.longBreakInterval) private var longBreakInterval = 4
    @AppStorage(Keys.autoStartBreak) private var autoStartBreak = false
    @AppStorage(Keys.autoStartFocus) private var autoStartFocus = false
    @AppStorage(Keys.soundName) private var soundName = "Glass"
    @AppStorage(Keys.soundVolume) private var soundVolume = 0.8
    @AppStorage(Keys.accentIndex) private var accentIndex = Palette.defaultAccent

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var message: String?
    @State private var confirmReset = false
    @State private var confirmImport: Data?

    var body: some View {
        Form {
            generalSection
            todoSection
            pomodoroSection
            notificationSection
            appearanceSection
            dataSection
            infoSection
        }
        .formStyle(.grouped)
        .navigationTitle("설정")
        .task { await notifications.refreshStatus() }
        .alert("모든 데이터를 초기화할까요?", isPresented: $confirmReset) {
            Button("초기화", role: .destructive) {
                store.resetAll()
                message = "초기화했어요."
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("목표, 할 일, 일정, 포모도로 기록이 모두 지워져요. 먼저 백업을 내보내 두는 것을 권장해요.")
        }
        .alert("백업에서 복원할까요?", isPresented: Binding(get: { confirmImport != nil }, set: { if !$0 { confirmImport = nil } })) {
            Button("복원", role: .destructive) {
                guard let raw = confirmImport else { return }
                do {
                    try store.importData(raw)
                    message = "복원했어요."
                } catch {
                    message = "복원 실패: 올바른 백업 파일이 아니에요."
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("지금 데이터는 백업 파일의 내용으로 바뀌어요.")
        }
    }

    private var generalSection: some View {
        Section("일반") {
            Picker("시작 화면", selection: $startTab) {
                ForEach(AppTab.allCases.filter { $0 != .settings }) { Text($0.label).tag($0) }
            }
            Toggle("메뉴 막대에 타이머 표시", isOn: $showMenuBar)
            Toggle("로그인 시 자동 실행", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, on in setLaunchAtLogin(on) }
        }
    }

    private var todoSection: some View {
        Section("투두") {
            Toggle("지난 미완료 할 일을 오늘로 자동 이월", isOn: $autoCarryOver)
                .onChange(of: autoCarryOver) { _, on in if on { store.carryOverIfNeeded() } }
            Picker("주 시작 요일", selection: $weekStartsOnMonday) {
                Text("일요일").tag(false)
                Text("월요일").tag(true)
            }
            Toggle("체크할 때 효과음", isOn: $checkSound)
        }
    }

    private var pomodoroSection: some View {
        Section("포모도로") {
            Stepper("집중 \(focusMinutes)분", value: $focusMinutes, in: 1...120)
            Stepper("짧은 휴식 \(shortBreakMinutes)분", value: $shortBreakMinutes, in: 1...60)
            Stepper("긴 휴식 \(longBreakMinutes)분", value: $longBreakMinutes, in: 1...90)
            Stepper("긴 휴식 주기: 집중 \(longBreakInterval)회마다", value: $longBreakInterval, in: 2...10)
            Toggle("집중이 끝나면 휴식 자동 시작", isOn: $autoStartBreak)
            Toggle("휴식이 끝나면 다음 집중 자동 시작", isOn: $autoStartFocus)
            HStack {
                Picker("알림음", selection: $soundName) {
                    ForEach(SoundPlayer.systemSounds, id: \.self) { Text($0).tag($0) }
                }
                Button { SoundPlayer.play(soundName) } label: { Image(systemName: "play.circle") }
                    .buttonStyle(.borderless)
                    .help("미리 듣기")
            }
            LabeledContent("볼륨") {
                Slider(value: $soundVolume, in: 0...1, onEditingChanged: previewVolume)
                    .frame(width: 200)
            }
        }
        .onChange(of: focusMinutes) { TimerEngine.shared.refreshIdleDuration() }
        .onChange(of: shortBreakMinutes) { TimerEngine.shared.refreshIdleDuration() }
        .onChange(of: longBreakMinutes) { TimerEngine.shared.refreshIdleDuration() }
    }

    private var notificationSection: some View {
        Section("알림") {
            LabeledContent("권한 상태") {
                Text(statusText).foregroundStyle(notifications.isAuthorized ? .green : .orange)
            }
            HStack {
                if notifications.status == .notDetermined {
                    Button("알림 허용 요청") { Task { await notifications.requestAuthorization() } }
                }
                Button("시스템 설정 열기") { notifications.openSystemSettings() }
                Button("테스트 알림 보내기") { notifications.sendTest() }
            }
        }
    }

    private var appearanceSection: some View {
        Section("모양") {
            LabeledContent("강조 색상") {
                ColorPalettePicker(selection: $accentIndex, size: 18)
            }
            ForEach(FontOption.allCases) { option in
                FontRow(option: option, selected: fonts.selected == option, available: fonts.isAvailable(option)) {
                    fonts.selected = option
                }
            }
            HStack {
                Button("서체 폴더 열기") { fonts.openFontsFolder() }
                Button("서체 다시 불러오기") { fonts.registerFonts() }
                Spacer()
            }
            Text("설치되지 않은 서체는 .ttf / .otf 파일을 서체 폴더에 넣고 ‘다시 불러오기’를 누르면 쓸 수 있어요. 배포 전 각 서체의 임베딩 라이선스를 확인하세요.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var dataSection: some View {
        Section("데이터") {
            LabeledContent("저장 위치") {
                Button(Store.fileURL.path(percentEncoded: false)) {
                    NSWorkspace.shared.activateFileViewerSelecting([Store.fileURL])
                }
                .buttonStyle(.link)
                .lineLimit(1)
                .truncationMode(.middle)
            }
            HStack {
                Button("백업 내보내기…", action: exportBackup)
                Button("백업에서 복원…", action: pickBackup)
                Spacer()
                Button("모든 데이터 초기화…", role: .destructive) { confirmReset = true }
            }
            if let message {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var infoSection: some View {
        Section("정보") {
            LabeledContent("앱", value: AppInfo.name)
            LabeledContent("버전", value: AppInfo.version)
            Text("서버도 계정도 없어요. 모든 데이터는 이 Mac에만 저장돼요.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func previewVolume(_ editing: Bool) {
        if !editing { SoundPlayer.play(soundName) }
    }

    private var statusText: String {
        switch notifications.status {
        case .authorized: "허용됨"
        case .provisional: "임시 허용"
        case .denied: "거부됨"
        case .notDetermined: "아직 묻지 않음"
        default: "알 수 없음"
        }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            message = nil
        } catch {
            message = "자동 실행 설정 실패: 앱을 ‘응용 프로그램’ 폴더로 옮긴 뒤 다시 시도해 주세요."
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func exportBackup() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "ALPHA-백업-\(Date().formatted("yyyyMMdd")).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.exportData().write(to: url, options: .atomic)
            message = "백업을 저장했어요: \(url.lastPathComponent)"
        } catch {
            message = "백업 실패: \(error.localizedDescription)"
        }
    }

    private func pickBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url, let raw = try? Data(contentsOf: url) else { return }
        confirmImport = raw
    }
}

struct FontRow: View {
    let option: FontOption
    let selected: Bool
    let available: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TodoCheckbox(isOn: selected, color: DS.ink, size: 16)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(option.label).font(.system(size: 13, weight: .semibold))
                    Text(option.summary).font(.caption).foregroundStyle(.secondary)
                    if !available {
                        Text("미설치").font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 2)
                            .foregroundStyle(DS.textSecondary)
                            .background(DS.surface, in: .capsule)
                    }
                }
                Text("오늘 할 일을 끝내고 ALPHA로 성장해요 123")
                    .font(FontManager.shared.font(size: 16, weight: .regular, option: option))
                    .foregroundStyle(available ? .primary : .tertiary)
            }
            Spacer()
        }
        .contentShape(.rect)
        .onTapGesture { if available { onSelect() } }
        .opacity(available ? 1 : 0.7)
    }
}
