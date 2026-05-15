// RamKiller/Features/Security/SecurityCheck.swift
import Foundation
import Darwin

protocol SecurityCheck: Sendable {
    var checkType: SecurityCheckType { get }
    func run() async -> [SecurityFinding]
}

/// Runs `codesign -v <path>` and returns true if the binary is signed.
enum CodeSignChecker {
    static func isSigned(_ path: String) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        p.arguments = ["-v", path]
        p.standardOutput = Pipe()
        p.standardError = Pipe()
        try? p.run()
        p.waitUntilExit()
        return p.terminationStatus == 0
    }
}

/// Glob-style pattern matching using Darwin fnmatch (supports * wildcard).
/// Pattern example: "*/com.shlayer.*"
func securityGlobMatch(pattern: String, path: String) -> Bool {
    fnmatch(pattern.lowercased(), path.lowercased(), 0) == 0
}
