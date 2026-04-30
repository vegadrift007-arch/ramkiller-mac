import Foundation
import SwiftData

@MainActor
public final class UserActionLog {
    public static let shared: UserActionLog = {
        guard let container = SharedContainer.container else {
            fatalError("SharedContainer.container missing — wire it from RamKillerApp init")
        }
        return UserActionLog(context: ModelContext(container))
    }()

    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func record(type: String, target: String? = nil, success: Bool, error: String? = nil, bytesFreed: Int64? = nil) {
        let action = UserAction(type: type, target: target, success: success, error: error, bytesFreed: bytesFreed)
        context.insert(action)
        try? context.save()
    }
}
