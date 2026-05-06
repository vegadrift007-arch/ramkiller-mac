import Foundation

public enum CleanerSafety: String, Codable {
    case safe, caution, risky
}

public enum CleanerCategory: String, Codable, CaseIterable {
    case developer
    case browser
    case media
    case appCache
    case system
    case trash

    public var label: String {
        switch self {
        case .developer: return String(localized: "Developer Tools")
        case .browser:   return String(localized: "Browsers")
        case .media:     return String(localized: "Media")
        case .appCache:  return String(localized: "Application Caches")
        case .system:    return String(localized: "System")
        case .trash:     return String(localized: "Trash")
        }
    }

    public var icon: String {
        switch self {
        case .developer: return "hammer"
        case .browser:   return "safari"
        case .media:     return "play.rectangle"
        case .appCache:  return "app"
        case .system:    return "macwindow"
        case .trash:     return "trash"
        }
    }
}

public struct Cleaner: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let description: String
    public let category: CleanerCategory
    public let safety: CleanerSafety
    public let paths: [String]
    public let requiresHelper: Bool
}
