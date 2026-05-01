import Foundation
import Shared

final class HelperService: NSObject, NSXPCListenerDelegate, HelperProtocol {
    static let version = "0.3.0"

    /// Cap incoming command size to prevent memory exhaustion DoS.
    private static let maxCommandBytes = 64 * 1024

    /// Code-signing requirement: caller must be RamKiller signed with our Apple Development team.
    /// Team ID 6G8MT5T376 is the personal team for vegadrift007@gmail.com.
    private static let codeSigningRequirement =
        "identifier \"com.vannaq.RamKiller\" and anchor apple generic " +
        "and certificate leaf[subject.OU] = \"6G8MT5T376\""

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection conn: NSXPCConnection) -> Bool {
        // Pin caller to our app's signing identity. Without this, any local process can drive root.
        conn.setCodeSigningRequirement(Self.codeSigningRequirement)
        conn.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        conn.exportedObject = self
        conn.resume()
        return true
    }

    // MARK: HelperProtocol

    func helperVersion(reply: @escaping (String) -> Void) {
        reply(Self.version)
    }

    func execute(commandData: Data, reply: @escaping (Data) -> Void) {
        guard commandData.count <= Self.maxCommandBytes else {
            let err = HelperResult.denied(reason: "command too large (\(commandData.count) bytes)")
            reply((try? JSONEncoder().encode(err)) ?? Data())
            return
        }
        do {
            let cmd = try JSONDecoder().decode(HelperCommand.self, from: commandData)
            let result = run(cmd)
            let data = try JSONEncoder().encode(result)
            reply(data)
        } catch {
            let err = HelperResult.failed(error: "decode failed: \(error.localizedDescription)")
            let data = (try? JSONEncoder().encode(err)) ?? Data()
            reply(data)
        }
    }

    private func run(_ cmd: HelperCommand) -> HelperResult {
        switch cmd {
        case .purgeMemory:
            if let err = PurgeOperation.run() {
                return .failed(error: err)
            }
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
        }
    }
}
