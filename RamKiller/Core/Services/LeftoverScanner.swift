import Foundation

public actor LeftoverScanner {
    public init() {}

    public func scan(for app: AppInfo) async -> [Leftover] {
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let bid = sanitize(app.bundleIdentifier)
        let nameSafe = sanitize(app.name)

        // Reject bundle ids that would escape — bundle id should be reverse-DNS only
        guard !bid.isEmpty, !nameSafe.isEmpty else { return [] }

        // Build candidate URLs via URL.appendingPathComponent (validates path components)
        // rather than string interpolation
        let lib = homeURL.appending(path: "Library")
        let candidatesUser: [(URL, Leftover.Kind)] = [
            (lib.appending(path: "Application Support").appending(path: nameSafe), .applicationSupport),
            (lib.appending(path: "Application Support").appending(path: bid), .applicationSupport),
            (lib.appending(path: "Caches").appending(path: bid), .caches),
            (lib.appending(path: "Caches").appending(path: nameSafe), .caches),
            (lib.appending(path: "Preferences").appending(path: "\(bid).plist"), .preferences),
            (lib.appending(path: "Logs").appending(path: nameSafe), .logs),
            (lib.appending(path: "Logs").appending(path: bid), .logs),
            (lib.appending(path: "Containers").appending(path: bid), .container),
            (lib.appending(path: "Group Containers").appending(path: "group.\(bid)"), .groupContainer),
            (lib.appending(path: "Saved Application State").appending(path: "\(bid).savedState"), .savedState),
            (lib.appending(path: "HTTPStorages").appending(path: bid), .httpStorage),
            (lib.appending(path: "HTTPStorages").appending(path: "\(bid).binarycookies"), .httpStorage),
            (lib.appending(path: "LaunchAgents").appending(path: "\(bid).plist"), .launchAgent),
        ]

        // System paths — keep as plain strings since /Library/... is fixed
        let candidatesSystem: [(String, Leftover.Kind)] = [
            ("/Library/LaunchAgents/\(bid).plist", .launchAgent),
            ("/Library/LaunchDaemons/\(bid).plist", .launchDaemon),
        ]

        var leftovers: [Leftover] = []
        for (url, kind) in candidatesUser {
            // Final containment check: resolved url must be within home directory
            guard isWithin(url, root: homeURL) else { continue }
            if FileManager.default.fileExists(atPath: url.path) {
                leftovers.append(Leftover(id: url.path, path: url.path, size: sizeOf(path: url.path), kind: kind))
            }
        }
        for (path, kind) in candidatesSystem {
            if FileManager.default.fileExists(atPath: path) {
                leftovers.append(Leftover(id: path, path: path, size: sizeOf(path: path), kind: kind))
            }
        }

        // Glob: anything in HTTPStorages containing bundle id
        let storagesDir = lib.appending(path: "HTTPStorages")
        if let entries = try? FileManager.default.contentsOfDirectory(atPath: storagesDir.path) {
            for e in entries where e.contains(bid) && !e.contains("..") && !e.contains("/") {
                let url = storagesDir.appending(path: e)
                guard isWithin(url, root: homeURL) else { continue }
                if !leftovers.contains(where: { $0.path == url.path }) {
                    leftovers.append(Leftover(id: url.path, path: url.path, size: sizeOf(path: url.path), kind: .httpStorage))
                }
            }
        }

        return leftovers.sorted { $0.size > $1.size }
    }

    /// Strips path-traversal characters from a string before using it as a path component.
    /// Bundle IDs and app names can in principle contain anything; we sanitize aggressively.
    private func sanitize(_ s: String) -> String {
        s.replacingOccurrences(of: "/", with: "")
         .replacingOccurrences(of: "\\", with: "")
         .replacingOccurrences(of: "..", with: "")
         .replacingOccurrences(of: "\0", with: "")
         .trimmingCharacters(in: .whitespaces)
    }

    /// Verifies a URL stays within the given root after standardization.
    private func isWithin(_ url: URL, root: URL) -> Bool {
        let r = root.standardizedFileURL.path
        let u = url.standardizedFileURL.path
        return u.hasPrefix(r + "/") || u == r
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
