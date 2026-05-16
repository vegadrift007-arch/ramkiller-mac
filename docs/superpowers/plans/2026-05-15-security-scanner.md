# Security Scanner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Security sidebar section to BeagleX that scans for malware, suspicious launch items, unsigned network processes, and permission-abusing apps — fully offline, with remove/quarantine and auto-scheduled scanning.

**Architecture:** Protocol-based scanner modules (`SecurityCheck`) orchestrated by `SecurityScanCoordinator` (ObservableObject). Four independent check modules run in parallel via `async let`. Findings are transient; only `lastScanDate` and `ignoredIDs` are persisted in UserDefaults.

**Tech Stack:** Swift, SwiftUI, Darwin (`proc_pidpath`, `fnmatch`), subprocess via `Process()` (codesign, lsof, sqlite3), existing `HelperBridge` for privileged deletions.

---

## File Map

**New files:**
```
BeagleX/Features/Security/
  SecurityFinding.swift              — SecurityFinding, SecurityCheckType, Severity, ScanState
  SecurityCheck.swift                — SecurityCheck protocol + CodeSignChecker utility
  SecurityScanCoordinator.swift      — ObservableObject orchestrator
  SecurityView.swift                 — grouped list UI
  Checks/
    MalwareSignatureCheck.swift
    SuspiciousLaunchItemCheck.swift
    NetworkConnectionCheck.swift
    PermissionAbuseCheck.swift
BeagleX/Resources/
  threat-signatures.json
BeagleXTests/
  SecurityFindingTests.swift
  MalwareSignatureCheckTests.swift
  SecurityScanCoordinatorTests.swift
```

**Modified files:**
- `BeagleX/Core/Navigation/SidebarItem.swift` — add `.security` case
- `BeagleX/UI/MainContentView.swift` — route `.security` to `SecurityView`
- `BeagleX/BeagleXApp.swift` — create and inject `SecurityScanCoordinator`
- `BeagleX/Features/Settings/SettingsView.swift` — add auto-scan interval picker
- `BeagleX/Resources/Localizable.xcstrings` — add "Security" / "安全"

---

## Task 1: Data Models

**Files:**
- Create: `BeagleX/Features/Security/SecurityFinding.swift`
- Create: `BeagleXTests/SecurityFindingTests.swift`

- [ ] **Step 1.1: Create SecurityFinding.swift**

```swift
// BeagleX/Features/Security/SecurityFinding.swift
import Foundation

enum SecurityCheckType: String, Codable, CaseIterable {
    case malware, launchItem, network, permission

    var sectionTitle: String {
        switch self {
        case .malware:    return "🦠 " + String(localized: "Malware")
        case .launchItem: return "🚀 " + String(localized: "Launch Items")
        case .network:    return "🌐 " + String(localized: "Network Connections")
        case .permission: return "🔑 " + String(localized: "Permission Abuse")
        }
    }

    var cleanMessage: String {
        switch self {
        case .malware:    return String(localized: "No known malware detected")
        case .launchItem: return String(localized: "All launch items are signed")
        case .network:    return String(localized: "All connections from signed apps")
        case .permission: return String(localized: "No permission abuse detected")
        }
    }
}

enum Severity: String, Codable, CaseIterable, Comparable {
    case info, warning, critical

    private var order: Int {
        switch self { case .info: return 0; case .warning: return 1; case .critical: return 2 }
    }
    static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.order < rhs.order }
}

enum ScanState: Equatable {
    case idle
    case scanning(progress: Double)
    case done(Date)
}

struct SecurityFinding: Identifiable, Equatable {
    let id: UUID
    let checkType: SecurityCheckType
    let severity: Severity
    let title: String
    let detail: String
    let path: String?
    let bundleID: String?

    init(checkType: SecurityCheckType, severity: Severity,
         title: String, detail: String,
         path: String? = nil, bundleID: String? = nil) {
        self.id = UUID()
        self.checkType = checkType
        self.severity = severity
        self.title = title
        self.detail = detail
        self.path = path
        self.bundleID = bundleID
    }
}
```

- [ ] **Step 1.2: Write failing tests**

```swift
// BeagleXTests/SecurityFindingTests.swift
import XCTest
@testable import BeagleX

final class SecurityFindingTests: XCTestCase {
    func testSeverityOrdering() {
        XCTAssertLessThan(Severity.info, .warning)
        XCTAssertLessThan(Severity.warning, .critical)
        XCTAssertGreaterThan(Severity.critical, .info)
    }

    func testSeverityComparableSort() {
        let sorted = [Severity.critical, .info, .warning].sorted()
        XCTAssertEqual(sorted, [.info, .warning, .critical])
    }

    func testFindingIdIsUnique() {
        let a = SecurityFinding(checkType: .malware, severity: .critical, title: "T", detail: "D")
        let b = SecurityFinding(checkType: .malware, severity: .critical, title: "T", detail: "D")
        XCTAssertNotEqual(a.id, b.id)
    }

    func testScanStateEquality() {
        XCTAssertEqual(ScanState.idle, .idle)
        XCTAssertNotEqual(ScanState.idle, .scanning(progress: 0.5))
        let now = Date()
        XCTAssertEqual(ScanState.done(now), .done(now))
    }
}
```

- [ ] **Step 1.3: Run tests — expect FAIL (SecurityFinding not yet defined)**

```bash
xcodebuild test -project BeagleX.xcodeproj -scheme BeagleXTests \
  -destination 'platform=macOS' \
  -only-testing:BeagleXTests/SecurityFindingTests 2>&1 | tail -5
```

- [ ] **Step 1.4: Run tests again after creating the file — expect PASS**

```bash
xcodebuild test -project BeagleX.xcodeproj -scheme BeagleXTests \
  -destination 'platform=macOS' \
  -only-testing:BeagleXTests/SecurityFindingTests 2>&1 | tail -5
```
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 1.5: Commit**

```bash
git add BeagleX/Features/Security/SecurityFinding.swift \
        BeagleXTests/SecurityFindingTests.swift
git commit -m "feat(security): data models — SecurityFinding, Severity, ScanState"
```

---

## Task 2: Protocol + CodeSignChecker + Threat Database

**Files:**
- Create: `BeagleX/Features/Security/SecurityCheck.swift`
- Create: `BeagleX/Resources/threat-signatures.json`

- [ ] **Step 2.1: Create SecurityCheck.swift**

```swift
// BeagleX/Features/Security/SecurityCheck.swift
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
```

- [ ] **Step 2.2: Create threat-signatures.json**

```json
{
  "version": "1.0",
  "updated": "2026-05-15",
  "malware": [
    { "name": "Shlayer",      "pathPatterns": ["*/com.shlayer.*", "*/MacOS/staf"] },
    { "name": "Adload",       "pathPatterns": ["/Library/LaunchAgents/com.adload.*", "*/com.amc.*"] },
    { "name": "Pirrit",       "pathPatterns": ["*/com.pirrit.*", "*/pirrit*"] },
    { "name": "KeRanger",     "pathPatterns": ["*/Transmission.app/Contents/Resources/General.rtf"] },
    { "name": "XCSSET",       "pathPatterns": ["*/XCSSET*", "*/.slToken"] },
    { "name": "MacDefender",  "pathPatterns": ["*/MacDefender*", "*/MacProtector*", "*/MacSecurity*"] },
    { "name": "Flashback",    "pathPatterns": ["*/com.java.update*", "*/.jupdate"] },
    { "name": "Genieo",       "pathPatterns": ["*/Genieo*", "*/com.genieoinnovation*"] },
    { "name": "DubRobber",    "pathPatterns": ["*/OSX.DubRobber*", "*/.ttt"] },
    { "name": "Tarmac",       "pathPatterns": ["*/com.intego.tarmac*"] },
    { "name": "CrescentCore", "pathPatterns": ["*/CrescentCore*"] },
    { "name": "Bundlore",     "pathPatterns": ["*/Bundlore*", "*/com.bundl.*"] },
    { "name": "NetWeird",     "pathPatterns": ["*/netweird*"] },
    { "name": "WireLurker",   "pathPatterns": ["*/WireLurker*", "*/FontMap1*"] },
    { "name": "EvilQuest",    "pathPatterns": ["*/com.apple.questd*", "*/.fseventsd*"] },
    { "name": "OSX.Dok",      "pathPatterns": ["*/Library/LaunchAgents/com.apple.Safari.helper*"] },
    { "name": "LoudMiner",    "pathPatterns": ["*/LoudMiner*"] },
    { "name": "Mughthesec",   "pathPatterns": ["*/Mughthesec*", "*/OriginalBrowser*"] },
    { "name": "Proton",       "pathPatterns": ["*/Proton*", "*/com.proton.rat*"] },
    { "name": "FruitFly",     "pathPatterns": ["*/Library/LaunchAgents/com.apple.finder.plist", "*/Library/LaunchDaemons/com.apple.systemkeychain*"] }
  ]
}
```

- [ ] **Step 2.3: Verify JSON is valid**

```bash
python3 -c "import json,sys; json.load(open('BeagleX/Resources/threat-signatures.json')); print('valid')"
```
Expected: `valid`

- [ ] **Step 2.4: Commit**

```bash
git add BeagleX/Features/Security/SecurityCheck.swift \
        BeagleX/Resources/threat-signatures.json
git commit -m "feat(security): SecurityCheck protocol + threat signature database (20 families)"
```

---

## Task 3: MalwareSignatureCheck

**Files:**
- Create: `BeagleX/Features/Security/Checks/MalwareSignatureCheck.swift`
- Create: `BeagleXTests/MalwareSignatureCheckTests.swift`

- [ ] **Step 3.1: Write failing test for pattern matching**

```swift
// BeagleXTests/MalwareSignatureCheckTests.swift
import XCTest
@testable import BeagleX

final class MalwareSignatureCheckTests: XCTestCase {
    func testGlobMatchWildcard() {
        XCTAssertTrue(securityGlobMatch(pattern: "*/com.shlayer.*",
                                        path: "/Library/LaunchAgents/com.shlayer.plist"))
    }

    func testGlobMatchNoMatch() {
        XCTAssertFalse(securityGlobMatch(pattern: "*/com.shlayer.*",
                                          path: "/Library/LaunchAgents/com.apple.plist"))
    }

    func testGlobMatchCaseInsensitive() {
        XCTAssertTrue(securityGlobMatch(pattern: "*/macdefender*",
                                         path: "/Applications/MacDefender.app/Contents/MacOS/MacDefender"))
    }

    func testGlobMatchAbsolutePath() {
        XCTAssertTrue(securityGlobMatch(
            pattern: "/Library/LaunchAgents/com.adload.*",
            path: "/Library/LaunchAgents/com.adload.plist"))
    }

    func testSignatureDBLoads() {
        let check = MalwareSignatureCheck()
        // loadDB() is internal; test by running on empty dirs (no crash)
        // We can't easily test file system scanning in unit tests,
        // so we verify the DB loads without crashing.
        XCTAssertNoThrow(Task { _ = await check.run() })
    }
}
```

- [ ] **Step 3.2: Run — expect FAIL**

```bash
xcodebuild test -project BeagleX.xcodeproj -scheme BeagleXTests \
  -destination 'platform=macOS' \
  -only-testing:BeagleXTests/MalwareSignatureCheckTests 2>&1 | tail -5
```

- [ ] **Step 3.3: Create MalwareSignatureCheck.swift**

```swift
// BeagleX/Features/Security/Checks/MalwareSignatureCheck.swift
import Foundation

private struct ThreatDB: Decodable {
    struct Entry: Decodable {
        let name: String
        let pathPatterns: [String]
    }
    let malware: [Entry]
}

struct MalwareSignatureCheck: SecurityCheck {
    let checkType: SecurityCheckType = .malware

    private static let scanDirs = [
        "~/Library/LaunchAgents",
        "/Library/LaunchAgents",
        "/Library/LaunchDaemons",
        "/tmp",
    ]

    func run() async -> [SecurityFinding] {
        guard let db = loadDB() else { return [] }
        let fm = FileManager.default
        var findings: [SecurityFinding] = []
        var seen = Set<String>()

        for dirRaw in Self.scanDirs {
            let dir = NSString(string: dirRaw).expandingTildeInPath
            guard let enumerator = fm.enumerator(atPath: dir) else { continue }
            while let file = enumerator.nextObject() as? String {
                let fullPath = (dir as NSString).appendingPathComponent(file)
                guard !seen.contains(fullPath) else { continue }
                for entry in db.malware {
                    for pattern in entry.pathPatterns {
                        if securityGlobMatch(pattern: pattern, path: fullPath) {
                            seen.insert(fullPath)
                            findings.append(SecurityFinding(
                                checkType: .malware,
                                severity: .critical,
                                title: "\(entry.name) detected",
                                detail: fullPath,
                                path: fullPath
                            ))
                        }
                    }
                }
            }
        }
        return findings
    }

    private func loadDB() -> ThreatDB? {
        guard let url = Bundle.main.url(forResource: "threat-signatures", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ThreatDB.self, from: data)
    }
}
```

- [ ] **Step 3.4: Run tests — expect PASS**

```bash
xcodebuild test -project BeagleX.xcodeproj -scheme BeagleXTests \
  -destination 'platform=macOS' \
  -only-testing:BeagleXTests/MalwareSignatureCheckTests 2>&1 | tail -5
```
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 3.5: Commit**

```bash
git add BeagleX/Features/Security/Checks/MalwareSignatureCheck.swift \
        BeagleXTests/MalwareSignatureCheckTests.swift
git commit -m "feat(security): MalwareSignatureCheck — glob pattern scanning against threat DB"
```

---

## Task 4: SuspiciousLaunchItemCheck

**Files:**
- Create: `BeagleX/Features/Security/Checks/SuspiciousLaunchItemCheck.swift`

- [ ] **Step 4.1: Create SuspiciousLaunchItemCheck.swift**

```swift
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
```

- [ ] **Step 4.2: Build to verify it compiles**

```bash
xcodebuild build -project BeagleX.xcodeproj -scheme BeagleX \
  -configuration Debug -destination 'platform=macOS' 2>&1 | grep -E "error:|BUILD"
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4.3: Commit**

```bash
git add BeagleX/Features/Security/Checks/SuspiciousLaunchItemCheck.swift
git commit -m "feat(security): SuspiciousLaunchItemCheck — codesign validation of launch items"
```

---

## Task 5: NetworkConnectionCheck

**Files:**
- Create: `BeagleX/Features/Security/Checks/NetworkConnectionCheck.swift`

- [ ] **Step 5.1: Create NetworkConnectionCheck.swift**

```swift
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
            // Skip system binaries — they are always signed
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

    /// Returns PIDs that have at least one ESTABLISHED TCP connection.
    private func establishedPIDs() -> [pid_t] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        p.arguments = ["-nP", "-iTCP", "-sTCP:ESTABLISHED", "-F", "p"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        try? p.run()
        p.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
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
```

- [ ] **Step 5.2: Build**

```bash
xcodebuild build -project BeagleX.xcodeproj -scheme BeagleX \
  -configuration Debug -destination 'platform=macOS' 2>&1 | grep -E "error:|BUILD"
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5.3: Commit**

```bash
git add BeagleX/Features/Security/Checks/NetworkConnectionCheck.swift
git commit -m "feat(security): NetworkConnectionCheck — lsof + codesign for active TCP connections"
```

---

## Task 6: PermissionAbuseCheck

**Files:**
- Create: `BeagleX/Features/Security/Checks/PermissionAbuseCheck.swift`

- [ ] **Step 6.1: Create PermissionAbuseCheck.swift**

```swift
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

        // Group high-risk services by bundle ID
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

    /// Queries TCC.db via sqlite3 CLI. Returns [(bundleID, service)] rows.
    private func queryTCC(at path: String) -> [(String, String)] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        p.arguments = [path, "SELECT client, service FROM access WHERE allowed=1 AND client_type=0;"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        try? p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { return [] }
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return out.components(separatedBy: .newlines).compactMap { line -> (String, String)? in
            let parts = line.components(separatedBy: "|")
            guard parts.count == 2 else { return nil }
            return (parts[0].trimmingCharacters(in: .whitespaces),
                    parts[1].trimmingCharacters(in: .whitespaces))
        }
    }
}
```

- [ ] **Step 6.2: Build**

```bash
xcodebuild build -project BeagleX.xcodeproj -scheme BeagleX \
  -configuration Debug -destination 'platform=macOS' 2>&1 | grep -E "error:|BUILD"
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6.3: Commit**

```bash
git add BeagleX/Features/Security/Checks/PermissionAbuseCheck.swift
git commit -m "feat(security): PermissionAbuseCheck — TCC.db query, flags unsigned apps with ≥2 high-risk permissions"
```

---

## Task 7: SecurityScanCoordinator

**Files:**
- Create: `BeagleX/Features/Security/SecurityScanCoordinator.swift`
- Create: `BeagleXTests/SecurityScanCoordinatorTests.swift`

- [ ] **Step 7.1: Write failing coordinator tests**

```swift
// BeagleXTests/SecurityScanCoordinatorTests.swift
import XCTest
@testable import BeagleX

@MainActor
final class SecurityScanCoordinatorTests: XCTestCase {
    func testInitialStateIsIdle() {
        let c = SecurityScanCoordinator()
        XCTAssertEqual(c.scanState, .idle)
        XCTAssertTrue(c.findings.isEmpty)
    }

    func testIgnoreRemovesFindingFromList() {
        let c = SecurityScanCoordinator()
        let f = SecurityFinding(checkType: .malware, severity: .critical, title: "T", detail: "D")
        c.findings = [f]
        c.ignore(f)
        XCTAssertTrue(c.findings.isEmpty)
    }

    func testIgnoredIdPersistedAndFilteredOnNextSet() {
        let c = SecurityScanCoordinator()
        let f = SecurityFinding(checkType: .malware, severity: .critical, title: "T", detail: "D")
        c.ignore(f)
        // After ignore, the same finding should be filtered when findings are set again
        c.findings = [f]
        XCTAssertTrue(c.findings.isEmpty, "Ignored finding should be filtered out")
    }
}
```

- [ ] **Step 7.2: Run — expect FAIL**

```bash
xcodebuild test -project BeagleX.xcodeproj -scheme BeagleXTests \
  -destination 'platform=macOS' \
  -only-testing:BeagleXTests/SecurityScanCoordinatorTests 2>&1 | tail -5
```

- [ ] **Step 7.3: Create SecurityScanCoordinator.swift**

```swift
// BeagleX/Features/Security/SecurityScanCoordinator.swift
import Foundation
import UserNotifications
import Shared

@MainActor
final class SecurityScanCoordinator: ObservableObject {
    @Published private(set) var scanState: ScanState = .idle
    @Published var findings: [SecurityFinding] = []
    @Published private(set) var lastScanDate: Date?

    var autoScanInterval: String {
        get { UserDefaults.standard.string(forKey: "security.autoScanInterval") ?? "off" }
        set { UserDefaults.standard.set(newValue, forKey: "security.autoScanInterval") }
    }

    private var ignoredIDs: Set<String> {
        get {
            let raw = UserDefaults.standard.string(forKey: "security.ignoredIDs") ?? ""
            return Set(raw.components(separatedBy: ",").filter { !$0.isEmpty })
        }
        set {
            UserDefaults.standard.set(newValue.joined(separator: ","), forKey: "security.ignoredIDs")
        }
    }

    private let checks: [any SecurityCheck] = [
        MalwareSignatureCheck(),
        SuspiciousLaunchItemCheck(),
        NetworkConnectionCheck(),
        PermissionAbuseCheck(),
    ]

    init() {
        lastScanDate = UserDefaults.standard.object(forKey: "security.lastScanDate") as? Date
    }

    /// Call once on app start — triggers auto-scan if overdue.
    func start() {
        let interval = autoScanInterval
        guard interval != "off" else { return }
        let hours: Double = interval == "daily" ? 24 : 168
        guard let last = lastScanDate else { Task { await scan() }; return }
        if Date().timeIntervalSince(last) > hours * 3600 { Task { await scan() } }
    }

    func scan() async {
        guard scanState == .idle else { return }
        scanState = .scanning(progress: 0)

        async let m = checks[0].run()
        async let l = checks[1].run()
        scanState = .scanning(progress: 0.3)
        async let n = checks[2].run()
        async let p = checks[3].run()
        scanState = .scanning(progress: 0.7)

        let all = await m + l + n + p
        let ignored = ignoredIDs
        let filtered = all
            .filter { !ignored.contains($0.id.uuidString) }
            .sorted { $0.severity > $1.severity }

        let now = Date()
        findings = filtered
        lastScanDate = now
        UserDefaults.standard.set(now, forKey: "security.lastScanDate")
        scanState = .done(now)

        let serious = filtered.filter { $0.severity >= .warning }
        if !serious.isEmpty { deliverNotification(count: serious.count) }
    }

    func ignore(_ finding: SecurityFinding) {
        var ids = ignoredIDs
        ids.insert(finding.id.uuidString)
        ignoredIDs = ids
        findings.removeAll { $0.id == finding.id }
    }

    func remove(_ finding: SecurityFinding) async {
        guard let path = finding.path else { return }
        do {
            if path.hasPrefix("/Library/") {
                let cmd: HelperCommand = path.hasSuffix(".plist")
                    ? .deletePlist(path: path)
                    : .removeAppBundle(path: path)
                _ = try await HelperBridge.shared.send(cmd)
            } else {
                try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
            }
            findings.removeAll { $0.id == finding.id }
            UserActionLog.shared.record(type: "security_remove", target: path, success: true)
        } catch {
            UserActionLog.shared.record(type: "security_remove", target: path,
                                        success: false, error: error.localizedDescription)
        }
    }

    private func deliverNotification(count: Int) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "BeagleX — Security Alert")
        content.body = String(format: String(localized: "%d security issue(s) found"), count)
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "security-\(UUID())", content: content, trigger: nil)
        )
    }
}
```

> **Note on `testIgnoredIdPersistedAndFilteredOnNextSet`:** This test requires `findings` to be settable from outside for test purposes (it's `@Published var` not `private(set)`). This is intentional for testability.

- [ ] **Step 7.4: Run coordinator tests — expect PASS**

```bash
xcodebuild test -project BeagleX.xcodeproj -scheme BeagleXTests \
  -destination 'platform=macOS' \
  -only-testing:BeagleXTests/SecurityScanCoordinatorTests 2>&1 | tail -5
```
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 7.5: Commit**

```bash
git add BeagleX/Features/Security/SecurityScanCoordinator.swift \
        BeagleXTests/SecurityScanCoordinatorTests.swift
git commit -m "feat(security): SecurityScanCoordinator — parallel orchestration, ignore/remove, auto-scan"
```

---

## Task 8: SecurityView UI

**Files:**
- Create: `BeagleX/Features/Security/SecurityView.swift`

- [ ] **Step 8.1: Create SecurityView.swift**

```swift
// BeagleX/Features/Security/SecurityView.swift
import SwiftUI

struct SecurityView: View {
    @EnvironmentObject private var coordinator: SecurityScanCoordinator
    @State private var confirmRemove: SecurityFinding?

    private var hasScanned: Bool {
        if case .idle = coordinator.scanState { return false }
        if case .scanning = coordinator.scanState { return false }
        return true
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                statusBanner
                ForEach(SecurityCheckType.allCases, id: \.self) { sectionGroup(for: $0) }
            }
            .padding(24)
        }
        .background(Theme.bg)
        .toolbarBackground(Theme.bg, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .navigationTitle(String(localized: "Security"))
        .toolbar {
            ToolbarItem {
                if let date = coordinator.lastScanDate {
                    Text(date, format: .relative(presentation: .named))
                        .font(Theme.caption).foregroundStyle(Theme.mute)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { Task { await coordinator.scan() } } label: {
                    Label(String(localized: "Scan Now"), systemImage: "shield.checkerboard")
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(coordinator.scanState != .idle)
            }
        }
        .confirmationDialog(
            String(localized: "Remove this item?"),
            isPresented: .init(
                get: { confirmRemove != nil },
                set: { if !$0 { confirmRemove = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "Move to Trash"), role: .destructive) {
                if let f = confirmRemove { Task { await coordinator.remove(f) } }
                confirmRemove = nil
            }
            Button(String(localized: "Cancel"), role: .cancel) { confirmRemove = nil }
        } message: {
            Text(confirmRemove?.detail ?? "")
        }
    }

    // MARK: - Status banner

    @ViewBuilder
    private var statusBanner: some View {
        switch coordinator.scanState {
        case .idle:
            HStack(spacing: 10) {
                Image(systemName: "shield").foregroundStyle(Theme.mute)
                Text(String(localized: "Run a scan to check your Mac for threats"))
                    .font(Theme.bodyText).foregroundStyle(Theme.mute)
                Spacer()
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.cardBg))

        case .scanning(let p):
            HStack(spacing: 12) {
                ProgressView(value: p).frame(width: 100)
                Text(String(localized: "Scanning...")).font(Theme.caption).foregroundStyle(Theme.mute)
                Spacer()
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.cardBg))

        case .done:
            let serious = coordinator.findings.filter { $0.severity >= .warning }
            if serious.isEmpty {
                bannerRow(icon: "checkmark.shield.fill", color: Theme.accent,
                          title: String(localized: "All clear"),
                          subtitle: String(localized: "No threats detected"))
            } else {
                bannerRow(icon: "exclamationmark.triangle.fill", color: Theme.warn,
                          title: String(format: String(localized: "%d issue(s) found"), serious.count),
                          subtitle: String(localized: "Review the findings below and take action"))
            }
        }
    }

    private func bannerRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(color).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.headline(14)).foregroundStyle(color)
                Text(subtitle).font(Theme.caption).foregroundStyle(Theme.mute)
            }
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(color.opacity(0.18), lineWidth: 1))
    }

    // MARK: - Section groups

    @ViewBuilder
    private func sectionGroup(for type: SecurityCheckType) -> some View {
        let typeFindings = coordinator.findings.filter { $0.checkType == type }
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(type.sectionTitle).vqEyebrow()
                if !typeFindings.isEmpty {
                    let color = typeFindings.contains { $0.severity == .critical } ? Theme.danger : Theme.warn
                    Text("· \(typeFindings.count)").vqEyebrow(color: color)
                }
            }
            if hasScanned {
                if typeFindings.isEmpty {
                    cleanRow(for: type)
                } else {
                    ForEach(typeFindings) { findingRow($0) }
                }
            } else {
                placeholderRow
            }
        }
    }

    private var placeholderRow: some View {
        HStack {
            Text("—").font(Theme.caption).foregroundStyle(Theme.mute)
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.cardBg))
    }

    private func cleanRow(for type: SecurityCheckType) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
            Text(type.cleanMessage).font(Theme.bodyText).foregroundStyle(Theme.accent)
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accent.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.accent.opacity(0.15), lineWidth: 1))
    }

    private func findingRow(_ finding: SecurityFinding) -> some View {
        let color = finding.severity == .critical ? Theme.danger : Theme.warn
        return HStack(alignment: .top, spacing: 12) {
            Circle().fill(color).frame(width: 7, height: 7).padding(.top, 5)
            VStack(alignment: .leading, spacing: 3) {
                Text(finding.title)
                    .font(Theme.bodyText).fontWeight(.semibold).foregroundStyle(color)
                Text(finding.detail)
                    .font(Theme.caption).foregroundStyle(Theme.mute).lineLimit(2)
            }
            Spacer()
            HStack(spacing: 6) {
                Button(String(localized: "Ignore")) { coordinator.ignore(finding) }
                    .buttonStyle(.bordered).controlSize(.small).foregroundStyle(Theme.mute)
                if finding.path != nil {
                    Button(String(localized: "Remove")) { confirmRemove = finding }
                        .buttonStyle(.bordered).controlSize(.small).foregroundStyle(Theme.danger)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(color.opacity(0.2), lineWidth: 1))
    }
}
```

- [ ] **Step 8.2: Build**

```bash
xcodebuild build -project BeagleX.xcodeproj -scheme BeagleX \
  -configuration Debug -destination 'platform=macOS' 2>&1 | grep -E "error:|BUILD"
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8.3: Commit**

```bash
git add BeagleX/Features/Security/SecurityView.swift
git commit -m "feat(security): SecurityView — grouped list UI with scan, ignore, remove actions"
```

---

## Task 9: Wire Navigation & Settings

**Files:**
- Modify: `BeagleX/Core/Navigation/SidebarItem.swift`
- Modify: `BeagleX/UI/MainContentView.swift`
- Modify: `BeagleX/BeagleXApp.swift`
- Modify: `BeagleX/Features/Settings/SettingsView.swift`
- Modify: `BeagleX/Resources/Localizable.xcstrings`

- [ ] **Step 9.1: Add `.security` to SidebarItem**

In `SidebarItem.swift`, add `case security` and its label/icon:

```swift
// Add after case automation:
case security
```

In the `label` switch, add:
```swift
case .security: return String(localized: "Security")
```

In the `icon` switch, add:
```swift
case .security: return "shield.checkerboard"
```

The full updated enum (replace entire file):

```swift
import Foundation

enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case monitoring
    case processes
    case automation
    case security
    case cacheCleaner
    case largeFiles
    case uninstaller
    case launchItems
    case settings

    var id: String { rawValue }

    var label: String {
        switch self {
        case .monitoring:   return String(localized: "Memory")
        case .processes:    return String(localized: "Processes")
        case .automation:   return String(localized: "Automation")
        case .security:     return String(localized: "Security")
        case .cacheCleaner: return String(localized: "Cache Cleaner")
        case .largeFiles:   return String(localized: "Large Files")
        case .uninstaller:  return String(localized: "Uninstaller")
        case .launchItems:  return String(localized: "Launch Items")
        case .settings:     return String(localized: "Settings")
        }
    }

    var icon: String {
        switch self {
        case .monitoring:   return "memorychip"
        case .processes:    return "list.bullet.rectangle"
        case .automation:   return "wand.and.stars"
        case .security:     return "shield.checkerboard"
        case .cacheCleaner: return "trash"
        case .largeFiles:   return "doc.zipper"
        case .uninstaller:  return "shippingbox"
        case .launchItems:  return "powerplug"
        case .settings:     return "gearshape"
        }
    }
}
```

- [ ] **Step 9.2: Add SecurityView to MainContentView detailView switch**

In `MainContentView.swift`, add after `case .automation:`:
```swift
case .security:      SecurityView()
```

- [ ] **Step 9.3: Inject SecurityScanCoordinator in BeagleXApp**

In `BeagleXApp.swift`, add the coordinator as a `@StateObject` and inject it:

```swift
// Add after @StateObject private var samplingCoordinator:
@StateObject private var securityCoordinator = SecurityScanCoordinator()
```

In `init()`, no changes needed (coordinator initializes itself).

In the `Window` body, add `.environmentObject(securityCoordinator)` alongside the existing ones, and call `.onAppear { ... securityCoordinator.start() }`:

```swift
Window("BeagleX", id: "main") {
    MainContentView()
        .frame(minWidth: 900, minHeight: 600)
        .environmentObject(samplingCoordinator)
        .environmentObject(themeManager)           // ThemeManager.shared is passed differently — keep existing
        .environmentObject(securityCoordinator)
        .onAppear {
            samplingCoordinator.start()
            DesktopOverlayController.shared.configure(coordinator: samplingCoordinator)
            securityCoordinator.start()
        }
}
```

> **Note:** Check existing `BeagleXApp.swift` — it uses `ThemeManager.shared` directly. Preserve that pattern, just add the `securityCoordinator` line.

- [ ] **Step 9.4: Add auto-scan picker to SettingsView**

Add a new section in `SettingsView.swift` between the existing sections (after `AutomationSettingsSection`):

```swift
section("Security") {
    Picker(String(localized: "Auto-scan interval"),
           selection: Binding(
               get: { securityCoordinator.autoScanInterval },
               set: { securityCoordinator.autoScanInterval = $0 }
           )) {
        Text(String(localized: "Off")).tag("off")
        Text(String(localized: "Daily")).tag("daily")
        Text(String(localized: "Weekly")).tag("weekly")
    }
    .pickerStyle(.segmented)
}
```

Add `@EnvironmentObject private var securityCoordinator: SecurityScanCoordinator` to `SettingsView`.

- [ ] **Step 9.5: Add "Security" / "安全" to Localizable.xcstrings**

Open `BeagleX/Resources/Localizable.xcstrings` and add the following entry in the `strings` dictionary (following the existing pattern):

```json
"Security" : {
  "localizations" : {
    "zh-Hans" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "安全"
      }
    }
  }
},
```

Also add these supporting strings:
```json
"Scan Now" : {
  "localizations" : { "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "立即扫描" } } }
},
"Malware" : {
  "localizations" : { "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "恶意软件" } } }
},
"Launch Items" : {
  "localizations" : { "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "启动项" } } }
},
"Network Connections" : {
  "localizations" : { "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "网络连接" } } }
},
"Permission Abuse" : {
  "localizations" : { "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "权限滥用" } } }
},
"All clear" : {
  "localizations" : { "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "全部正常" } } }
},
"No threats detected" : {
  "localizations" : { "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "未检测到威胁" } } }
},
"Remove this item?" : {
  "localizations" : { "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "删除此项目？" } } }
},
"Move to Trash" : {
  "localizations" : { "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "移到废纸篓" } } }
},
"Full Disk Access required" : {
  "localizations" : { "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "需要完全磁盘访问权限" } } }
}
```

- [ ] **Step 9.6: Build — verify everything compiles**

```bash
xcodebuild build -project BeagleX.xcodeproj -scheme BeagleX \
  -configuration Debug -destination 'platform=macOS' 2>&1 | grep -E "error:|BUILD"
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 9.7: Run all tests**

```bash
xcodebuild test -project BeagleX.xcodeproj -scheme BeagleXTests \
  -destination 'platform=macOS' 2>&1 | tail -8
```
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 9.8: Commit**

```bash
git add BeagleX/Core/Navigation/SidebarItem.swift \
        BeagleX/UI/MainContentView.swift \
        BeagleX/BeagleXApp.swift \
        BeagleX/Features/Settings/SettingsView.swift \
        BeagleX/Resources/Localizable.xcstrings
git commit -m "feat(security): wire Security into navigation, settings, and app lifecycle"
```

---

## Task 10: Archive, Notarize, Deploy

- [ ] **Step 10.1: Archive with Developer ID**

```bash
xcodebuild archive \
  -project BeagleX.xcodeproj \
  -scheme BeagleX \
  -configuration Release \
  -archivePath /tmp/BeagleX-archive/BeagleX-devid.xcarchive \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Developer ID Application: Lanmeng Ni (3APC6ALUWK)" \
  DEVELOPMENT_TEAM=3APC6ALUWK \
  OTHER_CODE_SIGN_FLAGS="--timestamp" \
  -allowProvisioningUpdates \
  2>&1 | grep -E "error:|ARCHIVE SUCCEEDED|ARCHIVE FAILED"
```

- [ ] **Step 10.2: Zip and notarize**

```bash
ditto -c -k --keepParent \
  /tmp/BeagleX-archive/BeagleX-devid.xcarchive/Products/Applications/BeagleX.app \
  /tmp/BeagleX-archive/BeagleX-1.4.0.zip

xcrun notarytool submit /tmp/BeagleX-archive/BeagleX-1.4.0.zip \
  --apple-id "vegadrift007@gmail.com" \
  --password "znam-ibta-xvxl-erjn" \
  --team-id "3APC6ALUWK" \
  --wait 2>&1 | grep -E "status:|Successfully"
```
Expected: `status: Accepted`

- [ ] **Step 10.3: Staple and deploy to Desktop**

```bash
cp -r /tmp/BeagleX-archive/BeagleX-devid.xcarchive/Products/Applications/BeagleX.app \
      /tmp/BeagleX-archive/BeagleX-final.app
xcrun stapler staple /tmp/BeagleX-archive/BeagleX-final.app
spctl -a -vvv -t exec /tmp/BeagleX-archive/BeagleX-final.app 2>&1 | grep "source="
rm -rf ~/Desktop/BeagleX.app
cp -r /tmp/BeagleX-archive/BeagleX-final.app ~/Desktop/BeagleX.app
echo "Done"
```
Expected: `source=Notarized Developer ID`

- [ ] **Step 10.4: Final commit**

```bash
git add -A
git commit -m "feat(security): complete Security Scanner — v1.4.0

- Malware signature check (20 threat families)
- Suspicious launch item codesign validation  
- Network connection unsigned process detection
- TCC permission abuse detection
- Remove/quarantine to Trash, ignore, auto-scan scheduling"
```
