import Foundation

public struct DuplicateGroup: Identifiable, Hashable {
    public let id: String         // common hash
    public let hash: String
    public let size: Int64
    public let entries: [LargeFileEntry]

    public var savings: Int64 {
        Int64(entries.count - 1) * size
    }
}
