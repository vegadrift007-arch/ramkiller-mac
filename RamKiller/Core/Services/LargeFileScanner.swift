import Foundation

public actor LargeFileScanner {
    public init() {}

    public func scan(folders: [URL], minSize: Int64) async -> [LargeFileEntry] {
        var results: [LargeFileEntry] = []
        for folder in folders {
            results.append(contentsOf: walkAndCollect(folder: folder, minSize: minSize))
        }
        return results.sorted { $0.size > $1.size }
    }

    private func walkAndCollect(folder: URL, minSize: Int64) -> [LargeFileEntry] {
        var out: [LargeFileEntry] = []
        guard FileManager.default.fileExists(atPath: folder.path) else { return out }
        let resKeys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey, .creationDateKey, .isRegularFileKey, .isPackageKey]
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: resKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return out }

        for case let url as URL in enumerator {
            do {
                let v = try url.resourceValues(forKeys: Set(resKeys))
                guard v.isRegularFile == true, v.isPackage != true else { continue }
                let size = Int64(v.fileSize ?? 0)
                if size >= minSize {
                    out.append(LargeFileEntry(
                        id: url.path, path: url.path, size: size,
                        modified: v.contentModificationDate ?? Date.distantPast,
                        created: v.creationDate ?? v.contentModificationDate ?? Date.distantPast
                    ))
                }
            } catch {
                continue
            }
        }
        return out
    }
}
