import Foundation
import Darwin

enum KillOperation {
    /// Whitelisted signals only (helper refuses other signals).
    private static let allowedSignals: Set<Int32> = [SIGTERM, SIGKILL]

    /// PIDs we never let anyone kill (kernel_task, launchd).
    private static let forbiddenPIDs: Set<Int32> = [0, 1]

    enum Outcome {
        case success
        case denied(reason: String)
        case failed(error: String)
    }

    static func run(pid: Int32, signal: Int32) -> Outcome {
        guard allowedSignals.contains(signal) else {
            return .denied(reason: "Signal \(signal) not allowed (only SIGTERM=15, SIGKILL=9)")
        }
        guard !forbiddenPIDs.contains(pid) else {
            return .denied(reason: "PID \(pid) is protected")
        }
        let result = kill(pid, signal)
        if result == 0 {
            return .success
        }
        let err = String(cString: strerror(errno))
        return .failed(error: "kill(\(pid),\(signal)) failed: \(err)")
    }
}
