import Foundation
import Darwin
import Shared

enum KillOperation {
    /// Whitelisted signals only (helper refuses other signals).
    private static let allowedSignals: Set<Int32> = [SIGTERM, SIGKILL]

    /// Process names we never let anyone kill — even via the helper.
    /// Killing any of these would brick the user session or destabilize the OS.
    private static let criticalProcessNames: Set<String> = [
        "kernel_task",
        "launchd",
        "WindowServer",
        "loginwindow",
        "Dock",
        "Finder",
        "tccd",
        "cfprefsd",
        "distnoted",
        "coreaudiod",
        "opendirectoryd",
        "securityd",
        "trustd",
        "notifyd",
        "mds",
        "mds_stores",
        "mdworker_shared",
        "logd",
        "systemstats",
        "powerd",
        "amfid"
    ]

    static func run(pid: Int32, signal: Int32) -> HelperResult {
        // 1. Must be a positive PID > 1 — rejects 0, 1, and negative (process-group/all-procs).
        // kill(-1, SIGKILL) sent from root nukes everything except init.
        guard pid > 1 else {
            return .denied(reason: "PID \(pid) is protected (only PIDs > 1 allowed)")
        }
        // 2. Whitelisted signals only
        guard allowedSignals.contains(signal) else {
            return .denied(reason: "Signal \(signal) not allowed (only SIGTERM=15, SIGKILL=9)")
        }
        // 3. Check process name against critical list
        if let name = processName(pid: pid), criticalProcessNames.contains(name) {
            return .denied(reason: "Process '\(name)' is protected (system-critical)")
        }
        // 4. Execute
        let result = kill(pid, signal)
        if result == 0 {
            return .success
        }
        let err = String(cString: strerror(errno))
        return .failed(error: "kill(\(pid),\(signal)) failed: \(err)")
    }

    /// Reads the process executable name via proc_pidpath. Returns nil if not found.
    private static func processName(pid: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: 4096)
        let n = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard n > 0 else { return nil }
        let path = String(cString: buffer)
        return (path as NSString).lastPathComponent
    }
}
