import Foundation
import SwiftData

@Model
public final class ProcessSnapshot {
    @Attribute(.unique) public var id: UUID
    public var timestamp: Date
    public var pid: Int32
    public var name: String
    public var bundleId: String?
    public var rssBytes: Int64
    public var cpuPercent: Double
    public var elapsedSeconds: Int

    public init(reading: ProcessReading, timestamp: Date) {
        self.id = UUID()
        self.timestamp = timestamp
        self.pid = reading.pid
        self.name = reading.name
        self.bundleId = reading.bundleId
        self.rssBytes = reading.rssBytes
        self.cpuPercent = reading.cpuPercent
        self.elapsedSeconds = reading.elapsedSeconds
    }
}
