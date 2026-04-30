import XCTest
import SwiftData
@testable import RamKiller

@MainActor
final class UserActionLogTests: XCTestCase {
    func testRecordPersistsRow() throws {
        let schema = Schema([UserAction.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let log = UserActionLog(context: ModelContext(container))

        log.record(type: "purge", success: true)
        log.record(type: "kill", target: "1234", success: false, error: "no permission")

        let ctx = ModelContext(container)
        let all = try ctx.fetch(FetchDescriptor<UserAction>())
        XCTAssertEqual(all.count, 2)
    }
}
