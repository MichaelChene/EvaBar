import Foundation

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"
    case korean = "ko"
    case german = "de"
    case french = "fr"
    case spanish = "es"
    case brazilianPortuguese = "pt-BR"
    case italian = "it"

    var displayName: String {
        switch self {
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .german: "Deutsch"
        case .french: "Français"
        case .spanish: "Español"
        case .brazilianPortuguese: "Português (Brasil)"
        case .italian: "Italiano"
        }
    }
}

@MainActor
enum L10n {
    private static let preferenceKey = "interfaceLanguage"
    private static var strings = bundle(for: selectedLanguage ?? systemLanguage)

    static var selectedLanguage: AppLanguage? {
        UserDefaults.standard.string(forKey: preferenceKey).flatMap(AppLanguage.init(rawValue:))
    }

    private static var systemLanguage: AppLanguage {
        let supported = AppLanguage.allCases.map(\.rawValue)
        return Bundle.preferredLocalizations(from: supported, forPreferences: Locale.preferredLanguages)
            .first.flatMap(AppLanguage.init(rawValue:)) ?? .english
    }

    private static func bundle(for language: AppLanguage) -> Bundle {
        Bundle.main.url(forResource: language.rawValue, withExtension: "lproj")
            .flatMap(Bundle.init(url:)) ?? .main
    }

    static func select(_ language: AppLanguage?) {
        UserDefaults.standard.set(language?.rawValue, forKey: preferenceKey)
        strings = bundle(for: language ?? systemLanguage)
    }

    static func text(_ key: String) -> String {
        strings.localizedString(forKey: key, value: key, table: nil)
    }

    static func format(_ key: String, _ value: String) -> String {
        String(format: text(key), value)
    }
}
