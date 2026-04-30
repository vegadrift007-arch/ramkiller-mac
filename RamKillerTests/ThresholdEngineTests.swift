import XCTest
@testable import RamKiller

final class ThresholdEngineTests: XCTestCase {
    func makeReading(unusedGB: Double, swapOut: Double, t: Date = Date()) -> MemoryReading {
        MemoryReading(
            timestamp: t,
            totalBytes: 36 * 1_073_741_824,
            usedBytes: Int64((36 - unusedGB) * 1_073_741_824),
            unusedBytes: Int64(unusedGB * 1_073_741_824),
            wiredBytes: 0, activeBytes: 0, inactiveBytes: 0, speculativeBytes: 0,
            compressorBytes: 0, purgeableBytes: 0, externalBytes: 0, fileBackedBytes: 0,
            swapInPagesPerSec: 0, swapOutPagesPerSec: swapOut, pressureLevel: 0
        )
    }

    func testWarningTriggersAfterHold() {
        let cfg = ThresholdConfig()
        let engine = ThresholdEngine(config: cfg)
        let now = Date()
        // First evaluation: starts the hold timer (warningSince = now)
        let first = engine.evaluate(makeReading(unusedGB: 1.5, swapOut: 0, t: now))
        XCTAssertNil(first, "Should not fire on first reading; need to wait for hold")
        // After hold elapses: should trigger
        let triggered = engine.evaluate(makeReading(unusedGB: 1.5, swapOut: 0, t: now.addingTimeInterval(61)))
        XCTAssertEqual(triggered, .warning)
    }

    func testNoTriggerIfBriefDip() {
        let cfg = ThresholdConfig()
        let engine = ThresholdEngine(config: cfg)
        let now = Date()
        _ = engine.evaluate(makeReading(unusedGB: 1.5, swapOut: 0, t: now))
        let triggered = engine.evaluate(makeReading(unusedGB: 5.0, swapOut: 0, t: now.addingTimeInterval(30)))
        XCTAssertNil(triggered)
    }

    func testEmergencyOnSwap() {
        let cfg = ThresholdConfig()
        let engine = ThresholdEngine(config: cfg)
        let now = Date()
        let first = engine.evaluate(makeReading(unusedGB: 5.0, swapOut: 5.0, t: now))
        XCTAssertNil(first)
        let trig = engine.evaluate(makeReading(unusedGB: 5.0, swapOut: 5.0, t: now.addingTimeInterval(11)))
        XCTAssertEqual(trig, .emergency)
    }

    func testCooldownPreventsReFire() {
        let cfg = ThresholdConfig()
        let engine = ThresholdEngine(config: cfg)
        let now = Date()
        _ = engine.evaluate(makeReading(unusedGB: 1.5, swapOut: 0, t: now))
        let firstTrigger = engine.evaluate(makeReading(unusedGB: 1.5, swapOut: 0, t: now.addingTimeInterval(61)))
        XCTAssertEqual(firstTrigger, .warning)
        // Same level within 300s cooldown: suppressed
        let secondAttempt = engine.evaluate(makeReading(unusedGB: 1.5, swapOut: 0, t: now.addingTimeInterval(70)))
        XCTAssertNil(secondAttempt)
    }
}
