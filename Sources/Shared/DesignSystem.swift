import AppKit
import SwiftUI

// 투두메이트에서 뽑은 디자인 토큰. 규칙과 근거는 DESIGN_SYSTEM.md 참고.

// MARK: - 색 도우미

nonisolated extension Color {
    /// 0xRRGGBB 정수로 만든 색
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// 라이트 / 다크 모드에서 다른 값을 쓰는 색
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(Color(hex: isDark ? dark : light))
        })
    }
}

// MARK: - 토큰

nonisolated enum DS {
    // 중립색
    static let bg = Color.dynamic(light: 0xFFFFFF, dark: 0x000000)
    static let text = Color.dynamic(light: 0x121212, dark: 0xF2F2F2)
    static let textSecondary = Color.dynamic(light: 0x8B919B, dark: 0x8E8E93)
    static let surface = Color.dynamic(light: 0xF2F2F2, dark: 0x1C1C1E)
    static let checkOff = Color.dynamic(light: 0xD5D9DC, dark: 0x3A3A3C)
    static let divider = Color.dynamic(light: 0xEEEEEE, dark: 0x2C2C2E)
    /// 선택 원, 선택 필, 주요 버튼
    static let ink = Color.dynamic(light: 0x121212, dark: 0xFFFFFF)
    static let onInk = Color.dynamic(light: 0xFFFFFF, dark: 0x121212)

    // 요일색
    static let sunday = Color(hex: 0xFF4A4A)
    static let saturday = Color(hex: 0x007AFF)

    enum TextSize {
        static let display: CGFloat = 72
        static let title: CGFloat = 22
        static let headline: CGFloat = 15
        static let body: CGFloat = 14
        static let chip: CGFloat = 13
        static let caption: CGFloat = 12
        static let label: CGFloat = 11
        static let micro: CGFloat = 10
    }

    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let checkbox: CGFloat = 5
        static let bar: CGFloat = 3
        static let swatch: CGFloat = 6
        static let tile: CGFloat = 14
        static let card: CGFloat = 18
    }

    enum Size {
        static let checkbox: CGFloat = 18
        static let stamp: CGFloat = 22
        static let circleButton: CGFloat = 28
        static let pill: CGFloat = 28
    }

    /// weekday(1 = 일 … 7 = 토)에 따른 글자색
    static func weekdayColor(for weekday: Int, base: Color = DS.text) -> Color {
        switch weekday {
        case 1: sunday
        case 7: saturday
        default: base
        }
    }

    /// 요일에 따른 날짜 글자색 (일 빨강, 토 파랑)
    static func weekdayColor(_ date: Date, calendar: Calendar, base: Color = DS.text) -> Color {
        switch calendar.component(.weekday, from: date) {
        case 1: sunday
        case 7: saturday
        default: base
        }
    }
}

// MARK: - 서체 전달 (앱은 FontManager, 위젯은 설정 서체)

nonisolated struct AppFontResolver: Sendable {
    var make: @Sendable (CGFloat, AppWeight) -> Font = { .system(size: $0, weight: $1.swiftUI) }
}

extension EnvironmentValues {
    @Entry var appFontResolver = AppFontResolver()
    /// 강조색 (기본 검정). 날짜 도장·선택 등에 쓴다.
    @Entry var dsAccent: Color = DS.ink
}

private struct DSFontModifier: ViewModifier {
    @Environment(\.appFontResolver) private var resolver
    let size: CGFloat
    let weight: AppWeight
    func body(content: Content) -> some View {
        content.font(resolver.make(size, weight))
    }
}

extension View {
    /// 공용 컴포넌트용 서체. 앱과 위젯이 각자 넣어 준 서체를 쓴다.
    func dsFont(_ size: CGFloat, _ weight: AppWeight = .regular) -> some View {
        modifier(DSFontModifier(size: size, weight: weight))
    }
}

// MARK: - 공용 컴포넌트 (앱·위젯)

/// 투두메이트식 둥근 사각형 체크박스. 미완료는 회색, 완료는 목표 색 + 흰 체크.
struct TodoCheckbox: View {
    let isOn: Bool
    let color: Color
    var size: CGFloat = DS.Size.checkbox
    var animated = true

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * DS.Radius.checkbox / DS.Size.checkbox, style: .continuous)
        ZStack {
            shape.fill(DS.checkOff)
            shape.fill(color)
                .scaleEffect(isOn ? 1 : 0.6)
                .opacity(isOn ? 1 : 0)
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.55, weight: .heavy))
                .foregroundStyle(color == DS.ink ? DS.onInk : .white)
                .scaleEffect(isOn ? 1 : 0.4)
                .opacity(isOn ? 1 : 0)
        }
        .frame(width: size, height: size)
        .animation(animated ? .spring(response: 0.3, dampingFraction: 0.55) : nil, value: isOn)
        .contentShape(shape)
        .accessibilityLabel(isOn ? "완료" : "미완료")
    }
}

/// 달력 날짜 위의 도장. 할 일 없음 / 진행 중(남은 개수) / 모두 완료(체크)
struct DayStamp: View {
    let done: Int
    let total: Int
    var color: Color = DS.ink
    var size: CGFloat = DS.Size.stamp
    var showsCount = true
    /// 주요 이벤트가 있는 날: 빨간 테두리
    var highlight = false
    /// 완료한 할 일을 목표 색별로 아래에서부터 쌓아 그린다 (없으면 color 한 가지)
    var segments: [(color: Color, count: Int)]? = nil

    private var ratio: Double { total == 0 ? 0 : Double(done) / Double(total) }
    private var allDone: Bool { total > 0 && done == total }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
        ZStack {
            shape.fill(DS.checkOff).opacity(total == 0 ? 0.5 : 1)
            // 완료 비율만큼 아래에서 차오른다
            GeometryReader { geo in
                let segs = segments ?? [(color: color, count: done)]
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    ForEach(Array(segs.enumerated().reversed()), id: \.offset) { _, seg in
                        Rectangle()
                            .fill(seg.color)
                            .frame(height: total == 0 ? 0 : geo.size.height * CGFloat(seg.count) / CGFloat(total))
                    }
                }
            }
            .clipShape(shape)
            if allDone {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.5, weight: .heavy))
                    .foregroundStyle(color == DS.ink ? DS.onInk : .white)
            } else if total > 0, showsCount {
                // 절반 넘게 차오르면 채움 위 글자색, 아니면 회색 위 진한 글자
                Text("\(total - done)")
                    .font(.system(size: size * 0.45, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(ratio >= 0.5 ? (color == DS.ink ? DS.onInk : .white) : DS.text)
            }
        }
        .overlay {
            if highlight { shape.strokeBorder(Color.red, lineWidth: max(2, size * 0.09)) }
        }
        .frame(width: size, height: size)
        .animation(.easeOut(duration: 0.3), value: ratio)
        .accessibilityLabel(total == 0 ? "할 일 없음" : "\(total)개 중 \(done)개 완료")
    }
}

/// 달력 날짜 숫자. 요일색, 선택 시 검정 원, 오늘은 굵게 + 아래 점.
struct DateNumber: View {
    let date: Date
    let calendar: Calendar
    var isSelected = false
    var isToday = false
    var inMonth = true
    var size: CGFloat = DS.TextSize.label

    var body: some View {
        Text(date.formatted("d"))
            .dsFont(size, isSelected || isToday ? .bold : .medium)
            .monospacedDigit()
            .foregroundStyle(isSelected ? DS.onInk : DS.weekdayColor(date, calendar: calendar))
            .frame(width: size * 2, height: size * 2)
            .background {
                if isSelected { Circle().fill(DS.ink) }
            }
            .overlay(alignment: .bottom) {
                if isToday && !isSelected {
                    Circle().fill(DS.text).frame(width: 3, height: 3).offset(y: 2)
                }
            }
            .opacity(inMonth ? 1 : 0.4)
    }
}

/// 꽉 찬 일정 막대 (흰 글씨)
struct EventBar: View {
    let title: String
    let color: Color
    var size: CGFloat = DS.TextSize.micro

    var body: some View {
        Text(title)
            .dsFont(size, .medium)
            .lineLimit(1)
            .foregroundStyle(color == DS.ink ? DS.onInk : .white)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, minHeight: size + 4, alignment: .leading)
            .background(color, in: .rect(cornerRadius: DS.Radius.bar))
    }
}

/// 가는 진행 막대 (타이머의 구분선 자리)
struct ProgressBar: View {
    let progress: Double
    let color: Color
    var height: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(DS.divider)
                Rectangle().fill(color).frame(width: geo.size.width * min(1, max(0, progress)))
            }
        }
        .frame(height: height)
    }
}
