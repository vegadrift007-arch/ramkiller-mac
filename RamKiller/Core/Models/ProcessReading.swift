import Foundation

public struct ProcessReading: Sendable, Identifiable, Equatable, Hashable {
    public let id: pid_t            // PID is the natural id
    public let pid: pid_t
    public let name: String
    public let bundleId: String?
    public let executablePath: String?
    public let user: String
    public let rssBytes: Int64
    public let cpuPercent: Double
    public let startedAt: Date
    public var elapsedSeconds: Int { Int(Date().timeIntervalSince(startedAt)) }
}
