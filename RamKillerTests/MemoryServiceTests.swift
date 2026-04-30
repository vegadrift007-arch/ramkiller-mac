import XCTest
@testable import RamKiller

final class MemoryServiceTests: XCTestCase {
    func testReadCurrentReturnsPlausibleValues() {
        let service = MemoryService()
        let reading = service.readCurrent()

        // Total memory > 1 GB on any modern Mac
        XCTAssertGreaterThan(reading.totalBytes, 1_000_000_000)
        // Used + Unused should approximately equal Total (within 5% to account for compressor/purgeable accounting)
        let approxTotal = reading.usedBytes + reading.unusedBytes
        let diff = abs(approxTotal - reading.totalBytes)
        XCTAssertLessThan(Double(diff) / Double(reading.totalBytes), 0.05)
        // Wired + Active + Inactive + Speculative should not exceed total
        let breakdown = reading.wiredBytes + reading.activeBytes + reading.inactiveBytes + reading.speculativeBytes
        XCTAssertLessThanOrEqual(breakdown, reading.totalBytes)
        // Pressure level is 0..2
        XCTAssertGreaterThanOrEqual(reading.pressureLevel, 0)
        XCTAssertLessThanOrEqual(reading.pressureLevel, 2)
    }

    func testSwapRatesAreNonNegative() {
        let service = MemoryService()
        _ = service.readCurrent()  // baseline
        Thread.sleep(forTimeInterval: 0.5)
        let reading = service.readCurrent()
        XCTAssertGreaterThanOrEqual(reading.swapInPagesPerSec, 0)
        XCTAssertGreaterThanOrEqual(reading.swapOutPagesPerSec, 0)
    }
}
