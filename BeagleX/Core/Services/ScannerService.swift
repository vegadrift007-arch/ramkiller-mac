import Foundation

public actor ScannerService {
    public init() {}

    public func computeSize(for cleaner: Cleaner) -> Int64 {
        var total: Int64 = 0
        for p in cleaner.paths {
            for resolved in PathExpander.expand(p) {
                total += URL(fileURLWithPath: resolved).diskSize()
            }
        }
        return total
    }

    public func computeSizes(for cleaners: [Cleaner]) async -> [String: Int64] {
        await withTaskGroup(of: (String, Int64).self) { group in
            for c in cleaners {
                group.addTask { (c.id, await self.computeSize(for: c)) }
            }
            var result: [String: Int64] = [:]
            for await (id, size) in group {
                result[id] = size
            }
            return result
        }
    }
}
