import XCTest
@testable import BeagleX

final class SidebarItemTests: XCTestCase {
    func testAllCasesIncludesAllEightFeaturesPlusSettings() {
        let cases = SidebarItem.allCases
        XCTAssertEqual(cases.count, 8)
        XCTAssertTrue(cases.contains(.monitoring))
        XCTAssertTrue(cases.contains(.processes))
        XCTAssertTrue(cases.contains(.automation))
        XCTAssertTrue(cases.contains(.cacheCleaner))
        XCTAssertTrue(cases.contains(.largeFiles))
        XCTAssertTrue(cases.contains(.uninstaller))
        XCTAssertTrue(cases.contains(.launchItems))
        XCTAssertTrue(cases.contains(.settings))
    }

    func testEachCaseHasNonEmptyLabelAndIcon() {
        for item in SidebarItem.allCases {
            XCTAssertFalse(item.label.isEmpty, "Empty label for \(item)")
            XCTAssertFalse(item.icon.isEmpty, "Empty icon for \(item)")
        }
    }
}
