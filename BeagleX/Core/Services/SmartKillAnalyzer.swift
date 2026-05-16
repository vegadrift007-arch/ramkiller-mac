import Foundation

final class SmartKillAnalyzer {
    let minRSS: Int64
    let minAgeSeconds: Int

    init(minRSS: Int64 = 100_000_000, minAgeSeconds: Int = 3600) {
        self.minRSS = minRSS
        self.minAgeSeconds = minAgeSeconds
    }

    /// Returns idle high-RSS processes owned by the current user.
    /// Excludes system / root processes — those need a privileged helper.
    func candidates(from processes: [ProcessReading], now: Date = Date()) -> [ProcessReading] {
        let me = NSUserName()
        return processes.filter {
            $0.user == me &&
            $0.rssBytes >= minRSS &&
            $0.elapsedSeconds >= minAgeSeconds
        }
        .sorted { $0.rssBytes > $1.rssBytes }
    }
}
