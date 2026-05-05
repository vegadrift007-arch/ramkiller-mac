import Foundation
import Shared

enum PkgReceiptOperation {
    static func forget(id: String) -> HelperResult {
        // Strict validation: pkg IDs are reverse-DNS, alphanumeric + dots + dashes + underscores.
        // No paths, no spaces, no special chars.
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_")
        guard !id.isEmpty,
              id.unicodeScalars.allSatisfy({ allowed.contains($0) }),
              !id.hasPrefix("."),
              !id.hasSuffix(".")
        else {
            return .denied(reason: "Invalid pkg ID format: \(id)")
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/pkgutil")
        task.arguments = ["--forget", id]
        task.environment = ["PATH": "/usr/sbin:/usr/bin:/sbin:/bin"]
        let stderr = Pipe()
        task.standardError = stderr
        task.standardOutput = Pipe()
        do {
            try task.run()
            let deadline = Date().addingTimeInterval(10)
            while task.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.05)
            }
            if task.isRunning {
                task.terminate()
                return .failed(error: "pkgutil --forget timed out")
            }
            if task.terminationStatus == 0 { return .success }
            let data = stderr.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: data, encoding: .utf8) ?? "exit \(task.terminationStatus)"
            return .failed(error: msg)
        } catch {
            return .failed(error: error.localizedDescription)
        }
    }
}
