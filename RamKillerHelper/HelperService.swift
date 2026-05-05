import Foundation
import Shared

final class HelperService: NSObject, NSXPCListenerDelegate, HelperProtocol {
    static let version = "0.4.1-debug"

    private static let maxCommandBytes = 64 * 1024

    private static let codeSigningRequirement =
        "identifier \"com.vannaq.RamKiller\" and anchor apple generic " +
        "and certificate leaf[subject.OU] = \"6G8MT5T376\""

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection conn: NSXPCConnection) -> Bool {
        NSLog("[helper] shouldAcceptNewConnection — pid=%d euid=%d", conn.processIdentifier, conn.effectiveUserIdentifier)

        // DEBUG: temporarily disable code-signing requirement to rule it out as the cause.
        // Will re-enable once we confirm XPC roundtrip works.
        // conn.setCodeSigningRequirement(Self.codeSigningRequirement)

        conn.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        conn.exportedObject = self
        conn.resume()
        NSLog("[helper] connection accepted")
        return true
    }

    func helperVersion(reply: @escaping (String) -> Void) {
        NSLog("[helper] helperVersion called → returning %@", Self.version)
        reply(Self.version)
    }

    func execute(commandData: Data, reply: @escaping (Data) -> Void) {
        NSLog("[helper] execute called, %d bytes", commandData.count)
        guard commandData.count <= Self.maxCommandBytes else {
            let err = HelperResult.denied(reason: "command too large (\(commandData.count) bytes)")
            reply((try? JSONEncoder().encode(err)) ?? Data())
            return
        }
        do {
            let cmd = try JSONDecoder().decode(HelperCommand.self, from: commandData)
            NSLog("[helper] decoded cmd: %@", String(describing: cmd))
            let result = run(cmd)
            NSLog("[helper] result: %@", String(describing: result))
            let data = try JSONEncoder().encode(result)
            reply(data)
        } catch {
            NSLog("[helper] decode error: %@", error.localizedDescription)
            let err = HelperResult.failed(error: "decode failed: \(error.localizedDescription)")
            let data = (try? JSONEncoder().encode(err)) ?? Data()
            reply(data)
        }
    }

    private func run(_ cmd: HelperCommand) -> HelperResult {
        switch cmd {
        case .purgeMemory:
            if let err = PurgeOperation.run() { return .failed(error: err) }
            return .success
        case .killProcess(let pid, let sig):
            return KillOperation.run(pid: pid, signal: sig)
        case .unloadLaunchPlist(let path):
            return LaunchItemOperation.unload(path: path)
        case .loadLaunchPlist(let path):
            return LaunchItemOperation.load(path: path)
        case .renamePlist(let from, let to):
            return LaunchItemOperation.rename(from: from, to: to)
        case .deletePlist(let path):
            return LaunchItemOperation.delete(path: path)
        case .removeAppBundle(let path):
            return AppBundleOperation.remove(path: path)
        case .forgetPkgReceipt(let id):
            return PkgReceiptOperation.forget(id: id)
        }
    }
}
