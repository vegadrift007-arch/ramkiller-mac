import Foundation
import Shared

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

        // 1. Remove the .app bundle (always user-writable in /Applications or ~/Applications)
        do {
            try FileManager.default.remove(app.bundleURL, toTrash: moveToTrash)
            freed += app.bundleSize
        } catch {
            errs.append("\(app.bundleURL.path): \(error.localizedDescription)")
        }

        // 2. Leftovers — system paths go through helper, user paths direct
        for l in leftovers {
            if l.path.hasPrefix("/Library/") {
                // Helper accepts only .plist files under /Library/Launch{Agents,Daemons}/,
                // which is exactly what LeftoverScanner returns for these kinds.
                do {
                    let result = try await HelperBridge.shared.send(.deletePlist(path: l.path))
                    switch result {
                    case .success:           freed += l.size
                    case .denied(let r):     errs.append("\(l.path): denied — \(r)")
                    case .failed(let e):     errs.append("\(l.path): \(e)")
                    }
                } catch {
                    errs.append("\(l.path): \(error.localizedDescription)")
                }
            } else {
                let url = URL(fileURLWithPath: l.path)
                do {
                    try FileManager.default.remove(url, toTrash: moveToTrash)
                    freed += l.size
                } catch {
                    errs.append("\(l.path): \(error.localizedDescription)")
                }
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
