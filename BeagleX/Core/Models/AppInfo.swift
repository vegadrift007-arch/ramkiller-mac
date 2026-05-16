import Foundation
import AppKit

public struct AppInfo: Identifiable, Hashable {
    public let id: String                 // bundle identifier
    public let bundleIdentifier: String
    public let name: String
    public let version: String
    public let bundleURL: URL
    public let bundleSize: Int64
    public let icon: NSImage?

    public var path: String { bundleURL.path }
    public var isSystem: Bool {
        path.hasPrefix("/System/")
        || path.hasPrefix("/Library/Apple/")
        || bundleIdentifier.hasPrefix("com.apple.")
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    public static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.id == rhs.id
    }
}
