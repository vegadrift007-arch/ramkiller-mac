import Foundation

public extension URL {
    /// Recursive on-disk size of this file or directory in bytes.
    /// Returns 0 if the path does not exist or is unreadable.
    func diskSize(skipPackages: Bool = true) -> Int64 {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else { return 0 }
        if isDir.boolValue {
            var total: Int64 = 0
            var options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles]
            if skipPackages { options.insert(.skipsPackageDescendants) }
            if let e = FileManager.default.enumerator(at: self, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: options) {
                for case let f as URL in e {
                    let r = try? f.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                    if r?.isDirectory == false {
                        total += Int64(r?.fileSize ?? 0)
                    }
                }
            }
            return total
        }
        let r = try? resourceValues(forKeys: [.fileSizeKey])
        return Int64(r?.fileSize ?? 0)
    }
}
