import AppKit
import Observation
import UserNotifications

/// 포모도로 타이머. 상태는 시작 시각 + 총 길이로 timer.json에 저장해서
/// 앱을 껐다 켜거나 위젯에서 보더라도 남은 시간이 정확하다.
@Observable
final class TimerEngine {
    static let shared = TimerEngine()

    private(set) var state = TimerState() {
        didSet { if state != oldValue { persist() } }
    }
    /// 화면 갱신용 현재 시각 (실행 중에만 갱신)
    private(set) var now = Date()
    /// 방금 끝난 세션 종류 — 화면에 "완료" 표시용
    private(set) var lastFinished: SessionKind?

    @ObservationIgnored private var ticker: Task<Void, Never>?
    private static let legacyStateKey = "timerState"

    var remaining: TimeInterval { state.remaining(at: now) }
    var progress: Double {
        guard state.duration > 0 else { return 0 }
        return 1 - remaining / state.duration
    }
    var longBreakInterval: Int { max(1, UserDefaults.standard.integer(forKey: Keys.longBreakInterval)) }
    private var settings: SharedSettings { Defaults.shared }

    // MARK: 복원

    func restore() {
        if let s = SharedStorage.readTimer() {
            state = s
        } else if let raw = UserDefaults.standard.data(forKey: Self.legacyStateKey),
                  let s = try? JSONDecoder().decode(TimerState.self, from: raw) {
            state = s // 이전 버전(UserDefaults 저장)에서 옮겨 온다
        }
        syncAfterExternalChange()
    }

    /// 위젯이 timer.json을 바꿨을 때 다시 읽고 알림·화면 갱신을 맞춘다.
    func reloadFromDisk() {
        guard let s = SharedStorage.readTimer() else { return }
        lastFinished = nil
        state = s
        syncAfterExternalChange()
    }

    private func syncAfterExternalChange() {
        now = Date()
        if state.isRunning {
            if remaining <= 0 {
                // 앱이 꺼져 있는 동안 끝난 세션
                finish(autoContinue: false, notify: false)
            } else {
                NotificationManager.shared.schedulePomodoroEnd(at: state.endDate!, kind: state.kind)
                startTicker()
            }
        } else {
            NotificationManager.shared.cancelPomodoro()
            stopTicker()
            if state.isIdle { state.duration = Defaults.minutes(for: state.kind) }
        }
    }

    private func persist() {
        try? SharedStorage.write(state, to: SharedStorage.timerURL)
        WidgetReloader.reload()
    }

    // MARK: 조작

    func toggle() {
        if state.isRunning { pause() } else { start() }
    }

    func start() {
        guard !state.isRunning else { return }
        lastFinished = nil
        TimerLogic.start(&state, settings)
        now = Date()
        NotificationManager.shared.schedulePomodoroEnd(at: state.endDate!, kind: state.kind)
        startTicker()
    }

    func pause() {
        guard state.isRunning else { return }
        TimerLogic.pause(&state)
        NotificationManager.shared.cancelPomodoro()
        stopTicker()
    }

    func reset() {
        NotificationManager.shared.cancelPomodoro()
        stopTicker()
        prepare(state.kind)
        lastFinished = nil
    }

    /// 사이클 처음(집중 1회차)으로 되돌린다.
    func resetCycle() {
        state.cycleCount = 0
        select(.focus)
    }

    func skip() {
        NotificationManager.shared.cancelPomodoro()
        stopTicker()
        lastFinished = nil
        TimerLogic.skip(&state, settings)
        now = Date()
    }

    func select(_ kind: SessionKind) {
        guard !state.isRunning else { return }
        prepare(kind)
    }

    /// 설정에서 시간을 바꾸면 대기 중인 타이머에 바로 반영한다.
    func refreshIdleDuration() {
        guard state.isIdle else { return }
        state.duration = Defaults.minutes(for: state.kind)
    }

    func link(todo id: UUID?) {
        state.todoID = id
    }

    /// 방금 끝난 세션을 같은 종류로 N분 더 이어간다.
    func extend(minutes: Int = 5, kind: SessionKind? = nil) {
        NotificationManager.shared.cancelPomodoro()
        stopTicker()
        lastFinished = nil
        state.kind = kind ?? state.kind
        state.isExtension = true
        state.pausedRemaining = nil
        state.duration = TimeInterval(minutes * 60)
        state.startedAt = Date()
        now = Date()
        NotificationManager.shared.schedulePomodoroEnd(at: state.endDate!, kind: state.kind)
        startTicker()
    }

    /// 실행 중일 때 남은 시간에 N분을 더한다.
    func addTime(minutes: Int) {
        if state.isRunning {
            state.duration += TimeInterval(minutes * 60)
            NotificationManager.shared.schedulePomodoroEnd(at: state.endDate!, kind: state.kind)
        } else if state.isPaused {
            state.pausedRemaining = (state.pausedRemaining ?? 0) + TimeInterval(minutes * 60)
        } else {
            state.duration += TimeInterval(minutes * 60)
        }
        now = Date()
    }

    func handleNotificationAction(_ action: String) {
        switch action {
        case NotificationManager.ID.startBreak:
            NotificationManager.shared.cancelPomodoro()
            stopTicker()
            if state.kind == .focus {
                prepare(TimerLogic.breakKind(cycleCount: state.cycleCount, interval: longBreakInterval))
            }
            start()
        case NotificationManager.ID.startFocus:
            NotificationManager.shared.cancelPomodoro()
            stopTicker()
            prepare(.focus)
            start()
        case NotificationManager.ID.extend:
            extend(minutes: 5, kind: lastFinished ?? state.kind)
        default:
            NSApp.activate()
        }
    }

    // MARK: 내부

    private func prepare(_ kind: SessionKind) {
        TimerLogic.prepare(&state, kind, settings)
        now = Date()
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self, !Task.isCancelled else { return }
                self.now = Date()
                if self.state.isRunning && self.remaining <= 0 {
                    self.finish(autoContinue: true, notify: true)
                }
            }
        }
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }

    private func finish(autoContinue: Bool, notify: Bool) {
        stopTicker()
        var st = state
        var finished: SessionKind?
        Store.shared.mutate { data in
            finished = TimerLogic.settle(&st, data: &data, settings, now: max(Date(), st.endDate ?? Date()))
        }
        state = st
        now = Date()
        guard let finished else { return }
        lastFinished = finished

        if notify { SoundPlayer.playAlarm() }

        guard autoContinue else { return }
        let d = UserDefaults.standard
        let auto = state.kind == .focus ? d.bool(forKey: Keys.autoStartFocus) : d.bool(forKey: Keys.autoStartBreak)
        if auto { start() }
    }

    /// 이번 사이클에서 채워진 점 개수 (●●●○)
    var cycleDots: (done: Int, total: Int) {
        let total = longBreakInterval
        let c = state.cycleCount
        return (c > 0 && c % total == 0 ? total : c % total, total)
    }
}

enum SoundPlayer {
    static var systemSounds: [String] {
        let dir = URL(fileURLWithPath: "/System/Library/Sounds")
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        let names = files.map { $0.deletingPathExtension().lastPathComponent }.sorted()
        return names.isEmpty ? ["Glass"] : names
    }

    static func play(_ name: String? = nil) {
        let d = UserDefaults.standard
        let n = name ?? d.string(forKey: Keys.soundName) ?? "Glass"
        guard let s = NSSound(named: NSSound.Name(n)) else { return }
        s.volume = Float(d.double(forKey: Keys.soundVolume))
        s.play()
    }

    static func playAlarm() { play() }

    static func playCheck() {
        guard UserDefaults.standard.bool(forKey: Keys.checkSound), let s = NSSound(named: "Pop") else { return }
        s.volume = 0.35
        s.play()
    }
}
