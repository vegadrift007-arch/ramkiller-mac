// BeagleXTests/SecurityFindingTests.swift
import XCTest
@testable import BeagleX

final class SecurityFindingTests: XCTestCase {
    func testSeverityOrdering() {
        XCTAssertLessThan(Severity.info, .warning)
        XCTAssertLessThan(Severity.warning, .critical)
        XCTAssertGreaterThan(Severity.critical, .info)
    }

    func testSeverityComparableSort() {
        let sorted = [Severity.critical, .info, .warning].sorted()
        XCTAssertEqual(sorted, [.info, .warning, .critical])
    }

    func testFindingIdIsUnique() {
        let a = SecurityFinding(checkType: .malware, severity: .critical, title: "T", detail: "D")
        let b = SecurityFinding(checkType: .malware, severity: .critical, title: "T", detail: "D")
        XCTAssertNotEqual(a.id, b.id)
    }

    func testScanStateEquality() {
        XCTAssertEqual(ScanState.idle, .idle)
        XCTAssertNotEqual(ScanState.idle, .scanning(progress: 0.5))
        let now = Date()
        XCTAssertEqual(ScanState.done(now), .done(now))
    }
}
