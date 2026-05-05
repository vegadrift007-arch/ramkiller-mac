import Foundation

public actor LeftoverScanner {
    public init() {}

    public struct ScanResult: Sendable {
        public let leftovers: [Leftover]
        public let hasFullDiskAccess: Bool
    }

    /// Backward-compatible shorthand — drops the TCC flag.
    public func scan(for app: AppInfo) async -> [Leftover] {
        await scanFull(for: app).leftovers
    }

    /// Returns leftovers + a TCC sentinel result so the UI can warn when access is missing.
    public func scanFull(for app: AppInfo) async -> ScanResult {
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let bid = sanitize(app.bundleIdentifier)
        let nameSafe = sanitize(app.name)
        let hasAccess = canReadLibrarySentinel(home: homeURL)
        guard !bid.isEmpty, !nameSafe.isEmpty else {
            return ScanResult(leftovers: [], hasFullDiskAccess: hasAccess)
        }
        let leftovers = collectLeftovers(homeURL: homeURL, bid: bid, nameSafe: nameSafe)
        return ScanResult(leftovers: leftovers, hasFullDiskAccess: hasAccess)
    }

    /// Probes ~/Library/Application Support readability. macOS gates many subdirs of ~/Library
    /// behind TCC ("Files and Folders" / "Full Disk Access") prompts; if the app hasn't been
    /// granted, fileExists() / contentsOfDirectory silently fail on those paths.
    private func canReadLibrarySentinel(home: URL) -> Bool {
        let path = home.appending(path: "Library/Application Support").path
        let entries = try? FileManager.default.contentsOfDirectory(atPath: path)
        return (entries?.count ?? 0) > 0
    }

    private func collectLeftovers(homeURL: URL, bid: String, nameSafe: String) -> [Leftover] {
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

        let candidatesSystem: [(String, Leftover.Kind)] = [
            ("/Library/LaunchAgents/\(bid).plist", .launchAgent),
            ("/Library/LaunchDaemons/\(bid).plist", .launchDaemon),
        ]

        var leftovers: [Leftover] = []
        for (url, kind) in candidatesUser {
            guard isWithin(url, root: homeURL) else { continue }
            if FileManager.default.fileExists(atPath: url.path) {
                leftovers.append(Leftover(id: url.path, path: url.path, size: url.diskSize(), kind: kind))
            }
        }
        for (path, kind) in candidatesSystem {
            if FileManager.default.fileExists(atPath: path) {
                let url = URL(fileURLWithPath: path)
                leftovers.append(Leftover(id: path, path: path, size: url.diskSize(), kind: kind))
            }
        }

        leftovers.append(contentsOf: scanPkgReceipts(bundleId: bid))

        let storagesDir = lib.appending(path: "HTTPStorages")
        if let entries = try? FileManager.default.contentsOfDirectory(atPath: storagesDir.path) {
            for e in entries where e.contains(bid) && !e.contains("..") && !e.contains("/") {
                let url = storagesDir.appending(path: e)
                guard isWithin(url, root: homeURL) else { continue }
                if !leftovers.contains(where: { $0.path == url.path }) {
                    leftovers.append(Leftover(id: url.path, path: url.path, size: url.diskSize(), kind: .httpStorage))
                }
            }
        }

        return leftovers.sorted { $0.size > $1.size }
    }

    /// Scans `pkgutil --pkgs` for receipts whose bundle id matches or shares a vendor prefix.
    private func scanPkgReceipts(bundleId: String) -> [Leftover] {
        let parts = bundleId.split(separator: ".")
        guard parts.count >= 2 else { return [] }
        let vendorPrefix = parts.prefix(2).joined(separator: ".")

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/pkgutil")
        task.arguments = ["--pkgs"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return []
        }
        guard task.terminationStatus == 0 else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return [] }

        return text
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && ($0 == bundleId || $0.hasPrefix(vendorPrefix + ".")) }
            .map { receipt in
                Leftover(id: "pkgutil:\(receipt)",
                         path: "pkgutil:\(receipt)",
                         size: 0,
                         kind: .pkgReceipt)
            }
    }

    private func sanitize(_ s: String) -> String {
        s.replacingOccurrences(of: "/", with: "")
         .replacingOccurrences(of: "\\", with: "")
         .replacingOccurrences(of: "..", with: "")
         .replacingOccurrences(of: "\0", with: "")
         .trimmingCharacters(in: .whitespaces)
    }

    private func isWithin(_ url: URL, root: URL) -> Bool {
        let r = root.standardizedFileURL.path
        let u = url.standardizedFileURL.path
        return u.hasPrefix(r + "/") || u == r
    }
}
