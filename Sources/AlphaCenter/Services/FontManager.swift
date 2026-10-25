import AppKit
import Observation
import SwiftUI

/// 앱 번들과 사용자 서체 폴더의 서체를 등록하고, 선택한 서체를 Regular / Medium / Bold로 매핑한다.
@Observable
final class FontManager {
    static let shared = FontManager()

    var selected: FontOption = .system {
        didSet { UserDefaults.standard.set(selected.rawValue, forKey: Keys.fontOption) }
    }
    private(set) var availability: [FontOption: Bool] = [:]
    @ObservationIgnored private var faceCache: [String: String] = [:]

    /// 사용자가 서체 파일을 넣을 수 있는 폴더
    static var userFontsDirectory: URL { SharedStorage.fontsDirectory }

    func setup() {
        try? FileManager.default.createDirectory(at: Self.userFontsDirectory, withIntermediateDirectories: true)
        registerFonts()
        selected = FontOption(rawValue: UserDefaults.standard.string(forKey: Keys.fontOption) ?? "") ?? .system
    }

    func registerFonts() {
        FontCatalog.registerDefaultLocations()
        faceCache.removeAll()
        var result: [FontOption: Bool] = [:]
        for option in FontOption.allCases {
            result[option] = option == .system || FontCatalog.resolvedFamily(option) != nil
        }
        availability = result
    }

    func isAvailable(_ option: FontOption) -> Bool { availability[option] ?? (option == .system) }

    /// 패밀리 안에서 원하는 굵기에 가장 가까운 PostScript 이름 (캐시)
    private func faceName(_ option: FontOption, _ weight: AppWeight) -> String? {
        let key = "\(option.rawValue).\(weight)"
        if let cached = faceCache[key] { return cached }
        let name = FontCatalog.faceName(option, weight)
        if let name { faceCache[key] = name }
        return name
    }

    func font(size: CGFloat, weight: AppWeight = .regular, option: FontOption? = nil) -> Font {
        let option = option ?? selected
        if option != .system, let name = faceName(option, weight) {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: weight.swiftUI)
    }

    func openFontsFolder() {
        NSWorkspace.shared.open(Self.userFontsDirectory)
    }
}

struct AppFontModifier: ViewModifier {
    let size: CGFloat
    let weight: AppWeight
    func body(content: Content) -> some View {
        content.font(FontManager.shared.font(size: size, weight: weight))
    }
}

extension View {
    /// 사용자가 고른 앱 서체로 표시한다.
    func appFont(_ size: CGFloat, _ weight: AppWeight = .regular) -> some View {
        modifier(AppFontModifier(size: size, weight: weight))
    }
}
