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

        NSLog("[uninstall] BEGIN app=%@ bundleId=%@ path=%@ leftovers=%d toTrash=%@",
              app.name, app.bundleIdentifier, app.bundleURL.path, leftovers.count, String(describing: moveToTrash))

        // 1. Remove the .app bundle
        // Strategy:
        //  a) Try FileManager directly (fast path for user-installed apps)
        //  b) On permission error, fall back to helper (for root-owned MDM/enterprise apps)
        do {
            NSLog("[uninstall] removing app bundle: %@", app.bundleURL.path)
            try FileManager.default.remove(app.bundleURL, toTrash: moveToTrash)
            freed += app.bundleSize
            NSLog("[uninstall]   → success (direct), +%lld bytes", app.bundleSize)
        } catch {
            let nsErr = error as NSError
            let isPermission = nsErr.domain == NSCocoaErrorDomain &&
                (nsErr.code == NSFileWriteNoPermissionError || nsErr.code == NSFileReadNoPermissionError)
            NSLog("[uninstall]   → direct failed (permission=%@): %@", String(isPermission), error.localizedDescription)
            if isPermission {
                // Fall back to helper — works for root-owned apps in /Applications.
                // Helper bypasses Trash and removes directly.
                NSLog("[uninstall]   → trying helper fallback")
                if let result = try? await HelperBridge.shared.send(.removeAppBundle(path: app.bundleURL.path)) {
                    switch result {
                    case .success:
                        freed += app.bundleSize
                        NSLog("[uninstall]   → helper success, +%lld bytes", app.bundleSize)
                    case .denied(let r):
                        errs.append("\(app.bundleURL.path): helper denied — \(r)")
                        NSLog("[uninstall]   → helper denied: %@", r)
                    case .failed(let e):
                        errs.append("\(app.bundleURL.path): \(e)")
                        NSLog("[uninstall]   → helper failed: %@", e)
                    }
                } else {
                    errs.append("\(app.bundleURL.path): \(error.localizedDescription) (helper not available)")
                }
            } else {
                errs.append("\(app.bundleURL.path): \(error.localizedDescription)")
            }
        }

        // 2. Leftovers
        for l in leftovers {
            NSLog("[uninstall] removing leftover: %@ (kind=%@, size=%lld)", l.path, l.kind.rawValue, l.size)
            if l.kind == .pkgReceipt {
                let id = l.path.hasPrefix("pkgutil:") ? String(l.path.dropFirst("pkgutil:".count)) : l.path
                do {
                    let result = try await HelperBridge.shared.send(.forgetPkgReceipt(id: id))
                    switch result {
                    case .success:           freed += l.size; NSLog("[uninstall]   → pkg forgot: %@", id)
                    case .denied(let r):     errs.append("\(l.path): denied — \(r)"); NSLog("[uninstall]   → denied: %@", r)
                    case .failed(let e):     errs.append("\(l.path): \(e)"); NSLog("[uninstall]   → failed: %@", e)
                    }
                } catch {
                    errs.append("\(l.path): \(error.localizedDescription)")
                    NSLog("[uninstall]   → throw: %@", error.localizedDescription)
                }
            } else if l.path.hasPrefix("/Library/") {
                do {
                    let result = try await HelperBridge.shared.send(.deletePlist(path: l.path))
                    switch result {
                    case .success:
                        freed += l.size
                        NSLog("[uninstall]   → helper success")
                    case .denied(let r):
                        errs.append("\(l.path): denied — \(r)")
                        NSLog("[uninstall]   → helper denied: %@", r)
                    case .failed(let e):
                        errs.append("\(l.path): \(e)")
                        NSLog("[uninstall]   → helper failed: %@", e)
                    }
                } catch {
                    errs.append("\(l.path): \(error.localizedDescription)")
                    NSLog("[uninstall]   → helper THROW: %@", error.localizedDescription)
                }
            } else {
                let url = URL(fileURLWithPath: l.path)
                do {
                    try FileManager.default.remove(url, toTrash: moveToTrash)
                    freed += l.size
                    NSLog("[uninstall]   → success")
                } catch {
                    errs.append("\(l.path): \(error.localizedDescription)")
                    NSLog("[uninstall]   → FAILED: %@", error.localizedDescription)
                }
            }
        }

        NSLog("[uninstall] DONE freed=%lld errors=%d", freed, errs.count)

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
