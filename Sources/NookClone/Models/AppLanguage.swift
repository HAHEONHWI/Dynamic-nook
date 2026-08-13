import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case english
    case korean

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .system: "System Default"
        case .english: "English"
        case .korean: "Korean"
        }
    }

    var locale: Locale {
        Locale(identifier: resolvedLanguageCode)
    }

    var resolvedLanguageCode: String {
        switch self {
        case .system:
            Self.supportedLanguageCode(preferredLanguages: Locale.preferredLanguages)
        case .english:
            "en"
        case .korean:
            "ko"
        }
    }

    func localized(_ key: String) -> String {
        let languageCode = resolvedLanguageCode
        guard let path = Self.localizationPath(for: languageCode),
              let localizedBundle = Bundle(path: path) else { return key }
        let value = localizedBundle.localizedString(forKey: key, value: nil, table: nil)
        if value != key || languageCode == "en" { return value }
        return key
    }

    private static func localizationPath(for languageCode: String) -> String? {
        if let bundledPath = Bundle.main.path(forResource: languageCode, ofType: "lproj") {
            return bundledPath
        }

        // SwiftPM tests run outside the packaged .app. Keep this source-tree
        // fallback out of the production lookup path.
        let sourceResources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources", isDirectory: true)
        let sourcePath = sourceResources.appendingPathComponent("\(languageCode).lproj", isDirectory: true).path
        return FileManager.default.fileExists(atPath: sourcePath) ? sourcePath : nil
    }

    static func supportedLanguageCode(preferredLanguages: [String]) -> String {
        guard let preferred = preferredLanguages.first,
              let languageCode = Locale(identifier: preferred).language.languageCode?.identifier else {
            return "en"
        }
        return languageCode == "ko" ? "ko" : "en"
    }
}
