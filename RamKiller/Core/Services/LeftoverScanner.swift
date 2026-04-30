import Foundation

public actor LeftoverScanner {
    public init() {}

    public func scan(for app: AppInfo) async -> [Leftover] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let bid = app.bundleIdentifier
        let nameSafe = app.name

        let candidates: [(String, Leftover.Kind)] = [
            ("\(home)/Library/Application Support/\(nameSafe)", .applicationSupport),
            ("\(home)/Library/Application Support/\(bid)", .applicationSupport),
            ("\(home)/Library/Caches/\(bid)", .caches),
            ("\(home)/Library/Caches/\(nameSafe)", .caches),
            ("\(home)/Library/Preferences/\(bid).plist", .preferences),
            ("\(home)/Library/Logs/\(nameSafe)", .logs),
            ("\(home)/Library/Logs/\(bid)", .logs),
            ("\(home)/Library/Containers/\(bid)", .container),
            ("\(home)/Library/Group Containers/group.\(bid)", .groupContainer),
            ("\(home)/Library/Saved Application State/\(bid).savedState", .savedState),
            ("\(home)/Library/HTTPStorages/\(bid)", .httpStorage),
            ("\(home)/Library/HTTPStorages/\(bid).binarycookies", .httpStorage),
            ("\(home)/Library/LaunchAgents/\(bid).plist", .launchAgent),
            ("/Library/LaunchAgents/\(bid).plist", .launchAgent),
            ("/Library/LaunchDaemons/\(bid).plist", .launchDaemon),
        ]

        var leftovers: [Leftover] = []
        for (path, kind) in candidates {
            if FileManager.default.fileExists(atPath: path) {
                let size = sizeOf(path: path)
                leftovers.append(Leftover(id: path, path: path, size: size, kind: kind))
            }
        }

        // Glob: anything in HTTPStorages containing bundle id
        let storagesDir = "\(home)/Library/HTTPStorages"
        if let entries = try? FileManager.default.contentsOfDirectory(atPath: storagesDir) {
            for e in entries where e.contains(bid) {
                let path = "\(storagesDir)/\(e)"
                if !leftovers.contains(where: { $0.path == path }) {
                    leftovers.append(Leftover(id: path, path: path, size: sizeOf(path: path), kind: .httpStorage))
                }
            }
        }

        return leftovers.sorted { $0.size > $1.size }
    }

    private func sizeOf(path: String) -> Int64 {
        let url = URL(fileURLWithPath: path)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else { return 0 }
        if isDir.boolValue {
            var total: Int64 = 0
            if let e = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
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
