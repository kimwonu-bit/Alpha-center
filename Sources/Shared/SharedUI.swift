import CoreText
import SwiftUI

// MARK: - 색상 팔레트

nonisolated enum Palette {
    /// 투두메이트형 고채도 목표 색 (DESIGN_SYSTEM.md 2.3). 저장된 colorIndex와 호환되도록 10색 순서 유지
    static let colors: [Color] = [
        Color(hex: 0xFF4A4A), // 빨강
        Color(hex: 0xFF8A1F), // 주황
        Color(hex: 0xFFBE0B), // 노랑
        Color(hex: 0x20C063), // 초록
        Color(hex: 0x00B4C5), // 청록
        Color(hex: 0x007AFF), // 파랑
        Color(hex: 0x454DFF), // 남색
        Color(hex: 0x6236FF), // 보라
        Color(hex: 0xFF2C9E), // 분홍
        DS.ink,               // 검정 (다크 모드에서 흰색)
    ]
    static let names = ["빨강", "주황", "노랑", "초록", "청록", "파랑", "남색", "보라", "분홍", "검정"]
    /// 기본 강조색: 검정
    static let defaultAccent = 9

    static func color(_ index: Int) -> Color { colors[((index % colors.count) + colors.count) % colors.count] }

    static func color(for kind: SessionKind) -> Color {
        switch kind {
        case .focus: DS.ink
        case .shortBreak: color(3)
        case .longBreak: color(5)
        }
    }
}

// MARK: - 서체

nonisolated enum FontOption: String, CaseIterable, Identifiable, Sendable {
    case system, pretendard, gmarket, cookieRun, paperlogy, cafe24Air, anthropicSerif
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "시스템 기본"
        case .pretendard: "Pretendard"
        case .gmarket: "G마켓 산스"
        case .cookieRun: "CookieRun"
        case .paperlogy: "페이퍼로지"
        case .cafe24Air: "카페24 써라운드 에어"
        case .anthropicSerif: "Anthropic Serif"
        }
    }

    var summary: String {
        switch self {
        case .system: "기본값, 가장 안정적"
        case .pretendard: "깔끔한 고딕, 가독성 최상"
        case .gmarket: "굵고 단단한 고딕"
        case .cookieRun: "둥글고 귀여운 느낌"
        case .paperlogy: "부드러운 현대 고딕"
        case .cafe24Air: "가볍고 둥근 손글씨 느낌"
        case .anthropicSerif: "세리프, 차분한 인상"
        }
    }

    /// 서체 파일에 따라 패밀리 이름이 다를 수 있어 후보를 여러 개 둔다.
    var familyCandidates: [String] {
        switch self {
        case .system: []
        case .pretendard: ["Pretendard", "Pretendard Variable", "Pretendard JP"]
        case .gmarket: ["Gmarket Sans", "GmarketSans", "Gmarket Sans TTF", "G마켓 산스", "G마켓 산스 TTF"]
        case .cookieRun: ["CookieRun", "CookieRunOTF", "CookieRun Regular", "쿠키런"]
        case .paperlogy: ["Paperlogy", "페이퍼로지"]
        case .cafe24Air: ["Cafe24 Ssurround air", "Cafe24 Ssurround Air", "Cafe24Ssurroundair", "Cafe24 SsurroundAir", "카페24 써라운드 에어"]
        case .anthropicSerif: ["Anthropic Serif", "AnthropicSerif", "Anthropic Serif Text"]
        }
    }
}

nonisolated enum AppWeight: Sendable {
    case regular, medium, bold

    /// CoreText 굵기 값 (-1 ~ 1)
    var ctWeight: Double {
        switch self {
        case .regular: 0
        case .medium: 0.23
        case .bold: 0.4
        }
    }

    var swiftUI: Font.Weight {
        switch self {
        case .regular: .regular
        case .medium: .medium
        case .bold: .bold
        }
    }
}

/// 서체 등록과 Regular / Medium / Bold 매핑 (CoreText만 사용해 위젯에서도 쓴다)
nonisolated enum FontCatalog {
    static func registerFonts(in dirs: [URL]) {
        for dir in dirs {
            guard let enumerator = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in enumerator where ["ttf", "otf", "ttc"].contains(url.pathExtension.lowercased()) {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }

    /// 앱 번들, 위젯 번들, 사용자 서체 폴더의 서체를 모두 등록한다.
    static func registerDefaultLocations() {
        var dirs = [SharedStorage.fontsDirectory]
        if let res = Bundle.main.resourceURL { dirs.append(res.appendingPathComponent("Fonts")) }
        registerFonts(in: dirs)
    }

    static func resolvedFamily(_ option: FontOption) -> String? {
        let families = Set((CTFontManagerCopyAvailableFontFamilyNames() as? [String]) ?? [])
        if let hit = option.familyCandidates.first(where: { families.contains($0) }) { return hit }
        // 대소문자·공백 차이를 무시하고 한 번 더 찾는다
        let normalized = { (s: String) in s.lowercased().replacingOccurrences(of: " ", with: "") }
        for candidate in option.familyCandidates {
            if let hit = families.first(where: { normalized($0) == normalized(candidate) }) { return hit }
        }
        return nil
    }

    /// 패밀리 안에서 원하는 굵기에 가장 가까운 PostScript 이름
    static func faceName(_ option: FontOption, _ weight: AppWeight) -> String? {
        guard let family = resolvedFamily(option) else { return nil }
        let desc = CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute: family] as CFDictionary)
        guard let matches = CTFontDescriptorCreateMatchingFontDescriptors(desc, nil) as? [CTFontDescriptor] else { return nil }
        let faces = matches.map { d -> (name: String, weight: Double, italic: Bool) in
            let name = CTFontDescriptorCopyAttribute(d, kCTFontNameAttribute) as? String ?? ""
            let traits = CTFontDescriptorCopyAttribute(d, kCTFontTraitsAttribute) as? [CFString: Any] ?? [:]
            let w = (traits[kCTFontWeightTrait] as? NSNumber)?.doubleValue ?? 0
            let sym = (traits[kCTFontSymbolicTrait] as? NSNumber)?.uint32Value ?? 0
            return (name, w, sym & CTFontSymbolicTraits.traitItalic.rawValue != 0)
        }
        let upright = faces.filter { !$0.italic }
        let pool = upright.isEmpty ? faces : upright
        return pool.min { abs($0.weight - weight.ctWeight) < abs($1.weight - weight.ctWeight) }?.name
    }

    static func font(size: CGFloat, weight: AppWeight, option: FontOption) -> Font {
        if option != .system, let name = faceName(option, weight) {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: weight.swiftUI)
    }
}

// MARK: - 날짜

nonisolated extension Calendar {
    /// 주 시작 요일을 반영한 한국어 달력
    static func alpha(mondayFirst: Bool) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "ko_KR")
        cal.firstWeekday = mondayFirst ? 2 : 1
        return cal
    }

    func days(inWeekOf date: Date) -> [Date] {
        let start = dateInterval(of: .weekOfYear, for: date)?.start ?? startOfDay(for: date)
        return (0..<7).compactMap { self.date(byAdding: .day, value: $0, to: start) }
    }

    /// 월간 그리드(6주 × 7일)에 들어갈 날짜
    func monthGrid(for date: Date) -> [Date] {
        let monthStart = dateInterval(of: .month, for: date)?.start ?? date
        let gridStart = dateInterval(of: .weekOfYear, for: monthStart)?.start ?? monthStart
        return (0..<42).compactMap { self.date(byAdding: .day, value: $0, to: gridStart) }
    }

    /// 주 시작 요일부터 정렬한 요일 이름
    var orderedWeekdaySymbols: [String] {
        let symbols = ["일", "월", "화", "수", "목", "금", "토"]
        return (0..<7).map { symbols[($0 + firstWeekday - 1) % 7] }
    }
}

nonisolated extension Date {
    func formatted(_ pattern: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = pattern
        return f.string(from: self)
    }

    /// 딥 링크에 쓰는 날짜 문자열 (yyyy-MM-dd)
    var linkKey: String { formatted("yyyy-MM-dd") }
}

nonisolated extension TimeInterval {
    var clockText: String {
        let total = Int(self.rounded(.up))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

// MARK: - 데이터 조회 (앱·위젯 공용)

nonisolated extension AppData {
    func todos(on day: Date, calendar cal: Calendar) -> [Todo] {
        let day = cal.startOfDay(for: day)
        let order = Dictionary(uniqueKeysWithValues: goals.map { ($0.id, $0.order) })
        return todos.filter { $0.date == day }
            .sorted { (order[$0.goalID] ?? 0, $0.order) < (order[$1.goalID] ?? 0, $1.order) }
    }

    func completion(on day: Date, calendar cal: Calendar) -> (done: Int, total: Int) {
        let items = todos(on: day, calendar: cal)
        return (items.filter(\.isDone).count, items.count)
    }

    func events(on day: Date, calendar cal: Calendar) -> [Event] {
        events.filter { $0.occurs(on: day, calendar: cal) }
            .sorted { ($0.isAllDay ? 0 : 1, $0.startTime(on: day, calendar: cal)) < ($1.isAllDay ? 0 : 1, $1.startTime(on: day, calendar: cal)) }
    }

    func focusCount(on day: Date, calendar cal: Calendar) -> Int {
        sessions.filter { $0.kind == .focus && $0.completed && cal.isDate($0.start, inSameDayAs: day) }.count
    }

    func goal(_ id: UUID?) -> Goal? { goals.first { $0.id == id } }
}
