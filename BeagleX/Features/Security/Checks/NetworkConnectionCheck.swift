// BeagleX/Features/Security/Checks/NetworkConnectionCheck.swift
import Foundation
import Darwin

struct NetworkConnectionCheck: SecurityCheck {
    let checkType: SecurityCheckType = .network

    func run() async -> [SecurityFinding] {
        let pids = establishedPIDs()
        var findings: [SecurityFinding] = []
        var seen = Set<pid_t>()

        for pid in pids {
            guard !seen.contains(pid) else { continue }
            seen.insert(pid)

            guard let execPath = execPath(for: pid) else { continue }
            guard !execPath.hasPrefix("/System/"),
                  !execPath.hasPrefix("/usr/"),
                  !execPath.hasPrefix("/sbin/") else { continue }

            if !CodeSignChecker.isSigned(execPath) {
                let name = URL(fileURLWithPath: execPath).lastPathComponent
                findings.append(SecurityFinding(
                    checkType: .network, severity: .warning,
                    title: "\(name) — unsigned with active connection",
                    detail: "Unsigned binary at \(execPath) has established TCP connections",
                    path: execPath
                ))
            }
        }
        return findings
    }

    private func establishedPIDs() -> [pid_t] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        p.arguments = ["-nP", "-iTCP", "-sTCP:ESTABLISHED", "-F", "p"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        try? p.run()
        // Read stdout BEFORE waitUntilExit — otherwise lsof blocks when pipe buffer fills up,
        // and waitUntilExit never returns (classic pipe deadlock).
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        let out = String(data: data, encoding: .utf8) ?? ""
        return out.components(separatedBy: .newlines)
            .filter { $0.hasPrefix("p") }
            .compactMap { pid_t($0.dropFirst()) }
    }

    private func execPath(for pid: pid_t) -> String? {
        var buf = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let len = proc_pidpath(pid, &buf, UInt32(MAXPATHLEN))
        guard len > 0 else { return nil }
        return String(cString: buf)
    }
}
