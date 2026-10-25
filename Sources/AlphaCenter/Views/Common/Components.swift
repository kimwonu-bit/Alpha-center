import SwiftUI

// 앱 전용 투두메이트 컴포넌트. 위젯과 같이 쓰는 것은 Shared/DesignSystem.swift에 있다.

extension AppFontResolver {
    /// 사용자가 고른 앱 서체
    static let app = AppFontResolver { size, weight in
        MainActor.assumeIsolated { FontManager.shared.font(size: size, weight: weight) }
    }
}

/// 목표 칩: 회색 캡슐 + 아이콘 + 목표 색 이름 + `+`
struct GoalChip: View {
    let title: String
    let icon: String
    let color: Color
    var showsPlus = true

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DS.textSecondary)
            Text(title)
                .appFont(DS.TextSize.chip, .bold)
                .foregroundStyle(color)
                .lineLimit(1)
            if showsPlus {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DS.text)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: DS.Size.pill)
        .background(DS.surface, in: .capsule)
    }
}

/// 이전/다음 같은 원형 아이콘 버튼 (조작 레이어라 Glass)
struct CircleIconButton: View {
    let systemName: String
    var help: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .frame(width: DS.Size.circleButton - 8, height: DS.Size.circleButton - 8)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .help(help)
    }
}

/// 2~3개 중 하나를 고르는 필. 선택된 것만 검정.
struct PillToggle<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(label: String, value: Value)]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.value) { option in
                let on = option.value == selection
                Text(option.label)
                    .appFont(DS.TextSize.caption, .bold)
                    .lineLimit(1)
                    .fixedSize()
                    .foregroundStyle(on ? DS.onInk : DS.text)
                    .padding(.horizontal, 12)
                    .frame(height: DS.Size.pill - 2)
                    .background(on ? DS.ink : DS.surface, in: .capsule)
                    .contentShape(.capsule)
                    .onTapGesture { withAnimation(.snappy) { selection = option.value } }
                    .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}

/// 액션 시트의 아이콘 타일
struct ActionTile: View {
    let title: String
    let systemImage: String
    var isDestructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage).font(.system(size: 18, weight: .medium))
                Text(title).appFont(DS.TextSize.caption, .medium).lineLimit(1)
            }
            .foregroundStyle(isDestructive ? DS.sunday : DS.text)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(DS.surface, in: .rect(cornerRadius: DS.Radius.tile, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// 통계용 점 격자: 완료 = 목표 색, 나머지 = 회색
struct DotGrid: View {
    let filled: Int
    let total: Int
    let color: Color
    var columns = 7
    var dot: CGFloat = 10

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(dot), spacing: 5), count: columns), alignment: .leading, spacing: 5) {
            ForEach(0..<max(total, 1), id: \.self) { i in
                Circle()
                    .fill(i < filled ? color : DS.checkOff)
                    .frame(width: dot, height: dot)
            }
        }
    }
}

/// 둥근 사각형 색 스와치
struct ColorPalettePicker: View {
    @Binding var selection: Int
    var size: CGFloat = 22

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Palette.colors.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: DS.Radius.swatch, style: .continuous)
                    .fill(Palette.colors[i])
                    .frame(width: size, height: size)
                    .overlay {
                        if i == selection {
                            Image(systemName: "checkmark")
                                .font(.system(size: size * 0.45, weight: .heavy))
                                .foregroundStyle(i == Palette.defaultAccent ? DS.onInk : .white)
                        }
                    }
                    .padding(2)
                    .overlay {
                        RoundedRectangle(cornerRadius: DS.Radius.swatch + 2, style: .continuous)
                            .strokeBorder(DS.ink.opacity(i == selection ? 1 : 0), lineWidth: 1.5)
                    }
                    .onTapGesture { selection = i }
                    .help(Palette.names[i])
                    .accessibilityLabel(Palette.names[i])
            }
        }
    }
}

struct IconPicker: View {
    @Binding var selection: String
    let color: Color

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(32), spacing: 6), count: 10), spacing: 6) {
            ForEach(GoalIcons.all, id: \.self) { name in
                let on = name == selection
                Image(systemName: name)
                    .frame(width: 32, height: 32)
                    .background(on ? color : DS.surface, in: .rect(cornerRadius: 8, style: .continuous))
                    .foregroundStyle(on ? (color == DS.ink ? DS.onInk : .white) : DS.textSecondary)
                    .onTapGesture { selection = name }
            }
        }
    }
}

/// 화면 상단 제목
struct ScreenHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).appFont(DS.TextSize.title, .bold).foregroundStyle(DS.text)
                if let subtitle {
                    Text(subtitle).appFont(DS.TextSize.caption).foregroundStyle(DS.textSecondary)
                }
            }
            Spacer()
            trailing
        }
    }
}

/// 섹션 제목 (굵은 headline)
struct SectionTitle: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack {
            Text(title).appFont(DS.TextSize.headline, .bold).foregroundStyle(DS.text)
            Spacer()
            if let trailing {
                Text(trailing).appFont(DS.TextSize.caption).foregroundStyle(DS.textSecondary)
            }
        }
    }
}

/// 요일 라벨 한 줄 (일 빨강, 토 파랑)
struct WeekdayHeader: View {
    var spacing: CGFloat = 0

    var body: some View {
        let cal = Calendar.app
        HStack(spacing: spacing) {
            ForEach(Array(cal.orderedWeekdaySymbols.enumerated()), id: \.offset) { i, s in
                let weekday = (i + cal.firstWeekday - 1) % 7 + 1
                Text(s)
                    .appFont(DS.TextSize.label, .medium)
                    .foregroundStyle(weekday == 1 ? DS.sunday : weekday == 7 ? DS.saturday : DS.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
