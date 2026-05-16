// BeagleX/Features/Security/Checks/SuspiciousLaunchItemCheck.swift
import Foundation

struct SuspiciousLaunchItemCheck: SecurityCheck {
    let checkType: SecurityCheckType = .launchItem

    private static let dirs: [(path: String, label: String)] = [
        ("~/Library/LaunchAgents", "User LaunchAgent"),
        ("/Library/LaunchAgents",  "System LaunchAgent"),
        ("/Library/LaunchDaemons", "System LaunchDaemon"),
    ]

    func run() async -> [SecurityFinding] {
        var findings: [SecurityFinding] = []
        let fm = FileManager.default

        for (dirRaw, label) in Self.dirs {
            let dir = NSString(string: dirRaw).expandingTildeInPath
            guard let files = try? fm.contentsOfDirectory(atPath: dir) else { continue }

            for file in files where file.hasSuffix(".plist") {
                let plistPath = (dir as NSString).appendingPathComponent(file)
                guard let dict = NSDictionary(contentsOfFile: plistPath) else { continue }

                let program = (dict["ProgramArguments"] as? [String])?.first
                              ?? dict["Program"] as? String

                guard let program else {
                    findings.append(SecurityFinding(
                        checkType: .launchItem, severity: .warning,
                        title: "\(file) — no executable key",
                        detail: "LaunchAgent/Daemon has no Program or ProgramArguments · \(label)",
                        path: plistPath
                    ))
                    continue
                }

                guard fm.fileExists(atPath: program) else {
                    findings.append(SecurityFinding(
                        checkType: .launchItem, severity: .warning,
                        title: "\(file) — missing binary",
                        detail: "Binary not found: \(program) · \(label)",
                        path: plistPath
                    ))
                    continue
                }

                if !CodeSignChecker.isSigned(program) {
                    findings.append(SecurityFinding(
                        checkType: .launchItem, severity: .warning,
                        title: "\(file) — unsigned binary",
                        detail: "Unsigned: \(program) · \(label)",
                        path: plistPath
                    ))
                }
            }
        }
        return findings
    }
}
