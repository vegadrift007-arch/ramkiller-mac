import XCTest
@testable import BeagleX

final class ScannerServiceTests: XCTestCase {
    func testScanReturnsBytesForExistingPath() async throws {
        let tmp = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let bytes = "hello".data(using: .utf8)!
        try bytes.write(to: tmp.appending(path: "a.txt"))

        let cleaner = Cleaner(
            id: "test", name: "test", description: "test",
            category: .system, safety: .safe,
            paths: [tmp.path + "/*"],
            requiresHelper: false
        )

        let service = ScannerService()
        let size = await service.computeSize(for: cleaner)
        XCTAssertEqual(size, 5)
    }

    func testScanReturnsZeroForMissingPath() async {
        let cleaner = Cleaner(
            id: "missing", name: "missing", description: "",
            category: .system, safety: .safe,
            paths: ["/nonexistent/path/123/*"],
            requiresHelper: false
        )
        let size = await ScannerService().computeSize(for: cleaner)
        XCTAssertEqual(size, 0)
    }
}
