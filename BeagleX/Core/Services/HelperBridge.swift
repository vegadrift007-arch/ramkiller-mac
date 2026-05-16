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
        HelperManager.shared.refresh()
        guard HelperManager.shared.status == .enabled else {
            throw BridgeError.helperNotInstalled
        }
        let conn = makeConnection()
        let cmdData = try JSONEncoder().encode(command)
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<HelperResult, Error>) in
            // Resume exactly once — either via the reply block or via XPC error handler.
            // Without this, code-signing rejection / connection invalidation leaks the continuation.
            let resumed = ResumeOnce()
            let proxy = conn.remoteObjectProxyWithErrorHandler { err in
                resumed.fire {
                    cont.resume(throwing: BridgeError.unreachable(err.localizedDescription))
                }
            } as? HelperProtocol

            guard let proxy else {
                resumed.fire {
                    cont.resume(throwing: BridgeError.unreachable("proxy nil"))
                }
                return
            }

            proxy.execute(commandData: cmdData) { resData in
                resumed.fire {
                    do {
                        let result = try JSONDecoder().decode(HelperResult.self, from: resData)
                        cont.resume(returning: result)
                    } catch {
                        cont.resume(throwing: BridgeError.decodeError(error.localizedDescription))
                    }
                }
            }
        }
    }

    func helperVersion() async -> String? {
        guard HelperManager.shared.status == .enabled else { return nil }
        let conn = makeConnection()
        return await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
            let resumed = ResumeOnce()

            // 2-second watchdog: if neither the reply nor the error handler fires
            // (e.g. helper is unresponsive), we still resume the continuation.
            let watchdog = DispatchSource.makeTimerSource(queue: .main)
            watchdog.schedule(deadline: .now() + 2)
            watchdog.setEventHandler { resumed.fire { cont.resume(returning: nil) } }
            watchdog.resume()

            let proxy = conn.remoteObjectProxyWithErrorHandler { _ in
                watchdog.cancel()
                resumed.fire { cont.resume(returning: nil) }
            } as? HelperProtocol

            guard let proxy else {
                watchdog.cancel()
                resumed.fire { cont.resume(returning: nil) }
                return
            }

            proxy.helperVersion { v in
                watchdog.cancel()
                resumed.fire { cont.resume(returning: v) }
            }
        }
    }

    /// Sends a command and records the outcome to UserActionLog in one shot.
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
        let conn = NSXPCConnection(machServiceName: "com.vannaq.BeagleXHelper", options: .privileged)
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

/// Helper that ensures a continuation is resumed exactly once, even when both
/// the XPC reply and the error handler fire (or neither does).
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func fire(_ block: () -> Void) {
        lock.lock()
        let wasDone = done
        done = true
        lock.unlock()
        if !wasDone {
            block()
        }
    }
}
