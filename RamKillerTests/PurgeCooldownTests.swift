import XCTest
@testable import RamKiller

@MainActor
final class PurgeCooldownTests: XCTestCase {
    func testInitiallyAllowed() {
        let c = PurgeCooldown(cooldownSeconds: 60)
        XCTAssertTrue(c.isAllowed(now: Date()))
    }

    func testBlockedDuringCooldown() {
        let c = PurgeCooldown(cooldownSeconds: 60)
        let t0 = Date()
        c.markFired(at: t0)
        XCTAssertFalse(c.isAllowed(now: t0.addingTimeInterval(30)))
    }

    func testAllowedAfterCooldown() {
        let c = PurgeCooldown(cooldownSeconds: 60)
        let t0 = Date()
        c.markFired(at: t0)
        XCTAssertTrue(c.isAllowed(now: t0.addingTimeInterval(61)))
    }

    func testRemainingSeconds() {
        let c = PurgeCooldown(cooldownSeconds: 60)
        let t0 = Date()
        c.markFired(at: t0)
        XCTAssertEqual(c.remainingSeconds(now: t0.addingTimeInterval(15)), 45, accuracy: 0.1)
    }
}
