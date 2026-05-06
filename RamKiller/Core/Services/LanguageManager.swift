import Foundation
import AppKit
import Combine

@MainActor
public final class LanguageManager: ObservableObject {
    public static let shared = LanguageManager()

    public enum Language: String, CaseIterable, Identifiable {
        case system
        case english
        case simplifiedChinese

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .system:            return String(localized: "Follow System")
            case .english:           return "English"
            case .simplifiedChinese: return "简体中文"
            }
        }

        var localeCode: String? {
            switch self {
            case .system:            return nil
            case .english:           return "en"
            case .simplifiedChinese: return "zh-Hans"
            }
        }
    }

    private static let storeKey = "language.selected"

    @Published public var selected: Language {
        didSet {
            UserDefaults.standard.set(selected.rawValue, forKey: Self.storeKey)
            applyToAppleLanguages()
        }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.storeKey) ?? Language.system.rawValue
        self.selected = Language(rawValue: raw) ?? .system
    }

    /// Must be called BEFORE any UI loads (in App.init), so AppleLanguages takes effect this launch.
    public static func bootstrap() {
        let raw = UserDefaults.standard.string(forKey: storeKey) ?? Language.system.rawValue
        let lang = Language(rawValue: raw) ?? .system
        if let code = lang.localeCode {
            UserDefaults.standard.set([code], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
    }

    private func applyToAppleLanguages() {
        if let code = selected.localeCode {
            UserDefaults.standard.set([code], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
    }

    /// Relaunch the app so the new locale is read by everything (Bundle, formatters, layouts).
    public func relaunch() {
        let bundlePath = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", bundlePath]
        try? task.run()
        NSApp.terminate(nil)
    }
}
