import Foundation

/// One in-memory snapshot of macOS memory state. Not persisted — the persisted form is `MemorySnapshot`.
public struct MemoryReading: Sendable, Equatable {
    public let timestamp: Date

    /// All values in bytes.
    public let totalBytes: Int64
    public let usedBytes: Int64
    public let unusedBytes: Int64
    public let wiredBytes: Int64
    public let activeBytes: Int64
    public let inactiveBytes: Int64
    public let speculativeBytes: Int64
    public let compressorBytes: Int64

    /// Per-second rate from kernel page counters (compared against last reading).
    public let swapInPagesPerSec: Double
    public let swapOutPagesPerSec: Double

    /// 0 = green, 1 = yellow, 2 = red. Read from `kern.memorystatus_vm_pressure_level`.
    public let pressureLevel: Int

    public var usedPercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100
    }
}
