import Foundation

public final class CleanerService {
    public init() {}

    public struct CleanResult {
        public let cleanerId: String
        public let bytesFreed: Int64
        public let errors: [String]
    }

    @MainActor
    public func clean(_ cleaners: [Cleaner], moveToTrash: Bool = true) async -> [CleanResult] {
        var results: [CleanResult] = []
        for cleaner in cleaners {
            var freed: Int64 = 0
            var errs: [String] = []
            for p in cleaner.paths {
                for resolved in PathExpander.expand(p) {
                    let url = URL(fileURLWithPath: resolved)
                    let size = sizeOf(url)
                    do {
                        if moveToTrash {
                            var resulting: NSURL?
                            try FileManager.default.trashItem(at: url, resultingItemURL: &resulting)
                        } else {
                            try FileManager.default.removeItem(at: url)
                        }
                        freed += size
                    } catch {
                        errs.append("\(resolved): \(error.localizedDescription)")
                    }
                }
            }
            results.append(CleanResult(cleanerId: cleaner.id, bytesFreed: freed, errors: errs))
            UserActionLog.shared.record(
                type: "clean_cache",
                target: cleaner.id,
                success: errs.isEmpty,
                error: errs.first,
                bytesFreed: freed
            )
        }
        return results
    }

    private func sizeOf(_ url: URL) -> Int64 {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        if isDir.boolValue {
            var total: Int64 = 0
            if let e = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) {
                for case let f as URL in e {
                    let r = try? f.resourceValues(forKeys: [.fileSizeKey])
                    total += Int64(r?.fileSize ?? 0)
                }
            }
            return total
        }
        let r = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(r?.fileSize ?? 0)
    }
}
