import Foundation
import CryptoKit

public actor DuplicateScanner {
    public init() {}

    public func scan(folders: [URL], minSize: Int64 = 1_048_576) async -> [DuplicateGroup] {
        let entries = await LargeFileScanner().scan(folders: folders, minSize: minSize)
        let bySize = Dictionary(grouping: entries) { $0.size }.filter { $0.value.count > 1 }

        var groups: [DuplicateGroup] = []

        for (size, candidates) in bySize {
            // Stage 2: quick-hash on first 4KB
            let byQuick = Dictionary(grouping: candidates) { e -> String in
                quickHash(path: e.path) ?? UUID().uuidString
            }
            for (_, quickGroup) in byQuick where quickGroup.count > 1 {
                // Stage 3: full hash
                let byFull = Dictionary(grouping: quickGroup) { e -> String in
                    fullHash(path: e.path) ?? UUID().uuidString
                }
                for (hash, fullGroup) in byFull where fullGroup.count > 1 {
                    groups.append(DuplicateGroup(
                        id: hash, hash: hash, size: size,
                        entries: fullGroup.sorted { $0.created < $1.created }
                    ))
                }
            }
        }
        return groups.sorted { $0.savings > $1.savings }
    }

    private func quickHash(path: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 4096) else { return nil }
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func fullHash(path: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try? handle.read(upToCount: 65536), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        let digest = hasher.finalize()
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
