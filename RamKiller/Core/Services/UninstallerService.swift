import Foundation

public final class UninstallerService {
    public init() {}

    public struct UninstallResult {
        public let appName: String
        public let bytesFreed: Int64
        public let errors: [String]
    }

    @MainActor
    public func uninstall(app: AppInfo, leftovers: [Leftover], moveToTrash: Bool = true) async -> UninstallResult {
        var freed: Int64 = 0
        var errs: [String] = []

        // 1. Remove the .app bundle
        do {
            if moveToTrash {
                var resulting: NSURL?
                try FileManager.default.trashItem(at: app.bundleURL, resultingItemURL: &resulting)
            } else {
                try FileManager.default.removeItem(at: app.bundleURL)
            }
            freed += app.bundleSize
        } catch {
            errs.append("\(app.bundleURL.path): \(error.localizedDescription)")
        }

        // 2. Remove leftovers (user paths only — system paths would need helper extension)
        for l in leftovers {
            let url = URL(fileURLWithPath: l.path)
            do {
                if moveToTrash {
                    var resulting: NSURL?
                    try FileManager.default.trashItem(at: url, resultingItemURL: &resulting)
                } else {
                    try FileManager.default.removeItem(at: url)
                }
                freed += l.size
            } catch {
                errs.append("\(l.path): \(error.localizedDescription)")
            }
        }

        UserActionLog.shared.record(
            type: "uninstall",
            target: app.bundleIdentifier,
            success: errs.isEmpty,
            error: errs.first,
            bytesFreed: freed
        )

        return UninstallResult(appName: app.name, bytesFreed: freed, errors: errs)
    }
}
