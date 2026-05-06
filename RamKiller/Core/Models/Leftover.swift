import Foundation

public struct Leftover: Identifiable, Hashable {
    public let id: String
    public let path: String
    public let size: Int64
    public let kind: Kind

    public enum Kind: String {
        case applicationSupport
        case caches
        case preferences
        case logs
        case container
        case groupContainer
        case savedState
        case httpStorage
        case launchAgent
        case launchDaemon
        case pkgReceipt
        case other

        public var label: String {
            switch self {
            case .applicationSupport: return String(localized: "App Support")
            case .caches:             return String(localized: "Caches")
            case .preferences:        return String(localized: "Preferences")
            case .logs:               return String(localized: "Logs")
            case .container:          return String(localized: "Container")
            case .groupContainer:     return String(localized: "Group Container")
            case .savedState:         return String(localized: "Saved State")
            case .httpStorage:        return String(localized: "HTTP Storage")
            case .launchAgent:        return String(localized: "Launch Agent")
            case .launchDaemon:       return String(localized: "Launch Daemon")
            case .pkgReceipt:         return String(localized: "Pkg Receipt")
            case .other:              return String(localized: "Other")
            }
        }

        public var icon: String {
            switch self {
            case .applicationSupport: return "folder"
            case .caches:             return "doc.on.doc"
            case .preferences:        return "gear"
            case .logs:                return "doc.text"
            case .container:           return "shippingbox"
            case .groupContainer:      return "shippingbox.and.arrow.backward"
            case .savedState:          return "clock.arrow.circlepath"
            case .httpStorage:         return "globe"
            case .launchAgent:         return "powerplug"
            case .launchDaemon:        return "shield"
            case .pkgReceipt:          return "doc.badge.gearshape"
            case .other:               return "questionmark"
            }
        }
    }
}
