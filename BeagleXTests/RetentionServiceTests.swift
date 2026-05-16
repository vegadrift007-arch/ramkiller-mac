import XCTest
import SwiftData
@testable import BeagleX

final class RetentionServiceTests: XCTestCase {
    func testPruneRemovesRecordsOlderThanCutoff() throws {
        let schema = Schema([MemorySnapshot.self, ProcessSnapshot.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let ctx = ModelContext(container)

        let now = Date()
        let oldReading = MemoryReading(
            timestamp: now.addingTimeInterval(-25 * 3600),
            totalBytes: 1, usedBytes: 0, unusedBytes: 0, wiredBytes: 0,
            activeBytes: 0, inactiveBytes: 0, speculativeBytes: 0, compressorBytes: 0,
            swapInPagesPerSec: 0, swapOutPagesPerSec: 0, pressureLevel: 0)
        let newReading = MemoryReading(
            timestamp: now,
            totalBytes: 1, usedBytes: 0, unusedBytes: 0, wiredBytes: 0,
            activeBytes: 0, inactiveBytes: 0, speculativeBytes: 0, compressorBytes: 0,
            swapInPagesPerSec: 0, swapOutPagesPerSec: 0, pressureLevel: 0)
        ctx.insert(MemorySnapshot(reading: oldReading))
        ctx.insert(MemorySnapshot(reading: newReading))
        try ctx.save()

        let service = RetentionService(retentionHours: 24)
        try service.prune(in: ctx, now: now)

        let remaining = try ctx.fetch(FetchDescriptor<MemorySnapshot>())
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.timestamp.timeIntervalSince1970 ?? 0, newReading.timestamp.timeIntervalSince1970, accuracy: 1)
    }
}
