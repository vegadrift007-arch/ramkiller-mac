import Foundation
import SwiftData

@Model
public final class UserAction {
    @Attribute(.unique) public var id: UUID
    public var timestamp: Date
    public var actionType: String          // "purge", "kill", "force_kill", "auto_purge"
    public var targetIdentifier: String?
    public var bytesFreed: Int64?
    public var success: Bool
    public var errorText: String?

    public init(type: String, target: String?, success: Bool, error: String? = nil, bytesFreed: Int64? = nil, timestamp: Date = Date()) {
        self.id = UUID()
        self.timestamp = timestamp
        self.actionType = type
        self.targetIdentifier = target
        self.success = success
        self.errorText = error
        self.bytesFreed = bytesFreed
    }
}
