import XCTest
@testable import BeagleX

@MainActor
final class SmokeTests: XCTestCase {
    func testThemeManagerHasKnownTheme() {
        let current = ThemeManager.shared.current
        XCTAssertTrue([.midnight, .bloom].contains(current))
    }

    func testCleanerKnowledgeBaseLoaded() {
        XCTAssertGreaterThanOrEqual(CleanerKnowledgeBase.shared.cleaners.count, 30)
    }

    func testPalettesProvideAllSemanticColors() {
        for theme in AppTheme.allCases {
            // Sanity check that every semantic color has been defined.
            // Just access them — if any were missing the struct wouldn't compile.
            _ = theme.palette.bg
            _ = theme.palette.accent
            _ = theme.palette.danger
            _ = theme.palette.warn
            _ = theme.palette.positive
        }
    }
}
