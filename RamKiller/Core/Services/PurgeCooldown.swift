import Foundation
import Combine

@MainActor
final class PurgeCooldown: ObservableObject {
    let cooldownSeconds: TimeInterval
    @Published private(set) var lastFiredAt: Date?

    init(cooldownSeconds: TimeInterval = 60) {
        self.cooldownSeconds = cooldownSeconds
    }

    func isAllowed(now: Date = Date()) -> Bool {
        guard let last = lastFiredAt else { return true }
        return now.timeIntervalSince(last) >= cooldownSeconds
    }

    func remainingSeconds(now: Date = Date()) -> TimeInterval {
        guard let last = lastFiredAt else { return 0 }
        return max(0, cooldownSeconds - now.timeIntervalSince(last))
    }

    func markFired(at date: Date = Date()) {
        lastFiredAt = date
    }
}
