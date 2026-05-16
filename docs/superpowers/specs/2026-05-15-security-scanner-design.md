# Security Scanner — Design Spec
**Date:** 2026-05-15  
**Status:** Approved for implementation

---

## Overview

A new **Security** section in BeagleX that scans the Mac for malware, suspicious launch items, unsigned network-connected processes, and permission-abusing apps. Fully offline. Users can view findings, remove threats, or ignore individual items. Scanning can be triggered manually or scheduled automatically.

---

## Goals

- Detect the four threat categories without any network calls
- Let users remove or quarantine threats directly from the app
- Support automatic scheduled scanning with push notifications
- Fit naturally into the existing sidebar navigation and visual theme

---

## Architecture

### Protocol

```swift
protocol SecurityCheck: Sendable {
    var checkType: SecurityCheckType { get }
    func run() async -> [SecurityFinding]
}

enum SecurityCheckType: String, Codable {
    case malware, launchItem, network, permission
}
```

### Four Check Modules

| Module | What it does |
|--------|-------------|
| `MalwareSignatureCheck` | Walks `~/Library/`, `/Applications/`, `LaunchAgents/`, `LaunchDaemons/` paths. Matches filenames, bundle IDs, and path patterns against the bundled `threat-signatures.json`. |
| `SuspiciousLaunchItemCheck` | Iterates every LaunchAgent and LaunchDaemon plist. Runs `codesign -v` on the referenced binary; flags entries that are unsigned or whose binary is missing. Reuses `LaunchItemManager` for enumeration. |
| `NetworkConnectionCheck` | Reads active TCP connections via `proc_pidinfo`. For each connected process, checks code-signing status. Flags processes with active outbound connections that are unsigned or have no developer ID. |
| `PermissionAbuseCheck` | Reads the user TCC database at `~/Library/Application Support/com.apple.TCC/TCC.db`. Finds apps that hold two or more high-risk permissions (full disk access, microphone, camera, screen recording) and have no valid developer signature. **Requires Full Disk Access.** If FDA is not granted, this check returns a single `info`-severity finding prompting the user to grant access (reuses the existing `hasFullDiskAccess` check from `LeftoverScanner`). |

### SecurityScanCoordinator

`@MainActor final class SecurityScanCoordinator: ObservableObject`

```
@Published findings: [SecurityFinding]
@Published scanState: ScanState          // idle | scanning(progress) | done
@Published lastScanDate: Date?
```

```swift
enum ScanState {
    case idle
    case scanning(progress: Double)   // 0.0–1.0
    case done(Date)
}
```

- Runs all four checks in parallel with `async let`
- Merges results, filters ignored IDs, sorts by severity
- Persists `lastScanDate` and `ignoredIDs` in `UserDefaults`
- Exposes `scan()` (manual) and `scheduleAutoScan()` (sets up timer on `start()`)

### SecurityFinding

```swift
struct SecurityFinding: Identifiable, Codable {
    let id: UUID
    let checkType: SecurityCheckType
    let severity: Severity            // critical | warning | info
    let title: String
    let detail: String
    let path: String?                 // file path for removal
    let bundleID: String?
}

enum Severity: String, Codable, Comparable {
    case info, warning, critical
}
```

---

## Threat Signature Database

File: `BeagleX/Resources/threat-signatures.json`  
Bundled with the app. Updated with each release.

```json
{
  "version": "1.0",
  "updated": "2026-05-15",
  "malware": [
    {
      "name": "Shlayer",
      "pathPatterns": ["*/com.shlayer.*", "*/MacOS/staf"],
      "bundleIDPatterns": ["com.shlayer.*"]
    },
    {
      "name": "Adload",
      "pathPatterns": ["/Library/LaunchAgents/com.adload.*", "*/MacOS/updater"]
    },
    {
      "name": "Pirrit",
      "pathPatterns": ["*/com.pirrit.*", "*/pirrit*"]
    },
    {
      "name": "KeRanger",
      "pathPatterns": ["*/Contents/Resources/General.rtf"]
    },
    {
      "name": "XCSSET",
      "pathPatterns": ["*/XCSSET*", "*/fastlane/worker.rb"]
    }
  ]
}
```

Initial database covers 20+ known macOS threats: Shlayer, Adload, Pirrit, KeRanger, XCSSET, MacDefender, Flashback, Genieo, OSX.DubRobber, OSX.Tarmac, and others.

---

## Remove / Quarantine Flow

| Scenario | Mechanism |
|----------|-----------|
| File in `~/Library/` (user space) | Move to `~/.Trash/` via `FileManager` in main process. Show confirmation alert first. |
| File in `/Library/` (system space) | Route through `HelperBridge` using existing `removeAppBundle` / `deletePlist` operations. Requires privileged helper. |
| App bundle (permission abuse) | Move entire `.app` to `~/.Trash/`. |
| Ignore item | Add `finding.id` to `AppStorage("security.ignoredIDs")`. Filtered out on next scan. |

All destructive actions require a confirmation alert. No permanent deletion — everything goes to Trash so the user can recover if needed.

---

## Auto-Scan Scheduling

Setting stored in `AppStorage("security.autoScanInterval")`:
- `"off"` — disabled
- `"daily"` — scan if last scan was > 24h ago
- `"weekly"` — scan if last scan was > 7 days ago

On `SecurityScanCoordinator.start()`, check interval against `lastScanDate`. If overdue, trigger a background scan. Use existing `NotificationService` to deliver a notification when new findings are detected.

Settings UI added to `SettingsView` alongside existing automation settings.

---

## Navigation

New sidebar entry added to `SidebarItem`:

```swift
case security   // label: "安全" / "Security", icon: "shield.checkerboard"
```

Positioned between `automation` and `cacheCleaner` in the sidebar.

---

## New Files

```
BeagleX/
  Features/
    Security/
      SecurityView.swift              — main SwiftUI view (grouped list)
      SecurityScanCoordinator.swift   — ObservableObject, orchestrates checks
      SecurityFinding.swift           — data model
      Checks/
        MalwareSignatureCheck.swift
        SuspiciousLaunchItemCheck.swift
        NetworkConnectionCheck.swift
        PermissionAbuseCheck.swift
  Resources/
    threat-signatures.json
```

Modified files:
- `SidebarItem.swift` — add `.security` case
- `MainContentView.swift` — wire security view
- `BeagleXApp.swift` — inject `SecurityScanCoordinator`
- `SettingsView.swift` — add auto-scan interval picker

---

## Out of Scope

- Online lookups (VirusTotal, any external API) — offline only
- Real-time file system monitoring (FSEvents) — scan-on-demand only
- Browser extension scanning — future version
- Kernel extension / rootkit detection — requires additional entitlements
