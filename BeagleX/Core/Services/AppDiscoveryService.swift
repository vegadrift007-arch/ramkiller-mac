import Foundation
import AppKit

public final class AppDiscoveryService {
    public init() {}

    /// Fast discovery — does NOT walk the bundle for size. Use `bundleSize(at:)` separately when needed.
    public func discover() -> [AppInfo] {
        let roots: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appending(path: "Applications")
        ]
        var seen = Set<String>()
        var apps: [AppInfo] = []
        for root in roots {
            guard FileManager.default.fileExists(atPath: root.path) else { continue }
            let contents = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
            for url in contents where url.pathExtension == "app" {
                guard let info = try? makeAppInfo(bundleURL: url, includeSize: false) else { continue }
                if seen.insert(info.bundleIdentifier).inserted {
                    apps.append(info)
                }
            }
        }
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func appInfo(at bundleURL: URL) -> AppInfo? {
        try? makeAppInfo(bundleURL: bundleURL, includeSize: false)
    }

    /// Computes bundle size on demand. Slow — call from background task.
    public func bundleSize(at url: URL) -> Int64 {
        var total: Int64 = 0
        if let e = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let f as URL in e {
                let v = try? f.resourceValues(forKeys: [.fileSizeKey])
                total += Int64(v?.fileSize ?? 0)
            }
        }
        return total
    }

    private func makeAppInfo(bundleURL: URL, includeSize: Bool) throws -> AppInfo {
        guard let bundle = Bundle(url: bundleURL),
              let bid = bundle.bundleIdentifier else {
            throw NSError(domain: "AppDiscovery", code: -1)
        }
        let infoDict = bundle.infoDictionary ?? [:]
        let name = (infoDict["CFBundleDisplayName"] as? String)
            ?? (infoDict["CFBundleName"] as? String)
            ?? bundleURL.deletingPathExtension().lastPathComponent
        let version = (infoDict["CFBundleShortVersionString"] as? String) ?? "—"
        let icon = NSWorkspace.shared.icon(forFile: bundleURL.path)
        let size: Int64 = includeSize ? bundleSize(at: bundleURL) : 0
        return AppInfo(
            id: bid,
            bundleIdentifier: bid,
            name: name,
            version: version,
            bundleURL: bundleURL,
            bundleSize: size,
            icon: icon
        )
    }
}
