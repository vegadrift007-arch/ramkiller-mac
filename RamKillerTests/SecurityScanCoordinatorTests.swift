// RamKillerTests/SecurityScanCoordinatorTests.swift
import XCTest
@testable import RamKiller

@MainActor
final class SecurityScanCoordinatorTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        UserDefaults.standard.removeObject(forKey: "security.ignoredIDs")
        UserDefaults.standard.removeObject(forKey: "security.autoScanInterval")
        UserDefaults.standard.removeObject(forKey: "security.lastScanDate")
    }

    func testInitialStateIsIdle() {
        let c = SecurityScanCoordinator()
        XCTAssertEqual(c.scanState, .idle)
        XCTAssertTrue(c.findings.isEmpty)
    }

    func testIgnoreRemovesFindingFromList() {
        let c = SecurityScanCoordinator()
        let f = SecurityFinding(checkType: .malware, severity: .critical, title: "T", detail: "D")
        c.findings = [f]
        c.ignore(f)
        XCTAssertTrue(c.findings.isEmpty)
    }

    func testIgnoredIdPersistedAndFilteredOnNextSet() {
        let c = SecurityScanCoordinator()
        let f = SecurityFinding(checkType: .malware, severity: .critical, title: "T", detail: "D")
        c.ignore(f)
        // After ignore, the same finding should be filtered when findings are set again
        c.findings = [f]
        XCTAssertTrue(c.findings.isEmpty, "Ignored finding should be filtered out")
    }
}
