import XCTest
@testable import BeagleX

final class PathExpanderTests: XCTestCase {
    func testTildeExpansion() {
        let r = PathExpander.expand("~/Library")
        XCTAssertTrue(r.first?.hasPrefix("/Users/") == true)
        XCTAssertTrue(r.first?.hasSuffix("/Library") == true)
    }

    func testGlobMatchesCurrentDirContents() throws {
        let tmp = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        ["a.txt","b.txt","c.txt"].forEach {
            FileManager.default.createFile(atPath: tmp.appending(path: $0).path, contents: Data())
        }
        let matches = PathExpander.expand(tmp.path + "/*")
        XCTAssertEqual(Set(matches.map { ($0 as NSString).lastPathComponent }), ["a.txt","b.txt","c.txt"])
    }

    func testNonExistentPathReturnsEmpty() {
        let r = PathExpander.expand("/nonexistent/path/*")
        XCTAssertTrue(r.isEmpty)
    }
}
