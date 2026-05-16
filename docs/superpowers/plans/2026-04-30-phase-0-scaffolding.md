# Phase 0 — Scaffolding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a runnable Xcode project skeleton with menubar + main window, 8 placeholder feature pages, login-item registration, and minimal settings page. No actual features yet.

**Architecture:** Single Xcode project with 3 targets — `BeagleX` (main app), `BeagleXHelper` (privileged daemon, defined here but empty until Phase 2), and `Shared` Swift Package (XPC types). SwiftUI lifecycle with `MenuBarExtra` + `Window` scenes.

**Tech Stack:** Xcode 15.4+, Swift 5.10, SwiftUI (macOS 14.4+), `SMAppService`, Swift Package Manager.

---

## File Structure (created/modified in this Phase)

| Path | Purpose |
|---|---|
| `BeagleX.xcodeproj/` | Xcode project file |
| `BeagleX/App/BeagleXApp.swift` | `@main`, defines `MenuBarExtra` + `Window` |
| `BeagleX/App/AppDelegate.swift` | Hooks for app launch/terminate |
| `BeagleX/Core/Navigation/SidebarItem.swift` | Enum of 8 sidebar entries |
| `BeagleX/UI/Sidebar/SidebarView.swift` | Left nav |
| `BeagleX/UI/MenuBar/MenuBarView.swift` | Menubar dropdown placeholder |
| `BeagleX/UI/Components/PlaceholderView.swift` | Reusable "Coming in Phase X" view |
| `BeagleX/Features/Monitoring/MonitoringView.swift` | P1 placeholder |
| `BeagleX/Features/Processes/ProcessesView.swift` | P2 placeholder |
| `BeagleX/Features/Automation/AutomationView.swift` | P3 placeholder |
| `BeagleX/Features/CacheCleaner/CacheCleanerView.swift` | P4 placeholder |
| `BeagleX/Features/LargeFiles/LargeFilesView.swift` | P5 placeholder |
| `BeagleX/Features/Uninstaller/UninstallerView.swift` | P6 placeholder |
| `BeagleX/Features/LaunchItems/LaunchItemsView.swift` | P7 placeholder |
| `BeagleX/Features/Settings/SettingsView.swift` | Settings (Launch at Login + About) |
| `BeagleX/Core/Services/LoginItemService.swift` | `SMAppService.mainApp` register/unregister |
| `BeagleX/Resources/Localizable.xcstrings` | i18n strings (zh + en) |
| `BeagleX/BeagleX.entitlements` | App entitlements (no sandbox) |
| `BeagleXHelper/main.swift` | Helper stub (does nothing yet) |
| `BeagleXHelper/BeagleXHelper.entitlements` | Helper entitlements |
| `Shared/Package.swift` | Swift Package manifest |
| `Shared/Sources/Shared/Placeholder.swift` | Stub for shared types |
| `BeagleXTests/BeagleXTests.swift` | Sanity test |
| `.gitignore` | Xcode/macOS ignores |

---

## Task 1: Create the Xcode project (manual GUI)

**Files:**
- Create: `/Users/a77/BeagleX/BeagleX.xcodeproj/...`

- [ ] **Step 1: Open Xcode and create the project**

In Xcode menu: **File → New → Project…**
- Choose **macOS** tab → **App** → Next
- Product Name: `BeagleX`
- Team: select your Apple ID team (free personal team is OK)
- Organization Identifier: `com.vannaq`
- Bundle Identifier (auto-derived): `com.vannaq.beaglex`
- Interface: **SwiftUI**
- Language: **Swift**
- Storage: **SwiftData**
- Include Tests: ✅
- Click Next → choose location `/Users/a77/BeagleX/` → uncheck "Create Git repository" (we already initialized) → Create

- [ ] **Step 2: Verify the project structure**

Run in terminal:
```bash
ls /Users/a77/BeagleX/
```

Expected output (order may vary):
```
BeagleX
BeagleX.xcodeproj
BeagleXTests
BeagleXUITests
docs
```

- [ ] **Step 3: Set deployment target to macOS 14.4**

In Xcode: select project root → `BeagleX` target → **General** tab → **Minimum Deployments** → set to **macOS 14.4**.

Repeat for the test targets. (Helper target will be added in Task 4.)

- [ ] **Step 4: Set Swift language version to Swift 5.10**

`BeagleX` target → **Build Settings** → search "Swift Language Version" → set to **Swift 5** (Xcode 15.4+ defaults to 5.10 under this setting).

- [ ] **Step 5: Commit baseline project**

```bash
cd /Users/a77/BeagleX
git add BeagleX.xcodeproj BeagleX BeagleXTests BeagleXUITests
git commit -m "phase-0: bootstrap Xcode project"
```

---

## Task 2: Add `.gitignore`

**Files:**
- Create: `/Users/a77/BeagleX/.gitignore`

- [ ] **Step 1: Write the gitignore**

Create `/Users/a77/BeagleX/.gitignore`:

```gitignore
# macOS
.DS_Store

# Xcode
build/
DerivedData/
*.xcworkspace/xcuserdata/
*.xcodeproj/xcuserdata/
*.xcodeproj/project.xcworkspace/xcuserdata/
*.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/
xcuserdata/

# Swift Package Manager
.build/
.swiftpm/
Package.resolved

# Build artifacts
*.dSYM
*.dSYM.zip
*.ipa
*.app
```

- [ ] **Step 2: Commit**

```bash
git add .gitignore
git commit -m "phase-0: add gitignore"
```

---

## Task 3: Create `Shared` Swift Package (for XPC types in later phases)

**Files:**
- Create: `/Users/a77/BeagleX/Shared/Package.swift`
- Create: `/Users/a77/BeagleX/Shared/Sources/Shared/Placeholder.swift`

- [ ] **Step 1: Create the package via terminal (faster than Xcode GUI)**

```bash
mkdir -p /Users/a77/BeagleX/Shared/Sources/Shared
mkdir -p /Users/a77/BeagleX/Shared/Tests/SharedTests
```

- [ ] **Step 2: Write `Package.swift`**

Create `/Users/a77/BeagleX/Shared/Package.swift`:

```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Shared",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Shared", targets: ["Shared"]),
    ],
    targets: [
        .target(name: "Shared"),
        .testTarget(name: "SharedTests", dependencies: ["Shared"]),
    ]
)
```

- [ ] **Step 3: Write the placeholder source**

Create `/Users/a77/BeagleX/Shared/Sources/Shared/Placeholder.swift`:

```swift
import Foundation

/// Placeholder so the package compiles. XPC protocol/types arrive in Phase 2.
public enum SharedNamespace {
    public static let version: String = "0.0.1"
}
```

- [ ] **Step 4: Verify it builds**

```bash
cd /Users/a77/BeagleX/Shared
swift build
```

Expected output ends with: `Build complete!`

- [ ] **Step 5: Add the package to the Xcode project**

In Xcode: **File → Add Package Dependencies… → Add Local…** → choose `/Users/a77/BeagleX/Shared` → Add Package.
Then in `BeagleX` target → **General** → **Frameworks and Libraries** → **+** → choose **Shared**.

- [ ] **Step 6: Commit**

```bash
cd /Users/a77/BeagleX
git add Shared BeagleX.xcodeproj
git commit -m "phase-0: add Shared swift package"
```

---

## Task 4: Add `BeagleXHelper` target (empty stub)

**Files:**
- Create: `/Users/a77/BeagleX/BeagleXHelper/main.swift`
- Create: `/Users/a77/BeagleX/BeagleXHelper/BeagleXHelper.entitlements`

- [ ] **Step 1: Add a Command-Line Tool target via Xcode**

In Xcode: **File → New → Target… → macOS → Command Line Tool → Next**
- Product Name: `BeagleXHelper`
- Team: same as main app
- Bundle Identifier: `com.vannaq.beaglex.helper`
- Language: **Swift**
- Click Finish.

- [ ] **Step 2: Write helper stub**

Replace `/Users/a77/BeagleX/BeagleXHelper/main.swift` content with:

```swift
import Foundation

// XPC server arrives in Phase 2. For now we just log and exit.
// Helper will run as a daemon registered via SMAppService later.
let logger = OSLog(subsystem: "com.vannaq.beaglex.helper", category: "main")
NSLog("BeagleXHelper stub started — Phase 2 will fill this in")

// Run forever so launchd doesn't restart-loop us in dev tests.
RunLoop.current.run()
```

- [ ] **Step 3: Add `Shared` dependency to helper**

In Xcode → `BeagleXHelper` target → **General** → **Frameworks and Libraries** → **+** → **Shared**.

- [ ] **Step 4: Create helper entitlements file**

Create `/Users/a77/BeagleX/BeagleXHelper/BeagleXHelper.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

In Xcode → `BeagleXHelper` target → **Build Settings** → search "Code Signing Entitlements" → set to `BeagleXHelper/BeagleXHelper.entitlements`.

- [ ] **Step 5: Verify both targets build**

In Xcode: **Product → Build** (⌘B). Expected: "Build Succeeded" for both `BeagleX` and `BeagleXHelper`.

- [ ] **Step 6: Commit**

```bash
git add BeagleXHelper BeagleX.xcodeproj
git commit -m "phase-0: add BeagleXHelper stub target"
```

---

## Task 5: Disable sandbox on main app

**Files:**
- Modify: `/Users/a77/BeagleX/BeagleX/BeagleX.entitlements`

- [ ] **Step 1: Locate the entitlements file**

Xcode auto-created one. Verify with:
```bash
ls /Users/a77/BeagleX/BeagleX/*.entitlements
```

- [ ] **Step 2: Replace the entitlements content**

Set `/Users/a77/BeagleX/BeagleX/BeagleX.entitlements` to:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

- [ ] **Step 3: Commit**

```bash
git add BeagleX/BeagleX.entitlements
git commit -m "phase-0: disable sandbox on main app"
```

---

## Task 6: Define `SidebarItem` enum

**Files:**
- Create: `/Users/a77/BeagleX/BeagleX/Core/Navigation/SidebarItem.swift`
- Test: `/Users/a77/BeagleX/BeagleXTests/SidebarItemTests.swift`

- [ ] **Step 1: Write the failing test**

Create `/Users/a77/BeagleX/BeagleXTests/SidebarItemTests.swift`:

```swift
import XCTest
@testable import BeagleX

final class SidebarItemTests: XCTestCase {
    func testAllCasesIncludesAllEightFeaturesPlusSettings() {
        let cases = SidebarItem.allCases
        XCTAssertEqual(cases.count, 9)
        XCTAssertTrue(cases.contains(.monitoring))
        XCTAssertTrue(cases.contains(.processes))
        XCTAssertTrue(cases.contains(.automation))
        XCTAssertTrue(cases.contains(.cacheCleaner))
        XCTAssertTrue(cases.contains(.largeFiles))
        XCTAssertTrue(cases.contains(.uninstaller))
        XCTAssertTrue(cases.contains(.launchItems))
        XCTAssertTrue(cases.contains(.settings))
    }

    func testEachCaseHasNonEmptyLabelAndIcon() {
        for item in SidebarItem.allCases {
            XCTAssertFalse(item.label.isEmpty, "Empty label for \(item)")
            XCTAssertFalse(item.icon.isEmpty, "Empty icon for \(item)")
        }
    }
}
```

- [ ] **Step 2: Run the test, expect failure**

In Xcode: ⌘U (run all tests). Expected: build error "Cannot find type 'SidebarItem' in scope".

- [ ] **Step 3: Create the file**

Create `/Users/a77/BeagleX/BeagleX/Core/Navigation/SidebarItem.swift`:

```swift
import Foundation

enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case monitoring
    case processes
    case automation
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
        case .cacheCleaner: return "trash"
        case .largeFiles:   return "doc.zipper"
        case .uninstaller:  return "shippingbox"
        case .launchItems:  return "rocket"
        case .settings:     return "gearshape"
        }
    }
}
```

- [ ] **Step 4: Run tests, expect pass**

⌘U. Expected: both `testAllCasesIncludesAllEightFeaturesPlusSettings` and `testEachCaseHasNonEmptyLabelAndIcon` pass.

- [ ] **Step 5: Commit**

```bash
git add BeagleX/Core BeagleXTests/SidebarItemTests.swift
git commit -m "phase-0: add SidebarItem enum + tests"
```

---

## Task 7: Reusable `PlaceholderView`

**Files:**
- Create: `/Users/a77/BeagleX/BeagleX/UI/Components/PlaceholderView.swift`

- [ ] **Step 1: Write the view**

Create `/Users/a77/BeagleX/BeagleX/UI/Components/PlaceholderView.swift`:

```swift
import SwiftUI

struct PlaceholderView: View {
    let title: String
    let phase: String
    let icon: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.title)
            Text("Coming in \(phase)")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    PlaceholderView(title: "Monitoring", phase: "Phase 1", icon: "memorychip")
        .frame(width: 600, height: 400)
}
```

- [ ] **Step 2: Verify the preview renders**

Open the file in Xcode → Canvas (⌥⌘↵) → click "Resume" if prompted. Expected: a centered icon + title + "Coming in Phase 1" text.

- [ ] **Step 3: Commit**

```bash
git add BeagleX/UI/Components/PlaceholderView.swift
git commit -m "phase-0: add PlaceholderView component"
```

---

## Task 8: Seven feature placeholder views

**Files:**
- Create: `/Users/a77/BeagleX/BeagleX/Features/Monitoring/MonitoringView.swift`
- Create: `/Users/a77/BeagleX/BeagleX/Features/Processes/ProcessesView.swift`
- Create: `/Users/a77/BeagleX/BeagleX/Features/Automation/AutomationView.swift`
- Create: `/Users/a77/BeagleX/BeagleX/Features/CacheCleaner/CacheCleanerView.swift`
- Create: `/Users/a77/BeagleX/BeagleX/Features/LargeFiles/LargeFilesView.swift`
- Create: `/Users/a77/BeagleX/BeagleX/Features/Uninstaller/UninstallerView.swift`
- Create: `/Users/a77/BeagleX/BeagleX/Features/LaunchItems/LaunchItemsView.swift`

- [ ] **Step 1: Write each placeholder view**

Each file follows the same pattern. Example for monitoring:

`/Users/a77/BeagleX/BeagleX/Features/Monitoring/MonitoringView.swift`:
```swift
import SwiftUI

struct MonitoringView: View {
    var body: some View {
        PlaceholderView(title: "Memory Monitoring", phase: "Phase 1", icon: "memorychip")
            .navigationTitle("Memory")
    }
}
```

`/Users/a77/BeagleX/BeagleX/Features/Processes/ProcessesView.swift`:
```swift
import SwiftUI

struct ProcessesView: View {
    var body: some View {
        PlaceholderView(title: "Processes", phase: "Phase 2", icon: "list.bullet.rectangle")
            .navigationTitle("Processes")
    }
}
```

`/Users/a77/BeagleX/BeagleX/Features/Automation/AutomationView.swift`:
```swift
import SwiftUI

struct AutomationView: View {
    var body: some View {
        PlaceholderView(title: "Automation", phase: "Phase 3", icon: "wand.and.stars")
            .navigationTitle("Automation")
    }
}
```

`/Users/a77/BeagleX/BeagleX/Features/CacheCleaner/CacheCleanerView.swift`:
```swift
import SwiftUI

struct CacheCleanerView: View {
    var body: some View {
        PlaceholderView(title: "Cache Cleaner", phase: "Phase 4", icon: "trash")
            .navigationTitle("Cache Cleaner")
    }
}
```

`/Users/a77/BeagleX/BeagleX/Features/LargeFiles/LargeFilesView.swift`:
```swift
import SwiftUI

struct LargeFilesView: View {
    var body: some View {
        PlaceholderView(title: "Large Files", phase: "Phase 5", icon: "doc.zipper")
            .navigationTitle("Large Files")
    }
}
```

`/Users/a77/BeagleX/BeagleX/Features/Uninstaller/UninstallerView.swift`:
```swift
import SwiftUI

struct UninstallerView: View {
    var body: some View {
        PlaceholderView(title: "Uninstaller", phase: "Phase 6", icon: "shippingbox")
            .navigationTitle("Uninstaller")
    }
}
```

`/Users/a77/BeagleX/BeagleX/Features/LaunchItems/LaunchItemsView.swift`:
```swift
import SwiftUI

struct LaunchItemsView: View {
    var body: some View {
        PlaceholderView(title: "Launch Items", phase: "Phase 7", icon: "rocket")
            .navigationTitle("Launch Items")
    }
}
```

- [ ] **Step 2: Verify the project builds**

⌘B. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

```bash
git add BeagleX/Features
git commit -m "phase-0: add 7 feature placeholder views"
```

---

## Task 9: `LoginItemService` for SMAppService.mainApp

**Files:**
- Create: `/Users/a77/BeagleX/BeagleX/Core/Services/LoginItemService.swift`
- Test: `/Users/a77/BeagleX/BeagleXTests/LoginItemServiceTests.swift`

- [ ] **Step 1: Write the failing test**

Create `/Users/a77/BeagleX/BeagleXTests/LoginItemServiceTests.swift`:

```swift
import XCTest
@testable import BeagleX

final class LoginItemServiceTests: XCTestCase {
    func testStatusReturnsKnownValue() {
        let status = LoginItemService.shared.status
        // We don't assert a specific status (depends on machine state),
        // but it should be one of the known values, not a crash.
        XCTAssertTrue([.notRegistered, .enabled, .requiresApproval, .notFound].contains(status))
    }
}
```

- [ ] **Step 2: Run, expect failure**

⌘U. Expected: "Cannot find type 'LoginItemService' in scope".

- [ ] **Step 3: Implement the service**

Create `/Users/a77/BeagleX/BeagleX/Core/Services/LoginItemService.swift`:

```swift
import Foundation
import ServiceManagement

final class LoginItemService {
    static let shared = LoginItemService()

    private let service: SMAppService

    private init() {
        self.service = .mainApp
    }

    var status: SMAppService.Status {
        service.status
    }

    @discardableResult
    func register() -> Result<Void, Error> {
        do {
            try service.register()
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    @discardableResult
    func unregister() -> Result<Void, Error> {
        do {
            try service.unregister()
            return .success(())
        } catch {
            return .failure(error)
        }
    }
}
```

- [ ] **Step 4: Run tests, expect pass**

⌘U. Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add BeagleX/Core/Services/LoginItemService.swift BeagleXTests/LoginItemServiceTests.swift
git commit -m "phase-0: add LoginItemService"
```

---

## Task 10: `SettingsView` with Launch-at-Login toggle

**Files:**
- Create: `/Users/a77/BeagleX/BeagleX/Features/Settings/SettingsView.swift`

- [ ] **Step 1: Write the view**

Create `/Users/a77/BeagleX/BeagleX/Features/Settings/SettingsView.swift`:

```swift
import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = true
    @State private var registrationError: String?

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        applyLoginSetting(enabled: newValue)
                    }
                if let err = registrationError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Text("Status: \(statusLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("About") {
                LabeledContent("Version", value: "0.1.0")
                LabeledContent("Bundle ID", value: "com.vannaq.beaglex")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .onAppear {
            // Reflect default-on policy at first launch
            if launchAtLogin && LoginItemService.shared.status != .enabled {
                applyLoginSetting(enabled: true)
            }
        }
    }

    private var statusLabel: String {
        switch LoginItemService.shared.status {
        case .enabled:           return "Enabled"
        case .notRegistered:     return "Not registered"
        case .requiresApproval:  return "Requires approval (System Settings → Login Items)"
        case .notFound:          return "Not found"
        @unknown default:        return "Unknown"
        }
    }

    private func applyLoginSetting(enabled: Bool) {
        let result = enabled
            ? LoginItemService.shared.register()
            : LoginItemService.shared.unregister()
        if case .failure(let err) = result {
            registrationError = err.localizedDescription
        } else {
            registrationError = nil
        }
    }
}
```

- [ ] **Step 2: Verify the preview renders**

Add to bottom of file:
```swift
#Preview {
    SettingsView()
        .frame(width: 600, height: 400)
}
```
Open Canvas → click Resume.

- [ ] **Step 3: Commit**

```bash
git add BeagleX/Features/Settings
git commit -m "phase-0: add SettingsView with launch-at-login"
```

---

## Task 11: `SidebarView`

**Files:**
- Create: `/Users/a77/BeagleX/BeagleX/UI/Sidebar/SidebarView.swift`

- [ ] **Step 1: Write the view**

```swift
import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem?

    var body: some View {
        List(selection: $selection) {
            Section("Tools") {
                ForEach([SidebarItem.monitoring, .processes, .automation,
                         .cacheCleaner, .largeFiles, .uninstaller, .launchItems], id: \.self) { item in
                    Label(item.label, systemImage: item.icon)
                        .tag(Optional(item))
                }
            }
            Section {
                Label(SidebarItem.settings.label, systemImage: SidebarItem.settings.icon)
                    .tag(Optional(SidebarItem.settings))
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 180)
        .navigationTitle("BeagleX")
    }
}

#Preview {
    @Previewable @State var sel: SidebarItem? = .monitoring
    return SidebarView(selection: $sel)
        .frame(width: 200, height: 500)
}
```

- [ ] **Step 2: Verify preview**

Canvas → Resume. Expected: list with 7 tools section + settings.

- [ ] **Step 3: Commit**

```bash
git add BeagleX/UI/Sidebar/SidebarView.swift
git commit -m "phase-0: add SidebarView"
```

---

## Task 12: `MainContentView` (sidebar + detail)

**Files:**
- Create: `/Users/a77/BeagleX/BeagleX/UI/MainContentView.swift`

- [ ] **Step 1: Write the view**

```swift
import SwiftUI

struct MainContentView: View {
    @State private var selection: SidebarItem? = .monitoring

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            detailView
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .monitoring:    MonitoringView()
        case .processes:     ProcessesView()
        case .automation:    AutomationView()
        case .cacheCleaner:  CacheCleanerView()
        case .largeFiles:    LargeFilesView()
        case .uninstaller:   UninstallerView()
        case .launchItems:   LaunchItemsView()
        case .settings:      SettingsView()
        case nil:            PlaceholderView(title: "Pick a tool", phase: "—", icon: "sidebar.left")
        }
    }
}

#Preview {
    MainContentView()
        .frame(width: 900, height: 600)
}
```

- [ ] **Step 2: Verify preview**

Canvas → Resume. Click each sidebar item → detail switches.

- [ ] **Step 3: Commit**

```bash
git add BeagleX/UI/MainContentView.swift
git commit -m "phase-0: add MainContentView"
```

---

## Task 13: `MenuBarView` (placeholder dropdown)

**Files:**
- Create: `/Users/a77/BeagleX/BeagleX/UI/MenuBar/MenuBarView.swift`

- [ ] **Step 1: Write the view**

```swift
import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("BeagleX")
                .font(.headline)
            Text("Phase 1 will fill these stats")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Divider()
        Button("Open Main Window") { openWindow(id: "main") }
        Button("Quit") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add BeagleX/UI/MenuBar/MenuBarView.swift
git commit -m "phase-0: add MenuBarView"
```

---

## Task 14: `AppDelegate`

**Files:**
- Create: `/Users/a77/BeagleX/BeagleX/App/AppDelegate.swift`

- [ ] **Step 1: Write the delegate**

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("BeagleX launched")
    }

    /// Closing the main window does NOT terminate the app — menubar stays alive.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add BeagleX/App/AppDelegate.swift
git commit -m "phase-0: add AppDelegate (menubar stays after window close)"
```

---

## Task 15: Wire `BeagleXApp` (main scene)

**Files:**
- Modify: `/Users/a77/BeagleX/BeagleX/App/BeagleXApp.swift` (replace Xcode default content)

- [ ] **Step 1: Replace the file**

```swift
import SwiftUI

@main
struct BeagleXApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("BeagleX", id: "main") {
            MainContentView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowToolbarStyle(.unified)

        MenuBarExtra {
            MenuBarView()
        } label: {
            Image(systemName: "memorychip")
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 2: Build and run**

⌘R in Xcode. Expected:
1. Main window appears with sidebar.
2. Menubar gets a chip icon.
3. Clicking the menubar icon opens a small popover with the placeholder text.
4. Closing the main window — the menubar icon **stays** (because of `applicationShouldTerminateAfterLastWindowClosed = false`).
5. Clicking "Open Main Window" from menubar reopens the window.

- [ ] **Step 3: Commit**

```bash
git add BeagleX/App/BeagleXApp.swift
git commit -m "phase-0: wire menubar + main window scene"
```

---

## Task 16: Localization scaffold (zh + en)

**Files:**
- Create: `/Users/a77/BeagleX/BeagleX/Resources/Localizable.xcstrings`

- [ ] **Step 1: Add String Catalog via Xcode**

In Xcode: **File → New → File… → macOS → Resource → String Catalog** → Name: `Localizable` → Save under `BeagleX/Resources/`.

- [ ] **Step 2: Add Chinese localization**

In the catalog editor:
- Click **+ Localization** → **Chinese (Simplified)** (zh-Hans).
- The English keys created by `String(localized:)` will auto-populate after the next build. For now, manually add:

| Key | English | Chinese |
|---|---|---|
| `Memory` | Memory | 内存 |
| `Processes` | Processes | 进程 |
| `Automation` | Automation | 自动化 |
| `Cache Cleaner` | Cache Cleaner | 缓存清理 |
| `Large Files` | Large Files | 大文件 |
| `Uninstaller` | Uninstaller | 卸载器 |
| `Launch Items` | Launch Items | 启动项 |
| `Settings` | Settings | 设置 |
| `Launch at login` | Launch at login | 开机启动 |
| `Tools` | Tools | 工具 |
| `Open Main Window` | Open Main Window | 打开主窗口 |
| `Quit` | Quit | 退出 |
| `Startup` | Startup | 启动 |
| `About` | About | 关于 |

- [ ] **Step 3: Verify Chinese rendering**

Set the scheme's app language: in Xcode → **Product → Scheme → Edit Scheme… → Run → Options → App Language: Chinese, Simplified** → Run.
Expected: sidebar shows Chinese labels.
Reset App Language to "System" after verification.

- [ ] **Step 4: Commit**

```bash
git add BeagleX/Resources
git commit -m "phase-0: add Localizable string catalog (en + zh-Hans)"
```

---

## Task 17: Sanity test

**Files:**
- Modify: `/Users/a77/BeagleX/BeagleXTests/BeagleXTests.swift`

- [ ] **Step 1: Replace the boilerplate test**

```swift
import XCTest
@testable import BeagleX

final class BeagleXTests: XCTestCase {
    func testAppBundleIdentifier() {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "com.vannaq.beaglex")
    }
}
```

- [ ] **Step 2: Run tests**

⌘U. Expected: all pass (this test + earlier ones).

- [ ] **Step 3: Commit**

```bash
git add BeagleXTests/BeagleXTests.swift
git commit -m "phase-0: sanity test for bundle identifier"
```

---

## Task 18: Manual end-to-end verification

- [ ] **Step 1: Run the app**

⌘R.

- [ ] **Step 2: Tick the verification checklist**

| Check | Expected |
|---|---|
| Menubar icon appears | ✅ chip icon in top-right |
| Click menubar icon | ✅ small popover opens |
| Main window opens | ✅ on launch |
| Sidebar shows 8 items + settings | ✅ |
| Click each sidebar item | ✅ detail view changes |
| Close main window (red ❌ button) | ✅ menubar icon **stays**; app does not quit |
| Click "Open Main Window" from menubar | ✅ window reappears |
| Settings → Launch at login toggle | ✅ system dialog may prompt for approval; status text updates |
| Click "Quit" from menubar | ✅ app fully exits |

- [ ] **Step 3: If any check fails, debug and re-commit fixes**

- [ ] **Step 4: Final commit (only if anything changed during verification)**

```bash
git add -A
git commit -m "phase-0: post-verification fixes" --allow-empty -m "All E2E checks passed."
```

---

## Phase 0 Acceptance Criteria

All of the following are true:

- [ ] `xcodebuild -project BeagleX.xcodeproj -scheme BeagleX build` succeeds without warnings related to deployment target.
- [ ] `xcodebuild -project BeagleX.xcodeproj -scheme BeagleX test` passes.
- [ ] App launches, menubar icon shows, main window has sidebar + 8 placeholder pages + settings.
- [ ] Closing the main window keeps the app alive in the menubar.
- [ ] Quit from menubar terminates the app.
- [ ] Login-at-login toggle works (status text reflects `SMAppService.mainApp.status`).
- [ ] Chinese localization shows when app language is set to zh-Hans.
- [ ] Git log on `main` shows ~18 commits, all prefixed `phase-0:`.

If all check, Phase 0 is complete — proceed to `2026-04-30-phase-1-monitoring.md`.
