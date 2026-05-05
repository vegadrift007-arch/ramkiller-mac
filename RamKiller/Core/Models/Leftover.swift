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
            case .applicationSupport: return "App Support"
            case .caches:             return "Caches"
            case .preferences:        return "Preferences"
            case .logs:               return "Logs"
            case .container:          return "Container"
            case .groupContainer:     return "Group Container"
            case .savedState:         return "Saved State"
            case .httpStorage:        return "HTTP Storage"
            case .launchAgent:        return "Launch Agent"
            case .launchDaemon:       return "Launch Daemon"
            case .pkgReceipt:         return "Pkg Receipt"
            case .other:              return "Other"
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
