import XCTest
@testable import Shared

final class HelperCommandTests: XCTestCase {
    func testPurgeRoundTrip() throws {
        let cmd: HelperCommand = .purgeMemory
        let data = try JSONEncoder().encode(cmd)
        let decoded = try JSONDecoder().decode(HelperCommand.self, from: data)
        XCTAssertEqual(decoded, cmd)
    }

    func testKillRoundTrip() throws {
        let cmd: HelperCommand = .killProcess(pid: 1234, signal: 15)
        let data = try JSONEncoder().encode(cmd)
        let decoded = try JSONDecoder().decode(HelperCommand.self, from: data)
        XCTAssertEqual(decoded, cmd)
    }

    func testHelperResultRoundTrip() throws {
        let r: HelperResult = .denied(reason: "test")
        let data = try JSONEncoder().encode(r)
        let decoded = try JSONDecoder().decode(HelperResult.self, from: data)
        XCTAssertEqual(decoded, r)
    }
}
