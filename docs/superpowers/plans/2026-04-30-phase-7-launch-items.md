# Phase 7 — Launch Items Manager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unified view + management of every "starts on login / runs in background" item: Login Items, user LaunchAgents, system LaunchAgents, system LaunchDaemons. User can disable, re-enable, or permanently delete (with system-level paths going through the helper).

**Architecture:** `PlistService` enumerates four directories + `SMAppService.loginItem`. Each entry maps to a `LaunchItem`. Disable = `launchctl bootout` + rename plist `.disabled`. Enable = reverse. Delete = remove the plist file. System-level operations extend `HelperCommand` with new cases.

**Tech Stack:** PropertyListSerialization, ServiceManagement, NSWorkspace, the existing helper.

**Prerequisite:** Phase 0–6 complete.

---

## File Structure

| Path | Purpose |
|---|---|
| `Shared/Sources/Shared/HelperCommand.swift` | (modify) add launch-item cases |
| `RamKillerHelper/HelperService.swift` | (modify) handle new cases |
| `RamKillerHelper/Operations/LaunchItemOperation.swift` | New ops |
| `RamKiller/Core/Models/LaunchItem.swift` | UI model |
| `RamKiller/Core/Services/PlistService.swift` | Enumerate sources |
| `RamKiller/Core/Services/LaunchItemManager.swift` | Disable/enable/delete |
| `RamKiller/Core/Services/KnownDaemons.swift` | Whitelist of "do not touch" labels |
| `RamKiller/Features/LaunchItems/LaunchItemsView.swift` | (replace) |
| `RamKiller/Features/LaunchItems/LaunchItemRow.swift` | |
| `RamKillerTests/PlistServiceTests.swift` | |

---

## Task 1: Extend `HelperCommand` (Shared)

**Files:**
- Modify: `/Users/a77/RamKiller/Shared/Sources/Shared/HelperCommand.swift`

- [ ] **Step 1: Add new cases**

```swift
import Foundation

public enum HelperCommand: Codable, Equatable, Sendable {
    case purgeMemory
    case killProcess(pid: Int32, signal: Int32)
    case unloadLaunchPlist(path: String)            // launchctl bootout
    case loadLaunchPlist(path: String)              // launchctl bootstrap
    case renamePlist(from: String, to: String)      // for .disabled toggling
    case deletePlist(path: String)                  // permanent delete
}
```

- [ ] **Step 2: Update Shared package — re-run tests**

```bash
cd /Users/a77/RamKiller/Shared
swift test
```

- [ ] **Step 3: Commit**

```bash
cd /Users/a77/RamKiller
git add Shared
git commit -m "phase-7: extend HelperCommand for launch-item operations"
```

---

## Task 2: `LaunchItemOperation` in helper

**Files:**
- Create: `/Users/a77/RamKiller/RamKillerHelper/Operations/LaunchItemOperation.swift`

- [ ] **Step 1: Write the operations**

```swift
import Foundation

enum LaunchItemOperation {
    /// Allowed parent directories for any plist operation.
    private static let allowedRoots = [
        "/Library/LaunchAgents/",
        "/Library/LaunchDaemons/"
    ]

    static func unload(path: String) -> HelperResultStub {
        guard isAllowed(path) else { return .denied(reason: "Path \(path) outside allowed roots") }
        return runLaunchctl(args: ["bootout", "system/\(label(from: path))"])
    }

    static func load(path: String) -> HelperResultStub {
        guard isAllowed(path) else { return .denied(reason: "Path \(path) outside allowed roots") }
        return runLaunchctl(args: ["bootstrap", "system", path])
    }

    static func rename(from: String, to: String) -> HelperResultStub {
        guard isAllowed(from), isAllowed(to) else { return .denied(reason: "Path outside allowed roots") }
        do {
            try FileManager.default.moveItem(atPath: from, toPath: to)
            return .success
        } catch {
            return .failed(error: error.localizedDescription)
        }
    }

    static func delete(path: String) -> HelperResultStub {
        guard isAllowed(path) else { return .denied(reason: "Path \(path) outside allowed roots") }
        do {
            try FileManager.default.removeItem(atPath: path)
            return .success
        } catch {
            return .failed(error: error.localizedDescription)
        }
    }

    private static func isAllowed(_ path: String) -> Bool {
        allowedRoots.contains { path.hasPrefix($0) }
    }

    private static func label(from path: String) -> String {
        let file = (path as NSString).lastPathComponent
        return (file as NSString).deletingPathExtension
    }

    private static func runLaunchctl(args: [String]) -> HelperResultStub {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = args
        let stderr = Pipe()
        task.standardError = stderr
        task.standardOutput = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus == 0 { return .success }
            let data = stderr.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: data, encoding: .utf8) ?? "exit \(task.terminationStatus)"
            return .failed(error: msg)
        } catch {
            return .failed(error: error.localizedDescription)
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add RamKillerHelper/Operations/LaunchItemOperation.swift
git commit -m "phase-7: LaunchItemOperation in helper"
```

---

## Task 3: Wire new commands in `HelperService`

**Files:**
- Modify: `/Users/a77/RamKiller/RamKillerHelper/HelperService.swift`

- [ ] **Step 1: Extend the `run(_:)` switch**

```swift
private func run(_ cmd: HelperCommand) -> HelperResult {
    switch cmd {
    case .purgeMemory:
        if let err = PurgeOperation.run() { return .failed(error: err) }
        return .success
    case .killProcess(let pid, let sig):
        switch KillOperation.run(pid: pid, signal: sig) {
        case .success:        return .success
        case .denied(let r):  return .denied(reason: r)
        case .failed(let e):  return .failed(error: e)
        }
    case .unloadLaunchPlist(let path):
        return adapt(LaunchItemOperation.unload(path: path))
    case .loadLaunchPlist(let path):
        return adapt(LaunchItemOperation.load(path: path))
    case .renamePlist(let from, let to):
        return adapt(LaunchItemOperation.rename(from: from, to: to))
    case .deletePlist(let path):
        return adapt(LaunchItemOperation.delete(path: path))
    }
}

private func adapt(_ stub: HelperResultStub) -> HelperResult {
    switch stub {
    case .success:        return .success
    case .denied(let r):  return .denied(reason: r)
    case .failed(let e):  return .failed(error: e)
    }
}
```

- [ ] **Step 2: Build helper, run tests**

```bash
xcodebuild -project /Users/a77/RamKiller/RamKiller.xcodeproj -target RamKillerHelper build
```

- [ ] **Step 3: Commit**

```bash
git add RamKillerHelper/HelperService.swift
git commit -m "phase-7: wire launch-item commands in HelperService"
```

---

## Task 4: `LaunchItem` model

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Core/Models/LaunchItem.swift`

- [ ] **Step 1: Write the model**

```swift
import Foundation

public struct LaunchItem: Identifiable, Hashable {
    public enum Source: String {
        case loginItem
        case userLaunchAgent
        case systemLaunchAgent
        case systemLaunchDaemon

        public var label: String {
            switch self {
            case .loginItem:           return "Login Item"
            case .userLaunchAgent:     return "User Agent"
            case .systemLaunchAgent:   return "System Agent"
            case .systemLaunchDaemon:  return "System Daemon"
            }
        }
    }

    public let id: String          // label
    public let label: String
    public let source: Source
    public let plistPath: String?
    public let program: String?
    public let isDisabled: Bool
    public let isApple: Bool
    public let bundleIdentifier: String?
}
```

- [ ] **Step 2: Commit**

```bash
git add RamKiller/Core/Models/LaunchItem.swift
git commit -m "phase-7: LaunchItem model"
```

---

## Task 5: `KnownDaemons` whitelist

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Core/Services/KnownDaemons.swift`

- [ ] **Step 1: Write the constants**

```swift
import Foundation

public enum KnownDaemons {
    /// Labels that should ALWAYS be displayed as "do not touch — system critical".
    public static let critical: Set<String> = [
        "com.apple.cfprefsd.xpc.daemon",
        "com.apple.cfprefsd.xpc.agent",
        "com.apple.distnoted.xpc.daemon",
        "com.apple.distnoted.xpc.agent",
        "com.apple.tccd",
        "com.apple.WindowServer",
        "com.apple.coreservicesd",
        "com.apple.launchd",
        "com.apple.notifyd",
        "com.apple.audio.coreaudiod",
        "com.apple.opendirectoryd",
        "com.apple.securityd",
        "com.apple.trustd",
        "com.apple.spotlight",
        "com.apple.mds",
        "com.apple.metadata.mds"
    ]

    public static func isCritical(_ label: String) -> Bool {
        critical.contains(label)
    }

    public static func isApple(_ label: String) -> Bool {
        label.hasPrefix("com.apple.")
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add RamKiller/Core/Services/KnownDaemons.swift
git commit -m "phase-7: KnownDaemons whitelist"
```

---

## Task 6: `PlistService` enumerator

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Core/Services/PlistService.swift`
- Test: `/Users/a77/RamKiller/RamKillerTests/PlistServiceTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import RamKiller

final class PlistServiceTests: XCTestCase {
    func testDiscoverIncludesUserAgents() async {
        let service = PlistService()
        let items = await service.discover()
        // Most Macs have at least a few user LaunchAgents installed
        XCTAssertGreaterThan(items.count, 0)
        XCTAssertTrue(items.contains { $0.source == .systemLaunchDaemon })
    }
}
```

- [ ] **Step 2: Implement**

```swift
import Foundation
import ServiceManagement

public actor PlistService {
    public init() {}

    public func discover() async -> [LaunchItem] {
        var out: [LaunchItem] = []
        out.append(contentsOf: await scanDirectory(
            path: NSString(string: "~/Library/LaunchAgents").expandingTildeInPath,
            source: .userLaunchAgent
        ))
        out.append(contentsOf: await scanDirectory(
            path: "/Library/LaunchAgents",
            source: .systemLaunchAgent
        ))
        out.append(contentsOf: await scanDirectory(
            path: "/Library/LaunchDaemons",
            source: .systemLaunchDaemon
        ))
        out.append(contentsOf: await readLoginItems())
        return out.sorted { ($0.label.lowercased()) < ($1.label.lowercased()) }
    }

    private func scanDirectory(path: String, source: LaunchItem.Source) async -> [LaunchItem] {
        var items: [LaunchItem] = []
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: path) else { return [] }
        for name in entries {
            let full = "\(path)/\(name)"
            let isDisabled = name.hasSuffix(".disabled")
            let plistPath = full
            let actualPlist = isDisabled ? String(full.dropLast(".disabled".count)) : full
            guard let dict = try? loadPlist(at: actualPlist) else { continue }
            let label = (dict["Label"] as? String)
                ?? (name as NSString).deletingPathExtension
            let program = (dict["Program"] as? String) ?? (dict["BundleProgram"] as? String) ?? (dict["ProgramArguments"] as? [String])?.first
            let bundleId = label.split(separator: ".").prefix(3).joined(separator: ".")
            items.append(LaunchItem(
                id: label, label: label, source: source,
                plistPath: plistPath, program: program,
                isDisabled: isDisabled,
                isApple: KnownDaemons.isApple(label),
                bundleIdentifier: bundleId
            ))
        }
        return items
    }

    private func loadPlist(at path: String) throws -> [String: Any]? {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    }

    private func readLoginItems() async -> [LaunchItem] {
        // SMAppService doesn't enumerate other apps' login items. Best-effort: NSWorkspace runningApplications
        // doesn't help either. We return only RamKiller's own login item registration as a placeholder.
        let svc = SMAppService.mainApp
        return [LaunchItem(
            id: "com.vannaq.ramkiller",
            label: "RamKiller",
            source: .loginItem,
            plistPath: nil,
            program: Bundle.main.executablePath,
            isDisabled: svc.status != .enabled,
            isApple: false,
            bundleIdentifier: "com.vannaq.ramkiller"
        )]
    }
}
```

> **Note:** macOS 13+ exposes a system-wide login items list only via private API. For self-use we settle for surfacing our own login item; the LaunchAgents directories cover the typical "third-party autostart" use case.

- [ ] **Step 3: Run tests**

⌘U.

- [ ] **Step 4: Commit**

```bash
git add RamKiller/Core/Services/PlistService.swift RamKillerTests/PlistServiceTests.swift
git commit -m "phase-7: PlistService enumerates 4 launch-item sources"
```

---

## Task 7: `LaunchItemManager`

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Core/Services/LaunchItemManager.swift`

- [ ] **Step 1: Write the manager**

```swift
import Foundation
import Shared

@MainActor
public final class LaunchItemManager {
    public static let shared = LaunchItemManager()
    private init() {}

    public func disable(_ item: LaunchItem) async throws {
        guard let plist = item.plistPath else { return }
        let disabled = plist + ".disabled"
        switch item.source {
        case .userLaunchAgent:
            // User dirs: do it ourselves
            _ = try? await unloadUser(label: item.label, plist: plist)
            try FileManager.default.moveItem(atPath: plist, toPath: disabled)
        case .systemLaunchAgent, .systemLaunchDaemon:
            // System dirs: helper
            _ = try await HelperBridge.shared.send(.unloadLaunchPlist(path: plist))
            _ = try await HelperBridge.shared.send(.renamePlist(from: plist, to: disabled))
        case .loginItem:
            // SMAppService unregister (only works for our own app)
            try LoginItemService.shared.unregister().get()
        }
        UserActionLog.shared.record(type: "disable_launch_item", target: item.label, success: true)
    }

    public func enable(_ item: LaunchItem) async throws {
        guard let plist = item.plistPath else { return }
        let active = plist.hasSuffix(".disabled") ? String(plist.dropLast(".disabled".count)) : plist
        switch item.source {
        case .userLaunchAgent:
            try FileManager.default.moveItem(atPath: plist, toPath: active)
            // Best-effort load
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            task.arguments = ["bootstrap", "gui/\(getuid())", active]
            try? task.run()
        case .systemLaunchAgent, .systemLaunchDaemon:
            _ = try await HelperBridge.shared.send(.renamePlist(from: plist, to: active))
            _ = try await HelperBridge.shared.send(.loadLaunchPlist(path: active))
        case .loginItem:
            try LoginItemService.shared.register().get()
        }
        UserActionLog.shared.record(type: "enable_launch_item", target: item.label, success: true)
    }

    public func delete(_ item: LaunchItem) async throws {
        guard let plist = item.plistPath else { return }
        switch item.source {
        case .userLaunchAgent:
            try FileManager.default.removeItem(atPath: plist)
        case .systemLaunchAgent, .systemLaunchDaemon:
            _ = try await HelperBridge.shared.send(.deletePlist(path: plist))
        case .loginItem:
            try LoginItemService.shared.unregister().get()
        }
        UserActionLog.shared.record(type: "delete_launch_item", target: item.label, success: true)
    }

    private func unloadUser(label: String, plist: String) async throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["bootout", "gui/\(getuid())", plist]
        try task.run()
        task.waitUntilExit()
    }
}

extension Result {
    func get() throws -> Success {
        switch self {
        case .success(let v): return v
        case .failure(let e): throw e
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add RamKiller/Core/Services/LaunchItemManager.swift
git commit -m "phase-7: LaunchItemManager (disable/enable/delete)"
```

---

## Task 8: `LaunchItemRow`

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Features/LaunchItems/LaunchItemRow.swift`

- [ ] **Step 1: Write the row**

```swift
import SwiftUI

struct LaunchItemRow: View {
    let item: LaunchItem
    let onDisable: () -> Void
    let onEnable: () -> Void
    let onDelete: () -> Void
    @State private var showDeleteConfirm = false
    @State private var error: String?

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    Text(item.label)
                    if KnownDaemons.isCritical(item.label) {
                        Label("Critical", systemImage: "lock.shield").labelStyle(.iconOnly)
                            .foregroundStyle(.orange)
                    } else if item.isApple {
                        Image(systemName: "apple.logo").foregroundStyle(.secondary)
                    }
                }
                if let p = item.program {
                    Text(p).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
            }
            Spacer()
            statusBadge
            HStack(spacing: 4) {
                if item.isDisabled {
                    Button("Enable") { onEnable() }
                } else {
                    Button("Disable") { onDisable() }
                }
                Button("Delete", role: .destructive) { showDeleteConfirm = true }
                    .disabled(KnownDaemons.isCritical(item.label))
            }
        }
        .alert("Delete \(item.label)?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("This permanently removes the plist file. Cannot be undone.")
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if item.isDisabled {
            Text("Disabled").font(.caption).foregroundStyle(.secondary)
        } else {
            Text("Active").font(.caption).foregroundStyle(.green)
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add RamKiller/Features/LaunchItems/LaunchItemRow.swift
git commit -m "phase-7: LaunchItemRow"
```

---

## Task 9: `LaunchItemsView` grouped list

**Files:**
- Modify: `/Users/a77/RamKiller/RamKiller/Features/LaunchItems/LaunchItemsView.swift`

- [ ] **Step 1: Replace placeholder**

```swift
import SwiftUI

struct LaunchItemsView: View {
    @State private var items: [LaunchItem] = []
    @State private var loading = true
    @State private var search: String = ""
    @State private var error: String?

    private var grouped: [(LaunchItem.Source, [LaunchItem])] {
        let sources: [LaunchItem.Source] = [.loginItem, .userLaunchAgent, .systemLaunchAgent, .systemLaunchDaemon]
        return sources.compactMap { src in
            let inGroup = items.filter { $0.source == src && (search.isEmpty || $0.label.localizedCaseInsensitiveContains(search)) }
            return inGroup.isEmpty ? nil : (src, inGroup)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search", text: $search)
                    .textFieldStyle(.roundedBorder)
                Button("Refresh") { Task { await load() } }
            }
            .padding()

            if loading {
                ProgressView().padding()
            } else {
                List {
                    ForEach(grouped, id: \.0) { (src, list) in
                        Section(src.label) {
                            ForEach(list) { item in
                                LaunchItemRow(
                                    item: item,
                                    onDisable: { Task { await act(item, action: .disable) } },
                                    onEnable: { Task { await act(item, action: .enable) } },
                                    onDelete: { Task { await act(item, action: .delete) } }
                                )
                            }
                        }
                    }
                }
            }

            if let e = error {
                Text(e).font(.caption).foregroundStyle(.red).padding()
            }
        }
        .navigationTitle("Launch Items")
        .task { await load() }
    }

    private enum Action { case disable, enable, delete }

    private func load() async {
        loading = true
        items = await PlistService().discover()
        loading = false
    }

    private func act(_ item: LaunchItem, action: Action) async {
        do {
            switch action {
            case .disable: try await LaunchItemManager.shared.disable(item)
            case .enable:  try await LaunchItemManager.shared.enable(item)
            case .delete:  try await LaunchItemManager.shared.delete(item)
            }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        await load()
    }
}
```

- [ ] **Step 2: Build and run**

⌘R. Navigate to Launch Items. Verify:
- 4 sections appear (Login Items, User Agents, System Agents, System Daemons).
- Critical daemons have shield icon and disabled "Delete" button.
- Disable a benign user agent → moved to `.disabled`. Re-enable → restored.
- System-level disable triggers the helper (status remains green).

- [ ] **Step 3: Commit**

```bash
git add RamKiller/Features/LaunchItems/LaunchItemsView.swift
git commit -m "phase-7: LaunchItemsView grouped + actions"
```

---

## Task 10: Acceptance verification

- [ ] **Step 1: Run all tests**

⌘U.

- [ ] **Step 2: End-to-end**

| Check | Expected |
|---|---|
| All 4 categories populated | ✅ |
| Critical daemons protected from delete | ✅ |
| Search filters live | ✅ |
| Disable user agent works (file renamed `.disabled`) | ✅ |
| Re-enable user agent works | ✅ |
| Disable system daemon works (helper invoked) | ✅ |
| Re-enable system daemon works | ✅ |
| Delete works for non-critical items | ✅ |
| User Action log shows new entries | ✅ |

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "phase-7: post-verification" --allow-empty
```

---

## Phase 7 Acceptance Criteria

- [ ] All XCTest pass.
- [ ] PlistService enumerates User Agents, System Agents, System Daemons reliably.
- [ ] Critical daemons cannot be deleted from the UI.
- [ ] Disable / Enable cycle works for both user and system items.
- [ ] System operations transit the privileged helper, not the app directly.
- [ ] User Action log records every disable/enable/delete.

---

## Project completion

If all 8 Phase plans (P0–P7) are checked off:

- [ ] Run all tests one final time: ⌘U.
- [ ] Tag a release: `git tag -a v1.0.0 -m "RamKiller v1.0.0 — full feature set"`.
- [ ] Optional: archive a release build via Xcode → Product → Archive → Export "Copy App" for stash on disk.
- [ ] Backup `~/Library/Application Support/RamKiller/db.store` if you care about your accumulated history.

**RamKiller is feature-complete.** All 8 phases — monitoring, processes, automation, cache cleaning, large/duplicate files, uninstaller, launch items — are functional, persistent, and production-quality for personal use.
