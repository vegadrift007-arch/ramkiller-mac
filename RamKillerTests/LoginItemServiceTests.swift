import XCTest
import ServiceManagement
@testable import RamKiller

final class LoginItemServiceTests: XCTestCase {
    func testStatusReturnsKnownValue() {
        let status = LoginItemService.shared.status
        let known: [SMAppService.Status] = [.notRegistered, .enabled, .requiresApproval, .notFound]
        XCTAssertTrue(known.contains(status))
    }
}
