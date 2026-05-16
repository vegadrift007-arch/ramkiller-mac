import Foundation
import Darwin

enum PurgeOperation {
    /// Calls `/usr/sbin/purge` with a scrubbed env + bounded wait.
    /// Returns nil on success or an error string.
    static func run() -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/purge")
        task.environment = ["PATH": "/usr/sbin:/usr/bin:/sbin:/bin"]
        let stderr = Pipe()
        task.standardError = stderr
        task.standardOutput = Pipe()
        do {
            try task.run()
            // Bounded wait — purge usually finishes < 2s, but we cap at 30
            let deadline = Date().addingTimeInterval(30)
            while task.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.05)
            }
            if task.isRunning {
                task.terminate()
                return "purge timed out"
            }
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
