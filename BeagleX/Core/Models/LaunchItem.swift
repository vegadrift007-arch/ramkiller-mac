import Foundation

public struct LaunchItem: Identifiable, Hashable {
    public enum Source: String {
        case loginItem
        case userLaunchAgent
        case systemLaunchAgent
        case systemLaunchDaemon

        public var label: String {
            switch self {
            case .loginItem:           return String(localized: "Login Item")
            case .userLaunchAgent:     return String(localized: "User Agent")
            case .systemLaunchAgent:   return String(localized: "System Agent")
            case .systemLaunchDaemon:  return String(localized: "System Daemon")
            }
        }
    }

    public let id: String          // label
    public let label: String
    public let source: Source
    public let plistPath: String?
    public let program: String?
    public let isDisabled: Bool
    public let isApple: Bool
    public let bundleIdentifier: String?
}
