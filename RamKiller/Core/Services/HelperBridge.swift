import Foundation
import Shared

@MainActor
final class HelperBridge {
    static let shared = HelperBridge()
    private var connection: NSXPCConnection?

    enum BridgeError: LocalizedError {
        case helperNotInstalled
        case unreachable(String)
        case decodeError(String)

        var errorDescription: String? {
            switch self {
            case .helperNotInstalled:    return "Privileged helper not installed (Settings → Privileged Helper)"
            case .unreachable(let m):    return "Helper unreachable: \(m)"
            case .decodeError(let m):    return "Result decode failed: \(m)"
            }
        }
    }

    func send(_ command: HelperCommand) async throws -> HelperResult {
        // Refresh status before sending — user may have disabled the helper externally
        // (System Settings → Login Items & Extensions) without our app knowing.
        HelperManager.shared.refresh()
        guard HelperManager.shared.status == .enabled else {
            throw BridgeError.helperNotInstalled
        }
        let conn = makeConnection()
        var proxyError: Error?
        let proxy = conn.remoteObjectProxyWithErrorHandler { err in
            proxyError = err
        } as? HelperProtocol
        guard let proxy else {
            throw BridgeError.unreachable("proxy nil: \(proxyError?.localizedDescription ?? "?")")
        }

        let cmdData = try JSONEncoder().encode(command)
        return try await withCheckedThrowingContinuation { cont in
            proxy.execute(commandData: cmdData) { resData in
                do {
                    let result = try JSONDecoder().decode(HelperResult.self, from: resData)
                    cont.resume(returning: result)
                } catch {
                    cont.resume(throwing: BridgeError.decodeError(error.localizedDescription))
                }
            }
        }
    }

    func helperVersion() async -> String? {
        guard HelperManager.shared.status == .enabled else { return nil }
        let conn = makeConnection()
        let proxy = conn.remoteObjectProxy as? HelperProtocol
        return await withCheckedContinuation { cont in
            proxy?.helperVersion { v in cont.resume(returning: v) } ?? cont.resume(returning: nil)
        }
    }

    /// Sends a command and records the outcome to UserActionLog in one shot.
    /// Returns the result on success/denied/failed; nil on transport error (which is also logged).
    func sendAndLog(
        _ command: HelperCommand,
        type: String,
        target: String? = nil,
        bytesFreed: Int64? = nil
    ) async -> HelperResult? {
        do {
            let result = try await send(command)
            switch result {
            case .success:
                UserActionLog.shared.record(type: type, target: target, success: true, bytesFreed: bytesFreed)
            case .denied(let r):
                UserActionLog.shared.record(type: type, target: target, success: false, error: r)
            case .failed(let e):
                UserActionLog.shared.record(type: type, target: target, success: false, error: e)
            }
            return result
        } catch {
            UserActionLog.shared.record(type: type, target: target, success: false, error: error.localizedDescription)
            return nil
        }
    }

    private func makeConnection() -> NSXPCConnection {
        if let conn = connection { return conn }
        let conn = NSXPCConnection(machServiceName: "com.vannaq.RamKillerHelper", options: .privileged)
        conn.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
        conn.invalidationHandler = { [weak self] in
            Task { @MainActor in self?.connection = nil }
        }
        conn.interruptionHandler = { [weak self] in
            Task { @MainActor in self?.connection = nil }
        }
        conn.resume()
        connection = conn
        return conn
    }
}
