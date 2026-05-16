// BeagleX/Features/Security/SecurityFinding.swift
import Foundation

enum SecurityCheckType: String, Codable, CaseIterable {
    case malware, launchItem, network, permission

    var sectionTitle: String {
        switch self {
        case .malware:    return "🦠 " + String(localized: "Malware")
        case .launchItem: return "🚀 " + String(localized: "Launch Items")
        case .network:    return "🌐 " + String(localized: "Network Connections")
        case .permission: return "🔑 " + String(localized: "Permission Abuse")
        }
    }

    var cleanMessage: String {
        switch self {
        case .malware:    return String(localized: "No known malware detected")
        case .launchItem: return String(localized: "All launch items are signed")
        case .network:    return String(localized: "All connections from signed apps")
        case .permission: return String(localized: "No permission abuse detected")
        }
    }
}

enum Severity: String, Codable, CaseIterable, Comparable {
    case info, warning, critical

    private var order: Int {
        switch self {
        case .info:     return 0
        case .warning:  return 1
        case .critical: return 2
        }
    }
    static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.order < rhs.order }
}

enum ScanState: Equatable {
    case idle
    case scanning(progress: Double)
    case done(Date)
}

// Findings are transient — only their UUIDs are persisted in UserDefaults for the ignore list.
// Codable is intentionally not adopted.
struct SecurityFinding: Identifiable, Equatable {
    let id: UUID
    let checkType: SecurityCheckType
    let severity: Severity
    let title: String
    let detail: String
    let path: String?
    let bundleID: String?

    init(checkType: SecurityCheckType, severity: Severity,
         title: String, detail: String,
         path: String? = nil, bundleID: String? = nil) {
        self.id = UUID()
        self.checkType = checkType
        self.severity = severity
        self.title = title
        self.detail = detail
        self.path = path
        self.bundleID = bundleID
    }
}
