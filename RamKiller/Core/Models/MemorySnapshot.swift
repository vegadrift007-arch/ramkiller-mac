import Foundation
import SwiftData

@Model
public final class MemorySnapshot {
    @Attribute(.unique) public var id: UUID
    public var timestamp: Date
    public var totalBytes: Int64
    public var usedBytes: Int64
    public var unusedBytes: Int64
    public var wiredBytes: Int64
    public var activeBytes: Int64
    public var inactiveBytes: Int64
    public var speculativeBytes: Int64
    public var compressorBytes: Int64
    public var swapInPagesPerSec: Double
    public var swapOutPagesPerSec: Double
    public var pressureLevel: Int

    public init(reading: MemoryReading) {
        self.id = UUID()
        self.timestamp = reading.timestamp
        self.totalBytes = reading.totalBytes
        self.usedBytes = reading.usedBytes
        self.unusedBytes = reading.unusedBytes
        self.wiredBytes = reading.wiredBytes
        self.activeBytes = reading.activeBytes
        self.inactiveBytes = reading.inactiveBytes
        self.speculativeBytes = reading.speculativeBytes
        self.compressorBytes = reading.compressorBytes
        self.swapInPagesPerSec = reading.swapInPagesPerSec
        self.swapOutPagesPerSec = reading.swapOutPagesPerSec
        self.pressureLevel = reading.pressureLevel
    }
}
