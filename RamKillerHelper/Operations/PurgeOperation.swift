import Foundation
import Darwin

enum PurgeOperation {
    /// Calls `/usr/sbin/purge` (system binary) which triggers vm_purge_inactive.
    /// Returns nil on success or an error string.
    static func run() -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/purge")
        let stderr = Pipe()
        task.standardError = stderr
        task.standardOutput = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus == 0 {
                return nil
            }
            let data = stderr.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: data, encoding: .utf8) ?? "exit \(task.terminationStatus)"
            return "purge failed: \(msg)"
        } catch {
            return "purge launch failed: \(error.localizedDescription)"
        }
    }
}
