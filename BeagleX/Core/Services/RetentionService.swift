import Foundation
import SwiftData

public final class RetentionService {
    private let retentionHours: Int

    public init(retentionHours: Int = 24) {
        self.retentionHours = retentionHours
    }

    /// Batch-delete records older than the cutoff. Uses SwiftData's `delete(model:where:)`
    /// which executes a single SQL DELETE — no per-row materialization.
    public func prune(in context: ModelContext, now: Date = Date()) throws {
        let cutoff = now.addingTimeInterval(-Double(retentionHours) * 3600)
        try context.delete(model: MemorySnapshot.self, where: #Predicate { $0.timestamp < cutoff })
        try context.delete(model: ProcessSnapshot.self, where: #Predicate { $0.timestamp < cutoff })
        try context.save()
    }
}
