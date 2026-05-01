import Foundation
import Shared

enum LaunchItemOperation {
    /// Allowed parent directories. Trailing slash is REQUIRED so prefix-checks reject siblings like `/Library/LaunchAgentsExtra/`.
    private static let allowedRoots = [
        "/Library/LaunchAgents/",
        "/Library/LaunchDaemons/"
    ]

    static func unload(path: String) -> HelperResult {
        guard let resolved = canonicalize(path) else {
            return .denied(reason: "Path \(path) outside allowed roots")
        }
        guard let label = readLabel(at: resolved) else {
            return .denied(reason: "Cannot read plist or missing Label key")
        }
        return runLaunchctl(args: ["bootout", "system/\(label)"])
    }

    static func load(path: String) -> HelperResult {
        guard let resolved = canonicalize(path) else {
            return .denied(reason: "Path \(path) outside allowed roots")
        }
        return runLaunchctl(args: ["bootstrap", "system", resolved])
    }

    static func rename(from: String, to: String) -> HelperResult {
        guard let resolvedFrom = canonicalize(from, allowMissing: false),
              let resolvedTo = canonicalize(to, allowMissing: true) else {
            return .denied(reason: "Path outside allowed roots")
        }
        do {
            try FileManager.default.moveItem(atPath: resolvedFrom, toPath: resolvedTo)
            return .success
        } catch {
            return .failed(error: error.localizedDescription)
        }
    }

    static func delete(path: String) -> HelperResult {
        guard let resolved = canonicalize(path) else {
            return .denied(reason: "Path \(path) outside allowed roots")
        }
        do {
            try FileManager.default.removeItem(atPath: resolved)
            return .success
        } catch {
            return .failed(error: error.localizedDescription)
        }
    }

    // MARK: - Path validation

    /// Canonicalizes a path and verifies it stays inside an allowed root.
    /// Rejects: traversal (`..`), wrong extension, escapes via symlinks, nested subdirs.
    private static func canonicalize(_ path: String, allowMissing: Bool = false) -> String? {
        if path.contains("/../") || path.hasSuffix("/..") || path.hasPrefix("../") || path.contains("\0") {
            return nil
        }
        guard path.hasSuffix(".plist") || path.hasSuffix(".plist.disabled") else {
            return nil
        }
        let url = URL(fileURLWithPath: path).standardizedFileURL
        let resolvedURL: URL
        if FileManager.default.fileExists(atPath: url.path) {
            resolvedURL = url.resolvingSymlinksInPath()
        } else if allowMissing {
            resolvedURL = url
        } else {
            return nil
        }
        let resolved = resolvedURL.path
        for root in allowedRoots where resolved.hasPrefix(root) {
            // Basename only — reject any further `/` after the prefix.
            let suffix = String(resolved.dropFirst(root.count))
            if suffix.contains("/") { return nil }
            return resolved
        }
        return nil
    }

    /// Reads the `Label` key from a plist. Returns nil if unreadable, missing, or contains path-like chars.
    private static func readLabel(at path: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let label = plist["Label"] as? String,
              !label.isEmpty,
              !label.contains("/"),
              !label.contains("..")
        else { return nil }
        return label
    }

    // MARK: - launchctl runner with bounded wait + scrubbed env

    private static func runLaunchctl(args: [String]) -> HelperResult {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = args
        task.environment = ["PATH": "/usr/sbin:/usr/bin:/sbin:/bin"]
        let stderr = Pipe()
        task.standardError = stderr
        task.standardOutput = Pipe()
        do {
            try task.run()
            let deadline = Date().addingTimeInterval(15)
            while task.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.05)
            }
            if task.isRunning {
                task.terminate()
                return .failed(error: "launchctl timed out")
            }
            if task.terminationStatus == 0 { return .success }
            let data = stderr.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: data, encoding: .utf8) ?? "exit \(task.terminationStatus)"
            return .failed(error: msg)
        } catch {
            return .failed(error: error.localizedDescription)
        }
    }
}
