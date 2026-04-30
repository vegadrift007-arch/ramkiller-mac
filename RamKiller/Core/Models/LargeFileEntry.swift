import Foundation

public struct LargeFileEntry: Identifiable, Hashable {
    public let id: String         // path
    public let path: String
    public let size: Int64
    public let modified: Date
    public let created: Date

    public var url: URL { URL(fileURLWithPath: path) }
    public var name: String { (path as NSString).lastPathComponent }
}
