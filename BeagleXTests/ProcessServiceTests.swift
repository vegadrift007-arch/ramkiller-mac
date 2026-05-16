import XCTest
@testable import BeagleX

final class ProcessServiceTests: XCTestCase {
    func testReadAllReturnsCurrentProcess() {
        let service = ProcessService()
        let all = service.readAll()
        XCTAssertGreaterThan(all.count, 50, "Mac always has 50+ processes")
        let me = ProcessInfo.processInfo.processIdentifier
        XCTAssertNotNil(all.first { $0.pid == me })
    }

    func testTopByRSSReturnsAtMostNAndIsSorted() {
        let service = ProcessService()
        let top = service.topByRSS(limit: 30)
        XCTAssertLessThanOrEqual(top.count, 30)
        for i in 1..<top.count {
            XCTAssertGreaterThanOrEqual(top[i-1].rssBytes, top[i].rssBytes)
        }
    }

    func testEachProcessHasNonEmptyName() {
        let service = ProcessService()
        let all = service.readAll()
        let nonEmpty = all.filter { !$0.name.isEmpty }
        // > 90% should have a parsable name; some kernel procs may not
        XCTAssertGreaterThan(Double(nonEmpty.count) / Double(all.count), 0.9)
    }
}
