import Foundation

/// 포모도로 상태 전이. 앱(TimerEngine)과 위젯(App Intents)이 같은 규칙을 쓴다.
nonisolated enum TimerLogic {
    static func duration(for kind: SessionKind, _ s: SharedSettings) -> TimeInterval {
        let m = switch kind {
        case .focus: s.focusMinutes
        case .shortBreak: s.shortBreakMinutes
        case .longBreak: s.longBreakMinutes
        }
        return TimeInterval(max(1, m) * 60)
    }

    static func breakKind(cycleCount: Int, interval: Int) -> SessionKind {
        cycleCount > 0 && cycleCount % max(1, interval) == 0 ? .longBreak : .shortBreak
    }

    static func prepare(_ st: inout TimerState, _ kind: SessionKind, _ s: SharedSettings) {
        st.kind = kind
        st.startedAt = nil
        st.pausedRemaining = nil
        st.isExtension = false
        st.duration = duration(for: kind, s)
    }

    static func start(_ st: inout TimerState, _ s: SharedSettings, now: Date = Date()) {
        if st.isPaused {
            st.duration = st.pausedRemaining ?? st.duration
            st.pausedRemaining = nil
        } else if st.isIdle {
            st.duration = duration(for: st.kind, s)
        } else {
            return
        }
        st.startedAt = now
    }

    static func pause(_ st: inout TimerState, now: Date = Date()) {
        guard st.isRunning else { return }
        st.pausedRemaining = st.remaining(at: now)
        st.startedAt = nil
    }

    /// 지금 세션을 기록 없이 넘기고 다음 세션을 준비한다.
    static func skip(_ st: inout TimerState, _ s: SharedSettings) {
        let next: SessionKind = st.kind == .focus
            ? breakKind(cycleCount: st.cycleCount + 1, interval: s.longBreakInterval)
            : .focus
        prepare(&st, next, s)
    }

    /// 실행 중인 세션이 끝났다면 기록하고 다음 세션을 준비한다. 끝난 세션 종류를 돌려준다.
    @discardableResult
    static func settle(_ st: inout TimerState, data: inout AppData, _ s: SharedSettings, now: Date = Date()) -> SessionKind? {
        guard let started = st.startedAt, let end = st.endDate, now >= end else { return nil }
        let finished = st
        data.sessions.append(PomodoroSession(kind: finished.kind, start: started, duration: finished.duration,
                                             completed: true, todoID: finished.todoID))
        if finished.kind == .focus && !finished.isExtension {
            st.cycleCount += 1
            if let tid = finished.todoID, let i = data.todos.firstIndex(where: { $0.id == tid }) {
                data.todos[i].pomodoroCount += 1
            }
        } else if finished.kind == .longBreak && !finished.isExtension {
            st.cycleCount = 0
        }
        let next: SessionKind = finished.kind == .focus
            ? breakKind(cycleCount: st.cycleCount, interval: s.longBreakInterval)
            : .focus
        prepare(&st, next, s)
        return finished.kind
    }
}
