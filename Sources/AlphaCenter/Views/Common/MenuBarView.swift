import SwiftUI

struct MenuBarLabel: View {
    let timer: TimerEngine

    /// 메뉴 막대용 그리스 문자 α (템플릿 이미지라 라이트/다크 모드에 맞게 색이 바뀐다)
    static let alphaGlyph: NSImage = {
        let font = NSFont(name: "Georgia-BoldItalic", size: 19)
            ?? NSFont.systemFont(ofSize: 19, weight: .bold)
        let text = NSAttributedString(string: "α", attributes: [.font: font, .foregroundColor: NSColor.black])
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let t = text.size()
            text.draw(at: NSPoint(x: (rect.width - t.width) / 2, y: (rect.height - t.height) / 2))
            return true
        }
        image.isTemplate = true
        return image
    }()

    var body: some View {
        if timer.state.isIdle {
            Image(nsImage: Self.alphaGlyph)
        } else {
            HStack(spacing: 4) {
                Image(systemName: timer.state.isRunning ? timer.state.kind.symbol : "pause.circle")
                Text(timer.remaining.clockText).monospacedDigit()
            }
        }
    }
}

/// 메뉴 막대 창: 남은 시간 + 미니 컨트롤 + 오늘 할 일 3개
struct MenuBarView: View {
    @Environment(Store.self) private var store
    @Environment(TimerEngine.self) private var timer
    @Environment(Router.self) private var router
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let today = store.todos(on: Date())
        let todos = store.orderedTodos(on: Date()).filter { !$0.isDone }
        GlassEffectContainer(spacing: DS.Space.s) {
        VStack(alignment: .leading, spacing: DS.Space.s) {
          VStack(alignment: .leading, spacing: DS.Space.s) {
            HStack(alignment: .firstTextBaseline) {
                Text("TODAY \(Calendar.app.component(.day, from: Date()))").appFont(DS.TextSize.headline, .bold)
                Spacer()
                Text(Date().formatted("M월 d일 E")).appFont(DS.TextSize.caption).foregroundStyle(DS.textSecondary)
            }

            // 타이머: 굵은 숫자 + 진행 막대
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(timer.state.kind.label).appFont(DS.TextSize.caption, .bold).foregroundStyle(DS.textSecondary)
                        Text(timer.remaining.clockText)
                            .font(FontManager.shared.font(size: 32, weight: .bold))
                            .monospacedDigit()
                            .contentTransition(.numericText(countsDown: true))
                    }
                    Spacer()
                    GlassEffectContainer(spacing: 6) {
                        HStack(spacing: 6) {
                            Button { timer.toggle() } label: {
                                Image(systemName: timer.state.isRunning ? "pause.fill" : "play.fill").frame(width: 22, height: 22)
                            }
                            .buttonStyle(.glassProminent)
                            .tint(Palette.color(for: timer.state.kind))
                            Button { timer.skip() } label: {
                                Image(systemName: "forward.end.fill").frame(width: 22, height: 22)
                            }
                            .buttonStyle(.glass)
                        }
                    }
                }
                ProgressBar(progress: timer.progress, color: Palette.color(for: timer.state.kind))
                    .clipShape(.capsule)
            }
          }
          .padding(DS.Space.m)
          .frame(maxWidth: .infinity, alignment: .leading)
          .glassEffect(.regular, in: .rect(cornerRadius: 24))

          VStack(alignment: .leading, spacing: DS.Space.s) {
            SectionTitle(title: "오늘 할 일", trailing: today.isEmpty ? nil : "\(today.count - todos.count)/\(today.count)")
            if todos.isEmpty {
                Text(today.isEmpty ? "오늘 할 일이 없어요" : "모두 완료! 🎉")
                    .appFont(DS.TextSize.caption).foregroundStyle(DS.textSecondary)
            }
            ForEach(todos.prefix(4)) { t in
                HStack(spacing: 8) {
                    TodoCheckbox(isOn: t.isDone, color: Palette.color(store.goal(t.goalID)?.colorIndex ?? 0), size: 15)
                        .onTapGesture {
                            SoundPlayer.playCheck()
                            store.toggleTodo(t.id)
                        }
                    Text(t.title).appFont(DS.TextSize.body - 1).lineLimit(1)
                }
            }
            if todos.count > 4 {
                Text("외 \(todos.count - 4)개").appFont(DS.TextSize.label).foregroundStyle(DS.textSecondary)
            }
          }
          .padding(DS.Space.m)
          .frame(maxWidth: .infinity, alignment: .leading)
          .glassEffect(.regular, in: .rect(cornerRadius: 24))

            HStack {
                Button("앱 열기") {
                    openWindow(id: "main")
                    NSApp.activate()
                }
                Spacer()
                Button("종료") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
            .appFont(DS.TextSize.caption, .medium)
            .foregroundStyle(DS.text)
            .padding(.horizontal, DS.Space.m)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .capsule)
        }
        }
        .padding(DS.Space.s)
        .frame(width: 320)
        .background(ClearMenuBarWindow())
        .environment(\.appFontResolver, .app)
    }
}

/// 메뉴 막대 팝업 창의 기본 배경·테두리를 없애 유리 카드만 떠 있게 한다 (제어센터 느낌)
private struct ClearMenuBarWindow: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async { Self.clear(v.window) }
        return v
    }

    func updateNSView(_ v: NSView, context: Context) {
        DispatchQueue.main.async { Self.clear(v.window) }
    }

    private static func clear(_ window: NSWindow?) {
        guard let window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        // 기본 팝업의 배경(비주얼 이펙트) 뷰를 투명하게
        func strip(_ view: NSView) {
            if let fx = view as? NSVisualEffectView { fx.isHidden = true }
            view.subviews.forEach(strip)
        }
        if let frame = window.contentView?.superview { strip(frame) }
    }
}
