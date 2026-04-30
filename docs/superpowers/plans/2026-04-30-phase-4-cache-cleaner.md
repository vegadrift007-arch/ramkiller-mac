# Phase 4 — Cache Cleaner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scan and clean common reclaimable cache directories (developer tools, browsers, application caches, system logs, trash). Driven by a built-in `cleaners.json` knowledge base. User reviews per-cleaner sizes, picks safe-by-default entries, confirms, and clicks Clean.

**Architecture:** Knowledge base loaded from bundled JSON. `ScannerService` computes sizes async per cleaner. `CleanerService` deletes selected paths (most user-owned, no helper needed; system paths optional via helper). UI lists categories with totals + safety badges + checkbox per cleaner.

**Tech Stack:** FileManager, async/await, JSON, SwiftUI.

**Prerequisite:** Phase 0 + 1 + 2 + 3 complete.

---

## File Structure

| Path | Purpose |
|---|---|
| `RamKiller/Resources/KnowledgeBase/cleaners.json` | 30+ pre-built cleaner definitions |
| `RamKiller/Core/Models/Cleaner.swift` | Codable cleaner schema |
| `RamKiller/Core/Services/CleanerKnowledgeBase.swift` | Loads + provides cleaners |
| `RamKiller/Core/Services/ScannerService.swift` | Async size computation |
| `RamKiller/Core/Services/CleanerService.swift` | Delete execution |
| `RamKiller/Core/Services/PathExpander.swift` | Glob/tilde expansion |
| `RamKiller/Features/CacheCleaner/CacheCleanerView.swift` | (replace) main UI |
| `RamKiller/Features/CacheCleaner/CleanerRow.swift` | One cleaner item |
| `RamKiller/Features/CacheCleaner/CleanerCategorySection.swift` | Folding section |
| `RamKiller/Features/CacheCleaner/CleanConfirmDialog.swift` | Pre-flight summary |
| `RamKillerTests/PathExpanderTests.swift` | |
| `RamKillerTests/ScannerServiceTests.swift` | |

---

## Task 1: `Cleaner` schema

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Core/Models/Cleaner.swift`

- [ ] **Step 1: Write the model**

```swift
import Foundation

public enum CleanerSafety: String, Codable {
    case safe, caution, risky
}

public enum CleanerCategory: String, Codable, CaseIterable {
    case developer
    case browser
    case media
    case appCache
    case system
    case trash

    public var label: String {
        switch self {
        case .developer: return "Developer Tools"
        case .browser:   return "Browsers"
        case .media:     return "Media"
        case .appCache:  return "Application Caches"
        case .system:    return "System"
        case .trash:     return "Trash"
        }
    }

    public var icon: String {
        switch self {
        case .developer: return "hammer"
        case .browser:   return "safari"
        case .media:     return "play.rectangle"
        case .appCache:  return "app"
        case .system:    return "macwindow"
        case .trash:     return "trash"
        }
    }
}

public struct Cleaner: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let description: String
    public let category: CleanerCategory
    public let safety: CleanerSafety
    public let paths: [String]              // tilde + glob supported (single-level *)
    public let requiresHelper: Bool         // true if path is in /Library or /System
}
```

- [ ] **Step 2: Commit**

```bash
git add RamKiller/Core/Models/Cleaner.swift
git commit -m "phase-4: Cleaner schema"
```

---

## Task 2: Bundle `cleaners.json` (30 entries)

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Resources/KnowledgeBase/cleaners.json`

- [ ] **Step 1: Write the file**

```json
[
  {
    "id": "xcode_derived_data",
    "name": "Xcode DerivedData",
    "description": "Xcode build cache. Safe to delete; rebuilds automatically on next compile.",
    "category": "developer",
    "safety": "safe",
    "paths": ["~/Library/Developer/Xcode/DerivedData/*"],
    "requiresHelper": false
  },
  {
    "id": "xcode_archives",
    "name": "Xcode Archives",
    "description": "Old build archives. Caution: contains dSYM and IPAs you may want.",
    "category": "developer",
    "safety": "caution",
    "paths": ["~/Library/Developer/Xcode/Archives/*"],
    "requiresHelper": false
  },
  {
    "id": "ios_device_support",
    "name": "Xcode iOS DeviceSupport",
    "description": "Device support files for old iOS versions. Caution: re-downloaded on next attach.",
    "category": "developer",
    "safety": "caution",
    "paths": ["~/Library/Developer/Xcode/iOS DeviceSupport/*"],
    "requiresHelper": false
  },
  {
    "id": "core_simulator",
    "name": "Xcode Simulator data",
    "description": "Old simulator runtime data. Risky: deletes installed simulator apps and their state.",
    "category": "developer",
    "safety": "risky",
    "paths": ["~/Library/Developer/CoreSimulator/Caches/*"],
    "requiresHelper": false
  },
  {
    "id": "homebrew_downloads",
    "name": "Homebrew Downloads",
    "description": "Cached formula downloads (.tar.gz/.bottle).",
    "category": "developer",
    "safety": "safe",
    "paths": ["~/Library/Caches/Homebrew/downloads/*"],
    "requiresHelper": false
  },
  {
    "id": "npm_cache",
    "name": "npm cache",
    "description": "npm package cache.",
    "category": "developer",
    "safety": "safe",
    "paths": ["~/.npm/_cacache/*"],
    "requiresHelper": false
  },
  {
    "id": "yarn_cache",
    "name": "Yarn cache",
    "description": "Yarn package cache.",
    "category": "developer",
    "safety": "safe",
    "paths": ["~/Library/Caches/Yarn/*"],
    "requiresHelper": false
  },
  {
    "id": "pnpm_cache",
    "name": "pnpm cache",
    "description": "pnpm content-addressed store.",
    "category": "developer",
    "safety": "caution",
    "paths": ["~/Library/pnpm/store/*"],
    "requiresHelper": false
  },
  {
    "id": "pip_cache",
    "name": "pip cache",
    "description": "Python package wheel cache.",
    "category": "developer",
    "safety": "safe",
    "paths": ["~/Library/Caches/pip/*"],
    "requiresHelper": false
  },
  {
    "id": "gradle_cache",
    "name": "Gradle cache",
    "description": "Gradle dependency + build cache.",
    "category": "developer",
    "safety": "safe",
    "paths": ["~/.gradle/caches/*"],
    "requiresHelper": false
  },
  {
    "id": "maven_repo",
    "name": "Maven local repo",
    "description": "Maven dependency cache.",
    "category": "developer",
    "safety": "caution",
    "paths": ["~/.m2/repository/*"],
    "requiresHelper": false
  },
  {
    "id": "go_module_cache",
    "name": "Go module cache",
    "description": "Go module download cache.",
    "category": "developer",
    "safety": "safe",
    "paths": ["~/go/pkg/mod/cache/*"],
    "requiresHelper": false
  },
  {
    "id": "rust_target",
    "name": "Rust target dirs (workspace caches)",
    "description": "Cargo build artifacts in your home dir's cargo cache.",
    "category": "developer",
    "safety": "safe",
    "paths": ["~/.cargo/registry/cache/*", "~/.cargo/registry/src/*"],
    "requiresHelper": false
  },
  {
    "id": "docker_temp",
    "name": "Docker Desktop logs/cache",
    "description": "Docker Desktop log files.",
    "category": "developer",
    "safety": "safe",
    "paths": ["~/Library/Containers/com.docker.docker/Data/log/*"],
    "requiresHelper": false
  },
  {
    "id": "chrome_cache",
    "name": "Chrome cache",
    "description": "Browser cache; cookies/history are NOT touched.",
    "category": "browser",
    "safety": "safe",
    "paths": [
      "~/Library/Caches/Google/Chrome/*",
      "~/Library/Application Support/Google/Chrome/Default/Cache/Cache_Data/*"
    ],
    "requiresHelper": false
  },
  {
    "id": "safari_cache",
    "name": "Safari cache",
    "description": "Safari resource cache.",
    "category": "browser",
    "safety": "safe",
    "paths": [
      "~/Library/Caches/com.apple.Safari/*",
      "~/Library/Caches/com.apple.SafariViewService/*"
    ],
    "requiresHelper": false
  },
  {
    "id": "firefox_cache",
    "name": "Firefox cache",
    "description": "Firefox cache2 directory.",
    "category": "browser",
    "safety": "safe",
    "paths": ["~/Library/Caches/Firefox/Profiles/*/cache2/*"],
    "requiresHelper": false
  },
  {
    "id": "arc_cache",
    "name": "Arc browser cache",
    "description": "Arc browser cache.",
    "category": "browser",
    "safety": "safe",
    "paths": ["~/Library/Caches/company.thebrowser.Browser/*"],
    "requiresHelper": false
  },
  {
    "id": "quicktime_cache",
    "name": "QuickTime caches",
    "description": "QuickTime Player caches.",
    "category": "media",
    "safety": "safe",
    "paths": ["~/Library/Caches/com.apple.QuickTimePlayerX/*"],
    "requiresHelper": false
  },
  {
    "id": "video_thumbnails",
    "name": "Quick Look thumbnails",
    "description": "Thumbnail cache for Finder previews.",
    "category": "media",
    "safety": "safe",
    "paths": ["~/Library/Caches/com.apple.QuickLook.thumbnailcache/*"],
    "requiresHelper": false
  },
  {
    "id": "slack_cache",
    "name": "Slack cache",
    "description": "Slack desktop cache (will require re-login if signed-in tokens cached here, rare).",
    "category": "appCache",
    "safety": "caution",
    "paths": [
      "~/Library/Application Support/Slack/Cache/*",
      "~/Library/Application Support/Slack/Service Worker/CacheStorage/*"
    ],
    "requiresHelper": false
  },
  {
    "id": "discord_cache",
    "name": "Discord cache",
    "description": "Discord renderer cache.",
    "category": "appCache",
    "safety": "safe",
    "paths": ["~/Library/Application Support/discord/Cache/*"],
    "requiresHelper": false
  },
  {
    "id": "spotify_cache",
    "name": "Spotify cache",
    "description": "Spotify track cache and PersistentCache.",
    "category": "appCache",
    "safety": "safe",
    "paths": [
      "~/Library/Caches/com.spotify.client/*",
      "~/Library/Application Support/Spotify/PersistentCache/*"
    ],
    "requiresHelper": false
  },
  {
    "id": "telegram_cache",
    "name": "Telegram cache",
    "description": "Telegram Desktop's local media cache.",
    "category": "appCache",
    "safety": "safe",
    "paths": ["~/Library/Group Containers/*.ru.keepcoder.Telegram/stable/account-*/postbox/media_cache/*"],
    "requiresHelper": false
  },
  {
    "id": "vscode_workspaces",
    "name": "VS Code workspace storage",
    "description": "VS Code per-workspace storage. Risky: loses some unsaved IDE state.",
    "category": "appCache",
    "safety": "risky",
    "paths": ["~/Library/Application Support/Code/User/workspaceStorage/*"],
    "requiresHelper": false
  },
  {
    "id": "system_logs_old",
    "name": "Old system logs (>7 days)",
    "description": "ASL/log files older than 7 days. Logs from past week are kept.",
    "category": "system",
    "safety": "safe",
    "paths": ["~/Library/Logs/*"],
    "requiresHelper": false
  },
  {
    "id": "crash_reports",
    "name": "Crash Reports (>7 days)",
    "description": "Diagnostic reports older than 7 days.",
    "category": "system",
    "safety": "safe",
    "paths": ["~/Library/Logs/DiagnosticReports/*"],
    "requiresHelper": false
  },
  {
    "id": "recent_items",
    "name": "Recent files lists",
    "description": "macOS shared file lists (Recents).",
    "category": "system",
    "safety": "caution",
    "paths": ["~/Library/Application Support/com.apple.sharedfilelist/*"],
    "requiresHelper": false
  },
  {
    "id": "saved_app_state",
    "name": "Saved Application State",
    "description": "Apps will not restore window positions on next launch.",
    "category": "system",
    "safety": "caution",
    "paths": ["~/Library/Saved Application State/*"],
    "requiresHelper": false
  },
  {
    "id": "trash",
    "name": "Empty Trash",
    "description": "Empty the user's Trash bin.",
    "category": "trash",
    "safety": "safe",
    "paths": ["~/.Trash/*"],
    "requiresHelper": false
  }
]
```

- [ ] **Step 2: Add to Resources in Xcode**

In Xcode → drag `cleaners.json` from Finder into the project navigator under `RamKiller/Resources/`. Make sure "Copy items if needed" is checked and **RamKiller** is the target.

- [ ] **Step 3: Commit**

```bash
git add RamKiller/Resources/KnowledgeBase/cleaners.json RamKiller.xcodeproj
git commit -m "phase-4: bundle cleaners.json knowledge base (30 entries)"
```

---

## Task 3: `CleanerKnowledgeBase`

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Core/Services/CleanerKnowledgeBase.swift`

- [ ] **Step 1: Write the loader**

```swift
import Foundation

public final class CleanerKnowledgeBase {
    public static let shared = CleanerKnowledgeBase()

    public let cleaners: [Cleaner]

    private init() {
        guard let url = Bundle.main.url(forResource: "cleaners", withExtension: "json", subdirectory: "KnowledgeBase")
                     ?? Bundle.main.url(forResource: "cleaners", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Cleaner].self, from: data) else {
            NSLog("[cleaners] failed to load")
            self.cleaners = []
            return
        }
        self.cleaners = decoded
    }

    public func byCategory() -> [(CleanerCategory, [Cleaner])] {
        CleanerCategory.allCases.compactMap { cat in
            let items = cleaners.filter { $0.category == cat }
            return items.isEmpty ? nil : (cat, items)
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add RamKiller/Core/Services/CleanerKnowledgeBase.swift
git commit -m "phase-4: CleanerKnowledgeBase loader"
```

---

## Task 4: `PathExpander`

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Core/Services/PathExpander.swift`
- Test: `/Users/a77/RamKiller/RamKillerTests/PathExpanderTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import RamKiller

final class PathExpanderTests: XCTestCase {
    func testTildeExpansion() {
        let r = PathExpander.expand("~/Library")
        XCTAssertTrue(r.first?.hasPrefix("/Users/") == true)
        XCTAssertTrue(r.first?.hasSuffix("/Library") == true)
    }

    func testGlobMatchesCurrentDirContents() throws {
        let tmp = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        ["a.txt","b.txt","c.txt"].forEach {
            FileManager.default.createFile(atPath: tmp.appending(path: $0).path, contents: Data())
        }
        let matches = PathExpander.expand(tmp.path + "/*")
        XCTAssertEqual(Set(matches.map { ($0 as NSString).lastPathComponent }), ["a.txt","b.txt","c.txt"])
    }
}
```

- [ ] **Step 2: Implement**

```swift
import Foundation

public enum PathExpander {
    public static func expand(_ path: String) -> [String] {
        let withHome = (path as NSString).expandingTildeInPath
        if withHome.contains("*") {
            return globMatches(pattern: withHome)
        }
        return [withHome]
    }

    private static func globMatches(pattern: String) -> [String] {
        var result = [String]()
        var gt = glob_t()
        let cString = (pattern as NSString).utf8String
        let rc = glob(cString, GLOB_TILDE, nil, &gt)
        defer { globfree(&gt) }
        if rc == 0 {
            for i in 0..<Int(gt.gl_pathc) {
                if let p = gt.gl_pathv[i] {
                    result.append(String(cString: p))
                }
            }
        }
        return result
    }
}
```

- [ ] **Step 3: Run tests, expect pass**

- [ ] **Step 4: Commit**

```bash
git add RamKiller/Core/Services/PathExpander.swift RamKillerTests/PathExpanderTests.swift
git commit -m "phase-4: PathExpander with tilde + glob"
```

---

## Task 5: `ScannerService`

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Core/Services/ScannerService.swift`
- Test: `/Users/a77/RamKiller/RamKillerTests/ScannerServiceTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import RamKiller

final class ScannerServiceTests: XCTestCase {
    func testScanReturnsBytesForExistingPath() async throws {
        let tmp = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let bytes = "hello".data(using: .utf8)!
        try bytes.write(to: tmp.appending(path: "a.txt"))

        let cleaner = Cleaner(
            id: "test", name: "test", description: "test",
            category: .system, safety: .safe,
            paths: [tmp.path + "/*"],
            requiresHelper: false
        )

        let service = ScannerService()
        let size = await service.computeSize(for: cleaner)
        XCTAssertEqual(size, 5)
    }

    func testScanReturnsZeroForMissingPath() async {
        let cleaner = Cleaner(
            id: "missing", name: "missing", description: "",
            category: .system, safety: .safe,
            paths: ["/nonexistent/path/123/*"],
            requiresHelper: false
        )
        let size = await ScannerService().computeSize(for: cleaner)
        XCTAssertEqual(size, 0)
    }
}
```

- [ ] **Step 2: Implement**

```swift
import Foundation

public actor ScannerService {
    public init() {}

    public func computeSize(for cleaner: Cleaner) -> Int64 {
        var total: Int64 = 0
        for p in cleaner.paths {
            for resolved in PathExpander.expand(p) {
                total += sizeOf(path: resolved)
            }
        }
        return total
    }

    public func computeSizes(for cleaners: [Cleaner]) async -> [String: Int64] {
        await withTaskGroup(of: (String, Int64).self) { group in
            for c in cleaners {
                group.addTask { (c.id, await self.computeSize(for: c)) }
            }
            var result: [String: Int64] = [:]
            for await (id, size) in group {
                result[id] = size
            }
            return result
        }
    }

    private func sizeOf(path: String) -> Int64 {
        let url = URL(fileURLWithPath: path)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else { return 0 }
        if isDir.boolValue {
            var total: Int64 = 0
            if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
                for case let fileURL as URL in enumerator {
                    let res = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                    if res?.isDirectory == false {
                        total += Int64(res?.fileSize ?? 0)
                    }
                }
            }
            return total
        }
        let res = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(res?.fileSize ?? 0)
    }
}
```

- [ ] **Step 3: Run tests, expect pass**

- [ ] **Step 4: Commit**

```bash
git add RamKiller/Core/Services/ScannerService.swift RamKillerTests/ScannerServiceTests.swift
git commit -m "phase-4: ScannerService with parallel size compute"
```

---

## Task 6: `CleanerService` — perform delete

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Core/Services/CleanerService.swift`

- [ ] **Step 1: Write the service**

```swift
import Foundation

public final class CleanerService {
    public init() {}

    public struct CleanResult {
        public let cleanerId: String
        public let bytesFreed: Int64
        public let errors: [String]
    }

    public func clean(_ cleaners: [Cleaner], moveToTrash: Bool = true) async -> [CleanResult] {
        var results: [CleanResult] = []
        for cleaner in cleaners {
            var freed: Int64 = 0
            var errs: [String] = []
            for p in cleaner.paths {
                for resolved in PathExpander.expand(p) {
                    let url = URL(fileURLWithPath: resolved)
                    let size = self.sizeOf(url)
                    do {
                        if moveToTrash {
                            var resulting: NSURL?
                            try FileManager.default.trashItem(at: url, resultingItemURL: &resulting)
                        } else {
                            try FileManager.default.removeItem(at: url)
                        }
                        freed += size
                    } catch {
                        errs.append("\(resolved): \(error.localizedDescription)")
                    }
                }
            }
            results.append(CleanResult(cleanerId: cleaner.id, bytesFreed: freed, errors: errs))
            UserActionLog.shared.record(
                type: "clean_cache",
                target: cleaner.id,
                success: errs.isEmpty,
                error: errs.first,
                bytesFreed: freed
            )
        }
        return results
    }

    private func sizeOf(_ url: URL) -> Int64 {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        if isDir.boolValue {
            var total: Int64 = 0
            if let e = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) {
                for case let f as URL in e {
                    let r = try? f.resourceValues(forKeys: [.fileSizeKey])
                    total += Int64(r?.fileSize ?? 0)
                }
            }
            return total
        }
        let r = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(r?.fileSize ?? 0)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add RamKiller/Core/Services/CleanerService.swift
git commit -m "phase-4: CleanerService with trash/permanent delete"
```

---

## Task 7: `CleanerRow` UI component

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Features/CacheCleaner/CleanerRow.swift`

- [ ] **Step 1: Write the row**

```swift
import SwiftUI

struct CleanerRow: View {
    let cleaner: Cleaner
    let size: Int64?
    @Binding var selected: Bool
    @State private var showInfo: Bool = false

    var body: some View {
        HStack {
            Toggle("", isOn: $selected).labelsHidden()
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(cleaner.name).fontWeight(.medium)
                    badge
                    if showInfo {
                        Text(cleaner.description).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if !showInfo {
                    Text(cleaner.description).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(sizeLabel)
                .monospacedDigit()
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { showInfo.toggle() }
    }

    private var sizeLabel: String {
        guard let s = size else { return "—" }
        if s == 0 { return "0 B" }
        if s < 1024 * 1024 { return "\(s / 1024) KB" }
        return ByteFormat.mb(s)
    }

    @ViewBuilder
    private var badge: some View {
        switch cleaner.safety {
        case .safe:    EmptyView()
        case .caution: Text("⚠️").font(.caption)
        case .risky:   Text("🔴").font(.caption)
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add RamKiller/Features/CacheCleaner/CleanerRow.swift
git commit -m "phase-4: CleanerRow"
```

---

## Task 8: `CleanerCategorySection`

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Features/CacheCleaner/CleanerCategorySection.swift`

- [ ] **Step 1: Write the section**

```swift
import SwiftUI

struct CleanerCategorySection: View {
    let category: CleanerCategory
    let cleaners: [Cleaner]
    let sizes: [String: Int64]
    @Binding var selectedIDs: Set<String>
    @State private var expanded: Bool = true

    private var categoryTotal: Int64 {
        cleaners.reduce(into: 0) { $0 += sizes[$1.id] ?? 0 }
    }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            ForEach(cleaners) { cleaner in
                CleanerRow(
                    cleaner: cleaner,
                    size: sizes[cleaner.id],
                    selected: Binding(
                        get: { selectedIDs.contains(cleaner.id) },
                        set: { isOn in
                            if isOn { selectedIDs.insert(cleaner.id) } else { selectedIDs.remove(cleaner.id) }
                        }
                    )
                )
                Divider()
            }
        } label: {
            HStack {
                Image(systemName: category.icon)
                Text(category.label).fontWeight(.semibold)
                Spacer()
                Text(ByteFormat.mb(categoryTotal))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add RamKiller/Features/CacheCleaner/CleanerCategorySection.swift
git commit -m "phase-4: CleanerCategorySection"
```

---

## Task 9: `CacheCleanerView` main view

**Files:**
- Modify: `/Users/a77/RamKiller/RamKiller/Features/CacheCleaner/CacheCleanerView.swift`

- [ ] **Step 1: Replace placeholder**

```swift
import SwiftUI

struct CacheCleanerView: View {
    @State private var sizes: [String: Int64] = [:]
    @State private var selectedIDs: Set<String> = []
    @State private var scanning: Bool = false
    @State private var scanProgress: Double = 0
    @State private var moveToTrash: Bool = true
    @State private var lastResult: [CleanerService.CleanResult] = []
    @State private var showConfirm: Bool = false

    private let kb = CleanerKnowledgeBase.shared

    private var selectedTotal: Int64 {
        kb.cleaners.filter { selectedIDs.contains($0.id) }
            .reduce(into: 0) { $0 += sizes[$1.id] ?? 0 }
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button("Scan") { Task { await scan() } }
                    .disabled(scanning)
                if scanning {
                    ProgressView(value: scanProgress).frame(width: 160)
                }
                Spacer()
                Toggle("Move to Trash (recoverable)", isOn: $moveToTrash)
                Button {
                    showConfirm = true
                } label: {
                    Label("Clean \(ByteFormat.mb(selectedTotal))", systemImage: "trash")
                }
                .disabled(selectedTotal == 0 || scanning)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(kb.byCategory(), id: \.0) { (cat, items) in
                        CleanerCategorySection(
                            category: cat,
                            cleaners: items,
                            sizes: sizes,
                            selectedIDs: $selectedIDs
                        )
                        .padding()
                        Divider()
                    }
                }
            }

            if !lastResult.isEmpty {
                resultBanner
            }
        }
        .navigationTitle("Cache Cleaner")
        .task { await scan() }
        .alert("Clean \(ByteFormat.mb(selectedTotal))?", isPresented: $showConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clean", role: .destructive) { Task { await performClean() } }
        } message: {
            Text("This will \(moveToTrash ? "move to Trash" : "permanently delete") files matched by \(selectedIDs.count) cleaner\(selectedIDs.count > 1 ? "s" : "").")
        }
    }

    private var resultBanner: some View {
        let totalFreed = lastResult.reduce(into: Int64(0)) { $0 += $1.bytesFreed }
        let totalErrors = lastResult.reduce(into: 0) { $0 += $1.errors.count }
        return HStack {
            Image(systemName: "checkmark.circle").foregroundStyle(.green)
            Text("Freed \(ByteFormat.mb(totalFreed))" + (totalErrors > 0 ? " (\(totalErrors) errors)" : ""))
            Spacer()
            Button("Dismiss") { lastResult = [] }
        }
        .padding(8)
        .background(Color.green.opacity(0.1))
        .padding(.horizontal)
    }

    private func scan() async {
        scanning = true
        sizes = [:]
        selectedIDs = []
        let scanner = ScannerService()
        let total = Double(kb.cleaners.count)
        var done = 0
        await withTaskGroup(of: (String, Int64).self) { group in
            for c in kb.cleaners {
                group.addTask { (c.id, await scanner.computeSize(for: c)) }
            }
            for await (id, size) in group {
                sizes[id] = size
                done += 1
                scanProgress = Double(done) / total
            }
        }
        // Default-select 'safe' cleaners with > 0 bytes
        selectedIDs = Set(kb.cleaners.filter { $0.safety == .safe && (sizes[$0.id] ?? 0) > 0 }.map { $0.id })
        scanning = false
    }

    private func performClean() async {
        let toClean = kb.cleaners.filter { selectedIDs.contains($0.id) }
        let service = CleanerService()
        lastResult = await service.clean(toClean, moveToTrash: moveToTrash)
        // Re-scan to refresh sizes
        await scan()
    }
}
```

- [ ] **Step 2: Build and run, navigate to Cache Cleaner**

⌘R. Verify:
- Scan progress bar fills.
- Categories show with totals.
- Safe entries default-selected.
- Clean button shows total selected.
- Click → confirmation → actual delete → banner with freed bytes.
- Move to Trash toggle controls behavior.

- [ ] **Step 3: Commit**

```bash
git add RamKiller/Features/CacheCleaner/CacheCleanerView.swift
git commit -m "phase-4: CacheCleanerView complete"
```

---

## Task 10: Acceptance verification

- [ ] **Step 1: Run all tests**

⌘U. All Phase 0–4 tests pass.

- [ ] **Step 2: End-to-end manual checks**

| Check | Expected |
|---|---|
| Initial scan shows real sizes (Xcode DerivedData usually shows GBs) | ✅ |
| Safe items default-selected | ✅ |
| Caution items not selected by default | ✅ |
| Toggle individual items | ✅ |
| Click row body → expands description | ✅ |
| Move-to-Trash → file appears in `~/.Trash/` | ✅ |
| Permanent delete → file gone | ✅ |
| UserAction log records each clean operation | ✅ (verify in Automation → Actions tab) |
| Re-scan after clean → sizes go to zero / refreshed | ✅ |

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "phase-4: post-verification" --allow-empty
```

---

## Phase 4 Acceptance Criteria

- [ ] All XCTest pass.
- [ ] Knowledge base loaded successfully (30 cleaners).
- [ ] Scan completes in < 15 s on a typical machine.
- [ ] Trash + permanent delete both work.
- [ ] User Action log records each clean.
- [ ] Browser caches do NOT touch cookies/history (verify by re-opening browser → still logged in).

If all check, Phase 4 is complete — proceed to `2026-04-30-phase-5-large-files.md`.
