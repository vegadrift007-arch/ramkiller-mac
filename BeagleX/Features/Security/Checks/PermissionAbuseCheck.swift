// BeagleX/Features/Security/Checks/PermissionAbuseCheck.swift
import AppKit

struct PermissionAbuseCheck: SecurityCheck {
    let checkType: SecurityCheckType = .permission

    private static let highRisk: Set<String> = [
        "kTCCServiceSystemPolicyAllFiles",
        "kTCCServiceMicrophone",
        "kTCCServiceCamera",
        "kTCCServiceScreenCapture",
        "kTCCServiceAccessibility",
    ]

    private static let readable: [String: String] = [
        "kTCCServiceSystemPolicyAllFiles": "Full Disk Access",
        "kTCCServiceMicrophone":           "Microphone",
        "kTCCServiceCamera":               "Camera",
        "kTCCServiceScreenCapture":        "Screen Recording",
        "kTCCServiceAccessibility":        "Accessibility",
    ]

    func run() async -> [SecurityFinding] {
        let tccPath = NSString(string:
            "~/Library/Application Support/com.apple.TCC/TCC.db"
        ).expandingTildeInPath

        guard FileManager.default.isReadableFile(atPath: tccPath) else {
            return [SecurityFinding(
                checkType: .permission, severity: .info,
                title: String(localized: "Full Disk Access required"),
                detail: String(localized: "Grant Full Disk Access in System Settings → Privacy & Security to enable permission scanning")
            )]
        }

        let rows = queryTCC(at: tccPath)

        var servicesByApp: [String: Set<String>] = [:]
        for (bundleID, service) in rows where Self.highRisk.contains(service) {
            servicesByApp[bundleID, default: []].insert(service)
        }

        var findings: [SecurityFinding] = []
        for (bundleID, services) in servicesByApp where services.count >= 2 {
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            else { continue }
            let appPath = appURL.path
            guard !CodeSignChecker.isSigned(appPath) else { continue }

            let appName = appURL.deletingPathExtension().lastPathComponent
            let list = services.compactMap { Self.readable[$0] }.sorted().joined(separator: ", ")
            findings.append(SecurityFinding(
                checkType: .permission, severity: .critical,
                title: "\(appName) — permission abuse",
                detail: "Unsigned app holds: \(list)",
                path: appPath, bundleID: bundleID
            ))
        }
        return findings
    }

    private func queryTCC(at path: String) -> [(String, String)] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        // auth_value=2 is the "allowed" value on macOS Ventura+ (14.4+ deployment target).
        // Fallback OR covers older schema where the column was named `allowed`.
        p.arguments = [path, "SELECT client, service FROM access WHERE (auth_value=2 OR allowed=1) AND client_type=0;"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        try? p.run()
        // Read stdout BEFORE waitUntilExit to prevent pipe buffer deadlock.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { return [] }
        let out = String(data: data, encoding: .utf8) ?? ""
        return out.components(separatedBy: .newlines).compactMap { line -> (String, String)? in
            let parts = line.components(separatedBy: "|")
            guard parts.count == 2 else { return nil }
            return (parts[0].trimmingCharacters(in: .whitespaces),
                    parts[1].trimmingCharacters(in: .whitespaces))
        }
    }
}
