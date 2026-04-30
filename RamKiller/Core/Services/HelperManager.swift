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

    private let plistName = "com.vannaq.RamKillerHelper.plist"
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
}
