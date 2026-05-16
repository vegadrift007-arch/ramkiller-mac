import Foundation
import Combine
import ServiceManagement

@MainActor
final class HelperManager: ObservableObject {
    static let shared = HelperManager()

    enum InstallStatus {
        case notRegistered
        case requiresApproval
        case enabled
        case unknown
    }

    private let plistName = "com.vannaq.BeagleXHelper.plist"
    private lazy var service: SMAppService = .daemon(plistName: plistName)

    @Published private(set) var status: InstallStatus = .unknown

    private init() {
        refresh()
    }

    func refresh() {
        switch service.status {
        case .enabled:           status = .enabled
        case .notRegistered:     status = .notRegistered
        case .requiresApproval:  status = .requiresApproval
        case .notFound:          status = .notRegistered
        @unknown default:        status = .unknown
        }
    }

    @discardableResult
    func install() -> String? {
        do {
            try service.register()
            refresh()
            return nil
        } catch {
            refresh()
            return error.localizedDescription
        }
    }

    @discardableResult
    func uninstall() -> String? {
        do {
            try service.unregister()
            refresh()
            return nil
        } catch {
            refresh()
            return error.localizedDescription
        }
    }

    /// Cycle the daemon: unregister + re-register. Forces launchd to load the
    /// current binary on disk (useful after rebuilding helper code).
    @discardableResult
    func restart() async -> String? {
        do {
            try await service.unregister()
        } catch {
            // ignore — service may not have been registered
        }
        // Brief pause so launchd flushes the unregistration before we re-register
        try? await Task.sleep(nanoseconds: 500_000_000)
        do {
            try service.register()
            refresh()
            return nil
        } catch {
            refresh()
            return error.localizedDescription
        }
    }
}
