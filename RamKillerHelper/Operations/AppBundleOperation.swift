import Foundation
import Shared

enum AppBundleOperation {
    private static let allowedRoots = ["/Applications/"]

    static func remove(path: String) -> HelperResult {
        guard let resolved = canonicalize(path) else {
            return .denied(reason: "Path \(path) outside /Applications/ or not a .app bundle")
        }
        do {
            try FileManager.default.removeItem(atPath: resolved)
            return .success
        } catch {
            return .failed(error: error.localizedDescription)
        }
    }

    /// Path must:
    /// - Not contain `..` or null bytes
    /// - End in `.app`
    /// - Be directly inside /Applications/ (one level deep — no nested traversal)
    /// - After symlink resolution, still satisfy the above
    private static func canonicalize(_ path: String) -> String? {
        if path.contains("/../") || path.hasSuffix("/..") || path.hasPrefix("../") || path.contains("\0") {
            return nil
        }
        guard path.hasSuffix(".app") else { return nil }

        let url = URL(fileURLWithPath: path).standardizedFileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let resolved = url.resolvingSymlinksInPath().path

        for root in allowedRoots where resolved.hasPrefix(root) {
            // Must be EXACTLY one level deep: /Applications/X.app — no /Applications/Foo/X.app
            let suffix = String(resolved.dropFirst(root.count))
            if suffix.contains("/") { return nil }
            return resolved
        }
        return nil
    }
}
