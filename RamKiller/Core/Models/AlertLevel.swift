import Foundation

public enum AlertLevel: String, Codable, CaseIterable {
    case warning
    case critical
    case emergency

    public var label: String {
        switch self {
        case .warning:   return String(localized: "Warning")
        case .critical:  return String(localized: "Critical")
        case .emergency: return String(localized: "Emergency")
        }
    }

    public var icon: String {
        switch self {
        case .warning:   return "exclamationmark.triangle"
        case .critical:  return "flame"
        case .emergency: return "exclamationmark.octagon"
        }
    }

    /// Severity ordering: warning < critical < emergency
    public var severity: Int {
        switch self {
        case .warning:   return 0
        case .critical:  return 1
        case .emergency: return 2
        }
    }
}
