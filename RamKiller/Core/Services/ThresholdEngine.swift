import Foundation

public final class ThresholdEngine {
    public var config: ThresholdConfig

    private var warningSince: Date?
    private var criticalSince: Date?
    private var emergencySince: Date?

    private var lastEmittedLevel: AlertLevel?
    private var lastEmittedAt: Date?

    public init(config: ThresholdConfig) {
        self.config = config
    }

    /// Evaluates the latest reading. Returns the level if a NEW alert should fire, else nil.
    public func evaluate(_ reading: MemoryReading) -> AlertLevel? {
        let unusedGB = Double(reading.unusedBytes) / 1_073_741_824
        let swapping = reading.swapOutPagesPerSec > 0

        if unusedGB < config.warningUnusedGB {
            if warningSince == nil { warningSince = reading.timestamp }
        } else { warningSince = nil }

        if unusedGB < config.criticalUnusedGB {
            if criticalSince == nil { criticalSince = reading.timestamp }
        } else { criticalSince = nil }

        if swapping {
            if emergencySince == nil { emergencySince = reading.timestamp }
        } else { emergencySince = nil }

        let now = reading.timestamp
        if let s = emergencySince, now.timeIntervalSince(s) >= Double(config.emergencyHoldSeconds) {
            return shouldEmit(.emergency, now: now) ? .emergency : nil
        }
        if let s = criticalSince, now.timeIntervalSince(s) >= Double(config.criticalHoldSeconds) {
            return shouldEmit(.critical, now: now) ? .critical : nil
        }
        if let s = warningSince, now.timeIntervalSince(s) >= Double(config.warningHoldSeconds) {
            return shouldEmit(.warning, now: now) ? .warning : nil
        }
        return nil
    }

    private func shouldEmit(_ level: AlertLevel, now: Date) -> Bool {
        let cooldown: TimeInterval = 300
        if let last = lastEmittedLevel, let lastT = lastEmittedAt {
            if level.severity == last.severity && now.timeIntervalSince(lastT) < cooldown {
                return false
            }
        }
        lastEmittedLevel = level
        lastEmittedAt = now
        return true
    }

    public func reset() {
        warningSince = nil; criticalSince = nil; emergencySince = nil
        lastEmittedLevel = nil; lastEmittedAt = nil
    }
}
