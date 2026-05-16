import XCTest
@testable import BeagleX

final class SmartKillAnalyzerTests: XCTestCase {
    func testRecommendsIdleHighRSSNonSystem() {
        let now = Date()
        let processes: [ProcessReading] = [
            // Idle high RSS user process — should recommend
            ProcessReading(id: 100, pid: 100, name: "leaky-app", bundleId: nil, executablePath: nil,
                           user: NSUserName(), rssBytes: 500_000_000, cpuPercent: 0,
                           startedAt: now.addingTimeInterval(-7200)),
            // System process — skip
            ProcessReading(id: 50, pid: 50, name: "kernel-thing", bundleId: nil, executablePath: nil,
                           user: "root", rssBytes: 1_000_000_000, cpuPercent: 0,
                           startedAt: now.addingTimeInterval(-7200)),
            // Low RSS — skip
            ProcessReading(id: 200, pid: 200, name: "tiny", bundleId: nil, executablePath: nil,
                           user: NSUserName(), rssBytes: 10_000_000, cpuPercent: 0,
                           startedAt: now.addingTimeInterval(-7200)),
            // Recent — skip
            ProcessReading(id: 300, pid: 300, name: "recent", bundleId: nil, executablePath: nil,
                           user: NSUserName(), rssBytes: 500_000_000, cpuPercent: 0,
                           startedAt: now.addingTimeInterval(-30)),
        ]
        let analyzer = SmartKillAnalyzer(minRSS: 100_000_000, minAgeSeconds: 3600)
        let candidates = analyzer.candidates(from: processes, now: now)
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.pid, 100)
    }

    func testEmptyWhenNoneMatch() {
        let analyzer = SmartKillAnalyzer()
        XCTAssertTrue(analyzer.candidates(from: []).isEmpty)
    }
}
