import Foundation
import SwiftData

@Model
public final class AlertEvent {
    @Attribute(.unique) public var id: UUID
    public var timestamp: Date
    public var levelRaw: String
    public var trigger: String
    public var resolvedAt: Date?
    public var userActionTaken: String?

    public var level: AlertLevel {
        AlertLevel(rawValue: levelRaw) ?? .warning
    }

    public init(level: AlertLevel, trigger: String, timestamp: Date = Date()) {
        self.id = UUID()
        self.timestamp = timestamp
        self.levelRaw = level.rawValue
        self.trigger = trigger
    }
}
