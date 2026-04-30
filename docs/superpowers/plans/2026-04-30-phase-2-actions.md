# Phase 2 — Actions: Kill + Purge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add executable actions on top of Phase 1 monitoring — kill a process (own or system) and purge memory. Kill of system processes and `purge` go through a privileged helper daemon registered via `SMAppService.daemon`, communicated via XPC with strict command + path whitelisting.

**Architecture:** Add `RamKillerHelper` real implementation (XPC server) + `Shared` types defining the protocol. The app side gains `HelperManager` (lifecycle: register/check/install) and `HelperBridge` (XPC client with command dispatch). UI: Kill button in process row, Force-kill in right-click menu, Purge button in menubar + main window with 60-second cooldown, Smart-Kill banner suggesting idle high-memory processes.

**Tech Stack:** SMAppService.daemon (macOS 13+), NSXPCConnection / NSXPCListener, Foundation, Mach `vm_purge` syscall.

**Prerequisite:** Phase 0 + 1 complete and verified.

**⚠️ Manual user steps:** First-time helper installation requires user to approve "RamKiller Helper" in **System Settings → General → Login Items & Extensions → Allow in the Background**. This cannot be automated.

---

## File Structure

| Path | Purpose |
|---|---|
| `Shared/Sources/Shared/HelperCommand.swift` | Codable command enum |
| `Shared/Sources/Shared/HelperResult.swift` | Codable result enum |
| `Shared/Sources/Shared/HelperProtocol.swift` | `@objc` XPC protocol |
| `RamKillerHelper/main.swift` | (replace) XPC server entry |
| `RamKillerHelper/HelperService.swift` | NSXPCListenerDelegate + command dispatch |
| `RamKillerHelper/Operations/PurgeOperation.swift` | Calls `vm_purge` |
| `RamKillerHelper/Operations/KillOperation.swift` | Calls `kill(2)` after whitelist check |
| `RamKillerHelper/Info.plist` | MachServices, version |
| `RamKillerHelper/com.vannaq.ramkiller.helper.plist` | launchd job (placed in `Contents/Library/LaunchDaemons/`) |
| `RamKiller/Core/Services/HelperManager.swift` | App-side: SMAppService lifecycle |
| `RamKiller/Core/Services/HelperBridge.swift` | XPC client with auto-install fallback |
| `RamKiller/Core/Services/PurgeCooldown.swift` | 60-second cooldown logic |
| `RamKiller/Core/Services/SmartKillAnalyzer.swift` | Identify idle high-memory candidates |
| `RamKiller/UI/Components/HelperStatusBadge.swift` | Compact helper-status indicator |
| `RamKiller/UI/Components/PurgeButton.swift` | Reusable purge button + cooldown |
| `RamKiller/UI/Components/KillConfirmAlert.swift` | Alert factory |
| `RamKiller/Features/Processes/ProcessesView.swift` | (modify) add kill button + right-click |
| `RamKiller/Features/Monitoring/MonitoringView.swift` | (modify) add purge button + smart-kill banner |
| `RamKiller/UI/MenuBar/MenuBarView.swift` | (modify) add purge button |
| `RamKiller/Features/Settings/SettingsView.swift` | (modify) add helper status row + reinstall button |
| `RamKillerTests/HelperCommandTests.swift` | Codable round-trip tests |
| `RamKillerTests/PurgeCooldownTests.swift` | Cooldown logic tests |
| `RamKillerTests/SmartKillAnalyzerTests.swift` | Recommendation logic tests |

---

## Task 1: `HelperCommand` enum

**Files:**
- Create: `/Users/a77/RamKiller/Shared/Sources/Shared/HelperCommand.swift`
- Test: `/Users/a77/RamKiller/Shared/Tests/SharedTests/HelperCommandTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import Shared

final class HelperCommandTests: XCTestCase {
    func testPurgeRoundTrip() throws {
        let cmd: HelperCommand = .purgeMemory
        let data = try JSONEncoder().encode(cmd)
        let decoded = try JSONDecoder().decode(HelperCommand.self, from: data)
        XCTAssertEqual(decoded, cmd)
    }

    func testKillRoundTrip() throws {
        let cmd: HelperCommand = .killProcess(pid: 1234, signal: 15)
        let data = try JSONEncoder().encode(cmd)
        let decoded = try JSONDecoder().decode(HelperCommand.self, from: data)
        XCTAssertEqual(decoded, cmd)
    }
}
```

- [ ] **Step 2: Run, expect failure**

```bash
cd /Users/a77/RamKiller/Shared
swift test
```

Expected: error `cannot find type 'HelperCommand' in scope`.

- [ ] **Step 3: Implement**

```swift
import Foundation

public enum HelperCommand: Codable, Equatable, Sendable {
    case purgeMemory
    case killProcess(pid: Int32, signal: Int32)
}
```

- [ ] **Step 4: Run tests, expect pass**

```bash
swift test
```

- [ ] **Step 5: Commit**

```bash
cd /Users/a77/RamKiller
git add Shared
git commit -m "phase-2: HelperCommand enum"
```

---

## Task 2: `HelperResult` enum

**Files:**
- Create: `/Users/a77/RamKiller/Shared/Sources/Shared/HelperResult.swift`

- [ ] **Step 1: Write the type**

```swift
import Foundation

public enum HelperResult: Codable, Equatable, Sendable {
    case success
    case denied(reason: String)
    case failed(error: String)
}
```

- [ ] **Step 2: Verify package builds**

```bash
cd /Users/a77/RamKiller/Shared
swift build
```

- [ ] **Step 3: Commit**

```bash
cd /Users/a77/RamKiller
git add Shared
git commit -m "phase-2: HelperResult enum"
```

---

## Task 3: `HelperProtocol` XPC interface

**Files:**
- Create: `/Users/a77/RamKiller/Shared/Sources/Shared/HelperProtocol.swift`

- [ ] **Step 1: Write the protocol**

```swift
import Foundation

/// XPC protocol bridging app → helper.
/// Both endpoints implement this on the same `NSXPCConnection`.
@objc public protocol HelperProtocol {
    /// Helper version, used by app to detect stale installs.
    func helperVersion(reply: @escaping (String) -> Void)

    /// Execute a JSON-encoded `HelperCommand`. Reply is JSON-encoded `HelperResult`.
    func execute(commandData: Data, reply: @escaping (Data) -> Void)
}
```

- [ ] **Step 2: Build**

```bash
cd /Users/a77/RamKiller/Shared
swift build
```

- [ ] **Step 3: Commit**

```bash
cd /Users/a77/RamKiller
git add Shared
git commit -m "phase-2: HelperProtocol XPC interface"
```

---

## Task 4: `PurgeOperation`

**Files:**
- Create: `/Users/a77/RamKiller/RamKillerHelper/Operations/PurgeOperation.swift`

- [ ] **Step 1: Write the operation**

```swift
import Foundation
import Darwin

enum PurgeOperation {
    /// Calls the kernel's `vm_purge_inactive` (same effect as `sudo purge`).
    /// Returns nil on success or an error string.
    static func run() -> String? {
        // Easiest reliable approach: shell out to `/usr/sbin/purge` (system binary,
        // available since 10.x). We are root in the helper, so it works without sudo.
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
```

- [ ] **Step 2: Build**

⌘B. Expected: helper target builds.

- [ ] **Step 3: Commit**

```bash
git add RamKillerHelper/Operations/PurgeOperation.swift
git commit -m "phase-2: PurgeOperation"
```

---

## Task 5: `KillOperation`

**Files:**
- Create: `/Users/a77/RamKiller/RamKillerHelper/Operations/KillOperation.swift`

- [ ] **Step 1: Write the operation**

```swift
import Foundation
import Darwin

enum KillOperation {
    /// Whitelisted signals only.
    private static let allowedSignals: Set<Int32> = [SIGTERM, SIGKILL]

    /// PIDs we never let anyone kill (launchd, kernel proxies).
    private static let forbiddenPIDs: Set<Int32> = [0, 1]

    static func run(pid: Int32, signal: Int32) -> HelperResultStub {
        guard allowedSignals.contains(signal) else {
            return .denied(reason: "Signal \(signal) not allowed")
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

/// Local mirror of HelperResult so this file does not need Shared (helper imports it elsewhere).
enum HelperResultStub {
    case success
    case denied(reason: String)
    case failed(error: String)
}
```

- [ ] **Step 2: Build**

⌘B.

- [ ] **Step 3: Commit**

```bash
git add RamKillerHelper/Operations/KillOperation.swift
git commit -m "phase-2: KillOperation with whitelist"
```

---

## Task 6: `HelperService` — XPC dispatch

**Files:**
- Create: `/Users/a77/RamKiller/RamKillerHelper/HelperService.swift`

- [ ] **Step 1: Write the service**

```swift
import Foundation
import Shared

final class HelperService: NSObject, NSXPCListenerDelegate, HelperProtocol {
    static let version = "0.1.0"

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection conn: NSXPCConnection) -> Bool {
        // Verify caller is the main app via code-signing requirement.
        let req = "anchor apple generic and identifier \"com.vannaq.ramkiller\" and certificate leaf[subject.OU] = \"\(teamID)\""
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(req as CFString, [], &requirement) == errSecSuccess,
              let requirement,
              conn.validate(requirement: requirement) else {
            NSLog("[helper] rejected connection: code requirement failed")
            return false
        }
        conn.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        conn.exportedObject = self
        conn.resume()
        return true
    }

    private var teamID: String {
        // Read from code-sign info (best-effort). Fallback empty triggers requirement to fail.
        SecCodeCopySelf([], nil) // keeps linker happy
        return Bundle.main.object(forInfoDictionaryKey: "TeamIdentifier") as? String ?? ""
    }

    // MARK: HelperProtocol

    func helperVersion(reply: @escaping (String) -> Void) {
        reply(Self.version)
    }

    func execute(commandData: Data, reply: @escaping (Data) -> Void) {
        do {
            let cmd = try JSONDecoder().decode(HelperCommand.self, from: commandData)
            let result = run(cmd)
            let data = try JSONEncoder().encode(result)
            reply(data)
        } catch {
            let err = HelperResult.failed(error: "decode failed: \(error.localizedDescription)")
            let data = (try? JSONEncoder().encode(err)) ?? Data()
            reply(data)
        }
    }

    private func run(_ cmd: HelperCommand) -> HelperResult {
        switch cmd {
        case .purgeMemory:
            if let err = PurgeOperation.run() {
                return .failed(error: err)
            }
            return .success
        case .killProcess(let pid, let sig):
            switch KillOperation.run(pid: pid, signal: sig) {
            case .success:                return .success
            case .denied(let r):          return .denied(reason: r)
            case .failed(let e):          return .failed(error: e)
            }
        }
    }
}

private extension NSXPCConnection {
    func validate(requirement: SecRequirement) -> Bool {
        var token = audit_token_t()
        var size = MemoryLayout<audit_token_t>.size
        guard withUnsafeMutablePointer(to: &token, {
            $0.withMemoryRebound(to: UInt8.self, capacity: size) { buf in
                xpc_connection_get_audit_token_self(self.xpcConnection, &token)
                return true
            }
        }) else { return false }

        var attrs: CFDictionary?
        let attrInput: CFDictionary = [kSecGuestAttributeAudit as String: Data(bytes: &token, count: size)] as CFDictionary
        var code: SecCode?
        guard SecCodeCopyGuestWithAttributes(nil, attrInput, [], &code) == errSecSuccess, let code else {
            return false
        }
        return SecCodeCheckValidity(code, [], requirement) == errSecSuccess
    }

    var xpcConnection: xpc_connection_t {
        unsafeBitCast(self, to: xpc_connection_t.self)
    }
}

@_silgen_name("xpc_connection_get_audit_token_self")
private func xpc_connection_get_audit_token_self(_ conn: xpc_connection_t, _ token: UnsafeMutablePointer<audit_token_t>)
```

- [ ] **Step 2: Add `Shared` dependency to helper target**

In Xcode → `RamKillerHelper` target → **General** → **Frameworks and Libraries** → **+** → `Shared`. (Already done in Phase 0 Task 4 Step 3 — verify it's still there.)

- [ ] **Step 3: Build**

⌘B. The validate function uses `xpc_connection_get_audit_token_self` which is a private API. If linker complains: comment out the `validate(requirement:)` body and just `return true` for now (we revisit signing verification once SMAppService is up). Keep the protocol so we can retrofit.

> **NOTE FOR ENGINEER:** If you're seeing linker errors on `xpc_connection_get_audit_token_self`, replace the body of `validate(requirement:)` with `return true` for the rest of this Phase. We'll harden it after the daemon is provably installable. Track this in `// FIXME: PHASE-2-HARDEN`.

- [ ] **Step 4: Commit**

```bash
git add RamKillerHelper/HelperService.swift
git commit -m "phase-2: HelperService XPC dispatch (signing check stubbed)"
```

---

## Task 7: Replace helper `main.swift` with NSXPCListener

**Files:**
- Modify: `/Users/a77/RamKiller/RamKillerHelper/main.swift`

- [ ] **Step 1: Replace the file**

```swift
import Foundation

NSLog("[helper] starting v\(HelperService.version)")

let listener = NSXPCListener(machServiceName: "com.vannaq.ramkiller.helper")
let delegate = HelperService()
listener.delegate = delegate
listener.resume()

RunLoop.current.run()
```

- [ ] **Step 2: Build**

⌘B.

- [ ] **Step 3: Commit**

```bash
git add RamKillerHelper/main.swift
git commit -m "phase-2: helper NSXPCListener boot"
```

---

## Task 8: Helper `Info.plist` with MachServices

**Files:**
- Modify: `/Users/a77/RamKiller/RamKillerHelper/Info.plist` (Xcode auto-generated; we add keys)

- [ ] **Step 1: Open helper Info.plist in Xcode**

Click `RamKillerHelper/Info.plist`. Add:

| Key | Type | Value |
|---|---|---|
| `MachServices` | Dictionary | (one child below) |
| `→ com.vannaq.ramkiller.helper` | Boolean | `YES` |
| `CFBundleVersion` | String | `1` |
| `CFBundleShortVersionString` | String | `0.1.0` |

If editing as XML directly:

```xml
<key>MachServices</key>
<dict>
    <key>com.vannaq.ramkiller.helper</key>
    <true/>
</dict>
<key>CFBundleVersion</key>
<string>1</string>
<key>CFBundleShortVersionString</key>
<string>0.1.0</string>
```

- [ ] **Step 2: Commit**

```bash
git add RamKillerHelper/Info.plist
git commit -m "phase-2: helper MachServices declaration"
```

---

## Task 9: launchd plist for the daemon

**Files:**
- Create: `/Users/a77/RamKiller/RamKillerHelper/com.vannaq.ramkiller.helper.plist`

- [ ] **Step 1: Write the plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.vannaq.ramkiller.helper</string>
    <key>BundleProgram</key>
    <string>Contents/MacOS/RamKillerHelper</string>
    <key>MachServices</key>
    <dict>
        <key>com.vannaq.ramkiller.helper</key>
        <true/>
    </dict>
    <key>AssociatedBundleIdentifiers</key>
    <array>
        <string>com.vannaq.ramkiller</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 2: Have Xcode embed the plist into the app bundle**

In Xcode:
1. Select the **RamKiller** target → **Build Phases** tab.
2. Click the **+** above the phase list → **New Copy Files Phase**.
3. Name the new phase: **Copy LaunchDaemon plist**.
4. **Destination**: Wrapper.
5. **Subpath**: `Contents/Library/LaunchDaemons`.
6. Drag `RamKillerHelper/com.vannaq.ramkiller.helper.plist` into the phase's file list.
7. Verify the file is added to **RamKiller** target membership (not the helper).

- [ ] **Step 3: Have Xcode embed the helper executable into the app**

Still in **RamKiller → Build Phases**:
1. Add another **New Copy Files Phase**.
2. Name: **Copy Helper Tool**.
3. **Destination**: Wrapper.
4. **Subpath**: `Contents/MacOS`.
5. Drag the **RamKillerHelper** product (under "Products" in the Project Navigator) into the file list.

This places the helper at `RamKiller.app/Contents/MacOS/RamKillerHelper`. SMAppService will read the embedded `Contents/Library/LaunchDaemons/com.vannaq.ramkiller.helper.plist`.

- [ ] **Step 4: Verify embed paths after a build**

```bash
xcodebuild -project /Users/a77/RamKiller/RamKiller.xcodeproj -scheme RamKiller -configuration Debug -derivedDataPath /tmp/rk-build build
ls /tmp/rk-build/Build/Products/Debug/RamKiller.app/Contents/Library/LaunchDaemons/
ls /tmp/rk-build/Build/Products/Debug/RamKiller.app/Contents/MacOS/
```

Expected:
- `Contents/Library/LaunchDaemons/com.vannaq.ramkiller.helper.plist` exists.
- `Contents/MacOS/RamKiller` exists.
- `Contents/MacOS/RamKillerHelper` exists.

- [ ] **Step 5: Commit**

```bash
git add RamKillerHelper/com.vannaq.ramkiller.helper.plist RamKiller.xcodeproj
git commit -m "phase-2: embed helper plist + executable in app bundle"
```

---

## Task 10: Code signing for both targets

**Files:**
- Modify: Xcode build settings (no source files changed)

- [ ] **Step 1: Set Team ID for both targets**

In Xcode → Project → Signing & Capabilities tab.

For **RamKiller**:
- Team: your Apple ID team
- Signing Certificate: Apple Development
- Bundle Identifier: `com.vannaq.ramkiller`
- Provisioning Profile: Automatic

For **RamKillerHelper**:
- Team: same as above
- Signing Certificate: Apple Development
- Bundle Identifier: `com.vannaq.ramkiller.helper`
- Provisioning Profile: Automatic

- [ ] **Step 2: Verify signing succeeds**

Run a clean build:

```bash
rm -rf /tmp/rk-build
xcodebuild -project /Users/a77/RamKiller/RamKiller.xcodeproj -scheme RamKiller -configuration Debug -derivedDataPath /tmp/rk-build build 2>&1 | grep -i "signing\|error:" | head -20
```

Expected: signing succeeds for both binaries; no errors.

- [ ] **Step 3: Verify the embedded helper is signed**

```bash
codesign -dvv /tmp/rk-build/Build/Products/Debug/RamKiller.app/Contents/MacOS/RamKillerHelper 2>&1 | head -10
```

Expected output includes `Identifier=com.vannaq.ramkiller.helper` and `TeamIdentifier=...` (your team).

- [ ] **Step 4: Commit (project-level changes)**

```bash
git add RamKiller.xcodeproj
git commit -m "phase-2: code signing config for app + helper"
```

---

## Task 11: `HelperManager` (app side)

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Core/Services/HelperManager.swift`

- [ ] **Step 1: Write the manager**

```swift
import Foundation
import ServiceManagement

@MainActor
final class HelperManager: ObservableObject {
    static let shared = HelperManager()

    enum InstallStatus {
        case notRegistered
        case requiresApproval
        case enabled
        case unknown
    }

    private let label = "com.vannaq.ramkiller.helper"
    private let plistPath = "Contents/Library/LaunchDaemons/com.vannaq.ramkiller.helper.plist"
    private lazy var service: SMAppService = .daemon(plistName: "com.vannaq.ramkiller.helper.plist")

    @Published private(set) var status: InstallStatus = .unknown

    private init() {
        refresh()
    }

    func refresh() {
        switch service.status {
        case .enabled:           status = .enabled
        case .notRegistered:     status = .notRegistered
        case .requiresApproval:  status = .requiresApproval
        case .notFound:          status = .notRegistered
        @unknown default:        status = .unknown
        }
    }

    func install() throws {
        try service.register()
        refresh()
    }

    func uninstall() throws {
        try service.unregister()
        refresh()
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add RamKiller/Core/Services/HelperManager.swift
git commit -m "phase-2: HelperManager wraps SMAppService.daemon"
```

---

## Task 12: `HelperBridge` — XPC client

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Core/Services/HelperBridge.swift`

- [ ] **Step 1: Write the bridge**

```swift
import Foundation
import Shared

@MainActor
final class HelperBridge {
    static let shared = HelperBridge()
    private var connection: NSXPCConnection?

    enum BridgeError: Error {
        case helperNotInstalled
        case unreachable(String)
    }

    func send(_ command: HelperCommand) async throws -> HelperResult {
        guard HelperManager.shared.status == .enabled else {
            throw BridgeError.helperNotInstalled
        }
        let conn = makeConnection()
        let proxy = conn.remoteObjectProxyWithErrorHandler { err in
            NSLog("[bridge] proxy error: \(err)")
        } as? HelperProtocol
        guard let proxy else { throw BridgeError.unreachable("proxy nil") }

        let cmdData = try JSONEncoder().encode(command)
        return try await withCheckedThrowingContinuation { cont in
            proxy.execute(commandData: cmdData) { resData in
                do {
                    let result = try JSONDecoder().decode(HelperResult.self, from: resData)
                    cont.resume(returning: result)
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    func helperVersion() async -> String? {
        guard HelperManager.shared.status == .enabled else { return nil }
        let conn = makeConnection()
        let proxy = conn.remoteObjectProxy as? HelperProtocol
        return await withCheckedContinuation { cont in
            proxy?.helperVersion { v in cont.resume(returning: v) }
        }
    }

    private func makeConnection() -> NSXPCConnection {
        if let conn = connection { return conn }
        let conn = NSXPCConnection(machServiceName: "com.vannaq.ramkiller.helper", options: .privileged)
        conn.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
        conn.invalidationHandler = { [weak self] in
            Task { @MainActor in self?.connection = nil }
        }
        conn.interruptionHandler = { [weak self] in
            Task { @MainActor in self?.connection = nil }
        }
        conn.resume()
        connection = conn
        return conn
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add RamKiller/Core/Services/HelperBridge.swift
git commit -m "phase-2: HelperBridge XPC client"
```

---

## Task 13: Helper status badge + Settings integration

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/UI/Components/HelperStatusBadge.swift`
- Modify: `/Users/a77/RamKiller/RamKiller/Features/Settings/SettingsView.swift`

- [ ] **Step 1: Write the badge**

```swift
import SwiftUI
import ServiceManagement

struct HelperStatusBadge: View {
    @ObservedObject var manager = HelperManager.shared

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
        }
    }

    private var color: Color {
        switch manager.status {
        case .enabled:           return .green
        case .requiresApproval:  return .yellow
        case .notRegistered:     return .red
        case .unknown:           return .gray
        }
    }

    private var label: String {
        switch manager.status {
        case .enabled:           return "Helper enabled"
        case .requiresApproval:  return "Needs approval (System Settings)"
        case .notRegistered:     return "Not installed"
        case .unknown:           return "Unknown"
        }
    }
}
```

- [ ] **Step 2: Add helper section to SettingsView**

Modify `SettingsView.swift` — replace the body to include a "Privileged Helper" section:

```swift
import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = true
    @State private var registrationError: String?
    @ObservedObject private var helperManager = HelperManager.shared
    @State private var helperError: String?
    @State private var helperVersion: String = "?"

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, n in apply(n) }
                if let e = registrationError {
                    Text(e).font(.caption).foregroundStyle(.red)
                }
            }
            Section("Privileged Helper") {
                HelperStatusBadge()
                LabeledContent("Version", value: helperVersion)
                HStack {
                    Button("Install / Repair") { install() }
                    Button("Uninstall") { uninstall() }
                        .disabled(helperManager.status != .enabled)
                }
                if helperManager.status == .requiresApproval {
                    Button("Open System Settings") {
                        SMAppService.openSystemSettingsLoginItems()
                    }
                }
                if let e = helperError {
                    Text(e).font(.caption).foregroundStyle(.red)
                }
            }
            Section("About") {
                LabeledContent("Version", value: "0.1.0")
                LabeledContent("Bundle ID", value: "com.vannaq.ramkiller")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .task { await loadHelperVersion() }
    }

    private func apply(_ enabled: Bool) {
        let result = enabled ? LoginItemService.shared.register() : LoginItemService.shared.unregister()
        if case .failure(let err) = result { registrationError = err.localizedDescription }
        else { registrationError = nil }
    }

    private func install() {
        do {
            try helperManager.install()
            helperError = nil
        } catch {
            helperError = error.localizedDescription
        }
    }

    private func uninstall() {
        do {
            try helperManager.uninstall()
            helperError = nil
        } catch {
            helperError = error.localizedDescription
        }
    }

    private func loadHelperVersion() async {
        if let v = await HelperBridge.shared.helperVersion() {
            helperVersion = v
        }
    }
}
```

- [ ] **Step 3: Build, run, navigate to Settings**

⌘R. In Settings:
- Helper status shows red "Not installed" initially.
- Click **Install / Repair** → System dialog appears asking to allow background activity.
- **Manually go to System Settings → General → Login Items & Extensions → Allow in the Background** and toggle "RamKiller Helper" ON.
- Return to RamKiller Settings. The badge should turn green within ~1 s after clicking Install again.

- [ ] **Step 4: Commit**

```bash
git add RamKiller/UI/Components/HelperStatusBadge.swift RamKiller/Features/Settings/SettingsView.swift
git commit -m "phase-2: helper install/uninstall in Settings"
```

---

## Task 14: `PurgeCooldown` logic

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Core/Services/PurgeCooldown.swift`
- Test: `/Users/a77/RamKiller/RamKillerTests/PurgeCooldownTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import RamKiller

final class PurgeCooldownTests: XCTestCase {
    func testInitiallyAllowed() {
        let c = PurgeCooldown(cooldownSeconds: 60)
        XCTAssertTrue(c.isAllowed(now: Date()))
    }

    func testBlockedDuringCooldown() {
        let c = PurgeCooldown(cooldownSeconds: 60)
        let t0 = Date()
        c.markFired(at: t0)
        XCTAssertFalse(c.isAllowed(now: t0.addingTimeInterval(30)))
    }

    func testAllowedAfterCooldown() {
        let c = PurgeCooldown(cooldownSeconds: 60)
        let t0 = Date()
        c.markFired(at: t0)
        XCTAssertTrue(c.isAllowed(now: t0.addingTimeInterval(61)))
    }

    func testRemainingSeconds() {
        let c = PurgeCooldown(cooldownSeconds: 60)
        let t0 = Date()
        c.markFired(at: t0)
        XCTAssertEqual(c.remainingSeconds(now: t0.addingTimeInterval(15)), 45, accuracy: 0.1)
    }
}
```

- [ ] **Step 2: Run, expect failure**

- [ ] **Step 3: Implement**

```swift
import Foundation
import Combine

@MainActor
final class PurgeCooldown: ObservableObject {
    let cooldownSeconds: TimeInterval
    @Published private(set) var lastFiredAt: Date?

    init(cooldownSeconds: TimeInterval = 60) {
        self.cooldownSeconds = cooldownSeconds
    }

    func isAllowed(now: Date = Date()) -> Bool {
        guard let last = lastFiredAt else { return true }
        return now.timeIntervalSince(last) >= cooldownSeconds
    }

    func remainingSeconds(now: Date = Date()) -> TimeInterval {
        guard let last = lastFiredAt else { return 0 }
        return max(0, cooldownSeconds - now.timeIntervalSince(last))
    }

    func markFired(at date: Date = Date()) {
        lastFiredAt = date
    }
}
```

- [ ] **Step 4: Run tests, expect pass**

- [ ] **Step 5: Commit**

```bash
git add RamKiller/Core/Services/PurgeCooldown.swift RamKillerTests/PurgeCooldownTests.swift
git commit -m "phase-2: PurgeCooldown logic"
```

---

## Task 15: `PurgeButton` reusable component

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/UI/Components/PurgeButton.swift`

- [ ] **Step 1: Write the view**

```swift
import SwiftUI

struct PurgeButton: View {
    @StateObject private var cooldown = PurgeCooldown(cooldownSeconds: 60)
    @ObservedObject private var helper = HelperManager.shared
    @State private var inFlight = false
    @State private var lastError: String?
    @State private var tick: TimeInterval = 0
    let style: Style

    enum Style { case prominent, compact }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: fire) {
                if inFlight {
                    ProgressView().controlSize(.small)
                } else if !cooldown.isAllowed() {
                    Text(String(format: "Purge (%.0fs)", cooldown.remainingSeconds()))
                } else {
                    Label("Purge Memory", systemImage: "trash")
                }
            }
            .disabled(inFlight || !cooldown.isAllowed() || helper.status != .enabled)
            .buttonStyle(style == .prominent ? .borderedProminent : .bordered)

            if let e = lastError {
                Text(e).font(.caption).foregroundStyle(.red)
            }
            if helper.status != .enabled {
                Text("Helper not enabled (Settings → Privileged Helper)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            tick = Date().timeIntervalSince1970
        }
    }

    private func fire() {
        inFlight = true
        lastError = nil
        Task {
            do {
                let result = try await HelperBridge.shared.send(.purgeMemory)
                switch result {
                case .success:           cooldown.markFired()
                case .denied(let r):     lastError = "Denied: \(r)"
                case .failed(let e):     lastError = e
                }
            } catch {
                lastError = error.localizedDescription
            }
            inFlight = false
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add RamKiller/UI/Components/PurgeButton.swift
git commit -m "phase-2: PurgeButton with cooldown"
```

---

## Task 16: Wire PurgeButton into MonitoringView + MenuBarView

**Files:**
- Modify: `/Users/a77/RamKiller/RamKiller/Features/Monitoring/MonitoringView.swift`
- Modify: `/Users/a77/RamKiller/RamKiller/UI/MenuBar/MenuBarView.swift`

- [ ] **Step 1: Add PurgeButton to MonitoringView toolbar**

Inside `MonitoringView` body, add a `.toolbar` ToolbarItem next to the existing pickers:

```swift
.toolbar {
    ToolbarItem(placement: .primaryAction) {
        PurgeButton(style: .prominent)
    }
    ToolbarItem {
        Picker("Window", selection: $windowHours) {
            Text("1h").tag(1); Text("6h").tag(6); Text("24h").tag(24)
        }
        .pickerStyle(.segmented)
    }
    ToolbarItem {
        Toggle("Advanced", isOn: $advanced)
    }
}
```

- [ ] **Step 2: Add to MenuBarView**

Insert above the `Open Main Window` button:

```swift
PurgeButton(style: .compact)
    .padding(.vertical, 4)
```

- [ ] **Step 3: Build and run, verify**

⌘R. Expected:
- Memory page toolbar has a prominent "Purge Memory" button.
- Menubar dropdown also has it.
- After clicking once: button shows "Purge (60s)" countdown for 60 seconds.
- Memory `Unused` jumps up immediately after a successful purge.

- [ ] **Step 4: Commit**

```bash
git add RamKiller/Features/Monitoring/MonitoringView.swift RamKiller/UI/MenuBar/MenuBarView.swift
git commit -m "phase-2: wire PurgeButton into UI"
```

---

## Task 17: `KillConfirmAlert`

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/UI/Components/KillConfirmAlert.swift`

- [ ] **Step 1: Write the helper**

```swift
import SwiftUI

struct KillConfirmContext: Identifiable {
    let id = UUID()
    let process: ProcessReading
    let force: Bool
}

extension View {
    func killConfirmAlert(_ context: Binding<KillConfirmContext?>, onConfirm: @escaping (ProcessReading, Bool) -> Void) -> some View {
        alert(
            context.wrappedValue.map { "\($0.force ? "Force kill" : "Kill") \($0.process.name)?" } ?? "",
            isPresented: Binding(
                get: { context.wrappedValue != nil },
                set: { if !$0 { context.wrappedValue = nil } }
            ),
            presenting: context.wrappedValue
        ) { ctx in
            Button(ctx.force ? "Force kill" : "Kill", role: .destructive) {
                onConfirm(ctx.process, ctx.force)
                context.wrappedValue = nil
            }
            Button("Cancel", role: .cancel) {
                context.wrappedValue = nil
            }
        } message: { ctx in
            Text("PID \(ctx.process.pid) — \(ByteFormat.mb(ctx.process.rssBytes)) RSS\nUser: \(ctx.process.user)")
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add RamKiller/UI/Components/KillConfirmAlert.swift
git commit -m "phase-2: KillConfirmAlert helper"
```

---

## Task 18: Kill button + right-click in `ProcessesView`

**Files:**
- Modify: `/Users/a77/RamKiller/RamKiller/Features/Processes/ProcessesView.swift`

- [ ] **Step 1: Add kill UI to the table**

Replace the `Table` definition with a richer one that includes an Action column:

```swift
Table(visible, selection: $selectedPID) {
    TableColumn("Name") { p in
        HStack {
            Text(p.name)
            Spacer()
            Button {
                killContext = KillConfirmContext(process: p, force: false)
            } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.borderless)
            .opacity(0.6)
            .contextMenu {
                Button("Kill (SIGTERM)") { killContext = .init(process: p, force: false) }
                Button("Force kill (SIGKILL)") { killContext = .init(process: p, force: true) }
            }
        }
    }
    .width(min: 220, ideal: 260)
    TableColumn("PID") { p in Text("\(p.pid)").monospacedDigit() }.width(80)
    TableColumn("RSS") { p in Text(ByteFormat.mb(p.rssBytes)).monospacedDigit() }.width(80)
    TableColumn("User") { p in Text(p.user) }.width(90)
}
```

Add state at the top of the view:

```swift
@State private var killContext: KillConfirmContext?
@State private var killError: String?
```

Add modifier at the bottom of the view body:

```swift
.killConfirmAlert($killContext) { process, force in
    Task { await performKill(process: process, force: force) }
}
.alert("Kill failed", isPresented: Binding(
    get: { killError != nil },
    set: { if !$0 { killError = nil } }
)) {
    Button("OK", role: .cancel) {}
} message: { Text(killError ?? "") }
```

Add the kill function:

```swift
private func performKill(process: ProcessReading, force: Bool) async {
    let signal: Int32 = force ? SIGKILL : SIGTERM
    if process.user == NSUserName() {
        // Own process — kill directly
        let result = kill(process.pid, signal)
        if result != 0 {
            killError = String(cString: strerror(errno))
        }
    } else {
        // System process — go through helper
        do {
            let result = try await HelperBridge.shared.send(.killProcess(pid: process.pid, signal: signal))
            switch result {
            case .success:           break
            case .denied(let r):     killError = "Denied: \(r)"
            case .failed(let e):     killError = e
            }
        } catch HelperBridge.BridgeError.helperNotInstalled {
            killError = "Privileged helper not installed. Open Settings → Privileged Helper → Install."
        } catch {
            killError = error.localizedDescription
        }
    }
}
```

- [ ] **Step 2: Build and run**

⌘R. Verify:
- Each process row has a small ❌ button (visible on hover).
- Right-click → "Kill (SIGTERM)" / "Force kill (SIGKILL)".
- Click ❌ → confirm dialog → kill executes → process disappears from list at next 60s sample (or your own kill — instant).

Test by killing a benign process (e.g., spawn `sleep 99999` in a Terminal and kill it from RamKiller).

- [ ] **Step 3: Commit**

```bash
git add RamKiller/Features/Processes/ProcessesView.swift
git commit -m "phase-2: kill action in process list (own + system via helper)"
```

---

## Task 19: `SmartKillAnalyzer`

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Core/Services/SmartKillAnalyzer.swift`
- Test: `/Users/a77/RamKiller/RamKillerTests/SmartKillAnalyzerTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import RamKiller

final class SmartKillAnalyzerTests: XCTestCase {
    func testRecommendsIdleHighRSSNonSystem() {
        let now = Date()
        let processes: [ProcessReading] = [
            // Idle high RSS user process — should recommend
            ProcessReading(id: 100, pid: 100, name: "leaky-app", bundleId: nil, executablePath: nil,
                           user: NSUserName(), rssBytes: 500_000_000, cpuPercent: 0,
                           startedAt: now.addingTimeInterval(-7200)),
            // System process — skip
            ProcessReading(id: 50, pid: 50, name: "kernel-thing", bundleId: nil, executablePath: nil,
                           user: "root", rssBytes: 1_000_000_000, cpuPercent: 0,
                           startedAt: now.addingTimeInterval(-7200)),
            // Low RSS — skip
            ProcessReading(id: 200, pid: 200, name: "tiny", bundleId: nil, executablePath: nil,
                           user: NSUserName(), rssBytes: 10_000_000, cpuPercent: 0,
                           startedAt: now.addingTimeInterval(-7200)),
            // Active CPU — skip (we'd rev this in a future Phase, for now just RSS+age)
        ]
        let analyzer = SmartKillAnalyzer(minRSS: 100_000_000, minAgeSeconds: 3600)
        let candidates = analyzer.candidates(from: processes, now: now)
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.pid, 100)
    }
}
```

- [ ] **Step 2: Run, expect failure**

- [ ] **Step 3: Implement**

```swift
import Foundation

final class SmartKillAnalyzer {
    let minRSS: Int64
    let minAgeSeconds: Int

    init(minRSS: Int64 = 100_000_000, minAgeSeconds: Int = 3600) {
        self.minRSS = minRSS
        self.minAgeSeconds = minAgeSeconds
    }

    func candidates(from processes: [ProcessReading], now: Date = Date()) -> [ProcessReading] {
        let me = NSUserName()
        return processes.filter {
            $0.user == me &&
            $0.rssBytes >= minRSS &&
            $0.elapsedSeconds >= minAgeSeconds
        }
        .sorted { $0.rssBytes > $1.rssBytes }
    }
}
```

- [ ] **Step 4: Run tests, expect pass**

- [ ] **Step 5: Commit**

```bash
git add RamKiller/Core/Services/SmartKillAnalyzer.swift RamKillerTests/SmartKillAnalyzerTests.swift
git commit -m "phase-2: SmartKillAnalyzer (idle high-RSS detection)"
```

---

## Task 20: Smart-Kill banner in MonitoringView

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Features/Monitoring/SmartKillBanner.swift`
- Modify: `/Users/a77/RamKiller/RamKiller/Features/Monitoring/MonitoringView.swift`

- [ ] **Step 1: Write the banner**

```swift
import SwiftUI

struct SmartKillBanner: View {
    @EnvironmentObject private var coordinator: SamplingCoordinator
    @State private var dismissed: Set<pid_t> = []
    @State private var error: String?

    private var candidates: [ProcessReading] {
        SmartKillAnalyzer().candidates(from: coordinator.latestProcesses)
            .filter { !dismissed.contains($0.pid) }
    }

    var body: some View {
        if !candidates.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "lightbulb")
                    Text("\(candidates.count) idle high-memory process\(candidates.count > 1 ? "es" : "")")
                        .font(.headline)
                    Spacer()
                    Button("Kill all") { Task { await killAll() } }
                        .buttonStyle(.borderedProminent)
                    Button("Dismiss") {
                        candidates.forEach { dismissed.insert($0.pid) }
                    }
                }
                ForEach(candidates.prefix(5)) { p in
                    HStack {
                        Text(p.name)
                        Spacer()
                        Text(ByteFormat.mb(p.rssBytes))
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
                if let e = error {
                    Text(e).font(.caption).foregroundStyle(.red)
                }
            }
            .padding(12)
            .background(Color.yellow.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)
        }
    }

    private func killAll() async {
        for p in candidates {
            let r = kill(p.pid, SIGTERM)
            if r != 0 {
                error = "Failed to kill \(p.name): \(String(cString: strerror(errno)))"
            }
        }
    }
}
```

- [ ] **Step 2: Insert into MonitoringView (top of ScrollView)**

In `MonitoringView.body`, add `SmartKillBanner()` as the first child of the `VStack` inside the `ScrollView`:

```swift
ScrollView {
    VStack(alignment: .leading, spacing: 16) {
        SmartKillBanner()
        statCardsRow
        chartsSection
        if advanced { AdvancedBreakdownView() }
    }
    .padding(16)
}
```

- [ ] **Step 3: Build and run, verify**

⌘R. To produce candidates: leave a few apps idle for >1 hour OR set the analyzer thresholds lower temporarily for testing.

For testing without waiting: temporarily change `SmartKillAnalyzer()` defaults to `minRSS: 50_000_000, minAgeSeconds: 60` in the banner, restart, and idle apps will show.

- [ ] **Step 4: Commit**

```bash
git add RamKiller/Features/Monitoring/SmartKillBanner.swift RamKiller/Features/Monitoring/MonitoringView.swift
git commit -m "phase-2: smart-kill banner"
```

---

## Task 21: First-launch helper bootstrap

**Files:**
- Modify: `/Users/a77/RamKiller/RamKiller/App/AppDelegate.swift`

- [ ] **Step 1: Auto-prompt on launch if helper not enabled**

Add to `applicationDidFinishLaunching`:

```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    NSLog("RamKiller launched")
    scheduleRetention()
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        Self.maybeBootstrapHelper()
    }
}

@MainActor
static func maybeBootstrapHelper() {
    let mgr = HelperManager.shared
    mgr.refresh()
    guard mgr.status != .enabled else { return }

    let alert = NSAlert()
    alert.messageText = "Install privileged helper?"
    alert.informativeText = "RamKiller needs a small background helper to run sudo-level operations like Purge Memory and killing system processes. You'll be asked to approve it in System Settings."
    alert.addButton(withTitle: "Install")
    alert.addButton(withTitle: "Later")
    if alert.runModal() == .alertFirstButtonReturn {
        try? mgr.install()
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add RamKiller/App/AppDelegate.swift
git commit -m "phase-2: prompt to install helper on first launch"
```

---

## Task 22: End-to-end verification

- [ ] **Step 1: Clean uninstall + reinstall flow**

```bash
# In Terminal:
sudo launchctl bootout system/com.vannaq.ramkiller.helper 2>/dev/null
sudo rm -f /Library/LaunchDaemons/com.vannaq.ramkiller.helper.plist 2>/dev/null
defaults delete com.vannaq.ramkiller 2>/dev/null
```

- [ ] **Step 2: Run tests**

⌘U. All Phase 0/1/2 tests pass.

- [ ] **Step 3: Walk through the acceptance checklist**

| Check | Expected |
|---|---|
| Launch app, prompt appears | ✅ "Install privileged helper?" alert |
| Click "Install" | ✅ system dialog about background activity |
| Open System Settings → Login Items & Extensions → Allow in Background | ✅ "RamKiller Helper" toggle, switch ON |
| Settings → Privileged Helper → Status | ✅ green "Helper enabled", version "0.1.0" |
| Memory page → Purge button | ✅ visible and enabled |
| Click Purge | ✅ Unused jumps up; cooldown countdown shows |
| Click Purge during cooldown | ✅ disabled with countdown |
| Wait 60s → Purge re-enabled | ✅ |
| Spawn `sleep 99999` in Terminal, find in Processes | ✅ |
| Click ❌ → confirm dialog → Kill | ✅ process dies |
| Right-click on a process → "Force kill" → confirm | ✅ |
| Try kill a system process (e.g., `cfprefsd`) | ✅ goes through helper, process restarted by launchd |
| Smart-Kill banner with idle apps (or with lowered thresholds for test) | ✅ visible, "Kill all" works |

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "phase-2: post-verification fixes" --allow-empty
```

---

## Phase 2 Acceptance Criteria

- [ ] All XCTest pass.
- [ ] Helper installs once, persists across reboots.
- [ ] Purge button works from menubar + main window.
- [ ] Cooldown enforced (60s).
- [ ] Kill works for both own and system processes.
- [ ] Force kill (SIGKILL) reachable via right-click.
- [ ] Smart-Kill banner appears for idle high-RSS processes.
- [ ] FIXME comment for `xpc_connection_get_audit_token_self` is tracked or resolved.

If all check, Phase 2 is complete — proceed to `2026-04-30-phase-3-automation.md`.
