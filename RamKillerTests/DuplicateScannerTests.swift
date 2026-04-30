import XCTest
@testable import RamKiller

final class DuplicateScannerTests: XCTestCase {
    func testIgnoresDistinctSameSizeFiles() async throws {
        let tmp = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let a = Data(repeating: 0x11, count: 2 * 1024 * 1024)
        let b = Data(repeating: 0x22, count: 2 * 1024 * 1024)

        try a.write(to: tmp.appending(path: "a.bin"))
        try b.write(to: tmp.appending(path: "b.bin"))

        let groups = await DuplicateScanner().scan(folders: [tmp], minSize: 1024 * 1024)
        XCTAssertEqual(groups.count, 0, "Files with same size but different content should not be grouped")
    }

    func testFindsExactDuplicates() async throws {
        let tmp = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let payload = Data(repeating: 0xab, count: 2 * 1024 * 1024)
        let unique  = Data(repeating: 0xcd, count: 2 * 1024 * 1024)

        try payload.write(to: tmp.appending(path: "a.bin"))
        try payload.write(to: tmp.appending(path: "b.bin"))
        try unique.write(to: tmp.appending(path: "c.bin"))

        let groups = await DuplicateScanner().scan(folders: [tmp], minSize: 1024 * 1024)
        XCTAssertGreaterThanOrEqual(groups.count, 1, "Should find at least one duplicate group for a.bin/b.bin")
        let firstGroup = groups[0]
        XCTAssertEqual(firstGroup.entries.count, 2)
    }
}
