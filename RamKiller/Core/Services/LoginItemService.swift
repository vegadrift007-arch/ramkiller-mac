import Foundation
import ServiceManagement

final class LoginItemService {
    static let shared = LoginItemService()

    private let service: SMAppService

    private init() {
        self.service = .mainApp
    }

    var status: SMAppService.Status {
        service.status
    }

    @discardableResult
    func register() -> Result<Void, Error> {
        do {
            try service.register()
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    @discardableResult
    func unregister() -> Result<Void, Error> {
        do {
            try service.unregister()
            return .success(())
        } catch {
            return .failure(error)
        }
    }
}
